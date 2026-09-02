extends GutTest

## 网络层测试：基于 Godot 内置 Multiplayer（ENetMultiplayerPeer）。
## 沙箱隔离了进程间网络，无法在本环境内跑双进程联机；
## 这里覆盖：ENet 传输连接（同进程双 SceneMultiplayer 回环）、
## 会话消息处理逻辑（直接调用 RPC 入口）、RoomState 序列化、GameRoom 双模式 UI。

const PORT := 17980
const HOST := "127.0.0.1"


## 等待条件成立（最多 max_frames 帧），返回是否成立。
func _wait_until(condition: Callable, max_frames: int = 600) -> bool:
	for i in range(max_frames):
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func after_each() -> void:
	NetSession.stop()
	RoomState.clear()


## 创建独立的 NetSession 实例（不依赖 autoload，供逻辑直调测试）。
func _make_session() -> Node:
	var session: Node = autofree(Node.new())
	session.set_script(load("res://src/net/net_session.gd"))
	add_child(session)
	return session


# === RoomState 序列化 ===

func test_room_state_serialization_roundtrip() -> void:
	var rs: Node = Node.new()
	rs.set_script(load("res://src/ui/room_state.gd"))
	rs.clear()
	RoomState.init_host_seats("主机", 1)
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.variants["crisis"] = true
	RoomState.seats[1] = {
		"type": "human", "survivor": DataManager.get_survivor("hunter"),
		"player_name": "客机", "peer_id": 2,
	}

	var d := RoomState.to_dict()
	assert_eq(int(d["selected_mission_id"]), 0)
	assert_eq(bool(d["variants"]["crisis"]), true)
	var seats: Array = d["seats"]
	assert_eq(seats.size(), 6)
	assert_eq(seats[0]["player_name"], "主机")
	assert_eq(int(seats[0]["peer_id"]), 1)
	assert_eq(seats[1]["survivor_id"], "hunter")

	rs.apply_dict(d)
	assert_eq(rs.seats.size(), 6, "反序列化后座位数应一致")
	assert_eq(int(rs.seats[1]["peer_id"]), 2)
	assert_eq(rs.seats[1]["player_name"], "客机")
	assert_true(rs.seats[1]["survivor"] is SurvivorData, "求生者应还原为对象")
	assert_eq(rs.seats[1]["survivor"].english_name, "hunter")
	assert_true(rs.selected_mission is MissionData, "任务应还原为对象")
	rs.free()


func test_room_state_is_ready_to_start() -> void:
	RoomState.init_host_seats("主机", 1)
	assert_false(RoomState.is_ready_to_start(), "主机未选角时不应可开始")
	RoomState.seats[0]["survivor"] = DataManager.get_survivor("gunslinger")
	assert_true(RoomState.is_ready_to_start(), "空座位忽略，主机选角后即可开始")
	RoomState.seats[1] = {
		"type": "human", "survivor": null, "player_name": "客机", "peer_id": 2,
	}
	assert_false(RoomState.is_ready_to_start(), "客机座位未选角时不应可开始")
	RoomState.seats[1]["survivor"] = DataManager.get_survivor("hunter")
	assert_true(RoomState.is_ready_to_start(), "所有非空座位选角后即可开始")


# === ENet 传输连接（同进程双 SceneMultiplayer 回环） ===

func test_enet_transport_connects_in_process() -> void:
	var host_mp := SceneMultiplayer.new()
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT + 3, 6), OK, "主机应监听")
	host_mp.multiplayer_peer = server_peer

	var client_mp := SceneMultiplayer.new()
	var client_peer := ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client(HOST, PORT + 3), OK, "客机应发起连接")
	client_mp.multiplayer_peer = client_peer

	var connected := {"server": false, "client": false}
	host_mp.peer_connected.connect(func(_pid: int) -> void:
		connected.server = true
	)
	client_mp.connected_to_server.connect(func() -> void:
		connected.client = true
	)
	var deadline := 600
	while deadline > 0 and not (bool(connected.server) and bool(connected.client)):
		host_mp.poll()
		client_mp.poll()
		await get_tree().process_frame
		deadline -= 1
	assert_true(bool(connected.client), "客机应建立 ENet 连接")
	assert_true(bool(connected.server), "主机应感知到客机连接")
	host_mp.multiplayer_peer = null
	client_mp.multiplayer_peer = null


# === 会话消息处理逻辑（直接调用 RPC 入口） ===

func test_host_handles_hello_logic() -> void:
	var host: Node = _make_session()
	host.mode = host.Mode.HOST
	host.peer_id = NetSession.HOST_PEER_ID
	var msgs: Array = []
	host.host_message.connect(func(pid: int, t: int, d: Dictionary) -> void:
		msgs.append([pid, t, d])
	)
	host._recv_client_message(NetProtocol.Msg.HELLO, {"name": "客机"})
	assert_eq(msgs.size(), 1, "主机应收到并转发 HELLO 消息")
	assert_eq(msgs[0][1], NetProtocol.Msg.HELLO)
	var sender: int = msgs[0][0]
	assert_eq(host.get_peer_name(sender), "客机", "主机应记录客机昵称")


func test_client_handles_hello_ack_logic() -> void:
	var client: Node = _make_session()
	client.mode = client.Mode.CLIENT
	var result := {"fired": false, "name": "", "pid": 0}
	client.host_ready.connect(func(pid: int, name: String, _state: Dictionary) -> void:
		result.fired = true
		result.name = name
		result.pid = pid
	)
	client._recv_host_message(NetProtocol.Msg.HELLO_ACK, {
		"peer_id": 2, "player_name": "客机", "room_state": {"seats": []},
	})
	assert_true(bool(result.fired), "客机应触发 host_ready")
	assert_eq(int(result.pid), 2)
	assert_eq(result.name, "客机")
	assert_eq(client.peer_id, 2, "客机 peer_id 应更新")


func test_client_handles_start_game_logic() -> void:
	var client: Node = _make_session()
	client.mode = client.Mode.CLIENT
	var started := {"fired": false}
	client.game_started.connect(func() -> void:
		started.fired = true
	)
	client._recv_host_message(NetProtocol.Msg.START_GAME, {})
	assert_true(bool(started.fired), "客机收到 START_GAME 应触发 game_started")


# === 输入编解码（行动选择 / 目标） ===

func test_input_codec_roundtrip() -> void:
	RoomState.init_host_seats("主机", NetSession.HOST_PEER_ID)
	RoomState.seats[0]["survivor"] = DataManager.get_survivor("gunslinger")
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	Game.initialize_game(RoomState.selected_mission, RoomState.variants, RoomState.seats)
	var player: Player = Game.players[0]
	var block: MapBlock = Game.map_area[0]
	var card: Card = Game.create_scavenge_card("手枪")
	player.hand.append(card)

	# move 选择
	var enc := NetInputCodec.encode_action_choice({"type": "move", "target": block})
	assert_eq(enc["target"], block.coordinate, "move 目标应编码为坐标")
	var dec: Dictionary = NetInputCodec.decode_action_choice(player, enc)
	assert_eq(dec["target"], block, "move 目标应还原为地块对象")

	# card 选择
	var enc2 := NetInputCodec.encode_action_choice({"type": "card", "card": card})
	assert_eq(int(enc2["card"]), card.net_id, "card 应编码为 net_id")
	var dec2: Dictionary = NetInputCodec.decode_action_choice(player, enc2)
	assert_eq(dec2["card"], card, "card 应还原为卡牌对象")

	# 目标编码（玩家 / 地块 / 卡牌）
	assert_eq(NetInputCodec.encode_target(player)["t"], "player")
	assert_eq(NetInputCodec.decode_target(Game, NetInputCodec.encode_target(player)), player)
	assert_eq(NetInputCodec.decode_target(Game, NetInputCodec.encode_target(block)), block)
	assert_eq(NetInputCodec.decode_target(Game, NetInputCodec.encode_target(card)), card)


# === 掉线结算（NetPlayerInput.disconnect） ===

func _spawn_wait_action(input: NetPlayerInput, started: Dictionary) -> void:
	started.result = await input.wait_action(null)
	started.done = true


func test_net_player_input_disconnect_resolves_pending() -> void:
	RoomState.init_host_seats("主机", NetSession.HOST_PEER_ID)
	RoomState.seats[0]["survivor"] = DataManager.get_survivor("gunslinger")
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	Game.initialize_game(RoomState.selected_mission, RoomState.variants, RoomState.seats)
	var input := NetPlayerInput.new()
	input.peer_id = 99
	input.player = Game.players[0]
	var started := {"done": false, "result": null}
	_spawn_wait_action(input, started)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(input._pending.size(), 1, "应有一个挂起请求")
	input.on_peer_disconnected()
	await get_tree().process_frame
	assert_true(bool(started.done), "disconnect 应结算挂起的 wait_action")
	assert_null(started.result, "action 类型默认返回 null（结束回合）")
	assert_eq(input._pending.size(), 0, "disconnect 应清空挂起请求")


# === GameRoom 双模式 UI ===

func test_game_room_host_mode_loads() -> void:
	RoomState.clear()
	# _setup_host_mode 在无会话时会兜底启动主机，随后初始化 6 座位
	var room: Node = (load("res://scenes/GameRoom.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(RoomState.seats.size(), 6, "主机房间应有 6 个座位")
	assert_eq(RoomState.seats[0]["player_name"], "玩家", "座位 0 应属于主机")
	assert_true(NetSession.mode == NetSession.Mode.HOST, "兜底应处于主机模式")
	room.queue_free()
	NetSession.stop()


func test_game_room_client_mode_loads() -> void:
	# 直接构造客机会话状态，验证客机模式 UI（不依赖真实连接）
	RoomState.init_host_seats("主机", NetSession.HOST_PEER_ID)
	RoomState.seats[1] = {
		"type": "human", "survivor": DataManager.get_survivor("hunter"),
		"player_name": "客机", "peer_id": 2,
	}
	NetSession.mode = NetSession.Mode.CLIENT
	NetSession.peer_id = 2
	NetSession.player_name = "客机"
	NetSession.host_ip = HOST
	NetSession.host_port = PORT

	var room: Node = (load("res://scenes/GameRoom.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame
	var start_btn: Button = room.get_node("BottomBar/StartGameButton")
	assert_true(start_btn.disabled, "客机模式开始按钮应禁用")
	assert_eq(start_btn.text, "等待主机开始...")
	assert_eq(RoomState.seats.size(), 6, "客机镜像房间应有 6 个座位")
	room.queue_free()
	NetSession.stop()
