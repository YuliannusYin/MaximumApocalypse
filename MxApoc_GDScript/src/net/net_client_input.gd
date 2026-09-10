class_name NetClientInput
extends RefCounted

## 客机输入请求适配器。UI 可订阅 requested，再通过 respond 返回基本类型。
const NetProtocol = preload("res://src/net/net_protocol.gd")
const NetInputCodec = preload("res://src/net/net_input_codec.gd")

signal requested(request_id: int, seat_id: int, request_type: String, payload: Dictionary)
signal request_state_changed()

var _active_requests: Dictionary = {}

func attach() -> void:
	if NetSession != null and not NetSession.message_received.is_connected(_on_message):
		NetSession.message_received.connect(_on_message)

func detach() -> void:
	if NetSession != null and NetSession.message_received.is_connected(_on_message):
		NetSession.message_received.disconnect(_on_message)
	_active_requests.clear()
	request_state_changed.emit()

## 权威侧 NetworkPlayerInput 同一座位同时只等一个请求。
## 新请求到达时丢掉该座位的旧 id，避免已完成的 action 残留，把后续 wait_action 点死。
func is_action_available(seat_id: int = -1) -> bool:
	var current: Dictionary = get_current_request(seat_id)
	return not current.is_empty() and String(current.get("request_type", "")) == "action"


func get_current_request(seat_id: int = -1) -> Dictionary:
	var result: Dictionary = {}
	for request_id in _active_requests:
		var request: Dictionary = _active_requests[request_id]
		if seat_id >= 0 and int(request.get("seat_id", -1)) != seat_id:
			continue
		result = {
			"request_id": int(request_id),
			"seat_id": int(request.get("seat_id", -1)),
			"request_type": String(request.get("request_type", "")),
		}
		if seat_id >= 0:
			break
	return result


## 当前座位若正等待 action，返回该请求；否则空。
func get_action_request(seat_id: int = -1) -> Dictionary:
	var current: Dictionary = get_current_request(seat_id)
	if String(current.get("request_type", "")) != "action":
		return {}
	return current

func respond(request_id: int, seat_id: int, value: Variant) -> void:
	if not _active_requests.has(request_id):
		return
	var request: Dictionary = _active_requests[request_id]
	if int(request.get("seat_id", -1)) != seat_id:
		return
	NetSession.send_input_response(
		request_id, seat_id, _encode_selection_response(request, value))
	_active_requests.erase(request_id)
	request_state_changed.emit()

func _encode_selection_response(request: Dictionary, value: Variant) -> Variant:
	var request_type := String(request.get("request_type", ""))
	if request_type not in ["choose_card", "choose_target", "choose_block",
			"choose_block_inline"]:
		return value
	var decoded_payload: Variant = request.get("decoded_payload", {})
	if not decoded_payload is Dictionary:
		return value
	var field := String(decoded_payload.get("selection_field", ""))
	var candidates: Variant = decoded_payload.get(field, [])
	var tokens: Variant = decoded_payload.get("selection_tokens", [])
	if field.is_empty() or not candidates is Array or not tokens is Array:
		return value
	if value is Array:
		var encoded: Array = []
		for selected in value:
			var index := _find_candidate_index(candidates, selected)
			if index >= 0 and index < tokens.size():
				encoded.append(tokens[index])
		return encoded
	var index := _find_candidate_index(candidates, value)
	return tokens[index] if index >= 0 and index < tokens.size() else ""

func _find_candidate_index(candidates: Array, selected: Variant) -> int:
	for i in range(candidates.size()):
		if candidates[i] == selected:
			return i
		if NetInputCodec.encode(candidates[i]) == NetInputCodec.encode(selected):
			return i
	return -1

func _on_message(message: Dictionary) -> void:
	if String(message.get("message_type", "")) != NetProtocol.INPUT_REQUEST:
		return
	var payload: Dictionary = message.get("payload", {})
	var request_id := int(message.get("request_id", -1))
	if request_id < 0:
		return
	var decoded_payload: Variant = NetInputCodec.decode(
		payload.get("payload", {}), Game)
	var seat_id := int(payload.get("seat_id", -1))
	_drop_seat_requests(seat_id)
	_active_requests[request_id] = {
		"seat_id": seat_id,
		"request_type": String(payload.get("request_type", "")),
		"decoded_payload": decoded_payload,
	}
	request_state_changed.emit()
	requested.emit(
		request_id,
		seat_id,
		String(payload.get("request_type", "")),
		decoded_payload)


func _drop_seat_requests(seat_id: int) -> void:
	var stale: Array = []
	for existing_id in _active_requests:
		var request: Dictionary = _active_requests[existing_id]
		if int(request.get("seat_id", -1)) == seat_id:
			stale.append(existing_id)
	for existing_id in stale:
		_active_requests.erase(existing_id)
