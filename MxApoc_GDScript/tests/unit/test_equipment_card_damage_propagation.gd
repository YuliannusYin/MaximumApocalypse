extends GutTest

## 传入装备卡牌至伤害事件 Spec 测试。
## 覆盖：4 种模式的 card 参数传递、回归验证。
## 设计 spec：.trae/specs/propagate-equipment-card-to-damage/spec.md


# === 辅助方法 ===

func _make_player(hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = "测试玩家"
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


## 创建玩家并放置在 center 地块上，完成 Game 状态初始化。
func _setup_player_in_block() -> Player:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var center: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [center]
	p.current_block = center
	return p


## 从 survivor 数据中取出指定 english_name 的卡牌 content 字符串。
func _get_card_content(survivor_name: String, card_english_name: String) -> String:
	var sd: SurvivorData = DataManager.get_survivor(survivor_name)
	assert_not_null(sd, "应能加载 " + survivor_name + " survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == card_english_name:
			for raw in card_dict.get("skills", []):
				if raw is Dictionary:
					return raw.get("content", "")
	return ""


## 从 survivor 数据创建一张真实 EquipmentCard。
func _make_equipment_card_from_data(survivor_name: String, card_english_name: String) -> EquipmentCard:
	var sd: SurvivorData = DataManager.get_survivor(survivor_name)
	assert_not_null(sd, "应能加载 " + survivor_name + " survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == card_english_name:
			return Game._create_game_card_from_dict(card_dict)
	return null


## 创建一个 on_deal_damage 技能，当 event.card != null 时 +10 伤害。
## 用于检测 card 参数是否被正确传入。
func _make_card_detector_skill() -> Skill:
	var s := Skill.new()
	s.english_name = "test_card_detector"
	s.skill_name = "test_card_detector"
	s.trigger = "on_deal_damage"
	s.forced = true
	s.filter = func(_p, _t, _event, _g): return _event != null and _event.get("card", null) != null
	s.content = func(_p, _t, _event, _g): _event["num"] = _event.get("num", 0) + 10
	return s


# === 测试用例 ===

func test_pattern_a_crossbow_with_hollow_point() -> void:
	var p: Player = _setup_player_in_block()
	# 装备 crossbow
	var crossbow: EquipmentCard = _make_equipment_card_from_data("hunter", "crossbow")
	assert_not_null(crossbow, "应能创建 crossbow 装备牌")
	await p.equip(crossbow)
	var weapon_entity: Equipment = p.equipment_zone[0]
	# 装填空尖弹
	var hp_card: Card = Game._create_game_card_from_dict(
		DataManager.get_survivor("gunslinger").deck.filter(func(c): return c.get("english_name") == "hollow_point")[0])
	p.hand.append(hp_card)
	# 通过 SubSkill 机制挂载 hollow_point_damage + hollow_point_remove 并修改武器
	p.mount_sub_skill("hollow_point_damage")
	p.mount_sub_skill("hollow_point_remove")
	weapon_entity.change_charge_type("hollow_point")
	weapon_entity.fill_charge()
	await p.remove_card(hp_card)
	assert_eq(weapon_entity.charge_type, "hollow_point", "crossbow charge_type 应为 hollow_point")
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸步行者", 20)
	# 端到端执行 crossbow content
	var content: String = _get_card_content("hunter", "crossbow")
	var cb: Callable = CodeExecutor.compile_content(content)
	await cb.call(p, monster, {}, Game)
	# 3 base + 2 hollow_point = 5 damage, 20 - 5 = 15
	assert_eq(monster.hp, 15, "装填空尖弹的 crossbow 应造成 5 点伤害（3 + 2 = 5）")


func test_pattern_b_bow_passes_card_param() -> void:
	var p: Player = _setup_player_in_block()
	# 装备 bow
	var bow: EquipmentCard = _make_equipment_card_from_data("hunter", "bow")
	await p.equip(bow)
	# 添加 card_detector 技能（event.card != null 时 +10 伤害）
	p.add_skill(_make_card_detector_skill())
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸", 20)
	# 端到端执行 bow content
	var content: String = _get_card_content("hunter", "bow")
	var cb: Callable = CodeExecutor.compile_content(content)
	await cb.call(p, monster, {}, Game)
	# 2 base + 10 detector = 12 damage, 20 - 12 = 8
	assert_eq(monster.hp, 8, "bow 传入 card 参数后 card_detector 应 +10 伤害（2 + 10 = 12）")


func test_pattern_c_bear_trap_passes_card_param() -> void:
	var p: Player = _setup_player_in_block()
	# 装备 bear_trap
	var bear_trap: EquipmentCard = _make_equipment_card_from_data("hunter", "bear_trap")
	await p.equip(bear_trap)
	# 添加 card_detector 技能
	p.add_skill(_make_card_detector_skill())
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸", 20)
	# 端到端执行 bear_trap content
	var content: String = _get_card_content("hunter", "bear_trap")
	var cb: Callable = CodeExecutor.compile_content(content)
	await cb.call(p, monster, {}, Game)
	# 4 base + 10 detector = 14 damage, 20 - 14 = 6
	assert_eq(monster.hp, 6, "bear_trap 传入 card 参数后 card_detector 应 +10 伤害（4 + 10 = 14）")


func test_pattern_d_auto_turret_passes_card_param() -> void:
	var p: Player = _setup_player_in_block()
	# 装备 auto_turret
	var auto_turret: EquipmentCard = _make_equipment_card_from_data("mechanic", "auto_turret")
	await p.equip(auto_turret)
	# 添加 card_detector 技能
	p.add_skill(_make_card_detector_skill())
	# 创建怪物作为 event.source（攻击者）
	var attacker: Monster = _make_monster("攻击者", 20)
	# 端到端执行 auto_turret content（event 中包含 source）
	var content: String = _get_card_content("mechanic", "auto_turret")
	var cb: Callable = CodeExecutor.compile_content(content)
	var event: Dictionary = {"source": attacker, "trigger_name": "on_take_damage"}
	await cb.call(p, null, event, Game)
	# 4 base + 10 detector = 14 damage, 20 - 14 = 6
	assert_eq(attacker.hp, 6, "auto_turret 反击传入 card 参数后 card_detector 应 +10 伤害（4 + 10 = 14）")


func test_revolver_without_hollow_point_deals_3_damage() -> void:
	var p: Player = _setup_player_in_block()
	# 装备 revolver（初始弹药数为 1，这样第一发后弹药为 0，跳过 choose 交互）
	var revolver: EquipmentCard = _make_equipment_card_from_data("gunslinger", "revolver")
	revolver.charge_current = 1
	await p.equip(revolver)
	# 创建怪物目标
	var monster: Monster = _make_monster("僵尸", 20)
	# 端到端执行 revolver content
	var content: String = _get_card_content("gunslinger", "revolver")
	var cb: Callable = CodeExecutor.compile_content(content)
	await cb.call(p, monster, {}, Game)
	# 3 damage, 20 - 3 = 17
	assert_eq(monster.hp, 17, "普通弹药 revolver 应造成 3 点伤害")
