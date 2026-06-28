# 04 - ScavengerCard（拾荒卡）

> 拾荒卡 = 拾荒牌堆中的卡（`ActionCardData` / `EquipmentCardData` 子类 / `FuelCardData` / `ItemCardData` + `source = SCAVENGER_DECK` + `scavenger_color = RED/BLUE/GREEN/GRAY`）。
> 不单设 `ScavengerCardData` 子类（02-Card.md 决策：按类型分层 + `source` 标记来源 + `scavenger_color` 标记大类颜色）。
> 应用 v1 决策：D5（燃料三选一）、D8（死亡后卡牌按来源处理）、D9（装备卡抓取先进手牌）、D12（拾荒牌库空无法拾荒）、D13（MVP 卡牌范围）。

---

## 1. 设计原则

- **不单设子类**：拾荒卡与求生者卡字段结构完全一致，唯一区别是来源。用 `source: CardSource.SCAVENGER_DECK` 标记 + `scavenger_color: ScavengerColor` 标记大类颜色（02-Card.md 已决策）。
- **大类颜色 vs 牌堆标识分离**：`scavenger_color`（卡牌大类颜色，RED/BLUE/GREEN/GRAY）只决定属性分类（来自原版 4 个 md 文件归属），**不决定**进入哪个牌堆；牌堆组成由任务卡 `scavenger_decks` 字段显式配置。
- **三色混合牌堆**：3 个拾荒牌堆（牌堆标识 RED/BLUE/GREEN），每个都是混合牌堆，可包含 4 色大类的卡牌。
- **拾荒弃牌堆全局共享**：1 个全局拾荒弃牌堆，所有色合并（用户决策）；牌堆空无法拾荒，弃牌堆不可重洗（D12）。
- **燃料卡特殊**：燃料卡单设 `FuelCardData` 子类（02-Card.md 第 10 节），抓取时立即三选一，不进手牌（D5）。
- **事件卡归入 ActionCardData**：不单设 `EventCardData` 子类。一无所获/伏击用 `ActionCardData + ON_CARD_DRAWN 时机 + forced=true TRIGGER 技能` 实现"抓到即结算"；多余配件用 `ActionCardData + ACTIVE_USE 主动技` 实现。

---

## 2. 拾荒卡的定义

拾荒卡就是 02-Card.md 中定义的 `ActionCardData` / `EquipmentCardData` 子类 / `FuelCardData` / `ItemCardData`，只是 `source = SCAVENGER_DECK` + `scavenger_color != NONE`：

```text
# 拾荒行动卡示例（医疗用品-便携）
{
    card_id: &"med_supply_small",
    card_type: CardType.ACTION,
    source: CardSource.SCAVENGER_DECK,        # ← 标记来源
    scavenger_color: ScavengerColor.RED,      # ← 标记大类颜色
    skill_ids: [&"heal_self_2"],
    # ... 其他字段同 ActionCardData
}

# 拾荒装备卡示例（手枪）
{
    card_id: &"pistol",
    card_type: CardType.EQUIPMENT,
    source: CardSource.SCAVENGER_DECK,
    scavenger_color: ScavengerColor.BLUE,
    size: 1,
    range: Range.MEDIUM,
    skill_ids: [&"pistol_attack_2"],
    # ... 其他字段同 WeaponCardData
}

# 拾荒事件卡示例（伏击）
{
    card_id: &"ambush",
    card_type: CardType.ACTION,
    source: CardSource.SCAVENGER_DECK,
    scavenger_color: ScavengerColor.GRAY,
    skill_ids: [&"ambush_draw_monster"],   # forced=true TRIGGER, ON_CARD_DRAWN
    # 注：无 ACTIVE 技能 → 进手牌后玩家无法主动打出（但 ON_CARD_DRAWN 触发后立即 discard_self）
}
```

> 类型判断用 `card.data.source == CardSource.SCAVENGER_DECK`，不依赖 `is` 检查。

---

## 3. ScavengerColor 字段（放在 PlayableCardData）

```text
class_name PlayableCardData extends CardData

# 已有字段（02-Card.md 第 7 节）：
@export var size: int = 0
@export var range: Range = Range.NONE

# 新增字段：
@export var scavenger_color: ScavengerColor = ScavengerColor.NONE   # 卡牌大类颜色（仅拾荒卡设置非 NONE）
```

```text
enum ScavengerColor {
    NONE,    # 非拾荒卡（求生者卡 / 怪物卡 / 任务卡 / 角色卡等）
    RED,     # 补给类（医疗用品、解毒剂、燃料）
    BLUE,    # 战备类（弹药、炸药、装备：防弹背心/对讲机/手枪/背包/手电筒/双筒望远镜）
    GREEN,   # 食物类（食物）
    GRAY,    # 其他类（一无所获、伏击、多余配件、脏毯子、老报纸、满是灰尘的日记本、科学家）
}
```

> `scavenger_color` 默认 `NONE`：求生者卡 / 怪物卡 / 任务卡 / 角色卡都不设置此字段。
> 仅拾荒卡设置为 RED/BLUE/GREEN/GRAY（按原版 4 个 md 文件归属）。

---

## 4. 拾荒牌堆结构（三色混合牌堆）

### 4.1 DeckColor 枚举（牌堆标识）

```text
enum DeckColor {
    RED,    # 红色拾荒牌堆标识
    BLUE,   # 蓝色拾荒牌堆标识
    GREEN,  # 绿色拾荒牌堆标识
}
```

> `DeckColor` 仅 3 值（无 GRAY）。灰色卡牌进入哪个牌堆由任务卡 `scavenger_decks` 配置决定，`DeckColor` 不需要 GRAY 值。

### 4.2 牌堆组成

3 个拾荒牌堆都是**混合牌堆**，可包含 4 色大类的卡牌。具体组成由任务卡 `scavenger_decks` 字段定义（详见 06-MissionCard.md）。

**任务 0 配置示例**（来自原版 `basic-mission_0.md`）：

| 牌堆标识 | 卡牌（大类颜色）× 数量 |
|---|---|
| RED（红色牌堆） | 食物(绿)×2、燃料(红)×4、医疗用品(红)×2、弹药(蓝)×1、双筒望远镜(蓝)×1、多余配件(灰)×1、一无所获(灰)×1 |
| GREEN（绿色牌堆） | 食物(绿)×6、燃料(红)×2、弹药(蓝)×1、手电筒(蓝)×1、多余配件(灰)×1、一无所获(灰)×1 |
| BLUE（蓝色牌堆） | 食物(绿)×2、燃料(红)×2、弹药(蓝)×3、双筒望远镜(蓝)×1、手枪(蓝)×1、对讲机(蓝)×1、多余配件(灰)×1、一无所获(灰)×1 |

> 示例中每个牌堆都包含红/蓝/绿/灰 4 色大类的卡牌。例如"红色牌堆"里有绿色食物卡、蓝色弹药卡、灰色事件卡。

### 4.3 牌堆与地块关联

地块通过 `scavenger_piles: Array[DeckColor]` 字段关联可拾荒的牌堆（详见 08-MapBlock.md，待编写）。

- 地块无拾荒标记 → 不能拾荒
- 地块有 1 个拾荒标记 → 可从该色牌堆抓 1 张
- 地块有 2-3 个拾荒标记 → 可从多色牌堆各抓 1 张（如游乐场[红、绿、蓝]）

---

## 5. 拾荒卡实例化流程

```text
MissionCardData.scavenger_decks: Dictionary[DeckColor, Array[Dictionary]]
  ↓（游戏开始时 GameSession 实例化）
对每个 DeckColor 的卡牌配置列表：
  ↓
CardRegistry.get_card_data(card_id) → CardData
  ↓（每份配置创建一个 CardInstance）
CardInstance {
    data = CardData,
    source = SCAVENGER_DECK,
    location = DECK
}
  ↓（洗混后存入）
ScavengerDeckStack.piles[DeckColor]: Array[CardInstance]
```

实例化流程：
1. `GameSession` 读取 `MissionCardData.scavenger_decks`
2. 对每个 `DeckColor` 的卡牌配置列表：
   - 每条配置包含 `card_id` + `count`
   - 对每个 count 调 `CardRegistry.get_card_data(card_id)` 获取 `CardData`
   - 创建 `CardInstance`，设置 `data` / `source = SCAVENGER_DECK` / `location = DECK`
3. 洗混后存入对应 `DeckColor` 的 `ScavengerDeckStack.piles[DeckColor]`

> 同一 `CardData` 可被多个任务配置为不同数量进入不同牌堆（如"食物"既可进红色牌堆也可进绿色牌堆）。
> `scavenger_color` 从 `CardData` 继承到 `CardInstance`，运行时无需重复设置。

---

## 6. 拾荒弃牌堆与牌库循环（D12）

### 6.1 拾荒弃牌堆（1 个全局）

```text
class_name ScavengerDiscardPile extends RefCounted

# 1 个全局拾荒弃牌堆（所有色合并，用户决策）
var cards: Array[CardInstance] = []

func add(card: CardInstance) -> void:
    card.location = CardLocation.DISCARD_PILE
    cards.append(card)

func get_count_by_color(color: ScavengerColor) -> int:
    # 仅用于 UI 显示按色统计，不分离牌堆
    return cards.filter(func(c): return c.data.scavenger_color == color).size()
```

> 选择 1 个全局弃牌堆的理由：
> - 卡牌打出/弃置时不需要按色分流（简化 `discard()` 调用）
> - 弃牌堆不可重洗（D12），全局共享无副作用
> - UI 可按色统计显示（如"红色卡 5 张、蓝色卡 3 张"）

### 6.2 牌库循环规则（D12）

```text
状态流转：
  ScavengerDeckStack.piles[DeckColor]（拾荒牌堆）
    ↓ 抓取
  CardInstance（进玩家手牌或触发事件卡效果）
    ↓ 打出/弃置
  ScavengerDiscardPile（全局拾荒弃牌堆）

规则：
  1. 拾荒行动时从对应 DeckColor 牌堆顶部抓
  2. 某 DeckColor 牌堆空 → 该色无法拾荒
     - UI 提示：地块拾荒标记变灰
  3. 拾荒弃牌堆不可重洗（D12）
     - 与求生者牌库（discard_pile 可重洗）和怪物牌库（怪物弃牌堆可重洗，D10）不同
```

> 与 03-SurvivorCard.md 第 4 节求生者牌库循环对比：
> - 求生者牌库：deck 空 → 玩家被淘汰；discard_pile 可重洗
> - 拾荒牌堆：deck 空 → 该色无法拾荒；弃牌堆不可重洗

---

## 7. 灰色卡的子分类

灰色卡分三类，共 7 种：

### 7.1 事件卡（3 种，抓到即结算 / 主动打出）

| card_id | card_name | 触发方式 | 实现方式 |
|---|---|---|---|
| `nothing` | 一无所获 | 抓到立即弃掉 | `ActionCardData` + `Skill(TRIGGER, ON_CARD_DRAWN, forced=true, discard_self=true)` |
| `ambush` | 伏击！ | 抓到立即抓怪物卡 + 弃掉 | `ActionCardData` + `Skill(TRIGGER, ON_CARD_DRAWN, forced=true, discard_self=true)` |
| `spare_parts` | 多余配件 | 玩家主动打出（消耗 1 行动） | `ActionCardData` + `Skill(ACTIVE, ACTIVE_USE, action_cost=1)` |

**事件卡实现细节**（沿用 01-Skill.md 的 forced 锁定技模式）：

```text
# 一无所获（forced=true TRIGGER，抓到即弃）
{
    card_id: &"nothing",
    card_type: CardType.ACTION,
    source: CardSource.SCAVENGER_DECK,
    scavenger_color: ScavengerColor.GRAY,
    skill_ids: [&"nothing_discard_self"],   # 唯一技能：ON_CARD_DRAWN 时 discard_self
    # 无 ACTIVE 技能 → 进手牌后玩家无法主动打出
}

# Skill 实现
class_name NothingDiscardSelfSkill extends TriggerSkill
func get_trigger_timings() -> Array[TriggerTiming]:
    return [TriggerTiming.ON_CARD_DRAWN]
func can_trigger(event, owner) -> bool:
    return true   # 抓到即触发，无条件
func execute(event, owner) -> void:
    owner.discard(ScavengerDiscardPile)   # 弃置自身进拾荒弃牌堆
# forced = true（在 Skill 基类字段中设置，01-Skill.md）

# 伏击（forced=true TRIGGER，抓到即抓怪物卡 + 弃）
# 类似实现，execute 内额外调用 MonsterDeck.draw_one_to(player) 抓怪物卡
```

> 事件卡的 `forced=true` 是关键：表示"锁定技"——抓到即触发，玩家不能选择不触发（对应三国杀"锁定技"）。
> 一无所获/伏击的 Skill 在 ON_CARD_DRAWN 时机触发后通过 `discard_self` 弃置自身，所以卡牌不会真正进手牌（即使进了也会立即被弃）。
> 多余配件不是锁定技，进手牌后玩家可选择时机主动打出。

### 7.2 任务物品卡（3 种，用于任务结算）

| card_id | card_name | 用途 |
|---|---|---|
| `dirty_blanket` | 脏毯子 | 任务 4/10 胜利条件交付物 |
| `old_newspaper` | 老报纸 | 任务 4 胜利条件交付物 |
| `dusty_journal` | 满是灰尘的日记本 | 任务 5/8 关键道具 |

```text
# 任务物品卡实现
{
    card_id: &"dirty_blanket",
    card_type: CardType.ITEM,
    source: CardSource.SCAVENGER_DECK,
    scavenger_color: ScavengerColor.GRAY,
    skill_ids: [],   # 任务物品卡无技能
    # 不进装备区，只在手牌里携带用于任务结算
}
```

> 任务物品卡继承 `ItemCardData`（02-Card.md 第 11 节），与 `EquipmentCardData` 平级，不共享 `size` / `max_ammo` 等装备字段。
> 通常无 `skill_ids`，纯靠任务系统检查玩家手牌中是否含指定 `card_id` 来结算。

### 7.3 任务专属装备卡（1 种）

| card_id | card_name | subtype | 技能效果 | skill_id |
|---|---|---|---|---|
| `scientist` | 科学家 | TOOL | 被动：装备后不可潜行穿过怪物标记；作为任务结算物品 | `scientist_no_stealth` |

```text
# 科学家（任务专属装备卡，由任务系统直接发出或拾荒牌堆配置）
{
    card_id: &"scientist",
    card_type: CardType.EQUIPMENT,
    source: CardSource.SCAVENGER_DECK,   # 或 CardSource.MISSION（由任务系统发出时）
    scavenger_color: ScavengerColor.GRAY,
    size: 1,
    range: Range.NONE,
    skill_ids: [&"scientist_no_stealth"],   # forced=true TRIGGER，ON_STEALTH_CHECK
}
```

> 科学家卡的 `source` 可能是 `SCAVENGER_DECK`（任务卡配置进入拾荒牌堆）或 `MISSION`（任务事件直接发给玩家），取决于任务设计。

---

## 8. 燃料卡特殊处理（D5，补充拾荒流程）

燃料卡是特殊拾荒卡，单设 `FuelCardData` 子类（02-Card.md 第 10 节已定义）。拾荒抓取时不进手牌，立即三选一：

```text
拾荒抓取燃料卡 → 立即弹窗三选一（不消耗行动）：
  1. 装备 → 进装备区（占用 size 格装备栏，作为"燃料储备"）
  2. 使用 → 立即给一张"ammo_type=FUEL 的武器/载具卡"填装满燃料（一次性消耗）→ discard()
  3. 弃掉 → 直接 discard() 进拾荒弃牌堆
```

> 详细字段与流程见 02-Card.md 第 10 节，此处仅补充拾荒流程中的处理。
> 燃料卡是红色大类卡（`scavenger_color = RED`），但可被任务卡配置进入任一三色拾荒牌堆。

---

## 9. 交易规则

作为一个**免费行动**，同地块玩家可给出/拿取/交易拾荒卡：

```text
规则：
  1. 免费：不消耗行动点
  2. 限制：仅拾荒卡（source == SCAVENGER_DECK）
     - 含拾荒装备卡（无论在手牌还是装备区）
     - 含拾荒行动卡（在手牌中）
     - 含任务物品卡（在手牌中）
     - 含燃料卡（在装备区中）
  3. 求生者卡（source == SURVIVOR_DECK）不可交易
  4. 同地块：交易双方必须在同一地图块上
  5. 装备区交易：装备中的拾荒卡交易时先 unequip() 再转移
```

> 交易是 PC 版单机模式下需要 AI 队友接口预留的核心场景之一（D1）。

---

## 10. MVP 拾荒卡范围（D13）

MVP 阶段仅实现**任务 0（教程）**配置的三色牌堆子集：

| 卡牌库 | MVP 范围 |
|---|---|
| 拾荒卡（4 色大类） | 任务 0 配置的三色牌堆子集（含红/蓝/绿/灰 4 色大类卡） |
| 求生者卡 | 1 名角色完整牌库（建议外科医生 31 张，见 03-SurvivorCard.md） |
| 怪物卡 | 僵尸包子集（任务 0 怪物包未指定，建议用僵尸） |

任务 0 的三色牌堆共包含以下卡牌定义（按 4.2 节示例）：
- 红色大类：燃料、医疗用品（便携）
- 蓝色大类：弹药（少量）、双筒望远镜、手电筒、手枪、对讲机
- 绿色大类：食物（微量）
- 灰色大类：一无所获、多余配件

> 验证核心循环（移动/拾荒/战斗/饥饿/燃料/胜利）后逐步扩展任务 1-12 的拾荒卡配置。

---

## 11. 拾荒卡清单（25 种）

按原版 4 个 md 文件归属：

### 11.1 红色大类（5 种，来自 red.md）

| card_id | card_name | card_type | 关键字段 | skill_id |
|---|---|---|---|---|
| `med_supply_small` | 医疗用品（便携） | ACTION | - | `heal_self_2` |
| `med_supply_medium` | 医疗用品（小型） | ACTION | - | `heal_self_4` |
| `med_supply_large` | 医疗用品（大型） | ACTION | - | `heal_self_6` |
| `antidote` | 解毒剂 | ACTION | - | `clear_all_status` |
| `fuel` | 燃料 | FUEL | size=1 | `fuel_pickup_choice`（D5 三选一） |

### 11.2 蓝色大类（13 种，来自 blue.md）

| card_id | card_name | card_type | subtype | size | range | skill_id |
|---|---|---|---|---|---|---|
| `ammo_2` | 弹药（少量） | ACTION | - | - | - | `reload_weapon_2` |
| `ammo_3` | 弹药（半盒） | ACTION | - | - | - | `reload_weapon_3` |
| `ammo_4` | 弹药（足量） | ACTION | - | - | - | `reload_weapon_4` |
| `ammo_5` | 弹药（大量） | ACTION | - | - | - | `reload_weapon_5` |
| `ammo_full` | 弹药（整盒） | ACTION | - | - | - | `reload_weapon_full` |
| `dynamite` | 炸药 | ACTION | - | - | LONG | `clear_tokens_damage_8` |
| `mega_dynamite` | 大炸药 | ACTION | - | - | SHORT | `destroy_map_block` |
| `bulletproof_vest` | 防弹背心 | EQUIPMENT | ARMOR | 1 | NONE | `vest_damage_reduce`（耐久 3 次） |
| `walkie_talkie` | 对讲机 | EQUIPMENT | TOOL | 1 | NONE | `walkie_extra_action` |
| `pistol` | 手枪 | EQUIPMENT | WEAPON | 1 | MEDIUM | `pistol_attack_2` |
| `backpack` | 背包 | EQUIPMENT | TOOL | 0 | NONE | `backpack_add_slot`（持续型被动） |
| `flashlight` | 手电筒 | EQUIPMENT | TOOL | 1 | NONE | `flashlight_scavenge_peek` |
| `binoculars` | 双筒望远镜 | EQUIPMENT | TOOL | 1 | LONG | `binoculars_reveal_silent` |

### 11.3 绿色大类（7 种，来自 green.md，全部为行动卡）

| card_id | card_name | 效果 | skill_id |
|---|---|---|---|
| `food_1` | 食物（微量） | 自身饥饿值 -1 | `reduce_hunger_self_1` |
| `food_2` | 食物（小额） | 自身饥饿值 -2 | `reduce_hunger_self_2` |
| `food_3` | 食物（标准） | 自身饥饿值 -3 | `reduce_hunger_self_3` |
| `food_4` | 食物（足量） | 自身饥饿值 -4 | `reduce_hunger_self_4` |
| `food_5` | 食物（大量） | 自身饥饿值 -5 | `reduce_hunger_self_5` |
| `food_box_small` | 食物（小箱） | 所有玩家饥饿值各 -1 | `reduce_hunger_all_1` |
| `food_box_large` | 食物（大箱） | 所有玩家饥饿值各 -2 | `reduce_hunger_all_2` |

### 11.4 灰色大类（7 种，来自 gray.md）

详见第 7 节灰色卡子分类（事件卡 3 种 + 任务物品卡 3 种 + 任务专属装备卡 1 种）。

---

## 12. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | 拾荒牌堆配置数据结构（`scavenger_decks` 字段类型） | 倾向 `Dictionary[DeckColor, Array[Dictionary]]`（每条 `Dictionary` 含 `card_id` + `count`），详见 06-MissionCard.md（待编写） |
| 2 | 手电筒"窥视牌堆顶 2 张"的拾荒流程时序 | **待后续决定**（倾向在拾荒行动触发前检查装备区是否有手电筒，有则弹窗展示顶 2 张供玩家选，保留 1 张另 1 张置牌堆底） |
| 3 | 防弹背心"使用 3 次后 remove"的耐久机制 | 沿用 02-Card.md Q2 待定（已确认采用 `current_durability` + 减伤技能 execute 内自减 + 归零 `remove()` 方向，细节待写技能时定） |
| 4 | 拾荒卡 `.tres` 文件组织 | 倾向按色分（`data/cards/scavenger/red/` / `blue/` / `green/` / `gray/`），便于按原版文件结构对照 |
| 5 | 同一卡牌定义被多任务复用 | CardRegistry 全局唯一，按 card_id 索引；不同任务的 `scavenger_decks` 可引用同一 card_id 并配置不同数量 |
| 6 | 燃料卡"装备"选项进装备区后的卡牌类型判断 | **已决**：`card_type == FUEL`（不变），与装备卡区分；装备栏容量检查同样适用（02-Card.md Q4） |
| 7 | 事件卡（一无所获/伏击）抓到后是否进手牌 | **已决**：进手牌后立即被 forced=true TRIGGER 弃置，UI 上可显示"抓到事件卡 → 立即结算 → 进弃牌堆"的过渡动画 |
| 8 | 多余配件"从你的弃牌堆将一张牌返回手牌"的弃牌堆范围 | **已决**：角色个人弃牌堆（仅求生者卡，用户决策）。多余配件打出后从 `Survivor.discard_pile` 取一张求生者卡回手牌；与机械师"神通广大"语义一致。拾荒卡打出后进全局拾荒弃牌堆，不受此效果影响 |

---

## 附：决策应用索引

本文档应用的决策：
- D5 燃料机制（抓取时三选一，02-Card.md 第 10 节）
- D8 死亡后卡牌按来源区分处理（拾荒来源卡留在死亡地块）
- D9 装备卡抓取先进手牌，使用花 1 行动（燃料卡例外）
- D12 拾荒牌库空无法拾荒（弃牌堆不可重洗）
- D13 MVP 最小可玩闭环（任务 0 配置子集）
- D22 装备栏大小字段 `size: int`
- D24 Skill 通用技能系统（事件卡用 forced=true TRIGGER 实现）
- 用户决策：事件卡归入 ActionCardData（不单设 EventCardData）
- 用户决策：ScavengerColor 字段放在 PlayableCardData（默认 NONE）
- 用户决策：拾荒弃牌堆 1 个全局（所有色合并）
