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
	assert_false(session.is_authority(), "环回后若无 Runtime 则不再是权威")
	session.free()
