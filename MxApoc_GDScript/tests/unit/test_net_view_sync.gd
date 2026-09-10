extends TestBase

## 快照按序号丢旧包；GAME_EVENT 不因序号落后丢弃。

const NetViewSyncScript = preload("res://src/net/net_view_sync.gd")


func test_stale_snapshot_is_rejected() -> void:
	assert_false(NetViewSyncScript.should_apply_snapshot(3, 5))
	assert_true(NetViewSyncScript.should_apply_snapshot(6, 5))
	assert_true(NetViewSyncScript.should_apply_snapshot(0, 5), "无序号快照仍应处理")


func test_event_dedup_uses_sequence_name_and_net_id() -> void:
	var key_a: String = NetViewSyncScript.event_dedup_key(4, "dice_animation", {"net_id": 12})
	var key_b: String = NetViewSyncScript.event_dedup_key(4, "dice_animation", {"card": {"net_id": 12}})
	var key_c: String = NetViewSyncScript.event_dedup_key(5, "dice_animation", {"net_id": 12})
	assert_eq(key_a, key_b)
	assert_ne(key_a, key_c)
