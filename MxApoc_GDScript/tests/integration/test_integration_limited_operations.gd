extends GutTest

## 四张跨玩家操作牌的有限操作集成测试。
## 验证目标玩家实际执行操作/出牌时，不会污染自身正式回合状态。


func _make_player(name: String, survivor_id: String) -> Player:
	var survivor: SurvivorData = DataManager.get_survivor(survivor_id)
	var player := Player.new()
	player.player_name = name
	player.max_hp = survivor.max_hp
	player.hp = survivor.initial_hp
	player.role_card = Game._create_role_card_from_survivor(survivor)
	player.game_deck = Pile.new()
	player.game_discard_pile = Pile.new()
	player.in_phase = "action"
	player.action_count = 3
	return player


func _setup_game(source: Player, target: Player) -> void:
	Game.players = [source, target]
	Game.map_area = []
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func _make_survivor_card(survivor_id: String, card_name: String) -> Card:
	var survivor: SurvivorData = DataManager.get_survivor(survivor_id)
	for card_data in survivor.deck:
		if card_data is Dictionary and card_data.get("card_name", "") == card_name:
			return Game._create_game_card_from_dict(card_data)
	return null


func _make_plain_card(name: String) -> Card:
	var card := Card.new()
	card.card_name = name
	card.card_type = "action"
	card.source = "game"
	return card


func before_each() -> void:
	Game.players = []
	Game.map_area = []


func after_each() -> void:
	Game.players = []
	Game.map_area = []


func test_walkie_talkie_runs_target_action_without_changing_formal_state() -> void:
	var source := _make_player("Source", "gunslinger")
	var target := _make_player("Target", "surgeon")
	_setup_game(source, target)
	var radio: Card = Game.create_scavenge_card("对讲机")
	assert_not_null(radio, "应能创建对讲机")
	await source.equip(radio)
	source.input.queue_choose_target([target])
	target.input.queue_action(null)
	var original_phase: String = target.in_phase
	var original_actions: int = target.action_count

	await source.use_active_skill(radio.get_all_skills()[0])

	assert_eq(target.in_phase, original_phase)
	assert_eq(target.action_count, original_actions)


func test_tactical_leadership_runs_target_action_without_changing_formal_state() -> void:
	var source := _make_player("Source", "gunslinger")
	var target := _make_player("Target", "surgeon")
	_setup_game(source, target)
	var card: Card = _make_survivor_card("gunslinger", "战术领导力")
	assert_not_null(card, "应能创建战术领导力")
	source.hand.append(card)
	source.input.queue_choose_target([target])
	target.input.queue_action(null)
	var original_phase: String = target.in_phase
	var original_actions: int = target.action_count

	var used: bool = await source.use_card(card)

	assert_true(used)
	assert_eq(target.in_phase, original_phase)
	assert_eq(target.action_count, original_actions)


func test_adrenaline_injection_allows_target_action_without_changing_formal_state() -> void:
	var source := _make_player("Source", "surgeon")
	var target := _make_player("Target", "gunslinger")
	_setup_game(source, target)
	var drawn := _make_plain_card("target_draw")
	target.game_deck.add(drawn)
	var card: Card = _make_survivor_card("surgeon", "注射肾上腺素")
	assert_not_null(card, "应能创建注射肾上腺素")
	source.hand.append(card)
	source.input.queue_choose_target([target])
	target.input.queue_action({"type": "pile_draw", "pile_key": "game_deck"})
	target.input.queue_action(null)
	var original_phase: String = target.in_phase
	var original_actions: int = target.action_count

	var used: bool = await source.use_card(card)

	assert_true(used)
	assert_eq(target.in_phase, original_phase)
	assert_eq(target.action_count, original_actions)
	assert_eq(target.hand, [drawn])


func test_steroid_injection_uses_two_target_hand_cards_for_free() -> void:
	var source := _make_player("Source", "surgeon")
	var target := _make_player("Target", "gunslinger")
	_setup_game(source, target)
	var first := _make_plain_card("first")
	var second := _make_plain_card("second")
	target.hand.append_array([first, second])
	var card: Card = _make_survivor_card("surgeon", "注射类固醇")
	assert_not_null(card, "应能创建注射类固醇")
	source.hand.append(card)
	source.input.queue_choose_target([target])
	target.input.queue_choose_card([first])
	target.input.queue_choose_card([second])
	var original_phase: String = target.in_phase
	var original_actions: int = target.action_count

	var used: bool = await source.use_card(card)

	assert_true(used)
	assert_eq(target.in_phase, original_phase)
	assert_eq(target.action_count, original_actions)
	assert_eq(target.hand.size(), 0)
	assert_eq(target.game_discard_pile.size(), 2)
