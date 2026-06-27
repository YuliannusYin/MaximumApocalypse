# CardRuntime.gd
class_name CardRuntime
extends RefCounted

var instance_id: String              # 局内唯一UUID
var template_id: String              # 对应配置的卡牌ID
var current_ammo: int = 0            # 装备牌的当前弹药/耐久

func _init(_instance_id: String, _template_id: String, _ammo: int = 0):
	self.instance_id = _instance_id
	self.template_id = _template_id
	self.current_ammo = _ammo