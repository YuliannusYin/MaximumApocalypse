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
