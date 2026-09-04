extends TestBase

## 任务进度面板（MissionProgressPanel）单元测试。
## 覆盖：build_lines_from 拼行格式、10 种条件类型的 _eval_condition 求值、
## 13 个任务 JSON 的 progress_conditions 配置合法性、build_lines 空/非空分支。
## 面板实例不加入场景树（_ready 不触发），只测纯数据方法（headless 可跑）。

## 已知条件类型全集（注意共 10 种）
const KNOWN_TYPES: Array = [
	"van_fuel", "van_boarding", "state_flag", "state_count", "hold_items",
	"submitted_count", "all_at_block", "escort_at_block", "marks_cleared", "all_revealed",
]

## 各类型必要 params（van_fuel / van_boarding / all_revealed 无必要参数）
const REQUIRED_PARAMS: Dictionary = {
	"state_flag": ["key"],
	"state_count": ["key", "target"],
	"hold_items": ["card_name", "count"],
	"submitted_count": ["card_name", "count"],
	"all_at_block": ["block_name"],
	"escort_at_block": ["card_name", "block_name"],
	"marks_cleared": ["count"],
}


# === 辅助方法 ===

func _make_panel() -> MissionProgressPanel:
	var panel: MissionProgressPanel = MissionProgressPanel.new()
	autofree(panel)
	return panel


## 创建并挂载 MissionConfig（mission_state 可直接写入）。
func _setup_mission_state() -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	Game.mission_config = mc
	return mc


# === A. build_lines_from 拼行格式 ===

func test_a_state_flag_line_text() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	var conds: Array = [
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "scientist_rescued"}},
	]
	mc.mission_state["scientist_rescued"] = true
	assert_eq(panel.build_lines_from(conds), ["1. ✔ 解救科学家"], "完成的 state_flag 行应为 '1. ✔ 文案'")
	mc.mission_state["scientist_rescued"] = false
	assert_eq(panel.build_lines_from(conds), ["1. 解救科学家"], "未完成的 state_flag 行应为 '1. 文案'（无 ✔）")


func test_a_state_count_line_text() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	mc.mission_state["kill_counts"] = {"僵尸步行者": 1}
	var conds: Array = [
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "scientist_rescued"}},
		{"text": "击杀僵尸", "type": "state_count", "params": {"key": "kill_counts", "name": "僵尸步行者", "target": 2}},
	]
	assert_eq(panel.build_lines_from(conds), ["1. 解救科学家", "2. 击杀僵尸(1/2)"],
		"未完成计数行应为 '{序号}. {文案}(x/n)'")
	mc.mission_state["kill_counts"] = {"僵尸步行者": 2}
	assert_eq(panel.build_lines_from(conds), ["1. 解救科学家", "2. ✔ 击杀僵尸(2/2)"],
		"完成计数行应为 '{序号}. ✔ {文案}(x/n)'")


func test_a_index_increments_per_displayed_line() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var conds: Array = [
		{"text": "条件一", "type": "state_flag", "params": {"key": "a"}},
		{"text": "条件二", "type": "state_flag", "params": {"key": "b"}},
		{"text": "条件三", "type": "state_count", "params": {"key": "c", "target": 2}},
	]
	var lines: Array = panel.build_lines_from(conds)
	assert_eq(lines.size(), 3, "3 个已知类型条件应生成 3 行")
	assert_true(str(lines[0]).begins_with("1. "), "第 1 行序号应为 1")
	assert_true(str(lines[1]).begins_with("2. "), "第 2 行序号应为 2")
	assert_true(str(lines[2]).begins_with("3. "), "第 3 行序号应为 3")


func test_a_unknown_type_skipped_and_index_continuous() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var conds: Array = [
		{"text": "未知条件", "type": "bogus_type"},
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "scientist_rescued"}},
	]
	var lines: Array = panel.build_lines_from(conds)
	assert_eq(lines.size(), 1, "未知类型行不应显示")
	assert_eq(lines[0], "1. 解救科学家", "跳过未知行后序号应保持连续（仍从 1 起）")
	assert_push_error("未知进度类型: bogus_type", "未知类型应产生一次 push_error")


func test_a_unknown_type_error_reported_once() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var conds: Array = [{"text": "未知条件", "type": "bogus_type"}]
	panel.build_lines_from(conds)
	panel.build_lines_from(conds)
	assert_push_error_count(1, "同一未知类型重复求值应去重只报一次错")


func test_a_non_dict_condition_skipped() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var conds: Array = [
		"not_a_dictionary",
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "scientist_rescued"}},
	]
	var lines: Array = panel.build_lines_from(conds)
	assert_eq(lines.size(), 1, "非 Dictionary 条件项应被跳过")
	assert_eq(lines[0], "1. 解救科学家", "跳过非法项后序号应保持连续")
	assert_push_error("非法条件项（应为 Dictionary）", "非 Dictionary 条件应产生一次 push_error")


func test_a_empty_conditions_return_empty() -> void:
	var panel: MissionProgressPanel = _make_panel()
	assert_eq(panel.build_lines_from([]), [], "空条件数组应返回空结果")


# === B. 各类型 _eval_condition 求值 ===

func test_b_van_fuel() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	mc.van_fuel_required = 4
	var van: MapBlock = _make_block("面包车", 0, 0)
	van.van_fuel = 1
	Game.map_area = [van]
	var r: Dictionary = panel._eval_condition({"type": "van_fuel"})
	assert_true(r["known"], "van_fuel 应为已知类型")
	assert_false(r["done"], "燃料 1/4 不应完成")
	assert_eq(r["progress"], "(1/4)", "燃料进度应为 (1/4)")
	van.van_fuel = 4
	r = panel._eval_condition({"type": "van_fuel"})
	assert_true(r["done"], "燃料 4/4 应完成")
	assert_eq(r["progress"], "(4/4)", "燃料进度应为 (4/4)")
	mc.van_fuel_required = -1
	r = panel._eval_condition({"type": "van_fuel"})
	assert_false(r["done"], "需求值 < 0 时应容错为未完成")
	assert_eq(r["progress"], "", "需求值 < 0 时不应有进度后缀")


func test_b_van_boarding() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var van: MapBlock = _make_block("面包车", 0, 0)
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = van
	p2.current_block = van
	Game.players = [p1, p2]
	Game.map_area = [van]
	var r: Dictionary = panel._eval_condition({"type": "van_boarding"})
	assert_true(r["done"], "全员登车且面包车无怪应完成")
	p2.current_block = _make_block("避难所", 1, 0)
	r = panel._eval_condition({"type": "van_boarding"})
	assert_false(r["done"], "一玩家不在面包车不应完成")
	p2.current_block = van
	van.add_monster_mark(1)
	r = panel._eval_condition({"type": "van_boarding"})
	assert_false(r["done"], "面包车有怪物标记不应完成")


func test_b_state_flag() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	var cond: Dictionary = {"type": "state_flag", "params": {"key": "scientist_rescued"}}
	var r: Dictionary = panel._eval_condition(cond)
	assert_false(r["done"], "标记未置位不应完成")
	assert_eq(r["progress"], "", "二态条件不应有进度后缀")
	mc.mission_state["scientist_rescued"] = true
	r = panel._eval_condition(cond)
	assert_true(r["done"], "标记置位应完成")


func test_b_state_count() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	# 顶层计数
	mc.mission_state["van_repair_count"] = 2
	var r: Dictionary = panel._eval_condition({"type": "state_count", "params": {"key": "van_repair_count", "target": 3}})
	assert_false(r["done"], "顶层计数 2/3 不应完成")
	assert_eq(r["progress"], "(2/3)", "顶层计数进度应为 (2/3)")
	# 嵌套计数
	mc.mission_state["kill_counts"] = {"僵尸步行者": 2}
	r = panel._eval_condition({"type": "state_count", "params": {"key": "kill_counts", "name": "僵尸步行者", "target": 2}})
	assert_true(r["done"], "嵌套计数 2/2 应完成")
	assert_eq(r["progress"], "(2/2)", "嵌套计数进度应为 (2/2)")
	# 值超 target 显示钳制
	mc.mission_state["kill_counts"] = {"僵尸步行者": 5}
	r = panel._eval_condition({"type": "state_count", "params": {"key": "kill_counts", "name": "僵尸步行者", "target": 2}})
	assert_true(r["done"], "值超 target 应完成")
	assert_eq(r["progress"], "(2/2)", "值超 target 显示应钳制到 target")


func test_b_hold_items() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var p1: Player = _make_player("P1")
	p1.hand.append(_make_card("燃料"))
	p1.hand.append(_make_card("燃料"))
	p1.hand.append(_make_card("燃料（备用）"))
	Game.players = [p1]
	var cond: Dictionary = {"type": "hold_items", "params": {"card_name": "燃料", "count": 4}}
	var r: Dictionary = panel._eval_condition(cond)
	assert_false(r["done"], "持有 3/4 不应完成")
	assert_eq(r["progress"], "(3/4)", "变体族卡（燃料（备用））应计入持有计数")
	p1.equipment_zone.append(_make_card("燃料", "equipment"))
	r = panel._eval_condition(cond)
	assert_true(r["done"], "装备区计入后 4/4 应完成")
	assert_eq(r["progress"], "(4/4)", "持有进度应为 (4/4)")


func test_b_submitted_count() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	mc.mission_state["submitted_items"] = {"燃料": 5}
	var cond: Dictionary = {"type": "submitted_count", "params": {"card_name": "燃料", "count": 6}}
	var r: Dictionary = panel._eval_condition(cond)
	assert_false(r["done"], "提交 5/6 不应完成")
	assert_eq(r["progress"], "(5/6)", "提交进度应为 (5/6)")
	mc.mission_state["submitted_items"] = {"燃料": 6}
	r = panel._eval_condition(cond)
	assert_true(r["done"], "提交 6/6 应完成")


func test_b_all_at_block_all_present_and_one_elsewhere() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var block: MapBlock = _make_block("军事基地", 0, 0)
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = block
	p2.current_block = block
	Game.players = [p1, p2]
	Game.map_area = [block]
	var r: Dictionary = panel._eval_condition({"type": "all_at_block", "params": {"block_name": "军事基地"}})
	assert_true(r["done"], "全员在指定地块应完成")
	p2.current_block = _make_block("避难所", 1, 0)
	r = panel._eval_condition({"type": "all_at_block", "params": {"block_name": "军事基地"}})
	assert_false(r["done"], "一玩家不在指定地块不应完成")


func test_b_all_at_block_no_monster_clear() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var block: MapBlock = _make_block("军事基地", 0, 0)
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = block
	p2.current_block = block
	Game.players = [p1, p2]
	Game.map_area = [block]
	var r: Dictionary = panel._eval_condition({"type": "all_at_block", "params": {"block_name": "军事基地", "no_monster": true}})
	assert_true(r["done"], "no_monster 且地块无怪时应完成")


func test_b_all_at_block_no_monster_with_mark() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var block: MapBlock = _make_block("军事基地", 0, 0)
	var p1: Player = _make_player("P1")
	p1.current_block = block
	Game.players = [p1]
	Game.map_area = [block]
	block.add_monster_mark(1)
	var r: Dictionary = panel._eval_condition({"type": "all_at_block", "params": {"block_name": "军事基地", "no_monster": true}})
	assert_false(r["done"], "no_monster 时地块有怪物标记不应完成")


func test_b_all_at_block_no_monster_with_monster_zone() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var block: MapBlock = _make_block("军事基地", 0, 0)
	var p1: Player = _make_player("P1")
	p1.current_block = block
	p1.monster_zone.append(Monster.new())
	Game.players = [p1]
	Game.map_area = [block]
	var r: Dictionary = panel._eval_condition({"type": "all_at_block", "params": {"block_name": "军事基地", "no_monster": true}})
	assert_false(r["done"], "no_monster 时玩家 monster_zone 有怪不应完成")


func test_b_escort_at_block() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var hospital: MapBlock = _make_block("医院", 0, 0)
	var p1: Player = _make_player("P1")
	p1.current_block = hospital
	p1.equipment_zone.append(_make_card("科学家", "equipment"))
	Game.players = [p1]
	Game.map_area = [hospital]
	var cond: Dictionary = {"type": "escort_at_block", "params": {"card_name": "科学家", "block_name": "医院"}}
	var r: Dictionary = panel._eval_condition(cond)
	assert_true(r["done"], "装备科学家的玩家在医院应完成")
	p1.current_block = _make_block("避难所", 1, 0)
	r = panel._eval_condition(cond)
	assert_false(r["done"], "持有者不在目标地块不应完成")
	p1.current_block = hospital
	p1.equipment_zone.clear()
	r = panel._eval_condition(cond)
	assert_false(r["done"], "无人持有指定卡不应完成")


func test_b_marks_cleared() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	mc.initial_objective_mark_count = 3
	var b1: MapBlock = _make_block("地点一", 0, 0)
	var b2: MapBlock = _make_block("地点二", 1, 0)
	b1.objective_marks.append({})
	b1.objective_marks.append({})
	Game.map_area = [b1, b2]
	var cond: Dictionary = {"type": "marks_cleared", "params": {"count": 3}}
	var r: Dictionary = panel._eval_condition(cond)
	assert_false(r["done"], "已移除 1/3 不应完成")
	assert_eq(r["progress"], "(1/3)", "剩余 2 个标记时应显示 (1/3)")
	b1.objective_marks.clear()
	r = panel._eval_condition(cond)
	assert_true(r["done"], "全部移除 3/3 应完成")
	assert_eq(r["progress"], "(3/3)", "全部移除应显示 (3/3)")


func test_b_all_revealed() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var blocks: Array = []
	for i in range(4):
		var b: MapBlock = _make_block("地块%d" % i, i, 0)
		if i < 3:
			b.revealed = true
		blocks.append(b)
	Game.map_area = blocks
	var r: Dictionary = panel._eval_condition({"type": "all_revealed"})
	assert_false(r["done"], "展示 3/4 不应完成")
	assert_eq(r["progress"], "(3/4)", "展示进度应为 (3/4)")
	for b in blocks:
		b.revealed = true
	r = panel._eval_condition({"type": "all_revealed"})
	assert_true(r["done"], "全部展示应完成")
	assert_eq(r["progress"], "(4/4)", "全部展示应显示 (4/4)")
	Game.map_area = []
	r = panel._eval_condition({"type": "all_revealed"})
	assert_false(r["done"], "无存活地块时应容错为未完成")
	assert_eq(r["progress"], "", "无存活地块时不应有进度后缀")


# === C. 13 个任务 JSON 配置合法性 ===

func test_c_condition_types_and_params() -> void:
	var missions: Array = DataManager.get_all_missions()
	for mission in missions:
		var mid: int = mission.mission_id
		for cond in mission.progress_conditions:
			assert_true(cond is Dictionary, "任务 %d 条件项应为 Dictionary" % mid)
			if not (cond is Dictionary):
				continue
			var cond_type: String = str(cond.get("type", ""))
			assert_true(KNOWN_TYPES.has(cond_type), "任务 %d 条件类型 '%s' 应属于已知类型集合" % [mid, cond_type])
			var text: String = str(cond.get("text", ""))
			assert_false(text.is_empty(), "任务 %d 条件 text 应为非空字符串" % mid)
			var required: Array = REQUIRED_PARAMS.get(cond_type, [])
			var params: Variant = cond.get("params", {})
			for param_name in required:
				assert_true(params is Dictionary and params.has(param_name),
					"任务 %d 类型 %s 缺少必要参数 %s" % [mid, cond_type, param_name])
				if params is Dictionary and params.has(param_name):
					var value: Variant = params.get(param_name)
					assert_false(value == null or str(value).is_empty(),
						"任务 %d 类型 %s 参数 %s 不应为空值" % [mid, cond_type, param_name])


func test_c_build_lines_with_real_conditions() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	var missions: Array = DataManager.get_all_missions()
	for mission in missions:
		var lines: Array = panel.build_lines_from(mission.progress_conditions)
		assert_eq(lines.size(), mission.progress_conditions.size(),
			"任务 %d 全部条件应为已知类型且逐行显示" % mission.mission_id)
		for line in lines:
			assert_false(str(line).is_empty(), "任务 %d 的显示行不应为空" % mission.mission_id)


# === D. build_lines 空/非空分支（面板可见性的数据条件） ===

func test_d_build_lines_empty_without_mission() -> void:
	var panel: MissionProgressPanel = _make_panel()
	Game.current_mission = null
	Game.mission_config = null
	assert_eq(panel.build_lines(), [], "current_mission 为 null 时应返回空")


func test_d_build_lines_empty_without_mission_config() -> void:
	var panel: MissionProgressPanel = _make_panel()
	Game.current_mission = MissionData.new({"progress_conditions": [
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "k"}},
	]})
	Game.mission_config = null
	assert_eq(panel.build_lines(), [], "mission_config 缺失时应返回空")


func test_d_build_lines_non_empty_with_mission_object() -> void:
	var panel: MissionProgressPanel = _make_panel()
	var mc: MissionConfig = _setup_mission_state()
	mc.mission_state["scientist_rescued"] = true
	Game.current_mission = MissionData.new({"progress_conditions": [
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "scientist_rescued"}},
	]})
	var lines: Array = panel.build_lines()
	assert_eq(lines.size(), 1, "设置 current_mission 后应返回非空")
	assert_eq(lines[0], "1. ✔ 解救科学家", "行内容应正确求值")


func test_d_build_lines_with_dictionary_mission() -> void:
	var panel: MissionProgressPanel = _make_panel()
	_setup_mission_state()
	Game.current_mission = {"progress_conditions": [
		{"text": "解救科学家", "type": "state_flag", "params": {"key": "k"}},
	]}
	var lines: Array = panel.build_lines()
	assert_eq(lines.size(), 1, "Dictionary 形式的 current_mission 也应正常求值")
	assert_eq(lines[0], "1. 解救科学家", "未置位标记应显示未完成行")
