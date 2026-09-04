extends TestBase

## 集成测试：任务行动技能化端到端链路（surface-mission-actions-as-skills Task 5）。
## 覆盖：真实任务 JSON（mission_1 / mission_9 / mission_11）→ MissionConfig 挂载 →
## player.move_to 真实移动链（进入挂载 / 取消回滚 / 离开卸载 / pull 与地块摧毁迁移）→
## Skill 管线（execute_filter 灰化 / execute_confirm_prompt 确认门 / use_active_skill 执行）。
## 与 tests/unit/test_mission_action_skills.gd 的分工：单测覆盖 decl 声明 / mount-unmount
## 幂等 / 出生点挂载；本文件覆盖真实移动事件链与真实 JSON 组件的行为闭环。
## 任务 9 的 destroy_current_mark 配置 require_no_monster=false（怪物标记不阻断），
## require_no_monster=true 的灰化分支用任务 11 真实 JSON 验证。


# === 辅助方法 ===

func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0, revealed: bool = true) -> MapBlock:
	return super._make_block(block_name, x, y, revealed)


## 轻量挂载：真实任务 JSON 组件 → MissionConfig（与 initialize_game 一致的旗标解析）
## 并执行 setup_components（注入组件的 game / mission_config 引用）。
func _mount_mission(mission_id: int) -> MissionConfig:
	var mission: MissionData = DataManager.get_mission(mission_id)
	if mission == null:
		assert_not_null(mission, "任务 %d 数据应已加载" % mission_id)
		return null
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = int(mission.van_fuel_required) if mission.van_fuel_required != null else -1
	mc.no_initial_monster_draw = mission.no_initial_monster_draw
	Game.mission_config = mc
	Game._mount_mission_components(mission)
	mc.setup_components(Game)
	return mc


## 设置玩家、地图与全局牌堆，并进入 PLAYING 状态。
func _setup_game_env(players: Array, map_blocks: Array = []) -> void:
	Game.players = players
	Game.map_area = map_blocks
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)


## 返回玩家身上全部任务行动技能（english_name 前缀 mission_action_）。
func _mission_skills(p: Player) -> Array:
	var result: Array = []
	for s in p.skills:
		if s is Skill and s.english_name.begins_with("mission_action_"):
			result.append(s)
	return result


## 按技能名查找玩家身上的任务行动技能，找不到返回 null。
func _find_mission_skill(p: Player, skill_name: String) -> Skill:
	for s in _mission_skills(p):
		if s.skill_name == skill_name:
			return s
	return null


## 构造在指定 trigger 节点取消事件的技能（移动取消注入，参考 test_player.gd）。
func _make_cancel_skill(trigger_name: String) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		EventSystem.cancel(ev)
	return s


func after_each() -> void:
	super.after_each()
	# 冲刷装备等 fire-and-forget 协程，避免事件残留跨用例
	for i in 3:
		await Engine.get_main_loop().process_frame


# ============================================================
# 1. 任务 1 全链路：真实 JSON + 真实 move_to + use_active_skill
# ============================================================

func test_mission_1_move_to_police_mounts_rescue_skill() -> void:
	_mount_mission(1)
	var police: MapBlock = _make_block("警察局", 0, 0)
	var gas: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = gas
	_setup_game_env([p], [police, gas])
	assert_eq(_mission_skills(p).size(), 0, "移动前不应有任务行动技能")
	var moved: bool = await p.move_to(police)
	assert_true(moved, "真实 move_to 进入警察局应成功")
	assert_eq(p.current_block, police, "玩家应位于警察局")
	var skills: Array = _mission_skills(p)
	assert_eq(skills.size(), 1, "进入警察局后应挂载 1 个任务行动技能")
	var skill: Skill = skills[0]
	assert_eq(skill.skill_name, "解救科学家", "技能名应为 解救科学家")
	assert_eq(skill.skill_type, "任务", "技能类型应为 任务")
	assert_eq(skill.active, "action", "应为主动技能（active=action）")
	assert_true(skill.english_name.begins_with("mission_action_"), "english_name 应带 mission_action_ 前缀")
	assert_true(skill.execute_filter(p, {}), "未解救且行动足够时 filter 应通过")
	var confirm_text: String = skill.execute_confirm_prompt(p)
	assert_true(confirm_text.find("解救") >= 0, "确认门文案应包含解救语义：%s" % confirm_text)
	assert_true(confirm_text.find("2") >= 0, "确认门文案应包含消耗行动数")


func test_mission_1_rescue_skill_filter_action_gating() -> void:
	_mount_mission(1)
	var police: MapBlock = _make_block("警察局", 0, 0)
	var gas: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = gas
	_setup_game_env([p], [police, gas])
	await p.move_to(police)
	var skill: Skill = _find_mission_skill(p, "解救科学家")
	assert_not_null(skill, "应已挂载解救科学家技能")
	p.action_count = 1
	assert_false(skill.execute_filter(p, {}), "行动不足（1 < 2）时 filter 应灰化")
	p.action_count = 4
	assert_true(skill.execute_filter(p, {}), "行动恢复后 filter 应重新可用")


func test_mission_1_use_active_skill_rescues_scientist() -> void:
	var mc: MissionConfig = _mount_mission(1)
	var police: MapBlock = _make_block("警察局", 0, 0)
	var gas: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = gas
	_setup_game_env([p], [police, gas])
	await p.move_to(police)
	var skill: Skill = _find_mission_skill(p, "解救科学家")
	assert_not_null(skill, "应已挂载解救科学家技能")
	# 单测直调 use_active_skill 跳过 UI 确认门（确认门在 action_selection_controller）
	await p.use_active_skill(skill)
	assert_eq(p.action_count, 2, "执行应扣减 2 点行动（4 → 2）")
	assert_true(p.has_equipment("科学家"), "科学家应装备到玩家装备区")
	assert_eq(mc.mission_state.get("scientist_rescued"), true, "执行后应标记 scientist_rescued")
	assert_eq(mc.mission_state.get("scientist_holder"), p, "执行后应记录持有者")
	assert_eq(p.current_block, police, "技能执行不应改变玩家位置")
	assert_false(skill.execute_filter(p, {}), "已解救后 filter 应灰化")
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0,
		"解救后旧行动选项通道应同步隐藏")


func test_mission_1_leave_police_unmounts_skill() -> void:
	_mount_mission(1)
	var police: MapBlock = _make_block("警察局", 0, 0)
	var gas: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = gas
	_setup_game_env([p], [police, gas])
	await p.move_to(police)
	assert_eq(_mission_skills(p).size(), 1, "进入警察局后应挂载任务技能")
	var moved: bool = await p.move_to(gas)
	assert_true(moved, "移动到加油站应成功")
	assert_eq(_mission_skills(p).size(), 0, "离开警察局后任务技能应卸载")


func test_mission_1_move_cancel_restores_source_block_skills() -> void:
	_mount_mission(1)
	var police: MapBlock = _make_block("警察局", 0, 0)
	var gas: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = gas
	_setup_game_env([p], [police, gas])
	await p.move_to(police)
	assert_eq(_mission_skills(p).size(), 1, "进入警察局后应挂载解救技能")
	# 注入移动取消：before_enter_block 节点取消事件
	p.add_skill(_make_cancel_skill("before_enter_block"))
	var moved: bool = await p.move_to(gas)
	assert_false(moved, "移动被取消应返回 false")
	assert_eq(p.current_block, police, "取消后应保留原地块")
	var skills: Array = _mission_skills(p)
	assert_eq(skills.size(), 1, "取消回滚后应恢复源地块（警察局）的任务技能")
	assert_eq(skills[0].skill_name, "解救科学家", "回滚后的技能应为解救科学家")
	assert_true(skills[0].execute_filter(p, {}), "回滚后的技能应可用（回到源地块状态）")


func test_mission_1_move_cancel_from_plain_no_skill_residue() -> void:
	_mount_mission(1)
	var police: MapBlock = _make_block("警察局", 0, 0)
	var gas: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = gas
	_setup_game_env([p], [police, gas])
	assert_eq(_mission_skills(p).size(), 0, "普通地块不应有任务技能")
	# 注入移动取消：目标地块（警察局）技能挂载后取消 → 应回滚卸载，不残留
	p.add_skill(_make_cancel_skill("before_enter_block"))
	var moved: bool = await p.move_to(police)
	assert_false(moved, "移动被取消应返回 false")
	assert_eq(p.current_block, gas, "取消后应保留原地块")
	assert_eq(_mission_skills(p).size(), 0, "取消回滚后不应残留目标地块的任务技能")


# ============================================================
# 2. 任务 9 动态技能：destroy_current_mark + upload_virus
# ============================================================

func test_mission_9_marked_block_mounts_destroy_skill() -> void:
	_mount_mission(9)
	var marked: MapBlock = _make_block("军事基地", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	var plain: MapBlock = _make_block("旷野", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 10
	p.current_block = plain
	_setup_game_env([p], [marked, plain])
	# 进入无标记地块：destroy 动态 block_match 不匹配、upload_virus 坠毁点不匹配
	await p.move_to(plain)
	assert_eq(_mission_skills(p).size(), 0, "无任务标记且非坠毁点的地块不应挂载任务技能")
	# 进入带任务标记地块：destroy block_match 动态匹配
	var moved: bool = await p.move_to(marked)
	assert_true(moved, "移动到标记地块应成功")
	var skills: Array = _mission_skills(p)
	assert_eq(skills.size(), 1, "进入带任务标记地块应挂载 1 个任务技能")
	assert_eq(skills[0].skill_name, "摧毁目标", "技能名应为 摧毁目标")
	assert_eq(skills[0].skill_type, "任务", "技能类型应为 任务")
	assert_true(skills[0].execute_filter(p, {}), "有标记且行动足够时 filter 应通过")


func test_mission_9_monster_marks_do_not_block_destroy() -> void:
	# 任务 9 真实配置 require_no_monster=false：地块怪物标记不阻断摧毁
	_mount_mission(9)
	var marked: MapBlock = _make_block("军事基地", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	var plain: MapBlock = _make_block("旷野", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 10
	p.current_block = plain
	_setup_game_env([p], [marked, plain])
	await p.move_to(marked)
	var skill: Skill = _find_mission_skill(p, "摧毁目标")
	assert_not_null(skill, "应已挂载摧毁目标技能")
	# 进入后追加怪物标记（进入时无怪物标记，避开潜行检定消耗）
	marked.add_monster_mark(2)
	assert_true(skill.execute_filter(p, {}),
		"任务 9（require_no_monster=false）地块有怪物标记时 filter 仍应通过")


func test_mission_9_destroy_execution_removes_mark() -> void:
	_mount_mission(9)
	var marked: MapBlock = _make_block("军事基地", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	var plain: MapBlock = _make_block("旷野", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 10
	p.current_block = plain
	_setup_game_env([p], [marked, plain])
	await p.move_to(marked)
	var skill: Skill = _find_mission_skill(p, "摧毁目标")
	assert_not_null(skill, "应已挂载摧毁目标技能")
	await p.use_active_skill(skill)
	assert_false(marked.has_objective_mark(), "执行后地块任务标记应被移除")
	assert_eq(p.action_count, 9, "执行应扣减 1 点行动（10 → 9）")
	assert_false(skill.execute_filter(p, {}), "标记移除后 filter 应灰化")
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0,
		"标记移除后旧行动选项通道应同步隐藏")


func test_mission_9_upload_virus_gating_and_win() -> void:
	var mc: MissionConfig = _mount_mission(9)
	var crash: MapBlock = _make_block("坠毁点", 0, 0)
	var marked: MapBlock = _make_block("军事基地", 1, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	var plain: MapBlock = _make_block("旷野", 2, 0)
	var p: Player = _make_player("P")
	p.action_count = 10
	p.current_block = plain
	_setup_game_env([p], [crash, marked, plain])
	# 真实装备科学家（create_scavenge_card + equip 协程）
	var card: Card = Game.create_scavenge_card("科学家")
	assert_not_null(card, "科学家拾荒卡应可创建")
	p.hand.append(card)
	await p.equip(card)
	assert_true(p.has_equipment("科学家"), "科学家应已装备")
	await p.move_to(crash)
	var skill: Skill = _find_mission_skill(p, "上传病毒")
	assert_not_null(skill, "进入坠毁点应挂载上传病毒技能")
	# 场上仍有未移除任务标记 → 灰化
	assert_false(skill.execute_filter(p, {}), "场上仍有任务标记时 filter 应灰化")
	# 清空场上标记 → 可用
	marked.remove_all_objective_marks()
	assert_true(skill.execute_filter(p, {}), "场上标记清空后 filter 应通过")
	var confirm_text: String = skill.execute_confirm_prompt(p)
	assert_true(confirm_text.find("上传病毒") >= 0, "确认门文案应包含上传病毒语义")
	await p.use_active_skill(skill)
	assert_eq(p.action_count, 9, "执行应扣减 1 点行动（10 → 9）")
	assert_true(Game.game_over_called, "上传病毒应触发游戏结束")
	assert_eq(Game.game_result, "win", "上传病毒应判定胜利")


func test_mission_9_pull_toward_migrates_skills() -> void:
	_mount_mission(9)
	# 3x1 地图：marked(0,0) 带标记、mid(1,0)、far(2,0)
	var marked: MapBlock = _make_block("军事基地", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	var mid: MapBlock = _make_block("旷野", 1, 0)
	var far: MapBlock = _make_block("森林", 2, 0)
	var p1: Player = _make_player("P1")
	p1.current_block = marked
	var p2: Player = _make_player("P2")
	p2.action_count = 10
	p2.current_block = far
	Game.map_width = 3
	Game.map_height = 1
	_setup_game_env([p1, p2], [marked, mid, far])
	Game.map_width = 3
	Game.map_height = 1
	# 第一次拉近：far → mid（无标记地块，无任务技能）
	p2.pull_toward_one_block_no_effect(p1)
	assert_eq(p2.current_block, mid, "第一次拉近应到达中间地块")
	assert_eq(_mission_skills(p2).size(), 0, "无标记地块迁移后不应有任务技能")
	# 第二次拉近：mid → marked（带标记地块，挂载摧毁目标）
	p2.pull_toward_one_block_no_effect(p1)
	assert_eq(p2.current_block, marked, "第二次拉近应到达标记地块")
	var skills: Array = _mission_skills(p2)
	assert_eq(skills.size(), 1, "拉近到标记地块应挂载任务技能")
	assert_eq(skills[0].skill_name, "摧毁目标", "技能名应为 摧毁目标")


func test_mission_9_destroy_block_migrates_skills() -> void:
	_mount_mission(9)
	var marked_a: MapBlock = _make_block("军事基地", 0, 0)
	marked_a.add_objective_mark({"mark_id": "mark_1"})
	var marked_b: MapBlock = _make_block("工厂", 1, 0)
	marked_b.add_objective_mark({"mark_id": "mark_2"})
	var plain: MapBlock = _make_block("旷野", 2, 0)
	var p: Player = _make_player("P")
	p.action_count = 10
	p.current_block = plain
	p.input = CliPlayerInput.new()
	_setup_game_env([p], [marked_a, marked_b, plain])
	# 经真实 move_to 进入标记地块挂载技能
	await p.move_to(marked_a)
	assert_eq(_mission_skills(p).size(), 1, "初始在标记地块应有摧毁目标技能")
	# 摧毁当前地块 → 弹到另一个标记地块：技能迁移为新地块的摧毁目标
	p.input.queue_choose_block(marked_b)
	var destroyed: bool = await Game.destroy_map_block(marked_a, null)
	assert_true(destroyed, "摧毁地块应成功")
	assert_eq(p.current_block, marked_b, "玩家应弹到相邻标记地块")
	var skills: Array = _mission_skills(p)
	assert_eq(skills.size(), 1, "迁移后应挂载新地块的任务技能")
	assert_eq(skills[0].skill_name, "摧毁目标", "迁移后的技能应为摧毁目标")
	# 再摧毁 → 弹到无标记地块：技能卸载
	p.input.queue_choose_block(plain)
	await Game.destroy_map_block(marked_b, null)
	assert_eq(p.current_block, plain, "玩家应弹到无标记地块")
	assert_eq(_mission_skills(p).size(), 0, "迁移到无标记地块后任务技能应卸载")


# ============================================================
# 3. 任务 11：destroy_current_mark require_no_monster=true 灰化
# ============================================================

func test_mission_11_destroy_skill_monster_gating() -> void:
	_mount_mission(11)
	var marked: MapBlock = _make_block("攻击部队", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	var plain: MapBlock = _make_block("旷野", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 10
	p.current_block = plain
	_setup_game_env([p], [marked, plain])
	await p.move_to(marked)
	var skill: Skill = _find_mission_skill(p, "摧毁目标")
	assert_not_null(skill, "进入标记地块应挂载摧毁目标技能")
	assert_true(skill.execute_filter(p, {}), "无怪物标记时 filter 应通过")
	# 进入后追加怪物标记（进入时无怪物标记，避开潜行检定消耗）
	marked.add_monster_mark(3)
	assert_false(skill.execute_filter(p, {}), "地块有怪物标记时 filter 应灰化（require_no_monster）")
	marked.remove_all_monster_marks()
	assert_true(skill.execute_filter(p, {}), "清除怪物标记后 filter 应恢复")
