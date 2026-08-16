extends GutTest

## Game 单元测试。
## 覆盖：日志 / 地图查询 / 玩家管理 / 状态机委托 / build_map / destroy_map_block / 弃牌堆装备查询。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md


# === 辅助方法 ===

func _make_block(name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	return b


func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_equipment(name: String = "test_equip") -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	return e


func _make_card(name: String = "test_card") -> Card:
	var c: Card = Card.new()
	c.card_name = name
	c.card_type = "action"
	c.source = "game"
	return c


func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.map_width = 0
	Game.map_height = 0
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


# === 1. 日志 ===

func test_log_message_appends_to_list() -> void:
	Game.log_message("测试日志")
	assert_eq(Game.log_list.size(), 1)
	assert_eq(Game.log_list[0], "测试日志")


func test_log_message_multiple() -> void:
	Game.log_message("第一条")
	Game.log_message("第二条")
	assert_eq(Game.log_list.size(), 2)


# === 2. 地图查询 ===

func test_get_block_by_coord_found() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var result: MapBlock = Game.get_block_by_coord(1, 0)
	assert_eq(result, b2)


func test_get_block_by_coord_not_found() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	Game.map_area = [b1]
	var result: MapBlock = Game.get_block_by_coord(5, 5)
	assert_null(result)


func test_get_blocks_by_name() -> void:
	var b1: MapBlock = _make_block("隧道", 0, 0)
	var b2: MapBlock = _make_block("隧道", 1, 0)
	var b3: MapBlock = _make_block("加油站", 2, 0)
	Game.map_area = [b1, b2, b3]
	var result: Array = Game.get_blocks_by_name("隧道")
	assert_eq(result.size(), 2)


func test_get_blocks_by_name_empty() -> void:
	var b1: MapBlock = _make_block("隧道", 0, 0)
	Game.map_area = [b1]
	var result: Array = Game.get_blocks_by_name("不存在")
	assert_eq(result.size(), 0)


func test_get_adjacent_alive_blocks() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var result: Array = Game.get_adjacent_alive_blocks(b1)
	assert_eq(result.size(), 1)
	assert_eq(result[0], b2)


# === 3. 玩家管理 ===

func test_get_all_players() -> void:
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	Game.players = [p1, p2]
	assert_eq(Game.get_all_players().size(), 2)


func test_get_alive_players_excludes_dead() -> void:
	var p1: Player = _make_player("P1", 10)
	var p2: Player = _make_player("P2", 0)
	Game.players = [p1, p2]
	assert_eq(Game.get_alive_players().size(), 1)


func test_all_players_dead_all_alive() -> void:
	var p1: Player = _make_player("P1", 10)
	Game.players = [p1]
	assert_false(Game.all_players_dead())


func test_all_players_dead_all_dead() -> void:
	var p1: Player = _make_player("P1", 0)
	Game.players = [p1]
	assert_true(Game.all_players_dead())


func test_all_players_dead_empty() -> void:
	Game.players = []
	assert_true(Game.all_players_dead())


# === 4. 状态机委托 ===

func test_game_over_lose_sets_flags() -> void:
	Game.game_over("lose")
	assert_true(Game.game_over_called)
	assert_eq(Game.game_result, "lose")


func test_game_over_win_sets_flags() -> void:
	Game.game_over("win")
	assert_true(Game.game_over_called)
	assert_eq(Game.game_result, "win")


func test_game_over_sets_state_machine() -> void:
	Game.game_over("lose")
	assert_eq(Game.state_machine.get_game_state(), GameStateMachine.GameState.GAME_OVER)
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.LOSE)


func test_game_over_idempotent() -> void:
	Game.game_over("lose")
	Game.game_over("win")
	assert_eq(Game.game_result, "lose", "已结束不应覆盖")


func test_get_current_player_initially_null() -> void:
	assert_null(Game.get_current_player())


func test_check_mission_win_condition_no_config() -> void:
	Game.mission_config = null
	assert_false(Game.check_mission_win_condition())


func test_check_mission_win_condition_no_callable() -> void:
	var mc: MissionConfig = MissionConfig.new()
	Game.mission_config = mc
	assert_false(Game.check_mission_win_condition())


func test_check_mission_win_condition_callable_true() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.check_win_condition = func() -> bool: return true
	Game.mission_config = mc
	assert_true(Game.check_mission_win_condition())


# === 5. build_map ===

func test_build_map_null_config_no_op() -> void:
	Game.build_map(null)
	assert_eq(Game.map_area.size(), 0)


func test_build_map_empty_template_no_op() -> void:
	var config: Dictionary = {"map_template": []}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 0)


func test_build_map_simple_2x2() -> void:
	var config: Dictionary = {
		"map_template": [[0, 1], [1, 2]],
		"map_block_config": [{"block_name": "加油站", "count": 2}],
		"spawn_block_name": "出生点",
		"end_block_name": "面包车",
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 4)
	assert_eq(Game.map_width, 2)
	assert_eq(Game.map_height, 2)
	var spawn: MapBlock = Game.get_block_by_coord(0, 0)
	assert_eq(spawn.block_name, "出生点")
	var end: MapBlock = Game.get_block_by_coord(1, 1)
	assert_eq(end.block_name, "面包车")


func test_build_map_skip_negative_one() -> void:
	var config: Dictionary = {
		"map_template": [[-1, 0], [0, -1]],
		"spawn_block_name": "出生点",
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 2)


func test_build_map_marked_block_adds_objective_mark() -> void:
	var mark: Dictionary = {"description": "测试标记", "initial_monster_marks": 2}
	var config: Dictionary = {
		"map_template": [[3]],
		"map_block_config": [{"block_name": "加油站", "count": 1}],
		"objective_marks": [mark],
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 1)
	var block: MapBlock = Game.map_area[0]
	assert_true(block.has_objective_mark())
	assert_eq(block.count_monster_mark(), 2)


# === 6. destroy_map_block ===

func test_destroy_map_block_basic() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var result: bool = await Game.destroy_map_block(b1, null)
	assert_true(result)
	assert_false(Game.map_area.has(b1))
	assert_true(b1.is_destroyed())


func test_destroy_map_block_null_returns_false() -> void:
	var result: bool = await Game.destroy_map_block(null, null)
	assert_false(result)


func test_destroy_map_block_cancel_prevents() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var p: Player = _make_player("P")
	Game.players = [p]
	p.add_skill(_make_cancel_skill("before_destroy_block"))
	var result: bool = await Game.destroy_map_block(b1, null)
	assert_false(result)
	assert_true(b1.is_alive())
	assert_true(Game.map_area.has(b1))


func test_destroy_map_block_player_popup_to_adjacent() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var p: Player = _make_player("P")
	Game.players = [p]
	p.current_block = b1
	await Game.destroy_map_block(b1, null)
	assert_eq(p.current_block, b2)


func test_destroy_map_block_no_adjacent_deals_damage() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	Game.map_area = [b1]
	var p: Player = _make_player("P", 10)
	Game.players = [p]
	p.current_block = b1
	await Game.destroy_map_block(b1, null)
	assert_eq(p.hp, 5, "无相邻地块应受 5 点伤害")


func test_destroy_map_block_clears_monster_marks() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	b1.add_monster_mark(3)
	await Game.destroy_map_block(b1, null)
	assert_eq(b1.count_monster_mark(), 0)


func test_destroy_map_block_triggers_all_hooks() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var p: Player = _make_player("P")
	Game.players = [p]
	var called: Array = []
	p.add_skill(_make_skill_with_trigger("before_destroy_block", called))
	p.add_skill(_make_skill_with_trigger("on_destroy_block", called))
	p.add_skill(_make_skill_with_trigger("after_destroy_block", called))
	await Game.destroy_map_block(b1, null)
	assert_eq(called, ["before_destroy_block", "on_destroy_block", "after_destroy_block"])


# === 7. 卡牌管理 ===

func test_remove_card() -> void:
	var c: Card = _make_card("c1")
	await Game.remove_card(c)
	assert_eq(Game.removed_cards.size(), 1)
	assert_eq(Game.removed_cards[0], c)


func test_get_scavenge_pile_red() -> void:
	var pile: Pile = Pile.new()
	Game.red_scavenge_pile = pile
	assert_eq(Game.get_scavenge_pile("red"), pile)


func test_get_scavenge_pile_green() -> void:
	var pile: Pile = Pile.new()
	Game.green_scavenge_pile = pile
	assert_eq(Game.get_scavenge_pile("green"), pile)


func test_get_scavenge_pile_blue() -> void:
	var pile: Pile = Pile.new()
	Game.blue_scavenge_pile = pile
	assert_eq(Game.get_scavenge_pile("blue"), pile)


func test_get_scavenge_pile_invalid_returns_null() -> void:
	assert_null(Game.get_scavenge_pile("yellow"))


func test_create_scavenge_card_stub_returns_null() -> void:
	var result: Card = Game.create_scavenge_card("测试卡")
	assert_null(result)


# === 8. 弃牌堆装备查询 ===

func test_get_all_discard_pile_equipments_empty() -> void:
	assert_eq(Game.get_all_discard_pile_equipments().size(), 0)


func test_get_all_discard_pile_equipments_from_player() -> void:
	var p: Player = _make_player("P")
	var e: EquipmentCard = _make_equipment("武器")
	p.game_discard_pile.add(e)
	Game.players = [p]
	var result: Array = Game.get_all_discard_pile_equipments()
	assert_eq(result.size(), 1)


func test_get_all_discard_pile_equipments_from_scavenge() -> void:
	var pile: Pile = Pile.new()
	var e: EquipmentCard = _make_equipment("防弹衣")
	pile.add(e)
	Game.scavenge_discard_pile = pile
	var result: Array = Game.get_all_discard_pile_equipments()
	assert_eq(result.size(), 1)


func test_get_all_discard_pile_equipments_excludes_non_equipment() -> void:
	var p: Player = _make_player("P")
	var c: Card = _make_card("普通牌")
	p.game_discard_pile.add(c)
	Game.players = [p]
	var result: Array = Game.get_all_discard_pile_equipments()
	assert_eq(result.size(), 0)


func test_has_equipment_in_discard_piles_true() -> void:
	var p: Player = _make_player("P")
	var e: EquipmentCard = _make_equipment("武器")
	p.game_discard_pile.add(e)
	Game.players = [p]
	assert_true(Game.has_equipment_in_discard_piles())


func test_has_equipment_in_discard_piles_false() -> void:
	var p: Player = _make_player("P")
	var c: Card = _make_card("普通牌")
	p.game_discard_pile.add(c)
	Game.players = [p]
	assert_false(Game.has_equipment_in_discard_piles())


# === 9. get_step_toward ===

func test_get_step_toward_horizontal() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	var b3: MapBlock = _make_block("b3", 2, 0)
	Game.map_area = [b1, b2, b3]
	var step: MapBlock = Game.get_step_toward(b1, b3)
	assert_eq(step, b2)


func test_get_step_toward_vertical() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 0, 1)
	var b3: MapBlock = _make_block("b3", 0, 2)
	Game.map_area = [b1, b2, b3]
	var step: MapBlock = Game.get_step_toward(b1, b3)
	assert_eq(step, b2)


func test_get_step_toward_adjacent_returns_target() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var step: MapBlock = Game.get_step_toward(b1, b2)
	assert_eq(step, b2)


func test_get_step_toward_same_block() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	Game.map_area = [b1]
	var step: MapBlock = Game.get_step_toward(b1, b1)
	assert_eq(step, b1)


func test_get_step_toward_null_source() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	Game.map_area = [b1]
	var step: MapBlock = Game.get_step_toward(null, b1)
	assert_null(step)


# === 辅助 skill 工厂 ===

func _make_skill_with_trigger(trigger_name: String, called: Array) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(trigger_name)
	return s


func _make_cancel_skill(trigger_name: String) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		EventSystem.cancel(ev)
	return s
