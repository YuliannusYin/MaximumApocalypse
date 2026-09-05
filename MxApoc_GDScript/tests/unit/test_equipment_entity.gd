extends TestBase

## Equipment 实体化回归测试。
## 覆盖装备牌实体化新契约：装备区持有 Equipment 实体（非卡），来源卡通过 equipment_card 回引，
## charge_current 委托来源卡；实体化时填充物补满并还原卡面类型。
## 弃置/卸下时来源卡入弃牌堆。
## 并直接回归「弹药 filter_target 在 Equipment 上访问 in_equipment_area」的崩溃点。
## 设计文档：GameDesignDocus/GameSystem/Entities/Equipment.md
##
## GUI 全链路回归说明：本项目无 GameScene2D 测试 harness（tests/unit/test_gui_player_input.gd
## 仅在隔离环境测试 GUIPlayerInput 信号机制，未实例化 GameScene2D）。搭建 GameScene2D harness
## 成本高且需引入大量 UI 基础设施，故跳过 _on_choose_target_requested 的全链路测试。
## 下方 test_ammo_filter_target_on_equipment_entity_no_crash 已直接覆盖崩溃语义
## （filter_target 字符串在 Equipment 实体上访问 in_equipment_area / charge_current / charge_max），
## 配合 test_use_ammo_small_adds_charge（CliPlayerInput + 实体 target）覆盖 content 路径。


# === 辅助方法 ===

func _make_combat_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.hp = hp
	p.max_hp = max_hp
	p.player_name = "TestPlayer"
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
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
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


## 从 DataManager 拾荒牌堆中按卡名取首个技能的 SkillData（用于获取原始 filter_target 字符串）。
func _get_scavenge_skill_data(card_name: String) -> SkillData:
	for color in ["red", "green", "blue", "gray"]:
		for card_data in DataManager.get_scavenge_pile(color):
			if card_data.card_name == card_name:
				if card_data.skills.size() > 0:
					return card_data.skills[0]
				return null
	return null


# === 1. 实体化单元 ===

func test_instantiate_returns_equipment_with_identity() -> void:
	var card: EquipmentCard = _make_equipment("test_weapon")
	card.english_name = "test_weapon_en"
	card.range = "medium"
	var s: Skill = Skill.new()
	s.skill_name = "weapon_skill"
	card.add_skill(s)
	var entity: Equipment = card.instantiate(null)
	assert_not_null(entity)
	assert_true(entity is Equipment, "instantiate 应返回 Equipment 实例")
	# 身份字段与来源卡一致
	assert_eq(entity.card_name, card.card_name, "card_name 应一致")
	assert_eq(entity.english_name, card.english_name, "english_name 应一致")
	assert_eq(entity.card_type, card.card_type, "card_type 应一致")
	assert_eq(entity.source, card.source, "source 应一致")
	assert_eq(entity.size, card.size, "size 应一致")
	assert_eq(entity.range, card.range, "range 应一致")
	assert_eq(entity.charge_type, card.charge_type, "charge_type 应一致")
	assert_eq(entity.charge_max, card.charge_max, "charge_max 应一致")
	# equipment_card 回引
	assert_eq(entity.equipment_card, card, "equipment_card 应回引来源卡")
	# in_equipment_area 标记
	assert_true(entity.in_equipment_area, "实体化后 in_equipment_area 应为 true")
	# 技能已挂载（数量与来源卡一致）
	assert_eq(entity.get_all_skills().size(), card.get_all_skills().size(), "技能数应一致")


func test_instantiate_resets_charge_type_to_printed() -> void:
	var card: EquipmentCard = _make_equipment("colt")
	card.charge_max = 4
	card.charge_current = 1
	card.change_charge_type("hollow_point")
	assert_eq(card.charge_type, "hollow_point")
	var entity: Equipment = card.instantiate(null)
	assert_eq(card.charge_type, "ammo", "实体化应还原卡面填充物类型")
	assert_eq(entity.charge_type, "ammo", "装备实体应为卡面填充物类型")
	assert_eq(card.charge_current, 4, "实体化应将填充物补满到上限")
	assert_eq(entity.charge_current, 4)


# === 2. charge_current 委托来源卡 ===

func test_charge_current_delegates_to_source_card() -> void:
	var card: EquipmentCard = _make_equipment("ammo_weapon")
	card.charge_max = 4
	card.charge_current = 3
	var entity: Equipment = card.instantiate(null)
	assert_eq(entity.charge_current, 4, "实体化进入装备区应将填充物补满到上限")
	assert_eq(card.charge_current, 4, "来源卡应同步为满填充")
	# add_charge 不超过 max，且写回来源卡
	entity.add_charge(2, "ammo")
	assert_eq(entity.charge_current, 4, "add_charge(2) 后不超过 max（4）")
	assert_eq(card.charge_current, 4, "add_charge 应委托写回来源卡（4）")
	# consume_charge 写回来源卡
	entity.consume_charge(1)
	assert_eq(entity.charge_current, 3, "consume_charge(1) 后实体 charge_current 应为 3")
	assert_eq(card.charge_current, 3, "consume_charge(1) 后来源卡 charge_current 应为 3")


# === 3. 装备入区 ===

func test_equip_puts_entity_in_zone() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	var card: EquipmentCard = _make_equipment("weapon")
	await p.equip(card)
	assert_eq(p.equipment_zone.size(), 1, "装备区应有 1 个实体")
	assert_true(p.equipment_zone[0] is Equipment, "装备区应持有 Equipment 实体")
	assert_eq(p.equipment_zone[0].equipment_card, card, "实体 equipment_card 应回引来源卡")
	assert_false(p.equipment_zone.has(card), "来源卡不应在装备区（实体在）")


# === 4. 卸下/弃置来源卡入弃牌堆（重装时填充物重置） ===

func test_discard_scavenge_equipment_sends_source_to_scavenge_pile_with_charge() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	# scavenge 武器：弃置后来源卡进 scavenge_discard_pile
	var weapon: EquipmentCard = _make_equipment("shotgun")
	weapon.source = "scavenge"
	weapon.charge_max = 4
	weapon.charge_current = 4
	await p.equip(weapon)
	var entity: Equipment = p.get_equipment("shotgun")
	assert_not_null(entity, "装备区应有实体")
	# 先消耗 2 点 charge，再弃置，验证 charge 保留
	var ok: bool = await p.consume_charge(entity, 2)
	assert_true(ok, "消耗填充物应成功")
	assert_eq(weapon.charge_current, 2, "消耗后来源卡 charge_current 应为 2")
	await p.discard(entity)
	assert_false(p.has_equipment("shotgun"), "弃置后装备区应无实体")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "scavenge 来源卡应进拾荒弃牌堆")
	assert_eq(Game.scavenge_discard_pile.get_all()[0], weapon, "弃牌堆应为来源卡")
	assert_eq(weapon.charge_current, 2, "弃置后来源卡 charge 暂为 2（重装时再重置）")
	await p.equip(weapon)
	assert_eq(weapon.charge_current, 4, "再次装备应把填充物补满到上限")
	assert_eq(weapon.charge_type, "ammo", "再次装备应还原卡面填充物类型")


func test_discard_game_equipment_sends_source_to_game_pile() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	# game 来源装备：弃置后来源卡进 game_discard_pile
	var weapon: EquipmentCard = _make_equipment("game_weapon")  # source = "game"
	await p.equip(weapon)
	var entity: Equipment = p.get_equipment("game_weapon")
	assert_not_null(entity)
	await p.discard(entity)
	assert_false(p.has_equipment("game_weapon"), "弃置后装备区应无实体")
	assert_eq(p.game_discard_pile.size(), 1, "game 来源卡应进游戏弃牌堆")
	assert_eq(p.game_discard_pile.get_all()[0], weapon, "弃牌堆应为来源卡")


# === 5. 崩溃直接回归：filter_target 在 Equipment 上访问 in_equipment_area ===

func test_ammo_filter_target_on_equipment_entity_no_crash() -> void:
	# 加载「弹药（少量）」拾荒卡，取其 active 技能的 filter_target 字符串
	var sd: SkillData = _get_scavenge_skill_data("弹药（少量）")
	assert_not_null(sd, "应找到弹药（少量）技能数据")
	var filter_code: String = sd.filter_target
	assert_false(filter_code.is_empty(), "filter_target 字符串不应为空")
	# 编译 filter_target（直接覆盖原崩溃点：filter_target 在 Equipment 上访问 in_equipment_area）
	var filter_callable: Callable = CodeExecutor.compile_filter_target(filter_code)
	assert_true(filter_callable.is_valid(), "filter_target 应编译为有效 Callable")
	# 构造手枪 Equipment 实体：charge_current=3, charge_max=4, charge_type="ammo"
	var pistol: EquipmentCard = Game.create_scavenge_card("手枪") as EquipmentCard
	assert_not_null(pistol, "应能创建手枪卡")
	pistol.charge_current = 3
	var entity: Equipment = pistol.instantiate(null)
	pistol.charge_current = 3
	var p: Player = _make_combat_player()
	var event: Dictionary = {"player": p, "target": entity, "card": null}
	# 未满 → 返回 true，不崩溃
	var ok: bool = filter_callable.call(p, entity, event, Game)
	assert_true(ok, "charge_current(3) < charge_max(4) 时 filter_target 应返回 true")
	# 已满 → 返回 false
	pistol.charge_current = 4
	var ok2: bool = filter_callable.call(p, entity, event, Game)
	assert_false(ok2, "charge_current(4) == charge_max(4) 时 filter_target 应返回 false")


# === 6. 数据断言：5 个弹药技能 target_type == "equipment" ===

func test_ammo_skills_target_type_equipment() -> void:
	var expected: Array = ["ammo_small", "ammo_half_box", "ammo_full", "ammo_large", "ammo_full_box"]
	for ename in expected:
		var found: SkillData = null
		for card_data in DataManager.get_scavenge_pile("blue"):
			for s in card_data.skills:
				if s.english_name == ename:
					found = s
					break
			if found != null:
				break
		assert_not_null(found, "应在蓝色拾荒包中找到技能: " + ename)
		assert_eq(found.target_type, "equipment", ename + " 的 target_type 应为 equipment")


# === 7. 自制子弹 filter_target：空 charge_type 不应入选 ===

func test_homemade_bullets_filter_excludes_empty_charge_type() -> void:
	var survivor: SurvivorData = DataManager.get_survivor("mechanic")
	assert_not_null(survivor, "应能加载机械师数据")
	var filter_code: String = ""
	for card_dict in survivor.deck:
		if str(card_dict.get("english_name", "")) == "homemade_bullets":
			var skills: Array = card_dict.get("skills", [])
			if skills.size() > 0:
				filter_code = str(skills[0].get("filter_target", ""))
			break
	assert_false(filter_code.is_empty(), "自制子弹 filter_target 不应为空")
	var filter_callable: Callable = CodeExecutor.compile_filter_target(filter_code)
	assert_true(filter_callable.is_valid(), "filter_target 应编译为有效 Callable")
	var p: Player = _make_combat_player()
	var event: Dictionary = {"player": p, "target": null, "card": null}

	var helmet_card: EquipmentCard = EquipmentCard.new()
	helmet_card.card_name = "welding_helmet"
	helmet_card.english_name = "welding_helmet"
	helmet_card.card_type = "equipment"
	helmet_card.card_subtype = "equipment"
	helmet_card.source = "game"
	var helmet: Equipment = helmet_card.instantiate(null)
	assert_eq(helmet.charge_type, "", "焊接头盔 charge_type 应为空字符串")
	assert_false(filter_callable.call(p, helmet, event, Game), "无填充物的焊接头盔不应被自制子弹选中")

	var torch_card: EquipmentCard = _make_equipment("blowtorch")
	torch_card.charge_type = "fuel"
	var torch: Equipment = torch_card.instantiate(null)
	assert_true(filter_callable.call(p, torch, event, Game), "有燃料的喷灯应被自制子弹选中")


func test_instantiate_copies_weapon_and_equipped_player() -> void:
	var p: Player = _make_combat_player()
	var card: EquipmentCard = _make_equipment("wrench")
	card.weapon = true
	var entity: Equipment = card.instantiate(p)
	assert_true(entity.weapon, "实体化应复制 weapon")
	assert_true(entity.is_weapon_card(), "weapon=true 的实体应是武器")
	assert_eq(entity.equipped_player, p, "实体化应记下 equipped_player")


func test_unequip_clears_equipped_player() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	var card: EquipmentCard = _make_equipment("wrench")
	card.weapon = true
	await p.equip(card)
	var entity: Equipment = p.get_equipment("wrench")
	assert_eq(entity.equipped_player, p, "装备后 equipped_player 应为持有者")
	await p.unequip(entity)
	assert_null(entity.equipped_player, "卸下后 equipped_player 应清空")


func test_get_equipment_candidates_empty_range_is_own_zone() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	var card: EquipmentCard = _make_equipment("wrench")
	await p.equip(card)
	var own: Array = p.get_equipment_candidates("")
	assert_eq(own.size(), 1, "空射程应只返回自己的装备区")
	assert_eq(own[0], p.equipment_zone[0])
	var fallback: Array = p.get_equipment_candidates("medium")
	assert_eq(fallback.size(), 1, "无当前地块时声明射程应回退到自己的装备区")
