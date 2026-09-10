class_name NetId
extends RefCounted

static var _counter: int = 0
static var _entity_counter: int = 0

static func make_id(prefix: String) -> String:
	_counter += 1
	return "%s_%s_%s" % [prefix, str(Time.get_ticks_usec()), str(_counter)]


static func next() -> int:
	_entity_counter += 1
	return _entity_counter


static func reset() -> void:
	_entity_counter = 0


## 客机联机不分配实体 id，等权威快照盖上。单机、本进程权威、测试分配。
static func should_allocate() -> bool:
	var tree: MainLoop = Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return true
	var net: Node = tree.root.get_node_or_null("NetSession")
	if net == null:
		return true
	if bool(net.get("applying_display_snapshot")):
		return false
	if net.has_method("has_active_server_runtime") and bool(net.call("has_active_server_runtime")):
		return true
	if String(net.get("session_role")) == "client":
		return false
	return true


static func assign(entity: Variant) -> void:
	if entity == null or not should_allocate():
		return
	if not "net_id" in entity:
		return
	entity.net_id = next()
