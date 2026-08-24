class_name ActiveSkillBar
extends Node

## 主动技能栏。
## 管理主动技能按钮网格的刷新与点击。
## 任务行动技能（skill_type=="任务"）金色区分显示。

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
		# 宽度按文字长度自适应（12px 字号下中文全宽约 14px），下限 80
		btn.custom_minimum_size = Vector2(maxi(80, sname.length() * 14 + 16), 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if skill.get("skill_type") == "任务":
			# 任务行动技能金色区分显示（disabled 用暗金）
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
			btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.6, 0.35))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.45))
			btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.45))
			btn.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.45))
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
