extends TestBase

const NetProtocol = preload("res://src/net/net_protocol.gd")

func test_parse_ipv4_address() -> void:
	var parsed := NetProtocol.parse_address("192.168.1.10:7777")
	assert_true(parsed.ok)
	assert_eq(parsed.host, "192.168.1.10")
	assert_eq(parsed.port, 7777)

func test_parse_ipv6_address() -> void:
	var parsed := NetProtocol.parse_address("[::1]:7777")
	assert_true(parsed.ok)
	assert_eq(parsed.host, "::1")

func test_reject_invalid_port() -> void:
	var parsed := NetProtocol.parse_address("localhost:70000")
	assert_false(parsed.ok)
	assert_eq(parsed.error, NetProtocol.ERROR_INVALID_PORT)

func test_message_envelope_has_protocol_version() -> void:
	var message := NetProtocol.make_message(NetProtocol.ROOM_SNAPSHOT, {"value": 1})
	assert_true(NetProtocol.is_valid_message(message))
	assert_eq(message.protocol_version, NetProtocol.VERSION)
	assert_eq(message.payload.value, 1)


func test_protocol_mismatch_is_detected() -> void:
	var message := NetProtocol.make_message(NetProtocol.JOIN_REQUEST, {"display_name": "x"})
	assert_false(NetProtocol.is_protocol_mismatch(message))
	message["protocol_version"] = NetProtocol.VERSION + 1
	assert_true(NetProtocol.is_protocol_mismatch(message))
	assert_false(NetProtocol.is_valid_message(message))


func test_error_text_prefers_detail_and_maps_join_codes() -> void:
	assert_eq(NetProtocol.error_text(NetProtocol.ERROR_ROOM_ALREADY_STARTED, "房间已开始"),
		"房间已开始")
	assert_eq(NetProtocol.error_text(NetProtocol.ERROR_ROOM_ALREADY_STARTED),
		"房间已开始，无法加入")
	assert_eq(NetProtocol.error_text(NetProtocol.ERROR_ROOM_FULL), "房间已满")
	assert_eq(NetProtocol.error_text("UNKNOWN_CODE"), "加入房间失败")
	assert_eq(NetProtocol.error_text(NetProtocol.ERROR_INVALID_ADDRESS),
		"地址格式无效，请填写 IP:端口，例如 192.168.1.10:7777")


func test_client_create_error_maps_resolve_failure() -> void:
	var ok: Dictionary = NetProtocol.client_create_error(OK)
	assert_true(bool(ok.get("ok", false)))
	var resolve_fail: Dictionary = NetProtocol.client_create_error(ERR_CANT_RESOLVE)
	assert_false(bool(resolve_fail.get("ok", true)))
	assert_eq(String(resolve_fail.get("code", "")), NetProtocol.ERROR_INVALID_ADDRESS)
	assert_eq(String(resolve_fail.get("detail", "")), "无法解析地址")
	var cant_create: Dictionary = NetProtocol.client_create_error(ERR_CANT_CREATE)
	assert_eq(String(cant_create.get("code", "")), NetProtocol.ERROR_CONNECTION_REFUSED)
	assert_eq(String(cant_create.get("detail", "")), "无法创建客户端连接")
	var other: Dictionary = NetProtocol.client_create_error(FAILED)
	assert_eq(String(other.get("code", "")), NetProtocol.ERROR_CONNECTION_REFUSED)


func test_resolve_host_uses_raw_ipv4_without_dns() -> void:
	var resolved: Dictionary = NetProtocol.resolve_host("192.168.1.10")
	assert_true(bool(resolved.get("ok", false)))
	assert_eq(String(resolved.get("ip", "")), "192.168.1.10")


func test_resolve_host_localhost() -> void:
	var resolved: Dictionary = NetProtocol.resolve_host("localhost")
	assert_true(bool(resolved.get("ok", false)))
	assert_eq(String(resolved.get("ip", "")), "127.0.0.1")


func test_resolve_host_empty_fails() -> void:
	var resolved: Dictionary = NetProtocol.resolve_host("   ")
	assert_false(bool(resolved.get("ok", true)))
	assert_eq(String(resolved.get("error", "")), NetProtocol.ERROR_INVALID_ADDRESS)


func test_identity_file_paths_split_host_and_guest() -> void:
	assert_eq(NetProtocol.identity_file_path_for_slot(NetProtocol.IDENTITY_SLOT_HOST),
		NetProtocol.IDENTITY_FILE_PATH_HOST)
	assert_eq(NetProtocol.identity_file_path_for_slot(NetProtocol.IDENTITY_SLOT_GUEST),
		NetProtocol.IDENTITY_FILE_PATH_GUEST)
	assert_ne(NetProtocol.IDENTITY_FILE_PATH_HOST, NetProtocol.IDENTITY_FILE_PATH_GUEST)
	assert_ne(NetProtocol.IDENTITY_FILE_PATH_HOST, NetProtocol.IDENTITY_FILE_PATH)


func test_error_text_shows_dns_detail() -> void:
	assert_eq(NetProtocol.error_text(NetProtocol.ERROR_INVALID_ADDRESS, "无法解析地址"),
		"无法解析地址")
