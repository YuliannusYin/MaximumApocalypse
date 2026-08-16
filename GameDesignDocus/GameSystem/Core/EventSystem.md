# EventSystem 事件触发系统

> 职责：游戏所有流程的钩子编排机制。提供 event Dictionary 的构建工厂与取消机制。
> 类名 `EventSystem`，继承 `RefCounted`。
> **纯静态工具类，无字段，无实例**。所有方法均为 `static func`。
> trigger 方法定义在 [Entity.md](Entity.md) 的 `Entity.trigger()`。
> **EventBus 信号总线详见 [System/EventBus.md](../System/EventBus.md)**（不在本章展开）。

> 对齐代码：`MxApoc_GDScript/src/core/event_system.gd`

---

## 一、机制原理

### 1.1 触发流程

`Entity.trigger(trigger_name, event)` 的工作步骤：

1. 调用 `EventSystem.set_trigger_name(event, trigger_name)` 写入当前触发名
2. 取实体 `skills` 的副本进行迭代
3. 遍历每个技能 `s`：
   - 调用 `s.matches_trigger(trigger_name)`（按「、」分隔判断）
   - 调用 `s.execute_filter(self, event)`（内部四参调用）
   - 执行前输出触发日志
   - 调用 `s.execute_content(self, event)`（内部四参调用）
   - 若 `EventSystem.is_cancelled(event)` 为 `true`，break 跳出循环

### 1.2 技能的 trigger 字段

- **单触发**：`trigger: "on_take_damage"`
- **复合触发**：`trigger: "on_game_start、on_take_damage"`（「、」分隔，content 内通过 `event["trigger_name"]` 判断分支）

### 1.3 filter / content 四参调用

技能 `filter` 与 `content` 的 Callable 实际为**四参调用**：

| 参数 | 含义 |
|------|------|
| `player` | 触发技能的实体 |
| `target` | 当前事件的目标（取自 `event.get("target", null)`，无则 `null`） |
| `event` | 事件对象（见 §2 event schema） |
| `Game` | 全局 Game 单例（autoload） |

- `execute_filter` 内部以 `filter.call(player, event.get("target", null), event, Game)` 调用
- `execute_content` 内部以 `await content.call(player, event.get("target", null), event, Game)` 调用
- 详见 [Skill.md §1.4](../Common/Skill.md)

---

## 二、event 对象 schema

### 2.1 通用字段

> 所有 event 均为 Dictionary。字段键名统一 snake_case。

| 字段名 | 类型 | 说明 |
|------|------|------|
| `trigger_name` | String | 由 `set_trigger_name()` 设置，当前触发的 trigger 名 |
| `cancelled` | bool | 是否已取消。`cancel()` 后置 `true` |
| `cancel` | Callable | 取消当前事件的闭包。调用 `event["cancel"].call()` 或 `EventSystem.cancel(event)` 后流程立即终止 |

### 2.2 按流程类型的字段

> **目标字段命名约定**：为避免歧义，不同流程使用不同字段名表达「目标」语义：
> - `target`：实体目标（伤害流程的受伤实体、死亡流程的死亡实体）
> - `target_block`：地块目标（移动流程的进入地块）
> - `block`：地块对象（检定、摧毁、标记等流程）
> - `card`：当前卡牌（抓牌流程当前抓到的牌、弃置/销毁流程当前处理的牌、装备流程的装备牌、消耗填充物的装备）
> - `cards`：卡牌列表（抓牌流程实际抓到的牌列表、弃置流程的卡牌数组）
> - `targets`：目标列表（主动技能经 filter 筛选后的目标列表，复数）

| 流程 | event 字段 |
|------|-----------|
| 伤害流程 | `target`、`source`（可 `null`）、`num`（可读写）、`type`、`card`（可 `null`） |
| 回复生命 | `player`、`num`（可读写） |
| 移动流程 | `player`、`source_block`（离开地块）、`target_block`（进入地块） |
| 抓游戏牌 | `player`、`num`（可读写）、`cards`（实际抓到的牌列表） |
| 抓拾荒牌 | `player`、`pile`、`num`（可读写）、`cards`、`card`（当前牌） |
| 抓怪物卡 | `player`、`num`、`cards`、`card`（当前怪物卡，实体化后） |
| 弃置/销毁牌 | `player`、`card`（当前牌）、`cards`、`num` |
| 怪物死亡 | `target`（死亡的怪物）、`source`（击杀者） |
| 玩家死亡 | `target`（死亡的玩家）、`source`（击杀者，可 `null`） |
| 装备进入/离开 | `player`、`card` |
| 消耗填充物 | `player`、`card`（装备）、`num` |
| 潜行检定 | `player`、`block`（可 `null`）、`sneak_value`、`result`（结构体 `{ value, success }`）、`skip_judge`（是否跳过投骰） |
| 怪物出生检定 | `player`、`result`（结构体 `{ value, success }`，success 恒为 `true`）、`skip_judge` |
| 摧毁地块流程 | `source`（摧毁者，可 `null`）、`block`（被摧毁的地块） |
| 触发目标标记 | `player`、`block`、`mark`（ObjectiveMark 结构，见 [MapBlock.md](../Entities/MapBlock.md)） |
| 主动技能 | `player`、`targets`（filter 筛选后的目标列表，复数） |
| 游戏开始 | `player` |
| 游戏结束 | `player`、`result` |
| 怪物行动 | `monster`、`target_players`（初始为空数组，流程中填充） |

### 2.3 cancel 语义

- 调用 `event["cancel"].call()` 或 `EventSystem.cancel(event)` 后，`event["cancelled"] = true`
- `trigger()` 循环立即 break，不再执行后续技能
- 流程方法检测到 `cancelled` 后 return，跳过后续节点
- **已执行的钩子不回滚**，例外：移动流程会回滚地块技能挂载（见 [Player.md moveTo](../Entities/Player.md)）
- `cancel` 是一个引用 event 的 Callable 闭包（GDScript Dictionary 为引用类型，闭包捕获的引用指向同一字典）

---

## 三、方法

### 3.1 通用 event 工厂

#### create_event(initial = {})

创建通用 event：注入 `trigger_name` / `cancelled` / `cancel` 字段，并合并调用方传入的初始字段。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_event(initial: Dictionary = {}) -> Dictionary` | `initial` 调用方传入的初始字段 | 新构建的 event Dictionary |

- 默认包含字段：`trigger_name`（`""`）、`cancelled`（`false`）、`cancel`（Callable 闭包）
- `cancel` 闭包通过 `(func(ev): return func(): ev["cancelled"] = true).call(event)` 构造，捕获 event 引用
- 调用方传入的 `initial` 字段会覆盖默认字段

> 各流程工厂方法在此基础上追加流程专属字段。

---

#### cancel(event)

取消事件：设置 `cancelled = true`。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static cancel(event: Dictionary) -> void` | `event` 待取消的事件 | 无 |

- 等价于 `event["cancel"].call()`，直接置 `cancelled` 字段

---

#### is_cancelled(event)

是否已取消。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static is_cancelled(event: Dictionary) -> bool` | `event` 待检查的事件 | `cancelled` 字段值，默认 `false` |

---

#### set_trigger_name(event, trigger_name)

设置当前触发名。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static set_trigger_name(event: Dictionary, trigger_name: String) -> void` | `event` 事件对象；`trigger_name` 触发名 | 无 |

- 由 `Entity.trigger()` / `Entity.trigger_only()` 在遍历前调用

---

### 3.2 流程 event 工厂

#### create_damage_event(target, source, num, type, card = null)

构建伤害流程 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_damage_event(target: Entity, source: Entity, num: int, type: Variant, card: Card = null) -> Dictionary` | `target` 受伤实体；`source` 伤害来源；`num` 伤害值；`type` 伤害类型；`card` 武器牌 | event Dictionary |

- 字段：`target`、`source`、`num`、`type`、`card`

---

#### create_recover_event(player, num)

构建回复生命 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_recover_event(player: Variant, num: int) -> Dictionary` | `player` 回复玩家；`num` 回复值 | event Dictionary |

- 字段：`player`、`num`

---

#### create_move_event(player, source_block, target_block)

构建移动流程 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_move_event(player: Variant, source_block: MapBlock, target_block: MapBlock) -> Dictionary` | `player` 移动玩家；`source_block` 离开地块；`target_block` 进入地块 | event Dictionary |

- 字段：`player`、`source_block`、`target_block`

---

#### create_draw_game_card_event(player, num)

构建抓游戏牌 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_draw_game_card_event(player: Variant, num: int) -> Dictionary` | `player` 抓牌玩家；`num` 抓牌数 | event Dictionary |

- 字段：`player`、`num`、`cards`（初始空数组）

---

#### create_draw_scavenge_event(player, pile, num)

构建抓拾荒牌 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_draw_scavenge_event(player: Variant, pile: Pile, num: int) -> Dictionary` | `player` 抓牌玩家；`pile` 拾荒牌堆；`num` 抓牌数 | event Dictionary |

- 字段：`player`、`pile`、`num`、`cards`（初始空数组）、`card`（初始 `null`）

---

#### create_draw_monster_event(player, num)

构建抓怪物卡 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_draw_monster_event(player: Variant, num: int) -> Dictionary` | `player` 抓牌玩家；`num` 抓牌数 | event Dictionary |

- 字段：`player`、`num`、`cards`（初始空数组）、`card`（初始 `null`）

---

#### create_discard_event(player, cards, num = 1)

构建弃置/销毁牌 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_discard_event(player: Variant, cards: Array, num: int = 1) -> Dictionary` | `player` 弃牌玩家；`cards` 卡牌数组；`num` 弃牌数 | event Dictionary |

- 字段：`player`、`card`（初始 `null`）、`cards`、`num`

---

#### create_monster_death_event(target, source)

构建怪物死亡 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_monster_death_event(target: Entity, source: Entity) -> Dictionary` | `target` 死亡的怪物；`source` 击杀者 | event Dictionary |

- 字段：`target`、`source`

---

#### create_player_death_event(target, source)

构建玩家死亡 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_player_death_event(target: Variant, source: Variant) -> Dictionary` | `target` 死亡的玩家；`source` 击杀者（可 `null`） | event Dictionary |

- 字段：`target`、`source`

---

#### create_equip_event(player, card)

构建装备进入/离开 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_equip_event(player: Variant, card: Card) -> Dictionary` | `player` 装备玩家；`card` 装备牌 | event Dictionary |

- 字段：`player`、`card`

---

#### create_consume_charge_event(player, equipment, num)

构建消耗填充物 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_consume_charge_event(player: Variant, equipment: Variant, num: int) -> Dictionary` | `player` 玩家；`equipment` 装备；`num` 消耗数 | event Dictionary |

- 字段：`player`、`card`（即 `equipment`）、`num`

---

#### create_sneak_judge_event(player, sneak_value, block = null)

构建潜行检定 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_sneak_judge_event(player: Variant, sneak_value: int, block: Variant = null) -> Dictionary` | `player` 检定玩家；`sneak_value` 潜行阈值；`block` 所在地块 | event Dictionary |

- 字段：`player`、`block`、`sneak_value`、`result`（初始 `{ value: 0, success: false }`）、`skip_judge`（初始 `false`）

---

#### create_spawn_judge_event(player)

构建怪物出生检定 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_spawn_judge_event(player: Variant) -> Dictionary` | `player` 检定玩家 | event Dictionary |

- 字段：`player`、`result`（初始 `{ value: 0, success: true }`，success 恒为 `true`）、`skip_judge`（初始 `false`）

---

#### create_destroy_block_event(source, block)

构建摧毁地块 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_destroy_block_event(source: Variant, block: MapBlock) -> Dictionary` | `source` 摧毁者（可 `null`）；`block` 被摧毁的地块 | event Dictionary |

- 字段：`source`、`block`

---

#### create_objective_mark_event(player, block, mark)

构建触发目标标记 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_objective_mark_event(player: Variant, block: MapBlock, mark: Dictionary) -> Dictionary` | `player` 触发玩家；`block` 所在地块；`mark` ObjectiveMark 结构 | event Dictionary |

- 字段：`player`、`block`、`mark`

---

#### create_active_skill_event(player, targets)

构建主动技能 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_active_skill_event(player: Variant, targets: Array) -> Dictionary` | `player` 主动技能玩家；`targets` 目标列表 | event Dictionary |

- 字段：`player`、`targets`

---

#### create_game_start_event(player)

构建游戏开始 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_game_start_event(player: Variant) -> Dictionary` | `player` 玩家 | event Dictionary |

- 字段：`player`
- **说明**：该方法存在但未被 `GameStateMachine.start_game()` 调用，状态机直接用 `create_event({"player": player})` 构建游戏开始事件

---

#### create_game_over_event(player, result)

构建游戏结束 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_game_over_event(player: Variant, result: int) -> Dictionary` | `player` 玩家；`result` 游戏结果（`GameResult.WIN` / `GameResult.LOSE`） | event Dictionary |

- 字段：`player`、`result`
- **说明**：该方法存在但未被 `GameStateMachine.game_over()` 调用，状态机直接用 `create_event({"player": player, "result": result})` 构建游戏结束事件

---

#### create_monster_act_event(monster)

构建怪物行动 event。

| 签名 | 参数 | 返回 |
|------|------|------|
| `static create_monster_act_event(monster: Monster) -> Dictionary` | `monster` 行动怪物 | event Dictionary |

- 字段：`monster`、`target_players`（初始空数组，流程中填充）

---

## 四、trigger 名命名规范

### 4.1 命名模式

采用「**before / on / after** + 英文动作」三段式，对称包围系统结算节点：

- `before_*`：系统结算前，可取消
- `on_*`：系统结算时，可修改 event 字段（如 `num`、`result`），部分为取消点
- `after_*`：系统结算后，仅通知

### 4.2 取消点约定

- 并非所有 `on_*` 节点都是取消点
- 取消点位于 `on_*` 节点：如 `on_take_damage`、`on_draw_game_card`、`before_enter_block`（注意 `before_*` 也可作取消点）

### 4.3 复合触发

`trigger` 字段支持「、」分隔的多个触发名，content 内通过 `event["trigger_name"]` 判断分支。

> trigger 名代码用英文键名清单详见 [IdentifierMapping.md](../../Engineering/IdentifierMapping.md)。

---

## 五、与其他文档的关系

| 文档 | 关系 |
|------|------|
| [Entity.md](Entity.md) | `Entity.trigger()` / `Entity.trigger_only()` 方法定义处 |
| [Player.md](../Entities/Player.md) | Player 类的流程方法定义各 trigger 的触发节点 |
| [Monster.md](../Entities/Monster.md) | Monster 类的死亡/行动/攻击 trigger |
| [Skill.md](../Common/Skill.md) | Skill 结构的 `trigger` 字段引用本文的 trigger 名 |
| [System/EventBus.md](../System/EventBus.md) | EventBus 信号总线，供 UI 层订阅游戏事件 |
| [04_事件流与变体.md](../../GameInstructions/04_事件流与变体.md) | GameInstructions 侧的事件流程汇总，本文为其源定义 |
