extends TestBase

## 实体 net_id 分配器与房间 make_id 计数器互不干扰。

var _saved_session_role: String = "none"
var _saved_server_runtime: Variant = null


func before_each() -> void:
	_saved_session_role = String(NetSession.session_role)
	_saved_server_runtime = NetSession.server_runtime
	super.before_each()


func after_each() -> void:
	NetSession.session_role = _saved_session_role
	NetSession.server_runtime = _saved_server_runtime
	super.after_each()


func test_next_and_reset_are_independent_of_make_id() -> void:
	NetId.reset()
	assert_eq(NetId.next(), 1)
	assert_eq(NetId.next(), 2)
	var room_id := NetId.make_id("r")
	assert_true(room_id.begins_with("r_"), "make_id 仍生成房间字符串")
	NetId.reset()
	assert_eq(NetId.next(), 1, "reset 只清实体计数")
	var later := NetId.make_id("p")
	assert_true(later.begins_with("p_"))


func test_assign_sets_entity_net_id() -> void:
	NetId.reset()
	var card: Card = _make_card("x")
	NetId.assign(card)
	assert_eq(card.net_id, 1)


func test_assign_skips_role_card_without_net_id() -> void:
	NetId.reset()
	var role := RoleCard.new()
	NetId.assign(role)
	assert_eq(NetId.next(), 1, "没有 net_id 的对象不应消耗实体计数")


func test_should_allocate_false_for_client_without_runtime() -> void:
	var saved_role := String(NetSession.session_role)
	var saved_runtime: Variant = NetSession.server_runtime
	NetSession.session_role = "client"
	NetSession.server_runtime = null
	assert_false(NetId.should_allocate(), "纯客机不应分配 net_id")
	NetSession.session_role = saved_role
	NetSession.server_runtime = saved_runtime


func test_should_allocate_true_for_host_role() -> void:
	var saved_role := String(NetSession.session_role)
	var saved_runtime: Variant = NetSession.server_runtime
	NetSession.session_role = "host"
	NetSession.server_runtime = null
	assert_true(NetId.should_allocate(), "大厅房主应分配 net_id")
	NetSession.session_role = saved_role
	NetSession.server_runtime = saved_runtime
