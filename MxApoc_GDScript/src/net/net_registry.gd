class_name NetRegistry
extends RefCounted

## 房间玩家、座位和权威快照的内存模型。
const NetProtocol = preload("res://src/net/net_protocol.gd")
const NetId = preload("res://src/net/net_id.gd")

var room_id: String = ""
var host_name: String = ""
var phase: String = "closed"
var online_multiplayer: bool = false
var port: int = NetProtocol.DEFAULT_PORT
var settings_revision: int = 0
var match_id: String = ""
var match_seed: int = 0
var server_sequence: int = 0
var mission_mode: String = "random"
var mission_id: int = -1
var variants: Dictionary = {}
const RECONNECT_TIMEOUT_MS := 5 * 60 * 1000
const MATCH_READY_TIMEOUT_MS := 15 * 1000
var players: Dictionary = {}
var seats: Array = []

func create_host(name: String, listen_port: int, configured_seats: Array) -> Dictionary:
	room_id = NetId.make_id("r")
	host_name = NetProtocol.normalize_nickname(name)
	port = listen_port
	phase = "lobby"
	online_multiplayer = true
	var host_id := NetId.make_id("p")
	var token := _make_token()
	players[host_id] = {
		"player_id": host_id,
		"display_name": host_name,
		"peer_id": 1,
		"reconnect_token_hash": _hash_token(token),
		"connection_state": "connected",
		"seat_ids": [],
		"is_host": true,
		"last_seen_ms": Time.get_ticks_msec(),
	}
	_set_seats(configured_seats, host_id)
	return {"player_id": host_id, "reconnect_token": token}

func add_player(display_name: String, peer_id: int) -> Dictionary:
	if phase != "lobby":
		return {}
	if players.size() >= MAX_PLAYERS:
		return {}
	var player_id := NetId.make_id("p")
	var token := _make_token()
	players[player_id] = {
		"player_id": player_id,
		"display_name": NetProtocol.normalize_nickname(display_name),
		"peer_id": peer_id,
		"reconnect_token_hash": _hash_token(token),
		"connection_state": "connected",
		"seat_ids": [],
		"is_host": false,
		"last_seen_ms": Time.get_ticks_msec(),
	}
	return {"player_id": player_id, "reconnect_token": token}

func disconnect_player(player_id: String) -> void:
	if not players.has(player_id):
		return
	var player: Dictionary = players[player_id]
	player["peer_id"] = 0
	player["connection_state"] = "disconnected"
	player["last_seen_ms"] = Time.get_ticks_msec()
	players[player_id] = player
	for seat in seats:
		if String(seat.get("controller_id", "")) == player_id:
			seat["control_mode"] = "ai"

## 开局移交：清掉 listener 的 peer_id==1，不当成掉线、不改座位。
func clear_live_peer(player_id: String) -> void:
	if not players.has(player_id):
		return
	var player: Dictionary = players[player_id]
	player["peer_id"] = 0
	player["connection_state"] = "connected"
	players[player_id] = player


func connected_human_player_ids() -> Array:
	var ids: Array = []
	for player_id in players:
		var player: Dictionary = players[player_id]
		if String(player.get("connection_state", "")) != "connected":
			continue
		if _player_has_human_seat(String(player_id)):
			ids.append(String(player_id))
	return ids


func is_player_live_bound(player_id: String) -> bool:
	if not players.has(player_id):
		return false
	return int(players[player_id].get("peer_id", 0)) > 1


func convert_unbound_human_to_ai(player_id: String) -> void:
	if not players.has(player_id):
		return
	var player: Dictionary = players[player_id]
	player["peer_id"] = 0
	player["connection_state"] = "disconnected"
	player["last_seen_ms"] = Time.get_ticks_msec()
	players[player_id] = player
	for seat in seats:
		if String(seat.get("controller_id", "")) == player_id:
			seat["control_mode"] = "ai"


func room_owner_player_id() -> String:
	for player_id in players:
		if bool(players[player_id].get("is_host", false)):
			return String(player_id)
	return ""


func _player_has_human_seat(player_id: String) -> bool:
	for seat in seats:
		if String(seat.get("controller_id", "")) == player_id \
				and String(seat.get("control_mode", "")) == "human":
			return true
	return false


func reconnect_player_by_token(token: String, peer_id: int) -> String:
	var token_hash := _hash_token(token)
	var player_id := ""
	for candidate_id in players:
		var candidate: Dictionary = players[candidate_id]
		if String(candidate.get("reconnect_token_hash", "")) == token_hash:
			player_id = String(candidate_id)
			break
	if player_id.is_empty():
		return ""
	var player: Dictionary = players[player_id]
	player["peer_id"] = peer_id
	player["connection_state"] = "connected"
	player["last_seen_ms"] = Time.get_ticks_msec()
	players[player_id] = player
	for seat in seats:
		if String(seat.get("controller_id", "")) == player_id:
			seat["control_mode"] = "human"
	return player_id

func expire_disconnected(now_ms: int = -1) -> Array:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	var expired: Array = []
	for player_id in players:
		var player: Dictionary = players[player_id]
		if String(player.get("connection_state", "")) != "disconnected":
			continue
		if now - int(player.get("last_seen_ms", now)) < RECONNECT_TIMEOUT_MS:
			continue
		player["connection_state"] = "left"
		player["reconnect_token_hash"] = ""
		players[player_id] = player
		expired.append(player_id)
	return expired

func bind_seat(seat_id: int, controller_id: String, survivor_id: String, is_ai: bool = false) -> bool:
	if seat_id < 0 or seat_id >= seats.size():
		return false
	if not is_ai and not players.has(controller_id):
		return false
	for i in range(seats.size()):
		if i != seat_id and String(seats[i].get("survivor_id", "")) == survivor_id and survivor_id != "":
			return false
	var seat: Dictionary = seats[seat_id]
	seat["controller_id"] = "" if is_ai else controller_id
	seat["control_mode"] = "ai" if is_ai else "human"
	seat["survivor_id"] = survivor_id
	seats[seat_id] = seat
	_rebuild_player_seat_ids()
	settings_revision += 1
	return true

func set_seat_survivor(seat_id: int, survivor_id: String) -> bool:
	if seat_id < 0 or seat_id >= seats.size():
		return false
	for i in range(seats.size()):
		if i != seat_id and String(seats[i].get("survivor_id", "")) == survivor_id \
				and survivor_id != "":
			return false
	var seat: Dictionary = seats[seat_id]
	seat["survivor_id"] = survivor_id
	seat["is_ready"] = not survivor_id.is_empty()
	seats[seat_id] = seat
	settings_revision += 1
	return true

func replace_seats(configured_seats: Array, default_controller_id: String = "") -> void:
	_set_seats(configured_seats, default_controller_id)
	settings_revision += 1

func set_room_config(new_mission_mode: String, new_mission_id: int,
		new_variants: Dictionary) -> void:
	mission_mode = new_mission_mode
	mission_id = new_mission_id
	variants = new_variants.duplicate(true)
	settings_revision += 1

func set_phase(next_phase: String) -> void:
	phase = next_phase

func start_match(seed_value: int = -1) -> void:
	phase = "playing"
	match_id = NetId.make_id("m")
	match_seed = seed_value if seed_value >= 0 else randi()
	server_sequence = 0

func next_server_sequence() -> int:
	server_sequence += 1
	return server_sequence

func snapshot(include_tokens: bool = false) -> Dictionary:
	var player_rows: Array = []
	for player in players.values():
		var row: Dictionary = player.duplicate(true)
		row.erase("reconnect_token_hash")
		if not include_tokens:
			row.erase("reconnect_token")
		player_rows.append(row)
	return {
		"protocol_version": NetProtocol.VERSION,
		"room_id": room_id,
		"host_name": host_name,
		"online_multiplayer": online_multiplayer,
		"port": port,
		"phase": phase,
		"max_seats": NetProtocol.MAX_SEATS,
		"match_id": match_id,
		"match_seed": match_seed,
		"mission": {
			"mode": mission_mode,
			"mission_id": mission_id,
		},
		"variants": variants.duplicate(true),
		"settings_revision": settings_revision,
		"server_sequence": server_sequence,
		"players": player_rows,
		"seats": seats.duplicate(true),
	}

func _set_seats(configured: Array, host_id: String) -> void:
	seats.clear()
	for i in range(min(NetProtocol.MAX_SEATS, configured.size())):
		var source: Dictionary = configured[i] if configured[i] is Dictionary else {}
		var type := String(source.get("type", "ai"))
		var survivor = source.get("survivor", null)
		var survivor_id := String(survivor.english_name) if survivor != null else ""
		var is_human := type == "human"
		var configured_controller := String(source.get("controller_id", ""))
		var controller_id := configured_controller if is_human and not configured_controller.is_empty() else (
			host_id if is_human else "")
		seats.append({
			"seat_id": i,
			"controller_id": controller_id,
			"control_mode": "human" if is_human else "ai",
			"survivor_id": survivor_id,
			"survivor_name": String(survivor.character_name) if survivor != null else "",
			"is_ready": survivor != null,
		})
	_rebuild_player_seat_ids()

func _rebuild_player_seat_ids() -> void:
	for player_id in players:
		var player: Dictionary = players[player_id]
		player["seat_ids"] = []
		players[player_id] = player
	for seat in seats:
		var controller_id := String(seat.get("controller_id", ""))
		if controller_id != "" and players.has(controller_id):
			var player: Dictionary = players[controller_id]
			var seat_ids: Array = player.get("seat_ids", [])
			seat_ids.append(int(seat.get("seat_id", -1)))
			player["seat_ids"] = seat_ids
			players[controller_id] = player

func _make_token() -> String:
	return "%s-%s-%s" % [str(randi()), str(Time.get_ticks_usec()), str(randi())]

func _hash_token(token: String) -> String:
	return Marshalls.utf8_to_base64(token.sha256_text())

const MAX_PLAYERS := 6
