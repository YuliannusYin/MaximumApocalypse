extends GutTest

## EventBus 信号单元测试。
## 验证新增 8 信号存在 + 可 connect + 可 emit。
## 设计文档：GameDesignDocus/GameSystem/Core/EventBus.md


func _make_player() -> Player:
	var p: Player = Player.new()
	p.hp = 10
	p.max_hp = 10
	p.player_name = "TestPlayer"
	return p


func _make_block() -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = "test_block"
	b.set_coordinate(0, 0)
	return b


# === 1. 装备信号 ===

func test_equipment_equipped_signal() -> void:
	var received: Array = []
	EventBus.equipment_equipped.connect(func(player, card): received.append([player, card]))
	var p: Player = _make_player()
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = "武器"
	EventBus.equipment_equipped.emit(p, e)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], p)
	assert_eq(received[0][1], e)


func test_equipment_unequipped_signal() -> void:
	var received: Array = []
	EventBus.equipment_unequipped.connect(func(player, card): received.append(card))
	var p: Player = _make_player()
	var e: EquipmentCard = EquipmentCard.new()
	EventBus.equipment_unequipped.emit(p, e)
	assert_eq(received.size(), 1)
	assert_eq(received[0], e)


func test_charge_consumed_signal() -> void:
	var received: Array = []
	EventBus.charge_consumed.connect(func(player, equip, num): received.append(num))
	var p: Player = _make_player()
	var e: EquipmentCard = EquipmentCard.new()
	EventBus.charge_consumed.emit(p, e, 2)
	assert_eq(received.size(), 1)
	assert_eq(received[0], 2)


# === 2. 卡牌抽取信号 ===

func test_scavenge_drawn_signal() -> void:
	var received: Array = []
	EventBus.scavenge_drawn.connect(func(player, card): received.append(card))
	var p: Player = _make_player()
	var c: ScavengeCard = ScavengeCard.new()
	c.card_name = "拾荒卡"
	EventBus.scavenge_drawn.emit(p, c)
	assert_eq(received.size(), 1)
	assert_eq(received[0], c)


func test_monster_card_drawn_signal() -> void:
	var received: Array = []
	EventBus.monster_card_drawn.connect(func(player, card): received.append(card))
	var p: Player = _make_player()
	var c: MonsterCard = MonsterCard.new()
	c.card_name = "怪物卡"
	EventBus.monster_card_drawn.emit(p, c)
	assert_eq(received.size(), 1)
	assert_eq(received[0], c)


# === 3. 回合阶段信号 ===

func test_phase_changed_signal() -> void:
	var received: Array = []
	EventBus.phase_changed.connect(func(player, old_p, new_p): received.append([old_p, new_p]))
	var p: Player = _make_player()
	EventBus.phase_changed.emit(p, "draw", "action")
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], "draw")
	assert_eq(received[0][1], "action")


func test_action_consumed_signal() -> void:
	var received: Array = []
	EventBus.action_consumed.connect(func(player, num): received.append(num))
	var p: Player = _make_player()
	EventBus.action_consumed.emit(p, 1)
	assert_eq(received.size(), 1)
	assert_eq(received[0], 1)


# === 4. 地图信号 ===

func test_objective_mark_triggered_signal() -> void:
	var received: Array = []
	EventBus.objective_mark_triggered.connect(func(player, block, mark): received.append([block, mark]))
	var p: Player = _make_player()
	var b: MapBlock = _make_block()
	var mark: Dictionary = {"description": "测试标记"}
	EventBus.objective_mark_triggered.emit(p, b, mark)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], b)
	assert_eq(received[0][1], mark)


# === 5. 信号计数验证 ===

func test_all_new_signals_exist() -> void:
	# 验证所有 8 个新信号都可以 connect（即存在）
	var signals: Array = [
		"equipment_equipped", "equipment_unequipped", "charge_consumed",
		"scavenge_drawn", "monster_card_drawn",
		"phase_changed", "action_consumed",
		"objective_mark_triggered",
	]
	var count: int = 0
	for sig_name in signals:
		if EventBus.has_signal(sig_name):
			count += 1
	assert_eq(count, 8, "应有 8 个新信号")


func test_emit_without_listener_no_crash() -> void:
	# 无监听器时 emit 不应崩溃
	var p: Player = _make_player()
	var e: EquipmentCard = EquipmentCard.new()
	EventBus.equipment_equipped.emit(p, e)
	EventBus.equipment_unequipped.emit(p, e)
	EventBus.charge_consumed.emit(p, e, 1)
	EventBus.scavenge_drawn.emit(p, null)
	EventBus.monster_card_drawn.emit(p, null)
	EventBus.phase_changed.emit(p, "a", "b")
	EventBus.action_consumed.emit(p, 1)
	EventBus.objective_mark_triggered.emit(p, null, null)
	assert_true(true, "无监听器 emit 不崩溃")
