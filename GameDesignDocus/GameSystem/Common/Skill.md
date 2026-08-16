# Skill 技能结构

> 职责：定义技能的字段规范与执行接口，并提供通用行动技能实例。
> 类名 `Skill`，继承 `RefCounted`。
> Skill **不继承** Entity，是挂载在 Entity 上的数据结构。
> 技能通过 [Entity.trigger](../Core/Entity.md) 被遍历与执行。

> 对齐代码：`MxApoc_GDScript/src/common/skill.gd`

---

## 一、字段规范

### 1.1 完整字段表

| 字段名 | 类型 | 默认值 | 说明 |
|------|------|------|------|
| `skill_name` | String | `""` | 技能名 |
| `english_name` | String | `""` | 英文名 |
| `skill_description` | String | `""` | 技能描述 |
| `active` | String | `""` | 可主动使用的技能声明可用阶段（如"行动阶段"）。空字符串表示非主动技能 |
| `trigger` | String | `""` | 触发名，支持「、」分隔的复合触发（如"游戏开始时、受到伤害时"）。空字符串表示无触发 |
| `skill_type` | String | `""` | 技能类型（如"装备"、"行动"） |
| `forced` | bool | `false` | 是否强制发动 |
| `filter` | Callable | `Callable()` | 触发条件过滤函数，返回 bool。`Callable()` 表示无过滤（恒真） |
| `filter_target` | Callable | `Callable()` | 目标过滤函数，返回 bool |
| `filter_target_range` | String | `""` | 目标距离限制，取值见 §1.3 射程枚举 |
| `filter_card` | Callable | `Callable()` | 选牌过滤函数 |
| `position` | String | `""` | 选牌位置限定（如"手牌区"） |
| `select_card` | int | `0` | 需选择的牌数 |
| `select_target` | int | `0` | 需选择的目标数 |
| `range` | String | `""` | 攻击射程，取值见 §1.3 射程枚举 |
| `usable` | int | `-1` | 每回合可用次数限制。`-1` 表示不限 |
| `content` | Callable | `Callable()` | 技能效果执行体 |
| `target_type` | String | `""` | 目标类型（`""` / `"block"` / `"entity"` / `"pile"` / `"equipment"`），用于 use_active_skill 目标选择 |
| `confirm_prompt` | Callable | `Callable()` | 动态确认提示函数，返回 String。`Callable()` 表示使用默认格式 |
| `defer_action_cost` | bool | `false` | 是否延迟结算行动消耗 |
| `used_count` | int | `0` | 运行时：本回合已使用次数（用于 `usable` 限制） |

> 字段完整清单与命名规范见 [IdentifierMapping.md](../../Engineering/IdentifierMapping.md)。

### 1.2 技能类型分类

| 类型 | 说明 |
|------|------|
| 主动技能 | 声明 `active`，玩家在对应阶段主动使用（如通用行动技能） |
| 触发技能 | 声明 `trigger`，在对应事件节点自动触发（如装备技能、地块技能） |
| 被动技能 | 无 `active` 无 `trigger`，提供持续性效果（如背包增加装备栏） |

### 1.3 射程枚举值

> 代码字段 `filter_target_range` 与 `range` 均使用英文键名。文档建立中英映射如下：

| 代码值（英文键名） | 中文显示 |
|-------------------|---------|
| `"short"` | 短距离 |
| `"medium"` | 中距离 |
| `"long"` | 长距离 |
| `"infinity"` | 无限距离 |
| `""` | 无 / 不限制 |

> 射程判定规则详见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md)。

### 1.4 content / filter 四参调用约定

`filter` 与 `content` 的 Callable 实际为**四参调用**：

| 参数 | 含义 |
|------|------|
| `player` | 触发技能的实体（主动技能与玩家侧触发技能为玩家；怪物侧为怪物） |
| `target` | 当前事件的目标（取自 `event.get("target", null)`，无则 `null`） |
| `event` | 事件对象（结构随流程类型变化，见 [EventSystem.md](../Core/EventSystem.md)） |
| `Game` | 全局 Game 单例（autoload） |

- `execute_filter(player, event)` 内部以 `filter.call(player, event.get("target", null), event, Game)` 调用
- `execute_content(player, event)` 内部以 `await content.call(player, event.get("target", null), event, Game)` 调用
- `execute_confirm_prompt(player)` 内部以 `confirm_prompt.call(player, null, {}, Game)` 调用

### 1.5 复合触发

技能的 trigger 字段可用顿号分隔多个触发名（如「游戏开始时、受到伤害时」），由 `matches_trigger` 拆分匹配任一即视为命中。code 字段内可通过查询当前触发名（`event.trigger_name` 字段，由 `EventSystem.set_trigger_name` 写入）走不同分支：当前为「游戏开始时」时执行游戏开始时分支；当前为「受到伤害时」时执行受到伤害时分支。

> trigger 名代码用英文键名清单详见 [IdentifierMapping.md](../../Engineering/IdentifierMapping.md)。

---

## 二、方法

### 1. matches_trigger(trigger_name)

判断本技能是否响应指定 trigger 名。

| 签名 | 参数 | 返回 |
|------|------|------|
| `matches_trigger(trigger_name: String) -> bool` | `trigger_name` 触发名 | 匹配返回 `true`；`trigger` 为空或无匹配返回 `false` |

- 将 `trigger` 字段按「、」分割为列表，判断是否包含 `trigger_name`

---

### 2. execute_filter(player, event)

执行 `filter`。无有效 `filter` 时返回 `true`（恒通过）。

| 签名 | 参数 | 返回 |
|------|------|------|
| `execute_filter(player: Variant, event: Dictionary) -> bool` | `player` 触发技能的实体；`event` 事件对象 | `filter` 返回值；`filter` 无效时返回 `true` |

- 内部以四参调用 `filter.call(player, event.get("target", null), event, Game)`

---

### 3. execute_content(player, event)

执行 `content`。

| 签名 | 参数 | 返回 |
|------|------|------|
| `execute_content(player: Variant, event: Dictionary) -> void` | `player` 触发技能的实体；`event` 事件对象 | 无（异步 await） |

- 内部以四参调用 `await content.call(player, event.get("target", null), event, Game)`
- `content` 代码可通过 `EventSystem.cancel(event)` 取消事件，调用方用 `EventSystem.is_cancelled(event)` 检查
- 无有效 `content` 时跳过执行

---

### 4. execute_confirm_prompt(player)

执行 `confirm_prompt`，返回动态确认提示文本。

| 签名 | 参数 | 返回 |
|------|------|------|
| `execute_confirm_prompt(player: Variant) -> String` | `player` 触发技能的实体 | 提示文本；`confirm_prompt` 无效时返回 `""` |

- 内部以四参调用 `confirm_prompt.call(player, null, {}, Game)`

---

### 5. is_usable()

本回合是否仍可使用（受 `usable` 限制）。

| 签名 | 返回 |
|------|------|
| `is_usable() -> bool` | 仍可使用返回 `true` |

- `usable < 0`（不限）时返回 `true`
- 否则返回 `used_count < usable`

---

### 6. record_use()

记录一次使用。

| 签名 | 返回 |
|------|------|
| `record_use() -> void` | 无 |

- 将 `used_count` 自增 1

---

### 7. reset_use_count()

重置使用次数（回合开始时调用）。

| 签名 | 返回 |
|------|------|
| `reset_use_count() -> void` | 无 |

- 将 `used_count` 置为 `0`

---

## 三、通用行动技能

> 6 个所有玩家共享的通用行动技能。
> 这些技能是 [Player](../Entities/Player.md) 类的固有技能，在行动阶段可用。
> 行动阶段玩家可按任意组合执行共 4 个行动（可多次执行同一行动）。

### 行动选项

1. 横向或竖向移动 1 格（移动技能）
2. 从求生者游戏牌堆中抓 1 张牌（摸牌技能）
3. 从手牌中打出 1 张牌
4. 执行 1 张已经在游戏中的卡牌上的行动
5. 拾荒：根据当前地点押 1 张拾荒卡（拾荒技能）

### 免费行动

- 每回合一次：弃掉两张求生者游戏牌来从游戏牌堆抓一张新牌（制衡技能）
- 每回合一次：与另一名同地图块玩家交易拾荒卡（交易技能）

---

### 移动

- 技能描述：移动到目标地块
- 可用阶段：行动阶段
- 可用条件：处于行动阶段，且玩家剩余行动次数大于 0
- 目标筛选：目标不是玩家当前所在地块
- 目标范围：中距离（目标地块必须在相邻地块范围内）
- 效果：玩家剩余行动次数减 1；玩家移动到目标地块

---

### 拾荒

- 技能描述：从可以进行拾荒的牌堆中抓取一张牌
- 可用阶段：行动阶段
- 可用条件：处于行动阶段，玩家剩余行动次数大于 0，且当前所在地块有拾荒牌堆
- 目标筛选：目标地块的拾荒牌堆颜色属于当前地块支持的拾荒颜色集合
- 效果：玩家剩余行动次数减 1；玩家从目标拾荒牌堆抓 1 张牌

---

### 摸牌

- 技能描述：从玩家游戏牌堆中抓取一张牌
- 可用阶段：行动阶段
- 可用条件：处于行动阶段，且玩家剩余行动次数大于 0
- 效果：玩家剩余行动次数减 1；玩家从游戏牌堆抓 1 张牌

---

### 制衡

- 技能描述：弃置两张玩家游戏牌，然后从玩家游戏牌堆中抓取一张牌
- 可用阶段：行动阶段
- 可用次数：每回合 1 次
- 可用条件：处于行动阶段（免费行动，不消耗行动次数）
- 卡牌选择：2 张
- 卡牌筛选：选中的牌必须是玩家的求生者游戏牌
- 位置：手牌区
- 效果：弃置所选的 2 张牌；从游戏牌堆抓 1 张牌

---

### 交易

- 技能描述：选择一张拾荒牌和同地图块内另一玩家，将该拾荒牌向该玩家展示，其可以选择一张手中的拾荒牌与你交易
- 可用阶段：行动阶段
- 可用次数：每回合 1 次
- 可用条件：处于行动阶段，且当前地块玩家数大于 1
- 卡牌选择：1 张
- 卡牌筛选：选中的牌必须是拾荒牌
- 位置：手牌区
- 目标选择：1 个
- 目标范围：短距离（同地块内）
- 目标筛选：目标不是玩家自身，且目标持有拾荒牌
- 效果：向目标展示所选的拾荒牌；询问目标是否同意交易；若同意，目标从其手牌区选择 1 张拾荒牌，双方交换该两张拾荒牌

---

### 加油

- 技能描述：消耗一个燃料，为面包车或燃料型装备补充燃料
- 可用阶段：行动阶段
- 可用次数：不限
- 可用条件：处于行动阶段，且玩家装备区里有"燃料"（免费行动，不消耗行动次数）
- 目标范围：短距离
- 目标筛选：目标为玩家当前所在地块且地块名为"面包车"；或目标的填充物类型为"燃料"
- 效果：从装备区弃置 1 张"燃料"；若目标为面包车，向面包车添加 1 个燃料；否则向目标装备添加最大燃料量

---

## 四、其他技能来源

> 通用行动技能之外，技能还来自以下来源，均遵循上述 Skill 结构。

| 来源 | 挂载位置 | 说明 |
|------|---------|------|
| 角色固有技能 | Player | 角色开局即拥有，非卡牌。见各 [SurvivorPacks](../../Resource/SurvivorPacks/) |
| 装备技能 | Player（装备时） | 装备牌进入装备区时挂载，离开时移除。见 [Player.md](../Entities/Player.md) |
| 行动牌效果 | Card | 即时使用，使用后弃掉 |
| 地块技能 | Player（进入地块时） | 地块技能挂载到进入的玩家身上，离开时清理。见 [MapBlock.md](../Entities/MapBlock.md) |
| 怪物技能 | Monster | 怪物自带技能。见 [Monster.md](../Entities/Monster.md) |

---

## 五、与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | Skill 通过 `add_skill` 挂载到 Entity，由 `Entity.trigger` 遍历执行 |
| [EventSystem](../Core/EventSystem.md) | `trigger` 字段引用 EventSystem 定义的 trigger 名 |
| [Player](../Entities/Player.md) | 通用行动技能是 Player 的固有技能 |
| [RoleCard](RoleCard.md) | 角色固有技能存储在 RoleCard 上 |
