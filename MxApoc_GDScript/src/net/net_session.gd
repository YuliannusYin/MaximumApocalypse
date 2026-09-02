extends Node

## 网络会话单例：基于 Godot 内置 Multiplayer（SceneMultiplayer + ENetMultiplayerPeer）。
## 主机权威模式：主机运行完整模拟，客机仅渲染并转发操作（RPC）。
## 客机通过 `create_client(ip, port)` 输入主机 IP 与端口即可连接。
## 心跳：每 5 秒双向发送 HEARTBEAT；超过 30 秒未收到任何数据判定连接超时。

enum Mode { NONE, HOST, CLIENT }

signal host_started(port: int)
signal host_start_failed(port: int, error: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_host()
signal connection_failed()
signal host_ready(peer_id: int, player_name: String, room_state: Dictionary)
signal disconnected()
signal host_message(peer_id: int, msg_type: int, data: Dictionary)
signal client_message(msg_type: int, data: Dictionary)
signal game_started()
signal room_state_changed()
signal input_request_received(req_id: int, req_type: String, params: Dictionary)
signal snapshot_received(state: Dictionary)
signal game_event_received(event: Dictionary)

## 主机 peer id 恒为 1（ENet 服务器约定）。
const HOST_PEER_ID := 1
## 心跳间隔（秒）
const HEARTBEAT_INTERVAL := 5.0
## 超过该时长未收到任何数据判定连接超时（秒）
const TIMEOUT_SECONDS := 30.0

var mode: int = Mode.NONE
## 本机在网络中的 peer id（主机恒为 HOST_PEER_ID；客机由主机分配）。
var peer_id: int = 0
var player_name: String = ""
var host_ip: String = ""
var host_port: int = 0

var _peer_names: Dictionary = {}   # 主机侧：pid -> 昵称
var _last_recv: Dictionary = {}    # 主机侧：pid -> 最近收到数据的时间戳（秒）
var _last_recv_self := 0.0         # 客机侧：最近收到主机数据的时间戳（秒）
var _heartbeat_timer := 0.0
var _remote_inputs: Dictionary = {}  # 主机侧：pid -> NetPlayerInput（阶段二输入转发）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	_heartbeat_timer += delta
	if _heartbeat_timer >= HEARTBEAT_INTERVAL:
		_heartbeat_timer = 0.0
		_heartbeat_and_timeout()


# === 主机 ===

## 启动主机（ENet 服务器）。成功后 mode 变为 HOST。
func start_host(port: int, name: String) -> Error:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 6)
	if err != OK:
		host_start_failed.emit(port, err)
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	peer_id = multiplayer.get_unique_id()
	player_name = name
	host_port = port
	host_started.emit(port)
	return OK


func _on_peer_connected(pid: int) -> void:
	peer_connected.emit(pid)


func _on_peer_disconnected(pid: int) -> void:
	_peer_names.erase(pid)
	_last_recv.erase(pid)
	peer_disconnected.emit(pid)


## 客机消息入口：由客机 rpc_id 到主机触发（any_peer）。
@rpc("any_peer", "call_remote", "reliable")
func _recv_client_message(msg_type: int, data: Dictionary) -> void:
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	_last_recv[sender] = Time.get_ticks_msec() / 1000.0
	match msg_type:
		NetProtocol.Msg.HELLO:
			var name := str(data.get("name", ""))
			if name == "":
				name = "玩家%d" % sender
			_peer_names[sender] = name
			host_send_to(sender, NetProtocol.Msg.HELLO_ACK, {
				"peer_id": sender,
				"player_name": name,
				"room_state": RoomState.to_dict(),
			})
		NetProtocol.Msg.INPUT_RESPONSE:
			var input: Variant = _remote_inputs.get(sender, null)
			if input != null:
				input.receive_response(int(data.get("req_id", -1)), data.get("choice", null))
		_:
			pass
	host_message.emit(sender, msg_type, data)


## 主机向指定客机发送消息。
func host_send_to(pid: int, msg_type: int, data: Dictionary) -> bool:
	if mode != Mode.HOST or not multiplayer.has_multiplayer_peer():
		return false
	rpc_id(pid, "_recv_host_message", msg_type, data)
	return true


## 主机向所有客机广播消息。
func host_broadcast(msg_type: int, data: Dictionary) -> void:
	if mode != Mode.HOST or not multiplayer.has_multiplayer_peer():
		return
	rpc("_recv_host_message", msg_type, data)


func get_peer_name(pid: int) -> String:
	return _peer_names.get(pid, "")


func get_peer_ids() -> Array:
	return multiplayer.get_peers()


## 注册远程玩家输入（主机侧，阶段二输入转发用）。
func register_remote_input(pid: int, input) -> void:
	_remote_inputs[pid] = input


func unregister_remote_input(pid: int) -> void:
	_remote_inputs.erase(pid)


## 主机向所有客机广播全量状态快照。
func host_broadcast_snapshot(state: Dictionary) -> void:
	host_broadcast(NetProtocol.Msg.SNAPSHOT, {"state": state})


# === 客机 ===

## 作为客机连接主机。成功后 mode 变为 CLIENT；握手完成后发射 host_ready。
func join_host(ip: String, port: int, name: String) -> Error:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	player_name = name
	host_ip = ip
	host_port = port
	return OK


func _on_connected_to_server() -> void:
	connected_to_host.emit()
	client_send(NetProtocol.Msg.HELLO, {"name": player_name, "version": NetProtocol.PROTOCOL_VERSION})


func _on_connection_failed() -> void:
	mode = Mode.NONE
	_clear_peer()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	mode = Mode.NONE
	_clear_peer()
	disconnected.emit()


## 主机消息入口：由主机 rpc 到客机触发（authority）。
@rpc("authority", "call_remote", "reliable")
func _recv_host_message(msg_type: int, data: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	_last_recv_self = Time.get_ticks_msec() / 1000.0
	match msg_type:
		NetProtocol.Msg.HELLO_ACK:
			peer_id = int(data.get("peer_id", 0))
			player_name = str(data.get("player_name", player_name))
			host_ready.emit(peer_id, player_name, data.get("room_state", {}))
		NetProtocol.Msg.START_GAME:
			game_started.emit()
		NetProtocol.Msg.INPUT_REQUEST:
			input_request_received.emit(int(data.get("req_id", -1)), str(data.get("type", "")), data.get("params", {}))
		NetProtocol.Msg.SNAPSHOT:
			snapshot_received.emit(data.get("state", {}))
		NetProtocol.Msg.GAME_EVENT:
			game_event_received.emit(data.get("event", {}))
		_:
			pass
	client_message.emit(msg_type, data)


## 客机向主机发送消息。
func client_send(msg_type: int, data: Dictionary) -> bool:
	if mode != Mode.CLIENT or not multiplayer.has_multiplayer_peer():
		return false
	rpc_id(HOST_PEER_ID, "_recv_client_message", msg_type, data)
	return true


# === 心跳 / 超时 ===

func _heartbeat_and_timeout() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if mode == Mode.HOST:
		for pid in multiplayer.get_peers():
			if now - float(_last_recv.get(pid, now)) > TIMEOUT_SECONDS:
				multiplayer.disconnect_peer(pid)
				continue
			rpc_id(pid, "_recv_host_message", NetProtocol.Msg.HEARTBEAT, {})
	elif mode == Mode.CLIENT:
		if now - _last_recv_self > TIMEOUT_SECONDS:
			_on_server_disconnected()
			return
		client_send(NetProtocol.Msg.HEARTBEAT, {})


# === 通用 ===

## 停止当前连接并复位状态。
func stop() -> void:
	_clear_peer()
	_peer_names.clear()
	_last_recv.clear()
	mode = Mode.NONE
	peer_id = 0
	host_port = 0
	_heartbeat_timer = 0.0
	_last_recv_self = 0.0


func _clear_peer() -> void:
	# 先显式关闭 ENet peer（发送 DISCONNECT），再清空 multiplayer_peer，
	# 否则对端（主机）无法及时收到 peer_disconnected，座位不会释放、客机也无法重连。
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
