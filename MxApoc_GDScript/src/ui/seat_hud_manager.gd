class_name SeatHudManager
extends Node

## 座位私有 HUD 管理器。
## 负责稳定的玩家映射、单一可见焦点以及各座位 HUD 信号路由。

signal focus_player_changed(player: Variant)
signal action_requested(player: Variant, action: Dictionary)
signal confirm_responded(player: Variant, result: bool)
signal move_mode_changed(player: Variant, active: bool)
signal card_move_select_completed(player: Variant, blocks: Variant)
signal pile_selection_changed(player: Variant, pile_key: String)
signal skill_pressed(player: Variant, skill: Variant)
signal redraw_decision_responded(player: Variant, result: bool)
signal judge_confirm_responded(player: Variant, result: bool)

var _ui_parent: Node
var _huds: Array = []
var _hud_by_player_id: Dictionary = {}
var _focused_player: Variant = null
var _event_scheduler: Variant = null


func setup(ui_parent: Node) -> void:
	_ui_parent = ui_parent


## 注入 EventScheduler，供座位 HUD 观察当前 InputRequest owner；
## focused_player 仍表示 UI 焦点，不与请求 owner 混用。
func set_event_scheduler(scheduler: Variant) -> void:
	_event_scheduler = scheduler
	for hud in _huds:
		if hud != null and is_instance_valid(hud):
			hud.set_event_scheduler(scheduler)


func build(players: Array) -> void:
	for hud in _huds:
		if hud != null and is_instance_valid(hud):
			hud.queue_free()
	_huds.clear()
	_hud_by_player_id.clear()
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var hud := SeatHud.new()
		hud.set_event_scheduler(_event_scheduler)
		hud.setup(player, _ui_parent)
		hud.action_controller.action_requested.connect(_on_action_requested.bind(player))
		hud.action_controller.confirm_responded.connect(_on_confirm_responded.bind(player))
		hud.action_controller.move_mode_changed.connect(_on_move_mode_changed.bind(player))
		hud.action_controller.card_move_select_completed.connect(_on_card_move_select_completed.bind(player))
		hud.action_controller.pile_selection_changed.connect(_on_pile_selection_changed.bind(player))
		hud.action_controller.redraw_decision_responded.connect(_on_redraw_decision_responded.bind(player))
		hud.action_controller.judge_confirm_responded.connect(_on_judge_confirm_responded.bind(player))
		hud.active_skill_bar.skill_pressed.connect(_on_skill_pressed.bind(player))
		hud.set_active(false)
		_huds.append(hud)
		_hud_by_player_id[player.get_instance_id()] = hud


func get_hud(player: Variant) -> SeatHud:
	if player == null or not is_instance_valid(player):
		return null
	var hud: Variant = _hud_by_player_id.get(player.get_instance_id())
	if hud is SeatHud and is_instance_valid(hud):
		return hud
	return null


func get_focused_player() -> Variant:
	if _focused_player != null and is_instance_valid(_focused_player):
		return _focused_player
	return null


func get_input_request() -> Variant:
	if _event_scheduler == null or not is_instance_valid(_event_scheduler):
		return null
	return _event_scheduler.get_current_input_request()


func get_input_request_owner() -> Variant:
	var request: Variant = get_input_request()
	if request != null and request.owner != null and is_instance_valid(request.owner):
		return request.owner
	return null


func focus_player(player: Variant) -> void:
	var hud: SeatHud = get_hud(player)
	if hud == null:
		return
	for item in _huds:
		if item != null and is_instance_valid(item):
			item.set_active(item == hud)
	_focused_player = player
	focus_player_changed.emit(player)
	hud.refresh()


func handle_shortcut(keycode: int, popup_open: bool) -> void:
	var hud: SeatHud = get_hud(_focused_player)
	if hud != null:
		hud.handle_shortcut(keycode, popup_open)


func _on_action_requested(action: Dictionary, player: Variant) -> void:
	action_requested.emit(player, action)


func _on_confirm_responded(result: bool, player: Variant) -> void:
	confirm_responded.emit(player, result)


func _on_move_mode_changed(active: bool, player: Variant) -> void:
	move_mode_changed.emit(player, active)


func _on_card_move_select_completed(blocks: Variant, player: Variant) -> void:
	card_move_select_completed.emit(player, blocks)


func _on_pile_selection_changed(pile_key: String, player: Variant) -> void:
	pile_selection_changed.emit(player, pile_key)


func _on_skill_pressed(skill: Variant, player: Variant) -> void:
	skill_pressed.emit(player, skill)


func _on_redraw_decision_responded(result: bool, player: Variant) -> void:
	redraw_decision_responded.emit(player, result)


func _on_judge_confirm_responded(result: bool, player: Variant) -> void:
	judge_confirm_responded.emit(player, result)
