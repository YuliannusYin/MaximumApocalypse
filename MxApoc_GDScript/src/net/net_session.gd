extends Node

## 房主权威网络会话。所有业务数据通过 receive_message() 进入同一校验入口。
const NetProtocol = preload("res://src/net/net_protocol.gd")
const NetRegistry = preload("res://src/net/net_registry.gd")
const NetInputCodec = preload("res://src/net/net_input_codec.gd")
const GameStateSerializer = preload("res://src/net/game_state_serializer.gd")
const ServerRuntimeScript = preload("res://src/net/server_runtime.gd")
const LoopbackRpcScript = preload("res://src/net/net_loopback_rpc.gd")
const LOOPBACK_ROOT_NAME := "NetLoopbackRoot"
const LOOPBACK_RPC_NAME := "NetSession"

signal session_changed(snapshot: Dictionary)
signal connection_state_changed(state: String, detail: String)
signal message_received(message: Dictionary)
signal network_error(code: String, detail: String)
signal player_presence_changed(player_id: String, state: String, display_name: String, left: bool)

var registry = NetRegistry.new()
var is_host: bool = false
var session_role: String = "none" # none/host/client
var local_player_id: String = ""
var local_reconnect_token: String = ""
var _client_sequence: int = 0
var _connected_address: String = ""
var _resolved_ip: String = ""
var _pending_nickname: String = ""
var _saved_identity: Dictionary = {}
var _state_snapshot_dirty: bool = false
var _request_id_counter: int = 0
var server_runtime: Node = null
var _client_api: MultiplayerAPI = null
var _loopback_root: Node = null
var _loopback_stub: Node = null
var _view_game: Node = null
var applying_display_snapshot: bool = false
var _closing: bool = false
var _awaiting_room_accept: bool = false
var _last_heartbeat_sent_ms: int = 0
## 每次替换/关闭 peer 时递增，用来丢掉上一次连接迟到的断开回调。
var _peer_serial: int = 0
var _handling_client_disconnect: bool = false
var _last_client_connect_error: String = ""
var _hello_used_reconnect: bool = false
var _hello_retry_at_ms: int = 0
var _hello_retry_delay_ms: int = 0
var _hello_retry_attempts: int = 0
## 单测可强制覆盖传输是否连通；null 表示按真实 peer 判断。
var _transport_connected_override: Variant = null
## 尚未绑座位的 peer 带来的昵称，旁观断开时用来刷新掉线。
var _peer_display_names: Dictionary = {}


func is_authority() -> bool:
	return has_active_server_runtime() or has_listen_server() \
		or (is_host and session_role == "host")


func has_listen_server() -> bool:
	var api := _server_api()
	if api == null or not _multiplayer_peer_is_live(api.multiplayer_peer):
		return false
	return api.is_server()


func _multiplayer_peer_is_live(peer: MultiplayerPeer) -> bool:
	return peer != null \
			and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_room_owner() -> bool:
	if local_player_id != "" and registry.players.has(local_player_id):
		return bool(registry.players[local_player_id].get("is_host", false))
	return is_host and session_role != "none"


func is_remote_client() -> bool:
	return session_role == "client" and not is_room_owner()


## 对局 UI 是否按客机通道刷新：环回后的房主也是 client。
func uses_network_view() -> bool:
	return session_role == "client"


## 该座位是否由本机玩家操作（不含 AI、不含他人座位）。
func is_local_controlled_seat(seat_id: int) -> bool:
	if local_player_id == "" or seat_id < 0 or seat_id >= registry.seats.size():
		return false
	return String(registry.seats[seat_id].get("controller_id", "")) == local_player_id


## 从对局玩家列表中挑出本机操作的座位。
func filter_local_controlled_players(players: Array) -> Array:
	var result: Array = []
	for player in players:
		if player == null or typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
			continue
		if is_local_controlled_seat(int(player.get("seat_number"))):
			result.append(player)
	return result


func is_awaiting_room_accept() -> bool:
	return _awaiting_room_accept


func has_loopback_client() -> bool:
	return _client_api != null

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_load_saved_identity()

func _process(_delta: float) -> void:
	_tick_heartbeat()
	_tick_hello_retry()
	if not is_authority():
		return
	_flush_pending_state_snapshot()
	_scan_heartbeat_timeouts()

func create_host(host_name: String, port: int, seats: Array) -> bool:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, NetProtocol.MAX_PLAYERS)
	if result != OK:
		network_error.emit(NetProtocol.ERROR_PORT_IN_USE, "无法占用端口 %d" % port)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	session_role = "host"
	var credentials := registry.create_host(host_name, port, seats)
	local_player_id = String(credentials.get("player_id", ""))
	local_reconnect_token = String(credentials.get("reconnect_token", ""))
	_save_identity()
	connection_state_changed.emit("host", "房间已创建")
	_emit_snapshot()
	if not _enter_host_loopback():
		close_session()
		network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "无法连入本机房间")
		return false
	return true

func join(address: String, nickname: String) -> bool:
	var guest_token := ""
	if not is_host and session_role != "host" and not is_room_owner():
		guest_token = local_reconnect_token
	var kept_identity: Dictionary = _saved_identity.duplicate(true)
	close_session()
	if not kept_identity.is_empty():
		_saved_identity = kept_identity
	local_reconnect_token = guest_token
	if local_reconnect_token.is_empty():
		local_reconnect_token = String(_identity_slot_dict(
			_saved_identity, NetProtocol.IDENTITY_SLOT_GUEST).get("reconnect_token", ""))
	var parsed := NetProtocol.parse_address(address)
	if not bool(parsed.get("ok", false)):
		network_error.emit(String(parsed.get("error", NetProtocol.ERROR_INVALID_ADDRESS)), "地址格式无效")
		return false
	var resolved: Dictionary = NetProtocol.resolve_host(String(parsed.host))
	if not bool(resolved.get("ok", false)):
		network_error.emit(NetProtocol.ERROR_INVALID_ADDRESS, "无法解析地址")
		return false
	if not _open_client_peer(String(resolved.ip), int(parsed.port),
			"%s:%d" % [String(parsed.host), int(parsed.port)],
			NetProtocol.normalize_nickname(nickname)):
		return false
	connection_state_changed.emit("connecting", "正在连接房间")
	return true


## 对局中重连：保留凭证和 ViewGame，只重建 ENet 客机连接。
func reconnect_to_last_room() -> bool:
	_last_client_connect_error = ""
	if is_room_owner() or session_role == "host":
		_last_client_connect_error = "房主不需要客机重连"
		return false
	var address := _connected_address
	if address.is_empty():
		_last_client_connect_error = "没有可重连的房间地址"
		return false
	var token := _hello_reconnect_token()
	if token.is_empty():
		_last_client_connect_error = "没有重连凭证"
		return false
	var parsed := NetProtocol.parse_address(address)
	if not bool(parsed.get("ok", false)):
		_last_client_connect_error = "房间地址无效"
		return false
	var cached: Dictionary = _client_connect_ip(String(parsed.host))
	if not bool(cached.get("ok", false)):
		_last_client_connect_error = "无法解析地址"
		network_error.emit(NetProtocol.ERROR_INVALID_ADDRESS, "无法解析地址")
		return false
	var connect_ip := String(cached.ip)
	_invalidate_peer_callbacks()
	_teardown_client_peer()
	if not _open_client_peer(connect_ip, int(parsed.port), address, _pending_nickname):
		_last_client_connect_error = "无法创建客户端连接"
		return false
	local_reconnect_token = token
	_last_heartbeat_sent_ms = 0
	connection_state_changed.emit("connecting", "正在重连房间")
	return true


func last_client_connect_error() -> String:
	return _last_client_connect_error


func _hello_reconnect_token() -> String:
	if local_reconnect_token != "":
		return local_reconnect_token
	return String(_identity_slot_dict(_saved_identity, _hello_identity_slot()).get("reconnect_token", ""))


func _invalidate_peer_callbacks() -> void:
	_peer_serial += 1


func _client_connect_ip(host: String) -> Dictionary:
	if _resolved_ip.is_valid_ip_address():
		return {"ok": true, "ip": _resolved_ip, "error": ""}
	return NetProtocol.resolve_host(host)


func _begin_client_peer(peer: ENetMultiplayerPeer, address: String, nickname: String,
		resolved_ip: String = "") -> void:
	_invalidate_peer_callbacks()
	if multiplayer != null:
		multiplayer.multiplayer_peer = peer
	is_host = false
	session_role = "client"
	_pending_nickname = nickname
	_connected_address = address
	_resolved_ip = resolved_ip
	_awaiting_room_accept = true
	_last_heartbeat_sent_ms = 0
	_hello_used_reconnect = false
	_reset_hello_retry()


func _open_client_peer(connect_ip: String, port: int, display_address: String,
		nickname: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(connect_ip, port)
	if result != OK:
		_emit_client_create_error(result)
		return false
	_begin_client_peer(peer, display_address, nickname, connect_ip)
	return true


func _emit_client_create_error(result: int) -> void:
	var mapped: Dictionary = NetProtocol.client_create_error(result)
	network_error.emit(String(mapped.get("code", NetProtocol.ERROR_CONNECTION_REFUSED)),
			String(mapped.get("detail", "无法创建客户端连接")))


func _teardown_client_peer() -> void:
	if multiplayer == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	# 先从 MultiplayerAPI 摘掉，再 close，避免在 ENet 回调栈里拆掉正在派发的 peer。
	multiplayer.multiplayer_peer = null
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()

func close_session() -> void:
	if _closing:
		return
	_closing = true
	_handling_client_disconnect = false
	_invalidate_peer_callbacks()
	stop_server_runtime()
	_teardown_loopback_client()
	_clear_view_game()
	_teardown_client_peer()
	is_host = false
	session_role = "none"
	local_player_id = ""
	local_reconnect_token = ""
	_pending_nickname = ""
	_connected_address = ""
	_resolved_ip = ""
	_awaiting_room_accept = false
	_last_heartbeat_sent_ms = 0
	_hello_used_reconnect = false
	_reset_hello_retry()
	_last_client_connect_error = ""
	_peer_display_names.clear()
	registry = NetRegistry.new()
	_state_snapshot_dirty = false
	_request_id_counter = 0
	connection_state_changed.emit("closed", "")
	_closing = false


func ensure_server_runtime() -> Node:
	if server_runtime != null and is_instance_valid(server_runtime):
		return server_runtime
	server_runtime = ServerRuntimeScript.new()
	server_runtime.name = "ServerRuntime"
	var root: Node = get_tree().root if get_tree() != null else self
	root.add_child(server_runtime)
	return server_runtime


func has_active_server_runtime() -> bool:
	return server_runtime != null and is_instance_valid(server_runtime) \
			and server_runtime.has_method("is_active") and server_runtime.is_active()


func stop_server_runtime() -> void:
	if server_runtime != null and is_instance_valid(server_runtime):
		server_runtime.stop()
	server_runtime = null


func next_request_id() -> int:
	_request_id_counter += 1
	return _request_id_counter


func begin_online_match() -> void:
	ensure_server_runtime()
	server_runtime.begin_match_from_lobby()
	_ensure_view_game()
	_broadcast(NetProtocol.MATCH_START, {
		"match_id": registry.match_id,
		"match_seed": registry.match_seed,
		"room_snapshot": registry.snapshot(),
	})
	if not has_loopback_client():
		_enter_host_loopback()


## 对局结束后把房间收回大厅：不拆监听、不清结算用的 Game。
func return_match_to_lobby() -> void:
	if not is_authority():
		return
	registry.set_phase("lobby")
	_emit_snapshot()


## 结算后返回房间：清掉对局视图；房主停掉 Runtime，便于下一局重建。
func cleanup_match_for_lobby() -> void:
	_clear_view_game()
	if is_authority() or is_room_owner():
		stop_server_runtime()
		if registry.phase != "lobby":
			return_match_to_lobby()


func close_authority_room(reason: String) -> void:
	_broadcast(NetProtocol.ROOM_CLOSED, {"reason": reason})
	close_session()


func get_display_game() -> Node:
	if _view_game != null and is_instance_valid(_view_game):
		return _view_game
	if _uses_display_world():
		return _ensure_view_game()
	return Game


func peek_view_game() -> Node:
	if _view_game != null and is_instance_valid(_view_game):
		return _view_game
	return null


## 客机认座成功后丢掉旧显示世界，随后由对局场景重建 ViewGame。
func rebuild_display_world() -> void:
	_clear_view_game()


## 客机重连进对局：已在 playing 且本进程不是权威运行时。
func should_enter_match_scene() -> bool:
	return registry.phase == "playing" and not has_active_server_runtime() \
			and is_remote_client()


func _uses_display_world() -> bool:
	return uses_network_view() or has_active_server_runtime()


func _ensure_view_game() -> Node:
	if not _uses_display_world():
		return Game
	if _view_game != null and is_instance_valid(_view_game):
		return _view_game
	var game_script: Script = Game.get_script()
	_view_game = game_script.new()
	_view_game.name = "ViewGame"
	add_child(_view_game)
	return _view_game


func _clear_view_game() -> void:
	if _view_game != null and is_instance_valid(_view_game):
		_view_game.queue_free()
	_view_game = null
	applying_display_snapshot = false


func apply_display_game_snapshot(snapshot: Dictionary, ctx: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if _uses_display_world():
		_ensure_view_game()
		if get_display_game() == Game:
			push_error("NetSession: 拒绝把对局快照套到权威 Game 上")
			return
	applying_display_snapshot = true
	GameStateSerializer.apply(get_display_game(), snapshot, ctx)
	applying_display_snapshot = false


## 客机结算页仍读单例 Game：把 ViewGame 的结算字段拷过去。权威端不覆盖 Game。
func commit_display_settlement_to_game() -> void:
	if is_authority():
		return
	var display: Node = get_display_game()
	if display == null or not is_instance_valid(display) or display == Game:
		return
	Game.log_list = display.log_list.duplicate()
	Game.players = display.players.duplicate()
	Game.current_mission = display.current_mission
	Game.game_over_called = bool(display.get("game_over_called"))
	Game.game_result = String(display.get("game_result"))
	var src_machine: Variant = display.state_machine
	var dst_machine: Variant = Game.state_machine
	if src_machine != null and dst_machine != null:
		dst_machine.current_state = src_machine.current_state
		dst_machine.game_result = src_machine.game_result
		dst_machine.last_player = src_machine.last_player
	var src_tracker: Variant = display.stats_tracker
	var dst_tracker: Variant = Game.stats_tracker
	if src_tracker != null and dst_tracker != null \
			and src_tracker.has_method("to_network_dict") \
			and dst_tracker.has_method("apply_network_snapshot"):
		dst_tracker.apply_network_snapshot(
			Game.players, src_tracker.to_network_dict(display.players))


func _enter_host_loopback() -> bool:
	if has_loopback_client():
		return true
	var port := int(registry.port)
	if port <= 0:
		port = NetProtocol.DEFAULT_PORT
	var client_peer := ENetMultiplayerPeer.new()
	var result := client_peer.create_client("127.0.0.1", port)
	if result != OK:
		if server_runtime != null and is_instance_valid(server_runtime):
			server_runtime.abort_owner_loopback_failed()
		return false
	_ensure_view_game()
	var tree := get_tree()
	var root: Node = tree.root if tree != null else self
	_loopback_root = root.get_node_or_null(LOOPBACK_ROOT_NAME)
	if _loopback_root == null:
		_loopback_root = Node.new()
		_loopback_root.name = LOOPBACK_ROOT_NAME
		root.add_child(_loopback_root)
	_client_api = MultiplayerAPI.create_default_interface()
	_client_api.multiplayer_peer = client_peer
	if tree != null:
		tree.set_multiplayer(_client_api, _loopback_root.get_path())
	_loopback_stub = LoopbackRpcScript.new()
	_loopback_stub.name = LOOPBACK_RPC_NAME
	_loopback_root.add_child(_loopback_stub)
	_client_api.connected_to_server.connect(_on_loopback_connected)
	_client_api.connection_failed.connect(_on_loopback_failed)
	_client_api.server_disconnected.connect(_on_loopback_disconnected)
	_awaiting_room_accept = true
	session_role = "client"
	connection_state_changed.emit("connecting", "正在连接房间")
	return true


func _teardown_loopback_client() -> void:
	if _client_api != null:
		if _client_api.connected_to_server.is_connected(_on_loopback_connected):
			_client_api.connected_to_server.disconnect(_on_loopback_connected)
		if _client_api.connection_failed.is_connected(_on_loopback_failed):
			_client_api.connection_failed.disconnect(_on_loopback_failed)
		if _client_api.server_disconnected.is_connected(_on_loopback_disconnected):
			_client_api.server_disconnected.disconnect(_on_loopback_disconnected)
		if _client_api.multiplayer_peer != null:
			_client_api.multiplayer_peer.close()
			_client_api.multiplayer_peer = null
	if is_inside_tree() and _loopback_root != null and is_instance_valid(_loopback_root):
		get_tree().set_multiplayer(null, _loopback_root.get_path())
	if _loopback_stub != null and is_instance_valid(_loopback_stub):
		_loopback_stub.queue_free()
	if _loopback_root != null and is_instance_valid(_loopback_root):
		_loopback_root.queue_free()
	_loopback_stub = null
	_loopback_root = null
	_client_api = null


func _on_loopback_connected() -> void:
	var peer_id := _loopback_peer_id()
	if peer_id <= 1:
		if server_runtime != null and is_instance_valid(server_runtime):
			server_runtime.abort_owner_loopback_failed()
		else:
			network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "本机环回未能取得客户端身份")
			close_session()
		return
	_finish_client_connected("已连接房间")


func _on_loopback_failed() -> void:
	if server_runtime != null and is_instance_valid(server_runtime):
		server_runtime.abort_owner_loopback_failed()
		return
	network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "本机环回连接失败")
	close_session()


func _on_loopback_disconnected() -> void:
	if is_authority():
		close_authority_room("owner_left")


func _is_loopback_peer(peer_id: int) -> bool:
	return _client_api != null and peer_id > 1 and _loopback_peer_id() == peer_id


func _loopback_peer_id() -> int:
	if _client_api == null:
		return 0
	return int(_client_api.get_unique_id())


func _peer_is_connected(peer: MultiplayerPeer) -> bool:
	return peer != null \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _client_transport_connected() -> bool:
	if _transport_connected_override != null:
		return bool(_transport_connected_override)
	if _client_api != null:
		return _peer_is_connected(_client_api.multiplayer_peer) and _loopback_peer_id() > 1
	if multiplayer == null:
		return false
	return _peer_is_connected(multiplayer.multiplayer_peer)


func _rpc_loopback_to_host(message: Dictionary) -> void:
	if _loopback_stub == null or not is_instance_valid(_loopback_stub):
		return
	if not _client_transport_connected():
		return
	_loopback_stub.rpc_id(1, "receive_message", message)


func send_room_command(command: String, payload: Dictionary = {}) -> void:
	_send_to_host(NetProtocol.ROOM_COMMAND, {
		"command": command,
		"payload": payload,
	})

func sync_room_config() -> void:
	if not is_authority():
		return
	var room_state := get_node_or_null("/root/RoomState")
	if room_state == null:
		return
	var mode := "random" if room_state.selected_mission_is_random else "fixed"
	var mission_id := -1 if room_state.selected_mission == null \
		else int(room_state.selected_mission.mission_id)
	registry.set_room_config(mode, mission_id, room_state.variants)
	_emit_snapshot()

func send_input_response(request_id: int, seat_id: int, value: Variant) -> void:
	_send_to_host(NetProtocol.INPUT_RESPONSE, {
		"seat_id": seat_id,
		"value": NetInputCodec.encode(value),
	}, request_id)

func request_resync() -> void:
	_send_to_host(NetProtocol.RESYNC_REQUEST)

func leave_room() -> void:
	if is_authority():
		close_authority_room("host_closed")
		return
	_send_to_host(NetProtocol.LEAVE_REQUEST, {
		"display_name": _pending_nickname,
	})
	if is_inside_tree():
		call_deferred("close_session")
	else:
		close_session()

func broadcast_game_event(event_name: String, payload: Dictionary) -> void:
	if not is_authority():
		return
	var sequence := registry.next_server_sequence()
	_broadcast(NetProtocol.GAME_EVENT, {
		"event_name": event_name,
		"payload": NetInputCodec.encode(payload),
	}, -1, sequence)

func broadcast_state_snapshot(_snapshot: Dictionary = {}) -> void:
	request_state_snapshot()


## 标记对局状态已变。真正的 STATE_SNAPSHOT 在本帧末尾最多发送一份，避免日志把演出堵住。
func request_state_snapshot() -> void:
	if not is_authority():
		return
	_state_snapshot_dirty = true


func has_pending_state_snapshot() -> bool:
	return _state_snapshot_dirty


func _flush_pending_state_snapshot() -> bool:
	if not is_authority() or not _state_snapshot_dirty:
		return false
	_state_snapshot_dirty = false
	var snapshot: Dictionary = GameStateSerializer.snapshot(Game)
	var sequence := registry.next_server_sequence()
	_broadcast(NetProtocol.STATE_SNAPSHOT, {
		"room_snapshot": registry.snapshot(),
		"game_snapshot": snapshot,
	}, -1, sequence)
	return true

func broadcast_input_request(request_id: int, seat_id: int, owner_id: String,
		request_type: String, payload: Dictionary) -> void:
	if not is_authority():
		return
	_flush_pending_state_snapshot()
	var owner: Dictionary = registry.players.get(owner_id, {})
	var peer_id := int(owner.get("peer_id", 0))
	if peer_id <= 0:
		if _is_owner_player(owner_id):
			_handoff_player_inputs(owner_id)
		else:
			_drop_remote_player(owner_id, false)
		return
	var message := NetProtocol.make_message(NetProtocol.INPUT_REQUEST, {
		"seat_id": seat_id,
		"owner_id": owner_id,
		"request_type": request_type,
		"payload": NetInputCodec.encode(payload),
	}, "", registry.match_id, 0, registry.server_sequence, request_id)
	_rpc_id_if_ready(peer_id, message)

func _send_to_host(message_type: String, payload: Dictionary = {}, request_id: int = -1) -> void:
	var message := NetProtocol.make_message(message_type, payload,
		local_player_id, registry.match_id, _next_client_sequence(), registry.server_sequence, request_id)
	if _client_api != null:
		if not _client_transport_connected():
			return
		_rpc_loopback_to_host(message)
		return
	if is_host:
		_handle_message(message, 1)
		return
	if not _client_transport_connected() or not is_inside_tree() or multiplayer == null:
		return
	rpc_id(1, "receive_message", message)

@rpc("any_peer", "reliable")
func receive_message(message: Dictionary) -> void:
	if NetProtocol.is_protocol_mismatch(message):
		_on_protocol_mismatch()
		return
	if not NetProtocol.is_valid_message(message):
		return
	if is_authority():
		var sender_id := _incoming_sender_id()
		if sender_id <= 0:
			return
		_handle_message(message, sender_id)
		return
	_apply_client_inbound_message(message)


func receive_loopback_client_message(message: Dictionary) -> void:
	if NetProtocol.is_protocol_mismatch(message):
		network_error.emit(NetProtocol.ERROR_PROTOCOL_MISMATCH, "协议版本不匹配")
		return
	if not NetProtocol.is_valid_message(message):
		return
	_apply_client_inbound_message(message)


func _apply_client_inbound_message(message: Dictionary) -> void:
	message_received.emit(message)
	var message_type := String(message.get("message_type", ""))
	var payload: Dictionary = message.get("payload", {})
	if message_type == NetProtocol.JOIN_ACCEPTED:
		_restore_client_identity(payload)
		_apply_snapshot(payload.get("room_snapshot", {}))
		session_changed.emit(payload.get("room_snapshot", {}))
		_finish_room_accept("已加入房间", payload)
	elif message_type == NetProtocol.ROOM_SNAPSHOT:
		_restore_client_identity(payload)
		_apply_snapshot(payload)
		session_changed.emit(payload)
		_finish_room_accept("已重连房间", payload)
	elif message_type == NetProtocol.STATE_SNAPSHOT:
		_restore_client_identity(payload)
		_apply_snapshot(payload.get("room_snapshot", payload))
		session_changed.emit(payload.get("room_snapshot", payload))
		if payload.has("game_snapshot"):
			_ensure_view_game()
		_finish_room_accept("已重连房间", payload)
	elif message_type == NetProtocol.MATCH_START:
		_apply_snapshot(payload.get("room_snapshot", {}))
		session_changed.emit(payload.get("room_snapshot", {}))
		_ensure_view_game()
		connection_state_changed.emit("match_started", "房主已开始对局")
	elif message_type == NetProtocol.ROOM_CLOSED:
		connection_state_changed.emit("closed", String(payload.get("reason", "房间已关闭")))
		close_session()
	elif message_type == NetProtocol.ERROR:
		var error_code := String(payload.get("code", NetProtocol.ERROR_INVALID_COMMAND))
		if error_code == NetProtocol.ERROR_INVALID_TOKEN \
				or error_code == NetProtocol.ERROR_TOKEN_EXPIRED:
			if _client_api != null:
				if server_runtime != null and is_instance_valid(server_runtime):
					server_runtime.abort_owner_loopback_failed()
				return
			if registry.phase == "playing" and not _awaiting_room_accept:
				return
			if _awaiting_room_accept and _client_transport_connected() \
					and not _pending_nickname.is_empty() and _hello_used_reconnect \
					and registry.phase != "playing":
				_hello_used_reconnect = false
				_clear_reconnect_identity()
				_send_join_hello()
				connection_state_changed.emit("connecting", "正在加入房间")
				return
			if _should_retry_hello_on_reject() and registry.phase == "playing":
				_schedule_hello_retry()
				return
			if not _client_transport_connected():
				_clear_reconnect_identity()
			if registry.phase == "playing":
				network_error.emit(error_code, "重连失败")
				return
			_clear_reconnect_identity()
			if _pending_nickname.is_empty():
				network_error.emit(error_code, String(payload.get("detail", "重连凭证已失效")))
				return
			_send_join_hello()
			connection_state_changed.emit("connecting", "重连凭证已失效，正在重新加入")
		else:
			if _client_api != null and (error_code == NetProtocol.ERROR_CONNECTION_REFUSED \
					or error_code == NetProtocol.ERROR_INVALID_TOKEN):
				if server_runtime != null and is_instance_valid(server_runtime):
					server_runtime.abort_owner_loopback_failed()
			if _should_retry_hello_on_reject():
				_schedule_hello_retry()
				return
			network_error.emit(error_code,
				String(payload.get("detail", "网络请求被拒绝")))


func _server_api() -> MultiplayerAPI:
	if is_inside_tree():
		var api: MultiplayerAPI = get_tree().get_multiplayer()
		if api != null:
			return api
	return multiplayer


func _incoming_sender_id() -> int:
	var sender_id := 0
	var api := _server_api()
	if api != null:
		sender_id = int(api.get_remote_sender_id())
	if sender_id <= 0 and multiplayer != null:
		sender_id = int(multiplayer.get_remote_sender_id())
	return sender_id if sender_id > 0 else 0


func _authority_sender_id() -> int:
	return _incoming_sender_id()


func _is_incoming_authority_rpc() -> bool:
	if not is_authority():
		return false
	return _incoming_sender_id() > 0

func _handle_message(message: Dictionary, sender_id: int) -> void:
	var player_id := _player_for_peer(sender_id)
	if player_id != "":
		registry.touch_last_seen(player_id)
	var message_type := String(message.get("message_type", ""))
	match message_type:
		NetProtocol.JOIN_REQUEST:
			_handle_join(message, sender_id)
		NetProtocol.RECONNECT_REQUEST:
			_handle_reconnect(message, sender_id)
		NetProtocol.ROOM_COMMAND:
			_handle_room_command(message, sender_id)
		NetProtocol.INPUT_RESPONSE:
			_handle_input_response(message, sender_id)
		NetProtocol.RESYNC_REQUEST:
			_send_snapshot_to(sender_id)
		NetProtocol.LEAVE_REQUEST:
			_handle_leave(message, sender_id)
		NetProtocol.HEARTBEAT:
			return
		_:
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "不支持的网络命令")

func _handle_join(message: Dictionary, sender_id: int) -> void:
	if not is_authority():
		_reject(sender_id, NetProtocol.ERROR_ROOM_ALREADY_STARTED, "房间已开始")
		return
	var payload: Dictionary = message.get("payload", {})
	_remember_peer_display_name(sender_id, String(payload.get("display_name", "")))
	if registry.phase == "playing":
		if _resume_playing_join(payload, sender_id):
			return
		_reject(sender_id, NetProtocol.ERROR_ROOM_ALREADY_STARTED,
			_playing_join_reject_detail(String(payload.get("display_name", ""))))
		return
	if registry.phase != "lobby":
		_reject(sender_id, NetProtocol.ERROR_ROOM_ALREADY_STARTED, "房间已开始")
		return
	var credentials := registry.add_player(String(payload.get("display_name", "")), sender_id)
	if credentials.is_empty():
		_reject(sender_id, NetProtocol.ERROR_ROOM_FULL, "房间已满")
		return
	var accept := NetProtocol.make_message(NetProtocol.JOIN_ACCEPTED, {
		"player_id": credentials.player_id,
		"reconnect_token": credentials.reconnect_token,
		"room_snapshot": registry.snapshot(),
	}, "", registry.match_id)
	_rpc_id_if_ready(sender_id, accept)
	_emit_snapshot()

func _resume_playing_join(payload: Dictionary, sender_id: int) -> bool:
	var resumed: Dictionary = _try_resume_player(
		String(payload.get("reconnect_token", "")),
		String(payload.get("display_name", "")),
		sender_id)
	if resumed.is_empty():
		return false
	_accept_reconnected_player(String(resumed.player_id),
		String(resumed.reconnect_token), sender_id)
	return true

func _handle_reconnect(message: Dictionary, sender_id: int) -> void:
	var payload: Dictionary = message.get("payload", {})
	_remember_peer_display_name(sender_id, String(payload.get("display_name", "")))
	var resumed: Dictionary = _try_resume_player(
		String(payload.get("reconnect_token", "")),
		String(payload.get("display_name", "")),
		sender_id)
	if resumed.is_empty():
		if registry.phase == "lobby":
			_handle_join(message, sender_id)
			return
		_reject(sender_id, NetProtocol.ERROR_INVALID_TOKEN, "重连凭证无效或已过期")
		return
	_accept_reconnected_player(String(resumed.player_id),
		String(resumed.reconnect_token), sender_id)


func _try_resume_player(token: String, display_name: String, sender_id: int) -> Dictionary:
	var token_player := ""
	if token != "":
		token_player = registry.player_id_for_token(token)
		if token_player != "" and not _guest_cannot_use_host_token(token_player, sender_id):
			var player_id := registry.reconnect_player_by_token(token, sender_id)
			if player_id != "":
				return {"player_id": player_id, "reconnect_token": token}
	var resumed: Dictionary = registry.reconnect_guest_by_unique_name(
		display_name, sender_id)
	if resumed.is_empty():
		return {}
	return {
		"player_id": String(resumed.get("player_id", "")),
		"reconnect_token": String(resumed.get("reconnect_token", "")),
	}


func _guest_cannot_use_host_token(player_id: String, sender_id: int) -> bool:
	if not _is_owner_player(player_id):
		return false
	var loopback := _loopback_peer_id()
	return loopback <= 1 or sender_id != loopback

func _accept_reconnected_player(player_id: String, token: String, sender_id: int) -> void:
	if has_active_server_runtime() and registry.phase == "playing":
		server_runtime.restore_network_inputs(player_id)
	_send_identity_snapshot(sender_id, player_id, token)
	if is_inside_tree():
		call_deferred("_retry_identity_snapshot", sender_id, player_id, token)
	_emit_player_presence(player_id, "connected", false)
	_broadcast(NetProtocol.PLAYER_RECONNECTED, _presence_payload(player_id, false))
	_emit_snapshot()

func _handle_room_command(message: Dictionary, sender_id: int) -> void:
	var player_id := _player_for_peer(sender_id)
	if player_id == "":
		_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "未知玩家")
		return
	var payload: Dictionary = message.get("payload", {})
	var command := String(payload.get("command", ""))
	var args: Dictionary = payload.get("payload", {})
	if command == "start":
		if not _is_owner_player(player_id) or registry.phase != "lobby":
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "只有房主可开始")
			return
		begin_online_match()
		return
	elif command == "bind_seat":
		if registry.phase != "lobby":
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "对局中不能改座位归属")
			return
		if not _is_owner_player(player_id):
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "只有房主可分配座位")
			return
		if not registry.bind_seat(int(args.get("seat_id", -1)),
				String(args.get("controller_id", "")),
				String(args.get("survivor_id", "")),
				bool(args.get("is_ai", false))):
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "座位配置无效")
			return
	elif command == "set_survivor":
		var seat_id := int(args.get("seat_id", -1))
		if registry.phase != "lobby":
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "对局中不能改角色")
			return
		if not _can_edit_seat_survivor(player_id, seat_id):
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "没有该座位的控制权")
			return
		var survivor_id := String(args.get("survivor_id", ""))
		var data_manager := get_node_or_null("/root/DataManager")
		if survivor_id != "" and (data_manager == null or not data_manager.has_survivor(survivor_id)):
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "角色不存在")
			return
		if not registry.set_seat_survivor(seat_id, survivor_id):
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "角色已被其他座位占用")
			return
	else:
		_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "未知房间命令")
		return
	_emit_snapshot()

func _handle_input_response(message: Dictionary, sender_id: int) -> void:
	var player_id := _player_for_peer(sender_id)
	var payload: Dictionary = message.get("payload", {})
	var seat_id := int(payload.get("seat_id", -1))
	if player_id == "" or not _owns_seat(player_id, seat_id):
		_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "没有该座位的控制权")
		return
	message_received.emit(message)


func _handle_leave(message: Dictionary, sender_id: int) -> void:
	var payload: Dictionary = message.get("payload", {})
	var display_name := String(payload.get("display_name", ""))
	_remember_peer_display_name(sender_id, display_name)
	var player_id := String(message.get("sender_player_id", ""))
	if player_id.is_empty():
		_drop_peer_or_named_guest(sender_id, display_name, true)
		return
	_peer_display_names.erase(sender_id)
	if bool(registry.players.get(player_id, {}).get("is_host", false)):
		close_authority_room("owner_left")
		return
	_drop_remote_player(player_id, true)


func _is_owner_player(player_id: String) -> bool:
	if player_id.is_empty():
		return false
	return bool(registry.players.get(player_id, {}).get("is_host", false))


func _can_edit_seat_survivor(player_id: String, seat_id: int) -> bool:
	if seat_id < 0 or seat_id >= registry.seats.size():
		return false
	if _is_owner_player(player_id):
		return true
	return String(registry.seats[seat_id].get("controller_id", "")) == player_id


func _handoff_player_inputs(player_id: String) -> void:
	if not has_active_server_runtime() or registry.phase != "playing":
		return
	server_runtime.handoff_seats_to_ai(player_id)


func _drop_remote_player(player_id: String, left: bool) -> void:
	if player_id.is_empty() or not registry.players.has(player_id):
		return
	if bool(registry.players[player_id].get("is_host", false)):
		return
	registry.disconnect_player(player_id)
	_handoff_player_inputs(player_id)
	_emit_player_presence(player_id, "disconnected", left)
	_broadcast(NetProtocol.PLAYER_DISCONNECTED, _presence_payload(player_id, left))
	_emit_snapshot()


func drop_stale_players(now_ms: int = -1) -> Array:
	if not is_authority() or registry.phase != "playing":
		return []
	var now := now_ms if now_ms >= 0 else Time.get_ticks_msec()
	var dropped: Array = []
	for player_id in registry.stale_connected_guest_ids(now, NetProtocol.HEARTBEAT_TIMEOUT_MS):
		_drop_remote_player(String(player_id), false)
		dropped.append(String(player_id))
	return dropped


func _tick_heartbeat() -> void:
	if session_role != "client":
		return
	if not _client_transport_connected():
		return
	var now := Time.get_ticks_msec()
	if _last_heartbeat_sent_ms > 0 \
			and now - _last_heartbeat_sent_ms < NetProtocol.HEARTBEAT_INTERVAL_MS:
		return
	_last_heartbeat_sent_ms = now
	_send_to_host(NetProtocol.HEARTBEAT)


func _reset_hello_retry() -> void:
	_hello_retry_at_ms = 0
	_hello_retry_delay_ms = 0
	_hello_retry_attempts = 0


func _schedule_hello_retry() -> void:
	if not _awaiting_room_accept:
		return
	if _hello_retry_delay_ms <= 0:
		_hello_retry_delay_ms = NetProtocol.HELLO_RETRY_INITIAL_MS
	else:
		_hello_retry_delay_ms = mini(_hello_retry_delay_ms * 2, NetProtocol.HELLO_RETRY_MAX_MS)
	_hello_retry_at_ms = Time.get_ticks_msec() + _hello_retry_delay_ms


func _tick_hello_retry() -> void:
	if session_role != "client" or is_room_owner():
		return
	if not _awaiting_room_accept or _hello_retry_at_ms <= 0:
		return
	if Time.get_ticks_msec() < _hello_retry_at_ms:
		return
	_hello_retry_at_ms = 0
	retry_room_hello()


func retry_room_hello() -> bool:
	if session_role != "client" or is_room_owner() or not _awaiting_room_accept:
		return false
	if _hello_retry_attempts >= NetProtocol.HELLO_RETRY_MAX_ATTEMPTS:
		network_error.emit(NetProtocol.ERROR_INVALID_TOKEN, "重连失败")
		return false
	_hello_retry_attempts += 1
	_send_client_hello()
	_schedule_hello_retry()
	return true


func can_retry_room_hello() -> bool:
	if session_role != "client" or is_room_owner():
		return false
	if not _awaiting_room_accept:
		return false
	return _hello_retry_attempts < NetProtocol.HELLO_RETRY_MAX_ATTEMPTS


func _should_retry_hello_on_reject() -> bool:
	return _awaiting_room_accept and _client_transport_connected()


func _presence_payload(player_id: String, left: bool) -> Dictionary:
	var payload := {
		"player_id": player_id,
		"display_name": String(registry.players.get(player_id, {}).get("display_name", "")),
	}
	if left:
		payload["left"] = true
	return payload


func _emit_player_presence(player_id: String, state: String, left: bool) -> void:
	var display_name := String(registry.players.get(player_id, {}).get("display_name", ""))
	player_presence_changed.emit(player_id, state, display_name, left)


func _identity_snapshot_message(player_id: String, token: String) -> Dictionary:
	var snapshot_message := _make_state_snapshot_message()
	var snap_payload: Dictionary = snapshot_message.get("payload", {}).duplicate(true)
	snap_payload["player_id"] = player_id
	snap_payload["reconnect_token"] = token
	snapshot_message["payload"] = snap_payload
	return snapshot_message


func _send_identity_snapshot(peer_id: int, player_id: String, token: String) -> void:
	_rpc_id_if_ready(peer_id, _identity_snapshot_message(player_id, token))


func _retry_identity_snapshot(peer_id: int, player_id: String, token: String) -> void:
	if _player_for_peer(peer_id) != player_id:
		return
	_send_identity_snapshot(peer_id, player_id, token)


func _has_rpc_peer(peer_id: int) -> bool:
	if multiplayer == null or peer_id <= 1:
		return false
	for id in multiplayer.get_peers():
		if int(id) == peer_id:
			return true
	return false


func _scan_heartbeat_timeouts() -> void:
	drop_stale_players()



func _on_protocol_mismatch() -> void:
	var sender_id := _incoming_sender_id()
	if is_authority() and sender_id > 0:
		_reject(sender_id, NetProtocol.ERROR_PROTOCOL_MISMATCH, "协议版本不匹配")
		return
	network_error.emit(NetProtocol.ERROR_PROTOCOL_MISMATCH, "协议版本不匹配")

func _player_for_peer(peer_id: int) -> String:
	for player in registry.players.values():
		if int(player.get("peer_id", 0)) == peer_id:
			return String(player.get("player_id", ""))
	return ""


func _remember_peer_display_name(peer_id: int, display_name: String) -> void:
	var normalized := NetProtocol.normalize_nickname(display_name)
	if peer_id <= 1 or normalized.is_empty():
		return
	_peer_display_names[peer_id] = normalized


func _named_guest_to_drop(display_name: String) -> String:
	return registry.guest_player_id_for_unique_name(display_name)


func _drop_peer_or_named_guest(peer_id: int, display_name: String, left: bool) -> void:
	var player_id := _player_for_peer(peer_id)
	if player_id.is_empty():
		player_id = _named_guest_to_drop(display_name)
		if player_id.is_empty():
			player_id = _named_guest_to_drop(String(_peer_display_names.get(peer_id, "")))
	_peer_display_names.erase(peer_id)
	if player_id.is_empty():
		return
	if bool(registry.players.get(player_id, {}).get("is_host", false)):
		close_authority_room("owner_left")
		return
	if registry.is_player_live_bound(player_id) and _player_for_peer(peer_id) != player_id:
		return
	_drop_remote_player(player_id, left)


func _playing_join_reject_detail(display_name: String) -> String:
	var normalized := NetProtocol.normalize_nickname(display_name)
	if normalized.is_empty():
		return "房间已开始"
	var match_count := 0
	for player_id in registry.players:
		var player: Dictionary = registry.players[player_id]
		if bool(player.get("is_host", false)):
			continue
		if String(player.get("display_name", "")) == normalized:
			match_count += 1
	if match_count > 1:
		return "房间已开始（同名玩家不唯一）"
	if match_count == 0:
		return "房间已开始（没有可认回的座位）"
	return "房间已开始"

func _owns_seat(player_id: String, seat_id: int) -> bool:
	if seat_id < 0 or seat_id >= registry.seats.size():
		return false
	return String(registry.seats[seat_id].get("controller_id", "")) == player_id

func _emit_snapshot() -> void:
	var snapshot := registry.snapshot()
	session_changed.emit(snapshot)
	_broadcast(NetProtocol.ROOM_SNAPSHOT, snapshot)

func _send_snapshot_to(peer_id: int) -> void:
	_rpc_id_if_ready(peer_id, _make_state_snapshot_message())


func playing_resync_payload() -> Dictionary:
	var payload := {"room_snapshot": registry.snapshot()}
	if registry.phase == "playing" and Game != null and is_instance_valid(Game) \
			and Game.players.size() > 0:
		payload["game_snapshot"] = GameStateSerializer.snapshot(Game)
	return payload


func _make_state_snapshot_message() -> Dictionary:
	if registry.phase != "playing":
		return NetProtocol.make_message(
			NetProtocol.ROOM_SNAPSHOT, registry.snapshot(), "", registry.match_id)
	var payload := playing_resync_payload()
	var sequence := 0
	if payload.has("game_snapshot"):
		sequence = registry.next_server_sequence()
	return NetProtocol.make_message(
		NetProtocol.STATE_SNAPSHOT, payload, "", registry.match_id, 0, sequence)

func _broadcast(message_type: String, payload: Dictionary = {}, request_id: int = -1,
		server_sequence: int = 0) -> void:
	var message := NetProtocol.make_message(message_type, payload, "", registry.match_id,
		0, server_sequence, request_id)
	_rpc_if_ready(message)

func _reject(peer_id: int, code: String, detail: String) -> void:
	var message := NetProtocol.make_message(
		NetProtocol.ERROR, {"code": code, "detail": detail})
	_rpc_id_if_ready(peer_id, message)


func _rpc_if_ready(message: Dictionary) -> void:
	if not is_inside_tree() or multiplayer == null \
			or not _peer_is_connected(multiplayer.multiplayer_peer):
		return
	for peer_id in multiplayer.get_peers():
		rpc_id(int(peer_id), "receive_message", message)


func _rpc_id_if_ready(peer_id: int, message: Dictionary) -> void:
	if peer_id <= 1 or not is_inside_tree() or multiplayer == null \
			or not _peer_is_connected(multiplayer.multiplayer_peer):
		return
	rpc_id(peer_id, "receive_message", message)

func _payload_identity_fields(payload: Dictionary) -> Dictionary:
	var player_id := String(payload.get("player_id", ""))
	var token := String(payload.get("reconnect_token", ""))
	var nested: Variant = payload.get("room_snapshot", {})
	if player_id.is_empty() and nested is Dictionary:
		player_id = String(nested.get("player_id", ""))
	if token.is_empty() and nested is Dictionary:
		token = String(nested.get("reconnect_token", ""))
	return {"player_id": player_id, "reconnect_token": token}


func _restore_client_identity(payload: Dictionary) -> void:
	var identity := _payload_identity_fields(payload)
	var player_id := String(identity.get("player_id", ""))
	var token := String(identity.get("reconnect_token", ""))
	if player_id.is_empty() and token.is_empty():
		return
	if player_id != "":
		local_player_id = player_id
	if token != "":
		local_reconnect_token = token
	if local_player_id != "" and local_reconnect_token != "":
		_save_identity()


func _payload_confirms_accept(payload: Dictionary) -> bool:
	var identity := _payload_identity_fields(payload)
	return String(identity.get("player_id", "")) != "" \
		or String(identity.get("reconnect_token", "")) != ""


func _registry_confirms_local_seat() -> bool:
	if local_player_id.is_empty() or not registry.players.has(local_player_id):
		return false
	if String(registry.players[local_player_id].get("connection_state", "")) != "connected":
		return false
	for seat in registry.seats:
		if String(seat.get("controller_id", "")) == local_player_id \
				and String(seat.get("control_mode", "")) == "human":
			return true
	return false


func _finish_room_accept(detail: String, payload: Dictionary = {}) -> void:
	if not _awaiting_room_accept or local_player_id == "":
		return
	if not _payload_confirms_accept(payload) and not _registry_confirms_local_seat():
		return
	_awaiting_room_accept = false
	_reset_hello_retry()
	connection_state_changed.emit("joined", detail)


func _apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if is_authority():
		return
	registry.room_id = String(snapshot.get("room_id", ""))
	registry.host_name = String(snapshot.get("host_name", ""))
	registry.port = int(snapshot.get("port", NetProtocol.DEFAULT_PORT))
	registry.online_multiplayer = bool(snapshot.get("online_multiplayer", false))
	registry.phase = String(snapshot.get("phase", "closed"))
	registry.match_id = String(snapshot.get("match_id", ""))
	if snapshot.has("match_seed"):
		registry.match_seed = int(snapshot.get("match_seed", 0))
	registry.settings_revision = int(snapshot.get("settings_revision", 0))
	var mission_config: Dictionary = snapshot.get("mission", {})
	registry.mission_mode = String(mission_config.get("mode", "random"))
	registry.mission_id = int(mission_config.get("mission_id", -1))
	registry.variants = snapshot.get("variants", {}).duplicate(true)
	registry.players.clear()
	for player in snapshot.get("players", []):
		if player is Dictionary:
			registry.players[String(player.get("player_id", ""))] = player
	registry.seats = snapshot.get("seats", []).duplicate(true)
	if not is_inside_tree():
		return
	var room_state := get_node_or_null("/root/RoomState")
	if room_state != null:
		room_state.online_multiplayer = bool(snapshot.get("online_multiplayer", false))
		room_state.selected_mission_is_random = registry.mission_mode == "random"
		room_state.selected_mission = null
		if not room_state.selected_mission_is_random:
			var data_manager_for_mission := get_node_or_null("/root/DataManager")
			if data_manager_for_mission != null:
				room_state.selected_mission = data_manager_for_mission.get_mission(registry.mission_id)
		for variant_id in room_state.variants:
			room_state.variants[variant_id] = bool(registry.variants.get(variant_id, false))
		var mirrored_seats: Array = []
		var data_manager := get_node_or_null("/root/DataManager")
		for seat in registry.seats:
			var survivor_id := String(seat.get("survivor_id", ""))
			var survivor = data_manager.get_survivor(survivor_id) \
				if survivor_id != "" and data_manager != null else null
			var control_mode := String(seat.get("control_mode", "ai"))
			mirrored_seats.append({
				"type": "human" if control_mode == "human" else "ai",
				"survivor": survivor,
			})
		if not mirrored_seats.is_empty():
			room_state.seats = mirrored_seats

func _on_peer_connected(peer_id: int) -> void:
	if session_role == "host" or has_listen_server():
		connection_state_changed.emit("peer_connected", str(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	if session_role == "host" or has_listen_server():
		# 延后处理，避免在 ENet 遍历 peer 时改房间状态；按 peer_id 查找，
		# 这样客机已经用新 peer 重连时不会误踢。
		call_deferred("_complete_host_peer_disconnected", peer_id)
		return
	if peer_id != 1:
		return
	_queue_client_disconnect("disconnected")

func _complete_host_peer_disconnected(peer_id: int) -> void:
	if session_role != "host" and not has_listen_server():
		return
	var remembered := String(_peer_display_names.get(peer_id, ""))
	_drop_peer_or_named_guest(peer_id, remembered, false)

func _on_connected_to_server() -> void:
	_finish_client_connected("已连接房间")


func _finish_client_connected(detail: String) -> void:
	connection_state_changed.emit("connected", detail)
	_hello_retry_attempts = 0
	_hello_retry_delay_ms = 0
	_send_client_hello()
	_schedule_hello_retry()


func _send_client_hello() -> void:
	var token := _hello_reconnect_token()
	if token != "":
		_hello_used_reconnect = true
		_send_to_host(NetProtocol.RECONNECT_REQUEST, {
			"reconnect_token": token,
			"display_name": _pending_nickname,
		})
	else:
		_hello_used_reconnect = false
		_send_join_hello()


func _send_join_hello() -> void:
	var payload := {"display_name": _pending_nickname}
	var token := _hello_reconnect_token()
	if token != "":
		payload["reconnect_token"] = token
	_send_to_host(NetProtocol.JOIN_REQUEST, payload)


func _on_connection_failed() -> void:
	_queue_client_disconnect("failed")


func _on_server_disconnected() -> void:
	_queue_client_disconnect("disconnected")


func _queue_client_disconnect(reason: String) -> void:
	if _closing or _handling_client_disconnect:
		return
	if session_role != "client" or is_room_owner():
		return
	call_deferred("_complete_client_disconnect", reason, _peer_serial)


func _can_resume_client_session() -> bool:
	return registry.phase == "playing" and _hello_reconnect_token() != ""


func _complete_client_disconnect(reason: String, serial: int) -> void:
	if serial != _peer_serial or _closing or _handling_client_disconnect:
		return
	if session_role != "client" or is_room_owner():
		return
	_handling_client_disconnect = true
	var can_resume := _can_resume_client_session()
	_teardown_client_peer()
	_invalidate_peer_callbacks()
	if reason == "failed":
		network_error.emit(NetProtocol.ERROR_CONNECT_TIMEOUT, "连接房间超时")
	if can_resume:
		connection_state_changed.emit("disconnected", "与房主的连接已断开")
		_handling_client_disconnect = false
		return
	if reason != "failed":
		network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "房主已关闭房间")
	_handling_client_disconnect = false
	close_session()

func _next_client_sequence() -> int:
	_client_sequence += 1
	return _client_sequence

func _load_saved_identity() -> void:
	_saved_identity = _read_normalized_identity_file()

func _save_identity() -> void:
	var slot := _identity_slot()
	var on_disk := _empty_identity_slots()
	if is_inside_tree():
		on_disk = _read_normalized_identity_file()
	var memory := _normalize_identity(_saved_identity)
	var other := NetProtocol.IDENTITY_SLOT_GUEST if slot == NetProtocol.IDENTITY_SLOT_HOST \
			else NetProtocol.IDENTITY_SLOT_HOST
	var merged := _empty_identity_slots()
	merged[other] = _identity_slot_dict(on_disk, other)
	if _identity_slot_dict(merged, other).is_empty():
		merged[other] = _identity_slot_dict(memory, other)
	merged[slot] = {
		"player_id": local_player_id,
		"reconnect_token": local_reconnect_token,
	}
	_saved_identity = merged
	if is_inside_tree():
		_write_identity_file()

func _clear_reconnect_identity() -> void:
	local_reconnect_token = ""
	var slot := _identity_slot()
	_saved_identity = _normalize_identity(_saved_identity)
	_saved_identity[slot] = {}
	if is_inside_tree():
		_write_identity_file()


func _identity_slot() -> String:
	if is_host or session_role == "host":
		return NetProtocol.IDENTITY_SLOT_HOST
	return NetProtocol.IDENTITY_SLOT_GUEST


func _hello_identity_slot() -> String:
	if session_role == "client" and not is_host:
		return NetProtocol.IDENTITY_SLOT_GUEST
	return _identity_slot()


func _empty_identity_slots() -> Dictionary:
	return {
		NetProtocol.IDENTITY_SLOT_HOST: {},
		NetProtocol.IDENTITY_SLOT_GUEST: {},
	}


func _normalize_identity(raw: Variant) -> Dictionary:
	var slots := _empty_identity_slots()
	if not raw is Dictionary:
		return slots
	var data: Dictionary = raw
	if data.has(NetProtocol.IDENTITY_SLOT_HOST) or data.has(NetProtocol.IDENTITY_SLOT_GUEST):
		slots[NetProtocol.IDENTITY_SLOT_HOST] = _copy_identity_slot(
			data.get(NetProtocol.IDENTITY_SLOT_HOST, {}))
		slots[NetProtocol.IDENTITY_SLOT_GUEST] = _copy_identity_slot(
			data.get(NetProtocol.IDENTITY_SLOT_GUEST, {}))
		return slots
	if data.has("player_id") or data.has("reconnect_token"):
		slots[NetProtocol.IDENTITY_SLOT_GUEST] = _copy_identity_slot(data)
	return slots


func _copy_identity_slot(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var row: Dictionary = value
	var player_id := String(row.get("player_id", ""))
	var token := String(row.get("reconnect_token", ""))
	if player_id.is_empty() and token.is_empty():
		return {}
	return {
		"player_id": player_id,
		"reconnect_token": token,
	}


func _identity_slot_dict(data: Dictionary, slot: String) -> Dictionary:
	var normalized := _normalize_identity(data)
	var nested: Variant = normalized.get(slot, {})
	if nested is Dictionary:
		return nested.duplicate(true)
	return {}


func _read_normalized_identity_file() -> Dictionary:
	_migrate_legacy_identity_file()
	var slots := _empty_identity_slots()
	slots[NetProtocol.IDENTITY_SLOT_HOST] = _read_identity_slot_file(
		NetProtocol.IDENTITY_FILE_PATH_HOST)
	slots[NetProtocol.IDENTITY_SLOT_GUEST] = _read_identity_slot_file(
		NetProtocol.IDENTITY_FILE_PATH_GUEST)
	return slots


func _read_identity_slot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return _copy_identity_slot(parsed)


func _write_identity_file() -> void:
	_write_identity_slot_data(_identity_slot(),
		_identity_slot_dict(_saved_identity, _identity_slot()))


func _write_identity_slot_data(slot: String, row: Dictionary) -> void:
	var path := NetProtocol.identity_file_path_for_slot(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_copy_identity_slot(row)))
	file.close()


func _migrate_legacy_identity_file() -> void:
	if not FileAccess.file_exists(NetProtocol.IDENTITY_FILE_PATH):
		return
	var file := FileAccess.open(NetProtocol.IDENTITY_FILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var legacy := _normalize_identity(parsed)
	if not FileAccess.file_exists(NetProtocol.IDENTITY_FILE_PATH_HOST):
		_write_identity_slot_data(NetProtocol.IDENTITY_SLOT_HOST,
			_identity_slot_dict(legacy, NetProtocol.IDENTITY_SLOT_HOST))
	if not FileAccess.file_exists(NetProtocol.IDENTITY_FILE_PATH_GUEST):
		_write_identity_slot_data(NetProtocol.IDENTITY_SLOT_GUEST,
			_identity_slot_dict(legacy, NetProtocol.IDENTITY_SLOT_GUEST))
	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		user_dir.remove("net_identity.json")
