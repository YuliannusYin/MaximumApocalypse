extends GutTest

## 触发类任务组件单元测试（三层架构第二层：6 个触发器组件）。
## 覆盖：mark_enter_reward / first_enter_draw_boss / reveal_mark_draw_boss /
## card_discard_watch / setup_equip_card / spawn_dice_effect 的注册表映射、
## 事件触发逻辑、去重语义与外围地块效果。
## 注册表 reset() 会清除内置注册标记，create()/has() 懒注册会重新注册内置组件，
## 故测试中直接 create 即可，无需手动处理。
## 说明：draw_boss_card / equip / death / destroy_map_block 均为协程，
## 组件内 fire-and-forget 调用；测试玩家无技能时协程不挂起、同步执行完毕，
## 故多数断言可在 on_event / setup 返回后立即判定。

# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_card(card_name: String = "test_card", type: String = "action", source: String = "game") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = source
	return c


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


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
	Game.map_width = 0
	Game.map_height = 0
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


## 判断 Game.log_list 中是否存在包含指定片段的日志。
func _log_contains(part: String) -> bool:
	for msg in Game.log_list:
		if part in msg:
			return true
	return false


func before_each() -> void:
	MissionComponentRegistry.reset()
	_clear_game()


func after_each() -> void:
	MissionComponentRegistry.reset()
	_clear_game()


# === 0. 注册表内置映射 ===

func test_registry_trigger_components_registered() -> void:
	assert_true(MissionComponentRegistry.has("mark_enter_reward"), "mark_enter_reward 应已注册")
	assert_true(MissionComponentRegistry.has("first_enter_draw_boss"), "first_enter_draw_boss 应已注册")
	assert_true(MissionComponentRegistry.has("reveal_mark_draw_boss"), "reveal_mark_draw_boss 应已注册")
	assert_true(MissionComponentRegistry.has("card_discard_watch"), "card_discard_watch 应已注册")
	assert_true(MissionComponentRegistry.has("setup_equip_card"), "setup_equip_card 应已注册")
	assert_true(MissionComponentRegistry.has("spawn_dice_effect"), "spawn_dice_effect 应已注册")
	assert_true(MissionComponentRegistry.create("mark_enter_reward") is MissionComponentMarkEnterReward, "mark_enter_reward 应映射到正确类")
	assert_true(MissionComponentRegistry.create("first_enter_draw_boss") is MissionComponentFirstEnterDrawBoss, "first_enter_draw_boss 应映射到正确类")
	assert_true(MissionComponentRegistry.create("reveal_mark_draw_boss") is MissionComponentRevealMarkDrawBoss, "reveal_mark_draw_boss 应映射到正确类")
	assert_true(MissionComponentRegistry.create("card_discard_watch") is MissionComponentCardDiscardWatch, "card_discard_watch 应映射到正确类")
	assert_true(MissionComponentRegistry.create("setup_equip_card") is MissionComponentSetupEquipCard, "setup_equip_card 应映射到正确类")
	assert_true(MissionComponentRegistry.create("spawn_dice_effect") is MissionComponentSpawnDiceEffect, "spawn_dice_effect 应映射到正确类")


# === 1. mark_enter_reward ===

func test_mark_enter_reward_cards_to_hand() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("mark_enter_reward", {"rewards": {"mark_1": {"cards": {"燃料": 2}}}})
	var p: Player = _make_player("P")
	Game.players = [p]
	component.on_event(Game, "objective_mark_triggered", {"player": p, "block": _make_block("废墟", 0, 0), "mark": {"mark_id": "mark_1"}})
	assert_eq(p.hand.size(), 2, "应按数量生成 2 张奖励卡进手牌")
	for card in p.hand:
		assert_eq(card.card_name, "燃料", "奖励卡名应为 燃料")
	assert_true(_log_contains("触发任务标记奖励"), "应记录奖励内容日志")


func test_mark_enter_reward_card_not_found_skipped() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("mark_enter_reward", {"rewards": {"mark_1": {"cards": {"不存在的卡": 1}}}})
	var p: Player = _make_player("P")
	Game.players = [p]
	component.on_event(Game, "objective_mark_triggered", {"player": p, "block": _make_block("废墟", 0, 0), "mark": {"mark_id": "mark_1"}})
	assert_eq(p.hand.size(), 0, "不存在的卡应跳过，手牌为空")
	assert_true(_log_contains("未找到奖励拾荒卡"), "应记录未找到奖励卡日志")


func test_mark_enter_reward_draw_boss() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("mark_enter_reward", {"rewards": {"mark_1": {"draw_boss": true}}})
	var p: Player = _make_player("P")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	component.on_event(Game, "objective_mark_triggered", {"player": p, "block": _make_block("废墟", 0, 0), "mark": {"mark_id": "mark_1"}})
	assert_eq(p.monster_zone.size(), 1, "draw_boss 分支应抓取一张首领牌进怪物区")
	assert_eq(Game.monster_pile.size(), 0, "首领卡应从怪物牌堆中移除")
	assert_true(_log_contains("抓取一张首领牌"), "应记录首领奖励日志")


func test_mark_enter_reward_unmatched_mark_id_ignored() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("mark_enter_reward", {"rewards": {"mark_1": {"cards": {"燃料": 1}, "draw_boss": true}}})
	var p: Player = _make_player("P")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	component.on_event(Game, "objective_mark_triggered", {"player": p, "block": _make_block("废墟", 0, 0), "mark": {"mark_id": "mark_9"}})
	assert_eq(p.hand.size(), 0, "mark_id 不在 rewards 中不应发卡")
	assert_eq(p.monster_zone.size(), 0, "mark_id 不在 rewards 中不应抓首领")
	assert_eq(Game.monster_pile.size(), 1, "怪物牌堆不应被抽取")


# === 2. first_enter_draw_boss ===

func test_first_enter_draw_boss_triggers_once() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("first_enter_draw_boss", {"block_name": "警察局"})
	component.setup(Game, mc)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	Game.monster_pile.add(_make_monster_card("boss2", "boss"))
	var block: MapBlock = _make_block("警察局", 0, 0)
	component.on_event(Game, "player_moved", {"player": p, "source_block": null, "target_block": block})
	assert_eq(p.monster_zone.size(), 1, "首次抵达目标地块应抓取一张首领牌")
	assert_eq(mc.mission_state.get("first_enter_done_警察局"), true, "应记录首次进入标记键")
	assert_eq(Game.monster_pile.size(), 1, "怪物牌堆应被抽取一张")
	# 同一地块第二次进入：不再触发
	component.on_event(Game, "player_moved", {"player": p, "source_block": block, "target_block": block})
	assert_eq(p.monster_zone.size(), 1, "同一地块第二次进入不应再抓首领")
	assert_eq(Game.monster_pile.size(), 1, "怪物牌堆不应再被抽取")


func test_first_enter_draw_boss_wrong_block() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("first_enter_draw_boss", {"block_name": "警察局"})
	component.setup(Game, mc)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	component.on_event(Game, "player_moved", {"player": p, "source_block": null, "target_block": _make_block("避难所", 0, 0)})
	assert_eq(p.monster_zone.size(), 0, "移动到非目标地块不应抓首领")
	assert_false(mc.mission_state.has("first_enter_done_警察局"), "不应记录首次进入标记键")


# === 3. reveal_mark_draw_boss ===

func test_reveal_mark_draw_boss_once_per_block() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("reveal_mark_draw_boss", {})
	var p: Player = _make_player("P")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	Game.monster_pile.add(_make_monster_card("boss2", "boss"))
	var block: MapBlock = _make_block("秘密实验室", 0, 0)
	block.add_objective_mark({"mark_id": "mark_1"})
	component.on_event(Game, "block_revealed", {"block": block, "player": p})
	assert_eq(p.monster_zone.size(), 1, "展示带目标标记地块应抓取一张首领牌")
	# 同一地块第二次展示：不重复触发
	component.on_event(Game, "block_revealed", {"block": block, "player": p})
	assert_eq(p.monster_zone.size(), 1, "同一地块第二次展示不应重复抓首领")
	assert_eq(Game.monster_pile.size(), 1, "怪物牌堆不应再被抽取")
	# 不同地块（带标记）：各自触发一次
	var block2: MapBlock = _make_block("废墟", 1, 0)
	block2.add_objective_mark({"mark_id": "mark_2"})
	component.on_event(Game, "block_revealed", {"block": block2, "player": p})
	assert_eq(p.monster_zone.size(), 2, "不同地块应各自触发一次")


func test_reveal_mark_draw_boss_no_mark_ignored() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("reveal_mark_draw_boss", {})
	var p: Player = _make_player("P")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("boss1", "boss"))
	var block: MapBlock = _make_block("普通地块", 0, 0)
	component.on_event(Game, "block_revealed", {"block": block, "player": p})
	assert_eq(p.monster_zone.size(), 0, "无目标标记的地块被展示不应抓首领")
	assert_eq(Game.monster_pile.size(), 1, "怪物牌堆不应被抽取")


# === 4. card_discard_watch ===

func test_card_discard_watch_destroy_removes_from_pile() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("card_discard_watch", {"card_name": "科学家", "on_discard": "destroy"})
	component.setup(Game, mc)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	Game.players = [p]
	var card: Card = _make_card("科学家", "equipment", "scavenge")
	Game.scavenge_discard_pile = Pile.new()
	Game.scavenge_discard_pile.add(card)
	component.on_event(Game, "card_discarded", {"player": p, "card": card})
	assert_eq(Game.scavenge_discard_pile.size(), 0, "destroy 模式卡应从弃牌堆消失")
	assert_true(Game.removed_cards.has(card), "destroy 模式卡应被移出游戏")
	assert_true(_log_contains("被弃置并销毁"), "应记录弃置并销毁日志")
	assert_false(component.check_lose(Game), "destroy 模式不应判定失败")


func test_card_discard_watch_lose_flags_failure() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("card_discard_watch", {"card_name": "科学家", "on_discard": "lose"})
	component.setup(Game, mc)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	Game.players = [p]
	var card: Card = _make_card("科学家", "equipment", "scavenge")
	Game.scavenge_discard_pile = Pile.new()
	Game.scavenge_discard_pile.add(card)
	assert_false(component.check_lose(Game), "弃置前不应判定失败")
	component.on_event(Game, "card_discarded", {"player": p, "card": card})
	assert_eq(mc.mission_state.get("card_discard_failed"), true, "lose 模式应置 card_discard_failed")
	assert_true(component.check_lose(Game), "lose 模式弃置后应判定失败")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "lose 模式卡应保留在弃牌堆")
	assert_false(Game.removed_cards.has(card), "lose 模式不应移出游戏")
	assert_true(_log_contains("任务失败"), "应记录警示日志")


func test_card_discard_watch_other_card_ignored() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("card_discard_watch", {"card_name": "科学家", "on_discard": "lose"})
	component.setup(Game, mc)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	Game.players = [p]
	var card: Card = _make_card("燃料", "item", "scavenge")
	Game.scavenge_discard_pile = Pile.new()
	Game.scavenge_discard_pile.add(card)
	component.on_event(Game, "card_discarded", {"player": p, "card": card})
	assert_false(component.check_lose(Game), "非监视卡名被弃置不应判定失败")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "非监视卡不应被移出弃牌堆")


func test_card_discard_watch_via_event_bus() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("card_discard_watch", {"card_name": "科学家", "on_discard": "destroy"})
	component.setup(Game, mc)
	mc.trigger_components.append(component)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	Game.players = [p]
	var card: Card = _make_card("科学家", "equipment", "scavenge")
	Game.scavenge_discard_pile = Pile.new()
	Game.scavenge_discard_pile.add(card)
	EventBus.card_discarded.emit(p, card)
	assert_eq(Game.scavenge_discard_pile.size(), 0, "EventBus 事件应转发到组件并销毁弃牌堆中的卡")


# === 5. setup_equip_card ===

func test_setup_equip_card_equips_first_player() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("setup_equip_card", {"card_name": "科学家"})
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	Game.players = [p1, p2]
	component.setup(Game, mc)
	await get_tree().process_frame
	assert_true(p1.has_equipment("科学家"), "科学家应装备到第一个玩家装备区")
	assert_false(p2.has_equipment("科学家"), "不应装备到其他玩家")


func test_setup_equip_card_no_players_or_dead_skipped() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("setup_equip_card", {"card_name": "科学家"})
	# 玩家列表为空：不装备、不崩溃
	Game.players = []
	component.setup(Game, mc)
	# 第一个玩家死亡：跳过
	var p_dead: Player = _make_player("P1", 0)
	var p_alive: Player = _make_player("P2")
	Game.players = [p_dead, p_alive]
	component.setup(Game, mc)
	await get_tree().process_frame
	assert_false(p_dead.has_equipment("科学家"), "死亡玩家不应被装备")
	assert_false(p_alive.has_equipment("科学家"), "首个玩家死亡时应整体跳过（不顺延装备）")


func test_setup_equip_card_card_not_found() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var component: MissionComponent = MissionComponentRegistry.create("setup_equip_card", {"card_name": "不存在的卡"})
	var p: Player = _make_player("P")
	Game.players = [p]
	component.setup(Game, mc)
	await get_tree().process_frame
	assert_false(p.has_equipment("不存在的卡"), "拾荒卡不存在时不应装备")
	assert_true(_log_contains("未找到拾荒卡"), "create_scavenge_card 应记录未找到日志")


# === 6. spawn_dice_effect ===

## 构建 3x3 测试地图并返回 Vector2i(x, y) → MapBlock 映射。
## revealed_except 中列出的坐标保持未展示，其余全部置为已展示。
func _build_3x3_map(revealed_except: Array) -> Dictionary:
	Game.map_width = 3
	Game.map_height = 3
	var blocks: Dictionary = {}
	for y in 3:
		for x in 3:
			var b: MapBlock = _make_block("地块_%d_%d" % [x, y], x, y)
			b.revealed = not Vector2i(x, y) in revealed_except
			Game.map_area.append(b)
			blocks[Vector2i(x, y)] = b
	return blocks


func test_spawn_dice_effect_reveals_outer_block() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("spawn_dice_effect", {"value": 7})
	var p: Player = _make_player("P")
	Game.players = [p]
	# 外围仅 (0,1) 未展示（确定性命中）；中心 (1,1) 也未展示但非外围，不应被动到
	var blocks: Dictionary = _build_3x3_map([Vector2i(0, 1), Vector2i(1, 1)])
	component.on_event(Game, "monster_spawn_judged", {"player": p, "value": 7})
	assert_true(blocks[Vector2i(0, 1)].revealed, "唯一未展示的外围地块应被揭示")
	assert_false(blocks[Vector2i(1, 1)].revealed, "中心（非外围）地块不应被揭示")
	assert_eq(Game.map_area.size(), 9, "揭示分支不应移除地块")
	assert_true(_log_contains("被揭示"), "应记录揭示日志")


func test_spawn_dice_effect_value_mismatch_noop() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("spawn_dice_effect", {"value": 7})
	var p: Player = _make_player("P")
	Game.players = [p]
	var blocks: Dictionary = _build_3x3_map([Vector2i(0, 1), Vector2i(1, 1)])
	component.on_event(Game, "monster_spawn_judged", {"player": p, "value": 5})
	assert_false(blocks[Vector2i(0, 1)].revealed, "点数不匹配时不应揭示外围地块")
	assert_eq(Game.map_area.size(), 9, "点数不匹配时不应移除地块")


func test_spawn_dice_effect_destroys_outer_block_and_kills_players() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("spawn_dice_effect", {"value": 7})
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	# 唯一外围地块 doomed（确定性命中）；safe 位于中心 (1,1) 非外围
	var doomed: MapBlock = _make_block("废墟", 0, 0)
	doomed.revealed = true
	var safe: MapBlock = _make_block("避难所", 1, 1)
	safe.revealed = true
	p1.current_block = doomed
	p2.current_block = safe
	Game.players = [p1, p2]
	Game.map_area = [doomed, safe]
	Game.map_width = 3
	Game.map_height = 3
	component.on_event(Game, "monster_spawn_judged", {"player": p2, "value": 7})
	assert_eq(Game.map_area.size(), 1, "外围地块应被移除")
	assert_eq(Game.map_area[0], safe, "幸存地块应保留在地图区域")
	assert_eq(doomed.block_state, "destroyed", "被移除地块状态应为 destroyed")
	assert_false(p1.is_alive(), "地块上的存活玩家应被崩塌吞噬死亡")
	assert_true(p2.is_alive(), "不在地块上的玩家应存活")
	assert_true(_log_contains("被崩塌的废墟吞噬"), "应记录吞噬日志")
	assert_true(_log_contains("崩塌了"), "应记录地块崩塌日志")


func test_spawn_dice_effect_no_outer_blocks_noop() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("spawn_dice_effect", {"value": 7})
	var p: Player = _make_player("P")
	Game.players = [p]
	# 仅有一个已摧毁状态的地块（is_alive == false），外围无存活地块
	var destroyed_block: MapBlock = _make_block("废墟", 0, 0)
	destroyed_block.block_state = "destroyed"
	Game.map_area = [destroyed_block]
	Game.map_width = 3
	Game.map_height = 3
	component.on_event(Game, "monster_spawn_judged", {"player": p, "value": 7})
	assert_eq(Game.map_area.size(), 1, "外围无存活地块时应跳过，不移除地块")
	assert_true(p.is_alive(), "外围无存活地块时玩家不应死亡")
