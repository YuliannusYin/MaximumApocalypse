extends GutTest

# 测试 scripts/system/player.gd 的 recover/increaseHunger/decreaseHunger/poison。
# 覆盖 spec/iteration_04_player_state.md §6.1-6.5 全部用例。


var _call_log: Array[String] = []


class _SpyPlayer extends Player:
	var death_called: bool = false
	var death_source: Variant = null
	func playerDeath(source: Variant) -> void:
		death_called = true
		death_source = source


func before_each() -> void:
	_call_log.clear()


# --- 6.1 recover ---

func test_recover_normal() -> void:
	var p := Player.new()
	p.set_hp(3)
	p.recover(2)
	assert_eq(p.get_hp(), 5, "HP=3 + 2 = 5")


func test_recover_exceeds_max_clamped() -> void:
	var p := Player.new()
	p.set_max_hp(6)
	p.set_hp(5)
	p.recover(5)
	assert_eq(p.get_hp(), 6, "clamp 到 max=6")


func test_recover_full_hp_noop() -> void:
	var p := Player.new()
	p.set_max_hp(6)
	p.set_hp(6)
	p.recover(3)
	assert_eq(p.get_hp(), 6, "已满血,max_recover=0,不增加")


func test_recover_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.set_hp(3)
	p.recover(0)
	assert_eq(p.get_hp(), 3, "recover(0) 不变")
	p.recover(-1)
	assert_eq(p.get_hp(), 3, "recover(-1) 不变")


func test_recover_triggers_recover_during_hook() -> void:
	var p := Player.new()
	p.set_max_hp(6)
	p.set_hp(3)
	p.add_skill(Skill.make("回复生命时", Callable(), func(ev: Event) -> void: ev.num += 1))
	p.recover(2)
	# event.num=2 → 钩子 +1 → event.num=3 → max_recover=3 → 不 clamp → 增加生命值(3) → HP=6
	assert_eq(p.get_hp(), 6, "钩子 +1 后 clamp 到 max-HP=3,实际 +3")


func test_recover_triggers_before_and_after_hooks() -> void:
	var p := Player.new()
	p.set_hp(3)
	p.add_skill(_make_recording_skill("回复生命前", "前"))
	p.add_skill(_make_recording_skill("回复生命后", "后"))
	p.recover(2)
	assert_eq(_call_log, ["前", "后"], "[提案] trigger 名也能挂载和触发")


func test_recover_cancel_in_recover_during() -> void:
	var p := Player.new()
	p.set_hp(3)
	p.add_skill(_make_cancel_skill("回复生命时"))
	p.add_skill(_make_recording_skill("回复生命后", "后"))
	p.recover(2)
	assert_eq(p.get_hp(), 3, "cancel 后不增加")
	assert_eq(_call_log, [], "回复生命后 不触发")


func test_recover_negative_after_hook_clamped_to_zero() -> void:
	var p := Player.new()
	p.set_max_hp(6)
	p.set_hp(3)
	p.add_skill(Skill.make("回复生命时", Callable(), func(ev: Event) -> void: ev.num = -5))
	p.recover(2)
	# event.num=-5,增加生命值(-5) 因 n<=0 不变更
	assert_eq(p.get_hp(), 3, "钩子改 num=-5,add_hp 拒绝负数,HP 不变")


# --- 6.2 increaseHunger ---

func test_increaseHunger_below_6_only_increases() -> void:
	var p := Player.new()
	p.set_hunger(2)
	p.increaseHunger(3)
	assert_eq(p.get_hunger(), 5, "hunger=2+3=5")
	assert_eq(p.countMark("饥饿伤害等级"), 0, "无饥饿伤害标记")
	assert_eq(p.get_hp(), 6, "HP 不变")


func test_increaseHunger_at_6_flips_role_card() -> void:
	var p := Player.new()
	p.set_hp(6)
	p.set_hunger(6)
	p.increaseHunger(1)
	assert_false(p.get_role_card().is_front(), "角色卡反面")
	assert_eq(p.countMark("饥饿伤害等级"), 1, "1 层标记")
	assert_eq(p.get_hp(), 4, "level 1 扣 2,HP=6-2=4")


func test_increaseHunger_at_6_already_flipped() -> void:
	var p := Player.new()
	p.set_hp(6)
	p.set_hunger(6)
	p.get_role_card().flip()
	p.increaseHunger(1)
	assert_false(p.get_role_card().is_front(), "角色卡仍反面(不重复翻)")
	assert_eq(p.countMark("饥饿伤害等级"), 1, "1 层标记")
	assert_eq(p.get_hp(), 4, "level 1 扣 2")


func test_increaseHunger_level_2_deals_4_damage() -> void:
	var p := Player.new()
	p.set_hp(10)
	p.set_max_hp(10)
	p.set_hunger(6)
	p.get_role_card().flip()
	p.addMarkSkill("饥饿伤害等级", 1)
	p.increaseHunger(1)
	assert_eq(p.countMark("饥饿伤害等级"), 2, "2 层")
	assert_eq(p.get_hp(), 6, "level 2 扣 4,HP=10-4=6")


func test_increaseHunger_level_3_deals_6_damage() -> void:
	var p := Player.new()
	p.set_hp(20)
	p.set_max_hp(20)
	p.set_hunger(6)
	p.get_role_card().flip()
	p.addMarkSkill("饥饿伤害等级", 2)
	p.increaseHunger(1)
	assert_eq(p.countMark("饥饿伤害等级"), 3, "3 层")
	assert_eq(p.get_hp(), 14, "level 3 扣 6,HP=20-6=14")


func test_increaseHunger_level_4_deals_8_damage() -> void:
	var p := Player.new()
	p.set_hp(20)
	p.set_max_hp(20)
	p.set_hunger(6)
	p.get_role_card().flip()
	p.addMarkSkill("饥饿伤害等级", 3)
	p.increaseHunger(1)
	assert_eq(p.countMark("饥饿伤害等级"), 4, "4 层")
	assert_eq(p.get_hp(), 12, "level 4 扣 8,HP=20-8=12")


func test_increaseHunger_level_5_lethal() -> void:
	var target := _SpyPlayer.new()
	target.set_hp(20)
	target.set_max_hp(20)
	target.set_hunger(6)
	target.get_role_card().flip()
	target.addMarkSkill("饥饿伤害等级", 4)
	target.increaseHunger(1)
	assert_eq(target.countMark("饥饿伤害等级"), 5, "5 层")
	assert_eq(target.get_hp(), 0, "damage(最大生命值=20),HP=20-20=0")
	assert_true(target.death_called, "playerDeath 被调用(stub)")


func test_increaseHunger_multi_point_iteration() -> void:
	var p := Player.new()
	p.set_hp(6)
	p.set_hunger(4)
	p.increaseHunger(3)
	# 第1点:hunger=4<6 → hunger=5,无伤害
	# 第2点:hunger=5<6 → hunger=6,无伤害
	# 第3点:hunger=6==6 → 翻面+1层+扣2
	assert_eq(p.get_hunger(), 6, "hunger=4+3 点 = 6")
	assert_eq(p.countMark("饥饿伤害等级"), 1, "1 层标记")
	assert_false(p.get_role_card().is_front(), "角色卡反面")
	assert_eq(p.get_hp(), 4, "level 1 扣 2,HP=6-2=4")


func test_increaseHunger_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.set_hunger(2)
	p.increaseHunger(0)
	assert_eq(p.get_hunger(), 2, "increaseHunger(0) 不变")
	p.increaseHunger(-1)
	assert_eq(p.get_hunger(), 2, "increaseHunger(-1) 不变")


# --- 6.3 decreaseHunger ---

func test_decreaseHunger_normal() -> void:
	var p := Player.new()
	p.set_hunger(4)
	var result := p.decreaseHunger(2)
	assert_eq(p.get_hunger(), 2, "hunger=4-2=2")
	assert_true(result, "返回 true")


func test_decreaseHunger_floor_at_1() -> void:
	var p := Player.new()
	p.set_hunger(2)
	var result := p.decreaseHunger(5)
	assert_eq(p.get_hunger(), 1, "clamp 到 1")
	assert_true(result, "返回 true(实际减少 1)")


func test_decreaseHunger_already_at_1_returns_false() -> void:
	var p := Player.new()
	p.set_hunger(1)
	var result := p.decreaseHunger(1)
	assert_eq(p.get_hunger(), 1, "hunger 仍 1")
	assert_false(result, "max_reduce=0,返回 false")


func test_decreaseHunger_clears_hunger_marks() -> void:
	var p := Player.new()
	p.set_hunger(6)
	p.addMarkSkill("饥饿伤害等级", 2)
	p.decreaseHunger(1)
	assert_eq(p.get_hunger(), 5, "hunger=6-1=5")
	assert_eq(p.countMark("饥饿伤害等级"), 0, "标记清除")


func test_decreaseHunger_flips_role_card_back() -> void:
	var p := Player.new()
	p.set_hunger(6)
	p.get_role_card().flip()
	p.decreaseHunger(1)
	assert_true(p.get_role_card().is_front(), "翻回正面")


func test_decreaseHunger_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.set_hunger(3)
	var result := p.decreaseHunger(0)
	assert_eq(p.get_hunger(), 3, "decreaseHunger(0) 不变")
	assert_false(result, "返回 false")


# --- 6.4 poison ---

func test_poison_no_mark_noop() -> void:
	var p := Player.new()
	p.set_hp(6)
	p.poison()
	assert_eq(p.get_hp(), 6, "无 poison 标记,HP 不变")


func test_poison_deals_damage_equal_to_mark_level() -> void:
	var p := Player.new()
	p.set_hp(6)
	p.addMarkSkill("poison", 3)
	p.poison()
	assert_eq(p.get_hp(), 3, "poison 3 层,扣 3,HP=6-3=3")


func test_poison_uses_no_source_damage() -> void:
	var p := Player.new()
	p.set_hp(10)
	p.addMarkSkill("poison", 2)
	# 挂"造成伤害前"(source 侧钩子),source=null 不应触发
	p.add_skill(_make_recording_skill("造成伤害前", "S前"))
	p.poison()
	assert_eq(_call_log, [], "source=null,source 侧钩子不触发")


func test_poison_lethal_triggers_playerDeath() -> void:
	var target := _SpyPlayer.new()
	target.set_hp(6)
	target.addMarkSkill("poison", 10)
	target.poison()
	assert_eq(target.get_hp(), -4, "HP=6-10=-4")
	assert_true(target.death_called, "playerDeath 被调用(stub)")


# --- 6.5 集成(与 03 轮 damage) ---

func test_increaseHunger_damage_uses_null_source() -> void:
	var p := Player.new()
	p.set_hp(6)
	p.set_hunger(6)
	# 挂"造成伤害前"(source 侧钩子),increaseHunger 触发 damage(null,...) 不应触发
	p.add_skill(_make_recording_skill("造成伤害前", "S前"))
	p.increaseHunger(1)
	assert_eq(_call_log, [], "increaseHunger 的 damage 用 null source,source 侧钩子不触发")


func test_poison_damage_type_is_poison() -> void:
	var p := Player.new()
	p.set_hp(10)
	p.addMarkSkill("poison", 2)
	var captured_type: Array[String] = []
	p.add_skill(Skill.make("受到伤害时", Callable(), func(ev: Event) -> void: captured_type.append(ev.type)))
	p.poison()
	assert_eq(captured_type, ["poison"], "event.type == 'poison'")


# --- 私有辅助 ---

func _make_recording_skill(trig: String, label: String) -> Skill:
	return Skill.make(trig, Callable(), _record_callable(label))


func _make_cancel_skill(trig: String) -> Skill:
	return Skill.make(trig, Callable(), func(ev: Event) -> void:
		ev.cancel()
	)


func _record_callable(label: String) -> Callable:
	return func(_ev: Event) -> void:
		_call_log.append(label)
