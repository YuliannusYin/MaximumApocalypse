extends TestBase

## Game 单元测试。
## 覆盖：地图查询 / 玩家管理 / 状态机委托 / build_map / destroy_map_block / 弃牌堆装备查询。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md


# === 测试用内嵌任务组件（胜利判定 true/false 两种） ===

class WinTrueComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return true


class WinFalseComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return false


# === 辅助方法 ===

func _make_equipment_card(name: String = "test_equip") -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	return e


# === 1. 地图查询 ===

## 合并族：按坐标查地块（原 2 个独立测试，断言逐段保留）。
func test_get_block_by_coord_found_and_missing() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	assert_eq(Game.get_block_by_coord(1, 0), b2)
	assert_null(Game.get_block_by_coord(5, 5))


## 合并族：按名字查地块（原 2 个独立测试，断言逐段保留）。
func test_get_blocks_by_name_found_and_empty() -> void:
	var b1: MapBlock = _make_block("隧道", 0, 0)
	var b2: MapBlock = _make_block("隧道", 1, 0)
	var b3: MapBlock = _make_block("加油站", 2, 0)
	Game.map_area = [b1, b2, b3]
	assert_eq(Game.get_blocks_by_name("隧道").size(), 2)
	assert_eq(Game.get_blocks_by_name("不存在").size(), 0)


func test_get_adjacent_alive_blocks() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var result: Array = Game.get_adjacent_alive_blocks(b1)
	assert_eq(result.size(), 1)
	assert_eq(result[0], b2)


# === 2. 玩家管理 ===

func test_get_alive_players_excludes_dead() -> void:
	var p1: Player = _make_player("P1", 10)
	var p2: Player = _make_player("P2", 0)
	Game.players = [p1, p2]
	assert_eq(Game.get_alive_players().size(), 1)


## 合并族：all_players_dead 随存活状态判定（原 2 个独立测试，断言逐段保留）。
func test_all_players_dead_by_hp() -> void:
	var p1: Player = _make_player("P1", 10)
	Game.players = [p1]
	assert_false(Game.all_players_dead())
	p1 = _make_player("P1", 0)
	Game.players = [p1]
	assert_true(Game.all_players_dead())


# === 3. 状态机委托 ===

## 合并族：game_over 按结果设置标记（原 2 个独立测试，断言逐段保留；
## 每个 case 前重置状态机与标记，因 game_over 在 GAME_OVER 态下会直接返回）。
func test_game_over_sets_flags() -> void:
	for result in ["lose", "win"]:
		Game.state_machine.init()
		Game.game_over_called = false
		Game.game_result = ""
		await Game.game_over(result)
		assert_true(Game.game_over_called)
		assert_eq(Game.game_result, result)


func test_game_over_sets_state_machine() -> void:
	await Game.game_over("lose")
	assert_eq(Game.state_machine.get_game_state(), GameStateMachine.GameState.GAME_OVER)
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.LOSE)


func test_game_over_idempotent() -> void:
	await Game.game_over("lose")
	await Game.game_over("win")
	assert_eq(Game.game_result, "lose", "已结束不应覆盖")


## 合并族：check_mission_win_condition 随胜利组件判定（原 2 个独立测试，断言逐段保留）。
func test_check_mission_win_condition_by_component() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.win_condition_components.append(WinTrueComponent.new())
	Game.mission_config = mc
	assert_true(Game.check_mission_win_condition())
	mc = MissionConfig.new()
	mc.win_condition_components.append(WinFalseComponent.new())
	Game.mission_config = mc
	assert_false(Game.check_mission_win_condition())


# === 4. build_map（legend 驱动） ===

func test_build_map_simple_2x2() -> void:
	var config: Dictionary = {
		"map_template": [[0, 1], [1, 2]],
		"map_block_config": [{"block_name": "加油站", "count": 2}],
		"map_legend": {
			"0": {"type": "spawn", "block_name": "出生点"},
			"1": "random_block",
			"2": {"type": "game_end", "block_name": "结束点"},
		},
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 4)
	assert_eq(Game.map_width, 2)
	assert_eq(Game.map_height, 2)
	var spawn: MapBlock = Game.get_block_by_coord(0, 0)
	assert_eq(spawn.block_name, "出生点")
	var end: MapBlock = Game.get_block_by_coord(1, 1)
	assert_eq(end.block_name, "结束点")


func test_build_map_skip_no_block() -> void:
	var config: Dictionary = {
		"map_template": [[0, 1], [1, 0]],
		"map_block_config": [{"block_name": "加油站", "count": 2}],
		"map_legend": {
			"0": "no_block",
			"1": "random_block",
		},
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 2, "no_block 格应跳过，仅 random_block 格生成地块")
	assert_not_null(Game.get_block_by_coord(1, 0))
	assert_not_null(Game.get_block_by_coord(0, 1))
	assert_null(Game.get_block_by_coord(0, 0), "no_block 格不应有地块")
	assert_null(Game.get_block_by_coord(1, 1), "no_block 格不应有地块")


func test_build_map_random_block_with_mission_mark_adds_objective_mark() -> void:
	var mark: Dictionary = {"description": "测试标记", "initial_monster_marks": 2}
	var config: Dictionary = {
		"map_template": [[4]],
		"map_block_config": [{"block_name": "加油站", "count": 1}],
		"map_legend": {
			"4": {"type": "random_block", "face": true, "mission_mark": 1},
		},
		"objective_marks": [mark],
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 1)
	var block: MapBlock = Game.map_area[0]
	assert_true(block.has_objective_mark())
	assert_eq(block.count_monster_mark(), 2, "标记定义的 initial_monster_marks 应放置怪物标记")
	assert_true(block.is_revealed(), "face:true 的 random_block 应初始翻开")


func test_build_map_face_default_by_type() -> void:
	var config: Dictionary = {
		"map_template": [[0, 1, 2]],
		"map_block_config": [{"block_name": "加油站", "count": 1}],
		"map_legend": {
			"0": {"type": "spawn", "block_name": "出生点"},
			"1": {"type": "random_block"},
			"2": {"type": "game_end", "block_name": "结束点"},
		},
	}
	Game.build_map(config)
	assert_true(Game.get_block_by_coord(0, 0).is_revealed(), "spawn 条目未写 face 应默认翻开")
	assert_false(Game.get_block_by_coord(1, 0).is_revealed(), "random_block 条目未写 face 应默认未翻开")
	assert_true(Game.get_block_by_coord(2, 0).is_revealed(), "game_end 条目未写 face 应默认翻开")


func test_build_map_spawn_face_false_not_revealed() -> void:
	var config: Dictionary = {
		"map_template": [[0]],
		"map_legend": {
			"0": {"type": "spawn", "block_name": "出生点", "face": false},
		},
	}
	Game.build_map(config)
	var spawn: MapBlock = Game.get_block_by_coord(0, 0)
	assert_not_null(spawn)
	assert_false(spawn.is_revealed(), "face:false 的 spawn 条目应初始未翻开")


func test_build_map_monster_mark_capped_at_three() -> void:
	var config: Dictionary = {
		"map_template": [[0]],
		"map_block_config": [{"block_name": "加油站", "count": 1}],
		"map_legend": {
			"0": {"type": "random_block", "monster_mark": 5},
		},
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 1)
	assert_eq(Game.map_area[0].count_monster_mark(), 3, "monster_mark 声明 5 应按上限 3 截断")


func test_build_map_mission_marks_consumed_in_order() -> void:
	var mark1: Dictionary = {"description": "标记一"}
	var mark2: Dictionary = {"description": "标记二"}
	var mark3: Dictionary = {"description": "标记三"}
	var config: Dictionary = {
		"map_template": [[0, 1, 2]],
		"map_block_config": [{"block_name": "加油站", "count": 3}],
		"map_legend": {
			"0": {"type": "random_block", "mission_mark": 2},
			"1": {"type": "random_block", "mission_mark": 1},
			"2": {"type": "random_block", "mission_mark": 1},
		},
		"objective_marks": [mark1, mark2, mark3],
	}
	Game.build_map(config)
	var first: MapBlock = Game.get_block_by_coord(0, 0)
	var second: MapBlock = Game.get_block_by_coord(1, 0)
	var third: MapBlock = Game.get_block_by_coord(2, 0)
	var first_marks: Array = first.get_objective_marks()
	assert_eq(first_marks.size(), 2, "行优先先到的地块应获得 2 个任务标记")
	assert_eq(first_marks[0], mark1, "先到地块应按序获得第 1 个标记")
	assert_eq(first_marks[1], mark2, "先到地块应按序获得第 2 个标记")
	var second_marks: Array = second.get_objective_marks()
	assert_eq(second_marks.size(), 1, "后到的地块应获得剩余 1 个任务标记")
	assert_eq(second_marks[0], mark3, "后到地块应获得队列中最后 1 个标记")
	assert_eq(third.get_objective_marks().size(), 0, "队列耗尽后应不再放置且不报错")


func test_build_map_unknown_cell_code_skipped() -> void:
	var config: Dictionary = {
		"map_template": [[0, 9]],
		"map_block_config": [{"block_name": "加油站", "count": 1}],
		"map_legend": {
			"0": "random_block",
		},
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 1, "未知编号的格应按无地块跳过")
	assert_not_null(Game.get_block_by_coord(0, 0))
	assert_null(Game.get_block_by_coord(1, 0), "未知编号格不应有地块")
	assert_push_error("单元格编号 9 不在 map_legend 中", "未知编号应产生容错 push_error")


func test_build_map_unknown_type_skipped() -> void:
	var config: Dictionary = {
		"map_template": [[0, 1]],
		"map_block_config": [{"block_name": "加油站", "count": 1}],
		"map_legend": {
			"0": {"type": "foo"},
			"1": "random_block",
		},
	}
	Game.build_map(config)
	assert_eq(Game.map_area.size(), 1, "未知 type 的格应按无地块跳过")
	var block: MapBlock = Game.get_block_by_coord(1, 0)
	assert_not_null(block)
	assert_eq(block.block_name, "加油站")
	assert_push_error("条目 type \"foo\" 未知", "未知 type 应产生容错 push_error")


# === 5. destroy_map_block ===

func test_destroy_map_block_basic() -> void:
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	var result: bool = await Game.destroy_map_block(b1, null)
	assert_true(result)
	assert_false(Game.map_area.has(b1))
	assert_true(b1.is_destroyed())


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


# === 6. 卡牌管理 ===

func test_remove_card() -> void:
	var c: Card = _make_card("c1")
	await Game.remove_card(c)
	assert_eq(Game.removed_cards.size(), 1)
	assert_eq(Game.removed_cards[0], c)


# === 7. 弃牌堆装备查询 ===

## 合并族：get_all_discard_pile_equipments 汇总玩家/拾荒弃牌堆（原 3 个独立测试，断言逐段保留）。
func test_get_all_discard_pile_equipments_sources() -> void:
	# 玩家弃牌堆
	var p: Player = _make_player("P")
	var e: EquipmentCard = _make_equipment_card("武器")
	p.game_discard_pile.add(e)
	Game.players = [p]
	assert_eq(Game.get_all_discard_pile_equipments().size(), 1)
	# 拾荒弃牌堆
	Game.players = []
	var pile: Pile = Pile.new()
	pile.add(_make_equipment_card("防弹衣"))
	Game.scavenge_discard_pile = pile
	assert_eq(Game.get_all_discard_pile_equipments().size(), 1)
	# 非装备卡不计入
	p = _make_player("P")
	p.game_discard_pile.add(_make_card("普通牌"))
	Game.players = [p]
	Game.scavenge_discard_pile = Pile.new()
	assert_eq(Game.get_all_discard_pile_equipments().size(), 0)


## 合并族：has_equipment_in_discard_piles 随弃牌堆内容判定（原 2 个独立测试，断言逐段保留）。
func test_has_equipment_in_discard_piles_by_content() -> void:
	var p: Player = _make_player("P")
	var e: EquipmentCard = _make_equipment_card("武器")
	p.game_discard_pile.add(e)
	Game.players = [p]
	assert_true(Game.has_equipment_in_discard_piles())
	p = _make_player("P")
	p.game_discard_pile.add(_make_card("普通牌"))
	Game.players = [p]
	assert_false(Game.has_equipment_in_discard_piles())


# === 8. get_step_toward ===

## 合并族：get_step_toward 方向与边界（原 5 个独立测试，断言逐段保留）。
func test_get_step_toward_cases() -> void:
	# 水平方向
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	var b3: MapBlock = _make_block("b3", 2, 0)
	Game.map_area = [b1, b2, b3]
	assert_eq(Game.get_step_toward(b1, b3), b2)
	# 垂直方向
	b1 = _make_block("b1", 0, 0)
	b2 = _make_block("b2", 0, 1)
	b3 = _make_block("b3", 0, 2)
	Game.map_area = [b1, b2, b3]
	assert_eq(Game.get_step_toward(b1, b3), b2)
	# 相邻地块返回目标
	b1 = _make_block("b1", 0, 0)
	b2 = _make_block("b2", 1, 0)
	Game.map_area = [b1, b2]
	assert_eq(Game.get_step_toward(b1, b2), b2)
	# 同地块返回自身
	b1 = _make_block("b1", 0, 0)
	Game.map_area = [b1]
	assert_eq(Game.get_step_toward(b1, b1), b1)
	# 源为空返回 null
	b1 = _make_block("b1", 0, 0)
	Game.map_area = [b1]
	assert_null(Game.get_step_toward(null, b1))


# === 9. 对局中止 / 世代 ===

func test_abort_session_invalidates_previous_session() -> void:
	var old_id: int = Game.get_session_id()
	Game.players.append(_make_player())
	Game.abort_session()
	assert_false(Game.is_session(old_id), "abort 后旧世代应失效")
	assert_eq(Game.players.size(), 0, "abort 应清空玩家")
	assert_eq(Game.state_machine.current_state, GameStateMachine.GameState.WAITING)
	assert_not_null(Game.event_scheduler)


func test_stale_player_draw_is_ignored_after_abort() -> void:
	var p: Player = _make_player()
	p.session_id = Game.get_session_id()
	p.game_deck.add(_make_card())
	Game.abort_session()
	assert_true(p.has_left_session())
	await p.draw(1)
	assert_eq(p.hand.size(), 0, "过期对局的玩家不应再抓牌")
	assert_eq(p.game_deck.size(), 1, "过期抓牌不应从牌堆抽走卡")


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
