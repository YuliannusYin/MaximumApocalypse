class_name NetId
extends RefCounted

static var _counter: int = 0

static func make_id(prefix: String) -> String:
	_counter += 1
	return "%s_%s_%s" % [prefix, str(Time.get_ticks_usec()), str(_counter)]
