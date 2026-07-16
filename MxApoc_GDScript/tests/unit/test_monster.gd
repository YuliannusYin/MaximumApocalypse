extends GutTest

## Monster 单元测试。


# === 测试用 mock player ===

class MockPlayer extends Player:
	var damage_received: Array = []  # 记录 [(num, source, type), ...]

	func _init() -> void:
		hp = 10
		max_hp = 10

	func damage(num: int, source: Entity, type: Variant = "", card: Card = null) -> void:
		damage_received.append([num, source, type])
		hp = maxi(hp - num, 0)


# === 测试用 mock block ===

class MockBlock extends MapBlock:
	var players_in_range: Array = []

	func get_players_in_range(_range_str: String) -> Array:
		return players_in_range


# === 辅助方法 ===

func _make_monster() -> Monster:
	var m: Monster = Monster.new()
	m.monster_name = "测试怪物"
	m.monster_type = "zombie"
	m.monster_level = "normal"
	m.max_hp = 5
	m.hp = 5
	m.damage_value = 2
	m.range = "none"
	return m


func _make_skill_with_trigger(trigger_name: String, called: Array) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(trigger_name)
	return s


# === 1. 默认字段 ===

func test_default_fields() -> void:
	var m: Monster = Monster.new()
	assert_eq(m.monster_name, "")
	assert_eq(m.monster_type, "")
	assert_eq(m.monster_level, "normal")
	assert_eq(m.hp, 0)
	assert_eq(m.max_hp, 0)
	assert_eq(m.damage_value, 0)
	assert_eq(m.range, "none")
	assert_null(m.attack_target)
	assert_null(m.monster_card)
	assert_false(m.stunned)


# === 2. 生命值接口 ===

func test_get_hp() -> void:
	var m: Monster = _make_monster()
	assert_eq(m.get_hp(), 5)


func test_get_max_hp() -> void:
	var m: Monster = _make_monster()
	assert_eq(m.get_max_hp(), 5)


func test_reduce_hp() -> void:
	var m: Monster = _make_monster()
	m.reduce_hp(3)
	assert_eq(m.hp, 2)


func test_reduce_hp_floor_zero() -> void:
	var m: Monster = _make_monster()
	m.reduce_hp(100)
	assert_eq(m.hp, 0, "生命值下限为 0")


func test_add_hp() -> void:
	var m: Monster = _make_monster()
	m.reduce_hp(3)
	m.add_hp(2)
	assert_eq(m.hp, 4)


func test_add_hp_capped_at_max() -> void:
	var m: Monster = _make_monster()
	m.add_hp(100)
	assert_eq(m.hp, 5, "生命值上限为 max_hp")


func test_is_monster_returns_true() -> void:
	var m: Monster = Monster.new()
	assert_true(m.is_monster())


func test_is_player_returns_false() -> void:
	var m: Monster = Monster.new()
	assert_false(m.is_player())


# === 3. 行动流程 ===

func test_act_six_node_trigger_order() -> void:
	var m: Monster = _make_monster()
	var p: MockPlayer = MockPlayer.new()
	m.attack_target = p
	var called: Array = []
	# 6 个 trigger 各挂一个技能
	for tname in ["before_monster_act", "on_monster_act", "before_monster_attack", "on_monster_attack", "after_monster_attack", "after_monster_act"]:
		m.add_skill(_make_skill_with_trigger(tname, called))
	await m.act()
	assert_eq(called, ["before_monster_act", "on_monster_act", "before_monster_attack", "on_monster_attack", "after_monster_attack", "after_monster_act"])


func test_act_stunned_skips_and_resets() -> void:
	var m: Monster = _make_monster()
	m.stunned = true
	var called: Array = []
	m.add_skill(_make_skill_with_trigger("on_monster_act", called))
	await m.act()
	assert_eq(called.size(), 0, "击晕的怪物跳过行动")
	assert_false(m.stunned, "击晕状态重置为 false")


func test_act_not_stunned_does_not_reset() -> void:
	var m: Monster = _make_monster()
	m.stunned = false
	await m.act()
	assert_false(m.stunned)


# === 4. 攻击流程 ===

func test_attack_none_range_only_targets_attack_target() -> void:
	var m: Monster = _make_monster()
	m.range = "none"
	var p: MockPlayer = MockPlayer.new()
	m.attack_target = p
	m._attack()
	assert_eq(p.damage_received.size(), 1, "none 射程只攻击纠缠玩家一次")
	assert_eq(p.damage_received[0][0], 2, "伤害值为 damage_value")
	assert_eq(p.damage_received[0][1], m, "source 为怪物自身")


func test_attack_with_range_uses_block_players_in_range() -> void:
	var m: Monster = _make_monster()
	m.range = "short"
	m.damage_value = 3
	var p1: MockPlayer = MockPlayer.new()
	var p2: MockPlayer = MockPlayer.new()
	var block: MockBlock = MockBlock.new()
	block.players_in_range = [p1, p2]
	p1.current_block = block
	p2.current_block = block
	m.attack_target = p1
	m._attack()
	assert_eq(p1.damage_received.size(), 1)
	assert_eq(p2.damage_received.size(), 1, "short 射程攻击地块上所有玩家")
	assert_eq(p1.damage_received[0][0], 3)


func test_attack_null_attack_target_safe_return() -> void:
	var m: Monster = _make_monster()
	m.attack_target = null
	# 不应抛错
	m._attack()
	assert_true(true, "attack_target 为 null 时安全返回")


func test_attack_dead_attack_target_skipped() -> void:
	var m: Monster = _make_monster()
	var p: MockPlayer = MockPlayer.new()
	p.hp = 0  # 死亡
	m.attack_target = p
	m._attack()
	assert_eq(p.damage_received.size(), 0, "纠缠玩家死亡时不再攻击")


func test_attack_invalid_block_safe_return() -> void:
	var m: Monster = _make_monster()
	var p: MockPlayer = MockPlayer.new()
	p.current_block = null
	m.attack_target = p
	m._attack()
	assert_true(true, "block 为 null 时安全返回")


# === 5. 死亡流程 ===

func test_death_three_node_trigger_order() -> void:
	var m: Monster = _make_monster()
	var called: Array = []
	for tname in ["before_monster_death", "on_monster_death", "after_monster_death"]:
		m.add_skill(_make_skill_with_trigger(tname, called))
	await m.death(null)
	assert_eq(called, ["before_monster_death", "on_monster_death", "after_monster_death"])


func test_death_removes_from_attack_target_monster_zone() -> void:
	var m: Monster = _make_monster()
	var p: MockPlayer = MockPlayer.new()
	p.monster_zone = [m]
	m.attack_target = p
	await m.death(null)
	assert_eq(p.monster_zone.size(), 0, "应从纠缠玩家怪物区移除")


func test_death_enters_monster_discard_pile() -> void:
	var m: Monster = _make_monster()
	# 暂用 Pile 作为 discard_pile
	var discard: Pile = Pile.new()
	Game.monster_discard_pile = discard
	await m.death(null)
	assert_eq(discard.size(), 1, "应进入怪物弃牌堆")
	# 清理
	Game.monster_discard_pile = null


func test_death_null_attack_target_safe() -> void:
	var m: Monster = _make_monster()
	m.attack_target = null
	Game.monster_discard_pile = Pile.new()
	await m.death(null)
	assert_true(true, "attack_target 为 null 时安全执行")
	Game.monster_discard_pile = null


# === 6. 修改纠缠对象 ===

func test_change_engaged_target_sets_field() -> void:
	var m: Monster = _make_monster()
	var p1: MockPlayer = MockPlayer.new()
	var p2: MockPlayer = MockPlayer.new()
	m.attack_target = p1
	m.change_engaged_target(p2)
	assert_eq(m.attack_target, p2, "应更新纠缠对象")


func test_change_engaged_target_emits_signal() -> void:
	var received: Array = []
	EventBus.monster_engaged_target_changed.connect(
		func(monster, old_t, new_t): received.append([monster, old_t, new_t])
	)
	var m: Monster = _make_monster()
	var p1: MockPlayer = MockPlayer.new()
	var p2: MockPlayer = MockPlayer.new()
	m.attack_target = p1
	m.change_engaged_target(p2)
	assert_eq(received.size(), 1, "应发射 1 次信号")
	assert_eq(received[0][0], m, "信号 monster 参数应为怪物自身")
	assert_eq(received[0][1], p1, "信号 old_target 应为原纠缠对象")
	assert_eq(received[0][2], p2, "信号 new_target 应为新纠缠对象")
	EventBus.monster_engaged_target_changed.get_connections().map(
		func(c): EventBus.monster_engaged_target_changed.disconnect(c.callable)
	)


# === 7. MonsterCard.instantiate ===

func test_monster_card_instantiate_creates_monster() -> void:
	var card: MonsterCard = MonsterCard.new()
	card.card_name = "测试僵尸"
	card.monster_type = "zombie"
	card.monster_level = "elite"
	card.max_hp = 7
	card.damage_value = 3
	card.range = "medium"
	var p: MockPlayer = MockPlayer.new()
	var m: Monster = card.instantiate(p)
	assert_eq(m.monster_name, "测试僵尸")
	assert_eq(m.monster_type, "zombie")
	assert_eq(m.monster_level, "elite")
	assert_eq(m.max_hp, 7)
	assert_eq(m.hp, 7, "实体化时当前生命值 = 最大生命值")
	assert_eq(m.damage_value, 3)
	assert_eq(m.range, "medium")
	assert_eq(m.attack_target, p)
	assert_eq(m.monster_card, card)


func test_monster_card_instantiate_copies_skills() -> void:
	var card: MonsterCard = MonsterCard.new()
	var s1: Skill = Skill.new()
	s1.skill_name = "技能1"
	s1.trigger = "on_monster_act"
	var s2: Skill = Skill.new()
	s2.skill_name = "技能2"
	s2.trigger = "before_monster_death"
	card.add_skill(s1)
	card.add_skill(s2)
	var p: MockPlayer = MockPlayer.new()
	var m: Monster = card.instantiate(p)
	assert_eq(m.get_all_skills().size(), 2, "应挂载 2 个技能到 Monster")


func test_monster_card_instantiate_returns_monster_instance() -> void:
	var card: MonsterCard = MonsterCard.new()
	var p: MockPlayer = MockPlayer.new()
	var m: Monster = card.instantiate(p)
	assert_true(m is Monster, "应返回 Monster 实例")
