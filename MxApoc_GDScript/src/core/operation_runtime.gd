class_name OperationRuntime
extends RefCounted

## 游戏操作事件运行时。
## 负责在一个规则/技能结算上下文中，按登记顺序串行执行操作。
## 领域方法本身仍拥有 before/on/after 钩子和 EventBus 通知；本类只提供
## 「不必在 JSON content 中逐项 await」的父子操作编排能力。

var _operations: Array[Dictionary] = []
var _is_flushing: bool = false


## 登记一个待执行操作。executor 必须是无参 Callable，可为协程。
## 返回的 Dictionary 是稳定的操作句柄；调用方可在父流程完成后读取 status/result。
func enqueue(operation_name: String, executor: Callable, payload: Dictionary = {}) -> Dictionary:
	var operation: Dictionary = EventSystem.create_event({
		"operation_name": operation_name,
		"payload": payload,
		"status": "pending",
		"result": null,
		"error": "",
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
		if EventSystem.is_cancelled(operation):
			operation["status"] = "cancelled"
			continue
		var executor: Callable = operation.get("executor", Callable())
		if not executor.is_valid():
			operation["status"] = "failed"
			operation["error"] = "操作没有有效执行器"
			continue
		operation["status"] = "running"
		operation["result"] = await executor.call()
		operation["status"] = "completed"
	_is_flushing = false


func has_pending_operations() -> bool:
	return not _operations.is_empty()
