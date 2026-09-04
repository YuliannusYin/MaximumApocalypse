class_name GameEvent
extends RefCounted

## 统一事件树节点。
## 为 EventSystem 的 Dictionary 事件、OperationRuntime 的操作事件、
## Player 正式回合/阶段事件提供共享的生命周期字段与父子关系。
## 详见 .cursor/plan/plan.md “最终架构”。

enum Status { PENDING, RUNNING, COMPLETED, CANCELLED, FAILED }

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
	type = init_type
	owner = init_owner
	source = init_source


## 挂接子事件：设置子事件 parent/root，并加入 children。
func add_child(child: GameEvent) -> void:
	child.parent = self
	child.root = root if root != 0 else id
	children.append(child)


func mark_running() -> void:
	status = Status.RUNNING


func complete(value: Variant = null) -> void:
	result = value
	status = Status.COMPLETED


func cancel() -> void:
	status = Status.CANCELLED


func fail(err: String = "") -> void:
	error = err
	status = Status.FAILED


func is_finished() -> bool:
	return status == Status.COMPLETED or status == Status.CANCELLED or status == Status.FAILED
