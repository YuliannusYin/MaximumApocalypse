extends TestBase

## 「我的斧子去哪儿了？」必须 await 装备，斧子要进装备区。


func test_where_is_my_axe_equips_from_deck() -> void:
	var p: Player = _make_player("Firefighter", 20)
	p.in_phase = "action"
	p.action_count = 2
	var role := RoleCard.new()
	role.equipment_capacity = 5
	p.role_card = role
	p.input = CliPlayerInput.new()
	var survivor: SurvivorData = DataManager.get_survivor("firefighter")
	assert_not_null(survivor)
	var axe_card: Card = null
	var skill_card: Card = null
	for card_dict in survivor.deck:
		var english_name := str(card_dict.get("english_name"))
		if english_name == "reliable_axe" and axe_card == null:
			axe_card = Game._create_game_card_from_dict(card_dict)
		elif english_name == "where_is_my_axe" and skill_card == null:
			skill_card = Game._create_game_card_from_dict(card_dict)
	assert_not_null(axe_card)
	assert_not_null(skill_card)
	p.game_deck.add(axe_card)
	Game.players = [p]
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	var skills: Array = skill_card.get_all_skills()
	assert_gt(skills.size(), 0)
	var event: GameEvent = EventSystem.create_event({"player": p})
	await skills[0].execute_content(p, event)
	assert_eq(p.equipment_zone.size(), 1, "斧子应进入装备区")
	assert_eq(str(p.equipment_zone[0].get("english_name")), "reliable_axe")
	assert_false(p.game_deck.cards.has(axe_card), "牌堆中不应再留着斧子")
