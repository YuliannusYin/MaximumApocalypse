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
	monster.damage_value = 4
	monster.range = "short"
	monster.stunned = true
	player.monster_zone = [monster]
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	var row: Dictionary = snapshot["players"][0]["monsters"][0]
	assert_eq(row["monster_name"], "丧尸")
	assert_eq(row["card_name"], "丧尸")
	assert_eq(row["hp"], 2)
	assert_eq(row["max_hp"], 3)
	assert_eq(row["damage_value"], 4)
	assert_eq(row["range"], "short")
	assert_true(row["stunned"])


func test_apply_monster_restores_combat_stats() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.net_id = 1
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	snapshot["players"][0]["monsters"] = [{
		"net_id": 31,
		"english_name": "zombie",
		"monster_name": "丧尸",
		"card_name": "丧尸",
		"monster_type": "zombie",
		"monster_level": "normal",
		"hp": 1,
		"max_hp": 5,
		"damage_value": 3,
		"range": "medium",
		"stunned": true,
	}]
	GameStateSerializerScript.apply(Game, snapshot, {1: player})
	assert_eq(player.monster_zone.size(), 1)
	var monster: Monster = player.monster_zone[0]
	assert_eq(monster.hp, 1)
	assert_eq(monster.max_hp, 5)
	assert_eq(monster.damage_value, 3)
	assert_eq(monster.range, "medium")
	assert_true(monster.stunned)


func test_apply_missing_hp_uses_max_hp() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.net_id = 1
	Game.players = [player]
	Game.map_area = []
	GameStateSerializerScript.apply(Game, {
		"players": [{
			"net_id": 1,
			"seat_number": 0,
			"player_name": "Hunter",
			"hp": 10,
			"max_hp": 10,
			"hunger": 1,
			"hand": [],
			"equipment": [],
			"discard": [],
			"monsters": [{
				"net_id": 32,
				"english_name": "zombie",
				"monster_name": "丧尸",
				"max_hp": 5,
				"damage_value": 2,
			}],
			"current_block": {},
		}],
		"map": [],
	}, {1: player})
	assert_eq(player.monster_zone.size(), 1)
	assert_eq(player.monster_zone[0].max_hp, 5)
	assert_eq(player.monster_zone[0].hp, 5, "快照缺 hp 时应按 max_hp 填当前血")


func test_apply_to_view_does_not_change_authority_monster_hp() -> void:
	var authority: Player = _make_player("Hunter")
	authority.seat_number = 0
	var monster: Monster = Monster.new()
	monster.net_id = 33
	monster.english_name = "zombie"
	monster.hp = 5
	monster.max_hp = 5
	authority.monster_zone = [monster]
	Game.players = [authority]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	snapshot["players"][0]["monsters"][0]["hp"] = 0
	var view_player: Player = _make_player("View")
	view_player.seat_number = 0
	var view_game: Node = Game.get_script().new()
	view_game.players = [view_player]
	view_game.map_area = []
	GameStateSerializerScript.apply(view_game, snapshot, {})
	assert_eq(monster.hp, 5, "套到另一份镜像后权威怪物血量不得被改")
	assert_eq(view_player.monster_zone.size(), 1)
	assert_eq(view_player.monster_zone[0].hp, 0)
	view_game.free()


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
	assert_eq(int(snapshot["players"][0]["limited_remaining_actions"]), 0,
		"迷你回合预算应单独放在 limited_remaining_actions")
	var view: Player = _make_player("Surgeon")
	view.seat_number = 0
	view.action_count = 2
	Game.players = [view]
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(view.action_count, 2, "客机应保留正式行动点")
	assert_eq(view.get_effective_action_count(), 0, "显示层应套用迷你回合剩余预算")


func test_snapshot_applies_limited_remaining_actions_without_touching_formal_ap() -> void:
	var player: Player = _make_player("Gunslinger")
	player.seat_number = 0
	player.action_count = 0
	player._operation_context_stack.append({
		"kind": "limited_action",
		"remaining_actions": 2,
		"requested_actions": 2,
	})
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_eq(int(snapshot["players"][0]["action_count"]), 0)
	assert_eq(int(snapshot["players"][0]["limited_remaining_actions"]), 2)
	var view: Player = _make_player("Gunslinger")
	view.seat_number = 0
	view.action_count = 0
	Game.players = [view]
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(view.action_count, 0, "正式行动点应保持 0")
	assert_eq(view.get_effective_action_count(), 2, "客机面板应读到临时行动 2")
	snapshot["players"][0]["limited_remaining_actions"] = -1
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(view.action_count, 0)
	assert_eq(view.get_effective_action_count(), 0, "迷你回合结束后应清掉显示层预算")


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


func test_apply_copies_game_over_result_and_last_player() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	Game.players = [player]
	Game.map_area = []
	Game.state_machine.current_state = GameStateMachine.GameState.PLAYING
	Game.state_machine.game_result = -1
	Game.state_machine.last_player = null
	Game.game_over_called = false
	Game.game_result = ""
	GameStateSerializerScript.apply(Game, {
		"players": [],
		"map": [],
		"state_machine": {
			"state": GameStateMachine.GameState.GAME_OVER,
			"game_result": GameStateMachine.GameResult.WIN,
			"current_player_seat": -1,
			"last_player_seat": 0,
			"turn_number": 4,
		},
	}, {})
	assert_eq(Game.state_machine.current_state, GameStateMachine.GameState.GAME_OVER)
	assert_eq(Game.state_machine.game_result, GameStateMachine.GameResult.WIN)
	assert_eq(Game.state_machine.last_player, player)
	assert_true(Game.game_over_called)
	assert_eq(Game.game_result, "win")


func test_snapshot_includes_game_over_fields() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 1
	Game.players = [player]
	Game.map_area = []
	Game.state_machine.current_state = GameStateMachine.GameState.GAME_OVER
	Game.state_machine.game_result = GameStateMachine.GameResult.LOSE
	Game.state_machine.last_player = player
	var packed: Dictionary = GameStateSerializerScript.snapshot(Game).get("state_machine", {})
	assert_eq(int(packed.get("state", -1)), GameStateMachine.GameState.GAME_OVER)
	assert_eq(int(packed.get("game_result", -2)), GameStateMachine.GameResult.LOSE)
	assert_eq(int(packed.get("last_player_seat", -1)), 1)


func test_apply_resizes_unrevealed_piles_from_counts() -> void:
	Game.players = []
	Game.map_area = []
	Game.red_scavenge_pile = Pile.new()
	Game.monster_pile = null
	var snapshot: Dictionary = {
		"players": [],
		"map": [],
		"piles": {
			"monster": 4,
			"red": 2,
			"green": 0,
			"blue": 1,
		},
	}
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(Game.monster_pile.size(), 4)
	assert_eq(Game.red_scavenge_pile.size(), 2)
	assert_eq(Game.green_scavenge_pile.size(), 0)
	assert_eq(Game.blue_scavenge_pile.size(), 1)


func test_apply_creates_player_and_game_deck_count_from_empty_game() -> void:
	Game.players = []
	Game.map_area = []
	var snapshot: Dictionary = {
		"players": [{
			"net_id": 7,
			"seat_number": 0,
			"player_name": "客机位",
			"hp": 5,
			"max_hp": 8,
			"hunger": 1,
			"hand": [],
			"equipment": [],
			"discard": [],
			"monsters": [],
			"game_deck": 3,
			"current_block": {},
		}],
		"map": [],
		"piles": {},
	}
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(Game.players.size(), 1)
	assert_eq(int(Game.players[0].net_id), 7)
	assert_eq(String(Game.players[0].player_name), "客机位")
	assert_eq(int(Game.players[0].hp), 5)
	assert_eq(Game.players[0].game_deck.size(), 3)


func test_display_game_add_van_fuel_usable_with_equipped_fuel() -> void:
	MissionComponentRegistry.reset()
	var mission: MissionData = DataManager.get_mission(0)
	assert_not_null(mission, "应能加载任务 0")
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.action_count = 2
	player.in_phase = "action"
	player.current_block = van
	var fuel: EquipmentCard = _make_equipment("燃料")
	fuel.english_name = "fuel"
	player.equipment_zone.append(fuel)
	Game.players = [player]
	Game.map_area = [van]
	Game.current_mission = mission
	Game.mission_config = MissionConfig.new()
	Game.mission_config.mission_state = {"van_fuel": 0, "van_fueled": false}
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	var display: Node = load("res://src/game/game.gd").new()
	GameStateSerializerScript.apply(display, snapshot, {})
	assert_false(display.mission_config.action_components.is_empty(), "显示世界应挂上任务行动组件")
	var fuel_component: Variant = null
	for component in display.mission_config.action_components:
		if component is MissionComponentAddVanFuel:
			fuel_component = component
			break
	assert_not_null(fuel_component, "显示世界应有添加燃料组件")
	assert_not_null(fuel_component._mission_config, "显示世界添加燃料组件应已 setup")
	assert_eq(display.players.size(), 1)
	var display_player: Player = display.players[0]
	var skill: Variant = null
	for candidate in display_player.skills:
		if candidate != null and String(candidate.get("skill_name")) == "添加燃料":
			skill = candidate
			break
	assert_not_null(skill, "走到面包车后显示世界应挂上添加燃料")
	assert_true(display_player.can_use_active_skill(skill),
		"装备区有燃料且有行动点时添加燃料应可确认")
	display.free()
	MissionComponentRegistry.reset()


func test_snapshot_and_apply_copy_player_stats() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var role := RoleCard.new()
	role.english_name = "hunter"
	player.role_card = role
	Game.players = [player]
	Game.map_area = []
	Game.stats_tracker.reset([player])
	EventBus.damage_dealt.emit(player, _make_monster("丧尸"), 6)
	EventBus.healing_done.emit(player, player, 2)
	Game.stats_tracker.game_duration_msec = 777
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_true(snapshot.has("stats"), "快照应带本局统计")
	assert_eq(int(snapshot["stats"]["players"]["0"]["damage_dealt"]), 6)
	assert_eq(int(snapshot["stats"]["duration_msec"]), 777)
	var guest: Player = _make_player("Hunter")
	guest.seat_number = 0
	guest.role_card = role
	Game.players = [guest]
	Game.stats_tracker.reset([guest])
	GameStateSerializerScript.apply(Game, snapshot, {})
	assert_eq(Game.stats_tracker.get_stats(guest).damage_dealt, 6)
	assert_eq(Game.stats_tracker.get_stats(guest).healing_done, 2)
	assert_eq(Game.stats_tracker.game_duration_msec, 777)


func test_snapshot_syncs_marks_and_role_flip() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.net_id = 11
	var role := RoleCard.new()
	role.english_name = "hunter"
	role.is_front_side = false
	player.role_card = role
	player.add_mark("check_weapon", 1, "检查武器", "造成的伤害+1", true)
	player.add_mark("hunger_damage_level", 2, "饥饿", "饥饿伤害等级2", true)
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	var row: Dictionary = snapshot["players"][0]
	assert_false(bool(row.get("is_front_side", true)), "快照应带角色卡反面")
	assert_eq(row["marks"].size(), 2, "快照应带玩家标记")

	var guest: Player = _make_player("Hunter")
	guest.seat_number = 0
	guest.net_id = 11
	guest.role_card = RoleCard.new()
	guest.role_card.is_front_side = true
	Game.players = [guest]
	GameStateSerializerScript.apply(Game, snapshot, {11: guest})
	assert_false(guest.role_card.is_front_side, "显示世界应同步角色卡翻面")
	assert_eq(guest.count_mark("check_weapon"), 1)
	assert_eq(guest.count_mark("hunger_damage_level"), 2)
	var check_mark: Mark = guest.marks.get("check_weapon")
	assert_not_null(check_mark)
	assert_eq(check_mark.mark_text, "检查武器")
	assert_true(check_mark.visible)
	var hunger_mark: Mark = guest.marks.get("hunger_damage_level")
	assert_not_null(hunger_mark)
	assert_eq(hunger_mark.mark_text, "饥饿")


func test_apply_two_same_name_monsters_keeps_hp_and_count() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	player.net_id = 1
	Game.players = [player]
	Game.map_area = []
	GameStateSerializerScript.apply(Game, {
		"players": [{
			"net_id": 1,
			"seat_number": 0,
			"player_name": "Hunter",
			"hp": 10,
			"max_hp": 10,
			"hunger": 1,
			"hand": [],
			"equipment": [],
			"discard": [],
			"monsters": [
				{
					"net_id": 41,
					"english_name": "zombie_soldier",
					"monster_name": "僵尸士兵",
					"hp": 1,
					"max_hp": 8,
				},
				{
					"net_id": 42,
					"english_name": "zombie_soldier",
					"monster_name": "僵尸士兵",
					"hp": 8,
					"max_hp": 8,
				},
			],
			"current_block": {},
		}],
		"map": [],
	}, {1: player})
	assert_eq(player.monster_zone.size(), 2, "同名士兵应各占一条")
	assert_eq(int(player.monster_zone[0].hp), 1)
	assert_eq(int(player.monster_zone[1].hp), 8)
	assert_ne(player.monster_zone[0], player.monster_zone[1])


func test_apply_does_not_share_monster_across_seats() -> void:
	var host: Player = _make_player("Host")
	host.seat_number = 0
	host.net_id = 1
	var guest: Player = _make_player("Guest")
	guest.seat_number = 1
	guest.net_id = 2
	Game.players = [host, guest]
	Game.map_area = []
	GameStateSerializerScript.apply(Game, {
		"players": [
			{
				"net_id": 1,
				"seat_number": 0,
				"player_name": "Host",
				"hp": 10,
				"max_hp": 10,
				"hunger": 1,
				"hand": [],
				"equipment": [],
				"discard": [],
				"monsters": [],
				"current_block": {},
			},
			{
				"net_id": 2,
				"seat_number": 1,
				"player_name": "Guest",
				"hp": 10,
				"max_hp": 10,
				"hunger": 1,
				"hand": [],
				"equipment": [],
				"discard": [],
				"monsters": [{
					"net_id": 51,
					"english_name": "zombie_soldier",
					"monster_name": "僵尸士兵",
					"hp": 8,
					"max_hp": 8,
				}],
				"current_block": {},
			},
		],
		"map": [],
	}, {1: host, 2: guest})
	assert_eq(host.monster_zone.size(), 0, "房主座位不应吃到客机的怪")
	assert_eq(guest.monster_zone.size(), 1)
	assert_eq(guest.monster_zone[0].attack_target, guest)
