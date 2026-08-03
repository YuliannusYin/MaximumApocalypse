extends GutTest

## Skill 单元测试。


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
	var event: Dictionary = EventSystem.create_event()
	assert_true(s.execute_filter(null, event), "无 filter 时应返回 true")


func test_execute_filter_with_filter() -> void:
	var s: Skill = Skill.new()
	s.filter = func(_p, _t, ev: Dictionary, _g) -> bool:
		return ev.get("num", 0) > 0
	var event_pos: Dictionary = EventSystem.create_event({"num": 5})
	var event_zero: Dictionary = EventSystem.create_event({"num": 0})
	assert_true(s.execute_filter(null, event_pos))
	assert_false(s.execute_filter(null, event_zero))


func test_execute_content() -> void:
	var s: Skill = Skill.new()
	var captured: Array = []
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		captured.append(ev.get("num", 0))
	var event: Dictionary = EventSystem.create_event({"num": 7})
	s.execute_content(null, event)
	assert_eq(captured, [7])


func test_execute_content_no_content_does_nothing() -> void:
	var s: Skill = Skill.new()
	var event: Dictionary = EventSystem.create_event()
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
