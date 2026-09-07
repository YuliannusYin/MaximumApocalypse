extends TestBase

## 判定类任务组件单元测试（已批准 spec Task 3：5 个新增胜利条件组件）。
## 覆盖：kill_monsters / all_blocks_revealed / objective_marks_cleared /
## state_flag / action_win_only 的注册表映射、判定逻辑、事件计数，
## 以及 MissionConfig.initial_objective_mark_count 字段与
## Game.initialize_game 的任务标记统计逻辑。
## 注册表 reset() 会清除内置注册标记，create()/has() 懒注册会重新注册内置组件，
## 故测试中直接 create 即可，无需手动处理。


# === 辅助方法 ===

func before_each() -> void:
	MissionComponentRegistry.reset()
	super.before_each()


func after_each() -> void:
	MissionComponentRegistry.reset()
	super.after_each()


# === 0. 注册表内置映射 ===

func test_registry_win_components_registered() -> void:
	assert_true(MissionComponentRegistry.has("kill_monsters"), "kill_monsters 应已注册")
	assert_true(MissionComponentRegistry.has("all_blocks_revealed"), "all_blocks_revealed 应已注册")
	assert_true(MissionComponentRegistry.has("objective_marks_cleared"), "objective_marks_cleared 应已注册")
	assert_true(MissionComponentRegistry.has("state_flag"), "state_flag 应已注册")
	assert_true(MissionComponentRegistry.has("action_win_only"), "action_win_only 应已注册")
	assert_true(MissionComponentRegistry.create("kill_monsters") is MissionComponentKillMonsters, "kill_monsters 应映射到正确类")
	assert_true(MissionComponentRegistry.create("all_blocks_revealed") is MissionComponentAllBlocksRevealed, "all_blocks_revealed 应映射到正确类")
	assert_true(MissionComponentRegistry.create("objective_marks_cleared") is MissionComponentObjectiveMarksCleared, "objective_marks_cleared 应映射到正确类")
	assert_true(MissionComponentRegistry.create("state_flag") is MissionComponentStateFlag, "state_flag 应映射到正确类")
	assert_true(MissionComponentRegistry.create("action_win_only") is MissionComponentActionWinOnly, "action_win_only 应映射到正确类")


# === 1. kill_monsters ===

func _setup_kill_monsters() -> Dictionary:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("kill_monsters", {"counts": {"僵尸潜伏者": 2}})
	component.setup(Game, mc)
	Game.mission_config = mc
	return {"mc": mc, "component": component}


func _fire_monster_died(component: MissionComponent, monster_name: String) -> void:
	component.on_event(Game, "monster_died", {"monster": _make_monster(monster_name), "source": null})


func test_kill_monsters_setup_initializes_counts() -> void:
	var ctx: Dictionary = _setup_kill_monsters()
	assert_eq(ctx["mc"].mission_state.get("kill_counts"), {}, "setup 应初始化 kill_counts 为空字典")


func test_kill_monsters_insufficient() -> void:
	var ctx: Dictionary = _setup_kill_monsters()
	_fire_monster_died(ctx["component"], "僵尸潜伏者")
	assert_false(ctx["component"].check_win(Game), "击杀 1 只未达要求 2 只应判定失败")


func test_kill_monsters_reaches_count() -> void:
	var ctx: Dictionary = _setup_kill_monsters()
	_fire_monster_died(ctx["component"], "僵尸潜伏者")
	_fire_monster_died(ctx["component"], "僵尸潜伏者")
	assert_true(ctx["component"].check_win(Game), "击杀 2 只达到要求应判定胜利")
	assert_eq(ctx["mc"].mission_state.get("kill_counts", {}).get("僵尸潜伏者", 0), 2, "kill_counts 应累计到 2")


func test_kill_monsters_non_target_ignored() -> void:
	var ctx: Dictionary = _setup_kill_monsters()
	_fire_monster_died(ctx["component"], "外来者")
	_fire_monster_died(ctx["component"], "外来者")
	assert_false(ctx["component"].check_win(Game), "非目标怪物名不应计入击杀数")
	assert_false(ctx["mc"].mission_state.get("kill_counts", {}).has("外来者"), "kill_counts 不应记录非目标怪物名")


func test_kill_monsters_mixed_kills() -> void:
	var ctx: Dictionary = _setup_kill_monsters()
	_fire_monster_died(ctx["component"], "外来者")
	_fire_monster_died(ctx["component"], "僵尸潜伏者")
	_fire_monster_died(ctx["component"], "外来者")
	_fire_monster_died(ctx["component"], "僵尸潜伏者")
	assert_true(ctx["component"].check_win(Game), "混入非目标怪物击杀不应影响目标计数")


# === 2. all_blocks_revealed ===

func test_all_blocks_revealed_all_revealed() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_blocks_revealed")
	var b1: MapBlock = _make_block("A", 0, 0)
	var b2: MapBlock = _make_block("B", 1, 0)
	b1.revealed = true
	b2.revealed = true
	Game.map_area = [b1, b2]
	assert_true(component.check_win(Game), "全部存活地块已展示应判定胜利")


func test_all_blocks_revealed_one_hidden() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_blocks_revealed")
	var b1: MapBlock = _make_block("A", 0, 0)
	var b2: MapBlock = _make_block("B", 1, 0)
	b1.revealed = true
	b2.revealed = false
	Game.map_area = [b1, b2]
	assert_false(component.check_win(Game), "有未展示地块应判定失败")


func test_all_blocks_revealed_empty_map() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_blocks_revealed")
	Game.map_area = []
	assert_false(component.check_win(Game), "空地图应判定失败")


func test_all_blocks_revealed_destroyed_block_ignored() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_blocks_revealed")
	var b1: MapBlock = _make_block("A", 0, 0)
	var b2: MapBlock = _make_block("B", 1, 0)
	b1.revealed = true
	b2.revealed = false
	b2.block_state = "destroyed"
	Game.map_area = [b1, b2]
	assert_true(component.check_win(Game), "已摧毁地块（未展示）不应影响判定")


# === 3. objective_marks_cleared ===

## 构造带任务标记的测试地块。返回 {block, marks}。
func _make_marked_block(marks: int) -> Dictionary:
	var block: MapBlock = _make_block("标记地", 0, 0)
	var mark_list: Array = []
	for i in marks:
		var mark: Dictionary = {"mark_id": "m" + str(i)}
		block.add_objective_mark(mark)
		mark_list.append(mark)
	return {"block": block, "marks": mark_list}


func _setup_marks_cleared(params: Dictionary, initial: int, marks: int) -> Dictionary:
	var mc: MissionConfig = MissionConfig.new()
	mc.initial_objective_mark_count = initial
	var component: MissionComponent = MissionComponentRegistry.create("objective_marks_cleared", params)
	component.setup(Game, mc)
	Game.mission_config = mc
	var marked: Dictionary = _make_marked_block(marks)
	Game.map_area = [marked["block"]]
	return {"mc": mc, "component": component, "block": marked["block"], "marks": marked["marks"]}


func test_marks_cleared_full_mode_progression() -> void:
	var ctx: Dictionary = _setup_marks_cleared({}, 3, 3)
	var component: MissionComponent = ctx["component"]
	var block: MapBlock = ctx["block"]
	var marks: Array = ctx["marks"]
	assert_false(component.check_win(Game), "未移除任何标记应判定失败")
	block.remove_objective_mark(marks[0])
	block.remove_objective_mark(marks[1])
	assert_false(component.check_win(Game), "移除 2 个仍剩 1 个应判定失败")
	block.remove_objective_mark(marks[2])
	assert_true(component.check_win(Game), "全部移除后应判定胜利")


func test_marks_cleared_full_mode_no_marks_mission() -> void:
	# 无标记任务（initial = 0 且场上无标记）：全清模式应返回 false 防误判
	var ctx: Dictionary = _setup_marks_cleared({}, 0, 0)
	assert_false(ctx["component"].check_win(Game), "无标记任务全清模式不应判定胜利")


func test_marks_cleared_count_mode() -> void:
	var ctx: Dictionary = _setup_marks_cleared({"count": 2}, 3, 3)
	var component: MissionComponent = ctx["component"]
	var block: MapBlock = ctx["block"]
	var marks: Array = ctx["marks"]
	assert_false(component.check_win(Game), "未移除任何标记应判定失败")
	block.remove_objective_mark(marks[0])
	block.remove_objective_mark(marks[1])
	assert_true(component.check_win(Game), "count 模式移除 2 个达 count=2 应判定胜利")


func test_marks_cleared_count_mode_insufficient() -> void:
	var ctx: Dictionary = _setup_marks_cleared({"count": 3}, 3, 3)
	var component: MissionComponent = ctx["component"]
	var block: MapBlock = ctx["block"]
	var marks: Array = ctx["marks"]
	block.remove_objective_mark(marks[0])
	block.remove_objective_mark(marks[1])
	assert_false(component.check_win(Game), "count 模式移除 2 个未达 count=3 应判定失败")
	block.remove_objective_mark(marks[2])
	assert_true(component.check_win(Game), "移除 3 个达 count=3 应判定胜利")


# === 4. state_flag ===

func test_state_flag_true() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("state_flag", {"key": "bomb_defused"})
	component.setup(Game, mc)
	Game.mission_config = mc
	assert_false(component.check_win(Game), "旗标未置位应判定失败")
	mc.mission_state["bomb_defused"] = true
	assert_true(component.check_win(Game), "旗标置 true 应判定胜利")


func test_state_flag_false_and_missing() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("state_flag", {"key": "van_repaired"})
	component.setup(Game, mc)
	Game.mission_config = mc
	mc.mission_state["van_repaired"] = false
	assert_false(component.check_win(Game), "旗标显式为 false 应判定失败")
	mc.mission_state.erase("van_repaired")
	assert_false(component.check_win(Game), "旗标缺失应判定失败")


# === 5. action_win_only ===

func test_action_win_only_always_false() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("action_win_only")
	assert_false(component.check_win(Game), "action_win_only 应恒返回 false")


func test_action_win_only_prevents_vacuous_win() -> void:
	# 挂载 action_win_only 后，MissionConfig.check_win 不应空真误判胜利
	var mc: MissionConfig = MissionConfig.new()
	mc.win_condition_components.append(MissionComponentRegistry.create("action_win_only"))
	Game.mission_config = mc
	assert_false(mc.check_win(Game), "仅挂载 action_win_only 的任务不应空真判定胜利")


# === 6. initial_objective_mark_count 字段与统计逻辑 ===

func test_mission_config_initial_mark_count_default_zero() -> void:
	var mc: MissionConfig = MissionConfig.new()
	assert_eq(mc.initial_objective_mark_count, 0, "MissionConfig 默认初始标记数应为 0")


func test_initialize_game_counts_objective_marks() -> void:
	# 最小任务数据：1 个出生地块 legend 声明 mission_mark=2，配 2 个任务标记
	var mission: MissionData = MissionData.new({
		"monster_pack_type": "zombie",
		"map_layout": [[2]],
		"map_legend": {
			"2": {"type": "spawn", "block_name": "面包车", "face": true, "mission_mark": 2},
		},
		"objective_marks": [
			{"mark_id": "m1"},
			{"mark_id": "m2"},
		],
	})
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.mission_config, "应创建任务配置")
	assert_eq(Game.map_area.size(), 1, "应构建 1 个地块")
	assert_eq(Game.mission_config.initial_objective_mark_count, 2, "开局应统计到 2 个任务标记")


func test_initialize_game_no_marks_counts_zero() -> void:
	var mission: MissionData = MissionData.new({"monster_pack_type": "zombie"})
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	assert_eq(Game.mission_config.initial_objective_mark_count, 0, "无任务标记的任务应统计为 0")
