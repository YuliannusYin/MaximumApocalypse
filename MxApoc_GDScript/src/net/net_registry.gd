class_name NetRegistry
extends RefCounted

## 主机侧 net_id -> 对象 注册表。
## 卡牌/怪物/地块/玩家在创建时注册，NetPlayerInput 收到客机回传的 net_id 时据此还原对象。

static var _by_id: Dictionary = {}


static func register(obj) -> void:
	if obj != null and int(obj.net_id) != 0:
		_by_id[obj.net_id] = obj


static func get_obj(id: int):
	return _by_id.get(id, null)


static func clear() -> void:
	_by_id.clear()
