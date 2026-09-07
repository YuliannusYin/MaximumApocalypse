class_name GameEvent
extends RefCounted

## 统一事件树节点。
## 为 EventSystem 的 Dictionary 事件、领域操作、
## Player 正式回合/阶段事件提供共享的生命周期字段与父子关系。
## 详见 GameDesignDocus/GameSystem/Core/EventScheduler.md。

enum Status { PENDING, RUNNING, COMPLETED, CANCELLED, FAILED }

static var _next_id: int = 1

var id: int = 0
var type: String = ""
var owner: Variant = null
var source: Variant = null
var parent: Variant = null  # GameEvent
var root: int = 0
var status: int = Status.PENDING
## 调度完成值（run_event 返回值）。JSON schema 的 event.result 走 data["result"]，避免撞名。
var completion: Variant = null
var error: String = ""
var data: Dictionary = {}
var context: Variant = null
var children: Array = []  # Array[GameEvent]
## JSON event["cancel"].call() 走真实属性，避免动态编译脚本不走 _get。
var cancel: Callable = Callable()
## JSON event.trigger_name；与 data["trigger_name"] 同步。
var trigger_name: String = ""


func _init(init_type: String = "", init_owner: Variant = null, init_source: Variant = null) -> void:
	id = _next_id
	_next_id += 1
	root = id
	type = init_type
	owner = init_owner
	source = init_source
	cancel = Callable(self, "mark_cancelled")


## 挂接子事件：设置子事件 parent/root，并加入 children。
func add_child(child: GameEvent) -> void:
	if child == null or child == self:
		return
	if child.parent != null and child.parent != self:
		return
	if children.has(child):
		return
	child.parent = self
	child.root = root if root != 0 else id
	children.append(child)


func mark_running() -> void:
	if status == Status.PENDING:
		status = Status.RUNNING


func complete(value: Variant = null) -> void:
	if is_finished():
		return
	completion = value
	status = Status.COMPLETED


## 将本节点标为取消。JSON 侧请用 EventSystem.cancel(event) 或 event["cancel"].call()，
## 不要依赖与方法同名的 event.cancel 属性。
func mark_cancelled() -> void:
	if is_finished():
		return
	status = Status.CANCELLED
	data["cancelled"] = true


func fail(err: String = "") -> void:
	if is_finished():
		return
	error = err
	status = Status.FAILED


func is_finished() -> bool:
	return status == Status.COMPLETED or status == Status.CANCELLED or status == Status.FAILED


## Dictionary 兼容：JSON / 技能四参可读 event.num、event["card"]、event["cancel"]。
## 项目内静态脚本不要写 event.get(key, default)：引擎 Object.get 只接受 1 个参数。
## CodeExecutor 动态编译的 JSON 两参 get 会走本方法；静态脚本请用 get_or / EventSystem.get_field / []。
@warning_ignore("native_method_override")
func get(key: Variant, default: Variant = null) -> Variant:
	return _lookup(str(key), default)


func get_or(key: Variant, default: Variant = null) -> Variant:
	return _lookup(str(key), default)


func has(key: Variant) -> bool:
	var name: String = str(key)
	if name in ["id", "type", "owner", "source", "parent", "root", "status", "error", "data", "context", "children", "cancelled", "cancel", "game_event", "completion", "trigger_name"]:
		return true
	return data.has(name)


func erase(key: Variant) -> void:
	data.erase(str(key))


func _get(property: StringName) -> Variant:
	return _lookup(String(property), null)


func _set(property: StringName, value: Variant) -> bool:
	var name: String = String(property)
	if name == "cancelled":
		if value:
			mark_cancelled()
			data["cancelled"] = true
		else:
			data["cancelled"] = false
		return true
	if name == "cancel" or name == "game_event" or name == "completion":
		return true
	if name == "trigger_name":
		trigger_name = str(value)
		data["trigger_name"] = trigger_name
		return true
	if name in ["id", "type", "owner", "source", "parent", "root", "status", "error", "data", "context", "children"]:
		return false
	data[name] = value
	return true


func _lookup(name: String, default: Variant) -> Variant:
	match name:
		"id":
			return id
		"type":
			if data.has("type"):
				return data["type"]
			return type
		"owner":
			return owner
		"source":
			return source
		"parent":
			return parent
		"root":
			return root
		"status":
			return status
		"completion":
			return completion
		"result":
			if data.has("result"):
				return data["result"]
			return default
		"error":
			return error
		"data":
			return data
		"context":
			return context
		"children":
			return children
		"cancelled":
			return status == Status.CANCELLED or bool(data.get("cancelled", false))
		"cancel":
			return cancel
		"trigger_name":
			return trigger_name
		"game_event":
			return self
	if data.has(name):
		return data[name]
	return default
