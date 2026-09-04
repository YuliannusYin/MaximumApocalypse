class_name EventScheduler
extends RefCounted

## 统一事件调度器。
## 一半职责是 InputRequest 的 LIFO 请求栈（抢占式插入结算，供 GUIPlayerInput 等
## 输入实现复用）；另一半职责是 GameEvent 的运行栈（run/current_event/current_owner，
## 供领域事件按父子关系顺序执行并在异常/取消时正确收束、恢复外层事件）。
## 详见 .cursor/plan/plan.md 批次二。

const InputRequestScript = preload("res://src/core/input_request.gd")
const GameEventScript = preload("res://src/core/game_event.gd")

# === InputRequest 请求栈 ===

var _request_stack: Array = []  # Array[InputRequest]，被抢占的外层请求，栈顶最先恢复
var _active_request: Variant = null  # InputRequest，当前活动请求；null = 无活动请求
var _request_counter: int = 0

# === GameEvent 运行栈 ===

var _event_stack: Array = []  # Array[GameEvent]


## 创建请求并入栈。仅当当前活动请求可抢占时才将其压栈暂停，随后立即派发新请求。
func enqueue_input(owner: Variant, emit_fn: Callable, preemptible: bool = false) -> Variant:
	_request_counter += 1
	var request: Variant = InputRequestScript.new(_request_counter, owner, emit_fn, preemptible)
	if _active_request != null and not _active_request.received and _active_request.preemptible:
		_request_stack.append(_active_request)
		_active_request = null
	_request_stack.append(request)
	_dispatch_next_if_idle()
	return request


## 空闲时弹出栈顶请求并派发（调用其 emit_fn）。
func _dispatch_next_if_idle() -> void:
	if _active_request == null and not _request_stack.is_empty():
		_active_request = _request_stack.pop_back()
		_active_request.emit()


## 当前活动请求的身份。UI 回执应携带这两个值，避免旧弹窗/旧 HUD 误响应。
func get_active_request_id() -> int:
	return _active_request.id if _active_request != null else -1


func get_active_request_owner() -> Variant:
	return _active_request.owner if _active_request != null else null


func get_active_request() -> Variant:
	return _active_request


## 写入当前活动请求的响应；request_id/owner 不匹配或已响应则忽略。
func respond(value: Variant, request_id: int = -1, owner: Variant = null) -> void:
	if _active_request == null:
		return
	if request_id >= 0 and _active_request.id != request_id:
		return
	if owner != null and _active_request.owner != owner:
		return
	_active_request.respond(value)


## 等待指定请求自身的响应；恢复后释放活动槽并弹出栈顶外层请求重新派发。
func wait_request(request: Variant) -> Variant:
	while not request.received:
		await Engine.get_main_loop().process_frame
	if _active_request == request:
		_active_request = null
		_dispatch_next_if_idle()
	return request.response


# === GameEvent 运行栈 ===

## 创建一个未挂接父子关系的独立 GameEvent。调用方可自行决定是否嵌套 run_event。
func create_event(type: String, owner: Variant = null, source: Variant = null) -> Variant:
	return GameEventScript.new(type, owner, source)


## 在事件树中运行一个 GameEvent：入栈、标记 running、执行 executor、
## 标记 completed（除非 executor 内部已将其取消），最后出栈恢复外层事件。
func run_event(event: Variant, executor: Callable) -> Variant:
	_event_stack.append(event)
	if event.status == GameEventScript.Status.PENDING:
		event.mark_running()
	var result: Variant = await executor.call(event)
	if event.status != GameEventScript.Status.CANCELLED:
		event.complete(result)
	_event_stack.pop_back()
	return result


## 当前正在运行的最内层 GameEvent；没有时返回 null。
func get_current_event() -> Variant:
	if _event_stack.is_empty():
		return null
	return _event_stack.back()


## 当前事件的 owner。
func get_current_owner() -> Variant:
	var event: Variant = get_current_event()
	if event == null:
		return null
	return event.owner
