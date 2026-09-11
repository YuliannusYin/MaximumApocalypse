extends TestBase

## 手榴弹同格溅射：主目标致死后仍应对同地块其他目标造成 3 点伤害。


func _grenade_content() -> String:
	var survivor: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(survivor, "应能加载枪手")
	for card in survivor.deck:
		if str(card.get("english_name")) != "grenade":
			continue
		var skills: Variant = card.get("skills", [])
		if skills is Array and not skills.is_empty():
			return str(skills[0].get("content", ""))
	return ""


func test_grenade_splash_hits_other_monster_and_player_after_killing_primary() -> void:
	var p: Player = _make_player("Gunslinger", 20)
	p.in_phase = "action"
	p.action_count = 2
	var block: MapBlock = _make_block("street", 0, 0, true)
	p.current_block = block
	var primary: Monster = Monster.new()
	primary.monster_name = "主目标"
	primary.hp = 3
	primary.max_hp = 3
	primary.attack_target = p
	var secondary: Monster = Monster.new()
	secondary.monster_name = "同格怪"
	secondary.hp = 10
	secondary.max_hp = 10
	secondary.attack_target = p
	p.monster_zone = [primary, secondary]
	Game.players = [p]
	Game.map_area = [block]
	var content: String = _grenade_content()
	assert_false(content.is_empty(), "应读到手榴弹 content")
	var skill := Skill.new()
	skill.content = CodeExecutor.compile_content(content)
	var event: GameEvent = EventSystem.create_event({"player": p, "target": primary})
	await skill.execute_content(p, event)
	assert_eq(primary.hp, 0, "主目标应受到 5 点伤害")
	assert_eq(secondary.hp, 7, "同格另一只怪应受到 3 点溅射")
	assert_eq(p.hp, 17, "同格玩家应受到 3 点溅射")
