# BaseEntity.gd
class_name BaseEntity
extends RefCounted

static var _next_instance_id: int = 1

enum Type {
	PLAYER,
	MONSTER,
	CARD,
	MAP_BLOCK,
	MISSION
}

var unique_id: int
var type: Type

func _init(p_type: Type) -> void:
	unique_id = _next_instance_id
	_next_instance_id += 1
	type = p_type
