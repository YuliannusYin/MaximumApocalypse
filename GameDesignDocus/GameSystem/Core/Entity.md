# Entity 实体基类

> **以 `entity.gd` 为准**。本文与 `MxApoc_GDScript/src/core/entity.gd` 完全对齐。
> 类名 `Entity`，继承 `RefCounted`。
> 所有可挂载技能、可触发事件的实体的基类。
> 继承关系：Entity ← Player / Monster / Card / MapBlock。
> 事件触发机制详见 [EventSystem.md](EventSystem.md)；**EventBus 信号总线详见 [System/EventBus.md](../System/EventBus.md)**（不在本章展开）。

---

## 一、设计职责

Entity 基类负责：

1. **技能挂载**：维护实体身上的技能列表（角色固有技能、装备技能、地块技能、临时技能等）
2. **事件触发**：提供统一的 `trigger(trigger_name, event)` 接口，遍历技能并执行匹配的 content
3. **通用流程**：提供跨子类共享的流程方法（如 `damage` 伤害流程）
4. **通用接口**：声明子类需实现的抽象方法（如 `death`）与通用查询接口

---

## 二、字段

| 字段名 | 类型 | 默认值 | 说明 |
|------|------|------|------|
| `skills` | Array[Skill] | `[]` | 挂载在该实体上的所有技能。`get_all_skills()` 返回此列表 |

> 子类各自扩展字段（如 Player 的 HP/饥饿/手牌区，Monster 的纠缠对象/射程等），详见各子类文档。

---

## 三、方法

### 1. 事件触发

#### 1.1 trigger(trigger_name, event)

遍历实体上所有匹配 `trigger_name` 的技能，依次执行。

| 签名 | 参数 | 返回 |
|------|------|------|
| `trigger(trigger_name: String, event: Dictionary) -> void` | `trigger_name` 触发名（英文键名）；`event` 事件对象 | 无（异步 await） |

**执行步骤**：

1. 调用 `EventSystem.set_trigger_name(event, trigger_name)` 写入当前触发名
2. 取 `skills.duplicate()` 作为迭代副本（避免技能 content 内挂载/移除技能导致迭代异常或死循环）
3. 对每个技能 `s`：
   - 若 `s.matches_trigger(trigger_name)` 为 `false`，跳过
   - 若 `s.execute_filter(self, event)` 为 `false`，跳过
   - **输出触发日志**：`"<触发者名> 触发了 <技能名>"`
   - `await s.execute_content(self, event)`
   - 若 `EventSystem.is_cancelled(event)` 为 `true`，break 跳出循环

**触发者名解析规则**：

- 默认触发者为 `self`
- 若 `self` 是 Monster 且 `event` 含 `player` 字段，触发者改取 `event["player"]`（怪物受伤时显示玩家名）
- 触发者名取值优先级：`player_name`（Player）→ `monster_name`（Monster）→ `block_name`（MapBlock）
- 技能名取值：优先 `skill_name`，为空时回退 `english_name`

> trigger 名代码用英文键名（如 `before_deal_damage` / `on_take_damage` / `on_game_start` 等），完整中英映射详见 [IdentifierMapping.md](../../Engineering/IdentifierMapping.md)。
> 技能的 `trigger` 字段支持「、」分隔的复合触发。技能 content 执行时可访问 `event` 与 `trigger_name`（位于 `event["trigger_name"]`）。

---

#### 1.2 trigger_only(trigger_name, event, skill_list)

仅在指定技能列表中触发匹配 `trigger_name` 的技能。

| 签名 | 参数 | 返回 |
|------|------|------|
| `trigger_only(trigger_name: String, event: Dictionary, skill_list: Array) -> void` | `trigger_name` 触发名；`event` 事件对象；`skill_list` 限定技能列表 | 无（异步 await） |

**与 `trigger` 的差异**：

- `trigger` 遍历 `self.skills` 全部技能
- `trigger_only` 仅遍历传入的 `skill_list` 子集

**用途**：用于 `on_draw_scavenge_card` 等自身反应触发器，避免已装备卡牌的同名触发器重复触发。

**执行步骤**：与 `trigger` 一致（set_trigger_name → 遍历 `skill_list` → matches_trigger → execute_filter → 输出日志 → execute_content → 检查 cancel）。

---

### 2. 技能挂载

#### 2.1 get_all_skills()

返回该实体身上的所有技能列表。

| 签名 | 返回 |
|------|------|
| `get_all_skills() -> Array[Skill]` | `skills` 字段 |

---

#### 2.2 add_skill(skill)

向实体挂载一个技能。

| 签名 | 参数 | 返回 |
|------|------|------|
| `add_skill(skill: Skill) -> void` | `skill` 待挂载的技能 | 无 |

- 将 `skill` 追加到 `skills` 末尾
- 典型场景：地块技能挂载到玩家身上、装备技能随装备加入

---

#### 2.3 remove_skill(skill)

从实体移除一个技能。

| 签名 | 参数 | 返回 |
|------|------|------|
| `remove_skill(skill: Skill) -> void` | `skill` 待移除的技能 | 无 |

- 调用 `skills.erase(skill)` 移除首个匹配项
- 典型场景：装备离开装备区、离开地块时清理地块技能

---

### 3. 伤害流程（通用，8 节点）

#### 3.1 damage(num, source, type = "", card = null)

「target 受到来自于 source 的 num 点类型为 type 的伤害」的流程方法。

| 签名 | 参数 | 返回 |
|------|------|------|
| `damage(num: int, source: Entity, type: Variant = "", card: Card = null) -> void` | `num` 伤害值；`source` 伤害来源（`null` 表示无来源）；`type` 伤害类型标识（可为 String 如 `"monster_attack"` / `"poison"` / `"hunger"`，或 int，**默认空字符串**）；`card` 武器牌（`null` 表示非武器伤害） | 无（异步 await） |

> **偏差修正**：`type` 默认值为**空字符串 `""`**（非 NULL）。
> `source = null` 时表示无来源伤害（饥饿/中毒），跳过所有 source 侧钩子。
> `card = null` 时表示非武器伤害；`card` 为武器牌时供「造成伤害时」filter 判断（如 gunslinger 空尖弹、mechanic 升级）。

**事件钩子顺序（8 节点 + 5.5/5.6 系统节点）**：

| 节点 | trigger 名（英文键名） | 触发对象 | 说明 |
|------|------------------------|---------|------|
| 1 | `before_deal_damage` | source | source != null 时触发 |
| 2 | `before_take_damage` | target | 始终触发（含无来源伤害） |
| 3 | `on_deal_damage` | source | source != null 时触发；可修改 `event.num`（伤害加成）；可通过 `event.card` 判断武器 |
| 4 | `on_take_damage` | target | **取消点**；可修改 `event.num`（伤害减免）或调用 `event.cancel()` |
| 5 | （系统扣血） | — | `reduce_hp(event.num)`，非钩子节点 |
| 5.5 | （EventBus 信号） | — | 实际扣血量大于 0 时发射 `damage_taken` / `damage_dealt` 信号，非钩子节点 |
| 5.6 | （日志记录） | — | 玩家/怪物受伤时输出区分来源的伤害日志，非钩子节点 |
| 6 | `after_deal_damage` | source | source != null 时触发 |
| 7 | `after_take_damage` | target | 始终触发（含无来源伤害） |
| 8 | （死亡判定） | — | `get_hp() <= 0` → 调用 `death(source)`（多态） |

**前置守卫**：

- `num <= 0`：直接 return
- `get_hp() <= 0`：直接 return（已死亡不再受伤）

**event 字段**：`target`、`source`（可 `null`）、`num`（可读写）、`type`、`card`（可 `null`）、`cancelled`、`cancel`、`trigger_name`

**5.5 EventBus 信号发射**（实际扣血量大于 0 时）：

- 始终发射 `EventBus.damage_taken.emit(self, source, actual_damage)`（target、source、实际扣血量）
- source != null 时额外发射 `EventBus.damage_dealt.emit(source, self, actual_damage)`（source、target、实际扣血量）
- 实际扣血量 = `hp_before - get_hp()`，仅统计 trigger 修改/取消后的实际扣血值

> EventBus 信号总线详见 [System/EventBus.md](../System/EventBus.md)。

**5.6 受伤日志规则**：

- 玩家受伤时根据 `type` 区分：
  - `"monster_attack"` + source 为 Monster → `"<玩家名> 受到 <怪物名> 造成的 <num> 点伤害"`
  - `"hunger"` → `"<玩家名> 因饥饿受到 <num> 点伤害"`
  - `"poison"` → `"<玩家名> 因中毒受到 <num> 点伤害"`
  - `"block_destroy"` → `"<玩家名> 因地块摧毁受到 <num> 点伤害"`
  - 其他 → `"<玩家名> 受到 <num> 点伤害"`
- 怪物受伤时：
  - source 为 Player → `"<怪物名> 受到 <玩家名> 造成的 <num> 点伤害"`
  - 其他 → `"<怪物名> 受到 <num> 点伤害"`

> **说明**：原 `DamageFlow.md` 中通过 `is_player()` / `is_monster()` 分支调用 `player_death` / `monster_death`，此处统一为多态调用 `death(source)`，由子类实现具体死亡流程。

---

### 4. 生命值接口（子类必须 override）

| 方法 | 签名 | 默认实现 | 说明 |
|------|------|---------|------|
| `get_hp()` | `get_hp() -> int` | 返回 `0` | 返回当前生命值 |
| `get_max_hp()` | `get_max_hp() -> int` | 返回 `0` | 返回最大生命值上限 |
| `reduce_hp(n)` | `reduce_hp(n: int) -> void` | 空实现 | 直接扣血（底层原子方法，不触发钩子） |
| `add_hp(n)` | `add_hp(n: int) -> void` | 空实现 | 直接加血（底层原子方法，不触发钩子，不受最大值约束） |

> 子类必须 override 上述方法以提供真实数值。子类可在此基础上增加受钩子约束的高层方法（如 Player 的 `recover(num)` 走完整回复流程）。

---

### 5. 类型判断

| 方法 | 签名 | 默认实现 | 说明 |
|------|------|---------|------|
| `is_player()` | `is_player() -> bool` | 返回 `false` | 是否为 Player 实例 |
| `is_monster()` | `is_monster() -> bool` | 返回 `false` | 是否为 Monster 实例 |

> 用于流程中需要区分实体类型的场景。多数场景应优先使用多态（如 `death()`）而非类型判断。

---

### 6. 抽象方法（子类实现）

#### 6.1 death(source)

死亡流程的抽象方法，由子类实现：

| 签名 | 参数 | 返回 |
|------|------|------|
| `death(source: Entity) -> void` | `source` 致死者 | 无 |

- `Player.death(source)` → 调用 `player_death` 流程，见 [Player.md](../Entities/Player.md)
- `Monster.death(source)` → 调用 `monster_death` 流程，见 [Monster.md](../Entities/Monster.md)

由 `damage` 流程节点 8 在 target 生命值 ≤ 0 时调用。

---

## 四、trigger 名英文键名清单（摘要）

> 完整中英映射详见 [IdentifierMapping.md](../../Engineering/IdentifierMapping.md)。以下为 Entity.damage 流程涉及的 trigger：

| 英文键名 | 中文显示 |
|---------|---------|
| `before_deal_damage` | 造成伤害前 |
| `before_take_damage` | 受到伤害前 |
| `on_deal_damage` | 造成伤害时 |
| `on_take_damage` | 受到伤害时 |
| `after_deal_damage` | 造成伤害后 |
| `after_take_damage` | 受到伤害后 |
| `on_game_start` | 游戏开始时 |
| `on_game_over` | 游戏结束时 |

---

## 五、与其他类的关系

| 关系 | 说明 |
|------|------|
| Player | 继承 Entity，扩展玩家状态与玩家专属流程 |
| Monster | 继承 Entity，扩展怪物属性与行动/攻击流程 |
| Card | 继承 Entity，卡牌自带技能（装备技能、行动牌效果、怪物卡技能） |
| MapBlock | 继承 Entity，地块技能挂载到进入的 Player 身上由 Player.trigger 触发 |
| Skill | 通过 `add_skill` / `remove_skill` 挂载到 Entity，见 [Skill.md](../Common/Skill.md) |
| EventSystem | 提供 event schema 与取消机制，见 [EventSystem.md](EventSystem.md) |
| EventBus | damage 流程 5.5 节点发射统计信号，详见 [System/EventBus.md](../System/EventBus.md) |
