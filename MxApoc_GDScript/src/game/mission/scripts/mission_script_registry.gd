class_name MissionScriptRegistry
extends RefCounted

## 任务脚本注册表。字符串 id → 脚本类静态映射。结构与 MissionComponentRegistry 一致。
## 由任务加载层调用 create() 按 JSON 声明的 id 实例化脚本并注入 params。

## 注册表本体：id → 脚本类（Script / GDScript 类）。
static var _registry: Dictionary = {}

## 内置脚本是否已注册标记。保证 _register_builtins() 幂等。
static var _builtins_registered: bool = false


## 注册脚本类到指定 id。重复注册以最后一次为准。
static func register(id: String, script_class: Variant) -> void:
	_registry[id] = script_class


## 是否已注册指定 id 的脚本。
static func has(id: String) -> bool:
	_ensure_builtins()
	return _registry.has(id)


## 按 id 实例化脚本并注入 params。未知 id 时 push_error 并返回 null。
static func create(id: String, params: Dictionary = {}) -> MissionScript:
	_ensure_builtins()
	if not _registry.has(id):
		push_error("MissionScriptRegistry: 未知任务脚本 id '%s'" % id)
		return null
	var script_class: Variant = _registry[id]
	var script: MissionScript = script_class.new()
	script.params = params
	return script


## 清空注册表与内置标记。仅测试用。
static func reset() -> void:
	_registry.clear()
	_builtins_registered = false


## 注册内置脚本。幂等；内置脚本后续任务会在此追加注册。
static func _register_builtins() -> void:
	if _builtins_registered:
		return
	_builtins_registered = true


## 确保内置脚本已注册（懒注册入口）。
static func _ensure_builtins() -> void:
	if not _builtins_registered:
		_register_builtins()
