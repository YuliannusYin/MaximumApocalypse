extends TestBase

## 行动类任务组件单元测试（Task 5：6 个行动选项组件）。
## 覆盖：destroy_current_mark / submit_items / repair_van / defuse_bomb /
## upload_virus / rescue_judge_win 的注册表映射、行动选项条件、
## 执行扣减行动与 mission_state 写入。
## 潜行检定分支用 stealth 值控制确定性（两骰和 2~12：
## stealth=12 必成功、缺省 0 必失败）。
## 注册表 reset() 会清除内置注册标记，create()/has() 懒注册会重新注册内置组件，
## 故测试中直接 create 即可，无需手动处理。

# === 辅助方法 ===

## 构造挂载单个行动组件的 MissionConfig 并完成 setup，返回上下文。
func _setup_component(id: String, comp_params: Dictionary, action_count: int = 3) -> Dictionary:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create(id, comp_params)
	mc.action_components.append(component)
	mc.setup_components(Game)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	p.action_count = action_count
	Game.players = [p]
	return {"mc": mc, "component": component, "p": p}


func before_each() -> void:
	MissionComponentRegistry.reset()
	super.before_each()


func after_each() -> void:
	MissionComponentRegistry.reset()
	super.after_each()


# === 0. 注册表内置映射 ===

func test_registry_action_components_registered() -> void:
	assert_true(MissionComponentRegistry.has("destroy_current_mark"), "destroy_current_mark 应已注册")
	assert_true(MissionComponentRegistry.has("submit_items"), "submit_items 应已注册")
	assert_true(MissionComponentRegistry.has("repair_van"), "repair_van 应已注册")
	assert_true(MissionComponentRegistry.has("defuse_bomb"), "defuse_bomb 应已注册")
	assert_true(MissionComponentRegistry.has("upload_virus"), "upload_virus 应已注册")
	assert_true(MissionComponentRegistry.has("rescue_judge_win"), "rescue_judge_win 应已注册")
	assert_true(MissionComponentRegistry.create("destroy_current_mark") is MissionComponentDestroyCurrentMark, "destroy_current_mark 应映射到正确类")
	assert_true(MissionComponentRegistry.create("submit_items") is MissionComponentSubmitItems, "submit_items 应映射到正确类")
	assert_true(MissionComponentRegistry.create("repair_van") is MissionComponentRepairVan, "repair_van 应映射到正确类")
	assert_true(MissionComponentRegistry.create("defuse_bomb") is MissionComponentDefuseBomb, "defuse_bomb 应映射到正确类")
	assert_true(MissionComponentRegistry.create("upload_virus") is MissionComponentUploadVirus, "upload_virus 应映射到正确类")
	assert_true(MissionComponentRegistry.create("rescue_judge_win") is MissionComponentRescueJudgeWin, "rescue_judge_win 应映射到正确类")


# === 1. destroy_current_mark ===

func test_destroy_option_available() -> void:
	var ctx: Dictionary = _setup_component("destroy_current_mark", {})
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("军事基地", 0, 0)
	block.add_objective_mark({"mark_id": "m1"})
	p.current_block = block
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "地块有任务标记且行动足够时应出现摧毁选项")
	assert_eq(options[0]["id"], "destroy_mark", "选项 id 应为 destroy_mark")
	assert_eq(options[0]["label"], "花费 1 行动摧毁目标", "选项 label 应包含默认消耗")
	assert_true(options[0]["execute"].is_valid(), "选项 execute 应为有效 Callable")


func test_destroy_option_conditions() -> void:
	var ctx: Dictionary = _setup_component("destroy_current_mark", {})
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("军事基地", 0, 0)
	p.current_block = block
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "地块无任务标记不应出现选项")
	block.add_objective_mark({"mark_id": "m1"})
	p.action_count = 0
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "行动数不足不应出现选项")


func test_destroy_require_no_monster_blocks_option() -> void:
	var ctx: Dictionary = _setup_component("destroy_current_mark", {"require_no_monster": true})
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("军事基地", 0, 0)
	block.add_objective_mark({"mark_id": "m1"})
	p.current_block = block
	# 地块有怪物标记 → 不出现
	block.add_monster_mark(1)
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "地块有怪物标记时不应出现摧毁选项")
	block.remove_monster_mark(1)
	# 同地块玩家被怪物纠缠 → 不出现
	var p2: Player = _make_player("P2")
	p2.current_block = block
	p2.monster_zone.append(Monster.new())
	Game.players = [p, p2]
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "同地块玩家怪物区有怪物时不应出现摧毁选项")
	# 怪物纠缠的是其他地块的玩家 → 不影响
	p2.current_block = _make_block("远处", 5, 5)
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 1, "怪物在其他地块时应出现摧毁选项")


func test_destroy_execute_removes_marks_and_costs_action() -> void:
	var ctx: Dictionary = _setup_component("destroy_current_mark", {"cost": 2}, 3)
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("军事基地", 0, 0)
	block.add_objective_mark({"mark_id": "m1"})
	block.add_objective_mark({"mark_id": "m2"})
	p.current_block = block
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "执行前应出现摧毁选项")
	await options[0]["execute"].call()
	assert_eq(p.action_count, 1, "摧毁应扣减 2 点行动（3 → 1）")
	assert_false(block.has_objective_mark(), "摧毁后地块不应再有任务标记")
	assert_eq(block.get_objective_marks().size(), 0, "全部任务标记应被移除")
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "标记移除后选项应消失")


# === 2. submit_items ===

func test_submit_option_available() -> void:
	var ctx: Dictionary = _setup_component("submit_items", {"block_name": "避难所", "items": {"燃料": 3, "医疗用品": 1}})
	var p: Player = ctx["p"]
	p.current_block = _make_block("避难所", 0, 0)
	p.hand.append(_make_card("燃料"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "地点正确且持有清单内物资时应出现提交选项")
	assert_eq(options[0]["id"], "submit_items", "选项 id 应为 submit_items")
	assert_eq(options[0]["label"], "消耗 1 行动提交物资", "选项 label 应为固定文案")
	assert_true(options[0]["execute"].is_valid(), "选项 execute 应为有效 Callable")


func test_submit_option_conditions() -> void:
	var ctx: Dictionary = _setup_component("submit_items", {"block_name": "避难所", "items": {"燃料": 3}})
	var p: Player = ctx["p"]
	# 不在提交地点
	p.current_block = _make_block("加油站", 0, 0)
	p.hand.append(_make_card("燃料"))
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "不在提交地点不应出现选项")
	# 在提交地点但无清单内物资
	p.current_block = _make_block("避难所", 1, 0)
	p.hand.clear()
	p.hand.append(_make_card("步枪"))
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "未持有清单内物资不应出现选项")
	# 有物资但行动不足
	p.hand.append(_make_card("燃料"))
	p.action_count = 0
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "行动数不足不应出现选项")


func test_submit_execute_discards_hand_items() -> void:
	var ctx: Dictionary = _setup_component("submit_items", {"block_name": "避难所", "items": {"燃料": 3, "医疗用品": 1}}, 3)
	var p: Player = ctx["p"]
	p.current_block = _make_block("避难所", 0, 0)
	p.hand.append(_make_card("燃料"))
	p.hand.append(_make_card("燃料"))
	p.hand.append(_make_card("医疗用品"))
	p.hand.append(_make_card("步枪"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "执行前应出现提交选项")
	await options[0]["execute"].call()
	assert_eq(p.action_count, 2, "提交应消耗 1 点行动（3 → 2）")
	assert_eq(p.hand.size(), 1, "清单内物资应全部弃置，仅剩非清单卡")
	assert_eq(p.hand[0].card_name, "步枪", "非清单卡不应被提交")
	var submitted: Dictionary = ctx["mc"].mission_state.get("submitted_items", {})
	assert_eq(int(submitted.get("燃料", 0)), 2, "燃料应按持有量计入提交进度")
	assert_eq(int(submitted.get("医疗用品", 0)), 1, "医疗用品应按持有量计入提交进度")


func test_submit_accumulates_across_submissions() -> void:
	var ctx: Dictionary = _setup_component("submit_items", {"block_name": "避难所", "items": {"燃料": 3}}, 3)
	var p: Player = ctx["p"]
	p.current_block = _make_block("避难所", 0, 0)
	# 第一次提交 1 张
	p.hand.append(_make_card("燃料"))
	await ctx["component"].get_action_options(Game, p)[0]["execute"].call()
	assert_eq(int(ctx["mc"].mission_state["submitted_items"].get("燃料", 0)), 1, "首次提交应累计 1 张燃料")
	# 第二次提交 1 张
	p.hand.append(_make_card("燃料"))
	await ctx["component"].get_action_options(Game, p)[0]["execute"].call()
	assert_eq(int(ctx["mc"].mission_state["submitted_items"].get("燃料", 0)), 2, "二次提交应累计到 2 张燃料")
	assert_eq(p.action_count, 1, "两次提交应共消耗 2 点行动（3 → 1）")


func test_submit_execute_from_equipment_zone() -> void:
	var ctx: Dictionary = _setup_component("submit_items", {"block_name": "避难所", "items": {"燃料": 2}}, 3)
	var p: Player = ctx["p"]
	p.current_block = _make_block("避难所", 0, 0)
	# 装备区实体 + 手牌各 1 张燃料（装备区物资提交路径）
	var ec: EquipmentCard = EquipmentCard.new()
	ec.card_name = "燃料"
	ec.source = "scavenge"
	p.equipment_zone.append(ec.instantiate(p))
	p.hand.append(_make_card("燃料"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "装备区与手牌各有物资时应出现提交选项")
	await options[0]["execute"].call()
	assert_eq(p.hand.size(), 0, "手牌中的燃料应被提交")
	assert_eq(p.equipment_zone.size(), 0, "装备区中的燃料应被提交（卸下并弃置）")
	var submitted: Dictionary = ctx["mc"].mission_state.get("submitted_items", {})
	assert_eq(int(submitted.get("燃料", 0)), 2, "装备区与手牌的燃料均应计入提交进度")
	assert_eq(p.action_count, 2, "提交应消耗 1 点行动（3 → 2）")


# === 3. repair_van ===

func test_repair_option_conditions() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {})
	var p: Player = ctx["p"]
	var van: MapBlock = _make_block("面包车", 0, 0)
	p.current_block = van
	p.hand.append(_make_card("多余配件"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "在面包车且持有配件时应出现维修选项")
	assert_eq(options[0]["id"], "repair_van", "选项 id 应为 repair_van")
	assert_eq(options[0]["label"], "消耗 1 行动维修面包车（弃置 1 张多余配件）", "选项 label 应包含配件名")
	# 不在面包车
	p.current_block = _make_block("避难所", 1, 0)
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "不在面包车地块不应出现选项")
	# 无配件
	p.current_block = van
	p.hand.clear()
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "未持有配件不应出现选项")
	# 已修满
	p.hand.append(_make_card("多余配件"))
	ctx["mc"].mission_state["van_repaired"] = true
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "修满后不应再出现维修选项")


func test_repair_three_times_completes() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {}, 9)
	var mc: MissionConfig = ctx["mc"]
	var component: MissionComponent = ctx["component"]
	var p: Player = ctx["p"]
	p.current_block = _make_block("面包车", 0, 0)
	for i in 3:
		p.hand.append(_make_card("多余配件"))
	# 第 1 次
	var options: Array = component.get_action_options(Game, p)
	assert_eq(options.size(), 1, "首次维修前应出现选项")
	await options[0]["execute"].call()
	assert_eq(int(mc.mission_state.get("van_repair_count")), 1, "首次维修后进度应为 1")
	assert_false(mc.mission_state.get("van_repaired", false), "进度 1/3 不应标记修满")
	assert_eq(p.hand.size(), 2, "首次维修应弃置 1 张配件")
	# 第 2 次
	options = component.get_action_options(Game, p)
	assert_eq(options.size(), 1, "第二次维修前应出现选项")
	await options[0]["execute"].call()
	assert_eq(int(mc.mission_state.get("van_repair_count")), 2, "第二次维修后进度应为 2")
	assert_false(mc.mission_state.get("van_repaired", false), "进度 2/3 不应标记修满")
	# 第 3 次
	options = component.get_action_options(Game, p)
	assert_eq(options.size(), 1, "第三次维修前应出现选项")
	await options[0]["execute"].call()
	assert_eq(int(mc.mission_state.get("van_repair_count")), 3, "第三次维修后进度应为 3")
	assert_true(mc.mission_state.get("van_repaired", false), "进度 3/3 应标记修满")
	assert_eq(p.hand.size(), 0, "三次维修应共弃置 3 张配件")
	assert_eq(p.action_count, 6, "三次维修应共消耗 3 点行动（9 → 6）")
	assert_eq(component.get_action_options(Game, p).size(), 0, "修满后不应再出现维修选项")


# === 4. defuse_bomb ===

func test_defuse_option_conditions() -> void:
	var ctx: Dictionary = _setup_component("defuse_bomb", {}, 3)
	var p: Player = ctx["p"]
	p.current_block = _make_block("电厂", 0, 0)
	p.hand.append(_make_card("满是灰尘的日记本"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "在电厂且持有日记本时应出现解除选项")
	assert_eq(options[0]["id"], "defuse_bomb", "选项 id 应为 defuse_bomb")
	assert_eq(options[0]["label"], "消耗 2 行动解除炸弹", "选项 label 应包含默认消耗")
	# 无日记本
	p.hand.clear()
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "未持有日记本不应出现选项")
	# 有日记本但行动不足（3 → 1）
	p.hand.append(_make_card("满是灰尘的日记本"))
	p.action_count = 1
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "行动数不足（1 < 2）不应出现选项")


func test_defuse_execute_activates_countdown() -> void:
	var ctx: Dictionary = _setup_component("defuse_bomb", {}, 4)
	var mc: MissionConfig = ctx["mc"]
	var p: Player = ctx["p"]
	p.current_block = _make_block("电厂", 0, 0)
	p.hand.append(_make_card("满是灰尘的日记本"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "执行前应出现解除选项")
	await options[0]["execute"].call()
	assert_eq(p.action_count, 2, "解除炸弹应扣减 2 点行动（4 → 2）")
	assert_eq(mc.mission_state.get("bomb_defused"), true, "执行后应标记 bomb_defused")
	assert_eq(mc.mission_state.get("countdown_activate"), true, "执行后应写入 countdown_activate 激活标记")
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "解除后选项应消失")
	assert_eq(p.hand.size(), 1, "日记本为持有门槛，不应被消耗")


func test_defuse_countdown_marker_activates_turn_countdown() -> void:
	# defuse_bomb 写入的 countdown_activate 标记应被 turn_countdown 组件消费激活
	var mc: MissionConfig = MissionConfig.new()
	var defuse: MissionComponent = MissionComponentRegistry.create("defuse_bomb", {})
	var countdown: MissionComponent = MissionComponentRegistry.create("turn_countdown", {"rounds": 3})
	mc.action_components.append(defuse)
	mc.trigger_components.append(countdown)
	mc.setup_components(Game)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = _make_block("电厂", 0, 0)
	p.hand.append(_make_card("满是灰尘的日记本"))
	Game.players = [p]
	await defuse.get_action_options(Game, p)[0]["execute"].call()
	assert_eq(mc.mission_state.get("countdown_activate"), true, "解除炸弹后应存在激活标记")
	countdown.on_event(Game, "turn_ended", {"player": p})
	assert_true(mc.mission_state.get("countdown_active", false), "turn_countdown 应消费标记激活倒计时")
	assert_false(mc.mission_state.has("countdown_activate"), "激活后标记键应被清除")
	assert_eq(int(mc.mission_state.get("countdown_remaining")), 3, "激活后剩余轮数应为 rounds")


# === 5. upload_virus ===

func test_upload_option_conditions() -> void:
	var ctx: Dictionary = _setup_component("upload_virus", {})
	var p: Player = ctx["p"]
	var crash: MapBlock = _make_block("坠毁点", 0, 0)
	var other: MapBlock = _make_block("避难所", 1, 0)
	Game.map_area = [crash, other]
	p.current_block = crash
	p.equipment_zone.append(_make_card("科学家", "equipment"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "装备科学家且场上无任务标记时应出现上传选项")
	assert_eq(options[0]["id"], "upload_virus", "选项 id 应为 upload_virus")
	assert_eq(options[0]["label"], "消耗 1 行动上传病毒", "选项 label 应为固定文案")
	# 场上还有未移除任务标记
	other.add_objective_mark({"mark_id": "m1"})
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "场上仍有任务标记时不应出现上传选项")
	other.remove_all_objective_marks()
	# 无科学家装备
	p.equipment_zone.clear()
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "装备区无科学家时不应出现上传选项")


func test_upload_execute_wins_game() -> void:
	var ctx: Dictionary = _setup_component("upload_virus", {}, 2)
	var p: Player = ctx["p"]
	var crash: MapBlock = _make_block("坠毁点", 0, 0)
	Game.map_area = [crash]
	p.current_block = crash
	p.equipment_zone.append(_make_card("科学家", "equipment"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "执行前应出现上传选项")
	await options[0]["execute"].call()
	assert_eq(p.action_count, 1, "上传应消耗 1 点行动（2 → 1）")
	assert_true(Game.game_over_called, "上传病毒应触发游戏结束")
	assert_eq(Game.game_result, "win", "游戏结果应为胜利")


# === 6. rescue_judge_win ===

func _setup_rescue_judge(stealth: int, action_count: int = 2) -> Dictionary:
	var ctx: Dictionary = _setup_component("rescue_judge_win", {}, action_count)
	var p: Player = ctx["p"]
	p.stealth = stealth
	var block: MapBlock = _make_block("实验室", 0, 0)
	block.add_objective_mark({"mark_id": "m1"})
	p.current_block = block
	return ctx


func test_rescue_judge_option_conditions() -> void:
	var ctx: Dictionary = _setup_component("rescue_judge_win", {})
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("实验室", 0, 0)
	p.current_block = block
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "地块无任务标记不应出现选项")
	block.add_objective_mark({"mark_id": "m1"})
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "地块有任务标记且行动足够时应出现解救选项")
	assert_eq(options[0]["id"], "rescue_judge_win", "选项 id 应为 rescue_judge_win")
	assert_eq(options[0]["label"], "消耗 1 行动解救科学家", "选项 label 应为固定文案")
	# 已执行过检定
	ctx["mc"].mission_state["rescue_judge_done"] = true
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "已执行过检定不应再出现选项")
	# 行动不足
	ctx["mc"].mission_state["rescue_judge_done"] = false
	p.action_count = 0
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "行动数不足不应出现选项")


func test_rescue_judge_success_wins() -> void:
	# stealth=12：两骰和 2~12 恒 ≤ 12，检定必成功
	var ctx: Dictionary = _setup_rescue_judge(12)
	var p: Player = ctx["p"]
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "执行前应出现解救选项")
	await options[0]["execute"].call()
	assert_eq(p.action_count, 1, "解救应消耗 1 点行动（2 → 1）")
	assert_eq(ctx["mc"].mission_state.get("rescue_judge_done"), true, "执行后应标记 rescue_judge_done")
	assert_true(Game.game_over_called, "检定成功应触发游戏结束")
	assert_eq(Game.game_result, "win", "潜行检定成功应判定胜利")


func test_rescue_judge_fail_with_diary_wins() -> void:
	# stealth=0：两骰和恒 ≥ 2 > 0，检定必失败；持有日记本仍胜利
	var ctx: Dictionary = _setup_rescue_judge(0)
	var p: Player = ctx["p"]
	p.hand.append(_make_card("满是灰尘的日记本"))
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "持有日记本不影响选项出现")
	await options[0]["execute"].call()
	assert_true(Game.game_over_called, "检定失败持日记本应触发游戏结束")
	assert_eq(Game.game_result, "win", "检定失败但持有日记本仍应胜利")


func test_rescue_judge_fail_without_diary_loses() -> void:
	# stealth=0：检定必失败且无日记本 → 失败
	var ctx: Dictionary = _setup_rescue_judge(0)
	var p: Player = ctx["p"]
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "无日记本不影响选项出现")
	await options[0]["execute"].call()
	assert_true(Game.game_over_called, "检定失败无日记本应触发游戏结束")
	assert_eq(Game.game_result, "lose", "检定失败且无日记本应判定失败")


func test_rescue_judge_done_hides_option() -> void:
	var ctx: Dictionary = _setup_rescue_judge(12)
	var component: MissionComponent = ctx["component"]
	var p: Player = ctx["p"]
	await component.get_action_options(Game, p)[0]["execute"].call()
	assert_eq(component.get_action_options(Game, p).size(), 0, "检定执行后选项应消失")
