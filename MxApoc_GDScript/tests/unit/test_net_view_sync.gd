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


func test_log_events_with_same_sequence_are_not_collapsed() -> void:
	var key_a: String = NetViewSyncScript.event_dedup_key(8, "log", {"message": "增加了 1 点饥饿值"})
	var key_b: String = NetViewSyncScript.event_dedup_key(8, "log", {"message": "因饥饿受到 2 点伤害"})
	assert_ne(key_a, key_b, "同序号多条日志应按文案区分，不能互相去重")


func test_append_guest_log_skips_authority() -> void:
	var logs: Array = ["已有"]
	NetViewSyncScript.append_guest_log(logs, "客机不应写入", true)
	assert_eq(logs, ["已有"], "房主已在 log_message 写过，不能再追加")


func test_append_guest_log_writes_for_client() -> void:
	var logs: Array = []
	NetViewSyncScript.append_guest_log(logs, "座位1 移动了", false)
	assert_eq(logs, ["座位1 移动了"])


func test_apply_game_over_logs_replaces_list() -> void:
	var logs: Array = ["旧1", "旧2"]
	NetViewSyncScript.apply_game_over_logs(logs, ["全量A", "全量B", "全量C"])
	assert_eq(logs, ["全量A", "全量B", "全量C"], "结束时应覆盖为权威全量")


func test_apply_game_over_logs_ignores_non_array() -> void:
	var logs: Array = ["保留"]
	NetViewSyncScript.apply_game_over_logs(logs, {})
	assert_eq(logs, ["保留"], "非法载荷不应清空已有日志")


func test_copy_event_log_if_empty_only_when_empty() -> void:
	var empty_logs: Array = []
	NetViewSyncScript.copy_event_log_if_empty(empty_logs, ["临时1", "临时2"])
	assert_eq(empty_logs, ["临时1", "临时2"])
	var kept: Array = ["权威"]
	NetViewSyncScript.copy_event_log_if_empty(kept, ["临时"])
	assert_eq(kept, ["权威"], "已有 log_list 时不应被临时日志覆盖")
