extends GutTest

## 任务引擎缺口修补单元测试（13 个任务新设计 Task 1）。
## 覆盖：card_discarded / monster_spawn_judged 事件转发（EventBus → mission_config.on_event）、
## no_initial_monster_draw 旗标（MissionData 解析 / initialize_game 传递 / start_game 跳过行为）、
## 首领卡下半区分布（_distribute_boss_cards_to_bottom_half 及 _init_global_piles 接线）。

# === 测试用内嵌组件 ===

# 记录型触发器组件：记录事件名与事件体。
class RecordingTriggerComponent extends MissionComponent:
	var events: Array = []
	var payloads: Array = []

	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		events.append(event_name)
		payloads.append(event)


# 恒真胜利组件：让 start_game 在第一回合结束后立即胜利退出（参考 test_integration_turn_flow）。
class AlwaysWinComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return true


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_deck_player(name: String = "A") -> Player:
	# 带 5 张游戏牌的玩家，避免 start_turn 摸牌阶段空牌堆死亡
	var p: Player = _make_player(name)
	for i in 5:
		var c: Card = Card.new()
		c.card_name = "card_" + str(i)
		c.card_type = "action"
		c.source = "game"
		p.game_deck.add(c)
	return p


func _make_monster_card(name: String = "test_monster", level: String = "normal") -> MonsterCard:
	var c: MonsterCard = MonsterCard.new()
	c.card_name = name
	c.card_type = "monster"
	c.source = "monster"
	c.monster_type = "zombie"
	c.monster_level = level
	c.max_hp = 3
	c.damage_value = 2
	c.range = "none"
	return c


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


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 1. EventBus 事件转发 ===

func test_event_forwarding_card_discarded() -> void:
	var trigger := RecordingTriggerComponent.new()
	var mc: MissionConfig = MissionConfig.new()
	mc.trigger_components.append(trigger)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	var card: Card = Card.new()
	card.card_name = "C"
	EventBus.card_discarded.emit(p, card)
	assert_eq(trigger.events, ["card_discarded"], "触发器应收到 card_discarded 事件")
	assert_eq(trigger.payloads[0].get("player"), p, "事件体应包含玩家")
	assert_eq(trigger.payloads[0].get("card"), card, "事件体应包含卡牌")


func test_event_forwarding_monster_spawn_judged() -> void:
	var trigger := RecordingTriggerComponent.new()
	var mc: MissionConfig = MissionConfig.new()
	mc.trigger_components.append(trigger)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	EventBus.monster_spawn_judged.emit(p, 7)
	assert_eq(trigger.events, ["monster_spawn_judged"], "触发器应收到 monster_spawn_judged 事件")
	assert_eq(trigger.payloads[0].get("player"), p, "事件体应包含玩家")
	assert_eq(trigger.payloads[0].get("value"), 7, "事件体应包含投骰点数 7")


# === 2. no_initial_monster_draw 旗标 ===

func test_mission_data_no_initial_monster_draw_default_false() -> void:
	var mission: MissionData = MissionData.new({})
	assert_false(mission.no_initial_monster_draw, "默认应不跳过初始怪物抽牌")


func test_mission_data_no_initial_monster_draw_parsed_from_json() -> void:
	var mission: MissionData = MissionData.new({"no_initial_monster_draw": true})
	assert_true(mission.no_initial_monster_draw, "应从 JSON 数据解析 no_initial_monster_draw=true")


func test_mission_config_no_initial_monster_draw_default_false() -> void:
	var mc: MissionConfig = MissionConfig.new()
	assert_false(mc.no_initial_monster_draw, "MissionConfig 默认应不跳过初始怪物抽牌")


func test_initialize_game_passes_no_initial_monster_draw() -> void:
	# 用最小 MissionData（仅怪物包类型 + 旗标）走 initialize_game，验证旗标传递到 mission_config。
	# 不复用 DataManager.get_mission() 的缓存实例，避免修改污染其他测试。
	var mission: MissionData = MissionData.new({
		"monster_pack_type": "zombie",
		"no_initial_monster_draw": true,
	})
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.mission_config, "应创建任务配置")
	assert_true(Game.mission_config.no_initial_monster_draw, "initialize_game 应把 no_initial_monster_draw 传递到 mission_config")


func test_start_game_skips_initial_monster_draw_when_flag_set() -> void:
	# 轻量验证 start_game 跳过逻辑：恒真胜利组件让流程在第一回合后立即结束
	# （CliPlayerInput 默认不阻塞，参考 test_integration_turn_flow 的同类模式）。
	var p: Player = _make_deck_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("z1"))
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.no_initial_monster_draw = true
	mc.win_condition_components.append(AlwaysWinComponent.new())
	Game.mission_config = mc
	await Game.state_machine.start_game()
	assert_eq(p.monster_zone.size(), 0, "no_initial_monster_draw=true 时开局不应抓初始怪物卡")
	assert_eq(Game.monster_pile.size(), 1, "怪物牌堆中的卡不应被抽取")


func test_start_game_draws_initial_monster_when_flag_false() -> void:
	var p: Player = _make_deck_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("z1"))
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.no_initial_monster_draw = false
	mc.win_condition_components.append(AlwaysWinComponent.new())
	Game.mission_config = mc
	await Game.state_machine.start_game()
	assert_eq(p.monster_zone.size(), 1, "旗标为 false 时开局应照常抓 1 张初始怪物卡")


# === 3. 首领卡分布 ===

func test_distribute_boss_cards_single_boss_to_bottom_half() -> void:
	# 8 张非首领卡（偶数）+ 1 张首领卡：首领卡索引必 >= floor(9/2)=4，确定性成立
	Game.monster_pile = Pile.new()
	for i in 8:
		Game.monster_pile.add(_make_monster_card("m" + str(i), "normal"))
	var boss: MonsterCard = _make_monster_card("boss1", "boss")
	Game.monster_pile.add(boss)
	Game._distribute_boss_cards_to_bottom_half()
	assert_eq(Game.monster_pile.size(), 9, "分布后牌堆张数应不变")
	var boss_index: int = Game.monster_pile.cards.find(boss)
	assert_true(boss_index >= Game.monster_pile.size() / 2, "首领卡应位于牌堆下半区（>= 4），实际 " + str(boss_index))


func test_distribute_boss_cards_multiple_boss() -> void:
	# 10 张非首领卡 + 2 张首领卡：算法保证所有首领卡索引 >= floor(10/2)=5
	Game.monster_pile = Pile.new()
	var non_boss_count: int = 10
	for i in non_boss_count:
		Game.monster_pile.add(_make_monster_card("m" + str(i), "normal"))
	var boss1: MonsterCard = _make_monster_card("boss1", "boss")
	var boss2: MonsterCard = _make_monster_card("boss2", "boss")
	Game.monster_pile.add(boss1)
	Game.monster_pile.add(boss2)
	Game._distribute_boss_cards_to_bottom_half()
	assert_eq(Game.monster_pile.size(), 12, "分布后牌堆张数应不变")
	var half: int = non_boss_count / 2
	for card in Game.monster_pile.cards:
		if card.monster_level == "boss":
			var idx: int = Game.monster_pile.cards.find(card)
			assert_true(idx >= half, "首领卡应位于下半区（>= " + str(half) + "），实际 " + str(idx))


func test_distribute_boss_cards_no_boss_unchanged() -> void:
	Game.monster_pile = Pile.new()
	var cards: Array = []
	for i in 4:
		var c: MonsterCard = _make_monster_card("m" + str(i), "normal")
		cards.append(c)
		Game.monster_pile.add(c)
	Game._distribute_boss_cards_to_bottom_half()
	assert_eq(Game.monster_pile.size(), 4, "牌堆张数应不变")
	for i in cards.size():
		assert_eq(Game.monster_pile.cards[i], cards[i], "无首领卡时牌堆顺序应完全不变（位置 " + str(i) + "）")


func test_distribute_boss_cards_all_boss_degenerate() -> void:
	# 退化场景：全部为首领卡（非首领卡 0 张）时插入位置为顶部，仅验证不崩溃且张数不变
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	Game.monster_pile.add(_make_monster_card("boss2", "boss"))
	Game._distribute_boss_cards_to_bottom_half()
	assert_eq(Game.monster_pile.size(), 2, "退化场景牌堆张数应不变")


func test_distribute_boss_cards_empty_pile_no_error() -> void:
	Game.monster_pile = Pile.new()
	Game._distribute_boss_cards_to_bottom_half()
	assert_eq(Game.monster_pile.size(), 0, "空牌堆应安全返回")


func test_initialize_game_distributes_boss_cards_in_monster_pile() -> void:
	# 验证 _init_global_piles 接线：真实僵尸包含 2 张首领卡，初始化后应全部位于下半区
	var mission: MissionData = MissionData.new({"monster_pack_type": "zombie"})
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.monster_pile, "应有怪物牌堆")
	var boss_cards: Array = []
	var non_boss_count: int = 0
	for card in Game.monster_pile.cards:
		if card.monster_level == "boss":
			boss_cards.append(card)
		else:
			non_boss_count += 1
	assert_eq(boss_cards.size(), 2, "僵尸包应含 2 张首领卡")
	var half: int = non_boss_count / 2
	for boss in boss_cards:
		var idx: int = Game.monster_pile.cards.find(boss)
		assert_true(idx >= half, "首领卡应位于怪物牌堆下半区（>= " + str(half) + "），实际 " + str(idx))


# === 4. setup_components 时序（玩家/地图/牌堆就绪后调用） ===

func test_initialize_game_setup_equip_card_equips_first_player() -> void:
	# setup_components 在 _init_global_piles 之后调用：带 setup_equip_card trigger 的
	# 最小任务数据走 initialize_game，第一个玩家装备区应出现"科学家"卡。
	# equip 为协程（setup_equip_card fire-and-forget 调用），轮询等待装备完成。
	var mission: MissionData = MissionData.new({
		"monster_pack_type": "zombie",
		"triggers": [{"component": "setup_equip_card", "params": {"card_name": "科学家"}}],
	})
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.mission_config, "应创建任务配置")
	assert_eq(Game.mission_config.trigger_components.size(), 1, "应挂载 setup_equip_card 触发器")
	assert_false(Game.players.is_empty(), "应已创建玩家")
	var player: Player = Game.players[0]
	# equip 协程推进：等待若干帧（超时循环兜底）
	var waited_frames: int = 0
	while not player.has_equipment("科学家") and waited_frames < 50:
		await Engine.get_main_loop().process_frame
		waited_frames += 1
	assert_true(player.has_equipment("科学家"), "setup_components 时序修复后，第一个玩家装备区应出现'科学家'卡")
