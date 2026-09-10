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
		if _owner_player_id != "":
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
	Game.initialize_from_room_state()
	_attach_authority_inputs()
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
		player.input = network_input
		_network_inputs.append(network_input)


func _seat_is_ai(seat_number: int) -> bool:
	var registry: Variant = _registry()
	if registry == null or seat_number < 0 or seat_number >= registry.seats.size():
		return false
	return String(registry.seats[seat_number].get("control_mode", "")) == "ai"


func _registry() -> Variant:
	if NetSession == null:
		return null
	return NetSession.registry
