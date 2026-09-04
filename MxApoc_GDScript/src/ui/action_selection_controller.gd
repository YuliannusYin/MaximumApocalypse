class_name ActionSelectionController
extends Node

## 行动选择控制器。
## 管理卡牌/牌堆选中状态、确定/取消双用途按钮、prompt 标签、移动选择模式。

signal action_requested(action: Dictionary)
signal confirm_responded(result: bool)
signal move_mode_changed(active: bool)
signal selection_cleared()
signal pile_selection_changed(pile_key: String)
signal card_move_select_completed(block: Variant)
signal redraw_decision_responded(result: bool)
signal judge_confirm_responded(result: bool)

# === 选中状态变量 ===
var _selected_card: Variant = null
var _selected_pile_key: String = ""
var _confirm_button: Button
var _cancel_end_button: Button
var _prompt_label: Label
var _confirm_mode: bool = false
var _move_select_mode: bool = false
var _skill_confirm_mode: bool = false
var _pending_skill: Variant = null
var _move_selected_blocks: Array = []  # 多选：当前选中的地块列表
var _block_select_count: int = 1  # 本次选取的目标数量
var _valid_blocks: Array = []  # 当前合法地块列表
var _card_move_mode: bool = false
var _card_move_valid_blocks: Array = []
var _ui_layer: Node
var _hand_area: Variant = null  # HandDisplayArea 引用，用于清空选中
var _round_zero_mode: bool = false
var _round_zero_buffering: bool = false
var _judge_confirm_mode: bool = false
var _judge_allow_cancel: bool = true
var _timer_bar: ProgressBar = null
var _timer_active: bool = false
var _timer_remaining: float = 0.0
var _timer_duration: float = 0.0
var _timer_on_timeout: Callable = Callable()
var _acting_player: Variant = null
var _event_scheduler: Variant = null


func setup(ui_layer: Node) -> void:
	_ui_layer = ui_layer


func set_hand_area(hand_area: Variant) -> void:
	_hand_area = hand_area


## 设置当前实际操作玩家；为空时回退到真实回合玩家。
func set_acting_player(player: Variant) -> void:
	_acting_player = player
	refresh_confirm_cancel_buttons()


## 注入 EventScheduler 观察器；控制器不再猜测当前输入玩家。
func set_event_scheduler(scheduler: Variant) -> void:
	_event_scheduler = scheduler
	refresh_confirm_cancel_buttons()


func _get_acting_player() -> Variant:
	if _event_scheduler != null and is_instance_valid(_event_scheduler):
		var request: Variant = _event_scheduler.get_current_input_request()
		if request != null and request.owner != null and is_instance_valid(request.owner):
			return request.owner
	if _acting_player != null and is_instance_valid(_acting_player):
		return _acting_player
	return Game.get_current_player()


# === 状态查询 ===

func is_in_move_mode() -> bool:
	return _move_select_mode


func is_in_confirm_mode() -> bool:
	return _confirm_mode


func is_busy() -> bool:
	return _move_select_mode or _confirm_mode or _skill_confirm_mode or _round_zero_mode or _judge_confirm_mode


func get_selected_pile_key() -> String:
	return _selected_pile_key


func _set_selected_pile_key(key: String) -> void:
	if _selected_pile_key == key:
		return
	_selected_pile_key = key
	pile_selection_changed.emit(_selected_pile_key)


func get_move_selected_block() -> Variant:
	if _move_selected_blocks.is_empty():
		return null
	return _move_selected_blocks[0]


## 返回当前选中的地块列表（多选）；空列表表示无选中。
func get_move_selected_blocks() -> Array:
	return _move_selected_blocks


func is_card_move_mode() -> bool:
	return _card_move_mode


func get_card_move_valid_blocks() -> Array:
	return _card_move_valid_blocks


# === 按钮与 prompt 构建 ===

func build_buttons() -> void:
	# 确定按钮
	_confirm_button = Button.new()
	_confirm_button.position = Vector2(575, 550)
	_confirm_button.size = Vector2(120, 30)
	_confirm_button.text = "确定 (S)"
	HudTheme.apply_slot_button(_confirm_button, 14, HudTheme.GOLD_BORDER, HudTheme.GOLD_TEXT)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_ui_layer.add_child(_confirm_button)
	# 取消/结束回合 双用途按钮
	_cancel_end_button = Button.new()
	_cancel_end_button.position = Vector2(735, 550)
	_cancel_end_button.size = Vector2(120, 30)
	_cancel_end_button.text = "结束回合 (E)"
	HudTheme.apply_slot_button(_cancel_end_button, 14)
	_cancel_end_button.disabled = true
	_cancel_end_button.pressed.connect(_on_cancel_end_pressed)
	_ui_layer.add_child(_cancel_end_button)
	# 回合时限条（可复用倒计时组件，渲染在 prompt 标签底层）
	_timer_bar = ProgressBar.new()
	_timer_bar.position = Vector2(315, 590)
	_timer_bar.size = Vector2(800, 20)
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 1.0
	_timer_bar.value = 1.0
	_timer_bar.show_percentage = false
	_timer_bar.visible = false
	_ui_layer.add_child(_timer_bar)
	# prompt 区
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(315, 590)
	_prompt_label.size = Vector2(800, 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1.0))
	_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("outline_size", 3)
	_ui_layer.add_child(_prompt_label)


# === 可复用倒计时时限条 ===

## 启动倒计时时限条。
func start_timer(duration: float, on_timeout: Callable) -> void:
	_timer_duration = duration
	_timer_remaining = duration
	_timer_on_timeout = on_timeout
	_timer_active = true
	if _timer_bar != null and is_instance_valid(_timer_bar):
		_timer_bar.max_value = duration
		_timer_bar.value = duration
		_timer_bar.visible = true


## 停止倒计时时限条。
func stop_timer() -> void:
	_timer_active = false
	_timer_on_timeout = Callable()
	if _timer_bar != null and is_instance_valid(_timer_bar):
		_timer_bar.visible = false


func _process(delta: float) -> void:
	if not _timer_active:
		return
	_timer_remaining -= delta
	if _timer_bar != null and is_instance_valid(_timer_bar):
		_timer_bar.value = _timer_remaining
	if _timer_remaining <= 0.0:
		var callback = _timer_on_timeout
		_timer_active = false
		if _timer_bar != null and is_instance_valid(_timer_bar):
			_timer_bar.visible = false
		_timer_on_timeout = Callable()
		if callback.is_valid():
			callback.call()


# === 卡牌选中处理 ===

func on_card_selected(card: Variant) -> void:
	if _move_select_mode:
		return
	if _confirm_mode:
		return
	if _skill_confirm_mode:
		return
	_set_selected_pile_key("")  # 互斥：清除牌堆选中
	_selected_card = card
	_update_prompt(card)
	refresh_confirm_cancel_buttons()


func on_card_deselected() -> void:
	_selected_card = null
	_update_prompt(null)
	refresh_confirm_cancel_buttons()


func _update_prompt(card: Variant) -> void:
	if _prompt_label == null or not is_instance_valid(_prompt_label):
		return
	if card == null or not is_instance_valid(card):
		_prompt_label.text = ""
		return
	var skills: Array = card.get("skills")
	if skills.is_empty():
		_prompt_label.text = card.get("card_name")
		return
	var first: Variant = skills[0]
	if first == null or not is_instance_valid(first):
		_prompt_label.text = card.get("card_name")
		return
	var desc: String = first.get("skill_description")
	if desc.is_empty():
		_prompt_label.text = card.get("card_name")
	else:
		_prompt_label.text = desc


# === 确认/取消处理 ===

func _on_confirm_pressed() -> void:
	if _judge_confirm_mode:
		exit_judge_confirm_mode()
		judge_confirm_responded.emit(true)
		return
	if _round_zero_mode:
		_round_zero_buffering = true
		refresh_confirm_cancel_buttons()
		redraw_decision_responded.emit(true)
		get_tree().create_timer(0.8).timeout.connect(_on_round_zero_buffer_end)
		return
	if _move_select_mode:
		if _block_select_count > 0 and _move_selected_blocks.size() == _block_select_count:
			var selected: Array = _move_selected_blocks.duplicate()
			var was_card_mode = _card_move_mode
			exit_move_select_mode()
			if was_card_mode:
				card_move_select_completed.emit(selected)
			else:
				action_requested.emit({"type": "move", "target": selected[0]})
		return
	if _skill_confirm_mode:
		var skill = _pending_skill
		exit_skill_confirm_mode()
		action_requested.emit({"type": "skill", "skill": skill})
		return
	if _confirm_mode:
		_confirm_mode = false
		if _prompt_label != null and is_instance_valid(_prompt_label):
			_prompt_label.text = ""
		refresh_confirm_cancel_buttons()
		confirm_responded.emit(true)
		return
	if _selected_pile_key != "":
		var pile_key: String = _selected_pile_key
		_set_selected_pile_key("")
		if _prompt_label != null and is_instance_valid(_prompt_label):
			_prompt_label.text = ""
		refresh_confirm_cancel_buttons()
		action_requested.emit({"type": "pile_draw", "pile_key": pile_key})
		return
	if _selected_card == null or not is_instance_valid(_selected_card):
		return
	var current: Variant = _get_acting_player()
	if current != null and is_instance_valid(current):
		var action_count: int = current.get_effective_action_count() if current.has_method("get_effective_action_count") else current.get("action_count")
		if action_count <= 0:
			return
	var card = _selected_card
	# 清空选中状态（会触发 on_card_deselected）
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	action_requested.emit({"type": "card", "card": card})


func _on_cancel_end_pressed() -> void:
	if _judge_confirm_mode:
		if not _judge_allow_cancel:
			return
		exit_judge_confirm_mode()
		judge_confirm_responded.emit(false)
		return
	if _round_zero_mode:
		exit_round_zero_mode()
		redraw_decision_responded.emit(false)
		return
	if _move_select_mode:
		var was_card_mode = _card_move_mode
		exit_move_select_mode()
		if was_card_mode:
			card_move_select_completed.emit([])
		return
	if _skill_confirm_mode:
		exit_skill_confirm_mode()
		return
	if _confirm_mode:
		_confirm_mode = false
		if _prompt_label != null and is_instance_valid(_prompt_label):
			_prompt_label.text = ""
		refresh_confirm_cancel_buttons()
		confirm_responded.emit(false)
		return
	if _selected_pile_key != "":
		_set_selected_pile_key("")
		if _prompt_label != null and is_instance_valid(_prompt_label):
			_prompt_label.text = ""
		refresh_confirm_cancel_buttons()
		return
	if _selected_card != null:
		# 有卡牌选中 → 取消选中
		if _hand_area != null and is_instance_valid(_hand_area):
			_hand_area.clear_selection()
	else:
		# 无卡牌选中 + 行动次数=0 → 结束回合
		action_requested.emit({})


## 双用途按钮 + 确定按钮状态刷新。
func refresh_confirm_cancel_buttons() -> void:
	if _round_zero_mode:
		if _confirm_button != null and is_instance_valid(_confirm_button):
			_confirm_button.text = "确定 (S)"
			_confirm_button.disabled = _round_zero_buffering
		if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = false
		return
	if _judge_confirm_mode:
		if _confirm_button != null and is_instance_valid(_confirm_button):
			_confirm_button.text = "确定 (S)"
			_confirm_button.disabled = false
		if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = not _judge_allow_cancel
		return
	if _move_select_mode:
		if _confirm_button != null and is_instance_valid(_confirm_button):
			_confirm_button.text = "确定 (S)"
			_confirm_button.disabled = not (_block_select_count > 0 and _move_selected_blocks.size() == _block_select_count)
		if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = false
		return
	if _skill_confirm_mode:
		if _confirm_button != null and is_instance_valid(_confirm_button):
			_confirm_button.text = "确定 (S)"
			var current: Variant = _get_acting_player()
			var usable: bool = false
			if current != null and is_instance_valid(current) and _pending_skill != null and is_instance_valid(_pending_skill):
				usable = current.can_use_active_skill(_pending_skill)
			_confirm_button.disabled = not usable
		if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = false
		return
	if _confirm_mode:
		if _confirm_button != null and is_instance_valid(_confirm_button):
			_confirm_button.text = "确定 (S)"
			_confirm_button.disabled = false
		if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = false
		return
	var current: Variant = _get_acting_player()
	var in_action: bool = false
	var action_count: int = 0
	if current != null and is_instance_valid(current):
		in_action = current.get_effective_phase() == "action" if current.has_method("get_effective_phase") else current.get("in_phase") == "action"
		action_count = current.get_effective_action_count() if current.has_method("get_effective_action_count") else current.get("action_count")
	# 确定按钮：有选中卡牌或牌堆 + 行动阶段 + 行动次数>0 + 选中卡牌 filter 通过
	if _confirm_button != null and is_instance_valid(_confirm_button):
		var card_ok: bool = true
		if _selected_card != null and is_instance_valid(_selected_card) and current != null and is_instance_valid(current):
			card_ok = current.is_card_usable(_selected_card)
		_confirm_button.disabled = not ((_selected_card != null or _selected_pile_key != "") and in_action and action_count > 0 and card_ok)
	# 取消/结束回合 双用途按钮
	if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
		if _selected_pile_key != "":
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = false
		elif _selected_card != null:
			_cancel_end_button.text = "取消 (C)"
			_cancel_end_button.disabled = false
		elif in_action and action_count <= 0:
			_cancel_end_button.text = "结束回合 (E)"
			_cancel_end_button.disabled = false
		else:
			_cancel_end_button.text = "结束回合 (E)"
			_cancel_end_button.disabled = true


# === 牌堆选中处理 ===

func on_pile_selected(pile_key: String, display_name: String = "") -> void:
	if _move_select_mode or _confirm_mode or _skill_confirm_mode:
		return
	if _selected_card != null:
		if _hand_area != null and is_instance_valid(_hand_area):
			_hand_area.clear_selection()
	_set_selected_pile_key(pile_key)
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = "是否从" + display_name + "中抓取一张牌？"
	refresh_confirm_cancel_buttons()


# === 移动选择模式 ===

## 进入地块选取模式（move/card 统一入口）。
## source == "move" 时执行行动次数守卫；source == "card" 时进入卡牌移动模式，
## 结果通过 card_move_select_completed 信号返回；count 为本次选取的目标数量。
func enter_block_select_mode(prompt: String, valid_blocks: Array, count: int, source: String) -> void:
	if _confirm_mode or _move_select_mode or _skill_confirm_mode or _round_zero_mode or _judge_confirm_mode:
		push_warning("enter_block_select_mode 被忽略：UI 模式冲突（confirm=%s move=%s skill_confirm=%s round_zero=%s judge_confirm=%s）" % [_confirm_mode, _move_select_mode, _skill_confirm_mode, _round_zero_mode, _judge_confirm_mode])
		return
	if source == "move":
		var current: Variant = _get_acting_player()
		if current == null or not is_instance_valid(current):
			return
		var in_action: bool = current.get_effective_phase() == "action" if current.has_method("get_effective_phase") else current.get("in_phase") == "action"
		var action_count: int = current.get_effective_action_count() if current.has_method("get_effective_action_count") else current.get("action_count")
		if not in_action or action_count <= 0:
			return
	_move_select_mode = true
	_card_move_mode = (source == "card")
	_card_move_valid_blocks = valid_blocks
	_block_select_count = count
	_valid_blocks = valid_blocks
	_move_selected_blocks = []
	# 清空手牌/牌堆选中（互斥）
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	_selected_card = null
	_set_selected_pile_key("")
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = prompt
	move_mode_changed.emit(true)
	refresh_confirm_cancel_buttons()


## M 键移动的薄封装：以当前地块相邻地块、count=1 进入 move 选取模式。
func enter_move_select_mode() -> void:
	var adjacent: Array = []
	var current: Variant = _get_acting_player()
	if current != null and is_instance_valid(current):
		var current_block: Variant = current.get("current_block")
		if current_block != null and is_instance_valid(current_block):
			adjacent = current_block.get_adjacent_blocks()
	enter_block_select_mode("\"移动\": 选择目标地图块", adjacent, 1, "move")


## 退出移动选择模式：复位状态，清空 prompt，清除移动高亮，刷新按钮。
func exit_move_select_mode() -> void:
	_move_select_mode = false
	_card_move_mode = false
	_move_selected_blocks = []
	_block_select_count = 1
	_valid_blocks = []
	_card_move_valid_blocks = []
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = ""
	move_mode_changed.emit(false)
	refresh_confirm_cancel_buttons()


## 移动模式下选择地图块：支持多选切换。
## 点击已选中地块 → 取消选中；点击合法未选中地块 → 在 count 未满时加入选中，已满则忽略。
func on_move_block_selected(block: Variant) -> void:
	if not _move_select_mode:
		return
	# 是否已在选中列表中
	var already_selected: bool = false
	for s in _move_selected_blocks:
		if s == block:
			already_selected = true
			break
	if already_selected:
		_move_selected_blocks.erase(block)
		move_mode_changed.emit(true)
		refresh_confirm_cancel_buttons()
		return
	# 是否在合法地块列表中
	var is_valid: bool = false
	for b in _valid_blocks:
		if b == block:
			is_valid = true
			break
	if not is_valid:
		return
	# 未满则加入，已满则忽略
	if _move_selected_blocks.size() < _block_select_count:
		_move_selected_blocks.append(block)
		move_mode_changed.emit(true)
		refresh_confirm_cancel_buttons()


# === 快捷键处理 ===

## 处理按钮快捷键（弹窗打开时不响应）。
func handle_shortcut(keycode: int, popup_open: bool = false) -> void:
	if popup_open:
		return
	if _round_zero_mode:
		match keycode:
			KEY_S:
				if _confirm_button != null and is_instance_valid(_confirm_button) and not _confirm_button.disabled:
					_on_confirm_pressed()
			KEY_C:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		return
	if _judge_confirm_mode:
		match keycode:
			KEY_S:
				if _confirm_button != null and is_instance_valid(_confirm_button) and not _confirm_button.disabled:
					_on_confirm_pressed()
			KEY_C:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		return
	if _move_select_mode:
		match keycode:
			KEY_S:
				if _confirm_button != null and is_instance_valid(_confirm_button) and not _confirm_button.disabled:
					_on_confirm_pressed()
			KEY_C:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		return
	if _skill_confirm_mode:
		match keycode:
			KEY_S:
				if _confirm_button != null and is_instance_valid(_confirm_button) and not _confirm_button.disabled:
					_on_confirm_pressed()
			KEY_C:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		return
	if _confirm_mode:
		match keycode:
			KEY_S:
				if _confirm_button != null and is_instance_valid(_confirm_button) and not _confirm_button.disabled:
					_on_confirm_pressed()
			KEY_C:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		return
	match keycode:
		KEY_S:
			if _confirm_button != null and is_instance_valid(_confirm_button) and not _confirm_button.disabled:
				_on_confirm_pressed()
		KEY_E:
			if _selected_pile_key == "" and _selected_card == null:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		KEY_C:
			if _selected_pile_key != "" or _selected_card != null:
				if _cancel_end_button != null and is_instance_valid(_cancel_end_button) and not _cancel_end_button.disabled:
					_on_cancel_end_pressed()
		KEY_M:
			enter_move_select_mode()


# === 技能确认模式 ===

## 进入技能确认模式：显示技能确认 prompt，根据可用性设置确定按钮置灰。
func enter_skill_confirm_mode(skill: Variant) -> void:
	if _confirm_mode or _move_select_mode or _skill_confirm_mode or _round_zero_mode or _judge_confirm_mode:
		return
	_skill_confirm_mode = true
	_pending_skill = skill
	# 互斥：清空手牌/牌堆选中
	_selected_card = null
	_set_selected_pile_key("")
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	# prompt 显示：优先使用技能的 confirm_prompt 动态文本，无则用默认格式
	if _prompt_label != null and is_instance_valid(_prompt_label):
		var prompt_text: String = ""
		if skill != null and is_instance_valid(skill) and skill.confirm_prompt.is_valid():
			var current_player: Variant = _get_acting_player()
			prompt_text = skill.execute_confirm_prompt(current_player)
		if prompt_text.is_empty():
			var sname: String = ""
			var sdesc: String = ""
			if skill != null and is_instance_valid(skill):
				sname = skill.skill_name
				sdesc = skill.skill_description
			prompt_text = "是否使用 \"" + sname + "\" { " + sdesc + " }"
		_prompt_label.text = prompt_text
	refresh_confirm_cancel_buttons()


## 退出技能确认模式：复位状态，清空 prompt，刷新按钮。
func exit_skill_confirm_mode() -> void:
	_skill_confirm_mode = false
	_pending_skill = null
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = ""
	refresh_confirm_cancel_buttons()


# === 第零轮模式 ===

## 进入第零轮重调模式：显示 prompt + 时限条 + 确定/取消按钮。
func enter_round_zero_mode(prompt: String, duration: float) -> void:
	if _confirm_mode or _move_select_mode or _skill_confirm_mode or _round_zero_mode or _judge_confirm_mode:
		return
	_round_zero_mode = true
	# 互斥：清空手牌/牌堆选中
	_selected_card = null
	_set_selected_pile_key("")
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = prompt
	# 启动倒计时时限条，超时自动取消
	start_timer(duration, Callable(self, "_on_round_zero_timeout"))
	refresh_confirm_cancel_buttons()


## 第零轮超时回调：自动取消。
func _on_round_zero_timeout() -> void:
	if not _round_zero_mode:
		return
	exit_round_zero_mode()
	redraw_decision_responded.emit(false)


## 退出第零轮模式：复位状态，清空 prompt，停止时限条，刷新按钮。
func exit_round_zero_mode() -> void:
	_round_zero_mode = false
	_round_zero_buffering = false
	stop_timer()
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = ""
	refresh_confirm_cancel_buttons()


## 第零轮缓冲结束回调：恢复确定按钮可点击。
func _on_round_zero_buffer_end() -> void:
	_round_zero_buffering = false
	if _round_zero_mode:
		refresh_confirm_cancel_buttons()


# === 检定确认模式 ===

## 进入检定确认模式：显示检定 prompt + 时限条 + 确定/取消按钮。
## allow_cancel 为 false 时取消按钮置灰（如怪物生成检定仅可确定）。
func enter_judge_confirm_mode(prompt: String, duration: float, allow_cancel: bool) -> void:
	if _confirm_mode or _move_select_mode or _skill_confirm_mode or _round_zero_mode or _judge_confirm_mode:
		return
	_judge_confirm_mode = true
	_judge_allow_cancel = allow_cancel
	# 互斥：清空手牌/牌堆选中
	_selected_card = null
	_set_selected_pile_key("")
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = prompt
	# 启动倒计时时限条，超时自动确定
	start_timer(duration, Callable(self, "_on_judge_confirm_timeout"))
	refresh_confirm_cancel_buttons()


## 检定确认超时回调：自动确定（与重调模式的超时取消不同）。
func _on_judge_confirm_timeout() -> void:
	if not _judge_confirm_mode:
		return
	exit_judge_confirm_mode()
	judge_confirm_responded.emit(true)


## 退出检定确认模式：复位状态，停止时限条，清空 prompt，刷新按钮。
func exit_judge_confirm_mode() -> void:
	_judge_confirm_mode = false
	stop_timer()
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = ""
	refresh_confirm_cancel_buttons()


# === 确认模式（由 GUIPlayerInput confirm_requested 触发）===

func set_confirm_mode(message: String) -> void:
	if _round_zero_mode or _judge_confirm_mode:
		return
	_confirm_mode = true
	_selected_card = null
	_set_selected_pile_key("")
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = message
	refresh_confirm_cancel_buttons()


## 设置 prompt 区文本（仅设置文本，不改变当前模式状态）。
func set_prompt_text(text: String) -> void:
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = text


# === 清空选中 ===

func clear_selection() -> void:
	_skill_confirm_mode = false
	_pending_skill = null
	_selected_card = null
	_set_selected_pile_key("")
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = ""
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	refresh_confirm_cancel_buttons()
	selection_cleared.emit()


## 非行动阶段清空选中（手牌 + 牌堆）。
func clear_for_non_action_phase() -> void:
	_set_selected_pile_key("")
	if _prompt_label != null and is_instance_valid(_prompt_label):
		_prompt_label.text = ""
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
