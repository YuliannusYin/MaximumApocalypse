# [新增] 2026-06-24: 卡牌运行时类，用于存储卡牌的运行时状态信息
# CardRuntime.gd
class_name CardRuntime
extends RefCounted

# [新增] 2026-06-24: 卡牌局内唯一UUID
var instance_id: String

# [新增] 2026-06-24: 对应配置的卡牌模板ID
var template_id: String

# [新增] 2026-06-24: 装备牌的当前弹药/耐久
var current_ammo: int = 0

# [新增] 2026-06-24: 初始化卡牌运行时实例
func _init(_instance_id: String, _template_id: String, _ammo: int = 0):
	self.instance_id = _instance_id
	self.template_id = _template_id
	self.current_ammo = _ammo