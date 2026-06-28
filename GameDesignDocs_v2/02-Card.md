# 02 - Card 系统

> MA 的卡牌大类抽象：所有"卡牌"形态的对象（拾荒卡 / 求生者卡 / 怪物卡 / 任务卡 / 角色卡 / 任务物品卡）统一用 Card 类表达。
> 数据 = Resource / 状态 = RefCounted（不可变 `CardData` + 可变 `CardInstance` 分离）。
> 本文档只定义基类与方法签名，不含具体卡牌实现。
> 应用 v1 决策：D5（燃料三选一）、D7（remove/discard）、D8（死亡后卡牌按来源处理）、D9（装备卡抓取先进手牌）、D22（装备栏 size）、D24（Skill 统一技能）、D80（行动中生成并装备的卡牌 source = SURVIVOR_DECK）、D88（"摧毁装备牌" = remove()）。

---

## 1. 设计原则

- **数据 + 状态分离**：`CardData`（Resource，不可变）存定义性字段（card_id / display_name / skills / max_ammo 等）；`CardInstance`（RefCounted，可变状态）存运行时状态（current_ammo / location / owner_player 等）。同一份 `CardData` 可被多个 `CardInstance` 共享（任务卡配置多份同一卡的定义即此机制）。
- **PlayableCard 中间层**：`CardData → PlayableCardData → (ActionCard/EquipmentCard/FuelCard/MonsterCard/ItemCard)`；`CardData → (MissionCard/CharacterCard)`。所有"可被玩家持有或上场"的卡都继承 `PlayableCardData`。
- **类型分层 + source 字段标记来源**：继承层级按"卡牌类型"划分（行动卡 / 装备卡 / 怪物卡 / 物品卡等），卡牌"来自哪个牌库"用 `source: CardSource` 字段表达（D8）。装备卡既可能来自求生者牌库（防火头盔）也可能来自拾荒牌堆（手枪），统一归 `EquipmentCardData`，靠 `source` 区分。
- **Skill 关联**：卡牌的"装备技能 / 天赋 / 怪物天赋"统一存 `skill_ids: Array[StringName]`，运行时由 `SkillRegistry` 查表返回 `Skill` 实例（沿用 01-Skill.md 的数据+逻辑分离）。
- **生命周期统一**：所有 Card 都遵循 `remove()` / `discard()` 统一接口（D7）。装备卡在装备区的进出通过 `equip()` / `unequip()` 触发 ON_EQUIP / ON_UNEQUIP 时机（与 01-Skill.md 6.1 节持续型被动对接）。

---

## 2. CardType 枚举

`CardType` 标识卡牌大类，决定 `CardData` 的继承层级：

```text
enum CardType {
    ACTION,      # 行动卡（食物/弹药/炸药/医疗用品/急救包/灭火器等，打出即结算）
    EQUIPMENT,   # 装备卡（进装备区，含武器/防具/载具/工具四子类）
    FUEL,        # 燃料卡（特殊装备卡，抓取时三选一，D5）
    MONSTER,     # 怪物卡
    ITEM,        # 任务物品卡（脏毯子/老报纸/日记本，不进装备区只在手牌里）
    MISSION,     # 任务卡
    CHARACTER,   # 角色卡（求生者本人）
}
```

> CardType 与 CardSource 是两个独立维度：CardType 决定卡牌类型与继承层级；CardSource 决定卡牌来自哪个牌库。

---

## 3. CardData 抽象基类

```text
class_name CardData extends Resource

# === 公共字段（所有卡牌都有） ===
@export var card_id: StringName            # 唯一标识（跨对象引用 key）
@export var display_name: String           # UI 显示名
@export var description: String            # UI 描述（自然语言）
@export var card_type: CardType            # 卡牌大类（决定继承层级，子类 _init 时强制设置）
@export var skill_ids: Array[StringName] = []  # 关联技能 ID 列表（运行时由 SkillRegistry 查表）
@export var source: CardSource             # 卡牌来源（D8，决定死亡后处理方式）

# CardData 是抽象基类，不直接实例化；子类必须 _init 设置 card_type。
# 各子类按需添加专属字段（见第 7-12 节）。
```

---

## 4. CardInstance（单一可变状态类）

```text
class_name CardInstance extends RefCounted

var data: CardData                         # 引用不可变数据（多份实例可共享同一 data）
var location: CardLocation = DECK          # 当前位置
var owner_player: Survivor = null          # 持有者（手牌 / 装备区时非空）

# === 通用可变状态（按 card_type / data 字段按需使用） ===
var current_ammo: int = 0                  # 当前弹药/燃料（武器 + 燃料载具 + 燃料卡用，对应 data.max_ammo）
var current_durability: int = 0            # 当前耐久（防弹背心等"使用 N 次后 remove"用，0 表示无耐久机制）

# 注：怪物卡的 current_hp / 击晕状态 / 纠缠目标等运行时状态不放 CardInstance，
# 而是放在怪物上场后产生的 Monster Node（Entity 层）上。
# CardInstance 只代表"卡在哪里"，所有卡牌共用同一结构（见第 15 节 Q8 决策）。

# === 生命周期方法（D7） ===

# 移出本局游戏：location = REMOVED，触发 ON_REMOVE
# 若在装备区，先触发 ON_UNEQUIP 再触发 ON_REMOVE（保证持续型被动对称回退）
func remove() -> void:
    pass

# 置入弃牌堆：location = DISCARD_PILE，触发 ON_DISCARD
# pile 由调用方指定：ScavengerDiscardPile / MonsterDiscardPile / Survivor.discard_pile（Array[CardInstance]）
# 不抽象 DiscardPile 基类（D48），参数类型用 Variant
func discard(pile: Variant) -> void:
    pass

# === 装备生命周期（仅 EquipmentCard 用） ===

# 进入装备区：location = EQUIPMENT，触发 ON_EQUIP
# 装备栏已满时返回 false（调用方需先 discard 一个已有装备）
func equip(player: Survivor) -> bool:
    return false

# 离开装备区：触发 ON_UNEQUIP（不改变 location，由调用方后续 remove/discard 决定去向）
func unequip() -> void:
    pass
```

> 设计取舍：单一 `CardInstance` 类放所有可能的可变状态字段（按需使用），避免类层级冗余。`current_ammo` 在非武器/载具卡上恒为 0、`current_hp` 仅怪物卡用、`current_durability` 仅"耐久型装备"用。这是 ponytail 取舍（最少类）。

---

## 5. CardLocation 枚举

```text
enum CardLocation {
    DECK,           # 在牌堆中（求生者牌库 / 拾荒牌堆 / 怪物牌库）
    HAND,           # 在玩家手牌
    EQUIPMENT,      # 在装备区
    DISCARD_PILE,   # 在弃牌堆
    REMOVED,        # 移出游戏
    ON_MAP,         # 在地块上（掉落卡 / 任务物品 / 伏击等）
    IN_PLAY,        # 在场上（怪物卡纠缠玩家时）
}
```

---

## 6. CardSource 枚举（D8）

```text
enum CardSource {
    SURVIVOR_DECK,   # 求生者牌库（角色个人牌库）
    SCAVENGER_DECK,  # 拾荒牌堆（4 色大类混合的三色堆）
    MONSTER_DECK,    # 怪物牌库
    MISSION,         # 任务系统直接发出（任务物品 / 科学家等）
}
```

死亡后卡牌处理按 `source` 分别进行（D8）：
- `SURVIVOR_DECK`：随玩家死亡 `remove()` 移出游戏
- `SCAVENGER_DECK`：留在死亡地块，可被同地块玩家花 1 行动捡起
- `MONSTER_DECK`：进怪物弃牌堆（可重洗，D10）
- `MISSION`：按任务系统规则处理

---

## 7. PlayableCardData 中间层

```text
class_name PlayableCardData extends CardData

# 所有"可被玩家持有或上场"的卡的中间层
# 公共字段：行动卡 / 装备卡 / 怪物卡 / 物品卡 都继承此类

# 装备栏占用（仅 EQUIPMENT 用；ACTION/FUEL/ITEM/MONSTER 默认 0）
@export var size: int = 0

# 射程（装备卡 / 部分行动卡用；NONE 表示无射程）
@export var range: Range = Range.NONE
```

> `Range` 枚举（NONE / SHORT / MEDIUM / LONG）沿用 01-Skill.md / v1 决策。

---

## 8. 装备卡层级（4 个 GDScript 子类）

### 8.1 EquipmentCardData 基类

```text
class_name EquipmentCardData extends PlayableCardData
# card_type = CardType.EQUIPMENT

# 弹药/燃料统一字段（武器 + 燃料载具共用，按 ammo_type 区分）
@export var max_ammo: int = 0              # 弹药/燃料容量（0 = 无弹药机制，如弓/斧子/防具/工具/无燃料载具）
@export var ammo_type: AmmoType = AmmoType.NONE   # 弹药类型

# current_ammo 在 CardInstance 中（运行时填装/消耗）
```

### 8.2 四个子类

```text
class_name WeaponCardData extends EquipmentCardData
# 武器：可主动攻击，有弹药/射程/伤害（伤害值在 skill 中实现，靠 ACTIVE 技能触发）
# 弹药机制：max_ammo > 0 时 ammo_type 必须为 NORMAL 或 FUEL
#   - NORMAL：手枪/左轮/猎枪/弩（蓝色"弹药"卡填装）
#   - FUEL：打火机/火焰箭（"燃料"卡填装）
# 无弹药武器：弓/砍刀/斧子（max_ammo=0, ammo_type=NONE，靠 ACTIVE 技能直接造成伤害）

class_name ArmorCardData extends EquipmentCardData
# 防具：被动减伤/属性修改为主，无专属字段（仅语义区分）
# 典型实现：forced=true 的 TRIGGER 技能（焊接头盔"受伤-1"、防弹背心"受伤-2"）
# 耐久机制（如防弹背心"使用 3 次后 remove"）通过 CardInstance.current_durability + 技能内自减实现

class_name VehicleCardData extends EquipmentCardData
# 载具：移动相关，燃料机制复用 max_ammo/current_ammo + ammo_type=FUEL
# 有燃料载具（hunter 摩托车）：max_ammo=2, ammo_type=FUEL
# 无燃料载具（cowboy/surgeon 的马）：max_ammo=0, ammo_type=NONE（移动效果靠 ACTIVE 技能实现）

class_name ToolCardData extends EquipmentCardData
# 工具/其他：无专属字段，作为"其他"装备类
# 含工具（背包/对讲机/手电筒/梯子/捕熊陷阱/双筒望远镜/伪装）+ 道具（科学家等特殊装备）
# 实现差异靠 skill_ids 关联不同 Skill 子类
```

---

## 9. AmmoType 枚举

```text
enum AmmoType {
    NONE,    # 无弹药（弓/砍刀/斧子/防具/工具/无燃料载具）
    NORMAL,  # 普通弹药（手枪/左轮/猎枪/弩，蓝色"弹药"卡填装）
    FUEL,    # 燃料（打火机/火焰箭/摩托车，"燃料"卡填装）
}
```

> 载具的"燃料"与武器的"弹药"在数据层统一为同一对字段（`max_ammo` / `current_ammo` + `ammo_type`），按 `ammo_type` 区分填充物。这是最 ponytail 的方案，避免了 `max_fuel` / `max_ammo` 的字段重复。

---

## 10. 燃料卡特殊处理（D5）

```text
class_name FuelCardData extends PlayableCardData
# card_type = CardType.FUEL
# size: 占用装备栏格数（如 1 格）

# 燃料卡是特殊拾荒卡，抓取时不进手牌，立即三选一：
#   1. 装备 → 进装备区（占用 size 格装备栏，作为"燃料储备"，后续可被填装到 ammo_type=FUEL 的武器/载具）
#   2. 使用 → 立即给一张"ammo_type=FUEL 的武器/载具卡"填装满燃料（一次性消耗），然后 discard()
#   3. 弃掉 → 直接 discard()
# 三选一不消耗行动点（抓取时立即执行）
```

> 燃料卡不继承 `EquipmentCardData`（虽然 size 字段相同），因为它本身不是装备，而是"燃料储备容器"或"一次性填装物"。单设 `FuelCardData` 与 `EquipmentCardData` 平级。

---

## 11. ActionCardData / ItemCardData / MonsterCardData

```text
class_name ActionCardData extends PlayableCardData
# card_type = CardType.ACTION
# 行动卡：打出消耗 1 行动，结算后 discard()
# 含食物/弹药/炸药/医疗用品/解毒剂（拾荒牌堆来源）+ 急救包/灭火器/能量饮料/闪光棒等（求生者牌库来源）
# 效果通过 skill_ids 关联 ACTIVE 类 Skill 实现（沿用 01-Skill.md）

class_name ItemCardData extends PlayableCardData
# card_type = CardType.ITEM
# 任务物品卡：不进装备区，只在手牌里携带用于任务结算
# 例：脏毯子/老报纸/日记本
# 与 EquipmentCardData 平级（都继承 PlayableCardData），不共享 size/max_ammo 等装备字段
# 通常无 skill_ids（任务物品卡无装备技能）

class_name MonsterCardData extends PlayableCardData
# card_type = CardType.MONSTER
# 怪物卡：被玩家抓取时进 IN_PLAY 状态（纠缠玩家或成为首领上场）
# 详细字段（怪物级别/血量/攻击/射程/天赋）见 05-MonsterCard.md
```

---

## 12. MissionCardData / CharacterCardData

```text
class_name MissionCardData extends CardData
# card_type = CardType.MISSION
# 任务卡：不进任何牌堆，由 GameSession 持有
# 详细字段（任务名/难度/燃料/介绍/目标/初始设置/怪物包/地图块配置/拾荒牌堆配置/地图要求）见 06-MissionCard.md

class_name CharacterCardData extends CardData
# card_type = CardType.CHARACTER
# 角色卡：求生者本人，不进任何牌堆
# 详细字段（生命值上限/潜行值/天赋）见 07-CharacterCard.md
```

> `MissionCardData` 和 `CharacterCardData` 直接继承 `CardData`（不经过 `PlayableCardData`），因为它们不进任何牌堆、不被玩家持有。

---

## 13. CardData 继承层级总览

```text
CardData (Resource, 抽象)
├── PlayableCardData (中间层，可被玩家持有或上场)
│   ├── ActionCardData          # 行动卡
│   ├── EquipmentCardData       # 装备卡基类
│   │   ├── WeaponCardData      # 武器
│   │   ├── ArmorCardData       # 防具
│   │   ├── VehicleCardData     # 载具
│   │   └── ToolCardData        # 工具/其他
│   ├── FuelCardData            # 燃料卡（D5 特殊）
│   ├── MonsterCardData         # 怪物卡
│   └── ItemCardData            # 任务物品卡
├── MissionCardData             # 任务卡
└── CharacterCardData           # 角色卡
```

---

## 14. 卡牌生命周期时序

```text
抓取（draw）
    ↓
进手牌（HAND）  ← 装备卡 / 行动卡 / 物品卡 / 怪物卡（怪物卡特例直接进 IN_PLAY）
    │
    ├── 装备卡：玩家消耗 1 行动"使用"(D9)
    │       ↓
    │   检查装备栏容量（含 size 字段，D22）
    │       ↓ 未满                              ↓ 已满
    │   equip(player) → EQUIPMENT               需先 discard 一个已有装备
    │       ↓
    │   触发 ON_EQUIP（SkillExecutor.dispatch）
    │       ↓
    │   持续型被动（背包"+1 装备栏"）在此刻生效
    │
    ├── 行动卡：玩家消耗 1 行动打出
    │       ↓
    │   执行 ACTIVE 技能
    │       ↓
    │   discard(拾荒/角色弃牌堆)
    │
    ├── 物品卡：留在手牌直至任务结算交付
    │
    └── 装备卡卸下：unequip()
            ↓
        触发 ON_UNEQUIP（持续型被动对称回退）
            ↓
        由调用方决定后续：discard / remove / 重新 equip

discard(pile) → DISCARD_PILE，触发 ON_DISCARD
remove()      → 若在装备区先 ON_UNEQUIP，再 REMOVED，触发 ON_REMOVE
```

> 关键约束（与 01-Skill.md 6.1 节对接）：
> - **remove 隐含 ON_UNEQUIP**：装备被 `remove()` 移出游戏时必须先触发 ON_UNEQUIP，保证持续型被动（背包"+1 装备栏"）的对称回退
> - **discard 也隐含 ON_UNEQUIP**：装备被 `discard()` 时同理
> - **"摧毁装备牌" = remove()**（D88）：怪物效果中的"摧毁"直接移出本局游戏，不进弃牌堆

---

## 15. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | `CardInstance` 单一类的"按需字段"是否会让 type-check 失效 | 接受 ponytail 取舍：`current_ammo` 在非武器卡上恒为 0，运行时不会误用 |
| 2 | 防弹背心"使用 3 次后 remove"的耐久机制具体实现 | **待后续决定**（已确认采用 `current_durability` + 减伤技能 execute 内自减 + 归零 `remove()` 方向，细节待写技能时定） |
| 3 | 装备栏容量检查在 `equip()` 内还是调用方 | **已决**：`equip()` 内检查并返回 bool，调用方处理 false（弹窗让玩家选 discard 谁） |
| 4 | 燃料卡"装备"选项进装备区后是否算装备卡 | **已决**：算装备卡（location=EQUIPMENT），占用 size 格装备栏容量，与其他装备卡同等规则；card_type 仍为 FUEL |
| 5 | 掉落卡（玩家死亡留在地块上的拾荒来源卡）的 location | 用 `ON_MAP`，地块上挂载 `Array[CardInstance]` |
| 6 | 任务系统发出的物品卡（如科学家）的 source | `MISSION`，不进三色拾荒牌堆 |
| 7 | 同一 CardData 多份实例的 CardInstance 创建时机 | 游戏设置时按任务卡 `scavenger_decks` 配置批量实例化 |
| 8 | MonsterCardData 的 `current_hp` 放在哪 | **已决**：不放 CardInstance，移至 Monster Node（Entity 层）。怪物卡上场后产生 Monster Node 持有 current_hp / 击晕状态 / 纠缠目标等；CardInstance 只代表"卡在哪里"。符合 v1"实体=Node"决策 |
