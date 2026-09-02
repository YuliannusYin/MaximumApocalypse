extends GutTest

## 全量状态序列化/视图还原测试（主机权威 -> 客机渲染的数据管道）。


func after_each() -> void:
	NetSession.stop()
	RoomState.clear()
	Game.players.clear()
	Game.map_area.clear()


## 构造一个真实的已初始化游戏（任务 0，枪手）。
func _setup_host_game() -> void:
	RoomState.init_host_seats("主机", NetSession.HOST_PEER_ID)
	RoomState.seats[0]["survivor"] = DataManager.get_survivor("gunslinger")
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	Game.initialize_game(RoomState.selected_mission, RoomState.variants, RoomState.seats)


## 创建独立的 Game 形状视图对象（供快照应用，不污染 autoload）。
func _make_view() -> Node:
	var view: Node = Node.new()
	view.set_script(load("res://src/game/game.gd"))
	add_child(view)
	view.mission_config = MissionConfig.new()
	return view


func test_serialize_roundtrip_basic() -> void:
	_setup_host_game()
	var state := GameStateSerializer.serialize(Game)
	assert_eq(state["blocks"].size(), Game.map_area.size(), "地图块数量应一致")
	assert_eq(state["players"].size(), Game.players.size(), "玩家数量应一致")
	assert_eq(state["map_width"], Game.map_width)
	assert_eq(state["map_height"], Game.map_height)

	var view := _make_view()
	var ctx := GameStateSerializer.make_context()
	GameStateSerializer.apply_to_view(view, state, ctx)

	assert_eq(view.map_area.size(), Game.map_area.size())
	assert_eq(view.players.size(), Game.players.size())
	for i in range(Game.players.size()):
		var src = Game.players[i]
		var dst = view.players[i]
		assert_eq(dst.net_id, src.net_id, "玩家 net_id 应一致")
		assert_eq(dst.seat_number, src.seat_number)
		assert_eq(dst.hp, src.hp)
		assert_eq(dst.max_hp, src.max_hp)
		assert_eq(dst.hunger, src.hunger)
		assert_eq(dst.hand.size(), src.hand.size(), "手牌数应一致")
		assert_eq(dst.game_deck.size(), src.game_deck.size(), "游戏牌堆数应一致")
		assert_eq(dst.skills.size(), src.skills.size(), "技能数应一致（供客机技能栏/choose_target）")
	# 地图块字段
	assert_eq(view.map_area[0].coordinate, Game.map_area[0].coordinate)
	assert_eq(view.map_area[0].block_name, Game.map_area[0].block_name)
	# 牌堆计数
	assert_eq(view.monster_pile.size(), Game.monster_pile.size())
	assert_eq(view.red_scavenge_pile.size(), Game.red_scavenge_pile.size())
	view.free()


func test_snapshot_in_place_identity() -> void:
	_setup_host_game()
	var view := _make_view()
	var ctx := GameStateSerializer.make_context()
	GameStateSerializer.apply_to_view(view, GameStateSerializer.serialize(Game), ctx)
	var first_players: Array = view.players
	var first_player_net_ids: Array = []
	for p in first_players:
		first_player_net_ids.append(p.net_id)
	var first_blocks: Array = view.map_area

	# 修改权威状态（受伤、摸牌）后再快照
	var src_player: Player = Game.players[0]
	src_player.hp -= 2
	src_player.hand.append(Game.create_scavenge_card("手枪"))
	var src_hand_count: int = src_player.hand.size()

	GameStateSerializer.apply_to_view(view, GameStateSerializer.serialize(Game), ctx)

	# 视图对象应保持同一批实例（原位更新，UI 实例 id 映射不失效）
	assert_eq(view.players, first_players, "视图玩家实例应保持不变")
	assert_eq(view.map_area, first_blocks, "视图地块实例应保持不变")
	assert_eq(view.players[0].hp, src_player.hp, "HP 应原位更新")
	assert_eq(view.players[0].hand.size(), src_hand_count, "手牌数应原位更新")
	assert_eq(view.players[0].net_id, first_player_net_ids[0], "net_id 应保持")
	view.free()


func test_serialize_equipment_and_monster_zone() -> void:
	_setup_host_game()
	var player: Player = Game.players[0]
	# 挂一件装备（拾荒装备卡进装备区）
	var eq_card: Card = Game.create_scavenge_card("防弹背心")
	var equipment: Equipment = (eq_card as EquipmentCard).instantiate(player)
	player.equipment_zone.append(equipment)
	# 抓一张怪物牌入怪物区
	var monster_card: Card = Game.create_scavenge_card("僵尸")
	if monster_card is MonsterCard:
		var monster: Monster = monster_card.instantiate(player)
		player.monster_zone.append(monster)

	var state := GameStateSerializer.serialize(Game)
	assert_eq(state["players"][0]["equipment"].size(), 1, "装备区应序列化")
	assert_eq(state["players"][0]["monster_zone"].size(), player.monster_zone.size(), "怪物区应序列化")

	var view := _make_view()
	var ctx := GameStateSerializer.make_context()
	GameStateSerializer.apply_to_view(view, state, ctx)
	assert_eq(view.players[0].equipment_zone.size(), 1, "装备区应还原")
	assert_eq(view.players[0].monster_zone.size(), player.monster_zone.size(), "怪物区应还原")
	if view.players[0].monster_zone.size() > 0:
		var vm: Monster = view.players[0].monster_zone[0]
		assert_eq(vm.hp, player.monster_zone[0].hp, "怪物 HP 应还原")
		assert_eq(vm.attack_target, view.players[0], "怪物纠缠目标应指向所在玩家")
	view.free()
