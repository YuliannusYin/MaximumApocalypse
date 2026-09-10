extends TestBase

## 房主对局快照同帧合并：多次标记只在 flush 时发出一份。


func test_request_state_snapshot_coalesces_until_flush() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	session.request_state_snapshot()
	session.request_state_snapshot()
	session.broadcast_state_snapshot()
	assert_true(session.has_pending_state_snapshot(), "同帧多次请求应只留下一份待发送快照")
	assert_true(session._flush_pending_state_snapshot(), "第一次 flush 应发送合并后的快照")
	assert_false(session.has_pending_state_snapshot(), "flush 后脏标记应清除")
	assert_false(session._flush_pending_state_snapshot(), "没有新脏标记时不应再发送")
	session.free()


func test_client_request_state_snapshot_is_ignored() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = false
	session.request_state_snapshot()
	assert_false(session.has_pending_state_snapshot(), "客机不应标记待发送快照")
	session.free()


func test_is_authority_false_after_host_becomes_client_without_runtime() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	assert_true(session.is_authority(), "大厅房主应是权威")
	session.is_host = false
	session.session_role = "client"
	assert_false(session.is_authority(), "无听服、无 Runtime 时环回 UI 不是权威")
	session.free()


func test_room_owner_client_is_not_remote_client() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var survivor = DataManager.get_survivor("firefighter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	session.is_host = true
	session.session_role = "client"
	session.local_player_id = host.player_id
	assert_true(session.is_room_owner())
	assert_false(session.is_remote_client())
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.is_host = false
	session.local_player_id = guest.player_id
	assert_false(session.is_room_owner())
	assert_true(session.is_remote_client())
	assert_true(session.uses_network_view(), "客机应对局走网络视图")
	session.free()


func test_room_owner_loopback_uses_network_view() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "client"
	assert_true(session.uses_network_view(), "环回后的房主应对局走网络视图")
	assert_false(session.is_remote_client(), "房主环回不是远端客机")
	session.session_role = "host"
	assert_false(session.uses_network_view(), "环回完成前大厅房主不走客机视图")
	session.session_role = "none"
	assert_false(session.uses_network_view())
	session.free()


func test_guest_cannot_start_or_bind_seat() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session._handle_room_command(NetProtocol.make_message(NetProtocol.ROOM_COMMAND, {
		"command": "start",
		"payload": {},
	}, guest.player_id), 3)
	assert_eq(session.registry.phase, "lobby")
	var owner_id: String = String(session.registry.room_owner_player_id())
	session._handle_room_command(NetProtocol.make_message(NetProtocol.ROOM_COMMAND, {
		"command": "bind_seat",
		"payload": {
			"seat_id": 0,
			"controller_id": guest.player_id,
			"survivor_id": "firefighter",
			"is_ai": false,
		},
	}, guest.player_id), 3)
	assert_eq(String(session.registry.seats[0].controller_id), owner_id)
	session.free()


func test_owner_loopback_peer_is_still_owner() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var survivor = DataManager.get_survivor("firefighter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	assert_eq(session.registry.reconnect_player_by_token(host.reconnect_token, 2),
		host.player_id)
	assert_true(session._is_owner_player(host.player_id))
	assert_eq(session._player_for_peer(2), host.player_id)
	assert_eq(session._player_for_peer(1), "")
	session.free()


func test_playing_resync_payload_includes_game_snapshot() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "host"
	session.is_host = true
	session.registry.phase = "playing"
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	Game.players = [player]
	Game.map_area = []
	var payload: Dictionary = session.playing_resync_payload()
	assert_true(payload.has("game_snapshot"), "对局重同步必须带场面")
	assert_eq(payload["game_snapshot"]["players"].size(), 1)
	session.free()


func test_lobby_resync_payload_omits_game_snapshot() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "host"
	session.is_host = true
	session.registry.phase = "lobby"
	Game.players = [_make_player("Hunter")]
	var payload: Dictionary = session.playing_resync_payload()
	assert_false(payload.has("game_snapshot"), "大厅重同步不应带对局场面")
	session.free()


func test_reconnect_state_snapshot_emits_joined_after_identity_cleared() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = ""
	session.local_reconnect_token = ""
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	watch_signals(session)
	session.receive_message(NetProtocol.make_message(NetProtocol.STATE_SNAPSHOT, {
		"player_id": "p_guest",
		"reconnect_token": "tok",
		"room_snapshot": {
			"phase": "playing",
			"players": [],
			"seats": [],
			"mission": {},
			"variants": {},
		},
	}))
	assert_eq(session.local_player_id, "p_guest")
	assert_eq(session.local_reconnect_token, "tok")
	assert_false(session._awaiting_room_accept)
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["joined", "已重连房间"])
	session.free()


func test_reconnect_lobby_snapshot_emits_joined() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = ""
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	watch_signals(session)
	session.receive_message(NetProtocol.make_message(NetProtocol.ROOM_SNAPSHOT, {
		"player_id": "p_guest",
		"reconnect_token": "tok",
		"phase": "lobby",
		"players": [],
		"seats": [],
		"mission": {},
		"variants": {},
	}))
	assert_eq(session.local_player_id, "p_guest")
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["joined", "已重连房间"])
	session.receive_message(NetProtocol.make_message(NetProtocol.ROOM_SNAPSHOT, {
		"phase": "lobby",
		"players": [],
		"seats": [],
		"mission": {},
		"variants": {},
	}))
	assert_signal_emit_count(session, "connection_state_changed", 1)
	session.free()


func test_get_display_game_prefers_view_instance() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var view := Node.new()
	session._view_game = view
	assert_eq(session.get_display_game(), view)
	view.free()
	session.free()


func test_loopback_client_message_emits_to_ui() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	watch_signals(session)
	session.receive_loopback_client_message(NetProtocol.make_message(
		NetProtocol.GAME_EVENT, {"event_name": "log", "payload": {"message": "x"}}))
	assert_signal_emitted(session, "message_received")
	session.free()


func test_guest_leave_allows_reconnect_with_same_token() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session._handle_leave(NetProtocol.make_message(
		NetProtocol.LEAVE_REQUEST, {}, guest.player_id), 3)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"disconnected")
	assert_eq(String(session.registry.seats[1].controller_id), guest.player_id)
	assert_eq(session.registry.reconnect_player_by_token(guest.reconnect_token, 9),
		guest.player_id)
	session.free()


func test_guest_cannot_edit_unowned_or_empty_seat() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	assert_true(session._can_edit_seat_survivor(host.player_id, 0))
	assert_true(session._can_edit_seat_survivor(host.player_id, 1))
	assert_true(session._can_edit_seat_survivor(guest.player_id, 1))
	assert_false(session._can_edit_seat_survivor(guest.player_id, 0))
	session.free()


func test_filter_local_controlled_players_skips_ai_and_foreign_seats() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var survivor_c = DataManager.get_survivor("surgeon")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.replace_seats([
		{"type": "human", "survivor": survivor_a, "controller_id": host.player_id},
		{"type": "ai", "survivor": survivor_b},
		{"type": "human", "survivor": survivor_c, "controller_id": guest.player_id},
	], host.player_id)
	var host_p: Player = _make_player("房主")
	host_p.seat_number = 0
	var ai_p: Player = _make_player("AI")
	ai_p.seat_number = 1
	var guest_p: Player = _make_player("客机")
	guest_p.seat_number = 2
	var all_players: Array = [host_p, ai_p, guest_p]
	session.local_player_id = guest.player_id
	var guest_local: Array = session.filter_local_controlled_players(all_players)
	assert_eq(guest_local.size(), 1, "客机只应计入自己操作的座位")
	assert_eq(guest_local[0], guest_p)
	session.local_player_id = host.player_id
	var host_local: Array = session.filter_local_controlled_players(all_players)
	assert_eq(host_local.size(), 1, "房主只应计入自己操作的座位，不含 AI/客机")
	assert_eq(host_local[0], host_p)
	session.free()


func test_game_result_filters_archive_only_in_online_view() -> void:
	var saved_online := RoomState.online_multiplayer
	var saved_role := String(NetSession.session_role)
	var result_ui: Control = load("res://src/ui/game_result.gd").new()
	RoomState.online_multiplayer = true
	NetSession.session_role = "client"
	assert_true(result_ui._should_filter_online_archive(), "联机对局视图应分开录入")
	RoomState.online_multiplayer = false
	assert_false(result_ui._should_filter_online_archive(), "单机不应过滤")
	RoomState.online_multiplayer = true
	NetSession.session_role = "host"
	assert_false(result_ui._should_filter_online_archive(), "未环回的大厅房主不按联机过滤")
	RoomState.online_multiplayer = saved_online
	NetSession.session_role = saved_role
	result_ui.free()
