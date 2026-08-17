extends GutTest

## "集中射击"重新设计单元测试。
## 覆盖：
## 1. content 编译无 Parser Error（含 var 声明检查）
## 2. 声明式字段存在（target_type / select_target / filter_target / window_prompt / defer_action_cost）
## 3. window_prompt 字段从 JSON → SkillData → Skill 正确传递
## 4. choose_target 方法签名含 prompt 参数
## 5. choose_target 接受 Dictionary 配置
## 6. String filter_target 被 CodeExecutor.compile_filter_target 正确编译过滤
## 7. use_card + defer_action_cost 取消保护：第一步取消时牌退回手牌、不消耗行动
## 8. 完整流程：选武器 → 选目标 → 消耗 1 行动 + 1 弹药 + 造成 5 伤害
## 设计 spec：.trae/specs/redesign-focused-shot/spec.md


# === 辅助方法 ===

func _make_player(hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = "枪手"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	return p


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


func _make_monster(monster_name: String = "test_monster", hp: int = 10) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = hp
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


## 创建一张弹药类装备牌（用于测试 filter_target 过滤）。
func _make_ammo_weapon(card_name: String = "test_weapon", charge: int = 3) -> EquipmentCard:
	var c: EquipmentCard = EquipmentCard.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "equipment"
	c.source = "game"
	c.charge_type = "ammo"
	c.charge_max = 6
	c.charge_current = charge
	c.size = 1
	return c


## 创建一张非弹药类装备牌（用于测试 filter_target 排除）。
func _make_non_ammo_equipment(card_name: String = "test_armor") -> EquipmentCard:
	var c: EquipmentCard = EquipmentCard.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "equipment"
	c.source = "game"
	c.charge_type = ""
	c.charge_max = 0
	c.charge_current = 0
	c.size = 1
	return c


## 从枪手 survivor 数据中取出 focused_shot 卡牌的原始字典。
func _get_focused_shot_card_dict() -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "应能加载枪手 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "focused_shot":
			return card_dict
	return {}


## 从枪手数据创建一张真实 focused_shot 卡牌（含编译后的技能 Callable）。
func _make_focused_shot_card() -> Card:
	var card_dict: Dictionary = _get_focused_shot_card_dict()
	assert(!card_dict.is_empty(), "未找到枪手 focused_shot 卡牌")
	return Game._create_game_card_from_dict(card_dict)


## 从枪手数据创建 focused_shot SkillData（用于字段检查）。
func _make_focused_shot_skill_data() -> SkillData:
	var card_dict: Dictionary = _get_focused_shot_card_dict()
	assert(!card_dict.is_empty(), "未找到枪手 focused_shot 卡牌")
	var raw_skills: Array = card_dict.get("skills", [])
	assert_gt(raw_skills.size(), 0, "focused_shot 应至少有一个技能")
	return SkillData.new(raw_skills[0])


func _setup_game_for_player(p: Player) -> void:
	Game.players = [p]
	Game.map_area = []
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.coop_death_mode = false
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


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
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 1. content 编译 ===

# 测试 1: focused_shot content 编译为有效 Callable，无 Parser Error
func test_focused_shot_content_compiles_without_error() -> void:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "枪手应存在")
	var found: bool = false
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") != "focused_shot":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "集中射击 content 应编译为有效 Callable")
			assert_engine_error_count(0, "集中射击 content 编译应无 Parser Error")
	assert_true(found, "应在枪手牌堆中找到 focused_shot 卡牌")


# 测试 2: focused_shot content 中所有局部变量使用 var 声明
# 防止再次出现 "Identifier 'xxx' not declared" Parser Error
func test_focused_shot_content_uses_var_declarations() -> void:
	var card_dict: Dictionary = _get_focused_shot_card_dict()
	var raw_skills: Array = card_dict.get("skills", [])
	var content: String = raw_skills[0].get("content", "")
	# _selected 与 target2 都应使用 var 声明
	assert_true(content.contains("var _selected"), "content 应使用 var 声明 _selected")
	assert_true(content.contains("var target2"), "content 应使用 var 声明 target2")
	# 编译验证
	var cb: Callable = CodeExecutor.compile_content(content)
	assert_true(cb.is_valid(), "var 声明齐全时 content 应编译成功")
	assert_engine_error_count(0, "var 声明齐全时 content 编译应无 Parser Error")


# === 2. 声明式字段存在 ===

# 测试 3: focused_shot SkillData 包含全部声明式字段
func test_focused_shot_skill_data_has_declarative_fields() -> void:
	var sd: SkillData = _make_focused_shot_skill_data()
	assert_eq(sd.target_type, "equipment", "target_type 应为 equipment")
	assert_eq(sd.select_target, 1, "select_target 应为 1")
	assert_false(sd.filter_target.strip_edges().is_empty(), "filter_target 应非空")
	assert_eq(sd.window_prompt, "\"集中射击\": 选取消耗弹药的武器牌", "window_prompt 应为预期提示文本")
	assert_true(sd.defer_action_cost, "defer_action_cost 应为 true")


# 测试 4: focused_shot filter_target 内容正确（弹药类 + 填充物 > 0 + 在装备区）
func test_focused_shot_filter_target_content() -> void:
	var sd: SkillData = _make_focused_shot_skill_data()
	var expected: String = "return target.in_equipment_area && target.charge_type == \"ammo\" && target.charge_current > 0"
	assert_eq(sd.filter_target, expected, "filter_target 应匹配预期过滤逻辑")


# 测试 5: focused_shot 无已删除的 complex_target 等字段
func test_focused_shot_no_removed_fields() -> void:
	var card_dict: Dictionary = _get_focused_shot_card_dict()
	var raw_skills: Array = card_dict.get("skills", [])
	var raw: Dictionary = raw_skills[0]
	assert_false(raw.has("complex_target"), "应删除 complex_target 字段")
	assert_false(raw.has("filter_target_1"), "应删除 filter_target_1 字段")
	assert_false(raw.has("filter_target_2"), "应删除 filter_target_2 字段")
	assert_false(raw.has("filter_target_1_range"), "应删除 filter_target_1_range 字段")
	assert_false(raw.has("filter_target_2_range"), "应删除 filter_target_2_range 字段")


# === 3. window_prompt 字段传递 ===

# 测试 6: SkillData 从 JSON 正确读取 window_prompt
func test_skill_data_reads_window_prompt_from_json() -> void:
	var sd: SkillData = SkillData.new({
		"skill_name": "测试技能",
		"window_prompt": "测试提示文本"
	})
	assert_eq(sd.window_prompt, "测试提示文本", "SkillData 应从 JSON 读取 window_prompt")


# 测试 7: SkillData 无 window_prompt 字段时默认空字符串
func test_skill_data_window_prompt_default_empty() -> void:
	var sd: SkillData = SkillData.new({"skill_name": "无提示技能"})
	assert_eq(sd.window_prompt, "", "无 window_prompt 字段时应默认空字符串")


# 测试 8: SkillData → Skill 转换时 window_prompt 正确传递
func test_skill_window_prompt_passed_from_skill_data() -> void:
	var sd: SkillData = SkillData.new({
		"skill_name": "测试技能",
		"window_prompt": "传递测试"
	})
	var skill: Skill = Game._create_skill_from_data(sd)
	assert_eq(skill.window_prompt, "传递测试", "Skill.window_prompt 应从 SkillData 传递")


# 测试 9: focused_shot 的 Skill 实例 window_prompt 字段正确
func test_focused_shot_skill_instance_has_window_prompt() -> void:
	var card: Card = _make_focused_shot_card()
	var found: bool = false
	for s in card.get_all_skills():
		if s.english_name == "focused_shot":
			found = true
			assert_eq(s.window_prompt, "\"集中射击\": 选取消耗弹药的武器牌", "Skill 实例 window_prompt 应正确")
			assert_eq(s.target_type, "equipment", "Skill 实例 target_type 应为 equipment")
			assert_eq(s.select_target, 1, "Skill 实例 select_target 应为 1")
			assert_true(s.defer_action_cost, "Skill 实例 defer_action_cost 应为 true")
	assert_true(found, "应在 focused_shot 卡牌上找到 focused_shot 技能")


# === 4. choose_target 方法签名 ===

# 测试 10: player.choose_target 接受 prompt 参数并传递给 input
# 使用 _PromptSpyInput 探针验证 prompt 传递到 input 层
func test_player_choose_target_passes_prompt_to_input() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var spy: _ChooseTargetSpyInput = _ChooseTargetSpyInput.new()
	# 队列注入一个空数组作为返回值，避免阻塞
	spy.queue_choose_target([])
	p.input = spy
	var _r: Array = await p.choose_target(1, null, "测试 prompt 文本")
	assert_eq(spy.last_prompt, "测试 prompt 文本", "choose_target 应将 prompt 传递给 input")
	assert_eq(spy.last_n, 1, "choose_target 应将 n 传递给 input")


# 测试 11: player.choose_target 的 prompt 参数默认为空字符串
func test_player_choose_target_prompt_defaults_empty() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var spy: _ChooseTargetSpyInput = _ChooseTargetSpyInput.new()
	spy.queue_choose_target([])
	p.input = spy
	var _r: Array = await p.choose_target(1)
	assert_eq(spy.last_prompt, "", "未传 prompt 时应默认为空字符串")


# === 5. choose_target 接受 Dictionary 配置 ===

# 测试 12: choose_target 接受 Dictionary 类型的 skill 参数（不崩溃）
func test_choose_target_accepts_dictionary_skill_config() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var config: Dictionary = {
		"filter_target_range": "long",
		"filter_target": "return target != player"
	}
	# 应正常返回，不崩溃
	var result: Array = await p.choose_target(1, config, "测试 Dictionary 配置")
	assert_eq(result.size(), 0, "CLI 队列注入空数组时应返回空数组")


# === 6. String filter_target 编译 ===

# 测试 13: CodeExecutor.compile_filter_target 正确编译 String 过滤代码
func test_compile_filter_target_string_code() -> void:
	var filter_code: String = "return target.charge_type == \"ammo\""
	var cb: Callable = CodeExecutor.compile_filter_target(filter_code)
	assert_true(cb.is_valid(), "String filter_target 应编译为有效 Callable")


# 测试 14: compile_filter_target 空字符串 / "true" 返回空 Callable（视为恒真）
func test_compile_filter_target_empty_returns_invalid_callable() -> void:
	var cb_empty: Callable = CodeExecutor.compile_filter_target("")
	assert_false(cb_empty.is_valid(), "空字符串应返回无效 Callable（恒真）")
	var cb_true: Callable = CodeExecutor.compile_filter_target("true")
	assert_false(cb_true.is_valid(), "\"true\" 应返回无效 Callable（恒真）")


# 测试 15: 编译后的 filter_target Callable 正确过滤弹药类装备
func test_compiled_filter_target_filters_ammo_equipment() -> void:
	var filter_code: String = "return target.in_equipment_area && target.charge_type == \"ammo\" && target.charge_current > 0"
	var cb: Callable = CodeExecutor.compile_filter_target(filter_code)
	assert_true(cb.is_valid(), "filter_target 应编译为有效 Callable")
	# 弹药类、在装备区、填充物 > 0：应通过
	var ammo_weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	ammo_weapon.in_equipment_area = true
	var event: Dictionary = EventSystem.create_event()
	var result_pass: bool = cb.call(null, ammo_weapon, event, null)
	assert_true(result_pass, "弹药类装备（填充物 > 0）应通过过滤")
	# 非弹药类装备：不通过
	var armor: EquipmentCard = _make_non_ammo_equipment("护甲")
	armor.in_equipment_area = true
	var result_fail_type: bool = cb.call(null, armor, event, null)
	assert_false(result_fail_type, "非弹药类装备应不通过过滤")
	# 弹药类但填充物为 0：不通过
	var empty_ammo: EquipmentCard = _make_ammo_weapon("空枪", 0)
	empty_ammo.in_equipment_area = true
	var result_fail_charge: bool = cb.call(null, empty_ammo, event, null)
	assert_false(result_fail_charge, "弹药类但填充物为 0 应不通过过滤")
	# 弹药类但不在装备区：不通过
	var offhand_ammo: EquipmentCard = _make_ammo_weapon("手边的枪", 3)
	offhand_ammo.in_equipment_area = false
	var result_fail_zone: bool = cb.call(null, offhand_ammo, event, null)
	assert_false(result_fail_zone, "不在装备区的弹药类装备应不通过过滤")


# 测试 16: focused_shot 的 filter_target String 编译后过滤逻辑正确
func test_focused_shot_filter_target_compiles_and_filters() -> void:
	var sd: SkillData = _make_focused_shot_skill_data()
	# SkillData 中 filter_target 为 String
	assert_true(sd.filter_target is String or typeof(sd.filter_target) == TYPE_STRING, "SkillData.filter_target 应为 String")
	# 编译为 Callable
	var cb: Callable = CodeExecutor.compile_filter_target(sd.filter_target)
	assert_true(cb.is_valid(), "focused_shot filter_target 应编译为有效 Callable")
	# 验证过滤逻辑
	var ammo_weapon: EquipmentCard = _make_ammo_weapon("柯尔特", 4)
	ammo_weapon.in_equipment_area = true
	var event: Dictionary = EventSystem.create_event()
	assert_true(cb.call(null, ammo_weapon, event, null), "柯尔特手枪（弹药 4）应通过过滤")


# === 7. use_card + defer_action_cost 取消保护 ===

# 测试 17: focused_shot 第一步（声明式选取武器）取消时牌退回手牌、不消耗行动
# use_card 中 select_target > 0 且 targets.is_empty() 且 deferred 时返回 false
func test_focused_shot_cancel_at_step1_returns_card_to_hand() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构建地图（长距离范围所需）
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	# 创建 focused_shot 卡牌
	var card: Card = _make_focused_shot_card()
	p.hand.append(card)
	# mock input：第一步选取时取消（返回空数组）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])  # 第一步取消
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "第一步取消应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "集中射击", "手牌中应为集中射击")
	assert_eq(p.game_discard_pile.get_all().size(), 0, "弃牌堆应为空")


# 测试 18: focused_shot 第二步（content 内 choose_target）取消时牌退回手牌、不消耗行动
# content 内 _selected.is_empty() → EventSystem.cancel(event) → use_card 检测 cancelled 返回 false
func test_focused_shot_cancel_at_step2_returns_card_to_hand() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构建地图
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	# 装备区放一把弹药武器（第一步选取的目标）
	var weapon: EquipmentCard = _make_ammo_weapon("柯尔特手枪", 4)
	weapon.in_equipment_area = true
	p.equipment_zone.append(weapon)
	# 创建 focused_shot 卡牌
	var card: Card = _make_focused_shot_card()
	p.hand.append(card)
	# mock input：第一步选 weapon，第二步取消（空数组）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([weapon])  # 第一步选取武器
	cli.queue_choose_target([])  # 第二步取消
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "第二步取消应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "集中射击", "手牌中应为集中射击")
	assert_eq(p.game_discard_pile.get_all().size(), 0, "弃牌堆应为空")
	# 弹药不应被消耗（content 在消耗前已 cancel）
	assert_eq(weapon.charge_current, 4, "第二步取消时弹药不应被消耗")


# === 8. 完整流程 ===

# 测试 19: focused_shot 完整流程：选武器 → 选目标 → 消耗 1 行动 + 1 弹药 + 造成 5 伤害
func test_focused_shot_full_flow_deals_damage() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构建地图（长距离范围所需）
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	# 装备区放一把弹药武器
	var weapon: EquipmentCard = _make_ammo_weapon("柯尔特手枪", 4)
	weapon.in_equipment_area = true
	p.equipment_zone.append(weapon)
	# 怪物作为攻击目标
	var monster: Monster = _make_monster("僵尸", 10)
	p.monster_zone = [monster]
	# 创建 focused_shot 卡牌
	var card: Card = _make_focused_shot_card()
	p.hand.append(card)
	# mock input：第一步选 weapon，第二步选 monster
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([weapon])  # 第一步选取武器
	cli.queue_choose_target([monster])  # 第二步选取攻击目标
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "完整流程应成功")
	assert_eq(p.action_count, 1, "应消耗 1 点行动次数（2 - 1 = 1）")
	assert_eq(weapon.charge_current, 3, "应消耗 1 枚弹药（4 - 1 = 3）")
	assert_eq(monster.hp, 5, "怪物应受到 5 点伤害（10 - 5 = 5）")
	# 卡牌应进入弃牌堆
	assert_eq(p.game_discard_pile.get_all().size(), 1, "弃牌堆应有 1 张（集中射击）")
	assert_eq(p.game_discard_pile.get_all()[0].card_name, "集中射击", "弃牌堆首张应为集中射击")


# 测试 20: focused_shot content 中 target2 变量正确引用第二步选取的目标
# 验证 content 代码逻辑：var target2 = _selected[0] → target2.damage(5, player)
func test_focused_shot_content_targets_second_selected() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 1
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	var weapon: EquipmentCard = _make_ammo_weapon("左轮手枪", 6)
	weapon.in_equipment_area = true
	p.equipment_zone.append(weapon)
	# 怪物 1（不应受伤）
	var monster_a: Monster = _make_monster("僵尸A", 10)
	# 怪物 2（应受伤）
	var monster_b: Monster = _make_monster("僵尸B", 10)
	p.monster_zone = [monster_a, monster_b]
	var card: Card = _make_focused_shot_card()
	p.hand.append(card)
	# 第一步选 weapon，第二步选 monster_b（不是 monster_a）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([weapon])
	cli.queue_choose_target([monster_b])
	p.input = cli
	var _r: bool = await p.use_card(card)
	# 仅 monster_b 应受伤
	assert_eq(monster_a.hp, 10, "未被选取的怪物不应受伤")
	assert_eq(monster_b.hp, 5, "被选取的怪物应受到 5 点伤害")


## 探针 input：记录 choose_target 调用参数（用于验证 prompt 传递）。
class _ChooseTargetSpyInput extends CliPlayerInput:
	var last_n: int = -1
	var last_skill: Variant = null
	var last_prompt: String = "__UNSET__"

	func choose_target(n: int, skill: Variant = null, prompt: String = "") -> Array:
		last_n = n
		last_skill = skill
		last_prompt = prompt
		return await super.choose_target(n, skill, prompt)
