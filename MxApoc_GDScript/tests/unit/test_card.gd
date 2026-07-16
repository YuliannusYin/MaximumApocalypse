extends GutTest

## Card 继承体系单元测试。


# === Card 基类 ===

func test_card_default_fields() -> void:
	var c: Card = Card.new()
	assert_eq(c.card_name, "")
	assert_eq(c.card_type, "")
	assert_eq(c.source, "")
	assert_eq(c.get_all_skills().size(), 0, "Card 应继承 Entity 的技能列表")


func test_card_can_mount_skill_and_trigger() -> void:
	var c: Card = Card.new()
	var called: Array = []
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(true)
	c.add_skill(s)
	var event: Dictionary = EventSystem.create_event()
	await c.trigger("on_take_damage", event)
	assert_eq(called.size(), 1, "Card 应能挂载技能并触发")


func test_card_is_entity() -> void:
	var c: Card = Card.new()
	assert_false(c.is_player(), "Card 不应是 Player")
	assert_false(c.is_monster(), "Card 不应是 Monster")


# === ScavengeCard ===

func test_scavenge_card_fields() -> void:
	var sc: ScavengeCard = ScavengeCard.new()
	sc.card_name = "伏击！"
	sc.color = "red"
	sc.scavenge_type = "ambush"
	sc.source = "scavenge"
	assert_eq(sc.card_name, "伏击！")
	assert_eq(sc.color, "red")
	assert_eq(sc.scavenge_type, "ambush")
	assert_eq(sc.source, "scavenge")


func test_scavenge_card_inherits_card() -> void:
	var sc: ScavengeCard = ScavengeCard.new()
	# 继承 Card 字段
	sc.card_name = "燃料"
	sc.source = "scavenge"
	assert_eq(sc.card_name, "燃料")
	# 继承 Entity 技能机制
	var s: Skill = Skill.new()
	sc.add_skill(s)
	assert_eq(sc.get_all_skills().size(), 1)


# === SurvivorGameCard ===

func test_survivor_game_card_fields() -> void:
	var sgc: SurvivorGameCard = SurvivorGameCard.new()
	sgc.card_name = "柯尔特手枪"
	sgc.card_subtype = "equipment"
	sgc.size = 2
	sgc.range = "short"
	sgc.source = "game"
	assert_eq(sgc.card_subtype, "equipment")
	assert_eq(sgc.size, 2)
	assert_eq(sgc.range, "short")


func test_survivor_game_card_action_type() -> void:
	var sgc: SurvivorGameCard = SurvivorGameCard.new()
	sgc.card_subtype = "action"
	sgc.range = "none"
	assert_eq(sgc.card_subtype, "action")
	assert_eq(sgc.range, "none")


# === EquipmentCard ===

func test_equipment_card_fields() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.card_name = "柯尔特手枪"
	ec.card_subtype = "equipment"
	ec.charge_type = "ammo"
	ec.charge_max = 6
	ec.charge_current = 6
	assert_eq(ec.charge_type, "ammo")
	assert_eq(ec.charge_max, 6)
	assert_eq(ec.charge_current, 6)


func test_equipment_card_consume_charge_success() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_max = 6
	ec.charge_current = 4
	var ok: bool = await ec.consume_charge(2)
	assert_true(ok, "充足时应消耗成功")
	assert_eq(ec.charge_current, 2, "消耗后剩余 2")


func test_equipment_card_consume_charge_fail() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_max = 6
	ec.charge_current = 1
	var ok: bool = await ec.consume_charge(2)
	assert_false(ok, "不足时应失败")
	assert_eq(ec.charge_current, 1, "失败后应保持不变")


func test_equipment_card_consume_charge_exact() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_max = 6
	ec.charge_current = 3
	var ok: bool = await ec.consume_charge(3)
	assert_true(ok, "刚好相等时应成功")
	assert_eq(ec.charge_current, 0, "消耗后应为 0")


func test_equipment_card_has_charge() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_current = 0
	assert_false(ec.has_charge(), "0 时应无填充物")
	ec.charge_current = 1
	assert_true(ec.has_charge(), "≥1 时应有填充物")


func test_equipment_card_refill() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_max = 6
	ec.charge_current = 2
	ec.refill(3)
	assert_eq(ec.charge_current, 5, "补充 3 后应为 5")


func test_equipment_card_refill_capped() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_max = 6
	ec.charge_current = 4
	ec.refill(10)
	assert_eq(ec.charge_current, 6, "补充超过上限应被截断")


func test_equipment_card_is_weapon_card() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.card_subtype = "equipment"
	ec.range = "short"
	assert_true(ec.is_weapon_card(), "有射程的装备牌应是武器")
	ec.range = "none"
	assert_false(ec.is_weapon_card(), "无射程的装备牌不是武器")
	ec.range = "short"
	ec.card_subtype = "action"
	assert_false(ec.is_weapon_card(), "行动牌不是武器")


# === MonsterCard ===

func test_monster_card_fields() -> void:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = "僵尸步行者"
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = 3
	mc.damage_value = 1
	mc.range = "none"
	mc.source = "monster"
	assert_eq(mc.monster_type, "zombie")
	assert_eq(mc.monster_level, "normal")
	assert_eq(mc.max_hp, 3)
	assert_eq(mc.damage_value, 1)


func test_monster_card_boss_flag() -> void:
	var mc: MonsterCard = MonsterCard.new()
	mc.monster_level = "boss"
	mc.is_boss = true
	assert_true(mc.is_boss, "首领卡标记应为 true")


func test_monster_card_instantiate_returns_monster_instance() -> void:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = "僵尸步行者"
	mc.monster_type = "zombie"
	mc.max_hp = 3
	var monster: Monster = mc.instantiate(null)
	assert_true(monster is Monster, "Monster 类已实现，instantiate 应返回 Monster 实例")
