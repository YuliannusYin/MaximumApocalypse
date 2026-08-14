class_name ActiveSkillBar
extends Node

## 主动技能栏。
## 管理主动技能按钮网格的刷新与点击。

signal skill_pressed(skill: Variant)

var _active_skill_grid: GridContainer
var _active_skill_buttons: Array = []


func setup(grid: GridContainer) -> void:
	_active_skill_grid = grid


func refresh(player: Variant) -> void:
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_active_skill_buttons.clear()

	if player == null or not is_instance_valid(player):
		return
	if player.get("in_phase") != "action":
		return

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
		btn.text = skill.skill_name
		btn.add_theme_font_size_override("font_size", 12)
		btn.custom_minimum_size = Vector2(80, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.disabled = not skill.is_usable()
		btn.pressed.connect(_on_skill_button_pressed.bind(skill))
		_active_skill_grid.add_child(btn)
		_active_skill_buttons.append(btn)


func clear() -> void:
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_active_skill_buttons.clear()


func _on_skill_button_pressed(skill: Variant) -> void:
	skill_pressed.emit(skill)
