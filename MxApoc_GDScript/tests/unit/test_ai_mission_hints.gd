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
