extends GutTest

## 任务组件/脚本注册表与基类默认行为单元测试。
## 覆盖 MissionComponentRegistry / MissionScriptRegistry 的 register/has/create/reset，
## 以及 MissionComponent / MissionScript 基类的默认语义。
## 使用内嵌 Dummy 类注册临时 id，before_each/after_each 里 reset() 隔离。


# === 测试用内嵌组件/脚本 ===

# 临时组件：按注入的 params 返回判定结果并记录事件名，用于验证注册表与接口转发。
class DummyComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return params.get("win", false)

	func check_lose(game: Game) -> bool:
		return params.get("lose", false)

	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		params["last_event"] = event_name

	func get_action_options(game: Game, player: Player) -> Array:
		return params.get("options", [])


# 临时脚本：与 DummyComponent 结构一致，用于 MissionScriptRegistry。
class DummyScript extends MissionScript:
	func check_win(game: Game) -> bool:
		return params.get("win", false)

	func check_lose(game: Game) -> bool:
		return params.get("lose", false)

	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		params["last_event"] = event_name

	func get_action_options(game: Game, player: Player) -> Array:
		return params.get("options", [])


# === 隔离：每个用例前后清空两个注册表 ===

func before_each() -> void:
	MissionComponentRegistry.reset()
	MissionScriptRegistry.reset()


func after_each() -> void:
	MissionComponentRegistry.reset()
	MissionScriptRegistry.reset()


# === 1. MissionComponentRegistry ===

func test_component_register_then_create_injects_params() -> void:
	MissionComponentRegistry.register("dummy", DummyComponent)
	assert_true(MissionComponentRegistry.has("dummy"), "注册后 has 应为 true")
	var component: MissionComponent = MissionComponentRegistry.create("dummy", {"win": true, "lose": false})
	assert_not_null(component, "create 应返回实例")
	assert_true(component is DummyComponent, "实例应为 DummyComponent 类型")
	var dummy := component as DummyComponent
	assert_eq(dummy.params.get("win"), true, "params 应正确注入")
	assert_true(dummy.check_win(null), "组件应按注入的 params 判定胜利")
	assert_false(dummy.check_lose(null), "组件应按注入的 params 判定失败")
	dummy.on_event(null, "test_event", {})
	assert_eq(dummy.params.get("last_event"), "test_event", "on_event 应被转发到组件")
	assert_eq(dummy.get_action_options(null, null), [], "行动选项缺省应为空数组")


func test_component_create_injects_options_params() -> void:
	MissionComponentRegistry.register("dummy", DummyComponent)
	var component: MissionComponent = MissionComponentRegistry.create("dummy", {"options": ["a", "b"]})
	var dummy := component as DummyComponent
	assert_eq(dummy.get_action_options(null, null), ["a", "b"], "行动选项应来自注入的 params")


func test_component_has_unknown_id() -> void:
	assert_false(MissionComponentRegistry.has("no_such_component"), "未注册 id 的 has 应为 false")


func test_component_create_unknown_id_returns_null() -> void:
	var component: MissionComponent = MissionComponentRegistry.create("no_such_component")
	assert_null(component, "未知 id 的 create 应返回 null")
	# 未知 id 会触发预期的 push_error；断言其存在后不再计为 Unexpected Error
	assert_push_error("未知任务组件 id 'no_such_component'", "应产生未知组件 id 的 push_error")


func test_component_create_default_params_empty() -> void:
	MissionComponentRegistry.register("dummy", DummyComponent)
	var component: MissionComponent = MissionComponentRegistry.create("dummy")
	assert_eq(component.params, {}, "缺省 params 应为空字典")


func test_component_reset_clears_registry() -> void:
	MissionComponentRegistry.register("dummy", DummyComponent)
	assert_true(MissionComponentRegistry.has("dummy"), "注册后应可查询")
	MissionComponentRegistry.reset()
	assert_false(MissionComponentRegistry.has("dummy"), "reset 后应清空注册表")


func test_component_reregister_overrides() -> void:
	MissionComponentRegistry.register("dummy", DummyComponent)
	MissionComponentRegistry.register("dummy", MissionComponent)
	var component: MissionComponent = MissionComponentRegistry.create("dummy")
	assert_true(component is MissionComponent and not (component is DummyComponent), "重复注册应以后一次为准")


# === 2. MissionScriptRegistry ===

func test_script_register_then_create_injects_params() -> void:
	MissionScriptRegistry.register("dummy", DummyScript)
	assert_true(MissionScriptRegistry.has("dummy"), "注册后 has 应为 true")
	var script: MissionScript = MissionScriptRegistry.create("dummy", {"win": true, "lose": false})
	assert_not_null(script, "create 应返回实例")
	assert_true(script is DummyScript, "实例应为 DummyScript 类型")
	var dummy := script as DummyScript
	assert_eq(dummy.params.get("win"), true, "params 应正确注入")
	assert_true(dummy.check_win(null), "脚本应按注入的 params 判定胜利")
	assert_false(dummy.check_lose(null), "脚本应按注入的 params 判定失败")
	dummy.on_event(null, "test_event", {})
	assert_eq(dummy.params.get("last_event"), "test_event", "on_event 应被转发到脚本")
	assert_eq(dummy.get_action_options(null, null), [], "行动选项缺省应为空数组")


func test_script_has_unknown_id() -> void:
	assert_false(MissionScriptRegistry.has("no_such_script"), "未注册 id 的 has 应为 false")


func test_script_create_unknown_id_returns_null() -> void:
	var script: MissionScript = MissionScriptRegistry.create("no_such_script")
	assert_null(script, "未知 id 的 create 应返回 null")
	# 未知 id 会触发预期的 push_error；断言其存在后不再计为 Unexpected Error
	assert_push_error("未知任务脚本 id 'no_such_script'", "应产生未知脚本 id 的 push_error")


func test_script_create_default_params_empty() -> void:
	MissionScriptRegistry.register("dummy", DummyScript)
	var script: MissionScript = MissionScriptRegistry.create("dummy")
	assert_eq(script.params, {}, "缺省 params 应为空字典")


func test_script_reset_clears_registry() -> void:
	MissionScriptRegistry.register("dummy", DummyScript)
	assert_true(MissionScriptRegistry.has("dummy"), "注册后应可查询")
	MissionScriptRegistry.reset()
	assert_false(MissionScriptRegistry.has("dummy"), "reset 后应清空注册表")


# === 3. 基类默认行为 ===

func test_component_base_defaults() -> void:
	var component := MissionComponent.new()
	assert_true(component.check_win(null), "基类 check_win 默认应为 true")
	assert_false(component.check_lose(null), "基类 check_lose 默认应为 false")
	assert_eq(component.get_action_options(null, null), [], "基类 get_action_options 默认应为空数组")
	assert_eq(component.params, {}, "基类 params 默认应为空字典")
	# setup / on_event 为默认空实现，调用不应产生运行时错误
	component.setup(null, null)
	component.on_event(null, "any", {})


func test_script_base_defaults() -> void:
	var script := MissionScript.new()
	assert_true(script.check_win(null), "基类 check_win 默认应为 true")
	assert_false(script.check_lose(null), "基类 check_lose 默认应为 false")
	assert_eq(script.get_action_options(null, null), [], "基类 get_action_options 默认应为空数组")
	assert_eq(script.params, {}, "基类 params 默认应为空字典")
	# setup / on_event 为默认空实现，调用不应产生运行时错误
	script.setup(null, null)
	script.on_event(null, "any", {})
