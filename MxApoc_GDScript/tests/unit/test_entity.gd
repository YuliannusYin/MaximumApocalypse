extends GutTest

## Entity 基类单元测试。


# === 测试用 mock 子类 ===

class MockEntity extends Entity:
	var hp: int = 10
	var max_hp: int = 10
	var death_called: bool = false
	var death_source: Variant = null

	func get_hp() -> int:
		return hp

	func get_max_hp() -> int:
		return max_hp

	func reduce_hp(n: int) -> void:
		hp -= n

	func add_hp(n: int) -> void:
		hp += n

	func death(source: Entity, runtime: Variant = null) -> void:
		death_called = true
		death_source = source


# === 1. 技能挂载 ===

func test_add_skill_and_get_all_skills() -> void:
	var e: MockEntity = MockEntity.new()
	assert_eq(e.get_all_skills().size(), 0, "初始无技能")
	var s: Skill = Skill.new()
	s.skill_name = "test_skill"
	e.add_skill(s)
	assert_eq(e.get_all_skills().size(), 1, "挂载后应有 1 个技能")
	assert_eq(e.get_all_skills()[0].skill_name, "test_skill")


func test_remove_skill() -> void:
	var e: MockEntity = MockEntity.new()
	var s: Skill = Skill.new()
	s.skill_name = "test_skill"
	e.add_skill(s)
	e.remove_skill(s)
	assert_eq(e.get_all_skills().size(), 0, "移除后应无技能")


# === 2. trigger 触发 ===

func test_trigger_executes_matching_skill() -> void:
	var e: MockEntity = MockEntity.new()
	var called: Array = []
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(true)
	e.add_skill(s)
	var event: Dictionary = EventSystem.create_event()
	await e.trigger("on_take_damage", event)
	assert_eq(called.size(), 1, "匹配 trigger 的技能 content 应被执行")


func test_trigger_skips_non_matching_skill() -> void:
	var e: MockEntity = MockEntity.new()
	var called: Array = []
	var s: Skill = Skill.new()
	s.trigger = "on_deal_damage"
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(true)
	e.add_skill(s)
	var event: Dictionary = EventSystem.create_event()
	await e.trigger("on_take_damage", event)
	assert_eq(called.size(), 0, "不匹配 trigger 的技能 content 不应执行")


func test_trigger_compound_trigger_matches() -> void:
	var e: MockEntity = MockEntity.new()
	var called: Array = []
	var s: Skill = Skill.new()
	s.trigger = "on_game_start、on_take_damage"
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(true)
	e.add_skill(s)
	var event: Dictionary = EventSystem.create_event()
	await e.trigger("on_take_damage", event)
	assert_eq(called.size(), 1, "复合 trigger 中包含匹配项时应执行")


func test_trigger_filter_false_skips_content() -> void:
	var e: MockEntity = MockEntity.new()
	var called: Array = []
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.filter = func(_p, _t, _ev: Dictionary, _g) -> bool:
		return false
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(true)
	e.add_skill(s)
	var event: Dictionary = EventSystem.create_event()
	await e.trigger("on_take_damage", event)
	assert_eq(called.size(), 0, "filter 返回 false 时 content 不应执行")


func test_trigger_cancel_breaks_loop() -> void:
	var e: MockEntity = MockEntity.new()
	var call_order: Array = []
	var s1: Skill = Skill.new()
	s1.trigger = "on_take_damage"
	s1.content = func(_p, _t, ev: Dictionary, _g) -> void:
		call_order.append("s1")
		EventSystem.cancel(ev)
	var s2: Skill = Skill.new()
	s2.trigger = "on_take_damage"
	s2.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_order.append("s2")
	e.add_skill(s1)
	e.add_skill(s2)
	var event: Dictionary = EventSystem.create_event()
	await e.trigger("on_take_damage", event)
	assert_eq(call_order, ["s1"], "cancel 后应中断后续技能")
	assert_true(EventSystem.is_cancelled(event), "event 应已取消")


# === 3. damage 流程 ===

func test_damage_reduces_hp() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 10
	target.damage(3, null)
	assert_eq(target.hp, 7, "无 source 伤害应扣 3 血")


func test_damage_zero_or_negative_no_effect() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 10
	target.damage(0, null)
	assert_eq(target.hp, 10, "0 伤害不应扣血")
	target.damage(-5, null)
	assert_eq(target.hp, 10, "负伤害不应扣血")


func test_damage_dead_target_no_effect() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 0
	target.damage(5, null)
	assert_eq(target.hp, 0, "已死亡目标不应再受伤害")
	assert_false(target.death_called, "不应再次触发 death")


func test_damage_with_source_triggers_all_hooks() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 10
	var source: MockEntity = MockEntity.new()
	var call_log: Array = []
	# 给 source 挂载造成伤害前/时/后
	var s_before: Skill = Skill.new()
	s_before.trigger = "before_deal_damage"
	s_before.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("source_before_deal")
	var s_on: Skill = Skill.new()
	s_on.trigger = "on_deal_damage"
	s_on.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("source_on_deal")
	var s_after: Skill = Skill.new()
	s_after.trigger = "after_deal_damage"
	s_after.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("source_after_deal")
	source.add_skill(s_before)
	source.add_skill(s_on)
	source.add_skill(s_after)
	# 给 target 挂载受到伤害前/时/后
	var t_before: Skill = Skill.new()
	t_before.trigger = "before_take_damage"
	t_before.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("target_before_take")
	var t_on: Skill = Skill.new()
	t_on.trigger = "on_take_damage"
	t_on.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("target_on_take")
	var t_after: Skill = Skill.new()
	t_after.trigger = "after_take_damage"
	t_after.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("target_after_take")
	target.add_skill(t_before)
	target.add_skill(t_on)
	target.add_skill(t_after)
	target.damage(3, source)
	assert_eq(call_log, [
		"source_before_deal", "target_before_take",
		"source_on_deal", "target_on_take",
		"source_after_deal", "target_after_take",
	], "8 节点顺序应正确")
	assert_eq(target.hp, 7, "应扣 3 血")


func test_damage_no_source_skips_source_hooks() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 10
	var source: MockEntity = MockEntity.new()
	var call_log: Array = []
	var s_before: Skill = Skill.new()
	s_before.trigger = "before_deal_damage"
	s_before.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("source_before_deal")
	source.add_skill(s_before)
	var t_before: Skill = Skill.new()
	t_before.trigger = "before_take_damage"
	t_before.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		call_log.append("target_before_take")
	target.add_skill(t_before)
	target.damage(3, null)
	assert_eq(call_log, ["target_before_take"], "无 source 时只触发 target 钩子")
	assert_eq(target.hp, 7)


func test_damage_cancel_prevents_hp_loss() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 10
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		EventSystem.cancel(ev)
	target.add_skill(s)
	target.damage(5, null)
	assert_eq(target.hp, 10, "on_take_damage 取消后不应扣血")


func test_damage_modify_num_via_hook() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 10
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		ev["num"] = 2  # 减少 5 → 2
	target.add_skill(s)
	target.damage(5, null)
	assert_eq(target.hp, 8, "on_take_damage 修改 num 后应按新值扣血")


func test_damage_lethal_triggers_death() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 3
	var source: MockEntity = MockEntity.new()
	target.damage(5, source)
	assert_true(target.death_called, "致命伤害应触发 death")
	assert_eq(target.death_source, source, "death 应收到 source")


func test_damage_lethal_no_source_death_source_null() -> void:
	var target: MockEntity = MockEntity.new()
	target.hp = 3
	target.damage(5, null)
	assert_true(target.death_called, "致命无源伤害应触发 death")
	assert_null(target.death_source, "death 的 source 应为 null")
