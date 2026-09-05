extends TestBase

## 外星科学家-协同强化：跨怪物 on_deal_damage 广播与叠加。


func _find_monster_data(pack_type: String, english_name: String) -> MonsterCardData:
	for d in DataManager.get_monster_pack(pack_type):
		if d.english_name == english_name:
			return d
	return null


func _spawn_alien(english_name: String, holder: Player) -> Monster:
	var data: MonsterCardData = _find_monster_data("alien", english_name)
	assert_not_null(data, "应能找到怪物数据 %s" % english_name)
	var card: MonsterCard = Game._create_monster_card_from_data(data, "alien")
	var m: Monster = card.instantiate(holder)
	holder.monster_zone.append(m)
	return m


func test_other_alien_damage_gains_plus_one() -> void:
	var victim: Player = _make_player("受害者", 28)
	var holder: Player = _make_player("持有者", 28)
	Game.players = [victim, holder]
	_spawn_alien("alien_scientist", holder)
	var soldier: Monster = _spawn_alien("alien_soldier", holder)
	await victim.damage(soldier.damage_value, soldier, "monster_attack")
	assert_eq(victim.hp, 28 - (soldier.damage_value + 1), "科学家在场时外星士兵伤害应 +1")


func test_two_scientists_stack() -> void:
	var victim: Player = _make_player("受害者", 28)
	var holder: Player = _make_player("持有者", 28)
	Game.players = [victim, holder]
	_spawn_alien("alien_scientist", holder)
	_spawn_alien("alien_scientist", holder)
	var soldier: Monster = _spawn_alien("alien_soldier", holder)
	await victim.damage(soldier.damage_value, soldier, "monster_attack")
	assert_eq(victim.hp, 28 - (soldier.damage_value + 2), "两只科学家应叠加为 +2")


func test_scientist_own_attack_plus_one_not_double() -> void:
	var victim: Player = _make_player("受害者", 28)
	var holder: Player = _make_player("持有者", 28)
	Game.players = [victim, holder]
	var scientist: Monster = _spawn_alien("alien_scientist", holder)
	await victim.damage(scientist.damage_value, scientist, "monster_attack")
	assert_eq(victim.hp, 28 - (scientist.damage_value + 1), "科学家自身攻击只应 +1，不应因广播给自己而 +2")


func test_non_alien_monster_not_boosted() -> void:
	var victim: Player = _make_player("受害者", 28)
	var holder: Player = _make_player("持有者", 28)
	Game.players = [victim, holder]
	_spawn_alien("alien_scientist", holder)
	var zombie: Monster = _make_monster("僵尸狗")
	zombie.monster_type = "zombie"
	zombie.damage_value = 4
	zombie.attack_target = holder
	holder.monster_zone.append(zombie)
	await victim.damage(zombie.damage_value, zombie, "monster_attack")
	assert_eq(victim.hp, 28 - zombie.damage_value, "非外星怪物攻击不应被协同强化")


func test_scientist_non_attack_damage_also_boosted() -> void:
	var victim: Player = _make_player("受害者", 28)
	var holder: Player = _make_player("持有者", 28)
	Game.players = [victim, holder]
	var scientist: Monster = _spawn_alien("alien_scientist", holder)
	await victim.damage(6, scientist)
	assert_eq(victim.hp, 28 - 7, "以科学家为来源的非攻击伤害也应 +1（勒索装备）")


func test_player_damage_does_not_broadcast() -> void:
	var victim: Player = _make_player("受害者", 28)
	var attacker: Player = _make_player("攻击者", 28)
	var holder: Player = _make_player("持有者", 28)
	Game.players = [victim, attacker, holder]
	var scientist: Monster = _spawn_alien("alien_scientist", holder)
	var called: Array = []
	var spy: Skill = Skill.new()
	spy.trigger = "on_deal_damage"
	spy.content = func(_p, _t, _ev, _g) -> void:
		called.append("broadcast")
	scientist.add_skill(spy)
	await victim.damage(3, attacker)
	assert_eq(victim.hp, 25, "玩家伤害不应被协同强化")
	assert_eq(called.size(), 0, "玩家造成伤害时不应向其他怪物广播 on_deal_damage")
