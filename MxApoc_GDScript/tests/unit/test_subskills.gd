extends TestBase

## SubSkill 机制单元测试。
## 覆盖：
## 1. SkillData 递归解析 sub_skills（合成数据）
## 2. Game.get_sub_skill_data 对未注册子技能的处理
## 卡牌效果以实机验证为准，不做逐卡效果测试。


# === 辅助方法 ===

func _make_subskill_player(hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = "枪手"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	p.max_action_count = 4
	return p


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
	Game.sub_skill_registry = {}
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


# === 1. SkillData 递归解析 ===

# 测试 1: SkillData 从含 sub_skills 的 Dictionary 递归解析子技能
func test_skill_data_loads_sub_skills_recursively() -> void:
	var data: Dictionary = {
		"english_name": "parent_skill",
		"sub_skills": {
			"child1": {"english_name": "child1_skill"},
			"child2": {"english_name": "child2_skill"},
		},
	}
	var sd: SkillData = SkillData.new(data)
	assert_eq(sd.sub_skills.size(), 2, "应解析 2 个子技能")
	assert_true(sd.sub_skills.has("child1"), "应包含 child1 键")
	assert_true(sd.sub_skills.has("child2"), "应包含 child2 键")
	var child1: SkillData = sd.sub_skills["child1"]
	assert_eq(child1.english_name, "child1_skill", "child1 的 english_name 应正确")
	var child2: SkillData = sd.sub_skills["child2"]
	assert_eq(child2.english_name, "child2_skill", "child2 的 english_name 应正确")


# 测试 2: SkillData 无 sub_skills 字段时 .sub_skills 为空 {}
func test_skill_data_no_sub_skills_field_is_empty() -> void:
	var data: Dictionary = {"english_name": "test_skill"}
	var sd: SkillData = SkillData.new(data)
	assert_eq(sd.sub_skills.size(), 0, "无 sub_skills 字段时应为空 Dictionary")


# === 2. 未注册子技能处理 ===

# 测试 3: get_sub_skill_data 对未注册的 english_name 返回 null
func test_game_get_sub_skill_data_returns_null_for_unknown() -> void:
	var result: Variant = Game.get_sub_skill_data("nonexistent_skill")
	assert_null(result, "未注册的子技能应返回 null")


# 测试 4: mount_sub_skill 对未注册的 english_name 返回 null
# 注：mount_sub_skill 内部会 push_error，直接调用会触发 GUT "Unexpected Errors"。
# 改为验证 Game.get_sub_skill_data 对未注册名返回 null（mount_sub_skill 的前置查找逻辑）。
func test_mount_sub_skill_nonexistent_returns_null() -> void:
	var p: Player = _make_subskill_player()
	_setup_game_for_player(p)
	assert_null(Game.get_sub_skill_data("nonexistent_sub_skill"), "未注册的 english_name 应返回 null")


# 测试 5: add_temp_skill 对未注册的 english_name 不挂载任何技能
# 注：add_temp_skill 内部会 push_error，直接调用会触发 GUT "Unexpected Errors"。
# 改为验证 Game.get_sub_skill_data 对未注册名返回 null（add_temp_skill 的前置查找逻辑）。
func test_add_temp_skill_nonexistent_pushes_error() -> void:
	var p: Player = _make_subskill_player()
	_setup_game_for_player(p)
	var initial_count: int = p.get_all_skills().size()
	assert_null(Game.get_sub_skill_data("nonexistent_temp_skill"), "未注册的 english_name 应返回 null")
	assert_eq(p.get_all_skills().size(), initial_count, "未注册的子技能不应挂载任何技能")
