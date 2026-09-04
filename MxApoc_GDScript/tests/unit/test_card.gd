extends TestBase

## Card 继承体系单元测试。


# === Card 基类 ===

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


# === EquipmentCard ===

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

func test_monster_card_instantiate_returns_monster_instance() -> void:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = "僵尸步行者"
	mc.monster_type = "zombie"
	mc.max_hp = 3
	var monster: Monster = mc.instantiate(null)
	assert_true(monster is Monster, "Monster 类已实现，instantiate 应返回 Monster 实例")
