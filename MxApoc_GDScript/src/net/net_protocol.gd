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
const HELLO_RETRY_INITIAL_MS := 1000
const HELLO_RETRY_MAX_MS := 4000
const HELLO_RETRY_MAX_ATTEMPTS := 8
const IDENTITY_SLOT_HOST := "host"
const IDENTITY_SLOT_GUEST := "guest"
const IDENTITY_FILE_PATH := "user://net_identity.json"
const IDENTITY_FILE_PATH_HOST := "user://net_identity_host.json"
const IDENTITY_FILE_PATH_GUEST := "user://net_identity_guest.json"

static func identity_file_path_for_slot(slot: String) -> String:
	if slot == IDENTITY_SLOT_HOST:
		return IDENTITY_FILE_PATH_HOST
	return IDENTITY_FILE_PATH_GUEST

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


## 把主机名解析成 ENet 能直接连的 IP。纯 IP 不走 DNS。
static func resolve_host(host: String) -> Dictionary:
	var trimmed := host.strip_edges()
	if trimmed.to_lower() == "localhost":
		trimmed = "127.0.0.1"
	if trimmed.is_empty():
		return {"ok": false, "ip": "", "error": ERROR_INVALID_ADDRESS}
	if trimmed.is_valid_ip_address():
		return {"ok": true, "ip": trimmed, "error": ""}
	IP.clear_cache(trimmed)
	var ipv4 := String(IP.resolve_hostname(trimmed, IP.TYPE_IPV4))
	if ipv4.is_valid_ip_address():
		return {"ok": true, "ip": ipv4, "error": ""}
	var any_ip := String(IP.resolve_hostname(trimmed, IP.TYPE_ANY))
	if any_ip.is_valid_ip_address():
		return {"ok": true, "ip": any_ip, "error": ""}
	return {"ok": false, "ip": "", "error": ERROR_INVALID_ADDRESS}


## 加入/连接失败时给玩家看的文案。有 detail 时优先用 detail，避免未知码落到「无法解析地址」。
static func error_text(code: String, detail: String = "") -> String:
	var trimmed := detail.strip_edges()
	if trimmed != "":
		return trimmed
	match code:
		ERROR_INVALID_ADDRESS:
			return "地址格式无效，请填写 IP:端口，例如 192.168.1.10:7777"
		ERROR_INVALID_PORT:
			return "端口无效"
		ERROR_PORT_IN_USE:
			return "端口已被占用"
		ERROR_CONNECT_TIMEOUT:
			return "连接超时"
		ERROR_CONNECTION_REFUSED:
			return "无法连接到房间"
		ERROR_ONLINE_DISABLED:
			return "联机未启用"
		ERROR_PROTOCOL_MISMATCH:
			return "客户端版本不兼容"
		ERROR_ROOM_FULL:
			return "房间已满"
		ERROR_ROOM_ALREADY_STARTED:
			return "房间已开始，无法加入"
		ERROR_INVALID_TOKEN, ERROR_TOKEN_EXPIRED:
			return "重连凭证已失效"
		ERROR_INVALID_COMMAND:
			return "网络请求无效"
		ERROR_STALE_REQUEST:
			return "请求已过期"
		ERROR_NEED_RESYNC:
			return "需要重新同步对局"
		_:
			return "加入房间失败"


## ENet create_client 的返回码映射到协议错误。
static func client_create_error(result: int) -> Dictionary:
	if result == OK:
		return {"ok": true, "code": "", "detail": ""}
	if result == ERR_CANT_RESOLVE:
		return {"ok": false, "code": ERROR_INVALID_ADDRESS, "detail": "无法解析地址"}
	if result == ERR_INVALID_PARAMETER:
		return {"ok": false, "code": ERROR_INVALID_PORT, "detail": "端口无效"}
	return {"ok": false, "code": ERROR_CONNECTION_REFUSED, "detail": "无法创建客户端连接"}
