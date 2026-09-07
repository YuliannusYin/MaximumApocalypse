extends TestBase

## AiMissionHints 行进目标：未完成行动点优先于脚下集结地名。

const AiMissionHintsScript = preload("res://src/ai/ai_mission_hints.gd")


func _setup_rescue_fuel_rally() -> MissionConfig:
	var mc := MissionConfig.new()
	var rescue := MissionComponentSpendActionRescue.new()
	rescue.params = {"block_name": "警察局"}
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	mc.action_components = [rescue, fuel]
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	return mc


func _map_van_police() -> Dictionary:
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var east: MapBlock = _make_block("旷野", 1, 0, true)
	var west: MapBlock = _make_block("旷野", -1, 0, true)
	var police: MapBlock = _make_block("警察局", 2, 0, true)
	var wild: MapBlock = _make_block("旷野", 3, 0, true)
	Game.map_area = [van, east, west, police, wild]
	return {"van": van, "east": east, "west": west, "police": police, "wild": wild}


func _dest_names(player: Player) -> Array:
	var hints = AiMissionHintsScript.new()
	var names: Array = []
	for block in hints.travel_destination_blocks(player):
		names.append(block.block_name)
	return names


func test_at_van_without_fuel_travels_to_police() -> void:
	_setup_rescue_fuel_rally()
	var blocks: Dictionary = _map_van_police()
	var p: Player = _make_player("AI")
	p.current_block = blocks["van"]
	var hints = AiMissionHintsScript.new()
	assert_eq(_dest_names(p), ["警察局"], "没燃料时行动层只有警察局")
	assert_eq(hints.nearest_travel_block(p), blocks["police"])
	assert_eq(hints.nearest_objective_distance(p), 2)


func test_at_van_with_fuel_stays_because_van_is_nearer() -> void:
	_setup_rescue_fuel_rally()
	var blocks: Dictionary = _map_van_police()
	var p: Player = _make_player("AI")
	p.current_block = blocks["van"]
	p.hand.append(_make_card("燃料"))
	var hints = AiMissionHintsScript.new()
	var names: Array = _dest_names(p)
	assert_true(names.has("面包车"), "有燃料应把面包车列入行动点")
	assert_true(names.has("警察局"), "解救未完成应仍列入警察局")
	assert_eq(hints.nearest_travel_block(p), blocks["van"], "脚下的加油点更近")
	assert_eq(hints.nearest_objective_distance(p), 0)


func test_wilderness_with_fuel_picks_nearer_police() -> void:
	_setup_rescue_fuel_rally()
	var blocks: Dictionary = _map_van_police()
	var p: Player = _make_player("AI")
	p.current_block = blocks["wild"]
	p.hand.append(_make_card("燃料"))
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.nearest_travel_block(p), blocks["police"], "警察局比面包车近")
	assert_eq(hints.nearest_objective_distance(p), 1)


func test_rescue_done_without_fuel_falls_back_to_rally() -> void:
	var mc: MissionConfig = _setup_rescue_fuel_rally()
	mc.mission_state["scientist_rescued"] = true
	var blocks: Dictionary = _map_van_police()
	var p: Player = _make_player("AI")
	p.current_block = blocks["wild"]
	var hints = AiMissionHintsScript.new()
	assert_eq(_dest_names(p), ["面包车"], "无未完成行动点时应回退集结")
	assert_eq(hints.nearest_travel_block(p), blocks["van"])


func _setup_fuel_only() -> MissionConfig:
	var mc := MissionConfig.new()
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	mc.action_components = [fuel]
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	return mc


func _map_van_gas() -> Dictionary:
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var gas: MapBlock = _make_block("加油站", 2, 0, true)
	gas.scavenge_colors = PackedStringArray(["red"])
	var mall: MapBlock = _make_block("购物中心", 1, 1, true)
	mall.scavenge_colors = PackedStringArray(["blue"])
	Game.map_area = [van, gas, mall]
	Game.red_scavenge_pile = Pile.new()
	Game.red_scavenge_pile.add(_make_scavenge_card("燃料", "red"))
	Game.red_scavenge_pile.add(_make_scavenge_card("燃料", "red"))
	Game.blue_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile.add(_make_scavenge_card("燃料", "blue"))
	return {"van": van, "gas": gas, "mall": mall}


func test_without_fuel_gathers_at_red_scavenge_not_van() -> void:
	_setup_fuel_only()
	var blocks: Dictionary = _map_van_gas()
	var p: Player = _make_player("AI")
	p.current_block = blocks["van"]
	Game.players = [p]
	var hints = AiMissionHintsScript.new()
	assert_eq(_dest_names(p), ["加油站"], "没燃料时应去剩余燃料最多的红拾荒格")
	assert_eq(hints.nearest_travel_block(p), blocks["gas"])
	assert_eq(hints.nearest_objective_distance(p), 2)


func test_with_fuel_still_travels_to_van() -> void:
	_setup_fuel_only()
	var blocks: Dictionary = _map_van_gas()
	var p: Player = _make_player("AI")
	p.current_block = blocks["gas"]
	p.hand.append(_make_card("燃料"))
	Game.players = [p]
	var hints = AiMissionHintsScript.new()
	assert_eq(_dest_names(p), ["面包车"], "持有燃料时应走加油行动点")
	assert_eq(hints.nearest_travel_block(p), blocks["van"])


func test_at_gas_stays_because_gather_distance_zero() -> void:
	_setup_fuel_only()
	var blocks: Dictionary = _map_van_gas()
	var p: Player = _make_player("AI")
	p.current_block = blocks["gas"]
	Game.players = [p]
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.nearest_objective_distance(p), 0, "已在最佳采集格时距离应为 0")
	assert_true(hints.is_staying_to_gather(p))


func test_remaining_needed_count_drops_when_party_holds_fuel() -> void:
	_setup_fuel_only()
	var p: Player = _make_player("AI")
	Game.players = [p]
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.remaining_needed_count("燃料"), 4, "无人持有时应缺 4")
	p.hand.append(_make_card("燃料"))
	assert_eq(hints.remaining_needed_count("燃料"), 3, "持有 1 桶后应缺 3")


func test_player_holds_needed_item_when_fuel_not_submitted() -> void:
	_setup_fuel_only()
	var p: Player = _make_player("AI")
	Game.players = [p]
	var hints = AiMissionHintsScript.new()
	assert_false(hints.player_holds_needed_item(p), "没拿燃料时应为假")
	p.hand.append(_make_card("燃料"))
	assert_true(hints.player_holds_needed_item(p), "手里有未交满的燃料时应为真")
	p.equipment_zone.append(_make_equipment("燃料"))
	assert_true(hints.player_holds_needed_item(p), "装备区有燃料也应为真")


func test_path_distance_around_hole_to_van() -> void:
	var coords: Array = [
		[2, 0], [3, 0], [4, 0],
		[1, 1], [2, 1], [4, 1], [5, 1],
		[2, 2], [3, 2], [4, 2],
	]
	var by_coord: Dictionary = {}
	var map_area: Array = []
	for c in coords:
		var block_name: String = "旷野"
		if int(c[0]) == 5 and int(c[1]) == 1:
			block_name = "面包车"
		var block: MapBlock = _make_block(block_name, int(c[0]), int(c[1]), true)
		map_area.append(block)
		by_coord["%d,%d" % [int(c[0]), int(c[1])]] = block
	Game.map_area = map_area
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	var mc := MissionConfig.new()
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	var p: Player = _make_player("AI")
	p.current_block = by_coord["2,1"]
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.nearest_travel_block(p), by_coord["5,1"])
	assert_eq(hints.nearest_objective_distance(p), 5, "曼哈顿 3，绕空洞图距离 5")
	assert_eq(hints.path_distance(by_coord["2,0"], by_coord["5,1"]), 4)
	assert_eq(hints.path_distance(by_coord["1,1"], by_coord["5,1"]), 6)


func test_party_leader_prefers_courier() -> void:
	_setup_fuel_only()
	var blocks: Dictionary = _map_van_gas()
	var scout: Player = _make_player("Scout")
	var courier: Player = _make_player("Courier")
	scout.current_block = blocks["gas"]
	courier.current_block = blocks["mall"]
	courier.hand.append(_make_card("燃料"))
	Game.players = [scout, courier]
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.party_leader(scout), courier, "持燃料的信使应当领队")
	assert_eq(hints.nearest_travel_block(scout), blocks["mall"], "其他人应跟随信使而不是继续采集")


func test_party_leader_is_nearest_to_personal_dest() -> void:
	_setup_fuel_only()
	var blocks: Dictionary = _map_van_gas()
	var near: Player = _make_player("Near")
	var far: Player = _make_player("Far")
	near.current_block = blocks["gas"]
	far.current_block = blocks["van"]
	Game.players = [near, far]
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.party_leader(far), near, "无人当信使时离采集格更近的人是领队")
	assert_eq(hints.nearest_travel_block(far), blocks["gas"], "掉队者应跟去领队所在格")


func test_follow_anchor_uses_safe_neighbor_when_leader_on_wilderness() -> void:
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var wild: MapBlock = _make_block("旷野", 1, 0, true)
	var hospital: MapBlock = _make_block("医院", 1, 1, true)
	Game.map_area = [van, wild, hospital]
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	var mc := MissionConfig.new()
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	var leader: Player = _make_player("Leader")
	var follower: Player = _make_player("Follower")
	leader.current_block = wild
	follower.current_block = hospital
	Game.players = [leader, follower]
	var hints = AiMissionHintsScript.new()
	assert_eq(hints.follow_anchor_block(leader), van, "领队在旷野时应把安全邻格当跟随锚点")
	assert_eq(hints.nearest_travel_block(follower), van, "跟随者不应把旷野当目标")
