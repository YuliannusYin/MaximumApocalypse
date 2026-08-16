# CodeExecutor 代码字段编译

> 本文档说明 `code_executor.gd`（类名 `CodeExecutor`）的职责、编译机制、接口与降级行为。
> 源码位置：`MxApoc_GDScript/src/data/code_executor.gd`。
> JSON 代码字段规范见 [DataFormat.md §四 / §五](DataFormat.md)。

---

## 一、职责

JSON 数据中的 `filter` / `content` / `filter_target` / `filter_card` / `confirm_prompt` 等"代码字段"是 GDScript 代码字符串，并非普通文本。`CodeExecutor` 负责在运行时将这些字符串懒编译为 `Callable`，供 `Skill` 在触发时机执行。

`Skill` 实例在首次需要执行某代码字段时调用对应的 `compile_*` 接口，编译产物被缓存复用。代码字符串内可直接访问形参 `player` / `target` / `event` / `game`，调用其公开方法完成判定或效果。

---

## 二、编译机制

`CodeExecutor` 通过 `GDScript.new()` 创建脚本对象，将代码字符串包装为完整源码后调用 `script.reload()` 触发编译。

**包装模板（以 filter 为例）：**

```
extends RefCounted
func _fn(player, target, event, game) -> bool:
    <代码字符串（整段缩进一级）>
```

三类前缀常量分别对应不同返回类型：

| 常量 | 模板 | 用途 |
| --- | --- | --- |
| `_FILTER_PREFIX` | `extends RefCounted\nfunc _fn(player, target, event, game) -> bool:\n` | `filter` / `filter_target` / `filter_card` |
| `_CONTENT_PREFIX` | `extends RefCounted\nfunc _fn(player, target, event, game) -> void:\n` | `content` |
| `_CONFIRM_PROMPT_PREFIX` | `extends RefCounted\nfunc _fn(player, target, event, game) -> String:\n` | `confirm_prompt` |

**关键实现要点：**

- 代码字符串通过 `code.indent("\t")` 整体缩进一级后嵌入模板，保证函数体缩进合法。
- 编译前由 `_next_path` 生成唯一 `resource_path`（形如 `res://addons/gut/not_a_real_file/ce_<n>.gd`）并自增 `_path_counter`，规避 Godot issue #65263（循环资源包含）。**必须在 `reload()` 前设置路径**，即便编译失败路径也不复用。
- 编译产物（`GDScript` 脚本对象与 `Object` 实例）分别存入静态数组 `_scripts` 与 `_instances`，**防止被垃圾回收**——因为 `Callable` 仅弱引用实例，若无强引用持有，实例会被回收导致调用失效。
- 参考实现：`addons/gut/dynamic_gdscript.gd`。

> **本工程不使用 `Expression` 类，也不使用 `eval()`**。原因：`Expression` 仅支持单表达式，无法表达 `for` / `if` / `await` / 多语句块；而 `content` 代码普遍包含这些结构（如循环伤害、异步确认、条件分支）。

---

## 三、5 个 compile_* 接口

全部为静态方法，入参为代码字符串，返回 `Callable`。

| 接口 | 签名 | 返回 Callable 签名 | 说明 |
| --- | --- | --- | --- |
| `compile_filter` | `compile_filter(code: String) -> Callable` | `(player, target, event, game) -> bool` | 编译可用条件代码 |
| `compile_content` | `compile_content(code: String) -> Callable` | `(player, target, event, game) -> void` | 编译效果代码 |
| `compile_filter_target` | `compile_filter_target(code: String) -> Callable` | `(player, target, event, game) -> bool` | 编译目标筛选代码 |
| `compile_filter_card` | `compile_filter_card(code: String) -> Callable` | `(player, target, event, game) -> bool` | 直接转调 `compile_filter_target` |
| `compile_confirm_prompt` | `compile_confirm_prompt(code: String) -> Callable` | `(player, target, event, game) -> String` | 编译确认提示代码 |

**空字符串处理：**

- `compile_filter` / `compile_content` / `compile_confirm_prompt`：空字符串直接返回空 `Callable`（调用方视为恒真 / 无操作 / 默认格式）。
- `compile_filter_target`：空字符串或字符串 `"true"` 均返回空 `Callable`（调用方视为无过滤）。
- `compile_filter_card`：行为同 `compile_filter_target`。

---

## 四、降级行为

编译失败（`script.reload()` 返回非 `OK`，或 `script.new()` 返回 `null`）时，`CodeExecutor` 通过 `push_warning` 输出告警并降级为 no-op `Callable`：

| 接口 | 降级 Callable 行为 |
| --- | --- |
| `compile_filter` | 恒真（返回 `true`），由 `_create_noop_filter` 生成 |
| `compile_content` | 无操作（`pass`），由 `_create_noop_content` 生成 |
| `compile_filter_target` | 恒真（返回 `true`） |
| `compile_filter_card` | 恒真（返回 `true`） |
| `compile_confirm_prompt` | 返回空 `Callable`（调用方视为使用默认格式） |

> no-op `Callable` 同样通过 `GDScript.new()` + `reload()` 编译一段固定源码生成（如 filter 的 no-op 源码为 `extends RefCounted\nfunc _fn(_p, _t, _e, _g) -> bool:\n\treturn true`），并将其脚本与实例存入 `_scripts` / `_instances` 防回收。

降级策略保证：即使某条数据代码字段有语法错误，游戏也不会崩溃——filter 恒真、content 无操作，仅该技能的判定 / 效果失效。

---

## 五、win_condition_code 特殊处理

任务胜利条件代码 `win_condition_code` **不走上述 5 个 `compile_*` 接口**，而由 `game.gd` 的私有方法 `_compile_win_condition` 单独编译。

**差异：**

- 包装模板为整函数形式，签名不同：

```
extends RefCounted
func _fn(game) -> bool:
    <代码字符串>
```

- 签名为 `(game) -> bool`（仅 `game` 单参），而非四参。
- **直接访问 `CodeExecutor` 的私有静态成员**：`CodeExecutor._path_counter`（生成唯一路径并自增）、`CodeExecutor._scripts`（追加脚本防回收）、`CodeExecutor._instances`（追加实例防回收）。
- 编译失败时 `push_warning` 并返回空 `Callable`；`GameStateMachine._check_mission_win_condition` 在 `Callable` 无效时直接返回 `true`（视为无须额外任务条件，仅靠面包车胜利）。
- 编译成功后返回一个闭包，调用时执行 `instance.call("_fn", Game)`。

**调用链：** `Game.setup_mission` 读取 `mission.win_condition_code` → 非空时调用 `_compile_win_condition` → 产物赋给 `mission_config.check_win_condition` → `GameStateMachine.check_win_condition` 在玩家回合结束后委托调用。

> 当前 `data/missions/*.json` 中所有任务的 `win_condition_code` 均为空字符串（靠面包车胜利），但 schema 与编译机制已支持非空代码。

---

## 六、代码字段语法约定

代码字段虽为字符串，但必须是合法的 GDScript 语句片段（嵌入函数体后能通过编译）。

### 6.1 filter / filter_target / filter_card

- 为 `return` 开头的布尔表达式，或求值为 bool 的语句。
- 示例：`return player.in_phase == "action" && player.get_number("action_count") > 0`
- 可包含多行条件（如面包车技能的 filter 含 `if` 分支判断）。

### 6.2 content

- 为多语句块，可包含 `\n` 换行、`\t` 缩进、`await` 异步调用、`for` / `while` / `if` 控制流。
- 可读写 `event` 字典（如 `event.num -= 1` 修改伤害值、`event["cancel"].call()` 取消事件、`event.targets` 访问目标列表）。
- 可调用 `player` / `target` / `game` 的公开方法（如 `player.consume_action(1)`、`target.damage(2, player)`、`game.get_target(...)`）。
- 可调用 `EventSystem.cancel(event)` 取消事件、`EventSystem` 静态方法。
- 可使用 `await player.confirm(...)` / `await player.choose_card(...)` 等异步 UI 交互。

### 6.3 trigger 多值语法

技能 `trigger` 字段可用中文顿号 `、` 分隔多个触发名（如 `"on_reveal_block、on_enter_block"`），由 `Skill.matches_trigger` 拆分匹配。`content` 内可通过 `event.trigger_name` 判断当前实际触发的名，走不同分支。

### 6.4 select_target 类型

`select_target` 可为 `Int` 或 `Array<Int>`：

- `Int`：固定选择数量；`-1` 表示射程内全部目标。
- `Array<Int>` 如 `[1, 3]`：表示可选数量范围（最少 1，最多 3）。

### 6.5 confirm_prompt

- 为 `return` 字符串表达式，根据 `player` / `target` / `event` / `game` 状态返回不同的确认提示文案。
- 示例：面包车技能根据燃料是否满返回"添加燃料"或"启动面包车"两种提示。
