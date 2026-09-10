extends TestBase

## 开局等人：座位只认 peer_id > 1 的环回/远端。

var _saved_registry: Variant = null


func before_each() -> void:
	_saved_registry = NetSession.registry
	super.before_each()


func after_each() -> void:
	NetSession.registry = _saved_registry
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
