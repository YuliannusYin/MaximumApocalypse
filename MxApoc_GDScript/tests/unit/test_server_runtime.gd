extends TestBase

## 开局等人：座位只认 peer_id > 1 的环回/远端。

var _saved_registry: Variant = null
var _saved_local_player_id: String = ""


func before_each() -> void:
	_saved_registry = NetSession.registry
	_saved_local_player_id = String(NetSession.local_player_id)
	super.before_each()


func after_each() -> void:
	NetSession.registry = _saved_registry
	NetSession.local_player_id = _saved_local_player_id
	super.after_each()


func test_all_expected_bound_requires_peer_id_gt_1() -> void:
	var saved_registry: Variant = NetSession.registry
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	NetSession.registry = registry
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	runtime._owner_player_id = credentials.player_id
	runtime._expected_player_ids = [credentials.player_id]
	assert_false(runtime._all_expected_bound(), "listener 的 peer 1 不能算已移交")
	registry.clear_live_peer(credentials.player_id)
	assert_false(runtime._all_expected_bound(), "清掉 peer 1 后仍应等待环回")
	assert_eq(registry.reconnect_player_by_token(credentials.reconnect_token, 2),
		credentials.player_id)
	assert_true(runtime._all_expected_bound(), "环回 peer>1 后应到齐")
	runtime.free()
	NetSession.registry = saved_registry


func test_begin_match_from_lobby_keeps_existing_loopback_peer() -> void:
	var saved_registry: Variant = NetSession.registry
	var saved_local := String(NetSession.local_player_id)
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	assert_eq(registry.reconnect_player_by_token(credentials.reconnect_token, 2),
		credentials.player_id)
	NetSession.registry = registry
	NetSession.local_player_id = credentials.player_id
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	runtime.begin_match_from_lobby()
	assert_eq(int(registry.players[credentials.player_id].peer_id), 2,
		"大厅已环回时开局不应清掉 owner peer")
	assert_eq(registry.phase, "playing")
	assert_true(runtime._all_expected_bound())
	runtime.free()
	NetSession.local_player_id = saved_local
	NetSession.registry = saved_registry


func test_empty_expected_still_waits_for_owner_loopback() -> void:
	var saved_registry: Variant = NetSession.registry
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "ai", "survivor": survivor},
	])
	NetSession.registry = registry
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	runtime._owner_player_id = credentials.player_id
	runtime._expected_player_ids = []
	registry.clear_live_peer(credentials.player_id)
	assert_false(runtime._all_expected_bound())
	registry.reconnect_player_by_token(credentials.reconnect_token, 5)
	assert_true(runtime._all_expected_bound())
	runtime.free()
	NetSession.registry = saved_registry


func test_visual_relays_bind_and_unbind_event_bus() -> void:
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	var before := EventBus.player_moved.get_connections().size()
	runtime._connect_visual_relays()
	assert_true(EventBus.player_moved.is_connected(runtime._relay_player_moved))
	assert_true(EventBus.block_revealed.is_connected(runtime._relay_block_revealed))
	assert_true(EventBus.block_destroyed.is_connected(runtime._relay_block_destroyed))
	assert_true(EventBus.game_over.is_connected(runtime._relay_game_over))
	assert_true(EventBus.turn_started.is_connected(runtime._relay_turn_started))
	assert_true(EventBus.phase_changed.is_connected(runtime._relay_phase_changed))
	assert_true(EventBus.monster_mark_changed.is_connected(runtime._relay_block_mark_changed))
	assert_true(EventBus.damage_taken.is_connected(runtime._relay_damage_taken))
	assert_true(EventBus.hp_recovered.is_connected(runtime._relay_hp_recovered))
	assert_true(EventBus.player_hunger_changed.is_connected(runtime._relay_hunger_changed))
	assert_true(EventBus.action_consumed.is_connected(runtime._relay_action_consumed))
	assert_true(EventBus.monster_died.is_connected(runtime._relay_monster_died))
	assert_eq(EventBus.player_moved.get_connections().size(), before + 1)
	runtime._connect_visual_relays()
	assert_eq(EventBus.player_moved.get_connections().size(), before + 1,
		"重复连接不应叠多份转播")
	runtime._disconnect_visual_relays()
	assert_false(EventBus.player_moved.is_connected(runtime._relay_player_moved))
	assert_false(EventBus.block_revealed.is_connected(runtime._relay_block_revealed))
	assert_false(EventBus.block_destroyed.is_connected(runtime._relay_block_destroyed))
	assert_false(EventBus.game_over.is_connected(runtime._relay_game_over))
	assert_false(EventBus.turn_started.is_connected(runtime._relay_turn_started))
	assert_false(EventBus.damage_taken.is_connected(runtime._relay_damage_taken))
	assert_eq(EventBus.player_moved.get_connections().size(), before)
	runtime.free()


func test_seed_match_uses_registry_match_seed() -> void:
	var saved_registry: Variant = NetSession.registry
	var registry := NetRegistry.new()
	registry.match_seed = 424242
	NetSession.registry = registry
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	seed(424242)
	var expected: int = randi()
	runtime._seed_match()
	assert_eq(randi(), expected, "权威开局应按 match_seed 播种")
	runtime.free()
	NetSession.registry = saved_registry


func test_handoff_replaces_network_input_with_ai() -> void:
	var saved_registry: Variant = NetSession.registry
	var registry := NetRegistry.new()
	var survivor = DataManager.get_survivor("firefighter")
	var credentials := registry.create_host("房主", 7777, [
		{"type": "human", "survivor": survivor},
	])
	NetSession.registry = registry
	var player: Player = _make_player("房主")
	player.seat_number = 0
	player.is_ai = false
	var network_input := NetworkPlayerInput.new()
	player.input = network_input
	Game.players = [player]
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	runtime._network_inputs = [network_input]
	runtime.handoff_seats_to_ai(credentials.player_id)
	assert_true(player.is_ai)
	assert_true(player.input is AIPlayerInput)
	runtime.restore_network_inputs(credentials.player_id)
	assert_false(player.is_ai)
	assert_true(player.input is NetworkPlayerInput)
	if player.input.has_method("detach"):
		player.input.detach()
	runtime.free()
	NetSession.registry = saved_registry


func test_authority_logs_payload_duplicates_game_log_list() -> void:
	Game.log_list = ["第一行", "第二行"]
	var runtime: Node = load("res://src/net/server_runtime.gd").new()
	var payload: Array = runtime._authority_logs_payload()
	assert_eq(payload, ["第一行", "第二行"])
	payload.append("不应回写")
	assert_eq(Game.log_list, ["第一行", "第二行"], "载荷应是副本")
	runtime.free()
