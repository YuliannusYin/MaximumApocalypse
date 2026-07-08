extends GutTest

## 集成测试：摧毁地块 6 节点 全链路。
## 覆盖 Game.destroy_map_block 6 节点 + 玩家弹出 + 怪物标记清零。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_block(name: String = "B", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	b.revealed = true
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

func test_destroy_block_removes_from_map_area() -> void:
	var b: MapBlock = _make_block("target", 0, 0)
	Game.map_area = [b]
	var ok: bool = Game.destroy_map_block(b, null)
	assert_true(ok, "摧毁应成功")
	assert_false(Game.map_area.has(b), "应从 map_area 移除")
	assert_eq(b.block_state, "destroyed", "地块状态应为 destroyed")


func test_destroy_block_pops_player_to_adjacent() -> void:
	var p: Player = _make_player("A", 10)
	var b1: MapBlock = _make_block("B1", 0, 0)
	var b2: MapBlock = _make_block("B2", 1, 0)
	p.current_block = b1
	Game.players = [p]
	Game.map_area = [b1, b2]
	# 摧毁 b1，玩家应弹出到 b2
	Game.destroy_map_block(b1, null)
	assert_eq(p.current_block, b2, "玩家应弹出到相邻地块 b2")


func test_destroy_block_no_adjacent_deals_damage() -> void:
	var p: Player = _make_player("A", 10)
	var b1: MapBlock = _make_block("B1", 0, 0)
	p.current_block = b1
	Game.players = [p]
	Game.map_area = [b1]  # 没有相邻地块
	# 摧毁 b1，玩家无处可逃应受 5 点伤害
	var initial_hp: int = p.hp
	Game.destroy_map_block(b1, null)
	assert_eq(p.hp, initial_hp - 5, "应受 5 点伤害")


func test_destroy_block_clears_monster_marks() -> void:
	var b: MapBlock = _make_block("target", 0, 0)
	b.add_monster_mark(3)  # 3 个怪物标记
	Game.map_area = [b]
	Game.destroy_map_block(b, null)
	assert_eq(b.count_monster_mark(), 0, "怪物标记应清零")


func test_destroy_block_cancel_prevents_destruction() -> void:
	var p: Player = _make_player("A", 10)
	var b: MapBlock = _make_block("target", 0, 0)
	Game.players = [p]
	Game.map_area = [b]
	# 添加取消技能
	var cancel_skill: Skill = Skill.new()
	cancel_skill.trigger = "before_destroy_block"
	cancel_skill.content = func(ev: Dictionary) -> void:
		EventSystem.cancel(ev)
	p.add_skill(cancel_skill)
	var ok: bool = Game.destroy_map_block(b, null)
	assert_false(ok, "取消应返回 false")
	assert_true(Game.map_area.has(b), "地块应仍在 map_area")
	assert_eq(b.block_state, "alive", "地块状态应仍为 alive")
