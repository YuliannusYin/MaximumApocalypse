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


func test_broadcast_input_request_flushes_pending_snapshot() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	session.request_state_snapshot()
	assert_true(session.has_pending_state_snapshot())
	session.broadcast_input_request(1, 0, "missing", "choose_target", {})
	assert_false(session.has_pending_state_snapshot(), "发 INPUT_REQUEST 前应 flush 脏快照")
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


func test_apply_display_snapshot_does_not_write_authority_monster_hp() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var monster: Monster = Monster.new()
	monster.english_name = "zombie"
	monster.hp = 5
	monster.max_hp = 5
	player.monster_zone = [monster]
	Game.players = [player]
	Game.map_area = []
	var session: Node = load("res://src/net/net_session.gd").new()
	add_child_autofree(session)
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	runtime._active = true
	session.add_child(runtime)
	session.server_runtime = runtime
	var snapshot: Dictionary = GameStateSerializer.snapshot(Game)
	assert_false(snapshot.get("players", []).is_empty())
	snapshot["players"][0]["monsters"][0]["hp"] = 0
	session.apply_display_game_snapshot(snapshot, {})
	assert_eq(monster.hp, 5, "有 Runtime 时快照不得写进权威怪物血量")
	assert_ne(session.get_display_game(), Game, "应创建 ViewGame 承接快照")


func test_client_apply_display_snapshot_creates_view_game() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var monster: Monster = Monster.new()
	monster.english_name = "zombie"
	monster.hp = 5
	monster.max_hp = 5
	player.monster_zone = [monster]
	Game.players = [player]
	Game.map_area = []
	var session: Node = load("res://src/net/net_session.gd").new()
	add_child_autofree(session)
	session.session_role = "client"
	session.is_host = false
	var snapshot: Dictionary = GameStateSerializer.snapshot(Game)
	assert_false(snapshot.get("players", []).is_empty())
	snapshot["players"][0]["monsters"][0]["hp"] = 0
	session.apply_display_game_snapshot(snapshot, {})
	assert_eq(monster.hp, 5, "无 Runtime 的客机快照不得写进单例 Game")
	assert_ne(session.get_display_game(), Game, "客机应对局走 ViewGame")
	var display: Node = session.get_display_game()
	assert_eq(display.name, "ViewGame")
	assert_eq(display.players.size(), 1)
	assert_eq(int(display.players[0].monster_zone[0].hp), 0, "客机 ViewGame 应承接快照血量")
	assert_eq(Game.players, [player], "单例 Game 玩家列表应保持原样")


func test_match_start_creates_view_game_for_client() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	add_child_autofree(session)
	session.session_role = "client"
	session.is_host = false
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.MATCH_START, {
		"room_snapshot": {
			"phase": "playing",
			"players": [],
			"seats": [],
			"mission": {},
			"variants": {},
		},
	}))
	assert_ne(session.get_display_game(), Game, "MATCH_START 应为客机创建 ViewGame")
	assert_eq(session.get_display_game().name, "ViewGame")


func test_authority_apply_snapshot_keeps_reconnect_hashes() -> void:
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
	var hash_before: String = String(
		session.registry.players[guest.player_id].get("reconnect_token_hash", ""))
	assert_ne(hash_before, "")
	session._apply_snapshot(session.registry.snapshot())
	assert_eq(String(session.registry.players[guest.player_id].get("reconnect_token_hash", "")),
		hash_before, "权威端不得用去哈希的环回快照覆盖凭证")
	session.free()


func test_guest_log_stays_on_view_game_until_settlement() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	assert_false(session.is_authority(), "无听服的客机实例才应回写结算")
	var display: Node = session._ensure_view_game()
	assert_ne(display, Game)
	var guest_player: Player = _make_player("客机")
	guest_player.seat_number = 0
	display.players = [guest_player]
	display.log_list = ["座位1 移动了"]
	display.game_result = "win"
	display.game_over_called = true
	if display.state_machine != null:
		display.state_machine.game_result = GameStateMachine.GameResult.WIN
		display.state_machine.last_player = guest_player
	assert_eq(Game.log_list, [], "对局中客机日志不应写进单例 Game")
	session.commit_display_settlement_to_game()
	assert_eq(Game.log_list, ["座位1 移动了"], "结算回写后 Game.log_list 应有客机日志")
	assert_eq(Game.players.size(), 1)
	assert_eq(Game.players[0], guest_player)
	assert_eq(Game.game_result, "win")
	if display.state_machine != null:
		assert_eq(int(Game.state_machine.game_result), GameStateMachine.GameResult.WIN)
		assert_eq(Game.state_machine.last_player, guest_player)
	session.free()


func test_commit_display_settlement_skips_authority() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	add_child_autofree(session)
	session.is_host = true
	session.session_role = "host"
	var view: Node = load("res://src/game/game.gd").new()
	view.log_list = ["显示世界日志"]
	session._view_game = view
	Game.log_list = ["权威日志"]
	session.commit_display_settlement_to_game()
	assert_eq(Game.log_list, ["权威日志"], "权威端结算回写不得覆盖 Game")
	view.free()


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


func test_should_enter_match_scene_for_remote_client_playing() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var survivor = DataManager.get_survivor("firefighter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.session_role = "client"
	session.is_host = false
	session.local_player_id = guest.player_id
	session.registry.phase = "playing"
	assert_true(session.should_enter_match_scene(), "客机 playing 应进对局")
	session.registry.phase = "lobby"
	assert_false(session.should_enter_match_scene(), "大厅不应进对局")
	session.local_player_id = host.player_id
	session.registry.phase = "playing"
	assert_false(session.should_enter_match_scene(), "房主环回不走客机进对局")
	session.free()


func test_drop_stale_players_handoffs_guest_not_host() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "human", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 4)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.phase = "playing"
	session.registry.players[host.player_id]["last_seen_ms"] = 0
	session.registry.players[guest.player_id]["last_seen_ms"] = 0
	var dropped: Array = session.drop_stale_players(40000)
	assert_eq(dropped, [guest.player_id])
	assert_eq(String(session.registry.seats[1].control_mode), "ai")
	assert_eq(String(session.registry.seats[0].control_mode), "human")
	session.free()


func test_reconnect_to_last_room_requires_address_and_token() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	assert_false(session.reconnect_to_last_room())
	assert_eq(session.last_client_connect_error(), "没有可重连的房间地址")
	session._connected_address = "127.0.0.1:7777"
	assert_false(session.reconnect_to_last_room(), "没有重连凭证不应开连")
	assert_eq(session.last_client_connect_error(), "没有重连凭证")
	session.local_reconnect_token = "tok"
	session.registry.phase = "playing"
	session.free()


func test_heartbeat_refreshes_guest_last_seen() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor = DataManager.get_survivor("firefighter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	var guest: Dictionary = session.registry.add_player("客机", 4)
	session.registry.players[guest.player_id]["last_seen_ms"] = 0
	session._handle_message(NetProtocol.make_message(NetProtocol.HEARTBEAT), 4)
	assert_gt(int(session.registry.players[guest.player_id].last_seen_ms), 0,
		"心跳应刷新客机 last_seen")
	session.free()


func test_client_transport_connected_false_without_peer() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	assert_false(session._peer_is_connected(null), "空 peer 未连通")
	var idle_peer := ENetMultiplayerPeer.new()
	assert_eq(idle_peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	assert_false(session._peer_is_connected(idle_peer), "未 create 的 ENet peer 未连通")
	assert_false(session._client_transport_connected(), "无客机 peer 时传输未连通")
	session.free()


func test_heartbeat_skips_when_disconnected() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._last_heartbeat_sent_ms = 0
	session._tick_heartbeat()
	assert_eq(session._last_heartbeat_sent_ms, 0, "未连通时心跳不应记下发送时间")
	session._send_to_host(NetProtocol.HEARTBEAT)
	assert_eq(session._last_heartbeat_sent_ms, 0, "未连通的 _send_to_host 不应误记心跳")
	session.free()


func test_close_session_keeps_saved_identity_for_menu_rejoin() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.local_reconnect_token = "tok"
	session._pending_nickname = "客机"
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	session.close_session()
	assert_eq(session.local_reconnect_token, "")
	assert_eq(session._hello_reconnect_token(), "tok", "回菜单后加入仍应带上磁盘里的重连凭证")
	session.free()


func test_stale_client_disconnect_is_ignored_after_new_join() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "closed"
	session._peer_serial = 7
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	watch_signals(session)
	session._complete_client_disconnect("disconnected", 6)
	assert_signal_not_emitted(session, "network_error")
	assert_eq(session.session_role, "client")
	assert_eq(session._peer_serial, 7)
	session.free()


func test_playing_disconnect_keeps_session_for_reconnect() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session._connected_address = "127.0.0.1:7777"
	session.local_reconnect_token = "tok"
	session._peer_serial = 3
	watch_signals(session)
	session._complete_client_disconnect("disconnected", 3)
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["disconnected", "与房主的连接已断开"])
	assert_eq(session.session_role, "client")
	assert_eq(session._connected_address, "127.0.0.1:7777")
	assert_eq(session._hello_reconnect_token(), "tok")
	session.free()


func test_host_stale_peer_disconnect_does_not_drop_reconnected_player() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "human", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 4)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.reconnect_player_by_token(guest.reconnect_token, 9)
	session._complete_host_peer_disconnected(4)
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 9)
	assert_eq(String(session.registry.players[guest.player_id].connection_state), "connected")
	session.free()


func test_has_listen_server_false_when_peer_disconnected() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	assert_false(session.has_listen_server())
	var idle := ENetMultiplayerPeer.new()
	assert_eq(idle.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	assert_false(session._multiplayer_peer_is_live(idle), "断开的 peer 不能再调 is_server")
	assert_false(session._multiplayer_peer_is_live(null))
	session.free()


func test_server_disconnected_ignores_inactive_peer_without_authority_check() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session.local_reconnect_token = "tok"
	watch_signals(session)
	session._on_server_disconnected()
	assert_false(session.has_listen_server())
	session.free()


func test_begin_client_peer_keeps_domain_and_resolved_ip() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var peer := ENetMultiplayerPeer.new()
	session._begin_client_peer(peer, "example.com:7777", "客机", "1.2.3.4")
	assert_eq(session._connected_address, "example.com:7777")
	assert_eq(session._resolved_ip, "1.2.3.4")
	assert_eq(session.session_role, "client")
	peer.close()
	session.free()


func test_reconnect_uses_cached_ip_instead_of_domain() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session._resolved_ip = "127.0.0.1"
	var cached: Dictionary = session._client_connect_ip("does-not-resolve.invalid")
	assert_true(bool(cached.get("ok", false)))
	assert_eq(String(cached.get("ip", "")), "127.0.0.1")
	session._resolved_ip = ""
	var ipv4: Dictionary = session._client_connect_ip("10.0.0.2")
	assert_eq(String(ipv4.get("ip", "")), "10.0.0.2")
	session.free()


func test_guest_peer_disconnected_emits_disconnected_when_playing() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session.local_reconnect_token = "tok"
	session._peer_serial = 3
	watch_signals(session)
	session._on_peer_disconnected(1)
	await wait_idle_frames(2)
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["disconnected", "与房主的连接已断开"])
	assert_eq(session.session_role, "client")
	assert_eq(session._hello_reconnect_token(), "tok")
	session.free()


func test_failed_playing_disconnect_emits_disconnected() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session.local_reconnect_token = "tok"
	session._peer_serial = 3
	watch_signals(session)
	session._complete_client_disconnect("failed", 3)
	assert_signal_emitted(session, "network_error")
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["disconnected", "与房主的连接已断开"])
	assert_eq(session.session_role, "client")
	assert_eq(session._hello_reconnect_token(), "tok")
	session.free()


func test_playing_invalid_token_does_not_fallback_to_join() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session._pending_nickname = "客机"
	session.local_reconnect_token = "tok"
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.ERROR, {
		"code": NetProtocol.ERROR_INVALID_TOKEN,
		"detail": "重连凭证无效或已过期",
	}))
	assert_eq(session.local_reconnect_token, "tok", "已入座后迟到的失效凭证不应清掉内存凭证")
	assert_signal_not_emitted(session, "network_error")
	assert_signal_not_emitted(session, "connection_state_changed")
	session.free()


func test_playing_awaiting_invalid_token_emits_reconnect_failed() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session._awaiting_room_accept = true
	session._pending_nickname = "客机"
	session.local_reconnect_token = "tok"
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.ERROR, {
		"code": NetProtocol.ERROR_INVALID_TOKEN,
		"detail": "重连凭证无效或已过期",
	}))
	assert_eq(session.local_reconnect_token, "")
	assert_signal_emitted_with_parameters(session, "network_error",
		[NetProtocol.ERROR_INVALID_TOKEN, "重连失败"])
	assert_signal_not_emitted(session, "connection_state_changed")
	session.free()


func test_broadcast_snapshot_without_identity_does_not_join() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = "p_guest"
	session.local_reconnect_token = "tok"
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.STATE_SNAPSHOT, {
		"room_snapshot": {
			"phase": "playing",
			"players": [],
			"seats": [],
			"mission": {},
			"variants": {},
		},
		"game_snapshot": {"players": []},
	}))
	assert_true(session._awaiting_room_accept, "广播快照不应当成重连成功")
	assert_eq(session.local_player_id, "p_guest")
	assert_eq(session.local_reconnect_token, "tok")
	assert_signal_not_emitted(session, "connection_state_changed")
	session.free()


func test_broadcast_snapshot_confirms_local_connected_seat() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = "p_guest"
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.STATE_SNAPSHOT, {
		"room_snapshot": {
			"phase": "playing",
			"players": [{
				"player_id": "p_guest",
				"connection_state": "connected",
				"is_host": false,
			}],
			"seats": [{
				"controller_id": "p_guest",
				"control_mode": "human",
			}],
			"mission": {},
			"variants": {},
		},
	}))
	assert_false(session._awaiting_room_accept)
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["joined", "已重连房间"])
	session.free()


func test_broadcast_snapshot_ai_seat_does_not_join() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = "p_guest"
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.STATE_SNAPSHOT, {
		"room_snapshot": {
			"phase": "playing",
			"players": [{
				"player_id": "p_guest",
				"connection_state": "connected",
				"is_host": false,
			}],
			"seats": [{
				"controller_id": "p_guest",
				"control_mode": "ai",
			}],
			"mission": {},
			"variants": {},
		},
	}))
	assert_true(session._awaiting_room_accept)
	assert_signal_not_emitted(session, "connection_state_changed")
	session.free()


func test_incoming_sender_id_does_not_default_to_host() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	assert_eq(session._incoming_sender_id(), 0)
	assert_eq(session._authority_sender_id(), 0)
	assert_false(session._has_rpc_peer(1))
	assert_false(session._has_rpc_peer(0))
	session.free()


func test_broadcast_input_request_drops_zero_peer() -> void:
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
	session.registry.start_match()
	session.registry.players[guest.player_id]["peer_id"] = 0
	session.broadcast_input_request(1, 1, guest.player_id, "choose_target", {})
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"disconnected")
	assert_eq(String(session.registry.seats[1].control_mode), "ai")
	session.free()


func test_join_keeps_reconnect_token_after_close_session() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.local_reconnect_token = "tok"
	session._saved_identity = {"player_id": "p_guest", "reconnect_token": "tok"}
	watch_signals(session)
	assert_false(session.join("", "客机"))
	assert_eq(session._hello_reconnect_token(), "tok", "加入失败后仍应保留凭证以便下次认回")
	session.free()


func test_playing_join_rejects_newcomer() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	var player_count: int = session.registry.players.size()
	session._handle_join(NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
		"display_name": "路人",
	}), 8)
	assert_eq(session.registry.players.size(), player_count)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"disconnected")
	session.free()


func test_playing_join_resumes_disconnected_same_name() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	session._handle_join(NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
		"display_name": "客机",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	assert_eq(String(session.registry.seats[1].control_mode), "human")
	session.free()


func test_playing_join_resumes_by_name_when_token_wrong() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	session._handle_join(NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
		"display_name": "客机",
		"reconnect_token": "wrong-token",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	assert_eq(String(session.registry.seats[1].control_mode), "human")
	session.free()


func test_reconnect_bad_token_resumes_disconnected_same_name() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": "wrong-token",
		"display_name": "客机",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	assert_eq(String(session.registry.seats[1].control_mode), "human")
	session.free()


func test_reconnect_bad_token_steals_connected_same_name() -> void:
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
	session.registry.start_match()
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": "wrong-token",
		"display_name": "客机",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	assert_eq(String(session.registry.seats[1].control_mode), "human")
	session.free()


func test_playing_join_steals_connected_same_name() -> void:
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
	session.registry.start_match()
	session._handle_join(NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {
		"display_name": "客机",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	session.free()


func test_reconnect_host_token_does_not_claim_host_seat() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.start_match()
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": host.reconnect_token,
		"display_name": "路人",
	}), 8)
	assert_eq(int(session.registry.players[host.player_id].peer_id), 1)
	assert_true(bool(session.registry.players[host.player_id].get("is_host", false)))
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 3)
	session.free()


func test_reconnect_host_token_falls_back_to_disconnected_guest_name() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var host: Dictionary = session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.start_match()
	session.registry.disconnect_player(guest.player_id)
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": host.reconnect_token,
		"display_name": "客机",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	assert_eq(int(session.registry.players[host.player_id].peer_id), 1)
	assert_true(bool(session.registry.players[host.player_id].get("is_host", false)))
	session.free()


func _host_playing_disconnected_guest(session: Node, nickname: String) -> Dictionary:
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player(nickname, 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.start_match()
	session.registry.disconnect_player(guest.player_id)
	return guest


func test_legacy_identity_migrates_to_guest_slot() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var migrated: Dictionary = session._normalize_identity({
		"player_id": "p_old",
		"reconnect_token": "old-tok",
	})
	assert_eq(String(migrated.guest.get("reconnect_token", "")), "old-tok")
	assert_eq(String(migrated.guest.get("player_id", "")), "p_old")
	assert_eq(String(migrated.host.get("reconnect_token", "")), "")
	session.free()


func test_host_identity_save_keeps_guest_slot() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "host"
	session.is_host = true
	session._saved_identity = {
		"guest": {"player_id": "p_guest", "reconnect_token": "guest-tok"},
	}
	session.local_player_id = "p_host"
	session.local_reconnect_token = "host-tok"
	session._save_identity()
	assert_eq(String(session._saved_identity.guest.get("reconnect_token", "")), "guest-tok")
	assert_eq(String(session._saved_identity.host.get("reconnect_token", "")), "host-tok")
	session.free()


func test_guest_hello_token_ignores_host_slot() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.local_reconnect_token = ""
	session._saved_identity = {
		"host": {"player_id": "p_host", "reconnect_token": "host-tok"},
		"guest": {"player_id": "p_guest", "reconnect_token": "guest-tok"},
	}
	assert_eq(session._hello_reconnect_token(), "guest-tok")
	session.session_role = "host"
	session.is_host = true
	assert_eq(session._hello_reconnect_token(), "host-tok")
	session.free()


func test_guest_hello_slot_ignores_room_owner_flag() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.local_player_id = "p_host"
	session.local_reconnect_token = ""
	session.registry.players["p_host"] = {
		"player_id": "p_host",
		"is_host": true,
	}
	session._saved_identity = {
		"host": {"player_id": "p_host", "reconnect_token": "host-tok"},
		"guest": {"player_id": "p_guest", "reconnect_token": "guest-tok"},
	}
	assert_true(session.is_room_owner())
	assert_eq(session._hello_identity_slot(), NetProtocol.IDENTITY_SLOT_GUEST)
	assert_eq(session._hello_reconnect_token(), "guest-tok")
	session.free()


func test_legacy_identity_file_migrates_to_split_files() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var user_dir := DirAccess.open("user://")
	assert_not_null(user_dir)
	user_dir.remove("net_identity_guest.json")
	user_dir.remove("net_identity_host.json")
	var legacy := FileAccess.open(NetProtocol.IDENTITY_FILE_PATH, FileAccess.WRITE)
	assert_not_null(legacy)
	legacy.store_string(JSON.stringify({
		"host": {"player_id": "p_host", "reconnect_token": "legacy-host"},
		"guest": {"player_id": "p_guest", "reconnect_token": "legacy-guest"},
	}))
	legacy.close()
	var slots: Dictionary = session._read_normalized_identity_file()
	assert_eq(String(slots.host.get("reconnect_token", "")), "legacy-host")
	assert_eq(String(slots.guest.get("reconnect_token", "")), "legacy-guest")
	assert_false(FileAccess.file_exists(NetProtocol.IDENTITY_FILE_PATH))
	assert_true(FileAccess.file_exists(NetProtocol.IDENTITY_FILE_PATH_HOST))
	assert_true(FileAccess.file_exists(NetProtocol.IDENTITY_FILE_PATH_GUEST))
	user_dir.remove("net_identity.json")
	user_dir.remove("net_identity_guest.json")
	user_dir.remove("net_identity_host.json")
	session.free()


func test_split_identity_files_roundtrip() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session._write_identity_slot_data(NetProtocol.IDENTITY_SLOT_GUEST, {
		"player_id": "p_guest",
		"reconnect_token": "guest-file-tok",
	})
	session._write_identity_slot_data(NetProtocol.IDENTITY_SLOT_HOST, {
		"player_id": "p_host",
		"reconnect_token": "host-file-tok",
	})
	var guest_row: Dictionary = session._read_identity_slot_file(
		NetProtocol.IDENTITY_FILE_PATH_GUEST)
	var host_row: Dictionary = session._read_identity_slot_file(
		NetProtocol.IDENTITY_FILE_PATH_HOST)
	assert_eq(String(guest_row.get("reconnect_token", "")), "guest-file-tok")
	assert_eq(String(host_row.get("reconnect_token", "")), "host-file-tok")
	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		user_dir.remove("net_identity_guest.json")
		user_dir.remove("net_identity_host.json")
	session.free()


func test_broadcast_snapshot_does_not_restore_saved_identity() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = ""
	session.local_reconnect_token = "guest-tok"
	session._saved_identity = {
		"host": {"player_id": "p_host", "reconnect_token": "host-tok"},
		"guest": {"player_id": "p_guest", "reconnect_token": "guest-tok"},
	}
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.STATE_SNAPSHOT, {
		"room_snapshot": {
			"phase": "playing",
			"players": [],
			"seats": [],
			"mission": {},
			"variants": {},
		},
	}))
	assert_eq(session.local_player_id, "", "广播快照不得用磁盘身份填 player_id")
	assert_eq(session.local_reconnect_token, "guest-tok")
	assert_true(session._awaiting_room_accept)
	assert_signal_not_emitted(session, "connection_state_changed")
	session.free()


func test_identity_snapshot_payload_includes_player_id() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	var message: Dictionary = session._identity_snapshot_message(guest.player_id, "tok")
	assert_eq(String(message.payload.get("player_id", "")), guest.player_id)
	assert_eq(String(message.payload.get("reconnect_token", "")), "tok")
	session.free()


func test_targeted_identity_snapshot_finishes_room_accept() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_player_id = ""
	session.local_reconnect_token = ""
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.STATE_SNAPSHOT, {
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


func test_drop_remote_player_emits_presence() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "human", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.start_match()
	watch_signals(session)
	session._drop_remote_player(guest.player_id, false)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"disconnected")
	assert_signal_emitted_with_parameters(session, "player_presence_changed",
		[guest.player_id, "disconnected", "客机", false])
	session.free()


func test_accept_reconnected_player_emits_presence() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	session.registry.reconnect_player_by_token(guest.reconnect_token, 8)
	watch_signals(session)
	session._accept_reconnected_player(guest.player_id, guest.reconnect_token, 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_signal_emitted_with_parameters(session, "player_presence_changed",
		[guest.player_id, "connected", "客机", false])
	session.free()


func test_retry_room_hello_while_awaiting() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session._awaiting_room_accept = true
	session.local_reconnect_token = "tok"
	assert_true(session.can_retry_room_hello())
	assert_true(session.retry_room_hello())
	assert_eq(session._hello_retry_attempts, 1)
	assert_gt(session._hello_retry_at_ms, 0)
	session._awaiting_room_accept = false
	assert_false(session.can_retry_room_hello())
	assert_false(session.retry_room_hello())
	session.free()


func test_playing_awaiting_room_already_started_schedules_hello_retry() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session._awaiting_room_accept = true
	session._transport_connected_override = true
	session._hello_retry_delay_ms = NetProtocol.HELLO_RETRY_INITIAL_MS
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.ERROR, {
		"code": NetProtocol.ERROR_ROOM_ALREADY_STARTED,
		"detail": "房间已开始",
	}))
	assert_true(session._awaiting_room_accept)
	assert_gt(session._hello_retry_at_ms, 0)
	assert_signal_not_emitted(session, "network_error")
	session.free()


func test_playing_awaiting_invalid_token_retries_when_transport_connected() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "playing"
	session._awaiting_room_accept = true
	session._transport_connected_override = true
	session._hello_used_reconnect = true
	session._pending_nickname = "客机"
	session.local_reconnect_token = "tok"
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.ERROR, {
		"code": NetProtocol.ERROR_INVALID_TOKEN,
		"detail": "重连凭证无效或已过期",
	}))
	assert_eq(session.local_reconnect_token, "tok", "对局中重连失败时应继续用原凭证重试")
	assert_true(session._hello_used_reconnect)
	assert_true(session._awaiting_room_accept)
	assert_gt(session._hello_retry_at_ms, 0)
	assert_signal_not_emitted(session, "network_error")
	session.free()


func test_closed_phase_invalid_token_falls_back_to_join() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "closed"
	session._awaiting_room_accept = true
	session._transport_connected_override = true
	session._hello_used_reconnect = true
	session._pending_nickname = "v"
	session.local_reconnect_token = "stale-tok"
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.ERROR, {
		"code": NetProtocol.ERROR_INVALID_TOKEN,
		"detail": "重连凭证无效或已过期",
	}))
	assert_false(session._hello_used_reconnect)
	assert_eq(session.local_reconnect_token, "")
	assert_eq(session._hello_reconnect_token(), "")
	assert_true(session._awaiting_room_accept)
	assert_signal_not_emitted(session, "network_error")
	assert_signal_emitted_with_parameters(session, "connection_state_changed",
		["connecting", "正在加入房间"])
	session.free()


func test_lobby_reconnect_unknown_token_adds_player() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var before: int = session.registry.players.size()
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": "stale-guest-token",
		"display_name": "v",
	}), 8)
	assert_eq(session.registry.players.size(), before + 1)
	var joined_id: String = session.registry.guest_player_id_for_unique_name("v")
	assert_ne(joined_id, "")
	assert_eq(int(session.registry.players[joined_id].peer_id), 8)
	assert_eq(String(session.registry.players[joined_id].connection_state), "connected")
	session.free()


func test_lobby_reconnect_valid_token_resumes_guest() -> void:
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
	session.registry.disconnect_player(guest.player_id)
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": guest.reconnect_token,
		"display_name": "客机",
	}), 8)
	assert_eq(session.registry.players.size(), 2)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	session.free()


func test_loopback_match_start_does_not_block_guest_reclaim() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("v", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.start_match()
	session.receive_loopback_client_message(NetProtocol.make_message(NetProtocol.MATCH_START, {
		"room_snapshot": session.registry.snapshot(),
	}))
	assert_ne(String(session.registry.players[guest.player_id].get("reconnect_token_hash", "")),
		"", "环回 MATCH_START 不得清掉客机凭证哈希")
	session.registry.disconnect_player(guest.player_id)
	session._handle_reconnect(NetProtocol.make_message(NetProtocol.RECONNECT_REQUEST, {
		"reconnect_token": "stale-token",
		"display_name": "v",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 8)
	assert_eq(String(session.registry.seats[1].control_mode), "human")
	session.free()


func test_rebuild_display_world_clears_view_game() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	var view := Node.new()
	view.name = "ViewGame"
	session._view_game = view
	session.rebuild_display_world()
	assert_eq(session.peek_view_game(), null)
	view.free()
	session.free()


func test_closed_phase_awaiting_room_already_started_retries_hello() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.session_role = "client"
	session.is_host = false
	session.registry.phase = "closed"
	session._awaiting_room_accept = true
	session._transport_connected_override = true
	session._hello_retry_delay_ms = NetProtocol.HELLO_RETRY_INITIAL_MS
	watch_signals(session)
	session._apply_client_inbound_message(NetProtocol.make_message(NetProtocol.ERROR, {
		"code": NetProtocol.ERROR_ROOM_ALREADY_STARTED,
		"detail": "房间已开始",
	}))
	assert_true(session._awaiting_room_accept)
	assert_gt(session._hello_retry_at_ms, 0)
	assert_signal_not_emitted(session, "network_error")
	session.free()


func test_unbound_leave_drops_unique_disconnected_guest() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	session._handle_leave(NetProtocol.make_message(NetProtocol.LEAVE_REQUEST, {
		"display_name": "客机",
	}), 8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"disconnected")
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 0)
	assert_eq(String(session.registry.seats[1].control_mode), "ai")
	session.free()


func test_unbound_peer_disconnect_does_not_drop_live_same_name() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	session.is_host = true
	session.session_role = "host"
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	session.registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "human", "survivor": survivor_b},
	])
	var guest: Dictionary = session.registry.add_player("客机", 3)
	session.registry.bind_seat(1, guest.player_id, "hunter")
	session.registry.start_match()
	session._remember_peer_display_name(8, "客机")
	session._complete_host_peer_disconnected(8)
	assert_eq(int(session.registry.players[guest.player_id].peer_id), 3)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"connected")
	session.free()


func test_unbound_peer_disconnect_drops_unique_disconnected_name() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	var guest: Dictionary = _host_playing_disconnected_guest(session, "客机")
	session._remember_peer_display_name(8, "客机")
	session._complete_host_peer_disconnected(8)
	assert_eq(String(session.registry.players[guest.player_id].connection_state),
		"disconnected")
	assert_eq(String(session.registry.seats[1].control_mode), "ai")
	session.free()


func test_playing_join_reject_detail_for_unknown_name() -> void:
	var session: Node = load("res://src/net/net_session.gd").new()
	_host_playing_disconnected_guest(session, "客机")
	assert_eq(session._playing_join_reject_detail("路人"), "房间已开始（没有可认回的座位）")
	assert_eq(session._playing_join_reject_detail("客机"), "房间已开始")
	session.free()

