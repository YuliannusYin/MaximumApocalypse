extends TestBase

## 四张跨玩家操作牌的有限操作集成测试。
## 验证目标玩家实际执行操作/出牌时，不会污染自身正式回合状态。


func _make_survivor_player(name: String, survivor_id: String) -> Player:
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


func _make_spend_ap_card(name: String) -> Card:
	var card := _make_plain_card(name)
	var skill := Skill.new()
	skill.active = "action"
	skill.filter = func(player, _t, _e, _g) -> bool:
		return player.get_effective_phase() == "action" and player.get_effective_action_count() > 0
	skill.content = func(_p, _t, _e, _g) -> void:
		return
	card.add_skill(skill)
	return card


func test_walkie_talkie_runs_target_action_without_changing_formal_state() -> void:
	var source := _make_survivor_player("Source", "gunslinger")
	var target := _make_survivor_player("Target", "surgeon")
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
	var source := _make_survivor_player("Source", "gunslinger")
	var target := _make_survivor_player("Target", "surgeon")
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
	var source := _make_survivor_player("Source", "surgeon")
	var target := _make_survivor_player("Target", "gunslinger")
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


func test_steroid_injection_grants_two_hand_only_actions() -> void:
	var source := _make_survivor_player("Source", "surgeon")
	var target := _make_survivor_player("Target", "gunslinger")
	_setup_game(source, target)
	var first := _make_spend_ap_card("first")
	var second := _make_spend_ap_card("second")
	target.hand.append_array([first, second])
	target.game_deck.add(_make_plain_card("should_not_draw"))
	var card: Card = _make_survivor_card("surgeon", "注射类固醇")
	assert_not_null(card, "应能创建注射类固醇")
	source.hand.append(card)
	source.input.queue_choose_target([target])
	target.input.queue_action({"type": "pile_draw", "pile_key": "game_deck"})
	target.input.queue_action({"type": "card", "card": first})
	target.input.queue_action({"type": "card", "card": second})
	var original_phase: String = target.in_phase
	var original_actions: int = target.action_count

	var used: bool = await source.use_card(card)

	assert_true(used)
	assert_eq(target.in_phase, original_phase)
	assert_eq(target.action_count, original_actions)
	assert_eq(target.hand.size(), 0)
	assert_eq(target.game_discard_pile.size(), 2)
	assert_eq(target.game_deck.size(), 1, "类固醇迷你回合不应允许点牌堆摸牌")


func test_scalpel_bonus_applies_to_outgoing_heal() -> void:
	var healer := _make_survivor_player("Healer", "surgeon")
	var target := _make_survivor_player("Target", "gunslinger")
	healer.hp = 20
	target.hp = 10
	_setup_game(healer, target)
	var scalpel: Card = _make_survivor_card("surgeon", "手术刀")
	assert_not_null(scalpel, "应能创建手术刀")
	await healer.equip(scalpel)
	var actions := GameActions.new(healer, Game)
	await actions.recover(target, 1)
	assert_eq(target.hp, 12, "手术刀应对来源于装备者的回复 +1")


func test_scalpel_bonus_does_not_apply_when_healed_by_other() -> void:
	var healer := _make_survivor_player("Healer", "firefighter")
	var target := _make_survivor_player("Target", "surgeon")
	healer.hp = 20
	target.hp = 10
	_setup_game(healer, target)
	var scalpel: Card = _make_survivor_card("surgeon", "手术刀")
	await target.equip(scalpel)
	var actions := GameActions.new(healer, Game)
	await actions.recover(target, 1)
	assert_eq(target.hp, 11, "他人治疗时目标的手术刀不应加成")


func test_scalpel_and_gloves_stack_on_outgoing_heal() -> void:
	var healer := _make_survivor_player("Healer", "surgeon")
	var target := _make_survivor_player("Target", "gunslinger")
	healer.hp = 20
	target.hp = 10
	_setup_game(healer, target)
	await healer.equip(_make_survivor_card("surgeon", "手术刀"))
	await healer.equip(_make_survivor_card("surgeon", "手套"))
	var actions := GameActions.new(healer, Game)
	await actions.recover(target, 1)
	assert_eq(target.hp, 13, "手术刀与手套应叠加为 +2")


func test_hospital_block_source_does_not_trigger_scalpel() -> void:
	var player := _make_survivor_player("Healer", "surgeon")
	player.hp = 10
	_setup_game(player, _make_survivor_player("Other", "gunslinger"))
	await player.equip(_make_survivor_card("surgeon", "手术刀"))
	var hospital := MapBlock.new()
	hospital.block_name = "医院"
	var actions := GameActions.new(player, Game)
	await actions.recover(player, 1, hospital)
	assert_eq(player.hp, 11, "医院回血以地块为 source 时手术刀不应加成")
