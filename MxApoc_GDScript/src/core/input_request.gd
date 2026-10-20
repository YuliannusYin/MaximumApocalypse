class_name InputRequest
extends "res://src/core/game_event.gd"

## 带 request_id/owner 的外部输入等待节点。
## 由 EventScheduler 统一创建与匹配；GUIPlayerInput 等兼容外观在此之上包装信号/await API。

var emit_fn: Callable = Callable()
var preemptible: bool = false
var received: bool = false
var response: Variant = null
var control_epoch: int = 0
var lifecycle: String = "pending" # pending/responded/cancelled/stale
var cancel_reason: String = ""


func _init(
	request_owner: Variant = null,
	emit: Callable = Callable(),
	can_preempt: bool = false,
	epoch: int = 0
) -> void:
	super._init("input_request", request_owner, null)
	owner = request_owner
	emit_fn = emit
	preemptible = can_preempt
	control_epoch = epoch


## 请求身份匹配：request_id 与 owner 都一致才算匹配同一次请求。
## owner 可能是 Player 或 GUI 的系统占位字符串；类型不同时视为不匹配，不能直接 `==`。
func matches(request_id: int, request_owner: Variant, epoch: int = -1) -> bool:
	if id != request_id or not _owners_equal(owner, request_owner):
		return false
	return epoch < 0 or control_epoch == epoch


static func _owners_equal(left: Variant, right: Variant) -> bool:
	if left == null:
		return right == null
	if right == null:
		return false
	if typeof(left) != typeof(right):
		return false
	return left == right


## 写入响应；已响应的请求忽略后续响应（防重复/防双击）。
func respond(value: Variant) -> void:
	if received:
		return
	response = value
	received = true
	lifecycle = "responded"
	complete(value)


func cancel_request(reason: String = "") -> void:
	if received:
		return
	received = true
	response = null
	error = reason
	cancel_reason = reason
	lifecycle = "cancelled"
	mark_cancelled()


## 派发：调用注册的 emit_fn（通常用于发射 UI 请求信号）。
func emit() -> void:
	if not received and emit_fn.is_valid():
		emit_fn.call()
