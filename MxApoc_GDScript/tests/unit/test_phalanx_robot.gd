extends TestBase

## 方阵机器人：跨怪物 on_take_damage 广播、射程减伤叠加与下限 0。


func _find_monster_data(pack_type: String, english_name: String) -> MonsterCardData:
	for d in DataManager.get_monster_pack(pack_type):
		if d.english_name == english_name:
			return d
	return null


func _spawn_robot(english_name: String, holder: Player) -> Monster:
	var data: MonsterCardData = _find_monster_data("robot", english_name)
	assert_not_null(data, "应能找到怪物数据 %s" % english_name)
	var card: MonsterCard = Game._create_monster_card_from_data(data, "robot")
	var m: Monster = card.instantiate(holder)
	holder.monster_zone.append(m)
	return m


func _setup_map(players: Array, blocks: Array) -> void:
	Game.players = players
	Game.map_area = blocks


func test_nearby_robot_damage_reduced_by_one() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	_setup_map([holder, attacker], [origin])
	_spawn_robot("phalanx_robot", holder)
	var drone: Monster = _spawn_robot("laser_drone", holder)
	var hp_before: int = drone.hp
	await drone.damage(3, attacker)
	assert_eq(drone.hp, hp_before - 2, "同地块方阵应使其他机器人受伤 -1")


func test_two_phalanxes_stack() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	_setup_map([holder, attacker], [origin])
	_spawn_robot("phalanx_robot", holder)
	_spawn_robot("phalanx_robot", holder)
	var drone: Monster = _spawn_robot("laser_drone", holder)
	var hp_before: int = drone.hp
	await drone.damage(3, attacker)
	assert_eq(drone.hp, hp_before - 1, "两只方阵应叠加为 -2")


func test_phalanx_self_damage_reduced_once() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	_setup_map([holder, attacker], [origin])
	var phalanx: Monster = _spawn_robot("phalanx_robot", holder)
	var hp_before: int = phalanx.hp
	await phalanx.damage(3, attacker)
	assert_eq(phalanx.hp, hp_before - 2, "方阵自身受伤只应 -1，不应因广播给自己而 -2")


func test_out_of_range_robot_not_reduced() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var far: MapBlock = _make_block("远处", 3, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var far_holder: Player = _make_player("远处持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	far_holder.current_block = far
	_setup_map([holder, far_holder, attacker], [origin, far])
	_spawn_robot("phalanx_robot", holder)
	var drone: Monster = _spawn_robot("laser_drone", far_holder)
	var hp_before: int = drone.hp
	await drone.damage(3, attacker)
	assert_eq(drone.hp, hp_before - 3, "中距离外的机器人不应被减伤")


func test_adjacent_robot_is_in_medium_range() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var adj: MapBlock = _make_block("相邻", 1, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var adj_holder: Player = _make_player("相邻持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	adj_holder.current_block = adj
	_setup_map([holder, adj_holder, attacker], [origin, adj])
	_spawn_robot("phalanx_robot", holder)
	var drone: Monster = _spawn_robot("laser_drone", adj_holder)
	var hp_before: int = drone.hp
	await drone.damage(3, attacker)
	assert_eq(drone.hp, hp_before - 2, "相邻地块上的机器人应在中距离内被减伤")


func test_non_robot_not_reduced() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	_setup_map([holder, attacker], [origin])
	_spawn_robot("phalanx_robot", holder)
	var zombie: Monster = _make_monster("僵尸狗")
	zombie.monster_type = "zombie"
	zombie.hp = 8
	zombie.max_hp = 8
	zombie.attack_target = holder
	holder.monster_zone.append(zombie)
	await zombie.damage(3, attacker)
	assert_eq(zombie.hp, 5, "非机器人受伤不应被方阵减伤")


func test_one_damage_floors_at_zero() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	_setup_map([holder, attacker], [origin])
	_spawn_robot("phalanx_robot", holder)
	var drone: Monster = _spawn_robot("laser_drone", holder)
	var hp_before: int = drone.hp
	await drone.damage(1, attacker)
	assert_eq(drone.hp, hp_before, "1 点伤害被减 1 后应为 0，不扣血")


func test_stacked_reduction_does_not_heal() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	_setup_map([holder, attacker], [origin])
	_spawn_robot("phalanx_robot", holder)
	_spawn_robot("phalanx_robot", holder)
	var drone: Monster = _spawn_robot("laser_drone", holder)
	var hp_before: int = drone.hp
	await drone.damage(1, attacker)
	assert_eq(drone.hp, hp_before, "叠加减伤低于 0 时不得回血")


func test_player_damage_does_not_broadcast() -> void:
	var origin: MapBlock = _make_block("原点", 0, 0, true)
	var victim: Player = _make_player("受害者", 20)
	var holder: Player = _make_player("持有者", 20)
	var attacker: Player = _make_player("攻击者", 20)
	holder.current_block = origin
	victim.current_block = origin
	_setup_map([victim, holder, attacker], [origin])
	var phalanx: Monster = _spawn_robot("phalanx_robot", holder)
	var called: Array = []
	var spy: Skill = Skill.new()
	spy.trigger = "on_take_damage"
	spy.content = func(_p, _t, _ev, _g) -> void:
		called.append("broadcast")
	phalanx.add_skill(spy)
	await victim.damage(3, attacker)
	assert_eq(victim.hp, 17, "玩家受伤不应被方阵减伤")
	assert_eq(called.size(), 0, "玩家受伤时不应向其他怪物广播 on_take_damage")
