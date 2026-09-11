extends TestBase

const NetRegistry = preload("res://src/net/net_registry.gd")

func test_host_registry_binds_human_seats() -> void:
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	assert_ne(credentials.player_id, "")
	assert_ne(credentials.reconnect_token, "")
	assert_eq(registry.players.size(), 1)
	assert_eq(registry.seats.size(), 1)
	assert_eq(registry.seats[0].controller_id, credentials.player_id)
	assert_eq(registry.seats[0].control_mode, "human")

func test_same_survivor_cannot_be_bound_twice() -> void:
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
		{"type": "ai", "survivor": null},
	])
	assert_false(registry.bind_seat(1, "", "firefighter", true))

func test_disconnect_switches_all_owned_seats_to_ai() -> void:
	var registry := NetRegistry.new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	registry.bind_seat(1, credentials.player_id, "hunter")
	registry.disconnect_player(credentials.player_id)
	assert_eq(registry.seats[0].control_mode, "ai")
	assert_eq(registry.seats[1].control_mode, "ai")
	assert_eq(registry.reconnect_player_by_token(credentials.reconnect_token, 9),
		credentials.player_id)
	assert_eq(registry.seats[0].control_mode, "human")
	assert_eq(registry.seats[1].control_mode, "human")


func test_clear_live_peer_keeps_human_seat_and_unbound() -> void:
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	registry.clear_live_peer(credentials.player_id)
	assert_eq(int(registry.players[credentials.player_id].peer_id), 0)
	assert_eq(registry.players[credentials.player_id].connection_state, "connected")
	assert_eq(registry.seats[0].control_mode, "human")
	assert_false(registry.is_player_live_bound(credentials.player_id))
	assert_eq(registry.reconnect_player_by_token(credentials.reconnect_token, 4),
		credentials.player_id)
	assert_true(registry.is_player_live_bound(credentials.player_id))


func test_connected_human_ids_and_timeout_convert() -> void:
	var registry := NetRegistry.new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var host := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest := registry.add_player("客机", 3)
	registry.bind_seat(1, guest.player_id, "hunter")
	var human_ids: Array = registry.connected_human_player_ids()
	assert_true(human_ids.has(host.player_id))
	assert_true(human_ids.has(guest.player_id))
	registry.convert_unbound_human_to_ai(guest.player_id)
	assert_eq(registry.seats[1].control_mode, "ai")
	assert_eq(registry.players[guest.player_id].connection_state, "disconnected")
	assert_false(registry.is_player_live_bound(guest.player_id))


func test_bind_seat_rejected_while_playing() -> void:
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
		{"type": "ai", "survivor": null},
	])
	registry.start_match()
	assert_false(registry.bind_seat(1, credentials.player_id, "hunter"))
	assert_false(registry.set_seat_survivor(0, "hunter"))


func test_return_to_lobby_allows_bind_seat_again() -> void:
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
		{"type": "ai", "survivor": null},
	])
	registry.start_match()
	assert_eq(registry.phase, "playing")
	registry.set_phase("lobby")
	assert_eq(registry.phase, "lobby")
	assert_true(registry.bind_seat(1, credentials.player_id, "hunter"))
	assert_eq(String(registry.seats[1].survivor_id), "hunter")


func test_disconnect_in_lobby_keeps_seat_and_allows_reconnect() -> void:
	var registry := NetRegistry.new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest := registry.add_player("客机", 3)
	registry.bind_seat(1, guest.player_id, "hunter")
	registry.disconnect_player(guest.player_id)
	assert_eq(String(registry.players[guest.player_id].connection_state), "disconnected")
	assert_eq(String(registry.seats[1].controller_id), guest.player_id)
	assert_eq(String(registry.seats[1].control_mode), "ai")
	assert_eq(registry.reconnect_error_for_token(guest.reconnect_token), "")
	assert_eq(registry.reconnect_player_by_token(guest.reconnect_token, 8),
		guest.player_id)
	assert_eq(String(registry.seats[1].control_mode), "human")


func test_disconnect_while_playing_keeps_controller_and_allows_reconnect() -> void:
	var registry := NetRegistry.new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest := registry.add_player("客机", 3)
	registry.bind_seat(1, guest.player_id, "hunter")
	registry.start_match()
	registry.disconnect_player(guest.player_id)
	assert_eq(String(registry.seats[1].controller_id), guest.player_id)
	assert_eq(String(registry.seats[1].control_mode), "ai")
	assert_eq(registry.reconnect_error_for_token(guest.reconnect_token), "")
	assert_eq(registry.reconnect_player_by_token(guest.reconnect_token, 8),
		guest.player_id)
	assert_eq(String(registry.seats[1].control_mode), "human")


func test_stale_connected_guest_ids_skips_host() -> void:
	var registry := NetRegistry.new()
	var survivor_a = DataManager.get_survivor("firefighter")
	var survivor_b = DataManager.get_survivor("hunter")
	var host := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor_a},
		{"type": "ai", "survivor": survivor_b},
	])
	var guest := registry.add_player("客机", 3)
	registry.bind_seat(1, guest.player_id, "hunter")
	registry.start_match()
	registry.players[host.player_id]["last_seen_ms"] = 0
	registry.players[guest.player_id]["last_seen_ms"] = 0
	var stale: Array = registry.stale_connected_guest_ids(40000, NetProtocol.HEARTBEAT_TIMEOUT_MS)
	assert_eq(stale, [guest.player_id], "超时只应列出客机，不含房主")
	registry.touch_last_seen(guest.player_id)
	var now := Time.get_ticks_msec()
	assert_eq(registry.stale_connected_guest_ids(now, NetProtocol.HEARTBEAT_TIMEOUT_MS).size(), 0)
