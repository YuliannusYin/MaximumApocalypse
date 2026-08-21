extends GutTest

## 内置任务组件单元测试（三层架构第二层：5 个可复用组件）。
## 覆盖：collect_items / all_players_at_block / escort_equipment_at_block /
## spend_action_rescue / turn_countdown 的注册表映射、判定逻辑、
## 行动选项条件与执行、倒计时轮次推进。
## 注册表 reset() 会清除内置注册标记，create()/has() 懒注册会重新注册内置组件，
## 故测试中直接 create 即可，无需手动处理。


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


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
	MissionComponentRegistry.reset()
	_clear_game()


func after_each() -> void:
	MissionComponentRegistry.reset()
	_clear_game()


# === 0. 注册表内置映射 ===

func test_registry_builtin_components_registered() -> void:
	assert_true(MissionComponentRegistry.has("collect_items"), "collect_items 应已注册")
	assert_true(MissionComponentRegistry.has("all_players_at_block"), "all_players_at_block 应已注册")
	assert_true(MissionComponentRegistry.has("escort_equipment_at_block"), "escort_equipment_at_block 应已注册")
	assert_true(MissionComponentRegistry.has("spend_action_rescue"), "spend_action_rescue 应已注册")
	assert_true(MissionComponentRegistry.has("turn_countdown"), "turn_countdown 应已注册")
	assert_true(MissionComponentRegistry.create("collect_items") is MissionComponentCollectItems, "collect_items 应映射到正确类")
	assert_true(MissionComponentRegistry.create("all_players_at_block") is MissionComponentAllPlayersAtBlock, "all_players_at_block 应映射到正确类")
	assert_true(MissionComponentRegistry.create("escort_equipment_at_block") is MissionComponentEscortEquipmentAtBlock, "escort_equipment_at_block 应映射到正确类")
	assert_true(MissionComponentRegistry.create("spend_action_rescue") is MissionComponentSpendActionRescue, "spend_action_rescue 应映射到正确类")
	assert_true(MissionComponentRegistry.create("turn_countdown") is MissionComponentTurnCountdown, "turn_countdown 应映射到正确类")


# === 1. collect_items ===

func test_collect_items_insufficient() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("collect_items", {"items": {"燃料": 3, "弹药（少量）": 1}})
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.hand.append(_make_card("燃料"))
	p1.hand.append(_make_card("燃料"))
	p2.hand.append(_make_card("燃料"))
	Game.players = [p1, p2]
	assert_false(component.check_win(Game), "弹药数量不足应判定失败")


func test_collect_items_sufficient() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("collect_items", {"items": {"燃料": 3, "弹药（少量）": 1}})
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.hand.append(_make_card("燃料"))
	p1.hand.append(_make_card("燃料"))
	p2.hand.append(_make_card("燃料"))
	p2.hand.append(_make_card("弹药（少量）"))
	Game.players = [p1, p2]
	assert_true(component.check_win(Game), "每种卡名数量均达标应判定胜利")


func test_collect_items_equipment_zone_counts() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("collect_items", {"items": {"燃料": 2}})
	var p1: Player = _make_player("P1")
	p1.hand.append(_make_card("燃料"))
	p1.equipment_zone.append(_make_card("燃料", "equipment"))
	Game.players = [p1]
	assert_true(component.check_win(Game), "装备区中的卡应计入收集数量")


func test_collect_items_dead_player_excluded() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("collect_items", {"items": {"燃料": 1}})
	var p1: Player = _make_player("P1", 0)
	var p2: Player = _make_player("P2")
	p1.hand.append(_make_card("燃料"))
	Game.players = [p1, p2]
	assert_false(component.check_win(Game), "死亡玩家的卡不应计入收集数量")
	p2.hand.append(_make_card("燃料"))
	assert_true(component.check_win(Game), "存活玩家持有后应判定胜利")


# === 2. all_players_at_block ===

func test_all_players_at_block_all_present() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_players_at_block", {"block_name": "撤离点"})
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = _make_block("撤离点", 0, 0)
	p2.current_block = _make_block("撤离点", 1, 0)
	Game.players = [p1, p2]
	assert_true(component.check_win(Game), "全部存活玩家在指定地块应判定胜利")


func test_all_players_at_block_one_elsewhere() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_players_at_block", {"block_name": "撤离点"})
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = _make_block("撤离点", 0, 0)
	p2.current_block = _make_block("避难所", 1, 0)
	Game.players = [p1, p2]
	assert_false(component.check_win(Game), "有玩家不在指定地块应判定失败")


func test_all_players_at_block_missing_block() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_players_at_block", {"block_name": "撤离点"})
	var p1: Player = _make_player("P1")
	p1.current_block = _make_block("撤离点", 0, 0)
	var p2: Player = _make_player("P2")
	Game.players = [p1, p2]
	assert_false(component.check_win(Game), "玩家 current_block 为空应判定失败")


func test_all_players_at_block_no_alive_players() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("all_players_at_block", {"block_name": "撤离点"})
	var p1: Player = _make_player("P1", 0)
	Game.players = [p1]
	assert_false(component.check_win(Game), "无存活玩家应判定失败")


# === 3. escort_equipment_at_block ===

func _setup_escort(block_name: String = "撤离点") -> Dictionary:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("escort_equipment_at_block", {"block_name": block_name})
	mc.win_condition_components.append(component)
	mc.setup_components(Game)
	Game.mission_config = mc
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = _make_block(block_name, 0, 0)
	p2.current_block = _make_block("避难所", 1, 0)
	Game.players = [p1, p2]
	return {"mc": mc, "p1": p1, "p2": p2}


func test_escort_rescued_holder_at_block() -> void:
	var ctx: Dictionary = _setup_escort()
	var mc: MissionConfig = ctx["mc"]
	var p1: Player = ctx["p1"]
	mc.mission_state["scientist_rescued"] = true
	mc.mission_state["scientist_holder"] = p1
	assert_true(mc.check_win(Game), "已解救且持有者在目标地块应判定胜利")


func test_escort_holder_elsewhere() -> void:
	var ctx: Dictionary = _setup_escort()
	var mc: MissionConfig = ctx["mc"]
	var p2: Player = ctx["p2"]
	mc.mission_state["scientist_rescued"] = true
	mc.mission_state["scientist_holder"] = p2
	assert_false(mc.check_win(Game), "持有者不在目标地块应判定失败")


func test_escort_not_rescued() -> void:
	var ctx: Dictionary = _setup_escort()
	var mc: MissionConfig = ctx["mc"]
	var p1: Player = ctx["p1"]
	mc.mission_state["scientist_holder"] = p1
	assert_false(mc.check_win(Game), "未解救应判定失败")


func test_escort_holder_dead() -> void:
	var ctx: Dictionary = _setup_escort()
	var mc: MissionConfig = ctx["mc"]
	var p1: Player = ctx["p1"]
	p1.hp = 0
	mc.mission_state["scientist_rescued"] = true
	mc.mission_state["scientist_holder"] = p1
	assert_false(mc.check_win(Game), "持有者死亡应判定失败")


# === 4. spend_action_rescue ===

func _setup_rescue(params: Dictionary, action_count: int = 3) -> Dictionary:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("spend_action_rescue", params)
	component.setup(Game, mc)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	p.current_block = _make_block(params.get("block_name", "实验室"))
	p.action_count = action_count
	Game.players = [p]
	return {"mc": mc, "component": component, "p": p}


func test_rescue_option_available() -> void:
	var ctx: Dictionary = _setup_rescue({"block_name": "实验室"}, 2)
	var options: Array = ctx["component"].get_action_options(Game, ctx["p"])
	assert_eq(options.size(), 1, "地点正确且行动足够时应出现解救选项")
	assert_eq(options[0]["id"], "rescue_科学家", "选项 id 应为 rescue_ + 卡牌名")
	assert_eq(options[0]["label"], "花费 2 行动解救科学家", "选项 label 应包含消耗与卡牌名")
	assert_true(options[0]["execute"].is_valid(), "选项 execute 应为有效 Callable")


func test_rescue_option_wrong_block() -> void:
	var ctx: Dictionary = _setup_rescue({"block_name": "实验室"}, 2)
	var p: Player = ctx["p"]
	p.current_block = _make_block("避难所")
	assert_eq(ctx["component"].get_action_options(Game, p).size(), 0, "不在解救地点不应出现选项")


func test_rescue_option_insufficient_actions() -> void:
	var ctx: Dictionary = _setup_rescue({"block_name": "实验室"}, 1)
	assert_eq(ctx["component"].get_action_options(Game, ctx["p"]).size(), 0, "行动数不足不应出现选项")


func test_rescue_option_hidden_after_rescued() -> void:
	var ctx: Dictionary = _setup_rescue({"block_name": "实验室"}, 2)
	ctx["mc"].mission_state["scientist_rescued"] = true
	assert_eq(ctx["component"].get_action_options(Game, ctx["p"]).size(), 0, "已解救后不应再出现选项")


func test_rescue_execute_equips_and_consumes() -> void:
	var ctx: Dictionary = _setup_rescue({"block_name": "实验室"}, 3)
	var mc: MissionConfig = ctx["mc"]
	var component: MissionComponent = ctx["component"]
	var p: Player = ctx["p"]
	var options: Array = component.get_action_options(Game, p)
	assert_eq(options.size(), 1, "执行前应出现解救选项")
	var fn: Callable = options[0]["execute"]
	await fn.call()
	assert_eq(p.action_count, 1, "解救应扣减 2 点行动（3 → 1）")
	assert_true(p.has_equipment("科学家"), "科学家应装备到玩家装备区")
	assert_eq(mc.mission_state.get("scientist_rescued"), true, "rescued_key 应写入 true")
	assert_eq(mc.mission_state.get("scientist_holder"), p, "holder_key 应写入解救玩家")
	assert_eq(component.get_action_options(Game, p).size(), 0, "解救后选项应消失")


func test_rescue_execute_card_not_found_no_cost() -> void:
	var ctx: Dictionary = _setup_rescue({"block_name": "实验室", "card_name": "不存在的卡", "cost": 1}, 2)
	var mc: MissionConfig = ctx["mc"]
	var p: Player = ctx["p"]
	var options: Array = ctx["component"].get_action_options(Game, p)
	assert_eq(options.size(), 1, "条件满足应出现解救选项")
	var fn: Callable = options[0]["execute"]
	await fn.call()
	assert_eq(p.action_count, 2, "拾荒卡不存在时不应消耗行动")
	assert_false(p.has_equipment("不存在的卡"), "不应装备任何卡")
	assert_ne(mc.mission_state.get("scientist_rescued", false), true, "不应标记为已解救")
	assert_true(Game.log_list.has("未找到拾荒卡：不存在的卡，无法解救"), "应输出未找到拾荒卡日志")


# === 5. turn_countdown ===

func test_countdown_setup_defaults() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("turn_countdown", {"rounds": 3})
	component.setup(Game, mc)
	assert_eq(mc.mission_state.get("countdown_active"), false, "缺省不激活")
	assert_eq(mc.mission_state.get("countdown_remaining"), 0, "缺省剩余为 0")
	assert_eq(mc.mission_state.get("countdown_expired"), false, "缺省未归零")
	assert_false(component.check_lose(Game), "未归零不应判定失败")


func test_countdown_auto_activate_and_progression() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("turn_countdown", {"rounds": 2, "auto_activate": true})
	component.setup(Game, mc)
	var p: Player = _make_player("P")
	Game.players = [p]
	assert_eq(mc.mission_state.get("countdown_active"), true, "auto_activate 时应立即激活")
	assert_eq(mc.mission_state.get("countdown_remaining"), 2, "激活后剩余应为 rounds")
	# 第 1 轮：首次 turn_started 仅记录轮数，不递减
	Game.state_machine.turn_number = 1
	component.on_event(Game, "turn_started", {"player": p})
	assert_eq(mc.mission_state.get("countdown_remaining"), 2, "首次 turn_started 不应递减")
	# 第 2 轮边界：递减到 1
	Game.state_machine.turn_number = 2
	component.on_event(Game, "turn_started", {"player": p})
	assert_eq(mc.mission_state.get("countdown_remaining"), 1, "轮次推进应递减剩余数")
	assert_eq(mc.mission_state.get("countdown_expired"), false, "未归零不应置 expired")
	assert_false(component.check_lose(Game), "未归零不应判定失败")
	# 第 3 轮边界：归零并置 expired
	Game.state_machine.turn_number = 3
	component.on_event(Game, "turn_started", {"player": p})
	assert_eq(mc.mission_state.get("countdown_remaining"), 0, "递减到 0")
	assert_eq(mc.mission_state.get("countdown_expired"), true, "归零应置 expired")
	assert_true(component.check_lose(Game), "归零后应判定失败")
	assert_true(Game.log_list.has("倒计时归零！"), "归零时应输出日志")
	# 归零后不再递减
	Game.state_machine.turn_number = 4
	component.on_event(Game, "turn_started", {"player": p})
	assert_eq(mc.mission_state.get("countdown_remaining"), 0, "归零后 remaining 应保持 0")


func test_countdown_same_round_no_decrement() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("turn_countdown", {"rounds": 3, "auto_activate": true})
	component.setup(Game, mc)
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	Game.players = [p1, p2]
	Game.state_machine.turn_number = 1
	component.on_event(Game, "turn_started", {"player": p1})
	component.on_event(Game, "turn_started", {"player": p2})
	assert_eq(mc.mission_state.get("countdown_remaining"), 3, "同轮内多次 turn_started 不应重复递减")
	Game.state_machine.turn_number = 2
	component.on_event(Game, "turn_started", {"player": p1})
	assert_eq(mc.mission_state.get("countdown_remaining"), 2, "新轮边界才递减一次")


func test_countdown_activate_method() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("turn_countdown", {"rounds": 5})
	component.setup(Game, mc)
	assert_eq(mc.mission_state.get("countdown_active"), false, "初始未激活")
	var countdown := component as MissionComponentTurnCountdown
	countdown.activate()
	assert_eq(mc.mission_state.get("countdown_active"), true, "activate() 应激活倒计时")
	assert_eq(mc.mission_state.get("countdown_remaining"), 5, "activate() 应重置剩余为 rounds")


func test_countdown_activate_marker() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("turn_countdown", {"rounds": 2})
	component.setup(Game, mc)
	var p: Player = _make_player("P")
	Game.players = [p]
	assert_eq(mc.mission_state.get("countdown_active"), false, "初始未激活")
	# 外部置 countdown_activate 标记：下一个事件激活并清除标记
	mc.mission_state["countdown_activate"] = true
	component.on_event(Game, "turn_ended", {"player": p})
	assert_eq(mc.mission_state.get("countdown_active"), true, "标记应触发激活")
	assert_eq(mc.mission_state.get("countdown_remaining"), 2, "激活后剩余应为 rounds")
	assert_false(mc.mission_state.has("countdown_activate"), "激活后应清除标记键")
	# 激活后轮次边界正常递减
	Game.state_machine.turn_number = 1
	component.on_event(Game, "turn_started", {"player": p})
	assert_eq(mc.mission_state.get("countdown_remaining"), 2, "激活后首个 turn_started 不应递减")
	Game.state_machine.turn_number = 2
	component.on_event(Game, "turn_started", {"player": p})
	assert_eq(mc.mission_state.get("countdown_remaining"), 1, "轮次边界应递减")
