class_name MissionComponentRegistry
extends RefCounted

## 任务组件注册表。字符串 id → 组件类静态映射。
## 由任务加载层调用 create() 按 JSON 声明的 id 实例化组件并注入 params。

## 注册表本体：id → 组件类（Script / GDScript 类）。
static var _registry: Dictionary = {}

## 内置组件是否已注册标记。保证 _register_builtins() 幂等。
static var _builtins_registered: bool = false


## 注册组件类到指定 id。重复注册以最后一次为准。
static func register(id: String, component_class: Variant) -> void:
	_registry[id] = component_class


## 是否已注册指定 id 的组件。
static func has(id: String) -> bool:
	_ensure_builtins()
	return _registry.has(id)


## 按 id 实例化组件并注入 params。未知 id 时 push_error 并返回 null。
static func create(id: String, params: Dictionary = {}) -> MissionComponent:
	_ensure_builtins()
	if not _registry.has(id):
		push_error("MissionComponentRegistry: 未知任务组件 id '%s'" % id)
		return null
	var component_class: Variant = _registry[id]
	var component: MissionComponent = component_class.new()
	component.params = params
	return component


## 清空注册表与内置标记。仅测试用。
static func reset() -> void:
	_registry.clear()
	_builtins_registered = false


## 注册内置组件。幂等；后续任务的内置组件会在此追加注册。
static func _register_builtins() -> void:
	if _builtins_registered:
		return
	_builtins_registered = true
	register("collect_items", MissionComponentCollectItems)
	register("all_players_at_block", MissionComponentAllPlayersAtBlock)
	register("escort_equipment_at_block", MissionComponentEscortEquipmentAtBlock)
	register("spend_action_rescue", MissionComponentSpendActionRescue)
	register("turn_countdown", MissionComponentTurnCountdown)


## 确保内置组件已注册（懒注册入口）。
static func _ensure_builtins() -> void:
	if not _builtins_registered:
		_register_builtins()
