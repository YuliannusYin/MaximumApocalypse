class_name SeatHud
extends Control

## 单个座位的私有热座 HUD。
## 地图、公共玩家面板、事件日志和牌堆面板不属于此组件。

var player: Variant = null
var hand_area: HandDisplayArea
var active_skill_bar: ActiveSkillBar
var action_controller: ActionSelectionController
var _event_scheduler: Variant = null


func setup(seat_player: Variant, ui_parent: Node) -> void:
	player = seat_player
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_parent.add_child(self)

	_build_private_controls()
	_refresh()


func set_event_scheduler(scheduler: Variant) -> void:
	_event_scheduler = scheduler
	if action_controller != null and is_instance_valid(action_controller):
		action_controller.set_event_scheduler(scheduler)


func _build_private_controls() -> void:
	hand_area = HandDisplayArea.new()
	hand_area.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hand_area)

	var skill_panel := Control.new()
	skill_panel.position = Vector2(1130, 595)
	skill_panel.size = Vector2(170, 175)
	skill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_panel)

	var skill_grid := GridContainer.new()
	skill_grid.set_anchors_preset(PRESET_FULL_RECT)
	skill_grid.add_theme_constant_override("h_separation", 10)
	skill_grid.add_theme_constant_override("v_separation", 5)
	skill_grid.columns = 2
	skill_panel.add_child(skill_grid)

	active_skill_bar = ActiveSkillBar.new()
	active_skill_bar.setup(skill_grid)
	add_child(active_skill_bar)

	action_controller = ActionSelectionController.new()
	action_controller.setup(self)
	action_controller.set_event_scheduler(_event_scheduler)
	add_child(action_controller)
	action_controller.build_buttons()

	hand_area.card_selected.connect(action_controller.on_card_selected)
	hand_area.card_deselected.connect(action_controller.on_card_deselected)


func set_active(active: bool) -> void:
	visible = active
	# SeatHud 是全屏容器，不能参与鼠标命中；只有实际的子控件接收输入。
	# 否则它会盖住同一 UILayer 中的牌堆、设置和任务按钮。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	hand_area.set_player(player)
	active_skill_bar.refresh(player)
	action_controller.set_acting_player(player)
	action_controller.refresh_confirm_cancel_buttons()


func refresh() -> void:
	_refresh()


func handle_shortcut(keycode: int, popup_open: bool) -> void:
	if visible:
		action_controller.handle_shortcut(keycode, popup_open)
