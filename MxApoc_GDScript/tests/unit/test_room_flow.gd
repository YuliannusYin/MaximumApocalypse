extends GutTest

## 复现/验证：主机单开开局 + 客机认领/放弃座位 的流程逻辑。


func after_each() -> void:
	NetSession.stop()
	RoomState.clear()
	Game.players.clear()
	Game.map_area.clear()


func test_host_alone_room_can_start() -> void:
	RoomState.clear()
	assert_eq(NetSession.start_host(17950, "主机"), OK)
	var room: Node = (load("res://scenes/GameRoom.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(RoomState.seats.size(), 6, "主机房间应有 6 个座位")
	# 通过座位 UI 选择求生者（模拟真实主机操作：下拉 → 触发 changed）
	var seat_list: VBoxContainer = room.get_node("PlayerSettingArea/VBoxContainer/SeatList")
	var seat0: Node = seat_list.get_child(0)
	var surv_opt: OptionButton = seat0.get_node("MarginContainer/VBoxContainer/SurvivorOption")
	surv_opt.select(1)
	seat0._on_selection_changed(1)
	assert_true(RoomState.is_ready_to_start(), "主机选角后应可开始")
	var start_btn: Button = room.get_node("BottomBar/StartGameButton")
	assert_false(start_btn.disabled, "开始按钮应可用")
	room.queue_free()
	NetSession.stop()


func test_host_handles_seat_claim_claim_and_release() -> void:
	RoomState.clear()
	assert_eq(NetSession.start_host(17952, "主机"), OK)
	# 模拟客机 2 已握手（昵称记录在 NetSession）
	NetSession._peer_names[2] = "客机"
	var room: Node = (load("res://scenes/GameRoom.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame
	# 认领（空 survivor_id = 占座）
	room._handle_seat_claim(2, {"seat_index": 1, "survivor_id": ""})
	assert_eq(int(RoomState.seats[1]["peer_id"]), 2, "认领后 peer_id 应为 2")
	assert_eq(RoomState.seats[1]["player_name"], "客机")
	assert_null(RoomState.seats[1]["survivor"], "认领后尚未选角")
	# 选角
	room._handle_seat_claim(2, {"seat_index": 1, "survivor_id": "hunter"})
	assert_true(RoomState.seats[1]["survivor"] is SurvivorData, "选角后应解析求生者")
	assert_eq(RoomState.seats[1]["survivor"].english_name, "hunter")
	# 放弃（自己占用的空 survivor_id = 释放）
	room._handle_seat_claim(2, {"seat_index": 1, "survivor_id": ""})
	assert_eq(int(RoomState.seats[1]["peer_id"]), 0, "放弃后座位应释放")
	room.queue_free()
	NetSession.stop()
