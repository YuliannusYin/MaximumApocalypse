extends GutTest

# 测试 scripts/system/player.gd 与 role_card.gd。
# 覆盖 spec/iteration_02_player_entity.md §6.1-6.8 全部用例。


# --- 6.1 状态查询 ---

func test_new_player_has_default_hp() -> void:
	var p := Player.new()
	assert_eq(p.get_hp(), 6, "默认 HP=6")
	assert_eq(p.get_max_hp(), 6, "默认 max HP=6")


func test_new_player_has_default_hunger() -> void:
	var p := Player.new()
	assert_eq(p.get_hunger(), 1, "默认 hunger=1")


func test_new_player_has_default_sneak() -> void:
	var p := Player.new()
	assert_eq(p.get_sneak(), 0, "默认 sneak=0")


func test_new_player_role_card_front() -> void:
	var p := Player.new()
	assert_true(p.get_role_card().is_front(), "角色卡默认正面")


func test_get_current_block_returns_null_stub() -> void:
	var p := Player.new()
	assert_null(p.get_current_block(), "02 轮 stub 返回 null")


# --- 6.2 add_hp(§9.6 处理) ---

func test_add_hp_increases_hp() -> void:
	var p := Player.new()
	p.set_hp(3)
	p.add_hp(2)
	assert_eq(p.get_hp(), 5, "HP=3 + 2 = 5")


func test_add_hp_exceeds_max_not_clamped() -> void:
	var p := Player.new()
	p.set_max_hp(6)
	p.set_hp(5)
	p.add_hp(5)
	assert_eq(p.get_hp(), 10, "不受最大值约束,与 recover 区别")


func test_add_hp_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.set_hp(3)
	p.add_hp(0)
	assert_eq(p.get_hp(), 3, "0 不变更")
	p.add_hp(-1)
	assert_eq(p.get_hp(), 3, "负数不变更")


# --- 6.3 add_hunger(§9.7 处理) ---

func test_add_hunger_increases_hunger() -> void:
	var p := Player.new()
	p.set_hunger(2)
	p.add_hunger(3)
	assert_eq(p.get_hunger(), 5, "hunger=2 + 3 = 5")


func test_add_hunger_does_not_flip_at_6() -> void:
	var p := Player.new()
	p.set_hunger(6)
	p.add_hunger(1)
	assert_eq(p.get_hunger(), 7, "不翻面,数值可超 6")
	assert_true(p.get_role_card().is_front(), "仍正面,与 increaseHunger 区别")


func test_add_hunger_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.set_hunger(2)
	p.add_hunger(0)
	assert_eq(p.get_hunger(), 2, "0 不变更")
	p.add_hunger(-1)
	assert_eq(p.get_hunger(), 2, "负数不变更")


# --- 6.4 reduce_hunger(§9.7 处理) ---

func test_reduce_hunger_decreases_hunger() -> void:
	var p := Player.new()
	p.set_hunger(4)
	p.reduce_hunger(2)
	assert_eq(p.get_hunger(), 2, "hunger=4 - 2 = 2")


func test_reduce_hunger_floor_at_1() -> void:
	var p := Player.new()
	p.set_hunger(2)
	p.reduce_hunger(5)
	assert_eq(p.get_hunger(), 1, "最低降至 1")


func test_reduce_hunger_does_not_clear_marks() -> void:
	var p := Player.new()
	p.set_hunger(6)
	p.addMarkSkill("饥饿伤害等级", 2)
	p.reduce_hunger(1)
	assert_eq(p.countMark("饥饿伤害等级"), 2, "不清饥饿伤害标记,与 decreaseHunger 区别")
	assert_true(p.get_role_card().is_front(), "不翻回正面(本来就没翻)")


func test_reduce_hunger_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.set_hunger(4)
	p.reduce_hunger(0)
	assert_eq(p.get_hunger(), 4, "0 不变更")
	p.reduce_hunger(-1)
	assert_eq(p.get_hunger(), 4, "负数不变更")


# --- 6.5 潜行值 ---

func test_add_sneak() -> void:
	var p := Player.new()
	p.set_sneak(3)
	p.add_sneak(2)
	assert_eq(p.get_sneak(), 5, "sneak=3 + 2 = 5")


func test_reduce_sneak() -> void:
	var p := Player.new()
	p.set_sneak(5)
	p.reduce_sneak(2)
	assert_eq(p.get_sneak(), 3, "sneak=5 - 2 = 3")


func test_reduce_sneak_can_go_negative() -> void:
	var p := Player.new()
	p.set_sneak(2)
	p.reduce_sneak(5)
	assert_eq(p.get_sneak(), -3, "潜行值可为负")


# --- 6.6 角色卡牌 ---

func test_role_card_flip_toggles() -> void:
	var rc := RoleCard.new()
	assert_true(rc.is_front(), "初始正面")
	rc.flip()
	assert_false(rc.is_front(), "翻面后反面")
	rc.flip()
	assert_true(rc.is_front(), "再翻面回正面")


# --- 6.7 标记系统 ---

func test_addMarkSkill_adds_quantity() -> void:
	var p := Player.new()
	p.addMarkSkill("poison", 2)
	assert_eq(p.countMark("poison"), 2, "添加 2 层 poison")


func test_addMarkSkill_default_quantity_1() -> void:
	var p := Player.new()
	p.addMarkSkill("poison")
	assert_eq(p.countMark("poison"), 1, "默认 quantity=1")


func test_addMarkSkill_accumulates() -> void:
	var p := Player.new()
	p.addMarkSkill("poison", 1)
	p.addMarkSkill("poison", 2)
	assert_eq(p.countMark("poison"), 3, "累积到 3 层")


func test_removeMarkSkill_clears() -> void:
	var p := Player.new()
	p.addMarkSkill("poison", 3)
	p.removeMarkSkill("poison")
	assert_eq(p.countMark("poison"), 0, "移除后 countMark=0")
	assert_false(p.hasMarkSkill("poison"), "hasMarkSkill=false")


func test_countMark_nonexistent_returns_0() -> void:
	var p := Player.new()
	assert_eq(p.countMark("不存在的标记"), 0, "未添加的标记 countMark=0")


func test_hasMarkSkill() -> void:
	var p := Player.new()
	assert_false(p.hasMarkSkill("poison"), "未添加时 false")
	p.addMarkSkill("poison", 1)
	assert_true(p.hasMarkSkill("poison"), "添加后 true")
	p.removeMarkSkill("poison")
	assert_false(p.hasMarkSkill("poison"), "移除后 false")


func test_addMarkSkill_zero_or_negative_noop() -> void:
	var p := Player.new()
	p.addMarkSkill("poison", 0)
	assert_eq(p.countMark("poison"), 0, "quantity=0 不变更")
	p.addMarkSkill("poison", -1)
	assert_eq(p.countMark("poison"), 0, "quantity=-1 不变更")


# --- 6.8 与 Entity 集成 ---

func test_player_inherits_entity_skills() -> void:
	var p := Player.new()
	var s := Skill.new()
	s.trigger = "受到伤害时"
	p.add_skill(s)
	assert_eq(p.get_all_skills().size(), 1, "Player 继承 Entity.add_skill")
	p.remove_skill(s)
	assert_eq(p.get_all_skills().size(), 0, "Player 继承 Entity.remove_skill")


func test_player_trigger_invokes_skills() -> void:
	var p := Player.new()
	var called: Array[String] = []
	var s := Skill.make("受到伤害时", Callable(), func(_ev: Event) -> void: called.append("X"))
	p.add_skill(s)
	var event := Event.new()
	p.trigger("受到伤害时", event)
	assert_eq(called, ["X"], "Player.trigger 复用 Entity 机制正确触发技能")
