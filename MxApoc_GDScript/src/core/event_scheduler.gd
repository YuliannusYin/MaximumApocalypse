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
var _operations: Array[Dictionary] = []
var _is_flushing: bool = false

# === GameEvent 运行栈 ===

var _event_stack: Array = []  # Array[GameEvent]
var _operation_stack: Array[Dictionary] = []


## 创建请求并入栈。仅当当前活动请求可抢占时才将其压栈暂停，随后立即派发新请求。
func enqueue_input(owner: Variant, emit_fn: Callable, preemptible: bool = false) -> Variant:
	var request: Variant = InputRequestScript.new(owner, emit_fn, preemptible)
	if _active_request != null and not _active_request.received and _active_request.preemptible:
		_request_stack.append(_active_request)
		_active_request = null
	_request_stack.append(request)
	_dispatch_next_if_idle()
	return request


## 空闲时弹出栈顶请求并派发（调用其 emit_fn）。
func _dispatch_next_if_idle() -> void:
	if _active_request != null:
		return
	while not _request_stack.is_empty():
		var request: Variant = _request_stack.pop_back()
		if request.received:
			continue
		_active_request = request
		_active_request.emit()
		return


## 当前活动请求的身份。UI 回执应携带这两个值，避免旧弹窗/旧 HUD 误响应。
func get_active_request_id() -> int:
	return _active_request.id if _active_request != null else -1


func get_active_request_owner() -> Variant:
	return _active_request.owner if _active_request != null else null


func get_active_request() -> Variant:
	return _active_request


## 当前 InputRequest 的只读别名，供 UI 观察当前等待节点。
## 不暴露请求栈，UI 只能依据当前活动请求刷新自身。
func get_current_input_request() -> Variant:
	return _active_request


func get_current_input_request_id() -> int:
	return get_active_request_id()


func get_current_input_request_owner() -> Variant:
	return get_active_request_owner()


## 写入当前活动请求的响应；request_id/owner 不匹配或已响应则忽略。
func respond(value: Variant, request_id: int, owner: Variant) -> void:
	if _active_request == null:
		return
	if not _active_request.matches(request_id, owner):
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

## 创建一个 GameEvent。若当前已有事件，则自动挂接为其子事件。
func create_event(type: String, owner: Variant = null, source: Variant = null) -> Variant:
	var event: Variant = GameEventScript.new(type, owner, source)
	_attach_event(event)
	return event


func _attach_event(event: Variant) -> void:
	if event == null or not (event is GameEventScript):
		return
	var current: Variant = get_current_event()
	if current != null and current != event and event.parent == null:
		current.add_child(event)


## 在事件树中运行一个 GameEvent，并保证正常/取消/失败状态不会互相覆盖。
func run_event(event: Variant, executor: Callable) -> Variant:
	if event == null or not (event is GameEventScript):
		return null
	_attach_event(event)
	if event.is_finished():
		return event.result
	if event.status == GameEventScript.Status.PENDING:
		event.mark_running()
	if not executor.is_valid():
		event.fail("事件没有有效执行器")
		return null
	_event_stack.append(event)
	var result: Variant = await executor.call(event)
	if not event.is_finished():
		event.complete(result)
	if not _event_stack.is_empty() and _event_stack.back() == event:
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


func get_current_source() -> Variant:
	var event: Variant = get_current_event()
	return event.source if event != null else null


func get_current_operation() -> Dictionary:
	return _operation_stack.back() if not _operation_stack.is_empty() else {}


func get_current_context() -> Dictionary:
	var context: Variant = get_current_operation().get("context", null)
	return context if context is Dictionary else {}


func create_limited_action_context(owner: Variant, source: Variant, action_count: int) -> Dictionary:
	return {
		"kind": "limited_action",
		"owner": owner,
		"source": source,
		"requested_actions": maxi(action_count, 0),
		"remaining_actions": maxi(action_count, 0),
		"consumed_actions": 0,
		"cancelled": false,
		"completed": false,
		"reason": "",
	}


func _new_operation(
	operation_name: String,
	executor: Callable,
	payload: Dictionary,
	owner: Variant,
	source: Variant,
	kind: String,
	rules: Dictionary,
	context: Dictionary
) -> Dictionary:
	var parent: Dictionary = get_current_operation()
	var inherited_owner: Variant = parent.get("owner", null)
	var inherited_source: Variant = parent.get("source", null)
	var inherited_kind: String = str(parent.get("kind", ""))
	var inherited_context: Variant = parent.get("context", null)
	var operation_context: Variant = context if not context.is_empty() else inherited_context
	var resolved_owner: Variant = owner if owner != null else inherited_owner
	var resolved_source: Variant = source if source != null else inherited_source
	var resolved_kind: String = kind if kind != "" else inherited_kind
	var event: Variant = create_event(operation_name, resolved_owner, resolved_source)
	event.data = payload
	event.context = operation_context
	return {
		"operation_name": operation_name,
		"payload": payload,
		"status": "pending",
		"result": null,
		"error": "",
		"parent": parent if not parent.is_empty() else null,
		"owner": resolved_owner,
		"source": resolved_source,
		"kind": resolved_kind,
		"rules": rules.duplicate(true),
		"context": operation_context,
		"executor": executor,
		"game_event": event,
	}


func dispatch(
	operation_name: String,
	executor: Callable,
	payload: Dictionary = {},
	owner: Variant = null,
	source: Variant = null,
	kind: String = "",
	rules: Dictionary = {},
	context: Dictionary = {}
) -> Variant:
	var operation: Dictionary = _new_operation(
		operation_name, executor, payload, owner, source, kind, rules, context
	)
	return await _run_operation(operation)


func _run_operation(operation: Dictionary) -> Variant:
	var event: Variant = operation.get("game_event", null)
	if EventSystem.is_cancelled(operation) or (
		operation.get("game_event", null) != null
		and operation["game_event"].status == GameEventScript.Status.CANCELLED
	):
		operation["status"] = "cancelled"
		if event != null:
			event.cancel()
		return null
	if event == null or not (event is GameEventScript):
		operation["status"] = "failed"
		operation["error"] = "操作缺少事件节点"
		return null
	if not operation.get("executor", Callable()).is_valid():
		operation["status"] = "failed"
		operation["error"] = "操作没有有效执行器"
		event.fail(operation["error"])
		return null
	_operation_stack.append(operation)
	var result: Variant = await run_event(event, func(_event: Variant) -> Variant:
		operation["status"] = "running"
		var value: Variant = await operation["executor"].call()
		operation["result"] = value
		return value
	)
	if event.status == GameEventScript.Status.COMPLETED:
		operation["status"] = "completed"
	elif event.status == GameEventScript.Status.CANCELLED:
		operation["status"] = "cancelled"
	elif event.status == GameEventScript.Status.FAILED:
		operation["status"] = "failed"
		operation["error"] = event.error
	if not _operation_stack.is_empty() and _operation_stack.back() == operation:
		_operation_stack.pop_back()
	return result


func enqueue(
	operation_name: String,
	executor: Callable,
	payload: Dictionary = {},
	owner: Variant = null,
	source: Variant = null,
	kind: String = "",
	rules: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	var operation: Dictionary = _new_operation(
		operation_name, executor, payload, owner, source, kind, rules, context
	)
	_operations.append(operation)
	return operation


func flush() -> void:
	if _is_flushing:
		return
	_is_flushing = true
	while not _operations.is_empty():
		var operation: Dictionary = _operations.pop_front()
		await _run_operation(operation)
	_is_flushing = false


func has_pending_operations() -> bool:
	return not _operations.is_empty()


func reset() -> void:
	if _active_request != null:
		_active_request.cancel_request("调度器已重置")
	for request in _request_stack:
		if request != null:
			request.cancel_request("调度器已重置")
	_request_stack.clear()
	_active_request = null
	_operations.clear()
	_event_stack.clear()
	_operation_stack.clear()
	_is_flushing = false
