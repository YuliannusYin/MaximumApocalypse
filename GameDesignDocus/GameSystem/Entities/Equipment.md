# Equipment 装备实体类

> 继承：[Entity](../Core/Entity.md)
> 职责：装备区的实体表示，由 [EquipmentCard](Card.md#equipmentcard-装备牌) 实体化生成。镜像 [Monster](Monster.md) 的实体化模式：装备区持有实体，弃牌堆 / EventBus / 钩子收到的永远是来源 EquipmentCard。
> 代码：`src/entities/equipment.gd`，`class_name Equipment extends Entity`。

---

## 实体化来源

装备牌进入玩家装备区时，由 `EquipmentCard.instantiate(player)` 复制卡面数据到本类实例。实体化时：

- 设置 `equipment_name = card.card_name`，`card_name = card.card_name`（兼容下游按 card_name 查询）
- 复制 `english_name` / `card_type` / `card_subtype` / `source` / `size` / `range` / `weapon` / `charge_type` / `charge_max`
- `in_equipment_area = true`，`equipment_card = card`（回引来源卡），`equipped_player = player`
- 复制卡牌 `skills` 到 Equipment 实例

> 详见 [EquipmentCard.instantiate](Card.md#equipmentcard-装备牌) 与 [Player.equip](Player.md#装备equipcard)。

---

## 字段

### 基础字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `equipment_name` | String | `""` | 装备名（来自 EquipmentCard.card_name） |
| `card_name` | String | `""` | 卡牌名。与 `equipment_name` 同值，兼容下游按 `card_name` 查询 |
| `english_name` | String | `""` | 英文名 |
| `card_type` | String | `"equipment"` | 卡牌类型，固定为 `"equipment"` |
| `card_subtype` | String | `""` | 卡牌子类型（`"equipment"` / `"action"`） |
| `source` | String | `""` | 卡牌来源：`"scavenge"` / `"game"` |
| `size` | int | `0` | 占用装备栏格数 |
| `range` | String | `"none"` | 射程：`"none"` / `"short"` / `"medium"` / `"long"` / `"infinity"` |
| `weapon` | bool | `false` | 是否为武器牌（会造成伤害的装备） |
| `charge_type` | String | `""` | 填充物类型（`"ammo"` / `"fuel"` / `"hollow_point"` 等） |
| `charge_max` | int | `0` | 填充物上限 |
| `in_equipment_area` | bool | `false` | 装备区标记。实体在装备区时为 true |
| `equipped_player` | Player | `null` | 当前持有该装备的玩家。`instantiate` 时写入，卸下时清空 |
| `equipment_card` | EquipmentCard | `null` | 来源装备卡回引（弃置 / 回收时入弃牌堆用） |
| `skills` | List\<Skill\> | — | 装备技能（继承自 Entity；装备技能挂载到 Player 身上） |

### `charge_current` 字段（委托来源卡）

`charge_current` 是当前填充物数量。**通过 getter / setter 委托给 `equipment_card.charge_current`**：

- 读取：`equipment_card != null` 时返回 `equipment_card.charge_current`，否则返回 0
- 写入：`equipment_card != null` 时设置 `equipment_card.charge_current = value`

> **设计原因**：填充物接口全部委托给来源 EquipmentCard，以保留弃置 → 回收 → 重装时填充物不重置的行为。来源 EquipmentCard 是同一实例，跨多次装备/弃置仍保持其 `charge_current` 状态。

---

## 方法

### 类型判断

| 方法 | 说明 |
|------|------|
| `is_equipment() -> bool` | 是否为装备实体（恒返回 true）。供 filter_target 中 `target.is_equipment()` 调用区分装备目标 |
| 继承自 Entity | `trigger` / `trigger_only` / `get_all_skills` / `add_skill` / `remove_skill` 等，详见 [Core/Entity.md](../Core/Entity.md) |

### 填充物接口（全部委托给 equipment_card）

> 所有方法在 `equipment_card == null` 时返回默认值（int 返回 0，bool 返回 false，void 不操作）。

| 方法 | 说明 |
|------|------|
| `get_charge() -> int` | 返回当前填充物数量 |
| `has_charge() -> bool` | 是否有至少 1 个填充物 |
| `consume_charge(n) -> bool` | 消耗 n 个填充物。成功返回 true，不足返回 false |
| `add_charge(amount, type)` | 添加指定类型的填充物（不超过上限） |
| `fill_charge()` | 将填充物填满到上限 |
| `refill(n)` | 补充填充物（不超过上限） |
| `change_charge_type(type)` | 修改填充物类型 |
| `is_weapon_card() -> bool` | 是否为武器牌。优先委托来源卡 `EquipmentCard.is_weapon_card()`，否则返回实体自身 `weapon` |

> 玩家侧的填充物流程入口在 [Player.消耗填充物](Player.md#消耗填充物consumeequipment-num)，统一接收 Equipment 实体或 EquipmentCard，内部解析来源卡后传给 EventBus / 钩子。

---

## 生命周期

| 阶段 | 触发 | 字段变化 |
|------|------|---------|
| 实体化 | `EquipmentCard.instantiate(player)` | 复制卡面数据；`in_equipment_area = true`；`equipment_card = card`；`equipped_player = player` |
| 装备入区 | [Player.equip](Player.md#装备equipcard) | 加入 `equipment_zone`；技能挂载到 Player |
| 装备离开 | [Player.unequip](Player.md#卸下card) | `in_equipment_area = false`；`equipped_player = null`；技能从 Player 移除 |
| 弃置 | [Player.discard](Player.md#discardtarget-position-quantity-type-silent) | 走内部 `_unequip`（不触发离开装备区 trigger）；来源 `equipment_card` 按其 `source` 进入对应弃牌堆 |
| 玩家死亡回收 | [Player.death](Player.md#deathsource) | 拾荒类来源卡按 `color` 洗回对应拾荒牌堆 |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。复用 trigger / damage / death 抽象方法 |
| [EquipmentCard](Card.md#equipmentcard-装备牌) | 来源卡。`equipment_card` 回引；填充物接口委托给来源卡 |
| [Player](Player.md) | 玩家 `equipment_zone` 持有 Equipment 实体；装备技能挂载到 Player |
| [Skill](../Common/Skill.md) | 装备技能遵循 Skill 结构，从实体挂载到 Player |
| [Game](../Game/Game.md) | 弃置时按来源卡 `source` 进入 Game 管理的弃牌堆 |
