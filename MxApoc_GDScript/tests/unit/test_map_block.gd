extends GutTest

## MapBlock 单元测试。


# === 测试用 mock player ===

class MockPlayer extends RefCounted:
	var current_block: Variant = null
	var monster_zone: Array = []
	var hp: int = 10
	var triggers_received: Array = []

	func is_alive() -> bool:
		return hp > 0

	func get_current_block():
		return current_block

	func trigger(trigger_name: String, event: Dictionary) -> void:
		triggers_received.append(trigger_name)


# === 辅助方法 ===

func _make_block(name: String, x: int, y: int) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	return b


func _setup_game_map(blocks: Array) -> void:
	Game.map_area = blocks
	Game.players = []


func _clear_game_map() -> void:
	Game.map_area = []
	Game.players = []


func after_each() -> void:
	_clear_game_map()


# === 1. 基础字段与坐标 ===

func test_default_fields() -> void:
	var b: MapBlock = MapBlock.new()
	assert_eq(b.block_name, "")
	assert_eq(b.coordinate["x"], 0)
	assert_eq(b.coordinate["y"], 0)
	assert_eq(b.monster_spawn_value, 0)
	assert_false(b.revealed)
	assert_eq(b.monster_marks, 0)
	assert_eq(b.block_state, "alive")
	assert_true(b.is_alive())
	assert_false(b.is_destroyed())


func test_set_and_get_coordinate() -> void:
	var b: MapBlock = MapBlock.new()
	b.set_coordinate(3, 5)
	assert_eq(b.get_coordinate()["x"], 3)
	assert_eq(b.get_coordinate()["y"], 5)


func test_is_alive_and_destroyed() -> void:
	var b: MapBlock = MapBlock.new()
	assert_true(b.is_alive())
	b.block_state = "destroyed"
	assert_false(b.is_alive())
	assert_true(b.is_destroyed())


# === 2. 怪物标记管理 ===

func test_add_monster_mark() -> void:
	var b: MapBlock = MapBlock.new()
	b.add_monster_mark(2)
	assert_eq(b.count_monster_mark(), 2)
	assert_true(b.has_monster_mark())


func test_add_monster_mark_capped_at_3() -> void:
	var b: MapBlock = MapBlock.new()
	b.add_monster_mark(5)
	assert_eq(b.count_monster_mark(), 3, "怪物标记上限为 3")


func test_remove_monster_mark() -> void:
	var b: MapBlock = MapBlock.new()
	b.add_monster_mark(3)
	b.remove_monster_mark(1)
	assert_eq(b.count_monster_mark(), 2)


func test_remove_monster_mark_floor_zero() -> void:
	var b: MapBlock = MapBlock.new()
	b.add_monster_mark(1)
	b.remove_monster_mark(5)
	assert_eq(b.count_monster_mark(), 0, "怪物标记下限为 0")


func test_remove_all_monster_marks() -> void:
	var b: MapBlock = MapBlock.new()
	b.add_monster_mark(3)
	b.remove_all_monster_marks()
	assert_eq(b.count_monster_mark(), 0)
	assert_false(b.has_monster_mark())


# === 3. 展示 ===

func test_reveal_sets_flag() -> void:
	var b: MapBlock = MapBlock.new()
	var p: MockPlayer = MockPlayer.new()
	await b.reveal(false, p)
	assert_true(b.revealed, "reveal 后 revealed 应为 true")


func test_reveal_triggers_on_reveal_block() -> void:
	var b: MapBlock = MapBlock.new()
	var p: MockPlayer = MockPlayer.new()
	await b.reveal(true, p)
	assert_eq(p.triggers_received, ["on_reveal_block"], "应触发 on_reveal_block")


func test_reveal_no_effect_does_not_trigger() -> void:
	var b: MapBlock = MapBlock.new()
	var p: MockPlayer = MockPlayer.new()
	await b.reveal(false, p)
	assert_eq(p.triggers_received.size(), 0, "trigger_effect=false 时不应触发")


# === 4. 距离计算 ===

func test_distance_to_manhattan() -> void:
	var b1: MapBlock = _make_block("A", 0, 0)
	var b2: MapBlock = _make_block("B", 3, 4)
	assert_eq(b1.distance_to(b2), 7, "曼哈顿距离应为 3+4=7")


func test_distance_to_same_block() -> void:
	var b1: MapBlock = _make_block("A", 2, 3)
	var b2: MapBlock = _make_block("B", 2, 3)
	assert_eq(b1.distance_to(b2), 0)


# === 5. 相邻地块查询 ===

func test_get_adjacent_blocks_four_directions() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var up: MapBlock = _make_block("U", 2, 1)
	var down: MapBlock = _make_block("D", 2, 3)
	var left: MapBlock = _make_block("L", 1, 2)
	var right: MapBlock = _make_block("R", 3, 2)
	_setup_game_map([center, up, down, left, right])
	var adjacent: Array = center.get_adjacent_blocks()
	assert_eq(adjacent.size(), 4, "应有 4 个相邻地块")


func test_get_adjacent_blocks_excludes_diagonal() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var diagonal: MapBlock = _make_block("X", 3, 3)
	_setup_game_map([center, diagonal])
	var adjacent: Array = center.get_adjacent_blocks()
	assert_eq(adjacent.size(), 0, "对角线地块不应被包含")


func test_get_adjacent_blocks_excludes_destroyed() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var up: MapBlock = _make_block("U", 2, 1)
	up.block_state = "destroyed"
	_setup_game_map([center, up])
	var adjacent: Array = center.get_adjacent_blocks()
	assert_eq(adjacent.size(), 0, "已摧毁地块不应被包含")


func test_has_adjacent_unrevealed_block() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var up: MapBlock = _make_block("U", 2, 1)
	up.revealed = false
	var down: MapBlock = _make_block("D", 2, 3)
	down.revealed = true
	_setup_game_map([center, up, down])
	assert_true(center.has_adjacent_unrevealed_block(), "存在未展示的相邻地块")


func test_has_adjacent_unrevealed_block_all_revealed() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var up: MapBlock = _make_block("U", 2, 1)
	up.revealed = true
	_setup_game_map([center, up])
	assert_false(center.has_adjacent_unrevealed_block(), "所有相邻都已展示")


# === 6. 射程范围查询 ===

func test_get_blocks_in_range_short() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var adjacent: MapBlock = _make_block("A", 2, 3)  # 距离 1
	var far: MapBlock = _make_block("F", 2, 5)  # 距离 3
	_setup_game_map([center, adjacent, far])
	var blocks: Array = center.get_blocks_in_range("short")
	assert_eq(blocks.size(), 1, "短距离只包含距离 1 的地块")


func test_get_blocks_in_range_medium() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var d1: MapBlock = _make_block("A", 2, 3)  # 距离 1
	var d2: MapBlock = _make_block("B", 2, 4)  # 距离 2
	var d3: MapBlock = _make_block("D", 2, 5)  # 距离 3
	_setup_game_map([center, d1, d2, d3])
	var blocks: Array = center.get_blocks_in_range("medium")
	assert_eq(blocks.size(), 2, "中距离包含距离 1-2 的地块")


func test_get_blocks_in_range_long() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var d1: MapBlock = _make_block("A", 2, 3)  # 距离 1
	var d2: MapBlock = _make_block("B", 2, 4)  # 距离 2
	var d3: MapBlock = _make_block("D", 2, 5)  # 距离 3
	var d4: MapBlock = _make_block("E", 2, 6)  # 距离 4
	_setup_game_map([center, d1, d2, d3, d4])
	var blocks: Array = center.get_blocks_in_range("long")
	assert_eq(blocks.size(), 2, "长距离包含距离 2-3 的地块（不含 1）")


func test_get_blocks_in_range_infinity() -> void:
	var center: MapBlock = _make_block("C", 2, 2)
	var d1: MapBlock = _make_block("A", 2, 3)
	var d10: MapBlock = _make_block("B", 12, 12)
	_setup_game_map([center, d1, d10])
	var blocks: Array = center.get_blocks_in_range("infinity")
	assert_eq(blocks.size(), 3, "infinity 包含所有存活地块（含自身）")


# === 7. 拾荒颜色 ===

func test_has_color_empty() -> void:
	var b: MapBlock = MapBlock.new()
	assert_false(b.has_color(), "默认无拾荒颜色")


func test_has_color_with_colors() -> void:
	var b: MapBlock = MapBlock.new()
	b.scavenge_colors = ["red", "blue"]
	assert_true(b.has_color())


# === 8. 玩家查询 ===

func test_get_players_on_block() -> void:
	var b: MapBlock = _make_block("B", 0, 0)
	var p1: MockPlayer = MockPlayer.new()
	p1.current_block = b
	var p2: MockPlayer = MockPlayer.new()
	p2.current_block = b
	var p3: MockPlayer = MockPlayer.new()  # 在其他地块
	_setup_game_map([b])
	Game.players = [p1, p2, p3]
	var players: Array = b.get_players()
	assert_eq(players.size(), 2, "应有 2 个玩家在此地块")


func test_get_players_excludes_dead() -> void:
	var b: MapBlock = _make_block("B", 0, 0)
	var p1: MockPlayer = MockPlayer.new()
	p1.current_block = b
	p1.hp = 0  # 死亡
	_setup_game_map([b])
	Game.players = [p1]
	var players: Array = b.get_players()
	assert_eq(players.size(), 0, "死亡玩家不应被包含")


func test_has_player() -> void:
	var b: MapBlock = _make_block("B", 0, 0)
	_setup_game_map([b])
	Game.players = []
	assert_false(b.has_player())
	var p: MockPlayer = MockPlayer.new()
	p.current_block = b
	Game.players = [p]
	assert_true(b.has_player())


# === 9. 目标标记管理 ===

func _make_mark(id: String, effect_called: Array = []) -> Dictionary:
	return {
		"id": id,
		"description": "test mark",
		"effect": func(_player) -> void:
			effect_called.append(true),
		"triggered": false,
		"initial_monster_marks": 0,
		"remove_condition": Callable(),
		"removed": false,
	}


func test_add_objective_mark() -> void:
	var b: MapBlock = MapBlock.new()
	var mark: Dictionary = _make_mark("m1")
	b.add_objective_mark(mark)
	assert_true(b.has_objective_mark())
	assert_eq(b.get_objective_marks().size(), 1)


func test_has_objective_mark_no_marks() -> void:
	var b: MapBlock = MapBlock.new()
	assert_false(b.has_objective_mark())


func test_has_objective_mark_all_removed() -> void:
	var b: MapBlock = MapBlock.new()
	var mark: Dictionary = _make_mark("m1")
	mark["removed"] = true
	b.add_objective_mark(mark)
	assert_false(b.has_objective_mark(), "全部已移除时应返回 false")


func test_remove_objective_mark() -> void:
	var b: MapBlock = MapBlock.new()
	var mark: Dictionary = _make_mark("m1")
	b.add_objective_mark(mark)
	b.remove_objective_mark(mark)
	assert_false(b.has_objective_mark())
	assert_eq(b.get_objective_marks().size(), 0)
	assert_true(mark["removed"], "mark 应标记为 removed")


func test_remove_all_objective_marks() -> void:
	var b: MapBlock = MapBlock.new()
	var m1: Dictionary = _make_mark("m1")
	var m2: Dictionary = _make_mark("m2")
	b.add_objective_mark(m1)
	b.add_objective_mark(m2)
	b.remove_all_objective_marks()
	assert_false(b.has_objective_mark())
	assert_true(m1["removed"])
	assert_true(m2["removed"])


func test_trigger_objective_marks_executes_effect_once() -> void:
	var b: MapBlock = MapBlock.new()
	var effect_called: Array = []
	var mark: Dictionary = _make_mark("m1", effect_called)
	b.add_objective_mark(mark)
	var p: MockPlayer = MockPlayer.new()
	await b.trigger_objective_marks(p)
	assert_eq(effect_called.size(), 1, "效果应执行一次")
	assert_true(mark["triggered"], "应标记为 triggered")
	# 再次触发不应重复执行
	await b.trigger_objective_marks(p)
	assert_eq(effect_called.size(), 1, "已触发的标记不应再次执行")


func test_trigger_objective_marks_triggers_hook() -> void:
	var b: MapBlock = MapBlock.new()
	var mark: Dictionary = _make_mark("m1")
	b.add_objective_mark(mark)
	var p: MockPlayer = MockPlayer.new()
	await b.trigger_objective_marks(p)
	assert_eq(p.triggers_received, ["on_objective_mark_triggered"], "应触发 on_objective_mark_triggered")


func test_trigger_objective_marks_skips_removed() -> void:
	var b: MapBlock = MapBlock.new()
	var effect_called: Array = []
	var mark: Dictionary = _make_mark("m1", effect_called)
	mark["removed"] = true
	b.add_objective_mark(mark)
	var p: MockPlayer = MockPlayer.new()
	await b.trigger_objective_marks(p)
	assert_eq(effect_called.size(), 0, "已移除的标记不应触发")


# === 10. 目标标记移除条件检查 ===

func test_remove_monster_mark_triggers_remove_condition() -> void:
	var b: MapBlock = MapBlock.new()
	var mark: Dictionary = _make_mark("m1")
	mark["remove_condition"] = func(block: MapBlock) -> bool:
		return block.count_monster_mark() == 0
	b.add_objective_mark(mark)
	b.add_monster_mark(2)
	assert_true(b.has_objective_mark(), "怪物标记 > 0 时标记不应被移除")
	b.remove_monster_mark(2)
	assert_false(b.has_objective_mark(), "怪物标记归 0 时标记应被自动移除")


func test_add_monster_mark_does_not_trigger_remove_check() -> void:
	var b: MapBlock = MapBlock.new()
	var mark: Dictionary = _make_mark("m1")
	var cond_called: Array = []
	mark["remove_condition"] = func(block: MapBlock) -> bool:
		cond_called.append(true)
		return false
	b.add_objective_mark(mark)
	b.add_monster_mark(1)
	assert_eq(cond_called.size(), 0, "add_monster_mark 不应触发移除条件检查")


# === 11. 地块技能查询 ===

func test_has_skill_by_name() -> void:
	var b: MapBlock = MapBlock.new()
	var s: Skill = Skill.new()
	s.skill_name = "避难所技能"
	b.add_skill(s)
	assert_true(b.has_skill("避难所技能"))
	assert_false(b.has_skill("其他技能"))
