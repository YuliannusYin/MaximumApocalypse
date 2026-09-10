extends TestBase

## 联机技能栏：结算间隙仍显示按钮，可点性才跟 action 请求走。


func _make_bar() -> Dictionary:
	var grid := GridContainer.new()
	add_child_autofree(grid)
	var bar := ActiveSkillBar.new()
	add_child_autofree(bar)
	bar.setup(grid)
	return {"bar": bar, "grid": grid}


func _make_action_player() -> Player:
	var player: Player = _make_player("Hunter")
	player.in_phase = "action"
	player.action_count = 2
	var skill := Skill.new()
	skill.skill_name = "潜行"
	skill.active = "action"
	skill.usable = -1
	player.add_skill(skill)
	return player


func test_network_settlement_keeps_skills_visible_but_disabled() -> void:
	var parts: Dictionary = _make_bar()
	var bar: ActiveSkillBar = parts.bar
	var player: Player = _make_action_player()
	bar.set_network_action_available(false)
	bar.refresh(player)
	await wait_idle_frames(1)
	assert_eq(bar._active_skill_buttons.size(), 1, "行动阶段结算中技能栏应仍显示")
	assert_true(bar._active_skill_buttons[0].disabled, "没有 action 请求时应禁用技能按钮")


func test_network_action_request_enables_skills() -> void:
	var parts: Dictionary = _make_bar()
	var bar: ActiveSkillBar = parts.bar
	var player: Player = _make_action_player()
	bar.set_network_action_available(true)
	bar.refresh(player)
	await wait_idle_frames(1)
	assert_eq(bar._active_skill_buttons.size(), 1)
	assert_false(bar._active_skill_buttons[0].disabled, "有 action 请求且有行动点时应可点")


func test_network_non_action_phase_hides_skills() -> void:
	var parts: Dictionary = _make_bar()
	var bar: ActiveSkillBar = parts.bar
	var player: Player = _make_action_player()
	player.in_phase = "draw"
	bar.set_network_action_available(true)
	bar.refresh(player)
	await wait_idle_frames(1)
	assert_eq(bar._active_skill_buttons.size(), 0, "非行动阶段即使有网络请求也不应显示技能")
