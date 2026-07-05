class_name RoleCard
extends RefCounted

var _is_front: bool = true


## 角色卡当前是否正面朝上。
func is_front() -> bool:
	return _is_front


## 翻面:正↔反切换。
func flip() -> void:
	_is_front = not _is_front
