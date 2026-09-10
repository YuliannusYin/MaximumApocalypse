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
