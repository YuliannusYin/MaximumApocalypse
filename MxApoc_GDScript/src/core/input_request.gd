class_name InputRequest
extends "res://src/core/game_event.gd"

## 带 request_id/owner 的外部输入等待节点。
## 由 EventScheduler 统一创建与匹配；GUIPlayerInput 等兼容外观在此之上包装信号/await API。

var emit_fn: Callable = Callable()
var preemptible: bool = false
var received: bool = false
var response: Variant = null


func _init(
	request_owner: Variant = null,
	emit: Callable = Callable(),
	can_preempt: bool = false
) -> void:
	super._init("input_request", request_owner, null)
	owner = request_owner
	emit_fn = emit
	preemptible = can_preempt


## 请求身份匹配：request_id 与 owner 都一致才算匹配同一次请求。
func matches(request_id: int, request_owner: Variant) -> bool:
	return id == request_id and owner == request_owner


## 写入响应；已响应的请求忽略后续响应（防重复/防双击）。
func respond(value: Variant) -> void:
	if received:
		return
	response = value
	received = true
	complete(value)


func cancel_request(reason: String = "") -> void:
	if received:
		return
	received = true
	response = null
	error = reason
	cancel()


## 派发：调用注册的 emit_fn（通常用于发射 UI 请求信号）。
func emit() -> void:
	if not received and emit_fn.is_valid():
		emit_fn.call()
