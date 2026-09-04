extends TestBase

## 集成测试：抓牌 + 弃牌 + 弃牌堆分派 全链路。
## 覆盖 Player.draw + Player.discard + Pile 循环 + 弃牌堆按 source 分派。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md


# === 测试用例 ===

func test_draw_from_deck_then_discard_to_pile() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var c1: Card = _make_card("action1")
	var c2: Card = _make_card("action2")
	p.game_deck.add(c1)
	p.game_deck.add(c2)
	# 抓 2 张
	await p.draw(2)
	assert_eq(p.hand.size(), 2, "应抓 2 张到手牌")
	assert_eq(p.game_deck.get_all().size(), 0, "牌堆应清空")
	# 弃掉第一张
	await p.discard(c1)
	assert_eq(p.hand.size(), 1, "弃掉后手牌 -1")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "弃牌堆应 +1")
	assert_eq(p.game_discard_pile.get_all()[0], c1, "弃掉的应是 c1")


func test_discard_scavenge_card_goes_to_scavenge_discard() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.scavenge_discard_pile = Pile.new()
	var sc: ScavengeCard = _make_scavenge_card("bandage", "red")
	p.hand.append(sc)
	# 弃掉拾荒卡
	await p.discard(sc)
	assert_eq(p.hand.size(), 0, "手牌应清空")
	assert_eq(Game.scavenge_discard_pile.get_all().size(), 1, "应进入拾荒弃牌堆")
	assert_eq(Game.scavenge_discard_pile.get_all()[0], sc, "弃掉的应是拾荒卡")


func test_discard_equipment_triggers_unequip() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e: EquipmentCard = _make_equipment("weapon")
	# 装备区放入装备 + 挂载技能（equip 实体化并自动挂载技能到玩家）
	var s: Skill = Skill.new()
	s.skill_name = "equip_skill"
	s.trigger = "on_use_card"
	e.add_skill(s)
	var called: Array = []
	var s_unequip: Skill = Skill.new()
	s_unequip.trigger = "on_unequip"
	s_unequip.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append("on_unequip")
	e.add_skill(s_unequip)
	await p.equip(e)
	assert_true(p.has_equipment("weapon"), "应有装备")
	assert_eq(p.get_all_skills().size(), 2, "装备技能应已挂载")
	# 弃掉装备（来源卡入弃牌堆，实体从区里移除并卸下技能）
	await p.discard(e)
	assert_false(p.has_equipment("weapon"), "装备应已卸下")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "装备应进入弃牌堆")
	assert_eq(p.game_discard_pile.get_all()[0], e, "弃牌堆应为来源卡")
	assert_eq(p.get_all_skills().size(), 0, "弃置装备应移除技能（触发 unequip）")
	assert_eq(called, ["on_unequip"], "弃置装备区装备应触发 on_unequip")


func test_pile_shuffle_into_recycles_discard() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	# 怪物牌堆空，弃牌堆有 2 张
	var mc1: MonsterCard = MonsterCard.new()
	mc1.card_name = "zombie1"
	mc1.monster_type = "zombie"
	mc1.monster_level = "normal"
	mc1.max_hp = 3
	mc1.damage_value = 2
	mc1.range = "none"
	var mc2: MonsterCard = MonsterCard.new()
	mc2.card_name = "zombie2"
	mc2.monster_type = "zombie"
	mc2.monster_level = "normal"
	mc2.max_hp = 3
	mc2.damage_value = 2
	mc2.range = "none"
	Game.monster_discard_pile.add(mc1)
	Game.monster_discard_pile.add(mc2)
	# draw_monster 应触发重洗
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 1, "应实体化 1 个怪物")
	assert_eq(Game.monster_pile.get_all().size(), 1, "牌堆应剩 1 张（重洗 2 - 抽 1）")
	assert_eq(Game.monster_discard_pile.get_all().size(), 0, "弃牌堆应清空")
