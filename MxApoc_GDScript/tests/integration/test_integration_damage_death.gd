extends GutTest

## 集成测试：伤害 → 死亡 → 游戏结束 全链路。
## 覆盖 Entity.damage 8 节点 + Player.death 3 节点 + Game.game_over("lose")。
## 设计文档：GameDesignDocus/GameSystem/Entities/Entity.md + Player.md


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_monster(name: String = "M", dmg: int = 3) -> Monster:
	var m: Monster = Monster.new()
	m.monster_name = name
	m.hp = 5
	m.max_hp = 5
	m.damage_value = dmg
	m.range = "none"
	return m


func _make_block(name: String = "B", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	return b


func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 测试用例 ===

func test_full_damage_to_death_triggers_all_hooks() -> void:
	var p: Player = _make_player("A", 5)
	var triggers_received: Array = []
	var s_before: Skill = Skill.new()
	s_before.trigger = "before_take_damage"
	s_before.content = func(_ev: Dictionary) -> void: triggers_received.append("before_take_damage")
	var s_on: Skill = Skill.new()
	s_on.trigger = "on_take_damage"
	s_on.content = func(_ev: Dictionary) -> void: triggers_received.append("on_take_damage")
	var s_after: Skill = Skill.new()
	s_after.trigger = "after_take_damage"
	s_after.content = func(_ev: Dictionary) -> void: triggers_received.append("after_take_damage")
	var s_death: Skill = Skill.new()
	s_death.trigger = "before_player_death"
	s_death.content = func(_ev: Dictionary) -> void: triggers_received.append("before_player_death")
	p.add_skill(s_before)
	p.add_skill(s_on)
	p.add_skill(s_after)
	p.add_skill(s_death)
	# 5 点伤害致死
	p.damage(5, null, "test")
	assert_false(p.is_alive(), "玩家应已死亡")
	assert_true(triggers_received.has("before_take_damage"))
	assert_true(triggers_received.has("on_take_damage"))
	assert_true(triggers_received.has("after_take_damage"))
	assert_true(triggers_received.has("before_player_death"))


func test_death_triggers_game_over_when_all_dead() -> void:
	var p: Player = _make_player("A", 3)
	Game.players = [p]
	# 致死伤害
	p.damage(3, null, "test")
	assert_true(Game.game_over_called, "全员死亡应触发 game_over")
	assert_eq(Game.game_result, "lose")


func test_death_triggers_game_over_in_coop_mode() -> void:
	var p1: Player = _make_player("A", 10)
	var p2: Player = _make_player("B", 10)
	Game.players = [p1, p2]
	Game.coop_death_mode = true
	# 合作模式下任一玩家死亡即游戏失败
	p1.damage(10, null, "test")
	assert_true(Game.game_over_called, "合作模式任一死亡应触发 game_over")
	assert_eq(Game.game_result, "lose")


func test_death_moves_monsters_to_discard_and_adds_marks() -> void:
	var p: Player = _make_player("A", 5)
	var block: MapBlock = _make_block("B", 0, 0)
	p.current_block = block
	Game.players = [p]
	Game.monster_discard_pile = Pile.new()
	# 给玩家面前放 2 个怪物
	var m1: Monster = _make_monster("M1")
	var m2: Monster = _make_monster("M2")
	m1.attack_target = p
	m2.attack_target = p
	p.monster_zone.append(m1)
	p.monster_zone.append(m2)
	# 致死
	p.damage(5, null, "test")
	assert_eq(p.monster_zone.size(), 0, "死亡后怪物区应清空")
	assert_eq(Game.monster_discard_pile.get_all().size(), 2, "怪物应进入弃牌堆")
	assert_eq(block.count_monster_mark(), 2, "应添加等量怪物标记（最多3）")
