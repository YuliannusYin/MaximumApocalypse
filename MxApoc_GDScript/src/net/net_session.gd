extends Node

## 房主权威网络会话。所有业务数据通过 receive_message() 进入同一校验入口。
const NetProtocol = preload("res://src/net/net_protocol.gd")
const NetRegistry = preload("res://src/net/net_registry.gd")
const NetInputCodec = preload("res://src/net/net_input_codec.gd")

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

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_load_saved_identity()

func _process(_delta: float) -> void:
	if not is_host:
		return
	var expired: Array = registry.expire_disconnected()
	if expired.is_empty():
		return
	for player_id in expired:
		_broadcast(NetProtocol.PLAYER_DISCONNECTED, {
			"player_id": player_id,
			"expired": true,
		})
	_emit_snapshot()

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
	connection_state_changed.emit("host", "房间已创建")
	_emit_snapshot()
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
	connection_state_changed.emit("connecting", "正在连接房间")
	return true

func close_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	session_role = "none"
	local_player_id = ""
	local_reconnect_token = ""
	_pending_nickname = ""
	_connected_address = ""
	registry = NetRegistry.new()
	connection_state_changed.emit("closed", "")

func send_room_command(command: String, payload: Dictionary = {}) -> void:
	_send_to_host(NetProtocol.ROOM_COMMAND, {
		"command": command,
		"payload": payload,
	})

func sync_room_config() -> void:
	if not is_host:
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
	if is_host:
		_broadcast(NetProtocol.ROOM_CLOSED, {"reason": "host_closed"})
	close_session()

func broadcast_game_event(event_name: String, payload: Dictionary) -> void:
	if not is_host:
		return
	var sequence := registry.next_server_sequence()
	_broadcast(NetProtocol.GAME_EVENT, {
		"event_name": event_name,
		"payload": NetInputCodec.encode(payload),
	}, -1, sequence)

func broadcast_state_snapshot(snapshot: Dictionary) -> void:
	if not is_host:
		return
	var sequence := registry.next_server_sequence()
	_broadcast(NetProtocol.STATE_SNAPSHOT, {
		"room_snapshot": registry.snapshot(),
		"game_snapshot": snapshot,
	}, -1, sequence)

func broadcast_input_request(request_id: int, seat_id: int, owner_id: String,
		request_type: String, payload: Dictionary) -> void:
	if not is_host:
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
	rpc_id(peer_id, "receive_message", message)

func _send_to_host(message_type: String, payload: Dictionary = {}, request_id: int = -1) -> void:
	if is_host:
		_handle_message(NetProtocol.make_message(message_type, payload,
			local_player_id, registry.match_id, _next_client_sequence(), registry.server_sequence, request_id), 1)
		return
	if multiplayer.multiplayer_peer == null:
		network_error.emit(NetProtocol.ERROR_CONNECTION_REFUSED, "当前未连接房间")
		return
	var message := NetProtocol.make_message(message_type, payload,
		local_player_id, registry.match_id, _next_client_sequence(), registry.server_sequence, request_id)
	rpc_id(1, "receive_message", message)

@rpc("any_peer", "reliable")
func receive_message(message: Dictionary) -> void:
	if not NetProtocol.is_valid_message(message):
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if is_host:
		_handle_message(message, sender_id)
	else:
		message_received.emit(message)
		var message_type := String(message.get("message_type", ""))
		var payload: Dictionary = message.get("payload", {})
		if message_type == NetProtocol.JOIN_ACCEPTED:
			local_player_id = String(payload.get("player_id", ""))
			local_reconnect_token = String(payload.get("reconnect_token", ""))
			_save_identity()
			_apply_snapshot(payload.get("room_snapshot", {}))
			session_changed.emit(payload.get("room_snapshot", {}))
			connection_state_changed.emit("joined", "已加入房间")
		elif message_type == NetProtocol.ROOM_SNAPSHOT:
			_apply_snapshot(payload)
			session_changed.emit(payload)
		elif message_type == NetProtocol.STATE_SNAPSHOT:
			_apply_snapshot(payload.get("room_snapshot", payload))
			session_changed.emit(payload.get("room_snapshot", payload))
			if local_player_id != "":
				connection_state_changed.emit("joined", "已重连房间")
		elif message_type == NetProtocol.MATCH_START:
			_apply_snapshot(payload.get("room_snapshot", {}))
			session_changed.emit(payload.get("room_snapshot", {}))
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
				rpc_id(1, "receive_message", NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
					"display_name": _pending_nickname,
				}))
				connection_state_changed.emit("connecting", "重连凭证已失效，正在重新加入")
			else:
				network_error.emit(error_code,
					String(payload.get("detail", "网络请求被拒绝")))

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
			_handle_leave(message)
		_:
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "不支持的网络命令")

func _handle_join(message: Dictionary, sender_id: int) -> void:
	if not is_host or registry.phase != "lobby":
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
	rpc_id(sender_id, "receive_message", accept)
	_emit_snapshot()

func _handle_reconnect(message: Dictionary, sender_id: int) -> void:
	var payload: Dictionary = message.get("payload", {})
	var token := String(payload.get("reconnect_token", ""))
	var player_id := registry.reconnect_player_by_token(token, sender_id)
	if player_id.is_empty():
		_reject(sender_id, NetProtocol.ERROR_INVALID_TOKEN, "重连凭证无效或已过期")
		return
	rpc_id(sender_id, "receive_message", NetProtocol.make_message(
		NetProtocol.STATE_SNAPSHOT, {"room_snapshot": registry.snapshot()}, "", registry.match_id))
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
		if sender_id != 1 or not registry.phase == "lobby":
			_reject(sender_id, NetProtocol.ERROR_INVALID_COMMAND, "只有房主可开始")
			return
		registry.start_match()
		_broadcast(NetProtocol.MATCH_START, {
			"match_id": registry.match_id,
			"match_seed": registry.match_seed,
			"room_snapshot": registry.snapshot(),
		})
	elif command == "bind_seat":
		if sender_id != 1:
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
		if seat_id < 0 or seat_id >= registry.seats.size() \
				or String(registry.seats[seat_id].get("controller_id", "")) != player_id:
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


func _handle_leave(message: Dictionary) -> void:
	var player_id := String(message.get("sender_player_id", ""))
	if player_id != "":
		registry.disconnect_player(player_id)
		_emit_snapshot()

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
	rpc_id(peer_id, "receive_message", NetProtocol.make_message(
		NetProtocol.ROOM_SNAPSHOT, registry.snapshot(), "", registry.match_id))

func _broadcast(message_type: String, payload: Dictionary = {}, request_id: int = -1,
		server_sequence: int = 0) -> void:
	var message := NetProtocol.make_message(message_type, payload, "", registry.match_id,
		0, server_sequence, request_id)
	rpc("receive_message", message)

func _reject(peer_id: int, code: String, detail: String) -> void:
	rpc_id(peer_id, "receive_message", NetProtocol.make_message(
		NetProtocol.ERROR, {"code": code, "detail": detail}))

func _apply_snapshot(snapshot: Dictionary) -> void:
	registry.room_id = String(snapshot.get("room_id", ""))
	registry.host_name = String(snapshot.get("host_name", ""))
	registry.port = int(snapshot.get("port", NetProtocol.DEFAULT_PORT))
	registry.online_multiplayer = bool(snapshot.get("online_multiplayer", false))
	registry.phase = String(snapshot.get("phase", "closed"))
	registry.match_id = String(snapshot.get("match_id", ""))
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
	if is_host:
		connection_state_changed.emit("peer_connected", str(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	if is_host:
		var player_id := _player_for_peer(peer_id)
		if player_id != "":
			registry.disconnect_player(player_id)
			_broadcast(NetProtocol.PLAYER_DISCONNECTED, {"player_id": player_id})
			_emit_snapshot()
	else:
		connection_state_changed.emit("disconnected", "与房主的连接已断开")

func _on_connected_to_server() -> void:
	connection_state_changed.emit("connected", "已连接房间")
	if String(_saved_identity.get("reconnect_token", "")) != "":
		rpc_id(1, "receive_message", NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
			"reconnect_token": _saved_identity.reconnect_token,
		}))
	else:
		rpc_id(1, "receive_message", NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
			"display_name": _pending_nickname,
		}))

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
