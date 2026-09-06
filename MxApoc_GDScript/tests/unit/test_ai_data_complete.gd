extends TestBase

## 断言玩家侧 JSON 均带 ai.order / ai.useful。


func _assert_ai(ai: Variant, label: String) -> void:
	assert_true(ai is Dictionary, "%s 应有 ai 对象" % label)
	assert_true((ai as Dictionary).has("order"), "%s.ai 应有 order" % label)
	assert_true((ai as Dictionary).has("useful"), "%s.ai 应有 useful" % label)


func _assert_skill_tree(skill_data: SkillData, label: String) -> void:
	_assert_ai(skill_data.ai, label)
	for sub_key in skill_data.sub_skills.keys():
		_assert_skill_tree(skill_data.sub_skills[sub_key], "%s / sub %s" % [label, str(sub_key)])


func _assert_skill_dict(raw: Dictionary, label: String) -> void:
	_assert_ai(raw.get("ai"), label)
	var subs: Variant = raw.get("sub_skills", {})
	if subs is Dictionary:
		for sub_key in subs.keys():
			if subs[sub_key] is Dictionary:
				_assert_skill_dict(subs[sub_key], "%s / sub %s" % [label, str(sub_key)])


func test_survivor_cards_and_skills_have_ai() -> void:
	for survivor in DataManager.get_all_survivors():
		for skill_data in survivor.intrinsic_skills:
			_assert_skill_tree(skill_data, "%s 固有 %s" % [survivor.english_name, skill_data.english_name])
		for card_dict in survivor.deck:
			var card_id: String = "%s/%s" % [survivor.english_name, card_dict.get("english_name", "")]
			_assert_ai(card_dict.get("ai"), card_id)
			for raw in card_dict.get("skills", []):
				if raw is Dictionary:
					_assert_skill_dict(raw, "%s skill %s" % [card_id, raw.get("english_name", "")])


func test_scavenge_cards_and_skills_have_ai() -> void:
	for color in DataManager.get_scavenge_pile_colors():
		for card_data in DataManager.get_scavenge_pile(color):
			var card_id: String = "%s/%s" % [color, card_data.english_name]
			_assert_ai(card_data.ai, card_id)
			for skill_data in card_data.skills:
				_assert_skill_tree(skill_data, "%s skill %s" % [card_id, skill_data.english_name])


func test_common_skills_have_ai() -> void:
	for skill_data in DataManager.get_common_skills():
		_assert_skill_tree(skill_data, "common %s" % skill_data.english_name)


func test_map_block_skills_have_ai() -> void:
	for block in DataManager.get_all_map_blocks():
		for skill_data in block.skills:
			_assert_skill_tree(skill_data, "%s/%s" % [block.english_name, skill_data.english_name])
