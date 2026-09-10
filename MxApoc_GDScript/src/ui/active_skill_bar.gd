class_name ActiveSkillBar
extends Node

## 主动技能栏。
## 管理主动技能按钮网格的刷新与点击。
## 任务行动技能（skill_type=="任务"）金色区分显示。

signal skill_pressed(skill: Variant)

var _active_skill_grid: GridContainer
var _active_skill_buttons: Array = []
var _network_action_available: Variant = null


func setup(grid: GridContainer) -> void:
	_active_skill_grid = grid

## 客机网络输入模式下，由 action INPUT_REQUEST 驱动技能栏显示。
## null 表示单机/房主本地模式，继续使用玩家 phase 判断。
func set_network_action_available(available: bool) -> void:
	_network_action_available = available

func clear_network_action_mode() -> void:
	_network_action_available = null


func refresh(player: Variant) -> void:
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_active_skill_buttons.clear()

	if player == null or not is_instance_valid(player):
		return
	var in_action: bool
	if _network_action_available != null:
		in_action = bool(_network_action_available)
	else:
		in_action = player.get_effective_phase() == "action" if player.has_method("get_effective_phase") else player.get("in_phase") == "action"
	if not in_action:
		return
	if player.has_method("is_action_type_allowed") and not player.is_action_type_allowed("skill"):
		return
	var has_action: bool
	if _network_action_available != null:
		has_action = player.get_effective_action_count() >= 1 \
			if player.has_method("get_effective_action_count") else player.get("action_count") > 0
	else:
		has_action = player.is_action_available(1) if player.has_method("is_action_available") \
			else player.get("action_count") > 0

	var seen_names: Dictionary = {}
	for skill in player.get("skills"):
		if skill == null or not is_instance_valid(skill):
			continue
		if skill.get("active") == "":
			continue
		var sname: String = skill.skill_name
		if seen_names.has(sname):
			continue
		seen_names[sname] = true
		var btn := Button.new()
		btn.text = _shorten_skill_name(sname)
		btn.tooltip_text = sname
		btn.custom_minimum_size = Vector2(80, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if skill.get("skill_type") == "任务":
			HudTheme.apply_mission_slot_button(btn, 12)
		else:
			HudTheme.apply_slot_button(btn, 12)
		btn.clip_text = true
		btn.disabled = not skill.is_usable() or not has_action
		btn.pressed.connect(_on_skill_button_pressed.bind(skill))
		_active_skill_grid.add_child(btn)
		_active_skill_buttons.append(btn)


## 教程挖洞：技能按钮包围盒；没有按钮时用整栏。
func get_bar_rect() -> Rect2:
	if _active_skill_grid == null or not is_instance_valid(_active_skill_grid):
		return Rect2()
	var merged := Rect2()
	for btn in _active_skill_buttons:
		if btn == null or not is_instance_valid(btn):
			continue
		var r: Rect2 = btn.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if merged.size == Vector2.ZERO:
			merged = r
		else:
			merged = merged.merge(r)
	if merged.size != Vector2.ZERO:
		return merged
	var parent: Node = _active_skill_grid.get_parent()
	if parent is Control:
		return (parent as Control).get_global_rect()
	return _active_skill_grid.get_global_rect()


func clear() -> void:
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_active_skill_buttons.clear()


func _on_skill_button_pressed(skill: Variant) -> void:
	skill_pressed.emit(skill)


## 超过 5 个字时取前 4 字加省略号；4～5 字原样显示。
func _shorten_skill_name(sname: String) -> String:
	if sname.length() <= 5:
		return sname
	return sname.substr(0, 4) + "..."
