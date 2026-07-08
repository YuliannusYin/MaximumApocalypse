extends GutTest

## RoleCard 单元测试。


func _make_card() -> RoleCard:
	var rc: RoleCard = RoleCard.new()
	rc.role_name = "猎人"
	rc.max_hp = 24
	rc.initial_hp = 24
	rc.sneak = 9
	rc.hunger_sneak = 8
	rc.equipment_capacity = 5
	return rc


func test_default_is_front() -> void:
	var rc: RoleCard = RoleCard.new()
	assert_true(rc.is_front(), "默认应为正面")


func test_flip_toggles_side() -> void:
	var rc: RoleCard = _make_card()
	rc.flip()
	assert_false(rc.is_front(), "flip 后应为反面")
	rc.flip()
	assert_true(rc.is_front(), "再次 flip 后应为正面")


func test_get_sneak_front_side() -> void:
	var rc: RoleCard = _make_card()
	assert_eq(rc.get_sneak(), 9, "正面应返回 sneak")


func test_get_sneak_back_side() -> void:
	var rc: RoleCard = _make_card()
	rc.flip()
	assert_eq(rc.get_sneak(), 8, "反面应返回 hunger_sneak")


func test_fields_default_values() -> void:
	var rc: RoleCard = RoleCard.new()
	assert_eq(rc.role_name, "")
	assert_eq(rc.max_hp, 0)
	assert_eq(rc.initial_hp, 0)
	assert_eq(rc.sneak, 0)
	assert_eq(rc.hunger_sneak, 0)
	assert_eq(rc.equipment_capacity, 5, "默认装备栏容量应为 5")
	assert_eq(rc.intrinsic_skills.size(), 0)


func test_intrinsic_skills_can_be_added() -> void:
	var rc: RoleCard = RoleCard.new()
	var s: Skill = Skill.new()
	s.skill_name = "侦察"
	rc.intrinsic_skills.append(s)
	assert_eq(rc.intrinsic_skills.size(), 1, "应能添加固有技能")
	assert_eq(rc.intrinsic_skills[0].skill_name, "侦察")
