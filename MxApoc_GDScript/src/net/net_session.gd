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

var registry = NetRegistry.new()
var is_host: bool = false
var session_role: String = "none" # none/host/client
var local_player_id: String = ""
var local_reconnect_token: String = ""
var _client_sequence: int = 0
var _connected_address: String = ""
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


func is_authority() -> bool:
	return has_active_server_runtime() or has_listen_server() \
		or (is_host and session_role == "host")


func has_listen_server() -> bool:
	var api := _server_api()
	if api == null or api.multiplayer_peer == null:
		return false
	return api.is_server()


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
	if not is_authority():
		return
	_flush_pending_state_snapshot()

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
	close_session()
	var parsed := NetProtocol.parse_address(address)
	if not bool(parsed.get("ok", false)):
		network_error.emit(String(parsed.get("error", NetProtocol.ERROR_INVALID_ADDRESS)), "地址格式无效")
		return false
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(String(parsed.host), int(parsed.port))
	if result != OK:
		network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "无法创建客户端连接")
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	session_role = "client"
	_pending_nickname = NetProtocol.normalize_nickname(nickname)
	_connected_address = "%s:%d" % [String(parsed.host), int(parsed.port)]
	_awaiting_room_accept = true
	connection_state_changed.emit("connecting", "正在连接房间")
	return true

func close_session() -> void:
	if _closing:
		return
	_closing = true
	stop_server_runtime()
	_teardown_loopback_client()
	_clear_view_game()
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	session_role = "none"
	local_player_id = ""
	local_reconnect_token = ""
	_pending_nickname = ""
	_connected_address = ""
	_awaiting_room_accept = false
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
	return Game


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
	if get_tree() != null and _loopback_root != null and is_instance_valid(_loopback_root):
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


func _rpc_loopback_to_host(message: Dictionary) -> void:
	if _loopback_stub == null or not is_instance_valid(_loopback_stub):
		network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "本机环回尚未就绪")
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
	_send_to_host(NetProtocol.LEAVE_REQUEST)
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
	var owner: Dictionary = registry.players.get(owner_id, {})
	var peer_id := int(owner.get("peer_id", 0))
	if peer_id <= 0:
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
		var peer_id := _loopback_peer_id()
		if peer_id <= 1:
			network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "本机环回尚未就绪")
			return
		_rpc_loopback_to_host(message)
		return
	if is_host:
		_handle_message(message, 1)
		return
	if multiplayer.multiplayer_peer == null:
		network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "当前未连接房间")
		return
	rpc_id(1, "receive_message", message)

@rpc("any_peer", "reliable")
func receive_message(message: Dictionary) -> void:
	if NetProtocol.is_protocol_mismatch(message):
		_on_protocol_mismatch()
		return
	if not NetProtocol.is_valid_message(message):
		return
	if _is_incoming_authority_rpc():
		_handle_message(message, _authority_sender_id())
		return
	if is_authority():
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
		_finish_room_accept("已加入房间")
	elif message_type == NetProtocol.ROOM_SNAPSHOT:
		_restore_client_identity(payload)
		_apply_snapshot(payload)
		session_changed.emit(payload)
		_finish_room_accept("已重连房间")
	elif message_type == NetProtocol.STATE_SNAPSHOT:
		_restore_client_identity(payload)
		_apply_snapshot(payload.get("room_snapshot", payload))
		session_changed.emit(payload.get("room_snapshot", payload))
		if payload.has("game_snapshot"):
			_ensure_view_game()
		_finish_room_accept("已重连房间")
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
			_saved_identity.clear()
			_delete_saved_identity()
			if _client_api != null:
				if server_runtime != null and is_instance_valid(server_runtime):
					server_runtime.abort_owner_loopback_failed()
				return
			rpc_id(1, "receive_message", NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
				"display_name": _pending_nickname,
			}))
			connection_state_changed.emit("connecting", "重连凭证已失效，正在重新加入")
		else:
			if _client_api != null and (error_code == NetProtocol.ERROR_CONNECTION_REFUSED \
					or error_code == NetProtocol.ERROR_INVALID_TOKEN):
				if server_runtime != null and is_instance_valid(server_runtime):
					server_runtime.abort_owner_loopback_failed()
			network_error.emit(error_code,
				String(payload.get("detail", "网络请求被拒绝")))


func _server_api() -> MultiplayerAPI:
	if is_inside_tree():
		var api: MultiplayerAPI = get_tree().get_multiplayer()
		if api != null:
			return api
	return multiplayer


func _authority_sender_id() -> int:
	var sender_id := 0
	var api := _server_api()
	if api != null:
		sender_id = int(api.get_remote_sender_id())
	if sender_id == 0 and multiplayer != null:
		sender_id = int(multiplayer.get_remote_sender_id())
	return sender_id if sender_id > 0 else 1


func _is_incoming_authority_rpc() -> bool:
	if not is_authority():
		return false
	var tree_sender := 0
	var api := _server_api()
	if api != null:
		tree_sender = int(api.get_remote_sender_id())
	if is_host:
		return tree_sender > 0 or (multiplayer != null and multiplayer.get_remote_sender_id() > 0)
	return tree_sender > 1

func _handle_message(message: Dictionary, sender_id: int) -> void:
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
		_:
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "不支持的网络命令")

func _handle_join(message: Dictionary, sender_id: int) -> void:
	if not is_authority() or registry.phase != "lobby":
		_reject(sender_id, NetProtocol.ERROR_ROOM_ALREADY_STARTED, "房间已开始")
		return
	var payload: Dictionary = message.get("payload", {})
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

func _handle_reconnect(message: Dictionary, sender_id: int) -> void:
	var payload: Dictionary = message.get("payload", {})
	var token := String(payload.get("reconnect_token", ""))
	var error_code := registry.reconnect_error_for_token(token)
	if error_code != "":
		var detail := "重连凭证已过期" if error_code == NetProtocol.ERROR_TOKEN_EXPIRED \
			else "重连凭证无效或已过期"
		_reject(sender_id, error_code, detail)
		return
	var player_id := registry.reconnect_player_by_token(token, sender_id)
	if player_id.is_empty():
		_reject(sender_id, NetProtocol.ERROR_INVALID_TOKEN, "重连凭证无效或已过期")
		return
	if has_active_server_runtime() and registry.phase == "playing":
		server_runtime.restore_network_inputs(player_id)
	var snapshot_message := _make_state_snapshot_message()
	var snap_payload: Dictionary = snapshot_message.get("payload", {}).duplicate(true)
	snap_payload["player_id"] = player_id
	snap_payload["reconnect_token"] = token
	snapshot_message["payload"] = snap_payload
	_rpc_id_if_ready(sender_id, snapshot_message)
	_broadcast(NetProtocol.PLAYER_RECONNECTED, {"player_id": player_id})
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
	var player_id := String(message.get("sender_player_id", ""))
	if player_id.is_empty():
		player_id = _player_for_peer(sender_id)
	if player_id.is_empty():
		return
	if bool(registry.players.get(player_id, {}).get("is_host", false)):
		close_authority_room("owner_left")
		return
	registry.disconnect_player(player_id)
	_handoff_player_inputs(player_id)
	_broadcast(NetProtocol.PLAYER_DISCONNECTED, {"player_id": player_id, "left": true})
	_emit_snapshot()


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


func _on_protocol_mismatch() -> void:
	if _is_incoming_authority_rpc():
		_reject(_authority_sender_id(), NetProtocol.ERROR_PROTOCOL_MISMATCH, "协议版本不匹配")
		return
	network_error.emit(NetProtocol.ERROR_PROTOCOL_MISMATCH, "协议版本不匹配")

func _player_for_peer(peer_id: int) -> String:
	for player in registry.players.values():
		if int(player.get("peer_id", 0)) == peer_id:
			return String(player.get("player_id", ""))
	return ""

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
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	for peer_id in multiplayer.get_peers():
		rpc_id(int(peer_id), "receive_message", message)


func _rpc_id_if_ready(peer_id: int, message: Dictionary) -> void:
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	rpc_id(peer_id, "receive_message", message)

func _restore_client_identity(payload: Dictionary) -> void:
	var player_id := String(payload.get("player_id", ""))
	var nested: Variant = payload.get("room_snapshot", {})
	if player_id.is_empty() and nested is Dictionary:
		player_id = String(nested.get("player_id", ""))
	if player_id.is_empty():
		player_id = String(_saved_identity.get("player_id", ""))
	if player_id != "":
		local_player_id = player_id
	var token := String(payload.get("reconnect_token", ""))
	if token.is_empty() and nested is Dictionary:
		token = String(nested.get("reconnect_token", ""))
	if token.is_empty():
		token = String(_saved_identity.get("reconnect_token", ""))
	if token != "":
		local_reconnect_token = token
	if local_player_id != "" and local_reconnect_token != "" and is_inside_tree():
		_save_identity()


func _finish_room_accept(detail: String) -> void:
	if not _awaiting_room_accept or local_player_id == "":
		return
	_awaiting_room_accept = false
	connection_state_changed.emit("joined", detail)


func _apply_snapshot(snapshot: Dictionary) -> void:
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
	if is_authority():
		connection_state_changed.emit("peer_connected", str(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	if is_authority():
		var player_id := _player_for_peer(peer_id)
		if player_id == "":
			return
		if bool(registry.players.get(player_id, {}).get("is_host", false)):
			close_authority_room("owner_left")
			return
		registry.disconnect_player(player_id)
		_handoff_player_inputs(player_id)
		_broadcast(NetProtocol.PLAYER_DISCONNECTED, {"player_id": player_id})
		_emit_snapshot()
		return
	connection_state_changed.emit("disconnected", "与房主的连接已断开")

func _on_connected_to_server() -> void:
	_finish_client_connected("已连接房间")


func _finish_client_connected(detail: String) -> void:
	connection_state_changed.emit("connected", detail)
	_send_client_hello()


func _send_client_hello() -> void:
	var token := local_reconnect_token
	if token.is_empty():
		token = String(_saved_identity.get("reconnect_token", ""))
	if token != "":
		_send_to_host(NetProtocol.RECONNECT_REQUEST, {"reconnect_token": token})
	else:
		_send_to_host(NetProtocol.JOIN_REQUEST, {"display_name": _pending_nickname})

func _on_connection_failed() -> void:
	network_error.emit(NetProtocol.ERROR_CONNECT_TIMEOUT, "连接房间超时")
	close_session()

func _on_server_disconnected() -> void:
	network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "房主已关闭房间")
	close_session()

func _next_client_sequence() -> int:
	_client_sequence += 1
	return _client_sequence

func _load_saved_identity() -> void:
	if not FileAccess.file_exists("user://net_identity.json"):
		return
	var file := FileAccess.open("user://net_identity.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_saved_identity = parsed

func _save_identity() -> void:
	_saved_identity = {
		"player_id": local_player_id,
		"reconnect_token": local_reconnect_token,
	}
	var file := FileAccess.open("user://net_identity.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_saved_identity))
		file.close()

func _delete_saved_identity() -> void:
	if FileAccess.file_exists("user://net_identity.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://net_identity.json"))
