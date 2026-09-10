extends Node

## 同进程权威运行时。开局后持有原 ENet server；UI 不再用 GUIPlayerInput 驱动规则。
const ServerLifetime = preload("res://src/net/server_lifetime.gd")
const AIPlayerInputScript = preload("res://src/ai/ai_player_input.gd")
const NetworkPlayerInputScript = preload("res://src/net/net_player_input.gd")

signal match_prepared
signal match_aborted(reason: String)

var lifetime: String = ServerLifetime.OWNER
var _active: bool = false
var _network_inputs: Array = []
var _expected_player_ids: Array = []
var _owner_player_id: String = ""
var _waiting_for_peers: bool = false
var _game_prepared: bool = false
var _wait_started_ms: int = 0
var _visual_relays_connected: bool = false
var _last_monster_mark_counts: Dictionary = {}


func is_active() -> bool:
	return _active and is_inside_tree()


func is_game_prepared() -> bool:
	return _game_prepared


## 大厅点开始：登记应到齐的真人，清掉 listener 座位上的 peer 1。
func begin_match_from_lobby() -> void:
	_active = true
	_game_prepared = false
	_waiting_for_peers = true
	_wait_started_ms = Time.get_ticks_msec()
	var registry: Variant = _registry()
	_owner_player_id = String(NetSession.local_player_id) if NetSession != null else ""
	if _owner_player_id.is_empty() and registry != null:
		_owner_player_id = String(registry.room_owner_player_id())
	_expected_player_ids = registry.connected_human_player_ids() if registry != null else []
	if registry != null:
		registry.start_match()
		if _owner_player_id != "" and not registry.is_player_live_bound(_owner_player_id):
			registry.clear_live_peer(_owner_player_id)


func wait_until_match_prepared() -> bool:
	while is_inside_tree() and _waiting_for_peers and not _game_prepared:
		_poll_match_ready()
		await get_tree().process_frame
	return _game_prepared


func prepare_from_room() -> void:
	if _game_prepared:
		return
	NetId.reset()
	_seed_match()
	Game.initialize_from_room_state()
	_attach_authority_inputs()
	_connect_visual_relays()
	_game_prepared = true
	if NetSession != null and is_instance_valid(NetSession):
		NetSession.request_state_snapshot()
	match_prepared.emit()


func attach_seat_inputs(_gui_for_anim: Variant = null, _visual_cb: Callable = Callable()) -> void:
	_attach_authority_inputs()
	if _visual_cb.is_valid():
		connect_visual_requested(_visual_cb)


func connect_visual_requested(callback: Callable) -> void:
	if not callback.is_valid():
		return
	for network_input in _network_inputs:
		if network_input == null or not is_instance_valid(network_input):
			continue
		if not network_input.visual_requested.is_connected(callback):
			network_input.visual_requested.connect(callback)


func start_game() -> void:
	if Game != null and is_instance_valid(Game):
		Game.start_game()


func abort_owner_loopback_failed() -> void:
	_waiting_for_peers = false
	_game_prepared = false
	match_aborted.emit("owner_loopback_timeout")
	if NetSession != null and is_instance_valid(NetSession):
		NetSession.close_authority_room("owner_loopback_timeout")


func stop() -> void:
	_active = false
	_waiting_for_peers = false
	_network_inputs.clear()
	_disconnect_visual_relays()
	if is_inside_tree():
		queue_free()


func _process(_delta: float) -> void:
	if _waiting_for_peers:
		_poll_match_ready()


func _poll_match_ready() -> void:
	if not _waiting_for_peers:
		return
	var now := Time.get_ticks_msec()
	if _all_expected_bound():
		_waiting_for_peers = false
		prepare_from_room()
		return
	var timeout_ms := 15000
	if NetRegistry != null:
		timeout_ms = int(NetRegistry.MATCH_READY_TIMEOUT_MS)
	if now - _wait_started_ms < timeout_ms:
		return
	var registry: Variant = _registry()
	if registry == null or not registry.is_player_live_bound(_owner_player_id):
		abort_owner_loopback_failed()
		return
	for player_id in _expected_player_ids:
		if registry.is_player_live_bound(String(player_id)):
			continue
		registry.convert_unbound_human_to_ai(String(player_id))
	_waiting_for_peers = false
	prepare_from_room()


func _all_expected_bound() -> bool:
	var registry: Variant = _registry()
	if registry == null:
		return false
	if _expected_player_ids.is_empty():
		return registry.is_player_live_bound(_owner_player_id)
	for player_id in _expected_player_ids:
		if not registry.is_player_live_bound(String(player_id)):
			return false
	return true


func _attach_authority_inputs() -> void:
	_network_inputs.clear()
	if Game == null:
		return
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		if bool(player.is_ai) or _seat_is_ai(int(player.seat_number)):
			var ai_input = AIPlayerInputScript.new()
			ai_input.think_seconds = 0.4
			player.input = ai_input
			player.is_ai = true
			continue
		var network_input = NetworkPlayerInputScript.new()
		network_input.set_request_owner(player)
		player.input = network_input
		_network_inputs.append(network_input)


func handoff_seats_to_ai(player_id: String) -> void:
	if Game == null or player_id.is_empty():
		return
	var seat_ids: Dictionary = _seat_ids_for_controller(player_id)
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		if not seat_ids.has(int(player.seat_number)):
			continue
		var current_input: Variant = player.input
		if current_input != null and current_input.has_method("detach"):
			current_input.detach()
			_network_inputs.erase(current_input)
		var ai_input = AIPlayerInputScript.new()
		ai_input.think_seconds = 0.4
		player.input = ai_input
		player.is_ai = true


func restore_network_inputs(player_id: String) -> void:
	if Game == null or player_id.is_empty():
		return
	var seat_ids: Dictionary = _seat_ids_for_controller(player_id)
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		if not seat_ids.has(int(player.seat_number)):
			continue
		var network_input = NetworkPlayerInputScript.new()
		network_input.set_request_owner(player)
		player.input = network_input
		player.is_ai = false
		_network_inputs.append(network_input)


func _seat_ids_for_controller(player_id: String) -> Dictionary:
	var result := {}
	var registry: Variant = _registry()
	if registry == null:
		return result
	for seat in registry.seats:
		if String(seat.get("controller_id", "")) == player_id:
			result[int(seat.get("seat_id", -1))] = true
	return result


func _seat_is_ai(seat_number: int) -> bool:
	var registry: Variant = _registry()
	if registry == null or seat_number < 0 or seat_number >= registry.seats.size():
		return false
	return String(registry.seats[seat_number].get("control_mode", "")) == "ai"


func _connect_visual_relays() -> void:
	if _visual_relays_connected or EventBus == null:
		return
	_bind_visual_relay(EventBus.player_moved, _relay_player_moved)
	_bind_visual_relay(EventBus.block_revealed, _relay_block_revealed)
	_bind_visual_relay(EventBus.block_destroyed, _relay_block_destroyed)
	_bind_visual_relay(EventBus.game_over, _relay_game_over)
	_bind_visual_relay(EventBus.turn_started, _relay_turn_started)
	_bind_visual_relay(EventBus.phase_changed, _relay_phase_changed)
	_bind_visual_relay(EventBus.monster_mark_changed, _relay_block_mark_changed)
	_bind_visual_relay(EventBus.objective_mark_changed, _relay_block_mark_changed)
	_bind_visual_relay(EventBus.monster_died, _relay_monster_died)
	_bind_visual_relay(EventBus.monster_spawned, _relay_monster_spawned)
	_bind_visual_relay(EventBus.monster_engaged_target_changed, _relay_monster_engaged)
	_bind_visual_relay(EventBus.player_hp_changed, _relay_player_state_changed)
	_bind_visual_relay(EventBus.player_died, _relay_player_state_changed)
	_bind_visual_relay(EventBus.equipment_equipped, _relay_player_state_changed)
	_bind_visual_relay(EventBus.equipment_unequipped, _relay_player_state_changed)
	_bind_visual_relay(EventBus.card_drawn, _relay_player_state_changed)
	_bind_visual_relay(EventBus.card_discarded, _relay_player_state_changed)
	_bind_visual_relay(EventBus.card_used, _relay_player_state_changed)
	_bind_visual_relay(EventBus.card_settlement_started, _relay_player_state_changed)
	_bind_visual_relay(EventBus.card_settlement_finished, _relay_player_state_changed)
	_bind_visual_relay(EventBus.scavenge_drawn, _relay_player_state_changed)
	_bind_visual_relay(EventBus.monster_card_drawn, _relay_player_state_changed)
	_bind_visual_relay(EventBus.damage_taken, _relay_damage_taken)
	_bind_visual_relay(EventBus.hp_recovered, _relay_hp_recovered)
	_bind_visual_relay(EventBus.player_hunger_changed, _relay_hunger_changed)
	_bind_visual_relay(EventBus.action_consumed, _relay_action_consumed)
	_seed_monster_mark_counts()
	_visual_relays_connected = true


func _disconnect_visual_relays() -> void:
	if not _visual_relays_connected or EventBus == null:
		return
	_unbind_visual_relay(EventBus.player_moved, _relay_player_moved)
	_unbind_visual_relay(EventBus.block_revealed, _relay_block_revealed)
	_unbind_visual_relay(EventBus.block_destroyed, _relay_block_destroyed)
	_unbind_visual_relay(EventBus.game_over, _relay_game_over)
	_unbind_visual_relay(EventBus.turn_started, _relay_turn_started)
	_unbind_visual_relay(EventBus.phase_changed, _relay_phase_changed)
	_unbind_visual_relay(EventBus.monster_mark_changed, _relay_block_mark_changed)
	_unbind_visual_relay(EventBus.objective_mark_changed, _relay_block_mark_changed)
	_unbind_visual_relay(EventBus.monster_died, _relay_monster_died)
	_unbind_visual_relay(EventBus.monster_spawned, _relay_monster_spawned)
	_unbind_visual_relay(EventBus.monster_engaged_target_changed, _relay_monster_engaged)
	_unbind_visual_relay(EventBus.player_hp_changed, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.player_died, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.equipment_equipped, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.equipment_unequipped, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.card_drawn, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.card_discarded, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.card_used, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.card_settlement_started, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.card_settlement_finished, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.scavenge_drawn, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.monster_card_drawn, _relay_player_state_changed)
	_unbind_visual_relay(EventBus.damage_taken, _relay_damage_taken)
	_unbind_visual_relay(EventBus.hp_recovered, _relay_hp_recovered)
	_unbind_visual_relay(EventBus.player_hunger_changed, _relay_hunger_changed)
	_unbind_visual_relay(EventBus.action_consumed, _relay_action_consumed)
	_last_monster_mark_counts.clear()
	_visual_relays_connected = false


func _bind_visual_relay(sig: Signal, callback: Callable) -> void:
	if not sig.is_connected(callback):
		sig.connect(callback)


func _unbind_visual_relay(sig: Signal, callback: Callable) -> void:
	if sig.is_connected(callback):
		sig.disconnect(callback)


func _seed_monster_mark_counts() -> void:
	_last_monster_mark_counts.clear()
	if Game == null or not is_instance_valid(Game):
		return
	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		_last_monster_mark_counts[_block_mark_key(block)] = _monster_mark_count(block)


func _relay_player_moved(player: Variant, source_block: Variant, target_block: Variant) -> void:
	_broadcast_visual("player_moved", {
		"player": player,
		"source_block": source_block,
		"target_block": target_block,
	})


func _relay_block_revealed(block: Variant, _player: Variant) -> void:
	_broadcast_visual("block_revealed", {"block": block})


func _relay_block_destroyed(block: Variant, _source: Variant) -> void:
	if block == null or not is_instance_valid(block):
		return
	var coordinate: Dictionary = block.get("coordinate")
	_broadcast_visual("block_destroyed", {
		"x": int(coordinate.get("x", 0)),
		"y": int(coordinate.get("y", 0)),
	})


func _relay_game_over(result: int) -> void:
	_broadcast_visual("game_over", {
		"result": result,
		"stats": _authority_stats_payload(),
	})
	if NetSession != null and is_instance_valid(NetSession):
		NetSession.request_state_snapshot()


func _relay_turn_started(player: Variant) -> void:
	_broadcast_visual("turn_started", {
		"seat_id": _seat_of(player),
	})


func _relay_phase_changed(player: Variant, old_phase: String, new_phase: String) -> void:
	_broadcast_visual("phase_changed", {
		"seat_id": _seat_of(player),
		"old_phase": old_phase,
		"new_phase": new_phase,
	})


func _relay_block_mark_changed(block: Variant) -> void:
	if block == null or not is_instance_valid(block):
		return
	var key := _block_mark_key(block)
	var new_count := _monster_mark_count(block)
	var old_count := int(_last_monster_mark_counts.get(key, 0))
	_last_monster_mark_counts[key] = new_count
	if new_count == old_count:
		return
	_broadcast_visual("block_mark_pulse", {
		"block": block,
		"increased": new_count > old_count,
	})


func _relay_monster_died(monster: Variant, _source: Variant) -> void:
	var holder: Variant = _find_monster_holder(monster)
	if holder == null:
		return
	_broadcast_visual("monster_died_feedback", {
		"seat_id": _seat_of(holder),
	})


func _relay_monster_spawned(_monster: Variant, player: Variant) -> void:
	_relay_player_state_changed(player)


func _relay_monster_engaged(_monster: Variant, old_target: Variant, new_target: Variant) -> void:
	_relay_player_state_changed(old_target)
	if new_target != old_target:
		_relay_player_state_changed(new_target)


func _relay_player_state_changed(player: Variant, _arg1: Variant = null, _arg2: Variant = null) -> void:
	_broadcast_visual("player_state_changed", {
		"seat_id": _seat_of(player),
	})


func _relay_damage_taken(target: Variant, source: Variant, amount: int) -> void:
	var shake := false
	if source != null and is_instance_valid(source) and source.has_method("get"):
		shake = source.get("monster_type") != null
	_broadcast_visual("player_damage_feedback", {
		"seat_id": _seat_of(target),
		"amount": amount,
		"shake": shake,
	})


func _relay_hp_recovered(player: Variant, amount: int) -> void:
	_broadcast_visual("player_heal_feedback", {
		"seat_id": _seat_of(player),
		"amount": amount,
	})


func _relay_hunger_changed(player: Variant, _old_value: int, _new_value: int) -> void:
	_relay_player_state_changed(player)
	_broadcast_visual("player_hunger_feedback", {
		"seat_id": _seat_of(player),
	})


func _relay_action_consumed(player: Variant, _num: int) -> void:
	_relay_player_state_changed(player)
	_broadcast_visual("player_action_feedback", {
		"seat_id": _seat_of(player),
	})


func _seat_of(entity: Variant) -> int:
	if entity == null or not is_instance_valid(entity) or not entity.has_method("get"):
		return -1
	var seat_value: Variant = entity.get("seat_number")
	return int(seat_value) if seat_value != null else -1


func _block_mark_key(block: Variant) -> String:
	var coordinate: Dictionary = {}
	if block != null and block.has_method("get"):
		var raw: Variant = block.get("coordinate")
		if raw is Dictionary:
			coordinate = raw
	return "%d,%d" % [int(coordinate.get("x", 0)), int(coordinate.get("y", 0))]


func _monster_mark_count(block: Variant) -> int:
	if block != null and is_instance_valid(block) and block.has_method("count_monster_mark"):
		return int(block.count_monster_mark())
	return 0


func _find_monster_holder(monster: Variant) -> Variant:
	if monster == null or not is_instance_valid(monster):
		return null
	if Game != null and is_instance_valid(Game):
		for player in Game.players:
			if player == null or not is_instance_valid(player):
				continue
			if "monster_zone" in player and player.monster_zone.has(monster):
				return player
	var engaged: Variant = monster.get("attack_target") if monster.has_method("get") else null
	if engaged != null and is_instance_valid(engaged):
		return engaged
	return null


func _authority_stats_payload() -> Dictionary:
	if Game == null or not is_instance_valid(Game) or Game.stats_tracker == null:
		return {}
	if not Game.stats_tracker.has_method("to_network_dict"):
		return {}
	return Game.stats_tracker.to_network_dict(Game.players)


func _broadcast_visual(event_name: String, payload: Dictionary) -> void:
	if NetSession != null and is_instance_valid(NetSession):
		NetSession.broadcast_game_event(event_name, payload)


func _seed_match() -> void:
	var registry: Variant = _registry()
	if registry == null:
		return
	seed(int(registry.match_seed))


func _registry() -> Variant:
	if NetSession == null:
		return null
	return NetSession.registry
