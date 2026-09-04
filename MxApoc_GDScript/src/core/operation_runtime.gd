class_name OperationRuntime
extends RefCounted

## 游戏操作事件运行时。
## 负责在一个规则/技能结算上下文中，按登记顺序串行执行操作。
## 领域方法本身仍拥有 before/on/after 钩子和 EventBus 通知；本类提供
## 父子操作的栈式编排能力，子操作完成后才恢复父操作。

var _operations: Array[Dictionary] = []
var _is_flushing: bool = false
var _stack: Array[Dictionary] = []


## 立即执行一个操作。操作执行期间触发的子操作会压到栈顶，
## 子操作完成后才恢复父操作。
## owner 是实际执行操作的玩家，source 是发起该操作的玩家。
## kind/rules 为操作策略元数据，供目标玩家操作和 UI 路由读取。
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
	var parent: Variant = _stack.back() if not _stack.is_empty() else null
	var inherited_owner: Variant = parent.get("owner", null) if parent is Dictionary else null
	var inherited_source: Variant = parent.get("source", null) if parent is Dictionary else null
	var inherited_kind: String = str(parent.get("kind", "")) if parent is Dictionary else ""
	var inherited_context: Variant = parent.get("context", null) if parent is Dictionary else null
	var operation_context: Variant = context if not context.is_empty() else inherited_context
	var operation: Dictionary = EventSystem.create_event({
		"operation_name": operation_name,
		"payload": payload,
		"status": "pending",
		"result": null,
		"error": "",
		"parent": parent,
		"owner": owner if owner != null else inherited_owner,
		"source": source if source != null else inherited_source,
		"kind": kind if kind != "" else inherited_kind,
		"rules": rules.duplicate(true),
		"context": operation_context,
	})
	operation["executor"] = executor
	var node: Variant = operation.get("game_event", null)
	if EventSystem.is_cancelled(operation):
		operation["status"] = "cancelled"
		if node != null:
			node.cancel()
		return null
	_stack.append(operation)
	operation["status"] = "running"
	if node != null:
		node.mark_running()
	operation["result"] = await executor.call()
	operation["status"] = "completed"
	if node != null:
		node.complete(operation["result"])
	_stack.pop_back()
	return operation["result"]


## 当前正在执行的最内层操作事件；没有操作时返回空字典。
func get_current_operation() -> Dictionary:
	if _stack.is_empty():
		return {}
	return _stack.back()


## 当前操作的实际执行者。它不等同于 GameStateMachine.current_player。
func get_current_owner() -> Variant:
	return get_current_operation().get("owner", null)


## 当前操作的发起者。
func get_current_source() -> Variant:
	return get_current_operation().get("source", null)


## 当前操作上下文。有限行动的剩余预算存放在这里，而不是 Player 正式字段。
func get_current_context() -> Dictionary:
	var context: Variant = get_current_operation().get("context", null)
	return context if context is Dictionary else {}


## 创建独立于 Player 正式状态的有限行动上下文。
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


## 登记一个待执行操作。executor 必须是无参 Callable，可为协程。
## 返回的 Dictionary 是稳定的操作句柄；调用方可在父流程完成后读取 status/result。
func enqueue(
	operation_name: String,
	executor: Callable,
	payload: Dictionary = {},
	owner: Variant = null,
	source: Variant = null,
	kind: String = "",
	rules: Dictionary = {}
) -> Dictionary:
	var operation: Dictionary = EventSystem.create_event({
		"operation_name": operation_name,
		"payload": payload,
		"status": "pending",
		"result": null,
		"error": "",
		"owner": owner,
		"source": source,
		"kind": kind,
		"rules": rules.duplicate(true),
	})
	operation["executor"] = executor
	_operations.append(operation)
	return operation


## 按登记顺序排空当前上下文。已取消的操作不会调用 executor。
## executor 抛出的脚本错误仍由引擎报告；运行时保留操作状态便于诊断。
func flush() -> void:
	if _is_flushing:
		return
	_is_flushing = true
	while not _operations.is_empty():
		var operation: Dictionary = _operations.pop_front()
		var node: Variant = operation.get("game_event", null)
		if EventSystem.is_cancelled(operation):
			operation["status"] = "cancelled"
			if node != null:
				node.cancel()
			continue
		var executor: Callable = operation.get("executor", Callable())
		if not executor.is_valid():
			operation["status"] = "failed"
			operation["error"] = "操作没有有效执行器"
			if node != null:
				node.fail(operation["error"])
			continue
		operation["status"] = "running"
		if node != null:
			node.mark_running()
		operation["result"] = await executor.call()
		operation["status"] = "completed"
		if node != null:
			node.complete(operation["result"])
	_is_flushing = false


func has_pending_operations() -> bool:
	return not _operations.is_empty()
