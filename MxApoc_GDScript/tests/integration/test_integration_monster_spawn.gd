extends TestBase

## 集成测试：怪物生成 + 行动 + 死亡 全链路。
## 覆盖 Player.draw_monster + MonsterCard.instantiate + Monster.act + Monster.death。
## 设计文档：GameDesignDocus/GameSystem/Entities/Monster.md


# === 辅助方法 ===

func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0, revealed: bool = true) -> MapBlock:
	return super._make_block(block_name, x, y, revealed)


func _make_custom_monster_card(name: String = "zombie", level: String = "normal", hp: int = 3, dmg: int = 2) -> MonsterCard:
	var c: MonsterCard = MonsterCard.new()
	c.card_name = name
	c.card_type = "monster"
	c.source = "monster"
	c.monster_type = "zombie"
	c.monster_level = level
	c.max_hp = hp
	c.damage_value = dmg
	c.range = "none"
	return c


# === 测试用例 ===

func test_draw_monster_instantiates_and_enters_zone() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	var mc: MonsterCard = _make_custom_monster_card("zombie1")
	Game.monster_pile.add(mc)
	# draw_monster 应实体化怪物并进入怪物区
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 1, "怪物区应有 1 个怪物")
	var m: Monster = p.monster_zone[0]
	assert_eq(m.monster_name, "zombie1", "怪物名应来自卡牌")
	assert_eq(m.attack_target, p, "纠缠对象应是玩家")
	assert_eq(m.hp, 3, "生命值应来自卡牌")


func test_monster_act_attacks_target_player() -> void:
	var p: Player = _make_player("A", 10)
	Game.players = [p]
	# 直接构造怪物并加入怪物区
	var mc: MonsterCard = _make_custom_monster_card("zombie", "normal", 3, 4)
	var m: Monster = mc.instantiate(p)
	p.monster_zone.append(m)
	# 怪物行动：range=none 只攻击纠缠玩家
	var initial_hp: int = p.hp
	await m.act()
	assert_eq(p.hp, initial_hp - 4, "玩家应受到 4 点伤害")


func test_monster_death_removes_from_zone_and_goes_to_discard() -> void:
	var p: Player = _make_player("A", 10)
	Game.players = [p]
	Game.monster_discard_pile = Pile.new()
	var mc: MonsterCard = _make_custom_monster_card("zombie", "normal", 3, 2)
	var m: Monster = mc.instantiate(p)
	p.monster_zone.append(m)
	# 造成 3 点伤害致死
	m.damage(3, p, "counter_attack")
	assert_eq(p.monster_zone.size(), 0, "死亡后应从怪物区移除")
	assert_eq(Game.monster_discard_pile.get_all().size(), 1, "应进入怪物弃牌堆")


func test_draw_monster_empty_pile_reshuffles_discard() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	# 牌堆空，弃牌堆有 1 张
	var mc: MonsterCard = _make_custom_monster_card("zombie1")
	Game.monster_discard_pile.add(mc)
	# draw_monster 应重洗弃牌堆
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 1, "应实体化 1 个怪物")
	assert_eq(Game.monster_pile.get_all().size(), 0, "牌堆应再次空")
	assert_eq(Game.monster_discard_pile.get_all().size(), 0, "弃牌堆应清空")


func test_draw_monster_empty_pile_and_discard_triggers_lose() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	# 牌堆与弃牌堆均空
	await p.draw_monster(1)
	assert_true(Game.game_over_called, "无怪可抽应触发 game_over")
	assert_eq(Game.game_result, "lose")
