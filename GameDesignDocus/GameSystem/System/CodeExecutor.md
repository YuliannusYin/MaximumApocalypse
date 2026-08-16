# CodeExecutor 代码执行沙箱

> 以 `src/data/code_executor.gd` 为准。
> 职责：将 JSON 中的代码字符串编译为 Callable 的运行时沙箱。
> 类名 `CodeExecutor`，继承 `RefCounted`。所有公开接口均为 `static`。
> 本文档聚焦运行时 API 与调用约定；数据视角与编译流程详述见 [Engineering/CodeExecutor.md](../../Engineering/CodeExecutor.md)。

---

## 设计意图

> 通过 `GDScript.new()` + `script.reload()` 将 JSON 中的代码字符串包装为 `extends RefCounted\nfunc _fn(...) -> ...:` 形式源码后编译为 Callable。
> 相比 `Expression` 类只能执行单表达式，本方案支持多语句（`for` / `while` / `if`-`else` 等），克服单表达式限制。
> 编译失败时降级为 no-op Callable（filter 恒真、content 无操作）。
> 编译产生的 `GDScript` 与其实例引用存入 static 数组防止 GC 回收。
> 参考模式：`addons/gut/dynamic_gdscript.gd`。

---

## 常量

| 常量名 | 类型 | 值 |
|--------|------|----|
| `_FILTER_PREFIX` | String | `"extends RefCounted\nfunc _fn(player, target, event, game) -> bool:\n"` |
| `_CONTENT_PREFIX` | String | `"extends RefCounted\nfunc _fn(player, target, event, game) -> void:\n"` |
| `_CONFIRM_PROMPT_PREFIX` | String | `"extends RefCounted\nfunc _fn(player, target, event, game) -> String:\n"` |

> 三个 prefix 均定义 `_fn(player, target, event, game)` 四参签名；区别仅在返回类型（bool / void / String）。

---

## 静态状态

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `_scripts` | Array[GDScript] | [] | 编译产生的 GDScript 引用列表，防止 GC |
| `_instances` | Array | [] | 编译产生的 Object 实例引用列表，防止 GC |
| `_path_counter` | int | 0 | 唯一 `resource_path` 计数器，每次生成新路径自增 |

> **重要调用约定**：[Game._compile_win_condition](../Game/Game.md#_compile_win_condition) 直接访问 `_path_counter`、`_scripts`、`_instances` 三个私有 static 成员编译胜利条件代码（不走 `compile_*` 公开接口），因为胜利条件 Callable 签名是单参 `(game) -> bool`，与 `compile_filter` 的四参签名不同。

---

## 公开静态接口

> 5 个 `compile_*` 接口，均接受 String 代码并返回 Callable。

### compile_filter(code: String) -> Callable

> 编译 filter 代码字符串为 Callable。
> **返回的 Callable 签名**：`(player, target, event, game) -> bool`。
> 空字符串（strip_edges 后）返回空 Callable（调用方视为恒真）。
> 编译失败时 `push_warning` 并降级为 `_create_noop_filter()`（恒返回 true）。

### compile_content(code: String) -> Callable

> 编译 content 代码字符串为 Callable。
> **返回的 Callable 签名**：`(player, target, event, game) -> void`。
> 空字符串返回空 Callable（调用方视为无操作）。
> 编译失败时 `push_warning` 并降级为 `_create_noop_content()`（无操作）。

### compile_filter_target(code: String) -> Callable

> 编译 filter_target 代码字符串为 Callable。
> **返回的 Callable 签名**：`(player, target, event, game) -> bool`（与 `compile_filter` 同 prefix）。
> `"true"` 或空字符串返回空 Callable（调用方视为无过滤）。
> 编译失败时降级为 `_create_noop_filter()`。

### compile_filter_card(code: String) -> Callable

> 编译 filter_card 代码字符串为 Callable。**直接转调** `compile_filter_target(code)`，二者编译逻辑相同。
> 返回签名同 `compile_filter_target`。

### compile_confirm_prompt(code: String) -> Callable

> 编译 confirm_prompt 代码字符串为 Callable。
> **返回的 Callable 签名**：`(player, target, event, game) -> String`。
> 空字符串返回空 Callable（调用方视为使用默认格式）。
> 编译失败时 `push_warning` 并返回空 Callable。

---

## 内部静态方法

### _next_path(prefix: String) -> String

> 生成唯一 `resource_path` 并自增计数器：`"res://addons/gut/not_a_real_file/%s_%d.gd" % [prefix, _path_counter]`，`_path_counter += 1`。
> 必须在 `reload()` 前调用，确保即使编译失败路径也不复用（避免 Godot 的 cyclic resource inclusion 警告）。

### _compile(source: String) -> Variant

> 编译 GDScript 源码并返回脚本实例。失败返回 null。
> 流程：
> 1. `script = GDScript.new()`
> 2. `script.source_code = source`
> 3. `script.resource_path = _next_path("ce")`
> 4. `result = script.reload()`；若 `result != OK` 返回 null
> 5. `_scripts.append(script)` 防止 GC
> 6. `instance = script.new()`；若为 null 返回 null
> 7. `_instances.append(instance)` 防止 GC
> 8. 返回 instance

### _create_noop_filter() -> Callable

> 创建 no-op filter Callable（恒返回 true）。
> 源码为 `"extends RefCounted\nfunc _fn(_p, _t, _e, _g) -> bool:\n\treturn true"`，编译流程同 `_compile`；失败返回空 Callable。

### _create_noop_content() -> Callable

> 创建 no-op content Callable（无操作）。
> 源码为 `"extends RefCounted\nfunc _fn(_p, _t, _e, _g) -> void:\n\tpass"`，编译流程同 `_compile`；失败返回空 Callable。

---

## 调用约定与降级策略

| compile 接口 | 空 code | 编译失败 |
|--------------|---------|---------|
| `compile_filter` | 空 Callable（调用方视为恒真） | `_create_noop_filter()`（恒真） |
| `compile_content` | 空 Callable（调用方视为无操作） | `_create_noop_content()`（无操作） |
| `compile_filter_target` | 空 Callable（视为无过滤） | `_create_noop_filter()`（恒真） |
| `compile_filter_card` | 同 `compile_filter_target` | 同 `compile_filter_target` |
| `compile_confirm_prompt` | 空 Callable（使用默认格式） | 空 Callable（使用默认格式） |

---

## win_condition_code 特殊处理

> 任务胜利条件代码（`MissionData.win_condition_code`）由 [Game._compile_win_condition](../Game/Game.md#_compile_win_condition) 编译，**不**走 `CodeExecutor.compile_*` 公开接口，而是直接访问 `CodeExecutor` 的私有 static 成员：
>
> - 拼接源码为 `"extends RefCounted\nfunc _fn(game) -> bool:\n\t" + code`（**单参 game**，非四参）
> - `script = GDScript.new()`、`script.source_code = full_code`
> - `script.resource_path = "res://addons/gut/not_a_real_file/wc_%d.gd" % CodeExecutor._path_counter`（直接读 `_path_counter`）
> - `CodeExecutor._path_counter += 1`（直接递增）
> - `script.reload()` 失败 `push_warning` 返回空 Callable
> - `CodeExecutor._scripts.append(script)`（直接追加防 GC）
> - `instance = script.new()`，`CodeExecutor._instances.append(instance)`（直接追加防 GC）
> - 返回闭包 `func() -> bool: return instance.call("_fn", Game)`（捕获全局 `Game` autoload 作为 game 参数）

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](../Game/Game.md) | `_create_skill_from_data` 调用 5 个 `compile_*` 接口编译 skill 代码字段；`_compile_win_condition` 直接访问其私有 static 成员 |
| [Skill](../Common/Skill.md) | Skill 实例的 `filter` / `content` / `filter_target` / `filter_card` / `confirm_prompt` 字段均为 CodeExecutor 编译产物 |
| [Engineering/CodeExecutor.md](../../Engineering/CodeExecutor.md) | 数据视角与编译流程详述 |
