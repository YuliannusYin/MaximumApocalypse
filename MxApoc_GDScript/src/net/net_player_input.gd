class_name NetworkPlayerInput
extends IPlayerInput

## 房主为远程真人座位创建的输入实现。
## 规则协程仍运行在房主，只有输入值通过 ENet 往返。
const NetProtocol = preload("res://src/net/net_protocol.gd")
const NetInputCodec = preload("res://src/net/net_input_codec.gd")

signal response_arrived(request_id: int, value: Variant)
signal visual_requested(request_type: String, seat_id: int, payload: Dictionary)

var _pending: Dictionary = {}
var _request_owner: Variant = null

func _init() -> void:
	if NetSession != null:
		NetSession.message_received.connect(_on_network_message)

func set_request_owner(player: Variant) -> void:
	_request_owner = player


func detach() -> void:
	abort_pending()
	if NetSession != null and NetSession.message_received.is_connected(_on_network_message):
		NetSession.message_received.disconnect(_on_network_message)


## 解开死等，让规则协程继续；随后由 AI 接管后续请求。
func abort_pending() -> void:
	if _pending.is_empty():
		return
	for request_id in _pending.keys():
		var state: Dictionary = _pending[request_id]
		if bool(state.get("received", false)):
			continue
		state["value"] = _abort_value_for(String(state.get("request_type", "")))
		state["received"] = true
		_pending[request_id] = state
	response_arrived.emit(-1, null)


## 同一座位新请求到达前，解开该座位上未应答的旧请求，避免客机丢弃后权威死等。
func _abort_unanswered_for_seat(seat_id: int) -> void:
	if seat_id < 0 or _pending.is_empty():
		return
	var aborted := false
	for request_id in _pending.keys():
		var state: Dictionary = _pending[request_id]
		if bool(state.get("received", false)):
			continue
		if int(state.get("seat_id", -1)) != seat_id:
			continue
		state["value"] = _abort_value_for(String(state.get("request_type", "")))
		state["received"] = true
		_pending[request_id] = state
		aborted = true
	if aborted:
		response_arrived.emit(-1, null)


func _abort_value_for(request_type: String) -> Variant:
	match request_type:
		"choose_card", "choose_target", "choose_block_inline":
			return []
		"confirm", "redraw_decision":
			return false
		"judge_confirm":
			return true
		_:
			return null

func wait_action(player: Variant) -> Variant:
	return await _request(player, "action", {})

func choose(options: Array, prompt: String = "") -> Variant:
	return await _request(_request_owner, "choose", {"options": options, "prompt": prompt})

func choose_card(n: int, param: Variant = "hand", filter: Variant = null,
		prompt: String = "", min_n: int = -1) -> Array:
	var candidates := _get_card_candidates(param, filter)
	var result = await _request(_request_owner, "choose_card", {
		"n": n, "param": param if param is String else "candidates",
		"cards": candidates,
		"selection_field": "cards",
		"prompt": prompt, "min_n": min_n,
	})
	return result if result is Array else []

func choose_target(n: int, skill: Variant, prompt: String = "", min_n: int = -1) -> Array:
	var candidates: Array = []
	if _request_owner != null and is_instance_valid(_request_owner) \
			and _request_owner.has_method("get_skill_valid_targets"):
		candidates = _request_owner.get_skill_valid_targets(skill)
	if candidates.is_empty():
		return []
	var display_n := n
	var preselect_all := false
	if n == -1 or n >= candidates.size():
		display_n = candidates.size()
		preselect_all = true
		if Settings.skip_target_selection:
			return candidates
	var result = await _request(_request_owner, "choose_target", {
		"n": display_n, "targets": candidates, "selection_field": "targets",
		"preselect_all": preselect_all,
		"prompt": prompt, "min_n": min_n,
	})
	return result if result is Array else []

func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	return await _request(_request_owner, "choose_block", {
		"blocks": blocks, "selection_field": "blocks", "prompt": prompt,
	})

func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	var result = await _request(_request_owner, "choose_block_inline", {
		"blocks": valid_blocks, "selection_field": "blocks",
		"prompt": prompt, "count": count,
	})
	return result if result is Array else []

func confirm(message: String) -> bool:
	return bool(await _request(_request_owner, "confirm", {"message": message}))

func show_card(card: Card, target: Variant) -> void:
	_emit_visual(target, "show_card", {"card": card})

func set_prompt(text: String) -> void:
	var owner: Variant = _request_owner
	_request_owner = null
	var seat_id := _seat_id_for_player(owner)
	var owner_id := _controller_for_seat(seat_id)
	if owner_id != "":
		NetSession.broadcast_input_request(
			-1, seat_id, owner_id, "set_prompt", {"text": text})

func wait_redraw_decision(player: Variant) -> bool:
	var hand: Array = player.hand if player != null and "hand" in player else []
	return bool(await _request(player, "redraw_decision", {"hand": hand}))

func wait_judge_confirm(player: Variant, prompt: String, allow_cancel: bool) -> bool:
	return bool(await _request(player, "judge_confirm", {
		"prompt": prompt, "allow_cancel": allow_cancel,
	}))

func play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	_emit_visual(_request_owner, "dice_animation", {
		"d1": d1, "d2": d2, "label": label, "outcome": outcome,
	})

func play_monster_draw_animation(player: Variant, card: Variant) -> void:
	_emit_visual(player, "monster_draw_animation", {"card": card})

func play_scavenge_draw_animation(player: Variant, card: Variant) -> void:
	_emit_visual(player, "scavenge_draw_animation", {"card": card})

func play_card_destroy_animation(card: Card) -> void:
	_emit_visual(_request_owner, "card_destroy_animation", {"card": card})

func play_monster_skill_trigger_animation(monster: Variant) -> void:
	_emit_visual(_request_owner, "monster_skill_animation", {"monster": monster})

func play_monster_attack_animation(monster: Variant, targets: Array) -> void:
	var target_seats: Array = []
	for target in targets:
		if target != null and target.has_method("get"):
			var seat_value: Variant = target.get("seat_number")
			if seat_value != null:
				target_seats.append(int(seat_value))
	_emit_visual(_request_owner, "monster_attack_animation", {
		"monster": monster,
		"targets": target_seats,
	})

func _get_card_candidates(param: Variant, filter: Variant) -> Array:
	var owner: Variant = _request_owner
	var candidates: Array = []
	if param is Array:
		candidates = param.duplicate()
	elif owner != null and is_instance_valid(owner) and owner.has_method("get_cards"):
		candidates = owner.get_cards(param)
	if not (filter is Callable) or not filter.is_valid():
		return candidates
	var filtered: Array = []
	for card in candidates:
		if filter.call(owner, card, {}, Game):
			filtered.append(card)
	return filtered

## 演出只走 GAME_EVENT，不等客机 ACK。决策请求才进 _pending。
func _emit_visual(player: Variant, request_type: String, payload: Dictionary) -> void:
	var seat_id := _seat_id_for_player(player)
	var visual_payload := payload.duplicate(true)
	visual_payload["seat_id"] = seat_id
	if NetSession != null:
		NetSession.broadcast_game_event(request_type, visual_payload)
	visual_requested.emit(request_type, seat_id, visual_payload)


func _request(player: Variant, request_type: String, payload: Dictionary) -> Variant:
	var seat_id := _seat_id_for_player(player)
	var owner_id := _controller_for_seat(seat_id)
	if owner_id == "" or seat_id < 0:
		return null
	var request_id := NetSession.next_request_id() if NetSession != null else 1
	_abort_unanswered_for_seat(seat_id)
	var request_payload := payload.duplicate(true)
	var selection_map: Dictionary = {}
	var selection_field := String(request_payload.get("selection_field", ""))
	if not selection_field.is_empty():
		var candidates: Variant = request_payload.get(selection_field, [])
		if candidates is Array:
			var selection_tokens: Array = []
			for index in range(candidates.size()):
				var token := str(index)
				selection_tokens.append(token)
				selection_map[token] = candidates[index]
			request_payload["selection_tokens"] = selection_tokens
	var state := {
		"value": null,
		"received": false,
		"selection_map": selection_map,
		"request_type": request_type,
		"seat_id": seat_id,
	}
	_pending[request_id] = state
	NetSession.broadcast_input_request(
		request_id, seat_id, owner_id, request_type, request_payload)
	while _pending.has(request_id) and not bool(_pending[request_id].received):
		await response_arrived
	var result = _pending.get(request_id, {}).get("value", null)
	var completed_state: Dictionary = _pending.get(request_id, {})
	_pending.erase(request_id)
	result = _resolve_response_value(
		request_type, result, completed_state.get("selection_map", {}))
	if request_type == "choose_target" and result is Array:
		NetSession.broadcast_game_event("target_links", {
			"source_seat": seat_id,
			"targets": result,
		})
	return result

func _resolve_response_value(request_type: String, result: Variant, selection_map: Variant) -> Variant:
	var tokens: Dictionary = selection_map if selection_map is Dictionary else {}
	if not tokens.is_empty():
		return _decode_selection_result(result, tokens)
	if request_type in ["choose_target", "choose_card", "choose_block", "choose_block_inline"]:
		return [] if request_type != "choose_block" else null
	return NetInputCodec.decode(result, Game)


func _decode_selection_result(result: Variant, selection_map: Dictionary) -> Variant:
	if result is Array:
		var decoded: Array = []
		for token in result:
			var key := String(token)
			if not selection_map.has(key):
				continue
			var candidate: Variant = selection_map[key]
			if not decoded.has(candidate):
				decoded.append(candidate)
		return decoded
	var key := String(result)
	return selection_map.get(key, null)

func _on_network_message(message: Dictionary) -> void:
	if String(message.get("message_type", "")) != NetProtocol.INPUT_RESPONSE:
		return
	var request_id := int(message.get("request_id", -1))
	if not _pending.has(request_id):
		return
	var payload: Dictionary = message.get("payload", {})
	_pending[request_id].value = payload.get("value", null)
	_pending[request_id].received = true
	response_arrived.emit(request_id, payload.get("value", null))


func _seat_id_for_player(player: Variant) -> int:
	if player == null:
		return -1
	if player is int:
		return int(player)
	var value: Variant = player.get("seat_number") if player.has_method("get") else null
	return int(value) if value != null else -1

func _controller_for_seat(seat_id: int) -> String:
	if NetSession == null or seat_id < 0 or seat_id >= NetSession.registry.seats.size():
		return ""
	return String(NetSession.registry.seats[seat_id].get("controller_id", ""))

