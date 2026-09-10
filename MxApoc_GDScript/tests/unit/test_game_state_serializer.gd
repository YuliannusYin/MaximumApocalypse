extends TestBase

const GameStateSerializerScript = preload("res://src/net/game_state_serializer.gd")

## 快照须带弃牌堆卡列表，客机才能判定「神通广大」等依赖弃牌堆装备的 filter。


func test_snapshot_includes_player_and_scavenge_discard_cards() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var camouflage: EquipmentCard = _make_equipment("迷彩服")
	camouflage.english_name = "camouflage"
	player.game_discard_pile.add(camouflage)
	var pistol: EquipmentCard = _make_equipment("手枪")
	pistol.english_name = "pistol"
	pistol.source = "scavenge"
	Game.players = [player]
	Game.scavenge_discard_pile = Pile.new()
	Game.scavenge_discard_pile.add(pistol)
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_eq(snapshot["players"][0]["discard"].size(), 1)
	assert_eq(snapshot["players"][0]["discard"][0]["english_name"], "camouflage")
	assert_eq(snapshot["piles"]["scavenge_discard_cards"].size(), 1)
	assert_eq(snapshot["piles"]["scavenge_discard_cards"][0]["english_name"], "pistol")


func test_rebuilt_discard_makes_has_equipment_true() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var camouflage: EquipmentCard = _make_equipment("迷彩服")
	camouflage.english_name = "camouflage"
	player.game_discard_pile.add(camouflage)
	Game.players = [player]
	Game.scavenge_discard_pile = Pile.new()
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	player.game_discard_pile = Pile.new()
	assert_false(Game.has_equipment_in_discard_piles(), "清空后客机镜像应判无装备")
	var rebuilt: Array = []
	for row in snapshot["players"][0]["discard"]:
		rebuilt.append(NetInputCodec.create_card_from_payload(row, Game))
	player.game_discard_pile.cards = rebuilt
	assert_true(Game.has_equipment_in_discard_piles(), "按快照重建弃牌堆后应能检出装备")


func test_snapshot_monster_keeps_monster_name() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var monster: Monster = Monster.new()
	monster.english_name = "zombie"
	monster.monster_name = "丧尸"
	monster.hp = 2
	monster.max_hp = 3
	player.monster_zone = [monster]
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_eq(snapshot["players"][0]["monsters"][0]["monster_name"], "丧尸")
	assert_eq(snapshot["players"][0]["monsters"][0]["card_name"], "丧尸")


func test_snapshot_includes_map_block_variants() -> void:
	var block: MapBlock = _make_block("城市街道", 1, 2, true)
	block.scavenge_colors = PackedStringArray(["green", "blue"])
	block.monster_spawn_value = 8
	Game.players = []
	Game.map_area = [block]
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_eq(snapshot["map"].size(), 1)
	assert_eq(snapshot["map"][0]["block_name"], "城市街道")
	assert_eq(snapshot["map"][0]["scavenge_colors"], ["green", "blue"])
	assert_eq(snapshot["map"][0]["monster_spawn_value"], 8)


func test_apply_keeps_hand_card_reference_by_net_id() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.net_id = 1
	player.hp = 7
	var card: Card = _make_card("手枪")
	card.english_name = "pistol"
	card.net_id = 10
	player.hand = [card]
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	snapshot["players"][0]["hp"] = 3
	var ctx := {1: player, 10: card}
	GameStateSerializerScript.apply(Game, snapshot, ctx)
	assert_eq(player.hand[0], card, "同 net_id 应保持原卡引用")
	assert_eq(player.hp, 3)
	assert_eq(card.net_id, 10)


func test_apply_keeps_equipment_and_skills() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.net_id = 1
	var source: EquipmentCard = _make_equipment("迷彩服")
	source.english_name = "camouflage"
	source.net_id = 11
	var equipment: Equipment = source.instantiate(player)
	equipment.net_id = 12
	var skill: Skill = Skill.new()
	skill.english_name = "camo_skill"
	equipment.add_skill(skill)
	player.add_skill(skill)
	player.equipment_zone = [equipment]
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	var ctx := {1: player, 11: source, 12: equipment}
	GameStateSerializerScript.apply(Game, snapshot, ctx)
	assert_eq(player.equipment_zone[0], equipment, "装备应原位保留")
	assert_eq(player.equipment_zone[0].net_id, 12)
	assert_true(player.equipment_zone[0].get_all_skills().has(skill),
		"同一装备进区后技能对象不应被拆掉重建")


func test_snapshot_keeps_formal_action_count_during_limited_action() -> void:
	var player: Player = _make_player("Surgeon")
	player.seat_number = 0
	player.action_count = 2
	player._operation_context_stack.append({
		"kind": "limited_action",
		"remaining_actions": 0,
	})
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_eq(int(snapshot["players"][0]["action_count"]), 2,
		"迷你回合预算不应写进快照里的正式行动点")
	var view: Player = _make_player("Surgeon")
	view.seat_number = 0
	view.action_count = 2
	Game.players = [view]
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(view.action_count, 2, "客机应保留正式行动点")


func test_apply_replaces_map_block_skills_when_name_changes() -> void:
	var block: MapBlock = Game._create_map_block("加油站")
	block.set_coordinate(0, 0)
	block.revealed = true
	assert_eq(block.skills[0].skill_name, "加油站")
	Game.players = []
	Game.map_area = [block]
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	snapshot["map"][0]["block_name"] = "墓地"
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(block.block_name, "墓地")
	assert_eq(block.skills.size(), 1, "应按新地名重挂地块技能")
	assert_eq(block.skills[0].skill_name, "墓地", "右键查看应显示墓地技能而不是加油站")


func test_apply_keeps_map_block_skill_instance_when_name_unchanged() -> void:
	var block: MapBlock = Game._create_map_block("加油站")
	block.set_coordinate(0, 0)
	var original: Skill = block.skills[0]
	Game.players = []
	Game.map_area = [block]
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(block.skills[0], original, "同名地块不应每帧重建技能对象")


func test_apply_mounts_mission_action_skill_when_current_block_changes() -> void:
	MissionComponentRegistry.reset()
	var wild: MapBlock = _make_block("旷野", 0, 0, true)
	var van: MapBlock = _make_block("面包车", 1, 0, true)
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.current_block = wild
	player.action_count = 2
	Game.players = [player]
	Game.map_area = [wild, van]
	var mc: MissionConfig = MissionConfig.new()
	mc.action_components.append(MissionComponentRegistry.create("add_van_fuel", {"count": 4}))
	mc.setup_components(Game)
	Game.mission_config = mc
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	snapshot["players"][0]["current_block"] = {"x": 1, "y": 0}
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(player.current_block, van)
	var names: PackedStringArray = PackedStringArray()
	for skill in player.skills:
		names.append(String(skill.skill_name))
	assert_true(names.has("添加燃料"), "走到面包车后应挂上添加燃料")
	MissionComponentRegistry.reset()


func test_apply_copies_mission_state() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.mission_state = {"van_fuel": 0, "van_fueled": false}
	Game.mission_config = mc
	Game.players = []
	Game.map_area = []
	var snapshot: Dictionary = {
		"mission_state": {"mission_state": {"van_fuel": 2, "van_fueled": false}},
	}
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(int(Game.mission_config.mission_state.get("van_fuel", 0)), 2,
		"客机任务进度应套用快照里的 mission_state")
