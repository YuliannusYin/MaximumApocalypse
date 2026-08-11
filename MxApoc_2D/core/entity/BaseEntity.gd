# BaseEntity.gd
class_name BaseEntity
extends RefCounted

# 实体实例 ID 生成器
static var _next_instance_id: int = 1

# 实体类型
enum Type {
	PLAYER,
	CARD,
	MAP_BLOCK,
	MISSION
}

# 实体唯一标识符
var unique_id: int
# 实体类型
var type: Type

# 初始化实体
func _init(p_type: Type) -> void:
	unique_id = _next_instance_id
	_next_instance_id += 1
	type = p_type
