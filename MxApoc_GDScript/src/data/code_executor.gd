class_name CodeExecutor
extends RefCounted

## 代码执行沙箱。
## 将 JSON 中的代码字符串编译为 Callable，通过 GDScript.new() 实现。
## 支持多语句（for/while/if-else），克服 Expression 类只能执行单表达式的限制。
## 编译失败时降级为 no-op Callable（filter 返回 true，content 无操作）。
## 参考模式：addons/gut/dynamic_gdscript.gd

const _FILTER_PREFIX := "extends RefCounted\nfunc _fn(player, target, event, game) -> bool:\n"
const _CONTENT_PREFIX := "extends RefCounted\nfunc _fn(player, target, event, game) -> void:\n\tvar actions = event.get(\"actions\", null)\n"
const _CONFIRM_PROMPT_PREFIX := "extends RefCounted\nfunc _fn(player, target, event, game) -> String:\n"


## 编译 filter 代码字符串为 Callable。
## 返回的 Callable 签名: (player, target, event, game) -> bool
## 空字符串返回空 Callable（调用方视为恒真）。
static func compile_filter(code: String) -> Callable:
	if code.strip_edges().is_empty():
		return Callable()
	var indented: String = code.indent("\t")
	var full_code: String = _FILTER_PREFIX + indented
	var instance: Object = _compile(full_code)
	if instance == null:
		push_warning("CodeExecutor: filter 编译失败，降级为恒真: " + code)
		return _create_noop_filter()
	return Callable(instance, "_fn")


## 编译 content 代码字符串为 Callable。
## 返回的 Callable 签名: (player, target, event, game) -> void
## 空字符串返回空 Callable（调用方视为无操作）。
static func compile_content(code: String) -> Callable:
	if code.strip_edges().is_empty():
		return Callable()
	code = _add_implicit_action_awaits(code)
	var indented: String = code.indent("\t")
	var full_code: String = _CONTENT_PREFIX + indented
	var instance: Object = _compile(full_code)
	if instance == null:
		push_warning("CodeExecutor: content 编译失败，降级为 no-op: " + code)
		return _create_noop_content()
	return Callable(instance, "_fn")


## JSON content 中的 actions.* 是可等待的嵌套操作。
## 为保留“数据不写 await”的语法，在编译阶段自动补齐等待。
static func _add_implicit_action_awaits(code: String) -> String:
	var result := code.replace("actions.", "await actions.")
	while result.contains("await await actions."):
		result = result.replace("await await actions.", "await actions.")
	return result


## 编译 filter_target 代码字符串为 Callable。
## "true" 或空字符串返回空 Callable（调用方视为无过滤）。
static func compile_filter_target(code: String) -> Callable:
	if code.strip_edges().is_empty() or code.strip_edges() == "true":
		return Callable()
	var indented: String = code.indent("\t")
	var full_code: String = _FILTER_PREFIX + indented
	var instance: Object = _compile(full_code)
	if instance == null:
		return _create_noop_filter()
	return Callable(instance, "_fn")


## 编译 filter_card 代码字符串为 Callable。
static func compile_filter_card(code: String) -> Callable:
	return compile_filter_target(code)


## 编译 confirm_prompt 代码字符串为 Callable。
## 返回的 Callable 签名: (player, target, event, game) -> String
## 空字符串返回空 Callable（调用方视为使用默认格式）。
static func compile_confirm_prompt(code: String) -> Callable:
	if code.strip_edges().is_empty():
		return Callable()
	var indented: String = code.indent("\t")
	var full_code: String = _CONFIRM_PROMPT_PREFIX + indented
	var instance: Object = _compile(full_code)
	if instance == null:
		push_warning("CodeExecutor: confirm_prompt 编译失败，降级为默认格式: " + code)
		return Callable()
	return Callable(instance, "_fn")


static var _scripts: Array[GDScript] = []
static var _instances: Array = []
static var _path_counter: int = 0


## 生成唯一 resource_path 并自增计数器。
## 必须在 reload() 前调用，确保即使编译失败路径也不复用（避免 cyclic resource inclusion）。
static func _next_path(prefix: String) -> String:
	var path: String = "res://addons/gut/not_a_real_file/%s_%d.gd" % [prefix, _path_counter]
	_path_counter += 1
	return path


## 编译 GDScript 源码并返回脚本实例。
## 失败返回 null。
## 设置 resource_path 避免 Godot issue #65263（参考 addons/gut/dynamic_gdscript.gd）。
## 脚本引用存入 _scripts、实例引用存入 _instances 防止 GC 回收。
static func _compile(source: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = source
	script.resource_path = _next_path("ce")
	var result: int = script.reload()
	if result != OK:
		return null
	_scripts.append(script)
	var instance: Object = script.new()
	if instance == null:
		return null
	_instances.append(instance)
	return instance


## 创建 no-op filter Callable（恒返回 true）。
static func _create_noop_filter() -> Callable:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nfunc _fn(_p, _t, _e, _g) -> bool:\n\treturn true"
	script.resource_path = _next_path("ce_noop_f")
	var result: int = script.reload()
	if result != OK:
		return Callable()
	_scripts.append(script)
	var instance: Object = script.new()
	if instance == null:
		return Callable()
	_instances.append(instance)
	return Callable(instance, "_fn")


## 创建 no-op content Callable（无操作）。
static func _create_noop_content() -> Callable:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nfunc _fn(_p, _t, _e, _g) -> void:\n\tpass"
	script.resource_path = _next_path("ce_noop_c")
	var result: int = script.reload()
	if result != OK:
		return Callable()
	_scripts.append(script)
	var instance: Object = script.new()
	if instance == null:
		return Callable()
	_instances.append(instance)
	return Callable(instance, "_fn")
