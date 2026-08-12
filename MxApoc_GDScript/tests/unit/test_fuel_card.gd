extends GutTest

## "燃料"拾荒卡行为单元测试。
## 覆盖：on_draw confirm 触发（装备/弃置）、"加油"主动技能（填充+弃燃料）、
## 多张燃料堆叠与 FIFO 弃置、无合法目标守卫。
## 数据来源：data/scavenge/red.json（燃料卡）
## 参考：tests/unit/test_use_card_scavenging.gd 与 tests/unit/test_active_skill.gd 的 fixture 模式


# === 辅助方法 ===

func _make_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = "TestPlayer"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
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


func _make_fuel_card() -> Card:
	return Game.create_scavenge_card("燃料")


func _make_fuel_generator(charge_current: int = 1, charge_max: int = 3) -> EquipmentCard:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.card_name = "发电机"
	ec.english_name = "generator"
	ec.card_type = "equipment"
	ec.card_subtype = "equipment"
	ec.source = "scavenge"
	ec.charge_type = "fuel"
	ec.charge_max = charge_max
	ec.charge_current = charge_current
	return ec


## 在玩家技能列表中查找"加油"主动技能。
func _find_refuel_skill(p: Player) -> Skill:
	for s in p.skills:
		if s.skill_name == "加油" and s.active == "action":
			return s
	return null


# === 一、on_draw confirm 触发 ===

# 抓到"燃料"确认装备 → 进入装备区，不在手牌
func test_fuel_draw_confirm_equips() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var cli: CliPlayerInput = CliPlayerInput.new()
	p.input = cli
	var card: Card = _make_fuel_card()
	Game.red_scavenge_pile.add(card)
	cli.queue_confirm(true)
	await p.draw_scavenge(1, Game.red_scavenge_pile)
	assert_eq(p.equipment_zone.size(), 1, "确认装备后装备区应有 1 个实体")
	var entity: Equipment = p.get_equipment("燃料")
	assert_not_null(entity, "装备区应有燃料实体")
	assert_eq(entity.card_name, "燃料", "装备实体卡名应为燃料")
	assert_eq(p.hand.size(), 0, "燃料不应留在手牌")


# 抓到"燃料"确认弃置 → 进入拾荒弃牌堆，不在手牌也不在装备区
func test_fuel_draw_confirm_discards() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var cli: CliPlayerInput = CliPlayerInput.new()
	p.input = cli
	var card: Card = _make_fuel_card()
	Game.red_scavenge_pile.add(card)
	cli.queue_confirm(false)
	await p.draw_scavenge(1, Game.red_scavenge_pile)
	assert_eq(p.equipment_zone.size(), 0, "确认弃置后装备区应为空")
	assert_eq(p.hand.size(), 0, "燃料不应留在手牌")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "燃料应进入拾荒弃牌堆")
	var discarded: Card = Game.scavenge_discard_pile.get_all()[0]
	assert_eq(discarded.card_name, "燃料", "弃牌堆顶应为燃料")


# === 二、"加油"主动技能 ===

# "加油"填充目标燃料装备并弃置首张燃料
func test_refuel_fills_target_and_discards_fuel() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var cli: CliPlayerInput = CliPlayerInput.new()
	p.input = cli
	var fuel: Card = _make_fuel_card()
	Game.red_scavenge_pile.add(fuel)
	cli.queue_confirm(true)
	await p.draw_scavenge(1, Game.red_scavenge_pile)
	var gen: EquipmentCard = _make_fuel_generator(1, 3)
	await p.equip(gen)
	var refuel_skill: Skill = _find_refuel_skill(p)
	assert_not_null(refuel_skill, "装备燃料后应有加油技能")
	var gen_entity: Equipment = p.get_equipment("发电机")
	cli.queue_choose(gen_entity)
	await p.use_active_skill(refuel_skill)
	var gen_after: Equipment = p.get_equipment("发电机")
	assert_not_null(gen_after, "发电机应仍在装备区")
	assert_eq(gen_after.get_charge(), 3, "发电机应被填满到 3")
	assert_false(p.has_equipment("燃料"), "燃料应被弃置")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "燃料应进入拾荒弃牌堆")


# 多张"燃料"可同时存在于装备区
func test_multiple_fuel_stacking() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var fuel1: Card = _make_fuel_card()
	var fuel2: Card = _make_fuel_card()
	await p.equip(fuel1)
	await p.equip(fuel2)
	assert_eq(p.equipment_zone.size(), 2, "两张燃料都应进入装备区")
	var fuel_count: int = 0
	for e in p.equipment_zone:
		if e.english_name == "fuel":
			fuel_count += 1
	assert_eq(fuel_count, 2, "应有 2 个燃料实体")


# "加油"按 FIFO 弃置最先进入的燃料
func test_refuel_fifo_discards_first_fuel() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var fuel1: Card = _make_fuel_card()
	var fuel2: Card = _make_fuel_card()
	await p.equip(fuel1)
	await p.equip(fuel2)
	var gen: EquipmentCard = _make_fuel_generator(1, 3)
	await p.equip(gen)
	var refuel_skill: Skill = _find_refuel_skill(p)
	assert_not_null(refuel_skill, "装备燃料后应有加油技能")
	var cli: CliPlayerInput = CliPlayerInput.new()
	p.input = cli
	var gen_entity: Equipment = p.get_equipment("发电机")
	cli.queue_choose(gen_entity)
	await p.use_active_skill(refuel_skill)
	assert_eq(p.equipment_zone.size(), 2, "装备区应剩 2 个实体（发电机+1张燃料）")
	var remaining_fuel: Equipment = null
	for e in p.equipment_zone:
		if e.english_name == "fuel":
			remaining_fuel = e
			break
	assert_not_null(remaining_fuel, "应剩余 1 张燃料")
	assert_eq(remaining_fuel.equipment_card, fuel2, "应弃置先进入的 fuel1，保留 fuel2")


# "加油"无合法目标时不做任何操作
func test_refuel_no_valid_target_does_nothing() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var fuel: Card = _make_fuel_card()
	await p.equip(fuel)
	var refuel_skill: Skill = _find_refuel_skill(p)
	assert_not_null(refuel_skill, "装备燃料后应有加油技能")
	await p.use_active_skill(refuel_skill)
	assert_eq(p.equipment_zone.size(), 1, "无合法目标时燃料不应被弃置")
	assert_true(p.has_equipment("燃料"), "燃料应仍在装备区")
	assert_eq(Game.scavenge_discard_pile.size(), 0, "无目标时不应有牌进入弃牌堆")
