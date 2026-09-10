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
