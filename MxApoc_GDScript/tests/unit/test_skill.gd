extends TestBase

## Skill 单元测试。

var _saved_view_game: Node = null


func test_default_fields() -> void:
	var s: Skill = Skill.new()
	assert_eq(s.skill_name, "")
	assert_eq(s.trigger, "")
	assert_eq(s.active, "")
	assert_false(s.forced)
	assert_false(s.filter.is_valid())
	assert_false(s.content.is_valid())
	assert_eq(s.filter_target_range, "")
	assert_eq(s.range, "")
	assert_eq(s.usable, -1)
	assert_eq(s.used_count, 0)


func test_matches_trigger_single() -> void:
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	assert_true(s.matches_trigger("on_take_damage"))
	assert_false(s.matches_trigger("on_deal_damage"))


func test_matches_trigger_compound() -> void:
	var s: Skill = Skill.new()
	s.trigger = "on_game_start、on_take_damage"
	assert_true(s.matches_trigger("on_game_start"))
	assert_true(s.matches_trigger("on_take_damage"))
	assert_false(s.matches_trigger("after_take_damage"))


func test_matches_trigger_empty() -> void:
	var s: Skill = Skill.new()
	s.trigger = ""
	assert_false(s.matches_trigger("on_take_damage"))


func test_execute_filter_no_filter_returns_true() -> void:
	var s: Skill = Skill.new()
	var event: GameEvent = EventSystem.create_event()
	assert_true(s.execute_filter(null, event), "无 filter 时应返回 true")


func test_execute_filter_with_filter() -> void:
	var s: Skill = Skill.new()
	s.filter = func(_p, _t, ev, _g) -> bool:
		return ev.get("num", 0) > 0
	var event_pos: GameEvent = EventSystem.create_event({"num": 5})
	var event_zero: GameEvent = EventSystem.create_event({"num": 0})
	assert_true(s.execute_filter(null, event_pos))
	assert_false(s.execute_filter(null, event_zero))


func test_execute_content() -> void:
	var s: Skill = Skill.new()
	var captured: Array = []
	s.content = func(_p, _t, ev, _g) -> void:
		captured.append(ev.get("num", 0))
	var event: GameEvent = EventSystem.create_event({"num": 7})
	s.execute_content(null, event)
	assert_eq(captured, [7])


func test_execute_content_no_content_does_nothing() -> void:
	var s: Skill = Skill.new()
	var event: GameEvent = EventSystem.create_event()
	s.execute_content(null, event)
	assert_true(true, "无 content 时 execute_content 不应抛错")


func test_is_usable_unlimited() -> void:
	var s: Skill = Skill.new()
	s.usable = -1
	assert_true(s.is_usable())
	s.record_use()
	assert_true(s.is_usable(), "usable=-1 表示不限次数")


func test_is_usable_limited() -> void:
	var s: Skill = Skill.new()
	s.usable = 2
	assert_true(s.is_usable())
	s.record_use()
	assert_true(s.is_usable())
	s.record_use()
	assert_false(s.is_usable(), "达到 usable 上限后不可用")


func test_reset_use_count() -> void:
	var s: Skill = Skill.new()
	s.usable = 1
	s.record_use()
	assert_false(s.is_usable())
	s.reset_use_count()
	assert_true(s.is_usable(), "重置后应可用")


# === Merged mechanism tests (from cleanup) ===

# 测试: SkillData 从 JSON 正确读取 window_prompt
func test_skill_data_reads_window_prompt_from_json() -> void:
	var sd: SkillData = SkillData.new({
		"skill_name": "测试技能",
		"window_prompt": "测试提示文本"
	})
	assert_eq(sd.window_prompt, "测试提示文本", "SkillData 应从 JSON 读取 window_prompt")


# 测试: SkillData 无 window_prompt 字段时默认空字符串
func test_skill_data_window_prompt_default_empty() -> void:
	var sd: SkillData = SkillData.new({"skill_name": "无提示技能"})
	assert_eq(sd.window_prompt, "", "无 window_prompt 字段时应默认空字符串")


# 测试: SkillData → Skill 转换时 window_prompt 正确传递
func test_skill_window_prompt_passed_from_skill_data() -> void:
	var sd: SkillData = SkillData.new({
		"skill_name": "测试技能",
		"window_prompt": "传递测试"
	})
	var skill: Skill = Game._create_skill_from_data(sd)
	assert_eq(skill.window_prompt, "传递测试", "Skill.window_prompt 应从 SkillData 传递")


# 测试: survivors/ 全目录无残留 on_card_enter/leave_equipment
func test_no_residual_on_card_enter_leave_equipment_in_survivors() -> void:
	var dir: DirAccess = DirAccess.open("res://data/survivors/")
	assert_not_null(dir, "应能打开 res://data/survivors/ 目录")
	dir.list_dir_begin()
	var expected_files: Array = [
		"firefighter.json",
		"gunslinger.json",
		"hunter.json",
		"mechanic.json",
		"surgeon.json",
		"veteran.json",
	]
	var found_files: Dictionary = {}
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			assert_true(expected_files.has(fname), "survivors 目录仅应含预期文件，意外文件: " + fname)
			found_files[fname] = true
			var path: String = "res://data/survivors/" + fname
			var content: String = FileAccess.get_file_as_string(path)
			assert_false(content.is_empty(), "应能读取文件: " + path)
			assert_false(
				content.contains("on_card_enter_equipment"),
				fname + " 不应含 on_card_enter_equipment"
			)
			assert_false(
				content.contains("on_card_leave_equipment"),
				fname + " 不应含 on_card_leave_equipment"
			)
		fname = dir.get_next()
	dir.list_dir_end()
	for expected in expected_files:
		assert_true(found_files.has(expected), "应遍历到 survivor 文件: " + expected)
	assert_eq(found_files.size(), 6, "应共遍历到 6 个 survivor 文件")


func after_each() -> void:
	if NetSession != null:
		NetSession._view_game = _saved_view_game
	_saved_view_game = null
	super.after_each()


func before_each() -> void:
	super.before_each()
	_saved_view_game = NetSession._view_game if NetSession != null else null


func _attach_view_game() -> Node:
	var view: Node = load("res://src/game/game.gd").new()
	view.name = "ViewGame"
	add_child_autofree(view)
	NetSession._view_game = view
	return view


func test_execute_filter_uses_view_game_for_display_player() -> void:
	var view: Node = _attach_view_game()
	var p: Player = _make_player()
	view.players = [p]
	view.red_scavenge_pile = Pile.new()
	view.red_scavenge_pile.add(_make_scavenge_card("scrap", "red"))
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	var captured: Array = []
	var s: Skill = Skill.new()
	s.filter = func(_p, _t, _e, g) -> bool:
		captured.append(g)
		return g != null and g.has_method("has_scavenge_cards") and g.has_scavenge_cards()
	assert_true(s.execute_filter(p, EventSystem.create_event()), "显示世界有拾荒牌时 filter 应通过")
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], view, "filter 第四参应为 ViewGame")
	assert_false(Game.has_scavenge_cards(), "autoload Game 牌堆应仍为空")


func test_execute_filter_uses_authority_game_for_authority_player() -> void:
	var view: Node = _attach_view_game()
	var display_p: Player = _make_player("display")
	var auth_p: Player = _make_player("auth")
	view.players = [display_p]
	Game.players = [auth_p]
	var captured: Array = []
	var s: Skill = Skill.new()
	s.filter = func(_p, _t, _e, g) -> bool:
		captured.append(g)
		return true
	assert_true(s.execute_filter(auth_p, EventSystem.create_event()))
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], Game, "权威玩家 filter 第四参应仍为 Game")


func test_execute_content_stays_on_authority_game() -> void:
	var view: Node = _attach_view_game()
	var p: Player = _make_player()
	view.players = [p]
	var captured: Array = []
	var s: Skill = Skill.new()
	s.content = func(_p, _t, _e, g) -> void:
		captured.append(g)
	s.execute_content(p, EventSystem.create_event())
	assert_eq(captured, [Game], "content 即使演员在 ViewGame 上第四参仍为 Game")


func test_execute_confirm_prompt_uses_view_game() -> void:
	var view: Node = _attach_view_game()
	var p: Player = _make_player()
	view.players = [p]
	var s: Skill = Skill.new()
	s.confirm_prompt = func(_p, _t, _e, g) -> String:
		return "view" if g == view else "authority"
	assert_eq(s.execute_confirm_prompt(p), "view", "confirm_prompt 第四参应为 ViewGame")
