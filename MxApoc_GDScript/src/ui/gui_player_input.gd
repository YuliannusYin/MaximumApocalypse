class_name GUIPlayerInput
extends IPlayerInput

## GUI 玩家输入实现。
## 通过信号与 GameScene2D 通信，使用 await 等待玩家操作。
## 输入请求按后进先出栈处理：空闲时立即派发（emit 请求信号）。
## 仅 wait_action 可被抢占：插入结算（确认/动画/选牌）会立刻盖住它，
## 结算后弹出栈顶并重新派发 wait_action。其它活动请求（选牌/确认等）
## 不会被后来的 wait_action 打断，避免弹窗被游戏循环抢走后反复重开。
## respond_* 方法写入当前活动请求的响应；已响应的请求忽略重复响应（防双击）。
##
## 请求栈的 LIFO 抢占/身份匹配逻辑已下沉到 EventScheduler/InputRequest（统一事件调度，
## 见 .cursor/plan/plan.md 批次二）；本类只是保留旧 signal/respond_* API 的兼容外观。

# === 请求信号（GameScene2D 订阅） ===

signal action_requested(player: Variant)
signal request_owner_changed(player: Variant)
signal choose_requested(options: Array, prompt: String)
signal choose_card_requested(n: int, param: Variant, filter: Variant, prompt: String, min_n: int)
signal choose_target_requested(n: int, skill: Variant, prompt: String, min_n: int)
signal choose_block_requested(blocks: Array, prompt: String)
signal choose_block_inline_requested(valid_blocks: Array, prompt: String, count: int)
signal confirm_requested(message: String)
signal show_card_requested(card: Card, target: Variant)
signal set_prompt_requested(text: String)
signal redraw_decision_requested()
signal judge_confirm_requested(prompt: String, allow_cancel: bool)
signal dice_animation_requested(d1: int, d2: int, label: String, outcome: String)
signal monster_draw_animation_requested(player: Variant, card: Variant)
signal scavenge_draw_animation_requested(player: Variant, card: Variant)
signal card_destroy_animation_requested(card: Card)
signal monster_skill_trigger_animation_requested(monster: Variant)
signal monster_attack_animation_requested(monster: Variant, targets: Array)

# === 请求栈（插入结算机制核心） ===
# 后进先出：新请求入栈；仅当活动请求是可抢占的 wait_action 时才压栈暂停并立即派发。
# 结算后弹出栈顶恢复外层。抢占/身份匹配/等待逻辑均委托给 EventScheduler/InputRequest。
var _scheduler: Variant = null
var _request_owner: Variant = null  # 下一次输入请求的所属玩家

const SYSTEM_OWNER: String = "__system__"


# === 栈核心 ===

## 设置下一次输入请求的所属玩家。
func set_request_owner(player: Variant) -> void:
	_request_owner = player


func set_event_scheduler(scheduler: Variant) -> void:
	_scheduler = scheduler


func _get_event_scheduler() -> Variant:
	return _scheduler if _scheduler != null else Game.event_scheduler


## 创建请求并入栈。仅当当前活动请求可抢占（wait_action）时才将其压栈暂停。
## request_owner_changed 在请求实际派发（emit）的那一刻发出，与旧实现时序一致，
## 无论是新请求立即派发，还是外层请求在内层结算后被重新派发。
func _enqueue_request(emit_fn: Callable, preemptible: bool = false) -> Variant:
	var owner: Variant = _request_owner if _request_owner != null else SYSTEM_OWNER
	_request_owner = null
	var wrapped_emit: Callable = func() -> void:
		request_owner_changed.emit(owner)
		emit_fn.call()
	return _get_event_scheduler().enqueue_input(owner, wrapped_emit, preemptible)


## 当前活动请求的身份。UI 回执应携带这两个值，避免旧弹窗/旧 HUD 误响应。
func get_active_request_id() -> int:
	return _get_event_scheduler().get_active_request_id()


func get_active_request_owner() -> Variant:
	return _get_event_scheduler().get_active_request_owner()


## UI 观察接口：返回 EventScheduler 当前活动的 InputRequest。
func get_active_request() -> Variant:
	return _get_event_scheduler().get_current_input_request()


func get_scheduler() -> Variant:
	return _get_event_scheduler()


## 等待指定请求自身的响应；恢复后释放活动槽并弹出栈顶外层请求。
func _wait_for_request(req: Variant) -> Variant:
	return await _get_event_scheduler().wait_request(req)


func _respond_active_with_identity(value: Variant, request_id: int, owner: Variant) -> void:
	_get_event_scheduler().respond(value, request_id, owner)


## Godot 的 bool() 构造只接受 bool/int/float；取消请求会留下 null，直接 bool(null) 会崩。
func _as_bool(result: Variant) -> bool:
	return result if typeof(result) == TYPE_BOOL else false


# === IPlayerInput 实现 ===

func wait_action(player: Variant) -> Variant:
	set_request_owner(player)
	var req: Variant = _enqueue_request(func() -> void:
		action_requested.emit(player), true)
	return await _wait_for_request(req)


func choose(options: Array, prompt: String = "") -> Variant:
	var req: Variant = _enqueue_request(func() -> void:
		choose_requested.emit(options, prompt))
	return await _wait_for_request(req)


func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	var req: Variant = _enqueue_request(func() -> void:
		choose_card_requested.emit(n, param, filter, prompt, min_n))
	var result: Variant = await _wait_for_request(req)
	if result is Array:
		return result
	return []


func choose_target(n: int, skill: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	var req: Variant = _enqueue_request(func() -> void:
		choose_target_requested.emit(n, skill, prompt, min_n))
	var result: Variant = await _wait_for_request(req)
	if result is Array:
		return result
	return []


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	var req: Variant = _enqueue_request(func() -> void:
		choose_block_requested.emit(blocks, prompt))
	return await _wait_for_request(req)


func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	var req: Variant = _enqueue_request(func() -> void:
		choose_block_inline_requested.emit(valid_blocks, prompt, count))
	var result: Variant = await _wait_for_request(req)
	if result is Array:
		return result
	return []


func confirm(message: String) -> bool:
	var req: Variant = _enqueue_request(func() -> void:
		confirm_requested.emit(message))
	var result: Variant = await _wait_for_request(req)
	return _as_bool(result)


func show_card(card: Card, target: Variant) -> void:
	var owner: Variant = _request_owner
	_request_owner = null
	if owner != null:
		request_owner_changed.emit(owner)
	show_card_requested.emit(card, target)


## 设置 prompt 区文本（fire-and-forget，不等待响应）。
func set_prompt(text: String) -> void:
	var owner: Variant = _request_owner
	_request_owner = null
	if owner != null:
		request_owner_changed.emit(owner)
	set_prompt_requested.emit(text)


## 等待玩家重调决策。发射信号请求 UI 显示重调界面，await 响应后返回。
func wait_redraw_decision(player: Variant) -> bool:
	set_request_owner(player)
	var req: Variant = _enqueue_request(func() -> void:
		redraw_decision_requested.emit())
	var result: Variant = await _wait_for_request(req)
	return _as_bool(result)


## 检定确认门。发射信号请求 UI 显示确认门，await 响应后返回（true=执行 / false=放弃）。
func wait_judge_confirm(player: Variant, prompt: String, allow_cancel: bool) -> bool:
	set_request_owner(player)
	var req: Variant = _enqueue_request(func() -> void:
		judge_confirm_requested.emit(prompt, allow_cancel))
	var result: Variant = await _wait_for_request(req)
	return _as_bool(result)


## 播放两颗骰子投掷动画并等待结束。动画播完后由 UI 调用 respond_dice_animation 结算，期间阻塞后续请求派发。
func play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	var req: Variant = _enqueue_request(func() -> void:
		dice_animation_requested.emit(d1, d2, label, outcome))
	await _wait_for_request(req)


## 播放抓取怪物牌动画并等待结束。动画播完后由 UI 调用 respond_monster_draw_animation 结算，期间阻塞后续请求派发。
func play_monster_draw_animation(player: Variant, card: Variant) -> void:
	var req: Variant = _enqueue_request(func() -> void:
		monster_draw_animation_requested.emit(player, card))
	await _wait_for_request(req)


## 播放抓取拾荒牌"抓取时"技能触发动画并等待结束。动画播完后由 UI 调用 respond_scavenge_draw_animation 结算，期间阻塞后续请求派发。
func play_scavenge_draw_animation(player: Variant, card: Variant) -> void:
	var req: Variant = _enqueue_request(func() -> void:
		scavenge_draw_animation_requested.emit(player, card))
	await _wait_for_request(req)


## 播放卡牌移出游戏动画并等待结束。动画由 UI 完成后回执，期间阻塞后续请求派发。
func play_card_destroy_animation(card: Card) -> void:
	var req: Variant = _enqueue_request(func() -> void:
		card_destroy_animation_requested.emit(card))
	await _wait_for_request(req)


## 播放触发怪物技能动画并等待结束。动画播完后由 UI 调用 respond_monster_skill_trigger_animation 结算，期间阻塞后续请求派发。
func play_monster_skill_trigger_animation(monster: Variant) -> void:
	var req: Variant = _enqueue_request(func() -> void:
		monster_skill_trigger_animation_requested.emit(monster))
	await _wait_for_request(req)


## 播放怪物攻击动画并等待结束。动画播完后由 UI 调用 respond_monster_attack_animation 结算，期间阻塞后续请求派发。
func play_monster_attack_animation(monster: Variant, targets: Array) -> void:
	var req: Variant = _enqueue_request(func() -> void:
		monster_attack_animation_requested.emit(monster, targets))
	await _wait_for_request(req)


# === 响应方法（GameScene2D 调用，写入当前活动请求） ===

func respond_action(choice: Variant, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(choice, request_id, owner)


func respond_choose(choice: Variant, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(choice, request_id, owner)


func respond_choose_card(cards: Array, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(cards, request_id, owner)


func respond_choose_target(targets: Array, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(targets, request_id, owner)


func respond_choose_block(blocks: Variant, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(blocks, request_id, owner)


func respond_confirm(result: bool, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(result, request_id, owner)


func respond_redraw_decision(result: bool, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(result, request_id, owner)


func respond_judge_confirm(result: bool, request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(result, request_id, owner)


func respond_dice_animation(request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(null, request_id, owner)


func respond_monster_draw_animation(request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(null, request_id, owner)


func respond_scavenge_draw_animation(request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(null, request_id, owner)


func respond_card_destroy_animation(request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(null, request_id, owner)


func respond_monster_skill_trigger_animation(request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(null, request_id, owner)


func respond_monster_attack_animation(request_id: int, owner: Variant) -> void:
	_respond_active_with_identity(null, request_id, owner)
