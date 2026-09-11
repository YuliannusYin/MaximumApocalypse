class_name NetProtocol
extends RefCounted

## 联机协议常量、消息封装和通用校验。
## 网络层只传输 JSON 可表示的数据，不传递 Godot 对象引用。

const VERSION := 1
const DEFAULT_PORT := 7777
const MAX_PORT := 65535
const MAX_NICKNAME_LENGTH := 24
const MAX_SEATS := 6
const MAX_PLAYERS := 6

const JOIN_REQUEST := "join_request"
const JOIN_ACCEPTED := "join_accepted"
const RECONNECT_REQUEST := "reconnect_request"
const ROOM_SNAPSHOT := "room_snapshot"
const ROOM_COMMAND := "room_command"
const INPUT_REQUEST := "input_request"
const INPUT_RESPONSE := "input_response"
const COMMAND_RESULT := "command_result"
const LEAVE_REQUEST := "leave_request"
const MATCH_START := "match_start"
const GAME_EVENT := "game_event"
const STATE_SNAPSHOT := "state_snapshot"
const RESYNC_REQUEST := "resync_request"
const HEARTBEAT := "heartbeat"
const PLAYER_CONNECTED := "player_connected"
const PLAYER_DISCONNECTED := "player_disconnected"
const PLAYER_RECONNECTED := "player_reconnected"
const ROOM_CLOSED := "room_closed"
const ERROR := "error"

const ERROR_INVALID_ADDRESS := "INVALID_ADDRESS"
const ERROR_INVALID_PORT := "INVALID_PORT"
const ERROR_PORT_IN_USE := "PORT_IN_USE"
const ERROR_CONNECT_TIMEOUT := "CONNECT_TIMEOUT"
const ERROR_CONNECTION_REFUSED := "CONNECTION_REFUSED"
const ERROR_ONLINE_DISABLED := "ONLINE_DISABLED"
const ERROR_PROTOCOL_MISMATCH := "PROTOCOL_MISMATCH"
const ERROR_ROOM_FULL := "ROOM_FULL"
const ERROR_ROOM_ALREADY_STARTED := "ROOM_ALREADY_STARTED"
const ERROR_INVALID_TOKEN := "INVALID_TOKEN"
const ERROR_TOKEN_EXPIRED := "TOKEN_EXPIRED"
const ERROR_INVALID_COMMAND := "INVALID_COMMAND"
const ERROR_STALE_REQUEST := "STALE_REQUEST"
const ERROR_NEED_RESYNC := "NEED_RESYNC"

const HEARTBEAT_INTERVAL_MS := 5000
const HEARTBEAT_TIMEOUT_MS := 30000

static func make_message(message_type: String, payload: Dictionary = {},
		sender_player_id: String = "", match_id: String = "",
		client_sequence: int = 0, server_sequence: int = 0,
		request_id: int = -1) -> Dictionary:
	return {
		"message_type": message_type,
		"protocol_version": VERSION,
		"match_id": match_id,
		"sender_player_id": sender_player_id,
		"client_sequence": client_sequence,
		"server_sequence": server_sequence,
		"request_id": request_id,
		"payload": payload.duplicate(true),
	}

static func has_message_envelope(message: Variant) -> bool:
	if not message is Dictionary:
		return false
	return String(message.get("message_type", "")) != "" \
		and message.get("payload", {}) is Dictionary


static func is_valid_message(message: Variant) -> bool:
	return has_message_envelope(message) \
		and int(message.get("protocol_version", -1)) == VERSION


static func is_protocol_mismatch(message: Variant) -> bool:
	return has_message_envelope(message) \
		and int(message.get("protocol_version", -1)) != VERSION

static func normalize_nickname(value: String) -> String:
	var result := value.strip_edges()
	if result.length() > MAX_NICKNAME_LENGTH:
		result = result.substr(0, MAX_NICKNAME_LENGTH)
	return result

static func parse_address(value: String) -> Dictionary:
	var text := value.strip_edges().replace("：", ":")
	if text.is_empty():
		return {"ok": false, "error": ERROR_INVALID_ADDRESS}
	var host := ""
	var port_text := ""
	if text.begins_with("["):
		var close := text.find("]")
		if close <= 1 or close + 1 >= text.length() or text[close + 1] != ":":
			return {"ok": false, "error": ERROR_INVALID_ADDRESS}
		host = text.substr(1, close - 1)
		port_text = text.substr(close + 2)
	else:
		var separator := text.rfind(":")
		if separator <= 0 or separator == text.length() - 1:
			return {"ok": false, "error": ERROR_INVALID_ADDRESS}
		host = text.substr(0, separator)
		port_text = text.substr(separator + 1)
	if host.to_lower() == "localhost":
		host = "127.0.0.1"
	if host.is_empty() or not port_text.is_valid_int():
		return {"ok": false, "error": ERROR_INVALID_ADDRESS}
	var port := int(port_text)
	if port < 1 or port > MAX_PORT:
		return {"ok": false, "error": ERROR_INVALID_PORT}
	return {"ok": true, "host": host, "port": port}
