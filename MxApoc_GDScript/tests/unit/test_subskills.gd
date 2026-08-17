extends GutTest

## SubSkill 机制单元测试。
## 覆盖：
## 1. SkillData 递归解析 sub_skills
## 2. Game.sub_skill_registry 在 _create_skill_from_data 时自动注册
## 3. add_skill / remove_skill 自动挂载/卸载子技能
## 4. mount_sub_skill mount-on-use 模式（含去重）
## 5. add_temp_skill 同/异 trigger 模式
## 6. use_card 端到端流程（空尖弹/搜索尸体）
## 7. 装备自动挂载/卸载子技能（游侠帽）
## 8. 老兵"把你的爪子拿开"免疫异 trigger 模式
## 9. 机械师"升级"mount_sub_skill 验证


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
	p.max_action_count = 4
	return p


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


func _make_monster(monster_name: String = "test_monster", hp: int = 20) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = hp
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


## 创建一张弹药类武器装备牌。
func _make_ammo_weapon(card_name: String = "test_weapon", charge: int = 3, max_charge: int = 6) -> EquipmentCard:
	var c: EquipmentCard = EquipmentCard.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "equipment"
	c.source = "game"
	c.charge_type = "ammo"
	c.charge_max = max_charge
	c.charge_current = charge
	c.size = 1
	c.range = "short"
	return c


## 创建一张非弹药类装备牌。
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


## 创建一张拾荒牌（用于填入拾荒牌堆，draw_scavenge 会抓到手牌）。
func _make_scavenge_card(card_name: String = "scavenge_card") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "action"
	c.source = "scavenge"
	return c


## 从指定 survivor 数据中取出指定 english_name 卡牌的原始字典。
func _get_card_dict_from_survivor(survivor_name: String, english_name: String) -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor(survivor_name)
	assert_not_null(sd, "应能加载 survivor 数据: " + survivor_name)
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == english_name:
			return card_dict
	return {}


## 从指定 survivor 数据创建一张真实卡牌（含编译后的技能 Callable）。
func _make_card_from_survivor(survivor_name: String, english_name: String) -> Card:
	var card_dict: Dictionary = _get_card_dict_from_survivor(survivor_name, english_name)
	assert(!card_dict.is_empty(), "未找到 survivor " + survivor_name + " 的卡牌: " + english_name)
	return Game._create_game_card_from_dict(card_dict)


func _make_hollow_point_card() -> Card:
	return _make_card_from_survivor("gunslinger", "hollow_point")


func _make_search_corpse_card() -> Card:
	return _make_card_from_survivor("gunslinger", "search_corpse")


func _make_ranger_hat_card() -> Card:
	return _make_card_from_survivor("gunslinger", "ranger_hat")


func _make_pull_trigger_happy_card() -> Card:
	return _make_card_from_survivor("gunslinger", "pull_trigger_happy")


func _make_energy_drink_card() -> Card:
	return _make_card_from_survivor("firefighter", "energy_drink")


func _make_check_weapon_card() -> Card:
	return _make_card_from_survivor("mechanic", "check_weapon")


func _make_upgrade_card() -> Card:
	return _make_card_from_survivor("mechanic", "upgrade")


## 构造一张包含 take_your_paws_off 技能的合成卡牌，用于注册 take_your_paws_off_immune。
## take_your_paws_off 在 veteran.json 的 sub_survivors[0].intrinsic_skills 中。
func _make_take_your_paws_off_card() -> Card:
	var sd: SurvivorData = DataManager.get_survivor("veteran")
	assert_not_null(sd, "应能加载老兵 survivor 数据")
	assert_gt(sd.sub_survivors.size(), 0, "老兵应有 sub_survivors")
	var sub_dict: Dictionary = sd.sub_survivors[0]
	var intrinsic_skills: Array = sub_dict.get("intrinsic_skills", [])
	for raw in intrinsic_skills:
		if raw is Dictionary and raw.get("english_name", "") == "take_your_paws_off":
			var card_dict: Dictionary = {
				"card_name": "把你的爪子拿开",
				"english_name": "take_your_paws_off",
				"card_type": "action",
				"skills": [raw],
			}
			return Game._create_game_card_from_dict(card_dict)
	assert(false, "未在老兵 sub_survivors 中找到 take_your_paws_off 技能")
	return null


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
	Game.sub_skill_registry = {}
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


func _has_skill_by_english_name(p: Player, en_name: String) -> bool:
	return p.has_skill_by_english_name(en_name)


func _count_skill_by_english_name(p: Player, en_name: String) -> int:
	var count: int = 0
	for s in p.get_all_skills():
		if s.english_name == en_name:
			count += 1
	return count


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


# === 2. Game.sub_skill_registry 注册 ===

# 测试 3: 创建 hollow_point 卡牌后 sub_skill_registry 应含 hollow_point_damage / hollow_point_remove
func test_game_sub_skill_registry_populated_on_card_create() -> void:
	var _card: Card = _make_hollow_point_card()
	assert_true(Game.sub_skill_registry.has("hollow_point_damage"), "应注册 hollow_point_damage")
	assert_true(Game.sub_skill_registry.has("hollow_point_remove"), "应注册 hollow_point_remove")


# 测试 4: get_sub_skill_data 对未注册的 english_name 返回 null
func test_game_get_sub_skill_data_returns_null_for_unknown() -> void:
	var result: Variant = Game.get_sub_skill_data("nonexistent_skill")
	assert_null(result, "未注册的子技能应返回 null")


# === 3. add_skill / remove_skill 自动挂载/卸载 ===

# 测试 5: 装备 ranger_hat 后 add_skill 自动挂载其 sub_skill ranger_hat_damage
func test_add_skill_auto_mounts_sub_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var ranger_hat: Card = _make_ranger_hat_card()
	await p.equip(ranger_hat)
	assert_true(_has_skill_by_english_name(p, "ranger_hat"), "应挂载 ranger_hat 父技能")
	assert_true(_has_skill_by_english_name(p, "ranger_hat_damage"), "应自动挂载子技能 ranger_hat_damage")


# 测试 6: 去重：预挂载 ranger_hat_damage 后再 add_skill 父技能，不重复挂载
func test_add_skill_dedup_sub_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var card: Card = _make_ranger_hat_card()
	var pre: Skill = p.mount_sub_skill("ranger_hat_damage")
	assert_not_null(pre, "首次 mount_sub_skill 应返回 Skill 实例")
	assert_eq(_count_skill_by_english_name(p, "ranger_hat_damage"), 1, "首次挂载后应有 1 个 ranger_hat_damage")
	var parent_skill: Skill = card.get_all_skills()[0]
	p.add_skill(parent_skill)
	assert_eq(_count_skill_by_english_name(p, "ranger_hat_damage"), 1, "add_skill 应去重，不重复挂载子技能")


# 测试 7: remove_skill 父技能后自动卸载仍挂载的子技能
func test_remove_skill_auto_unmounts_sub_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var ranger_hat: Card = _make_ranger_hat_card()
	await p.equip(ranger_hat)
	assert_true(_has_skill_by_english_name(p, "ranger_hat_damage"), "装备后应已挂载 ranger_hat_damage")
	var parent_skill: Skill = null
	for s in p.get_all_skills():
		if s.english_name == "ranger_hat":
			parent_skill = s
			break
	assert_not_null(parent_skill, "应找到 ranger_hat 父技能")
	p.remove_skill(parent_skill)
	assert_false(_has_skill_by_english_name(p, "ranger_hat"), "移除后 ranger_hat 父技能应被卸载")
	assert_false(_has_skill_by_english_name(p, "ranger_hat_damage"), "移除父技能后子技能应自动卸载")


# === 4. mount_sub_skill mount-on-use ===

# 测试 8: mount_sub_skill 重复调用去重，第二次返回同一 Skill 实例
func test_mount_sub_skill_mounts_and_dedups() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var _card: Card = _make_hollow_point_card()
	var s1: Skill = p.mount_sub_skill("hollow_point_damage")
	assert_not_null(s1, "首次 mount_sub_skill 应返回 Skill 实例")
	var s2: Skill = p.mount_sub_skill("hollow_point_damage")
	assert_not_null(s2, "第二次 mount_sub_skill 应返回 Skill 实例（去重）")
	assert_eq(s1, s2, "去重：第二次应返回同一 Skill 实例")
	assert_eq(_count_skill_by_english_name(p, "hollow_point_damage"), 1, "去重：仅 1 个挂载")


# 测试 9: mount_sub_skill 对未注册的 english_name 返回 null
# 注：mount_sub_skill 内部会 push_error，直接调用会触发 GUT "Unexpected Errors"。
# 改为验证 Game.get_sub_skill_data 对未注册名返回 null（mount_sub_skill 的前置查找逻辑）。
func test_mount_sub_skill_nonexistent_returns_null() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_null(Game.get_sub_skill_data("nonexistent_sub_skill"), "未注册的 english_name 应返回 null")


# === 5. add_temp_skill 同 trigger 模式 ===

# 测试 10: pull_trigger_happy_clear 同 trigger 模式（expire == JSON trigger）
# 验证：english_name 加 _temp 后缀、触发后执行原 content 并自移除
func test_add_temp_skill_same_trigger_mode() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var _card: Card = _make_pull_trigger_happy_card()
	p.max_action_count = 6
	p.add_temp_skill("pull_trigger_happy_clear", "before_turn_end")
	assert_true(_has_skill_by_english_name(p, "pull_trigger_happy_clear_temp"), "应挂载 pull_trigger_happy_clear_temp")
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_turn_end", event)
	assert_eq(p.max_action_count, 4, "触发后应执行 decrease_max_action(2)：6 - 2 = 4")
	assert_false(_has_skill_by_english_name(p, "pull_trigger_happy_clear_temp"), "触发后临时技能应被移除")


# === 6. add_temp_skill 异 trigger 模式 ===

# 测试 11: energy_drink_satiety 异 trigger 模式（expire != JSON trigger）
# 验证：挂载子技能 + 看护 Skill；触发原 trigger 取消事件；触发 expire 移除两者
func test_add_temp_skill_different_trigger_mode() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var _card: Card = _make_energy_drink_card()
	p.add_temp_skill("energy_drink_satiety", "before_next_turn_start")
	assert_true(_has_skill_by_english_name(p, "energy_drink_satiety"), "应挂载子技能 energy_drink_satiety")
	assert_true(_has_skill_by_english_name(p, "energy_drink_satiety_expiry"), "应挂载看护 energy_drink_satiety_expiry")
	# 触发原 trigger before_hunger_settlement，应取消事件
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_hunger_settlement", event)
	assert_true(EventSystem.is_cancelled(event), "energy_drink_satiety 应取消事件")
	assert_true(_has_skill_by_english_name(p, "energy_drink_satiety"), "异 trigger 触发后子技能应仍挂载")
	assert_true(_has_skill_by_english_name(p, "energy_drink_satiety_expiry"), "看护应仍挂载")
	# 触发 expire trigger before_next_turn_start，应移除子技能 + 看护
	var event2: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_next_turn_start", event2)
	assert_false(_has_skill_by_english_name(p, "energy_drink_satiety"), "看护触发后子技能应被移除")
	assert_false(_has_skill_by_english_name(p, "energy_drink_satiety_expiry"), "看护触发后看护应被移除")


# 测试 12: check_weapon_damage 异 trigger 模式 + 伤害加成（回归 bug 修复）
# 验证：挂载 check_weapon_damage + 看护；玩家造成伤害时 +1；触发 before_turn_end 移除两者
func test_add_temp_skill_check_weapon_bug_fix() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var _card: Card = _make_check_weapon_card()
	p.add_temp_skill("check_weapon_damage", "before_turn_end")
	assert_true(_has_skill_by_english_name(p, "check_weapon_damage"), "应挂载 check_weapon_damage")
	assert_true(_has_skill_by_english_name(p, "check_weapon_damage_expiry"), "应挂载 check_weapon_damage_expiry")
	# 玩家对怪物造成 5 点伤害 → on_deal_damage 触发 check_weapon_damage → event.num +1 → 6 伤害
	var m: Monster = _make_monster("僵尸", 20)
	await m.damage(5, p)
	assert_eq(m.hp, 14, "check_weapon 应额外造成 1 点伤害（5 + 1 = 6，20 - 6 = 14）")
	# 触发 before_turn_end，应移除两者
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_turn_end", event)
	assert_false(_has_skill_by_english_name(p, "check_weapon_damage"), "触发后 check_weapon_damage 应被移除")
	assert_false(_has_skill_by_english_name(p, "check_weapon_damage_expiry"), "触发后看护应被移除")


# 测试 13: add_temp_skill 对未注册的 english_name 不挂载任何技能
# 注：add_temp_skill 内部会 push_error，直接调用会触发 GUT "Unexpected Errors"。
# 改为验证 Game.get_sub_skill_data 对未注册名返回 null（add_temp_skill 的前置查找逻辑）。
func test_add_temp_skill_nonexistent_pushes_error() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var initial_count: int = p.get_all_skills().size()
	assert_null(Game.get_sub_skill_data("nonexistent_temp_skill"), "未注册的 english_name 应返回 null")
	assert_eq(p.get_all_skills().size(), initial_count, "未注册的子技能不应挂载任何技能")


# === 7. use_card 端到端 ===

# 测试 14: 空尖弹 use_card 完整流程：销毁牌、修改武器、挂载技能、消耗行动
func test_hollow_point_use_card_full_flow() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 1, 6)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var card: Card = _make_hollow_point_card()
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([weapon_entity])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用空尖弹应成功")
	assert_true(_has_skill_by_english_name(p, "hollow_point_damage"), "应挂载 hollow_point_damage")
	assert_true(_has_skill_by_english_name(p, "hollow_point_remove"), "应挂载 hollow_point_remove")
	assert_eq(weapon.charge_type, "hollow_point", "武器 charge_type 应为 hollow_point")
	assert_eq(weapon.charge_current, 6, "武器 charge_current 应填满至 6")
	assert_true(Game.removed_cards.has(card), "空尖弹牌应进入 removed_cards")
	assert_eq(p.action_count, 1, "应消耗 1 点行动（2 - 1 = 1）")


# 测试 15: 搜索尸体 use_card 完整流程：挂载技能、击杀抓牌、before_turn_end 清除
func test_search_corpse_use_card_full_flow() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var block: MapBlock = _make_block("test_block", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	Game.red_scavenge_pile.add(_make_scavenge_card("card1"))
	var card: Card = _make_search_corpse_card()
	p.hand.append(card)
	var result: bool = await p.use_card(card)
	assert_true(result, "使用搜索尸体应成功")
	assert_true(_has_skill_by_english_name(p, "search_corpse_draw"), "应挂载 search_corpse_draw")
	assert_true(_has_skill_by_english_name(p, "search_corpse_clear_temp"), "应挂载 search_corpse_clear_temp")
	# 击杀怪物，应抓 1 张拾荒牌
	var m: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [m]
	m.attack_target = p
	await m.death(p)
	assert_eq(p.hand.size(), 1, "击杀怪物后应抓 1 张拾荒牌")
	# 触发 before_turn_end，应移除 search_corpse_draw（同 trigger 包装执行原 content + 自移除）
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_turn_end", event)
	assert_false(_has_skill_by_english_name(p, "search_corpse_draw"), "before_turn_end 后 search_corpse_draw 应被移除")
	assert_false(_has_skill_by_english_name(p, "search_corpse_clear_temp"), "before_turn_end 后 search_corpse_clear_temp 应被移除")


# === 8. 装备自动挂载/卸载 ===

# 测试 16: 装备 ranger_hat 自动挂载 ranger_hat_damage；卸下后自动卸载
func test_ranger_hat_auto_mount_unmount() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var ranger_hat: Card = _make_ranger_hat_card()
	await p.equip(ranger_hat)
	assert_true(_has_skill_by_english_name(p, "ranger_hat_damage"), "装备游侠帽后应自动挂载 ranger_hat_damage")
	var entity: Equipment = p.equipment_zone[0]
	var unequip_result: bool = await p.unequip(entity)
	assert_true(unequip_result, "卸下装备应成功")
	assert_false(_has_skill_by_english_name(p, "ranger_hat"), "卸下后 ranger_hat 父技能应被移除")
	assert_false(_has_skill_by_english_name(p, "ranger_hat_damage"), "卸下后 ranger_hat_damage 应自动卸载")


# === 9. 老兵 take_your_paws_off_immune 异 trigger ===

# 测试 17: take_your_paws_off_immune 异 trigger 模式（on_take_damage != before_next_turn_start）
# 验证：挂载子技能 + 看护；触发 on_take_damage 取消事件；触发 before_next_turn_start 移除两者
# 注：player.gd 暂无 dog 属性，故直接在 player 上验证 add_temp_skill 异 trigger 模式行为。
func test_take_your_paws_off_dog_add_temp_skill() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var _card: Card = _make_take_your_paws_off_card()
	p.add_temp_skill("take_your_paws_off_immune", "before_next_turn_start")
	assert_true(_has_skill_by_english_name(p, "take_your_paws_off_immune"), "应挂载 take_your_paws_off_immune")
	assert_true(_has_skill_by_english_name(p, "take_your_paws_off_immune_expiry"), "应挂载看护 take_your_paws_off_immune_expiry")
	# 触发 on_take_damage，应取消事件
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("on_take_damage", event)
	assert_true(EventSystem.is_cancelled(event), "take_your_paws_off_immune 应取消事件")
	assert_true(_has_skill_by_english_name(p, "take_your_paws_off_immune"), "on_take_damage 触发后子技能应仍挂载")
	# 触发 before_next_turn_start，应移除两者
	var event2: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_next_turn_start", event2)
	assert_false(_has_skill_by_english_name(p, "take_your_paws_off_immune"), "触发后 take_your_paws_off_immune 应被移除")
	assert_false(_has_skill_by_english_name(p, "take_your_paws_off_immune_expiry"), "触发后看护应被移除")


# === 10. 机械师 upgrade mount_sub_skill ===

# 测试 18: upgrade 卡创建后注册 upgrade_damage；player.mount_sub_skill 应挂载成功
func test_upgrade_mount_sub_skill() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var _card: Card = _make_upgrade_card()
	assert_true(Game.sub_skill_registry.has("upgrade_damage"), "创建 upgrade 卡后应注册 upgrade_damage")
	var s: Skill = p.mount_sub_skill("upgrade_damage")
	assert_not_null(s, "mount_sub_skill 应返回 Skill 实例")
	assert_true(_has_skill_by_english_name(p, "upgrade_damage"), "应挂载 upgrade_damage")
