class_name PopupManager
extends Node

## 弹窗管理器。
## 接管全部弹窗的创建、显示、交互。
## 通过信号向主脚本返回用户选择结果。

const PRESET_FULL_RECT := Control.PRESET_FULL_RECT

signal option_selected(choice: Variant)
signal confirm_responded(result: bool)
signal cards_selected(cards: Array)
signal targets_selected(targets: Array)
signal block_selected(block: Variant)
signal closed()

# === 弹窗状态 ===
var _popup_overlay: ColorRect = null
var _popup_selected: Array = []
var _popup_required_n: int = 0
var _popup_min_n: int = -1
var _popup_ok_button: Button = null
var _popup_item_views: Array = []

var _popup_layer: CanvasLayer


func setup(popup_layer: CanvasLayer) -> void:
	_popup_layer = popup_layer


func is_popup_open() -> bool:
	return _popup_overlay != null and is_instance_valid(_popup_overlay)


# === 弹窗工具 ===

func _create_modal_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.4)
	_popup_layer.add_child(overlay)
	_popup_overlay = overlay
	return overlay


func close_popup() -> void:
	_close_popup()


func _close_popup() -> void:
	if _popup_overlay != null and is_instance_valid(_popup_overlay):
		_popup_overlay.queue_free()
	_popup_overlay = null
	_popup_selected.clear()
	_popup_required_n = 0
	_popup_ok_button = null
	_popup_item_views.clear()
	closed.emit()


func _option_display_name(option: Variant) -> String:
	if option == null:
		return "无"
	if option is String:
		return option
	if option is Monster:
		return "%s (HP %d/%d)" % [option.monster_name, option.hp, option.max_hp]
	if option is Player:
		return option.player_name
	if option is Equipment:
		var eq: Equipment = option
		if eq.charge_max > 0:
			return "%s (%d/%d)" % [eq.card_name, eq.charge_current, eq.charge_max]
		return eq.card_name
	if option is Card:
		return option.card_name
	return str(option)


## 检查目标列表是否全部为卡牌（Card 或 Equipment）。
func _is_all_card_targets(targets: Array) -> bool:
	if targets.is_empty():
		return false
	for target in targets:
		if not (target is Card or target is Equipment):
			return false
	return true


## 检查目标列表是否全部为实体（Monster 或 Player）。
func _is_all_entity_targets(targets: Array) -> bool:
	if targets.is_empty():
		return false
	for target in targets:
		if not (target is Monster or target is Player):
			return false
	return true


## 检查区域标签数组是否包含多种不同的区域值。
func _has_mixed_zones(zone_labels: Array) -> bool:
	if zone_labels.is_empty():
		return false
	var seen: Dictionary = {}
	for label in zone_labels:
		if label is String and not label.is_empty():
			seen[label] = true
	return seen.size() > 1


## 选项弹窗（choose）：点击选项立即响应
func show_option_popup(options: Array, prompt: String) -> void:
	if options.is_empty():
		option_selected.emit(null)
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(565, 200)
	panel.size = Vector2(300, 50 + options.size() * 38)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt if prompt != "" else "请选择"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	for option in options:
		var btn := Button.new()
		btn.text = _option_display_name(option)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_option_selected.bind(option))
		vbox.add_child(btn)


func _on_option_selected(choice: Variant) -> void:
	_close_popup()
	option_selected.emit(choice)


## 确认弹窗（confirm）：Yes/No
func show_confirm_popup(message: String) -> void:
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(515, 330)
	panel.size = Vector2(400, 120)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "确认"
	yes_btn.custom_minimum_size = Vector2(80, 30)
	yes_btn.pressed.connect(_on_confirm_responded.bind(true))
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "取消"
	no_btn.custom_minimum_size = Vector2(80, 30)
	no_btn.pressed.connect(_on_confirm_responded.bind(false))
	hbox.add_child(no_btn)


func _on_confirm_responded(result: bool) -> void:
	_close_popup()
	confirm_responded.emit(result)


## 卡牌选择弹窗（choose_card）：选择 N 张卡牌
func show_card_select_popup(cards: Array, n: int, position: String, zone_labels: Array = [], prompt: String = "", min_n: int = -1) -> void:
	if cards.is_empty():
		cards_selected.emit([])
		return
	var overlay := _create_modal_overlay()
	_popup_required_n = n
	_popup_selected.clear()
	_popup_min_n = min_n

	var panel := Panel.new()
	panel.position = Vector2(215, 80)
	panel.size = Vector2(1000, 560)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt if prompt != "" else "选择 %d 张卡牌（从 %s）" % [n, position]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	_popup_item_views.clear()
	var show_zone: bool = _has_mixed_zones(zone_labels)
	for i in range(cards.size()):
		var card = cards[i]
		var view := CardView.new()
		view.set_card(card)
		if show_zone and i < zone_labels.size():
			view.set_zone_label(zone_labels[i])
		view.gui_input.connect(_on_card_select_clicked.bind(card, view))
		grid.add_child(view)
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		_popup_item_views.append(view)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var ok_btn := Button.new()
	ok_btn.text = "确认（0/%d）" % n
	ok_btn.custom_minimum_size = Vector2(140, 30)
	if _popup_min_n >= 0:
		ok_btn.disabled = _popup_selected.size() < _popup_min_n
	else:
		ok_btn.disabled = true
	ok_btn.pressed.connect(_on_card_select_confirmed)
	hbox.add_child(ok_btn)
	_popup_ok_button = ok_btn

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.pressed.connect(_on_card_select_cancelled)
	hbox.add_child(cancel_btn)


func _on_card_select_clicked(event: InputEvent, card: Variant, view: CardView) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx: int = _popup_selected.find(card)
		if idx >= 0:
			_popup_selected.remove_at(idx)
			view.set_selected(false)
		else:
			if _popup_selected.size() >= _popup_required_n:
				return
			_popup_selected.append(card)
			view.set_selected(true)
		if _popup_ok_button != null and is_instance_valid(_popup_ok_button):
			_popup_ok_button.text = "确认（%d/%d）" % [_popup_selected.size(), _popup_required_n]
			if _popup_min_n >= 0:
				_popup_ok_button.disabled = _popup_selected.size() < _popup_min_n
			else:
				_popup_ok_button.disabled = _popup_selected.size() != _popup_required_n


func _on_card_select_confirmed() -> void:
	var cards: Array = _popup_selected.duplicate()
	_close_popup()
	cards_selected.emit(cards)


func _on_card_select_cancelled() -> void:
	_close_popup()
	cards_selected.emit([])


## 目标选择区（315,120 800×420）：仅选目标时弹出。
func show_target_select_area(targets: Array, n: int, zone_labels: Array = [], prompt: String = "") -> void:
	if targets.is_empty():
		targets_selected.emit([])
		return
	# 卡牌目标：使用 CardView 网格布局
	if _is_all_card_targets(targets):
		var overlay := _create_modal_overlay()
		_popup_required_n = n
		_popup_selected.clear()

		var panel := Panel.new()
		panel.position = Vector2(215, 80)
		panel.size = Vector2(1000, 560)
		overlay.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(PRESET_FULL_RECT)
		vbox.offset_left = 10
		vbox.offset_top = 8
		vbox.offset_right = -10
		vbox.offset_bottom = -8
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)

		var title := Label.new()
		title.text = prompt if prompt != "" else "选择 %d 个目标" % n
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(title)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)

		_popup_item_views.clear()
		var show_zone: bool = _has_mixed_zones(zone_labels)
		for i in range(targets.size()):
			var target = targets[i]
			var view := CardView.new()
			view.set_card(target)
			if show_zone and i < zone_labels.size():
				view.set_zone_label(zone_labels[i])
			view.gui_input.connect(_on_target_card_clicked.bind(target, view))
			grid.add_child(view)
			view.mouse_filter = Control.MOUSE_FILTER_STOP
			_popup_item_views.append(view)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)
		vbox.add_child(hbox)

		var ok_btn := Button.new()
		ok_btn.text = "确认（0/%d）" % n
		ok_btn.custom_minimum_size = Vector2(140, 30)
		ok_btn.disabled = true
		ok_btn.pressed.connect(_on_target_card_confirmed)
		hbox.add_child(ok_btn)
		_popup_ok_button = ok_btn

		var cancel_btn := Button.new()
		cancel_btn.text = "取消"
		cancel_btn.custom_minimum_size = Vector2(80, 30)
		cancel_btn.pressed.connect(_on_target_card_cancelled)
		hbox.add_child(cancel_btn)
		return
	# 实体目标：使用卡片网格布局（Monster/Player）
	if _is_all_entity_targets(targets):
		var overlay := _create_modal_overlay()
		_popup_required_n = n
		_popup_selected.clear()

		var panel := Panel.new()
		panel.position = Vector2(215, 80)
		panel.size = Vector2(1000, 560)
		overlay.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(PRESET_FULL_RECT)
		vbox.offset_left = 10
		vbox.offset_top = 8
		vbox.offset_right = -10
		vbox.offset_bottom = -8
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)

		var title := Label.new()
		title.text = prompt if prompt != "" else "选择 %d 个目标" % n
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(title)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)

		_popup_item_views.clear()
		for target in targets:
			var card_panel: Panel = null
			if target is Monster:
				card_panel = _build_monster_card(target, 120, 180)
				# 添加"纠缠: 玩家名"标签
				var m: Monster = target
				if m.attack_target != null and is_instance_valid(m.attack_target):
					var inner: Panel = card_panel.get_child(0)
					var entangle_lbl := Label.new()
					entangle_lbl.text = "纠缠: " + m.attack_target.player_name
					entangle_lbl.position = Vector2(2, 2)
					entangle_lbl.size = Vector2(116, 14)
					entangle_lbl.add_theme_font_size_override("font_size", 9)
					entangle_lbl.add_theme_color_override("font_color", Color.WHITE)
					entangle_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
					entangle_lbl.add_theme_constant_override("outline_size", 3)
					inner.add_child(entangle_lbl)
					# 若同时存在"眩晕"标签，移至下方避免重叠
					if m.stunned:
						for child in inner.get_children():
							if child is Label and child.text == "眩晕":
								child.position = Vector2(4, 16)
								break
			elif target is Player:
				card_panel = _build_player_card(target, 120, 180)
			if card_panel != null:
				card_panel.gui_input.connect(_on_entity_card_clicked.bind(target, card_panel))
				grid.add_child(card_panel)
				_popup_item_views.append(card_panel)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)
		vbox.add_child(hbox)

		var ok_btn := Button.new()
		ok_btn.text = "确认（0/%d）" % n
		ok_btn.custom_minimum_size = Vector2(140, 30)
		ok_btn.disabled = true
		ok_btn.pressed.connect(_on_entity_card_confirmed)
		hbox.add_child(ok_btn)
		_popup_ok_button = ok_btn

		var cancel_btn := Button.new()
		cancel_btn.text = "取消"
		cancel_btn.custom_minimum_size = Vector2(80, 30)
		cancel_btn.pressed.connect(_on_entity_card_cancelled)
		hbox.add_child(cancel_btn)
		return
	# 非卡牌目标：原有 Button 布局（完全不变）
	var overlay := _create_modal_overlay()
	_popup_required_n = n
	_popup_selected.clear()
	var panel := Panel.new()
	panel.position = Vector2(315, 120)
	panel.size = Vector2(800, 420)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = prompt if prompt != "" else "选择 %d 个目标" % n
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for target in targets:
		var btn := Button.new()
		btn.text = _option_display_name(target)
		btn.custom_minimum_size = Vector2(180, 40)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_target_area_clicked.bind(target, btn))
		grid.add_child(btn)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	var ok_btn := Button.new()
	ok_btn.text = "确认（0/%d）" % n
	ok_btn.custom_minimum_size = Vector2(140, 30)
	ok_btn.disabled = true
	ok_btn.pressed.connect(_on_target_area_confirmed)
	hbox.add_child(ok_btn)
	_popup_ok_button = ok_btn
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.pressed.connect(_on_target_area_cancelled)
	hbox.add_child(cancel_btn)


func _on_target_area_clicked(target: Variant, btn: Button) -> void:
	var idx: int = _popup_selected.find(target)
	if idx >= 0:
		_popup_selected.remove_at(idx)
		btn.modulate = Color(1, 1, 1, 1)
	else:
		if _popup_selected.size() >= _popup_required_n:
			return
		_popup_selected.append(target)
		btn.modulate = Color(0.4, 0.8, 0.4, 1.0)
	if _popup_ok_button != null and is_instance_valid(_popup_ok_button):
		_popup_ok_button.text = "确认（%d/%d）" % [_popup_selected.size(), _popup_required_n]
		_popup_ok_button.disabled = _popup_selected.size() != _popup_required_n


func _on_target_area_confirmed() -> void:
	var targets: Array = _popup_selected.duplicate()
	_close_popup()
	targets_selected.emit(targets)


func _on_target_area_cancelled() -> void:
	_close_popup()
	targets_selected.emit([])


func _on_target_card_clicked(event: InputEvent, target: Variant, view: CardView) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx: int = _popup_selected.find(target)
		if idx >= 0:
			_popup_selected.remove_at(idx)
			view.set_selected(false)
		else:
			if _popup_selected.size() >= _popup_required_n:
				return
			_popup_selected.append(target)
			view.set_selected(true)
		if _popup_ok_button != null and is_instance_valid(_popup_ok_button):
			_popup_ok_button.text = "确认（%d/%d）" % [_popup_selected.size(), _popup_required_n]
			_popup_ok_button.disabled = _popup_selected.size() != _popup_required_n


func _on_target_card_confirmed() -> void:
	var targets: Array = _popup_selected.duplicate()
	_close_popup()
	targets_selected.emit(targets)


func _on_target_card_cancelled() -> void:
	_close_popup()
	targets_selected.emit([])


func _on_entity_card_clicked(event: InputEvent, target: Variant, panel: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx: int = _popup_selected.find(target)
		if idx >= 0:
			_popup_selected.remove_at(idx)
			_set_entity_card_selected(panel, false)
		else:
			if _popup_selected.size() >= _popup_required_n:
				return
			_popup_selected.append(target)
			_set_entity_card_selected(panel, true)
		if _popup_ok_button != null and is_instance_valid(_popup_ok_button):
			_popup_ok_button.text = "确认（%d/%d）" % [_popup_selected.size(), _popup_required_n]
			_popup_ok_button.disabled = _popup_selected.size() != _popup_required_n


func _on_entity_card_confirmed() -> void:
	var targets: Array = _popup_selected.duplicate()
	_close_popup()
	targets_selected.emit(targets)


func _on_entity_card_cancelled() -> void:
	_close_popup()
	targets_selected.emit([])


## 地块选择弹窗（choose_block）：选择 1 个地块
func show_block_select_popup(blocks: Array, prompt: String) -> void:
	if blocks.is_empty():
		block_selected.emit(null)
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(515, 200)
	panel.size = Vector2(400, 50 + blocks.size() * 38)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt if prompt != "" else "选择地块"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	for block in blocks:
		var btn := Button.new()
		var bname: String = block.block_name if block != null and is_instance_valid(block) else "?"
		var coord: String = ""
		if block != null and is_instance_valid(block) and block.get("coordinate") != null:
			var c: Dictionary = block.coordinate
			coord = " (%d,%d)" % [c.get("x", 0), c.get("y", 0)]
		btn.text = bname + coord
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_block_selected.bind(block))
		vbox.add_child(btn)


func _on_block_selected(block: Variant) -> void:
	_close_popup()
	block_selected.emit(block)


## 卡牌详情弹窗（show_card）
func show_card_detail_popup(card: Card) -> void:
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(615, 250)
	panel.size = Vector2(200, 260)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var view := CardView.new()
	view.set_card(card)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(view)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_on_card_detail_closed)
	vbox.add_child(ok_btn)


func _on_card_detail_closed() -> void:
	_close_popup()


## 地块详情弹窗：点击地块时显示地块信息（已展示/未探索/已摧毁 三种分支）。
func show_block_detail_popup(block: Variant) -> void:
	if block == null or not is_instance_valid(block):
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(515, 200)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var coord_var: Variant = block.get("coordinate")
	var coord: Dictionary = coord_var if coord_var is Dictionary else {"x": 0, "y": 0}
	var coord_str: String = "(%d,%d)" % [coord.get("x", 0), coord.get("y", 0)]

	# 已摧毁地块
	if block.is_destroyed():
		var destroyed_title := Label.new()
		destroyed_title.text = "已摧毁 %s" % coord_str
		destroyed_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(destroyed_title)
		panel.size = Vector2(240, 90)
		var d_close := Button.new()
		d_close.text = "关闭"
		d_close.custom_minimum_size = Vector2(80, 30)
		d_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		d_close.pressed.connect(_close_popup)
		vbox.add_child(d_close)
		return

	# 未展示地块
	if not block.is_revealed():
		var unrevealed_title := Label.new()
		unrevealed_title.text = "未探索 %s" % coord_str
		unrevealed_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(unrevealed_title)
		# 怪物标记数
		var mm_lbl := Label.new()
		mm_lbl.text = "怪物标记：%d" % block.get("monster_marks")
		mm_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(mm_lbl)
		# 目标标记数
		var om_arr: Array = block.get("objective_marks")
		var om_count: int = 0
		for om in om_arr:
			if not om.get("removed", false):
				om_count += 1
		var om_lbl := Label.new()
		om_lbl.text = "目标标记：%d" % om_count
		om_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(om_lbl)
		panel.size = Vector2(240, 150)
		var u_close := Button.new()
		u_close.text = "关闭"
		u_close.custom_minimum_size = Vector2(80, 30)
		u_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		u_close.pressed.connect(_close_popup)
		vbox.add_child(u_close)
		return

	# 已展示地块
	var title := Label.new()
	title.text = "%s %s" % [block.get("block_name"), coord_str]
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var spawn_lbl := Label.new()
	spawn_lbl.text = "刷怪点数：%d" % block.get("monster_spawn_value")
	spawn_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(spawn_lbl)

	var color_map: Dictionary = {"red": "红", "green": "绿", "blue": "蓝"}
	var color_parts: PackedStringArray = []
	for c in block.get("scavenge_colors"):
		color_parts.append(color_map.get(c, c))
	var scavenge_lbl := Label.new()
	scavenge_lbl.text = "拾荒颜色：" + ("、".join(color_parts) if color_parts.size() > 0 else "无")
	scavenge_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(scavenge_lbl)

	# 技能描述
	var skills: Array = block.get("skills")
	var skill_count: int = 0
	if not skills.is_empty():
		var skill_header := Label.new()
		skill_header.text = "地块技能："
		skill_header.add_theme_font_size_override("font_size", 13)
		vbox.add_child(skill_header)
		for skill in skills:
			if skill == null or not is_instance_valid(skill):
				continue
			skill_count += 1
			var skill_lbl := Label.new()
			skill_lbl.text = "• %s：%s" % [skill.get("skill_name"), skill.get("skill_description")]
			skill_lbl.add_theme_font_size_override("font_size", 12)
			skill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			skill_lbl.custom_minimum_size = Vector2(376, 0)
			vbox.add_child(skill_lbl)

	# 玩家列表
	var players: Array = block.get_players()
	var player_parts: PackedStringArray = []
	for p in players:
		if p != null and is_instance_valid(p):
			player_parts.append(p.get("player_name"))
	var players_lbl := Label.new()
	players_lbl.text = "玩家：" + ("、".join(player_parts) if player_parts.size() > 0 else "无")
	players_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(players_lbl)

	# 怪物列表（遍历地块上所有玩家的 monster_zone）
	var monsters: Array = []
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		for m in p.get("monster_zone"):
			if m != null and is_instance_valid(m):
				monsters.append(m)
	var monster_header := Label.new()
	monster_header.text = "怪物："
	monster_header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(monster_header)
	if monsters.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "  无"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty_lbl)
	else:
		for m in monsters:
			var m_lbl := Label.new()
			m_lbl.text = "  %s (HP %d/%d)" % [m.get("monster_name"), m.get("hp"), m.get("max_hp")]
			m_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(m_lbl)

	# 怪物标记数
	var marks_lbl := Label.new()
	marks_lbl.text = "怪物标记：%d" % block.get("monster_marks")
	marks_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(marks_lbl)

	# 特殊标记（目标标记）
	var obj_marks: Array = block.get("objective_marks")
	var obj_lbl := Label.new()
	obj_lbl.text = "特殊标记：%d" % obj_marks.size()
	obj_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(obj_lbl)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_popup)
	vbox.add_child(close_btn)

	# 尺寸根据内容自适应（粗略估算高度）
	var est_h: int = 28 + 22 + 22 + (22 + skill_count * 36) + 22 + (22 + maxi(monsters.size(), 1) * 20) + 22 + 22 + 38 + 24
	panel.size = Vector2(400, est_h)


# === 详情弹窗（任务 #91） ===

func show_mission_detail_popup() -> void:
	var mission: Variant = Game.current_mission
	if mission == null or not is_instance_valid(mission):
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(365, 120)
	panel.size = Vector2(700, 480)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "任务：%s（%s）" % [mission.get("mission_name"), mission.get("difficulty_display")]
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var fuel: String = "无需"
	if mission.get("van_fuel_required") != null:
		fuel = str(mission.get("van_fuel_required"))
	var info := Label.new()
	info.text = "面包车燃料需求：%s    怪物包：%s" % [fuel, mission.get("monster_pack_type")]
	info.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info)

	# 可滚动内容区域
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var obj_label := Label.new()
	obj_label.text = "目标："
	obj_label.add_theme_font_size_override("font_size", 13)
	content.add_child(obj_label)

	var obj_text := Label.new()
	obj_text.text = mission.get("objective_text")
	obj_text.add_theme_font_size_override("font_size", 12)
	obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_text.custom_minimum_size = Vector2(660, 0)
	content.add_child(obj_text)

	var intro_label := Label.new()
	intro_label.text = "简介："
	intro_label.add_theme_font_size_override("font_size", 13)
	content.add_child(intro_label)

	var intro_text := Label.new()
	intro_text.text = mission.get("intro_text")
	intro_text.add_theme_font_size_override("font_size", 12)
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.custom_minimum_size = Vector2(660, 0)
	content.add_child(intro_text)

	# 地图块配置
	var block_label := Label.new()
	block_label.text = "地图块配置："
	block_label.add_theme_font_size_override("font_size", 13)
	content.add_child(block_label)
	var block_parts: PackedStringArray = []
	var map_blocks_config: Dictionary = mission.get("map_blocks_config")
	for block_name in map_blocks_config:
		block_parts.append("%s×%d" % [block_name, map_blocks_config[block_name]])
	var block_text := Label.new()
	block_text.text = ", ".join(block_parts)
	block_text.add_theme_font_size_override("font_size", 12)
	block_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block_text.custom_minimum_size = Vector2(660, 0)
	content.add_child(block_text)

	# 拾荒牌堆配置
	var scavenge_label := Label.new()
	scavenge_label.text = "拾荒牌堆配置："
	scavenge_label.add_theme_font_size_override("font_size", 13)
	content.add_child(scavenge_label)
	var color_names: Dictionary = {"red": "红色", "green": "绿色", "blue": "蓝色"}
	var scavenge_config: Dictionary = mission.get("scavenge_config")
	for color in ["red", "green", "blue"]:
		var card_entries: Array = scavenge_config.get(color, [])
		var card_parts: PackedStringArray = []
		for entry in card_entries:
			card_parts.append("%s×%d" % [entry.get("card_name", ""), int(entry.get("count", 0))])
		var color_text := Label.new()
		color_text.text = "%s：%s" % [color_names[color], ", ".join(card_parts)]
		color_text.add_theme_font_size_override("font_size", 12)
		color_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		color_text.custom_minimum_size = Vector2(660, 0)
		content.add_child(color_text)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


func show_event_log_popup(event_log: Array) -> void:
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(415, 100)
	panel.size = Vector2(600, 520)
	# 设置背景色 #1E2228
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1E2228")
	bg_style.content_margin_left = 8
	bg_style.content_margin_right = 8
	bg_style.content_margin_top = 8
	bg_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", bg_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "事件日志（最近 %d 条）" % mini(event_log.size(), 100)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 1)
	scroll.add_child(content)

	var start_idx: int = maxi(0, event_log.size() - 100)
	for i in range(start_idx, event_log.size()):
		var msg: String = event_log[i]
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.add_theme_color_override("default_color", Color("#cccccc"))
		if msg.begins_with("===="):
			lbl.text = msg
			lbl.add_theme_font_size_override("font_size", 12)
		else:
			lbl.text = "  " + msg
			lbl.add_theme_font_size_override("font_size", 11)
		content.add_child(lbl)

	if event_log.is_empty():
		var empty := RichTextLabel.new()
		empty.bbcode_enabled = true
		empty.fit_content = true
		empty.text = "暂无日志"
		empty.add_theme_font_size_override("font_size", 12)
		content.add_child(empty)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


# === 弃牌堆面板 ===

func show_scavenge_discard_popup() -> void:
	var cards: Array = []
	if Game.scavenge_discard_pile != null and is_instance_valid(Game.scavenge_discard_pile):
		cards = Game.scavenge_discard_pile.get("cards")
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(315, 100)
	panel.size = Vector2(800, 560)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "拾荒弃牌堆（%d 张）" % cards.size()
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "弃牌堆为空"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for card in cards:
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			view.set_card(card)
			grid.add_child(view)
	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


func show_game_discard_popup() -> void:
	var cards: Array = []
	var current: Variant = Game.get_current_player()
	if current != null and is_instance_valid(current):
		var pile: Variant = current.get("game_discard_pile")
		if pile != null and is_instance_valid(pile):
			cards = pile.get("cards")
	var pname: String = "当前玩家"
	if current != null and is_instance_valid(current):
		pname = current.get("player_name")
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(315, 100)
	panel.size = Vector2(800, 560)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "%s 的角色弃牌堆（%d 张）" % [pname, cards.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "弃牌堆为空"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for card in cards:
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			view.set_card(card)
			grid.add_child(view)
	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


func show_monster_zone_popup(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var monsters: Array = player.get("monster_zone")
	var pname: String = player.get("player_name")
	var overlay := _create_modal_overlay()

	var card_w: int = 130
	var card_h: int = 190
	var cols: int = 4
	var flow_w: int = cols * card_w + (cols - 1) * 8
	var rows: int = ceili(float(maxi(monsters.size(), 1)) / float(cols))
	var panel_w: int = flow_w + 32
	var panel_h: int = 50 + rows * (card_h + 8) + 50

	var panel := Panel.new()
	panel.position = Vector2((1430 - panel_w) / 2, (780 - panel_h) / 2)
	panel.size = Vector2(panel_w, panel_h)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s 的怪物区（%d 只）" % [pname, monsters.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	if monsters.is_empty():
		var empty := Label.new()
		empty.text = "无怪物"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(flow_w, 0)
		flow.add_theme_constant_override("separation", 8)
		flow.add_theme_constant_override("line_separation", 8)
		vbox.add_child(flow)
		for m in monsters:
			if m == null or not is_instance_valid(m):
				continue
			flow.add_child(_build_monster_card(m, 120, 180))

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


## 构建单个怪物卡片（外层130×190黑色边框 + 内层120×180）：图片 + 属性叠加。
func _build_monster_card(m: Variant, w: int, h: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(w + 10, h + 10)
	card.size = Vector2(w + 10, h + 10)

	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	card.add_theme_stylebox_override("panel", style)

	var inner := Panel.new()
	inner.position = Vector2(5, 5)
	inner.size = Vector2(w, h)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	inner.add_theme_stylebox_override("panel", inner_style)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	# 怪物图片
	var tex: Texture2D = ImageCache.get_monster_texture(m.get("monster_name"))
	if tex != null:
		var img := TextureRect.new()
		img.set_anchors_preset(PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.texture = tex
		if m.get("stunned"):
			img.modulate = Color(0.5, 0.5, 0.8, 0.7)
		inner.add_child(img)

	# HP/MaxHP（右上角）
	var hp_lbl := Label.new()
	hp_lbl.text = "%d/%d" % [m.get("hp"), m.get("max_hp")]
	hp_lbl.position = Vector2(w - 58, 4)
	hp_lbl.size = Vector2(54, 16)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(hp_lbl)

	# 攻击力（HP 下方）
	var atk_lbl := Label.new()
	atk_lbl.text = "攻 %d" % [m.get("damage_value")]
	atk_lbl.position = Vector2(w - 58, 21)
	atk_lbl.size = Vector2(54, 16)
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	atk_lbl.add_theme_font_size_override("font_size", 11)
	atk_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	atk_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(atk_lbl)

	# 怪物名（中下）
	var name_lbl := Label.new()
	name_lbl.text = m.get("monster_name")
	name_lbl.position = Vector2(4, h - 52)
	name_lbl.size = Vector2(w - 8, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(name_lbl)

	# 射程（名字下方）
	var range_map := {"none": "纠缠", "short": "短程", "medium": "中程", "long": "远程", "infinity": "无限"}
	var range_lbl := Label.new()
	range_lbl.text = "射程 " + range_map.get(m.get("range"), m.get("range"))
	range_lbl.position = Vector2(4, h - 32)
	range_lbl.size = Vector2(w - 8, 18)
	range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_lbl.add_theme_font_size_override("font_size", 11)
	range_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	range_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(range_lbl)

	# 眩晕标识（左上角）
	if m.get("stunned"):
		var stun_lbl := Label.new()
		stun_lbl.text = "眩晕"
		stun_lbl.position = Vector2(4, 4)
		stun_lbl.size = Vector2(34, 16)
		stun_lbl.add_theme_font_size_override("font_size", 10)
		stun_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
		stun_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		stun_lbl.add_theme_constant_override("outline_size", 2)
		inner.add_child(stun_lbl)

	return card


## 构建玩家目标卡片（外层 w+10×h+10 黑色边框 + 内层 w×h 蓝色背景）。
func _build_player_card(p: Variant, w: int, h: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(w + 10, h + 10)
	card.size = Vector2(w + 10, h + 10)

	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	card.add_theme_stylebox_override("panel", style)

	var inner := Panel.new()
	inner.position = Vector2(5, 5)
	inner.size = Vector2(w, h)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.15, 0.25, 0.40, 1.0)
	inner.add_theme_stylebox_override("panel", inner_style)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	# 玩家名（中下）
	var name_lbl := Label.new()
	name_lbl.text = p.get("player_name")
	name_lbl.position = Vector2(4, h - 52)
	name_lbl.size = Vector2(w - 8, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(name_lbl)

	# "玩家"标识（名字下方）
	var role_lbl := Label.new()
	role_lbl.text = "玩家"
	role_lbl.position = Vector2(4, h - 32)
	role_lbl.size = Vector2(w - 8, 18)
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	role_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	role_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(role_lbl)

	# HP/MaxHP（右上角）
	var hp_lbl := Label.new()
	hp_lbl.text = "%d/%d" % [p.get("hp"), p.get("max_hp")]
	hp_lbl.position = Vector2(w - 58, 4)
	hp_lbl.size = Vector2(54, 16)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(hp_lbl)

	return card


## 设置实体卡选中态（金色边框）。
func _set_entity_card_selected(panel: Panel, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	if selected:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	panel.add_theme_stylebox_override("panel", style)


func show_equipment_zone_popup(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var equips: Array = player.get("equipment_zone")
	var pname: String = player.get("player_name")
	var overlay := _create_modal_overlay()

	var card_w: int = 130
	var card_h: int = 190
	var cols: int = 4
	var flow_w: int = cols * card_w + (cols - 1) * 8
	var rows: int = ceili(float(maxi(equips.size(), 1)) / float(cols))
	var panel_w: int = flow_w + 32
	var panel_h: int = 50 + rows * (card_h + 8) + 50

	var panel := Panel.new()
	panel.position = Vector2((1430 - panel_w) / 2, (780 - panel_h) / 2)
	panel.size = Vector2(panel_w, panel_h)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s 的装备区（%d 件）" % [pname, equips.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	if equips.is_empty():
		var empty := Label.new()
		empty.text = "无装备"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(flow_w, 0)
		flow.add_theme_constant_override("separation", 8)
		flow.add_theme_constant_override("line_separation", 8)
		vbox.add_child(flow)
		for card in equips:
			if card == null or not is_instance_valid(card):
				continue
			flow.add_child(_build_equipment_card(card, 120, 180))

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


## 构建单个装备卡片（120×180）：图片 + 牌名(中下) + 射程(名字下) + 左上角格子数。
func _build_equipment_card(card: Variant, w: int, h: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(w + 10, h + 10)
	p.size = Vector2(w + 10, h + 10)

	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	p.add_theme_stylebox_override("panel", style)

	var inner := Panel.new()
	inner.position = Vector2(5, 5)
	inner.size = Vector2(w, h)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	inner.add_theme_stylebox_override("panel", inner_style)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)

	# 装备图片
	var tex: Texture2D = ImageCache.get_card_texture(card.get("card_name"))
	if tex != null:
		var img := TextureRect.new()
		img.set_anchors_preset(PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.texture = tex
		inner.add_child(img)

	# 左上角格子数
	var size_val: Variant = card.get("size")
	var sz: int = size_val if size_val is int else 0
	var badge := Label.new()
	badge.text = "%d格" % sz
	badge.position = Vector2(4, 4)
	badge.size = Vector2(40, 16)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 3)
	inner.add_child(badge)

	# 牌名（中下）
	var name_lbl := Label.new()
	name_lbl.text = card.get("card_name")
	name_lbl.position = Vector2(4, h - 52)
	name_lbl.size = Vector2(w - 8, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 3)
	inner.add_child(name_lbl)

	# 射程（名字下方，仅 range≠"none" 且非空）
	var range_val: Variant = card.get("range")
	var range_str: String = range_val if range_val is String else ""
	if not range_str.is_empty() and range_str != "none":
		var range_map := {"short": "短程", "medium": "中程", "long": "远程", "infinity": "无限"}
		var range_lbl := Label.new()
		range_lbl.text = "射程 " + range_map.get(range_str, range_str)
		range_lbl.position = Vector2(4, h - 32)
		range_lbl.size = Vector2(w - 8, 18)
		range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		range_lbl.add_theme_font_size_override("font_size", 11)
		range_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		range_lbl.add_theme_constant_override("outline_size", 3)
		inner.add_child(range_lbl)

	# 填充物信息（如果有）
	var charge_max_val: Variant = card.get("charge_max")
	var charge_cur_val: Variant = card.get("charge_current")
	if charge_max_val is int and charge_max_val > 0:
		var cur: int = charge_cur_val if charge_cur_val is int else 0
		var charge_lbl := Label.new()
		charge_lbl.text = "%d/%d" % [cur, charge_max_val]
		charge_lbl.position = Vector2(w - 50, 4)
		charge_lbl.size = Vector2(46, 16)
		charge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		charge_lbl.add_theme_font_size_override("font_size", 11)
		charge_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1.0))
		charge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_lbl.add_theme_constant_override("outline_size", 3)
		inner.add_child(charge_lbl)

	return p


func show_hand_popup(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var cards: Array = player.get("hand")
	var pname: String = player.get("player_name")
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(315, 100)
	panel.size = Vector2(800, 560)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s 的手牌（%d 张）" % [pname, cards.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	if cards.is_empty():
		var empty := Label.new()
		empty.text = "无手牌"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(grid)
		for card in cards:
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			view.set_card(card)
			grid.add_child(view)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)
