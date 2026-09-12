class_name ActiveSkillBar
extends Node

## 主动技能栏。
## 管理主动技能按钮网格的刷新与点击。
## 任务行动技能（skill_type=="任务"）金色区分显示。

signal skill_pressed(skill: Variant)

var _active_skill_grid: GridContainer
var _active_skill_buttons: Array = []
var _network_action_available: Variant = null
var _last_skill_names: PackedStringArray = []


func setup(grid: GridContainer) -> void:
	_active_skill_grid = grid

## 客机网络输入模式下，可点性由 action INPUT_REQUEST 驱动。
## 栏是否显示仍看玩家 phase，避免打出卡牌后结算间隙把技能栏清空。
## null 表示单机/房主本地模式，显示与可点都用玩家 phase / 行动点。
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
		_last_skill_names = PackedStringArray()
		return
	var in_action: bool = player.get_effective_phase() == "action" \
		if player.has_method("get_effective_phase") else player.get("in_phase") == "action"
	if not in_action:
		_last_skill_names = PackedStringArray()
		return
	if player.has_method("is_action_type_allowed") and not player.is_action_type_allowed("skill"):
		_last_skill_names = PackedStringArray()
		return
	var has_action: bool
	if _network_action_available != null:
		has_action = bool(_network_action_available)
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
		btn.disabled = not _is_skill_usable(player, skill) or not has_action
		btn.pressed.connect(_on_skill_button_pressed.bind(skill))
		_active_skill_grid.add_child(btn)
		_active_skill_buttons.append(btn)
	_maybe_animate_skill_buttons_in()


func _maybe_animate_skill_buttons_in() -> void:
	var names: PackedStringArray = PackedStringArray()
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			names.append(str(btn.text))
	if names == _last_skill_names:
		return
	_last_skill_names = names
	for btn in _active_skill_buttons:
		if btn == null or not is_instance_valid(btn):
			continue
		btn.pivot_offset = btn.custom_minimum_size * 0.5
		btn.scale = Vector2(0.86, 0.86)
		btn.modulate.a = 0.0
		var tw := btn.create_tween()
		tw.bind_node(btn)
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.14)
		tw.tween_property(btn, "modulate:a", 1.0, 0.14)


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
	_last_skill_names = PackedStringArray()


func _on_skill_button_pressed(skill: Variant) -> void:
	skill_pressed.emit(skill)


func _is_skill_usable(player: Variant, skill: Variant) -> bool:
	if player != null and is_instance_valid(player) and player.has_method("can_use_active_skill"):
		return bool(player.can_use_active_skill(skill))
	return skill != null and skill.has_method("is_usable") and bool(skill.is_usable())


## 超过 5 个字时取前 4 字加省略号；4～5 字原样显示。
func _shorten_skill_name(sname: String) -> String:
	if sname.length() <= 5:
		return sname
	return sname.substr(0, 4) + "..."
