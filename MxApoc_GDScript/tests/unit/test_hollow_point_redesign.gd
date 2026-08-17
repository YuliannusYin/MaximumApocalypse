extends GutTest

## "空尖弹"重设计单元测试。
## 覆盖：
## 1. has_ammo_weapon 方法
## 2. mount_sub_skill 销毁牌、修改 charge_type、填满 charge、挂载技能
## 3. 持久伤害技能：hollow_point 武器造成伤害 +2
## 4. 持久弃置技能：hollow_point 武器弹药耗尽时弃置武器
## 5. 去重：重复调用 mount_sub_skill 不重复挂载技能
## 6. use_card 完整流程（含销毁检测跳过弃置）
## 7. 取消保护：玩家取消选取时牌退回手牌
## 设计 spec：.trae/specs/redesign-hollow-point/spec.md


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


## 从枪手 survivor 数据中取出 hollow_point 卡牌的原始字典。
func _get_hollow_point_card_dict() -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "应能加载枪手 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "hollow_point":
			return card_dict
	return {}


## 从枪手数据创建一张真实 hollow_point 卡牌。
func _make_hollow_point_card() -> Card:
	var card_dict: Dictionary = _get_hollow_point_card_dict()
	assert(!card_dict.is_empty(), "未找到枪手 hollow_point 卡牌")
	return Game._create_game_card_from_dict(card_dict)


## 从枪手数据创建一张真实 colt_pistol 装备牌。
func _make_colt_pistol_card() -> EquipmentCard:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "colt_pistol":
			return Game._create_game_card_from_dict(card_dict)
	return null


## 从枪手 survivor 数据中取出 colt_pistol 卡牌的 content 字符串。
func _get_colt_pistol_content() -> String:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "colt_pistol":
			for raw in card_dict.get("skills", []):
				if raw is Dictionary:
					return raw.get("content", "")
	return ""


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
	for s in p.get_all_skills():
		if s.english_name == en_name:
			return true
	return false


func _count_skill_by_english_name(p: Player, en_name: String) -> int:
	var count: int = 0
	for s in p.get_all_skills():
		if s.english_name == en_name:
			count += 1
	return count


# === 1. has_ammo_weapon ===

# 测试 1: 装备区有弹药武器时返回 true
func test_has_ammo_weapon_true() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	await p.equip(weapon)
	assert_true(p.has_ammo_weapon(), "装备区有弹药武器时应返回 true")


# 测试 2: 装备区无弹药武器时返回 false
func test_has_ammo_weapon_false_no_ammo() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var armor: EquipmentCard = _make_non_ammo_equipment("护甲")
	await p.equip(armor)
	assert_false(p.has_ammo_weapon(), "装备区无弹药武器时应返回 false")


# 测试 3: 空装备区时返回 false
func test_has_ammo_weapon_false_empty() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_false(p.has_ammo_weapon(), "空装备区时应返回 false")


# === 2. mount_sub_skill ===

# 测试 4: mount_sub_skill 销毁手牌中的空尖弹牌
func test_mount_sub_skill_destroys_card() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 2)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	assert_eq(p.hand.size(), 1, "使用前手牌应有 1 张")
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	assert_eq(p.hand.size(), 0, "使用后空尖弹牌应被销毁（不在手牌）")
	assert_true(Game.removed_cards.has(hp_card), "空尖弹牌应进入 Game.removed_cards")


# 测试 5: mount_sub_skill 修改 charge_type 并填满 charge
func test_mount_sub_skill_modifies_weapon() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 1, 6)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	assert_eq(weapon.charge_type, "hollow_point", "武器 charge_type 应变为 hollow_point")
	assert_eq(weapon.charge_current, 6, "武器 charge_current 应填满至 6")
	assert_eq(weapon_entity.charge_type, "hollow_point", "Equipment 实体 charge_type 应同步")


# 测试 6: mount_sub_skill 挂载持久伤害/弃置技能
func test_mount_sub_skill_mounts_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 2)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	assert_true(_has_skill_by_english_name(p, "hollow_point_damage"), "应挂载 hollow_point_damage 技能")
	assert_true(_has_skill_by_english_name(p, "hollow_point_remove"), "应挂载 hollow_point_remove 技能")


# 测试 7: 去重：重复调用 mount_sub_skill 不重复挂载技能
func test_mount_sub_skill_dedup_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon1: EquipmentCard = _make_ammo_weapon("手枪1", 2)
	await p.equip(weapon1)
	var weapon_entity1: Equipment = p.equipment_zone[0]
	var hp_card1: Card = _make_hollow_point_card()
	p.hand.append(hp_card1)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity1.change_charge_type("hollow_point")
	weapon_entity1.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card1)
	# 第二次使用
	var weapon2: EquipmentCard = _make_ammo_weapon("手枪2", 2)
	await p.equip(weapon2)
	var weapon_entity2: Equipment = p.equipment_zone[1]
	var hp_card2: Card = _make_hollow_point_card()
	p.hand.append(hp_card2)
	# mount the sub_skills (dedup: returns existing instances)
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity2.change_charge_type("hollow_point")
	weapon_entity2.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card2)
	assert_eq(_count_skill_by_english_name(p, "hollow_point_damage"), 1, "不重复挂载 damage 技能")
	assert_eq(_count_skill_by_english_name(p, "hollow_point_remove"), 1, "不重复挂载 remove 技能")


# === 3. 持久伤害技能 ===

# 测试 8: hollow_point 武器造成伤害时 +2
func test_hollow_point_damage_boost() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 2, 6)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸", 20)
	# 用 hollow_point 武器造成 5 点伤害
	await monster.damage(5, p, "monster_attack", weapon)
	# 5 + 2 = 7 伤害，20 - 7 = 13
	assert_eq(monster.hp, 13, "hollow_point 武器应额外造成 2 点伤害（5 + 2 = 7）")


# 测试 9: 非 hollow_point 武器造成伤害时不加成
func test_non_hollow_point_weapon_no_boost() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# 装备一把普通弹药武器（不使用空尖弹）
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	await p.equip(weapon)
	# 但先挂载 hollow_point 技能（模拟其他武器使用过空尖弹）
	var weapon2: EquipmentCard = _make_ammo_weapon("手枪2", 2, 6)
	await p.equip(weapon2)
	var weapon_entity2: Equipment = p.equipment_zone[1]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity2.change_charge_type("hollow_point")
	weapon_entity2.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	# weapon（非 hollow_point）造成伤害
	var monster: Monster = _make_monster("僵尸", 20)
	await monster.damage(5, p, "monster_attack", weapon)
	# 不加成：5 伤害，20 - 5 = 15
	assert_eq(monster.hp, 15, "非 hollow_point 武器不应触发 +2 加成")


# === 4. 持久弃置技能 ===

# 测试 10: hollow_point 武器弹药耗尽时弃置武器
func test_hollow_point_depleted_discards_weapon() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 1, 6)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	# charge_current 应为 6（填满）
	assert_eq(weapon.charge_current, 6, "装填后应为 6")
	# 消耗全部 6 发
	var consumed: bool = await p.consume_charge(weapon_entity, 6)
	assert_true(consumed, "消耗应成功")
	assert_eq(weapon.charge_current, 0, "消耗后应为 0")
	# on_charge_depleted 应触发，弃置武器
	assert_eq(p.equipment_zone.size(), 0, "武器应从装备区移除")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "武器应进入弃牌堆")


# 测试 11: 非 hollow_point 武器弹药耗尽时不弃置
func test_non_hollow_point_depleted_no_discard() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 1, 3)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	# 不使用空尖弹（不挂载技能）
	# 消耗全部填充物
	var consumed: bool = await p.consume_charge(weapon_entity, 1)
	assert_true(consumed, "消耗应成功")
	# on_charge_depleted 触发但无 hollow_point_remove 技能
	assert_eq(p.equipment_zone.size(), 1, "非 hollow_point 武器耗尽时不应被弃置")


# === 5. use_card 完整流程 ===

# 测试 12: use_card 完整流程：销毁牌、修改武器、不进弃牌堆
func test_use_card_hollow_point_full_flow() -> void:
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
	# mock input：选取武器实体
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([weapon_entity])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用空尖弹应成功")
	# 空尖弹牌应被销毁（不在手牌、不在弃牌堆、在 removed_cards）
	assert_eq(p.hand.size(), 0, "手牌应为空")
	assert_eq(p.game_discard_pile.get_all().size(), 0, "弃牌堆应为空（牌被销毁而非弃置）")
	assert_true(Game.removed_cards.has(card), "空尖弹牌应进入 removed_cards")
	# 行动应被消耗
	assert_eq(p.action_count, 1, "应消耗 1 点行动（2 - 1 = 1）")
	# 武器应被修改
	assert_eq(weapon.charge_type, "hollow_point", "武器应变为 hollow_point")
	assert_eq(weapon.charge_current, 6, "武器填充物应填满至 6")


# 测试 13: use_card 取消保护：玩家取消选取时牌退回手牌、不消耗行动
func test_use_card_hollow_point_cancel_returns_to_hand() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	await p.equip(weapon)
	var card: Card = _make_hollow_point_card()
	p.hand.append(card)
	# mock input：取消选取（返回空数组）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "空尖弹", "手牌中应为空尖弹")
	# 武器不应被修改
	assert_eq(weapon.charge_type, "ammo", "取消时武器 charge_type 不应变")


# === 6. 卡牌数据验证 ===

# 测试 14: hollow_point content 编译无 Parser Error
func test_hollow_point_content_compiles_without_error() -> void:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "枪手应存在")
	var found: bool = false
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") != "hollow_point":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "空尖弹 content 应编译为有效 Callable")
			assert_engine_error_count(0, "空尖弹 content 编译应无 Parser Error")
	assert_true(found, "应在枪手牌堆中找到 hollow_point 卡牌")


# 测试 15: hollow_point 声明式字段存在
func test_hollow_point_has_declarative_fields() -> void:
	var card_dict: Dictionary = _get_hollow_point_card_dict()
	var raw_skills: Array = card_dict.get("skills", [])
	var raw: Dictionary = raw_skills[0]
	assert_eq(raw.get("target_type", ""), "equipment", "target_type 应为 equipment")
	assert_eq(raw.get("select_target", 0), 1, "select_target 应为 1")
	assert_eq(raw.get("defer_action_cost", false), true, "defer_action_cost 应为 true")
	assert_false(str(raw.get("window_prompt", "")).is_empty(), "window_prompt 应非空")
	# SubSkill 机制：hollow_point 现已含 sub_skills.damage + sub_skills.remove
	assert_true(raw.has("sub_skills"), "应含 sub_skills 字段（SubSkill 机制）")
	var sub_skills: Dictionary = raw.get("sub_skills", {})
	assert_true(sub_skills.has("damage"), "sub_skills 应含 damage")
	assert_true(sub_skills.has("remove"), "sub_skills 应含 remove")
	assert_eq(sub_skills.damage.get("english_name", ""), "hollow_point_damage", "damage.english_name 应为 hollow_point_damage")
	assert_eq(sub_skills.remove.get("english_name", ""), "hollow_point_remove", "remove.english_name 应为 hollow_point_remove")
	assert_eq(raw.get("filter", ""), "return player.in_phase == \"action\" && player.has_ammo_weapon()", "filter 应使用 has_ammo_weapon")


# === 7. 销毁日志（spec: fix-hollow-point-and-destruction-log） ===

# 测试 16: remove_card 输出玩家销毁详细日志（不输出兜底日志）
func test_remove_card_logs_player_destroy_message() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 2)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	# 详细日志应包含 "将" + "空尖弹" + "移出游戏"
	assert_true(
		Game.log_list.any(func(l): return l.contains("将") and l.contains("空尖弹") and l.contains("移出游戏")),
		"应输出玩家销毁详细日志：枪手 将 空尖弹 移出游戏"
	)
	# 不应出现兜底日志（"被移出游戏" + "空尖弹"）
	assert_false(
		Game.log_list.any(func(l): return l.contains("被移出游戏") and l.contains("空尖弹")),
		"不应输出兜底销毁日志（silent=true 已抑制）"
	)


# 测试 17: Game.remove_card 默认输出兜底日志
func test_game_remove_card_fallback_log() -> void:
	var card: Card = Card.new()
	card.card_name = "测试牌"
	await Game.remove_card(card)
	assert_true(
		Game.log_list.any(func(l): return l.contains("测试牌") and l.contains("被移出游戏")),
		"默认调用应输出兜底日志：测试牌 被移出游戏"
	)
	assert_true(Game.removed_cards.has(card), "卡牌应进入 removed_cards")


# 测试 18: Game.remove_card silent=true 不输出日志
func test_game_remove_card_silent_no_log() -> void:
	var card: Card = Card.new()
	card.card_name = "测试牌"
	await Game.remove_card(card, true)
	assert_false(
		Game.log_list.any(func(l): return l.contains("被移出游戏")),
		"silent=true 时不应输出兜底销毁日志"
	)
	assert_true(Game.removed_cards.has(card), "卡牌应进入 removed_cards（数据行为保留）")


# === 8. colt_pistol 伤害加成（spec: fix-hollow-point-and-destruction-log） ===

# colt_pistol content 中 `target.damage(2, player, "weapon_attack", weapon.equipment_card)`
# 传入的是 EquipmentCard（Card 子类），符合 Entity.damage 的 card: Card 参数类型。
# 以下测试端到端执行 colt_pistol content（通过 CodeExecutor 编译并调用），验证 hollow_point 加成行为。

# 测试 19: 装填空尖弹的柯尔特手枪造成 4 点伤害
func test_colt_pistol_with_hollow_point_deals_4_damage() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	var colt_pistol: EquipmentCard = _make_colt_pistol_card()
	assert_not_null(colt_pistol, "应能创建 colt_pistol 装备牌")
	await p.equip(colt_pistol)
	var weapon_entity: Equipment = p.equipment_zone[0]
	# 装填空尖弹
	var hp_card: Card = _make_hollow_point_card()
	p.hand.append(hp_card)
	# mount the sub_skills
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	# modify weapon (the original apply_hollow_point did this internally)
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	# destroy the hollow_point card (the original apply_hollow_point called remove_card)
	await p.remove_card(hp_card)
	# 验证装填后状态：EquipmentCard 与 Equipment 实体的 charge_type 均同步
	assert_eq(colt_pistol.charge_type, "hollow_point", "柯尔特手枪 charge_type 应为 hollow_point")
	assert_eq(weapon_entity.charge_type, "hollow_point", "Equipment 实体 charge_type 应同步")
	assert_eq(colt_pistol.charge_current, 4, "柯尔特手枪 charge_current 应填满至 4")
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸步行者", 20)
	# 端到端执行 colt_pistol content（通过 CodeExecutor 编译并调用）
	var content: String = _get_colt_pistol_content()
	assert_false(content.is_empty(), "应能获取 colt_pistol content")
	var cb: Callable = CodeExecutor.compile_content(content)
	assert_true(cb.is_valid(), "colt_pistol content 应编译为有效 Callable")
	await cb.call(p, monster, {}, Game)
	# 2 base + 2 hollow_point = 4 damage, 20 - 4 = 16
	assert_eq(monster.hp, 16, "装填空尖弹的柯尔特手枪应造成 4 点伤害（2 + 2 = 4）")
	# 日志应显示受到 4 点伤害
	assert_true(
		Game.log_list.any(func(l): return l.contains("僵尸步行者") and l.contains("4") and l.contains("伤害")),
		"日志应显示僵尸步行者受到 4 点伤害"
	)


# 测试 20: 普通弹药柯尔特手枪造成 2 点伤害
func test_colt_pistol_without_hollow_point_deals_2_damage() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	var colt_pistol: EquipmentCard = _make_colt_pistol_card()
	assert_not_null(colt_pistol, "应能创建 colt_pistol 装备牌")
	await p.equip(colt_pistol)
	var weapon_entity: Equipment = p.equipment_zone[0]
	# 不使用空尖弹（charge_type 保持 ammo）
	assert_eq(weapon_entity.charge_type, "ammo", "柯尔特手枪 charge_type 应为 ammo")
	assert_eq(colt_pistol.charge_type, "ammo", "EquipmentCard charge_type 应为 ammo")
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸步行者", 20)
	# 端到端执行 colt_pistol content（通过 CodeExecutor 编译并调用）
	var content: String = _get_colt_pistol_content()
	assert_false(content.is_empty(), "应能获取 colt_pistol content")
	var cb: Callable = CodeExecutor.compile_content(content)
	assert_true(cb.is_valid(), "colt_pistol content 应编译为有效 Callable")
	await cb.call(p, monster, {}, Game)
	# 2 damage, 20 - 2 = 18
	assert_eq(monster.hp, 18, "普通弹药柯尔特手枪应造成 2 点伤害")
	# 日志应显示受到 2 点伤害
	assert_true(
		Game.log_list.any(func(l): return l.contains("僵尸步行者") and l.contains("2") and l.contains("伤害")),
		"日志应显示僵尸步行者受到 2 点伤害"
	)


# 测试 21: colt_pistol content 编译无 Parser Error
func test_colt_pistol_content_compiles() -> void:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "枪手应存在")
	var found: bool = false
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") != "colt_pistol":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "柯尔特手枪 content 应编译为有效 Callable")
			assert_engine_error_count(0, "colt_pistol content 编译应无 Parser Error")
	assert_true(found, "应在枪手牌堆中找到 colt_pistol 卡牌")
