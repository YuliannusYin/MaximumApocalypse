extends GutTest

## 任务行动技能化单元测试（surface-mission-actions-as-skills Task 1+2+3）。
## 覆盖：7 个行动组件 get_action_skill_decl 声明完整性、block_match 地块匹配、
## filter 灰化条件正反例、MissionConfig.mount_action_skills / unmount_action_skills
## 挂载卸载幂等性、挂载 Skill 的 filter/content/confirm_prompt 执行链路、
## initialize_game 出生点技能挂载（地块技能 + 任务行动技能）。
## 潜行检定分支用 stealth 值控制确定性（两骰和 2~12：stealth=12 必成功、缺省 0 必失败）。
## move_to 挂载链路（进入/回滚/清理）由 Task 5 集成测试覆盖，此处只测 mount/unmount/decl。

# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
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
	Game.current_mission = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


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


## 返回玩家身上全部任务行动技能（english_name 前缀 mission_action_）。
func _mission_skills(p: Player) -> Array:
	var result: Array = []
	for s in p.skills:
		if s is Skill and s.english_name.begins_with("mission_action_"):
			result.append(s)
	return result


func before_each() -> void:
	MissionComponentRegistry.reset()
	_clear_game()


func after_each() -> void:
	MissionComponentRegistry.reset()
	_clear_game()


# === 1. decl 完整性 ===

func test_decl_non_action_component_returns_null() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("state_flag", {"key": "k"})
	assert_not_null(component, "state_flag 组件应可创建")
	assert_null(component.get_action_skill_decl(), "非 action 类组件应返回 null")


func test_decl_complete_for_all_seven_components() -> void:
	var expectations: Dictionary = {
		"spend_action_rescue": "解救科学家",
		"destroy_current_mark": "摧毁目标",
		"submit_items": "提交物资",
		"repair_van": "维修面包车",
		"defuse_bomb": "解除炸弹",
		"upload_virus": "上传病毒",
		"rescue_judge_win": "解救科学家",
	}
	for id in expectations:
		var component: MissionComponent = MissionComponentRegistry.create(id, {})
		var decl: Variant = component.get_action_skill_decl()
		assert_not_null(decl, id + " 应返回 decl")
		assert_true(decl is Dictionary, id + " 的 decl 应为 Dictionary")
		for key in ["skill_name", "block_match", "filter", "execute", "confirm"]:
			assert_true(decl.has(key), id + " 的 decl 应含键 " + key)
		assert_eq(decl["skill_name"], expectations[id], id + " 的默认技能名应为 " + expectations[id])
		for key in ["block_match", "filter", "execute", "confirm"]:
			assert_true(decl[key].is_valid(), id + " 的 " + key + " 应为有效 Callable")


func test_decl_skill_name_override_spend_action_rescue() -> void:
	var ctx: Dictionary = _setup_component("spend_action_rescue", {"block_name": "实验室", "skill_name": "解救幸存者"})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	assert_eq(decl["skill_name"], "解救幸存者", "params.skill_name 应覆盖默认技能名")


# === 2. block_match ===

func test_block_match_static_components() -> void:
	# 静态组件按 params.block_name 匹配 block.block_name
	var cases: Array = [
		["spend_action_rescue", {"block_name": "实验室"}, "实验室", "加油站"],
		["submit_items", {"block_name": "避难所"}, "避难所", "隧道"],
		["repair_van", {}, "面包车", "避难所"],
		["defuse_bomb", {}, "电厂", "面包车"],
		["upload_virus", {}, "坠毁点", "避难所"],
	]
	for case in cases:
		var ctx: Dictionary = _setup_component(case[0], case[1])
		var decl: Variant = ctx["component"].get_action_skill_decl()
		assert_true(decl["block_match"].call(_make_block(case[2])), case[0] + " 在正确地块应匹配")
		assert_false(decl["block_match"].call(_make_block(case[3])), case[0] + " 在错误地块不应匹配")
		assert_false(decl["block_match"].call(null), case[0] + " 对 null 地块不应匹配")


func test_block_match_dynamic_components() -> void:
	# 动态组件按 block.has_objective_mark() 匹配
	for id in ["destroy_current_mark", "rescue_judge_win"]:
		var ctx: Dictionary = _setup_component(id, {})
		var decl: Variant = ctx["component"].get_action_skill_decl()
		var marked: MapBlock = _make_block("军事基地")
		marked.add_objective_mark({"mark_id": "m1"})
		var bare: MapBlock = _make_block("旷野")
		assert_true(decl["block_match"].call(marked), id + " 带任务标记地块应匹配")
		assert_false(decl["block_match"].call(bare), id + " 无任务标记地块不应匹配")


# === 3. filter 灰化条件正反例 ===

func test_filter_spend_action_rescue() -> void:
	var ctx: Dictionary = _setup_component("spend_action_rescue", {"block_name": "实验室"})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	p.current_block = _make_block("实验室")
	assert_true(decl["filter"].call(p), "未解救且行动足够时应可用")
	p.action_count = 1
	assert_false(decl["filter"].call(p), "行动不足（1 < 2）应灰化")
	p.action_count = 3
	ctx["mc"].mission_state["scientist_rescued"] = true
	assert_false(decl["filter"].call(p), "已解救后应灰化")


func test_filter_destroy_current_mark() -> void:
	var ctx: Dictionary = _setup_component("destroy_current_mark", {})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("军事基地")
	block.add_objective_mark({"mark_id": "m1"})
	p.current_block = block
	assert_true(decl["filter"].call(p), "地块有标记且行动足够时应可用")
	p.action_count = 0
	assert_false(decl["filter"].call(p), "行动不足应灰化")
	p.action_count = 3
	block.remove_all_objective_marks()
	assert_false(decl["filter"].call(p), "地块标记被移除后应灰化")


func test_filter_destroy_require_no_monster() -> void:
	var ctx: Dictionary = _setup_component("destroy_current_mark", {"require_no_monster": true})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("军事基地")
	block.add_objective_mark({"mark_id": "m1"})
	p.current_block = block
	assert_true(decl["filter"].call(p), "无怪物时应可用")
	block.add_monster_mark(1)
	assert_false(decl["filter"].call(p), "地块有怪物标记时应灰化")
	block.remove_monster_mark(1)
	var p2: Player = _make_player("P2")
	p2.current_block = block
	p2.monster_zone.append(Monster.new())
	Game.players = [p, p2]
	assert_false(decl["filter"].call(p), "同地块玩家怪物区有怪物时应灰化")


func test_filter_submit_items() -> void:
	var ctx: Dictionary = _setup_component("submit_items", {"block_name": "避难所", "items": {"燃料": 3}})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	p.current_block = _make_block("避难所")
	p.hand.append(_make_card("燃料"))
	assert_true(decl["filter"].call(p), "持有清单内物资且行动足够时应可用")
	p.action_count = 0
	assert_false(decl["filter"].call(p), "行动不足应灰化")
	p.action_count = 3
	p.hand.clear()
	assert_false(decl["filter"].call(p), "未持有清单内物资应灰化")


func test_filter_repair_van() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	p.current_block = _make_block("面包车")
	p.hand.append(_make_card("多余配件"))
	assert_true(decl["filter"].call(p), "持有配件且未修满时应可用")
	p.hand.clear()
	assert_false(decl["filter"].call(p), "未持有配件应灰化")
	p.hand.append(_make_card("多余配件"))
	ctx["mc"].mission_state["van_repaired"] = true
	assert_false(decl["filter"].call(p), "修满后应灰化")


func test_filter_defuse_bomb() -> void:
	var ctx: Dictionary = _setup_component("defuse_bomb", {})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	p.current_block = _make_block("电厂")
	p.hand.append(_make_card("满是灰尘的日记本"))
	assert_true(decl["filter"].call(p), "持有日记本且行动足够时应可用")
	p.action_count = 1
	assert_false(decl["filter"].call(p), "行动不足（1 < 2）应灰化")
	p.action_count = 3
	p.hand.clear()
	assert_false(decl["filter"].call(p), "未持有日记本应灰化")
	p.hand.append(_make_card("满是灰尘的日记本"))
	ctx["mc"].mission_state["bomb_defused"] = true
	assert_false(decl["filter"].call(p), "已解除后应灰化")


func test_filter_upload_virus() -> void:
	var ctx: Dictionary = _setup_component("upload_virus", {})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	var crash: MapBlock = _make_block("坠毁点")
	var other: MapBlock = _make_block("避难所", 1, 0)
	Game.map_area = [crash, other]
	p.current_block = crash
	p.equipment_zone.append(_make_card("科学家", "equipment"))
	assert_true(decl["filter"].call(p), "装备科学家且场上无任务标记时应可用")
	other.add_objective_mark({"mark_id": "m1"})
	assert_false(decl["filter"].call(p), "场上仍有未移除任务标记应灰化")
	other.remove_all_objective_marks()
	p.equipment_zone.clear()
	assert_false(decl["filter"].call(p), "装备区无科学家应灰化")


func test_filter_rescue_judge_win() -> void:
	var ctx: Dictionary = _setup_component("rescue_judge_win", {})
	var decl: Variant = ctx["component"].get_action_skill_decl()
	var p: Player = ctx["p"]
	var block: MapBlock = _make_block("实验室")
	block.add_objective_mark({"mark_id": "m1"})
	p.current_block = block
	assert_true(decl["filter"].call(p), "地块有标记、未执行过且行动足够时应可用")
	ctx["mc"].mission_state["rescue_judge_done"] = true
	assert_false(decl["filter"].call(p), "已执行过检定应灰化")
	ctx["mc"].mission_state["rescue_judge_done"] = false
	p.action_count = 0
	assert_false(decl["filter"].call(p), "行动不足应灰化")


# === 4. mount / unmount ===

func test_mount_adds_mission_skill() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {})
	var p: Player = ctx["p"]
	var van: MapBlock = _make_block("面包车")
	p.current_block = van
	ctx["mc"].mount_action_skills(p, van)
	var skills: Array = _mission_skills(p)
	assert_eq(skills.size(), 1, "匹配地块挂载后应有 1 个任务行动技能")
	var skill: Skill = skills[0]
	assert_eq(skill.skill_name, "维修面包车", "技能名应为组件声明的技能名")
	assert_eq(skill.skill_type, "任务", "技能类型应为 任务")
	assert_eq(skill.active, "action", "应为主动技能（active=action）")
	assert_true(skill.english_name.begins_with("mission_action_"), "english_name 应带 mission_action_ 前缀")
	assert_true(skill.skill_description.length() > 0, "技能描述应为确认文案（非空）")


func test_mount_non_matching_block_no_skill() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {})
	var p: Player = ctx["p"]
	var shelter: MapBlock = _make_block("避难所")
	p.current_block = shelter
	ctx["mc"].mount_action_skills(p, shelter)
	assert_eq(_mission_skills(p).size(), 0, "不匹配地块挂载后不应有任务行动技能")


func test_unmount_removes_mission_skills() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {})
	var p: Player = ctx["p"]
	var van: MapBlock = _make_block("面包车")
	p.current_block = van
	ctx["mc"].mount_action_skills(p, van)
	assert_eq(_mission_skills(p).size(), 1, "挂载后应有 1 个任务行动技能")
	ctx["mc"].unmount_action_skills(p)
	assert_eq(_mission_skills(p).size(), 0, "卸载后任务行动技能应消失")
	assert_eq(p.skills.size(), 0, "卸载后玩家技能列表应为空")


func test_mount_idempotent() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {})
	var p: Player = ctx["p"]
	var van: MapBlock = _make_block("面包车")
	p.current_block = van
	ctx["mc"].mount_action_skills(p, van)
	ctx["mc"].mount_action_skills(p, van)
	ctx["mc"].mount_action_skills(p, van)
	assert_eq(_mission_skills(p).size(), 1, "重复挂载应幂等，不重复累积")


func test_mount_multiple_components_distinct_english_names() -> void:
	# 两个组件同时匹配面包车地块：repair_van + submit_items（block_name 面包车）
	var mc: MissionConfig = MissionConfig.new()
	mc.action_components.append(MissionComponentRegistry.create("repair_van", {}))
	mc.action_components.append(MissionComponentRegistry.create("submit_items", {"block_name": "面包车", "items": {"燃料": 1}}))
	mc.setup_components(Game)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	p.action_count = 3
	p.current_block = _make_block("面包车")
	Game.players = [p]
	mc.mount_action_skills(p, p.current_block)
	var skills: Array = _mission_skills(p)
	assert_eq(skills.size(), 2, "两个匹配组件应各挂载 1 个任务技能")
	assert_ne(skills[0].english_name, skills[1].english_name, "多组件的 english_name 应互不相同")
	assert_eq(skills[0].skill_name, "维修面包车", "第 0 个组件的技能名应为维修面包车")
	assert_eq(skills[1].skill_name, "提交物资", "第 1 个组件的技能名应为提交物资")


# === 5. 挂载 Skill 执行链路 ===

func test_mounted_skill_execution_chain_repair() -> void:
	var ctx: Dictionary = _setup_component("repair_van", {}, 3)
	var p: Player = ctx["p"]
	var van: MapBlock = _make_block("面包车")
	p.current_block = van
	p.hand.append(_make_card("多余配件"))
	ctx["mc"].mount_action_skills(p, van)
	var skill: Skill = _mission_skills(p)[0]
	assert_true(skill.execute_filter(p, {}), "持有配件时 filter 应通过")
	var confirm_text: String = skill.execute_confirm_prompt(p)
	assert_true(confirm_text.length() > 0, "确认门文案应非空")
	assert_true(confirm_text.find("维修") >= 0, "确认门文案应包含技能语义")
	await skill.execute_content(p, {})
	assert_eq(p.action_count, 2, "执行应扣减 1 点行动（3 → 2）")
	assert_eq(p.hand.size(), 0, "执行应弃置 1 张配件")
	assert_eq(int(ctx["mc"].mission_state.get("van_repair_count", 0)), 1, "执行后维修进度应为 1")
	assert_false(skill.execute_filter(p, {}), "配件耗尽后 filter 应灰化")


func test_mounted_skill_execution_chain_rescue() -> void:
	var ctx: Dictionary = _setup_component("spend_action_rescue", {"block_name": "实验室"}, 3)
	var p: Player = ctx["p"]
	var lab: MapBlock = _make_block("实验室")
	p.current_block = lab
	ctx["mc"].mount_action_skills(p, lab)
	var skill: Skill = _mission_skills(p)[0]
	assert_true(skill.execute_filter(p, {}), "未解救且行动充足时 filter 应通过")
	var confirm_text: String = skill.execute_confirm_prompt(p)
	assert_true(confirm_text.find("解救") >= 0, "确认门文案应包含解救语义")
	await skill.execute_content(p, {})
	assert_eq(p.action_count, 1, "执行应扣减 2 点行动（3 → 1）")
	assert_true(p.has_equipment("科学家"), "执行后应装备解救的科学家")
	assert_eq(ctx["mc"].mission_state.get("scientist_rescued"), true, "执行后应标记 scientist_rescued")
	assert_eq(ctx["mc"].mission_state.get("scientist_holder"), p, "执行后应记录持有者")
	assert_false(skill.execute_filter(p, {}), "解救完成后 filter 应灰化")


# === 6. 出生点挂载（initialize_game） ===

func test_initialize_game_mounts_spawn_skills() -> void:
	# 最小任务数据：出生点为面包车、行动组件 repair_van（参考任务 6 场景）
	var mission: MissionData = MissionData.new({
		"monster_pack_type": "zombie",
		"map_blocks_config": {"加油站": 1},
		"map_layout": [[2, 1]],
		"map_legend": {
			"2": {"type": "spawn", "block_name": "面包车", "face": true},
			"1": "random_block",
		},
		"actions": [
			{"component": "repair_van", "params": {"block_name": "面包车", "card_name": "多余配件", "times": 3}},
		],
	})
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	assert_eq(Game.players.size(), 1, "应创建 1 名玩家")
	var p: Player = Game.players[0]
	var has_van_block_skill: bool = false
	var mission_skills: Array = []
	for s in p.skills:
		if s.english_name == "van":
			has_van_block_skill = true
		if s.english_name.begins_with("mission_action_"):
			mission_skills.append(s)
	assert_true(has_van_block_skill, "开局应挂载出生点（面包车）地块技能")
	assert_eq(mission_skills.size(), 1, "开局应挂载 1 个任务行动技能")
	assert_eq(mission_skills[0].skill_name, "维修面包车", "任务行动技能名应为维修面包车")
	assert_eq(mission_skills[0].skill_type, "任务", "任务行动技能类型应为 任务")
	assert_eq(mission_skills[0].active, "action", "任务行动技能应为主动技能")
