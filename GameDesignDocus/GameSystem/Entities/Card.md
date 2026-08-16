# Card 卡牌类

> 继承：[Entity](../Core/Entity.md)
> 职责：卡牌的通用属性与子类定义。卡牌自带技能（装备技能、行动牌效果、怪物卡技能）。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 类继承关系

```
Card（卡牌基类，继承 Entity）
├── SurvivorGameCard（求生者游戏牌）
│   └── EquipmentCard（装备牌，含填充物）
│       └── ScavengeCard（拾荒卡，复用 EquipmentCard 的填充物接口与字段）
└── MonsterCard（怪物卡，实体化前）
```

> **继承链修正**：ScavengeCard 直接继承 EquipmentCard（而非 Card），完整链路为 `ScavengeCard → EquipmentCard → SurvivorGameCard → Card → Entity`。设计原因见 [ScavengeCard 章节](#scavengecard-拾荒卡)。

---

## Card 基类

> 代码：`src/entities/card.gd`，`class_name Card`。

### 字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `card_name` | String | `""` | 卡牌名称（中文） |
| `english_name` | String | `""` | 卡牌英文名。用于 content 代码字符串中按名查找装备/卡牌（如燃料例外的 `"fuel"` 校验） |
| `card_type` | String | `""` | 卡牌类型（如"行动"、"装备"、"食物"等） |
| `source` | String | `""` | 卡牌来源：`"scavenge"`（拾荒牌堆）/ `"game"`（游戏牌堆）/ `"monster"`（怪物牌堆） |
| `skills` | List\<Skill\> | — | 卡牌自带技能（继承自 Entity） |

### 方法

| 方法 | 说明 |
|------|------|
| 继承自 Entity | `trigger` / `trigger_only` / `get_all_skills` / `add_skill` / `remove_skill` 等，详见 [Core/Entity.md](../Core/Entity.md) |

---

## SurvivorGameCard 求生者游戏牌

> 代码：`src/entities/survivor_game_card.gd`，`class_name SurvivorGameCard extends Card`。
> 玩家游戏牌堆中的牌。分为**行动牌**与**装备牌**两种。

### 字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `card_subtype` | String | `""` | 卡牌子类型：`"action"`（行动牌）/ `"equipment"`（装备牌） |
| `size` | int | `0` | 占用装备栏的格数（仅装备牌） |
| `range` | String | `"none"` | 射程：`"none"` / `"short"` / `"medium"` / `"long"` / `"infinity"`，详见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md) |

### 行动牌

> 即时使用的卡牌。使用后弃掉。
> 装填武器、吃食物和治疗玩家都需要花费行动。

### 装备牌

> 装备到装备区的卡牌。占用装备栏格数（由 `size` 决定）。

---

## EquipmentCard 装备牌

> 代码：`src/entities/equipment_card.gd`，`class_name EquipmentCard extends SurvivorGameCard`。
> 装备到装备区的卡牌。装备牌进入装备区时其技能挂载到 Player 身上；离开装备区时移除。

### 字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `charge_type` | String | `""` | 填充物类型：`"ammo"`（弹药）/ `"fuel"`（燃料）/ `"hollow_point"`（空尖弹）等 |
| `charge_max` | int | `0` | 填充物上限。补满填充物时不超过此值 |
| `charge_current` | int | `0` | 当前填充物数量。耗尽时触发 `on_charge_depleted` trigger（见 [Player.消耗填充物](Player.md#消耗填充物consumechargearmmentum-num)） |
| `in_equipment_area` | bool | `false` | 装备区标记。来源卡实体化为 Equipment 实体后置 true；卸下时置 false |

### 方法

| 方法 | 说明 |
|------|------|
| `consume_charge(n) -> bool` | 消耗 n 个填充物。成功返回 true，不足返回 false |
| `has_charge() -> bool` | 是否有至少 1 个填充物 |
| `get_charge() -> int` | 返回当前填充物数量 |
| `refill(n)` | 补充填充物（不超过上限） |
| `add_charge(amount, type)` | 添加指定类型的填充物。`type` 匹配 `charge_type`（或 `charge_type` 为空时接受任意类型）时增加 `amount` 但不超过上限；不匹配则不操作 |
| `fill_charge()` | 将填充物填满到上限 |
| `change_charge_type(type)` | 修改填充物类型 |
| `is_weapon_card() -> bool` | 是否为武器牌（`range != "none"` 且 `card_subtype == "equipment"`）。用于 damage 流程的 card 参数判断 |
| `instantiate(player=null) -> Equipment` | 实体化：复制卡面数据到 Equipment 实例，由 [Player.equip](Player.md#equipcard) 调用。详见 [Equipment.md](Equipment.md) |

### 装备技能挂载

装备牌进入装备区时，由 `instantiate` 创建 Equipment 实体加入 `equipment_zone`，技能从实体挂载到 Player 身上（见 [Player.装备](Player.md#装备equipcard)）；离开装备区时移除（见 [Player.卸下](Player.md#卸下card)）。

---

## ScavengeCard 拾荒卡

> 代码：`src/entities/scavenge_card.gd`，`class_name ScavengeCard extends EquipmentCard`。
> 从拾荒牌堆获取的牌。使用后进入拾荒弃牌堆（非游戏牌弃牌堆）。

### 字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `color` | String | `""` | 颜色：`"red"` / `"green"` / `"blue"` / `"gray"`。红色最危险（含伏击！），蓝色最安全；`"gray"` 用于「一无所获」等特殊牌 |
| `scavenge_type` | String | `""` | 拾荒卡子类型：`"equipment"`（装备）/ `"consumable"`（消耗品）/ `"ambush"`（伏击） |

### 方法

| 方法 | 说明 |
|------|------|
| `get_color() -> String` | 返回拾荒卡颜色 |

### 继承 EquipmentCard 的设计原因

ScavengeCard 直接继承 EquipmentCard，是为了让拾荒包中的装备类卡（手枪、防弹背心、背包等）共享 `charge_type` / `charge_max` / `charge_current` / `in_equipment_area` 字段及 `consume_charge` / `refill` / `fill_charge` / `add_charge` 等方法，并通过 `card is EquipmentCard` 类型守卫统一处理。非装备类拾荒卡的 charge 字段保持默认值 0 / 空，不参与填充物流程。

### 特殊牌

| 名字 | 颜色 | 说明 |
|------|------|------|
| 伏击！ | red | 抓取时触发怪物进入怪物区流程（在 `on_draw_scavenge_card` trigger 中处理） |
| 一无所获 | gray | 抓取时立即弃掉 |
| 燃料 | red | 抓取时可选装备或弃掉 |
| 手电筒 | blue | 在 `before_draw_scavenge_card` 阶段取消并替代为「看2留1放1」 |

---

## MonsterCard 怪物卡

> 代码：`src/entities/monster_card.gd`，`class_name MonsterCard extends Card`。
> 怪物牌堆中的卡。进入玩家怪物区时**实体化**为 [Monster](Monster.md) 实例（见 [Player.draw_monster](Player.md#draw_monstern) 节点 2d）。

### 字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `monster_type` | String | `""` | 怪物类型：`"alien"`（外星人）/ `"mutant"`（突变体）/ `"zombie"`（僵尸）/ `"robot"`（机器人） |
| `monster_level` | String | `"normal"` | 怪物级别：`"boss"`（首领）/ `"elite"`（精英）/ `"normal"`（普通） |
| `max_hp` | int | `0` | 怪物生命值上限 |
| `damage_value` | int | `0` | 怪物攻击伤害 |
| `range` | String | `"none"` | 射程：`"none"` / `"short"` / `"medium"` / `"long"` / `"infinity"` |
| `is_boss` | bool | `false` | 是否首领卡。任务特殊设置中洗入怪物牌堆 |
| `skills` | List\<Skill\> | — | 怪物技能 |

### 首领卡

> 特殊怪物卡。任务特殊设置中洗入怪物牌堆。`is_boss = true`，`monster_level == "boss"`。

### 实体化方法

`instantiate(player=null) -> Monster`：复制卡面数据到 Monster 实例。由 [Player.draw_monster](Player.md#draw_monstern) 节点 2d 调用。

实体化时执行以下赋值：

- `monster.monster_name = card_name`（怪物名回引卡牌名）
- `monster.monster_type = monster_type`
- `monster.monster_level = monster_level`
- `monster.max_hp = max_hp`
- `monster.hp = max_hp`（初始化当前生命值为上限）
- `monster.damage_value = damage_value`
- `monster.range = range`
- `monster.attack_target = player`（设置纠缠对象为抓取玩家）
- `monster.monster_card = self`（回引来源怪物卡，死亡后入怪物弃牌堆用）
- 复制卡牌 `skills` 到 Monster 实例

---

## 卡牌使用流程

> 使用卡牌的规则见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md)。
> 流程方法见 [Player.use_card](Player.md#use_cardcard)。
>
> 从手牌中使用一张卡牌需要花费一个行动。use_card 对装备牌和行动牌统一消耗 1 点行动次数：
> - **装备牌** → 调用 `Player.equip(card)` 实体化并加入装备区
> - **行动牌** → 技能系统独立执行 content 后弃掉（按 `card.source` 分派弃牌堆：scavenge → 拾荒弃牌堆，game → 游戏牌弃牌堆）
>
> trigger 节点：使用卡牌前/时/后（见 [EventSystem.md](../Core/EventSystem.md)）。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。卡牌技能通过 Entity.trigger 触发 |
| [Equipment](Equipment.md) | EquipmentCard 实体化为 Equipment 实体进入玩家装备区 |
| [Player](Player.md) | 玩家手牌区/装备区/牌堆持有卡牌；装备牌技能挂载到 Player |
| [Monster](Monster.md) | MonsterCard 实体化为 Monster |
| [Game](../Game/Game.md) | Game 管理各类牌堆 |
| [Pile](../Common/Pile.md) | 卡牌存储在 Pile 实例中 |
| [Skill](../Common/Skill.md) | 卡牌自带技能遵循 Skill 结构 |
