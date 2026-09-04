class_name GameEvent
extends RefCounted

## 统一事件树节点。
## 为 EventSystem 的 Dictionary 事件、领域操作、
## Player 正式回合/阶段事件提供共享的生命周期字段与父子关系。
## 详见 .cursor/plan/plan.md “最终架构”。

enum Status { PENDING, RUNNING, COMPLETED, CANCELLED, FAILED }

static var _next_id: int = 1

var id: int = 0
var type: String = ""
var owner: Variant = null
var source: Variant = null
var parent: Variant = null  # GameEvent
var root: int = 0
var status: int = Status.PENDING
var result: Variant = null
var error: String = ""
var data: Dictionary = {}
var context: Variant = null
var children: Array = []  # Array[GameEvent]


func _init(init_type: String = "", init_owner: Variant = null, init_source: Variant = null) -> void:
	id = _next_id
	_next_id += 1
	root = id
	type = init_type
	owner = init_owner
	source = init_source


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
	result = value
	status = Status.COMPLETED


func cancel() -> void:
	if is_finished():
		return
	status = Status.CANCELLED


func fail(err: String = "") -> void:
	if is_finished():
		return
	error = err
	status = Status.FAILED


func is_finished() -> bool:
	return status == Status.COMPLETED or status == Status.CANCELLED or status == Status.FAILED
