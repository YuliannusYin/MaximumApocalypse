# 08 - MissionCard（任务卡）

> 任务卡 = `MissionCardData`（Resource，任务定义）。任务卡不进任何牌堆（`source = MISSION`），由 `GameSession` 持有。
> 任务卡是单局游戏的核心配置：定义地图布局、拾荒牌堆、怪物包、首领卡机制、目标标记、胜利条件。
> 13 个任务的详细设计（任务名/难度/特殊规则/首领配置等）引用 v1 `GameDesignDocs_v1/08-任务系统设计.md`，本文档只定义基类与字段。
> 应用 v1 决策：D3（map_layout 内置布局）、D5（燃料机制）、D13（MVP 任务 0）、D16（怪物标记上限）、D18（部分任务无需燃料）、D19（首领卡机制）、D20（回合限制）、R4（任务 4 燃料交付物）。

---

## 1. 设计原则

- **数据 + 逻辑分离**：`MissionCardData`（Resource）存任务定义性字段（任务 ID / 难度 / 怪物包 / 地图布局 / 拾荒配置 / 首领配置 等）；任务特殊规则的运行时逻辑用 `Skill`（forced=true TRIGGER）实现，任务卡只存 `skill_ids` 引用（沿用 01-Skill.md）。
- **任务卡不进任何牌堆**：`source = CardSource.MISSION`（02-Card.md 第 6 节），由 `GameSession` 直接持有，不进拾荒/怪物/求生者牌库。
- **子结构用独立 Resource 子类**：`BossConfig` / `TargetMarkerConfig` 独立 Resource 子类，`@export` 暴露字段，便于 `.tres` 编辑器可视化编辑（用户决策）。
- **map_layout 二维数组编码**：`Array[Array[int]]`，值 0/1/2/3 表达空位/任意地块/面包车/必需地块占位（D3，引用 09-MapBlock.md 待编写）。
- **13 个任务详细设计引用 v1**：本文档只定义基类与字段，任务 0-12 的具体配置表引用 v1 第 3/4 节，避免重复（用户决策）。

---

## 2. MissionCardData（Resource，任务定义）

```text
class_name MissionCardData extends CardData
# card_type = CardType.MISSION（02-Card.md 第 12 节）
# source = CardSource.MISSION（02-Card.md 第 6 节，不进任何牌堆）

# === 任务身份 ===
@export var mission_id: StringName              # 任务唯一标识（如 &"mission_0"）
@export var mission_name: String                # UI 显示名（如 "教程"）
@export var difficulty: Difficulty              # 难度枚举（见第 3 节）

# === 怪物包 ===
@export var monster_pack: MonsterPack           # 本局使用的怪物包（引用 05-MonsterCard.md 第 4 节）

# === 任务叙事 ===
@export var intro: String                       # 任务介绍/背景（UI 用）
@export var objective: String                   # 胜利条件描述（UI 用）

# === 燃料（D18） ===
@export var fuel_required: int = 0              # 启动面包车所需燃料
                                                 #   0  = 不需燃料（D18，胜利条件为到达特定地点）
                                                 #   >0 = 需要的燃料数（如任务 0 用 4，任务 10 用 6）
                                                 # 注：任务 4 的 3 燃料是任务交付物（R4），fuel_required 仍为 0

# === 地图（D3） ===
@export var map_layout: Array[Array[int]] = []  # 二维数组定义地图形状（0/1/2/3，见第 4 节）
@export var required_blocks: Array[StringName] = []  # 必需地块类型列表（按顺序填充到占位值 3 的格子）
@export var starting_block: StringName = &""    # 起始地块类型（空 = 默认面包车；该地块 is_revealed=true）

# === 拾荒牌堆配置 ===
@export var scavenger_decks: Dictionary = {}    # Dictionary[DeckColor, Array[Dictionary]]
                                                 # 每条 Dictionary 含 card_id: StringName + count: int
                                                 # 引用 10-Deck.md 第 4 节 / 04-ScavengerCard.md 第 5 节

# === 首领卡配置（D19） ===
@export var boss_config: BossConfig             # 首领卡配置（见第 6 节）

# === 目标标记配置 ===
@export var target_markers: Array[TargetMarkerConfig] = []  # 最多 3 个（见第 7 节）

# === 怪物标记上限（D16） ===
@export var monster_token_limit: int = 30       # 全局怪物标记总数上限，达到则游戏失败

# === 任务特殊规则 ===
@export var special_rules: Array[String] = []   # 任务特殊规则描述（UI 提示用，自然语言）
@export var special_rule_skill_ids: Array[StringName] = []  # 任务特殊规则的 Skill 引用（forced=true TRIGGER，如任务 6 核辐射扩散）
```

> `MissionCardData` 不直接持有 `Skill` 实例或子结构实例的运行时状态，只存 ID 引用与配置数据。运行时由 `SkillRegistry` / `GameSession` 查表与解析。

---

## 3. Difficulty 枚举

```text
enum Difficulty {
    TUTORIAL,    # 特别简单（任务 0）
    VERY_EASY,   # 非常简单（任务 2）
    EASY,        # 简单（任务 1、3）
    NORMAL,      # 正常（任务 4、5、6）
    HARD,        # 困难（任务 7、8、10、11）
    VERY_HARD,   # 非常困难（任务 9、12）
}
```

> 难度仅用于 UI 显示与匹配推荐，不影响规则计算。难度覆盖（如调整 `monster_token_limit`）由玩家选择难度时由 `GameSession` 应用。

---

## 4. map_layout 字段说明（D3）

```text
map_layout: Array[Array[int]]
值含义：
  0 = 空位（不放置地块）
  1 = 任意地块（从剩余实例池随机抽取）
  2 = 面包车（取 van_1，is_revealed=true）
  3 = 必需地块占位（从 required_blocks 队首取类型，填充实例）

起始地块展示状态：
  填充算法中，若 required_blocks 中某类型的地块 == starting_block，
  则该地块 is_revealed=true（如任务 0 的购物中心）
```

### 4.1 任务 0 map_layout 示例

```text
原版网格（basic-mission_0.md）：
|购物中心|未知地块|未知地块|未知地块|未知地块|无地块|
|未知地块|未知地块|未知地块|无地块|未知地块|面包车|
|无地块|未知地块|未知地块|未知地块|未知地块|未知地块|

PC 版 map_layout：
[
  [3, 1, 1, 1, 1, 0],
  [1, 1, 1, 0, 1, 2],
  [0, 1, 1, 1, 1, 1]
]
required_blocks = [&"mall"]
starting_block = &"mall"   # 玩家从购物中心开始，购物中心 is_revealed=true
```

> 地块填充算法、地块类型枚举、`is_revealed` 字段见 09-MapBlock.md（待编写）。
> 任务 1-12 的 `map_layout` 具体值待数据录入阶段根据原版地块清单设计，需保证所有非空地块从起始地块可达（连通性）。

---

## 5. scavenger_decks 字段

```text
scavenger_decks: Dictionary[DeckColor, Array[Dictionary]]
# key   = DeckColor（RED/BLUE/GREEN，见 04-ScavengerCard.md 第 4.1 节）
# value = Array[Dictionary]，每条 Dictionary 含：
#   - card_id: StringName   卡牌 ID（引用 CardRegistry 注册的 CardData）
#   - count: int            该卡在此牌堆中的张数

# 示例（任务 0 红色牌堆，共 12 张）：
{
    DeckColor.RED: [
        {card_id: &"food_1", count: 2},           # 绿色大类卡
        {card_id: &"fuel", count: 4},             # 红色大类卡
        {card_id: &"med_supply_small", count: 2}, # 红色大类卡
        {card_id: &"ammo_2", count: 1},           # 蓝色大类卡
        {card_id: &"binoculars", count: 1},       # 蓝色大类卡
        {card_id: &"spare_parts", count: 1},      # 灰色大类卡
        {card_id: &"nothing", count: 1},          # 灰色大类卡
    ],
    DeckColor.GREEN: [...],   # 共 12 张
    DeckColor.BLUE: [...],    # 共 12 张
}
```

> 每个牌堆都是**混合牌堆**，可含 4 色大类卡牌（卡牌大类颜色 ≠ 牌堆标识，04-ScavengerCard.md 第 4 节）。
> 实例化流程见 10-Deck.md 第 4 节 `ScavengerDeckStack.init_from_mission()`。
> 各任务的拾荒牌堆组成规律见 v1 第 5.3 节。

---

## 6. BossConfig（首领卡配置，D19）

```text
class_name BossConfig extends Resource

@export var mechanic: BossMechanic = BossMechanic.NONE   # 首领卡机制类型（见 6.1）
@export var count: int = 1                                # 首领卡数量（默认 1，任务 9/12 用 2）
@export var setup_cards: int = 0                          # 洗入牌库底前抓取的牌数（如任务 2 用 9，任务 6 用 5）
@export var trigger_block: StringName = &""               # 触发地块（如 &"police_station"；空 = 无触发地块）
@export var trigger_marker_index: int = -1                # 触发的目标标记索引（-1 = 无，任务 10 用 1 表示标记 2）
```

### 6.1 BossMechanic 枚举

```text
enum BossMechanic {
    NONE,                   # 无首领（任务 0）
    TRIGGER_ON_BLOCK,       # 到达 trigger_block 首名玩家抓首领卡（任务 1/5/8）
    SHUFFLE_BOTTOM,         # setup_cards 张牌 + 首领卡洗混放牌库底（任务 2/3/4/6）
    TRIGGER_ON_REVEAL,      # 展示目标标记地块的玩家抓首领牌（任务 7）
    SHUFFLE_INTO_DECK,      # 首领卡洗入怪物牌库（任务 9）
    TRIGGER_ON_MARKER,      # trigger_marker_index 标记触发首领（任务 10）
    SHUFFLE_LOWER_HALF,     # 首领卡洗入怪物牌库下半部（任务 11）
    SHUFFLE_PLUS_BOTTOM,    # 随机洗入 + 牌库底额外 1 张（任务 12，count=2）
}
```

### 6.2 各任务首领卡配置

| 任务 | mechanic | count | setup_cards | trigger_block | trigger_marker_index |
|---|---|---|---|---|---|
| 0 | NONE | - | - | - | -1 |
| 1 | TRIGGER_ON_BLOCK | 1 | 0 | `&"police_station"` | -1 |
| 2 | SHUFFLE_BOTTOM | 1 | 9 | `&"police_station"` | -1 |
| 3 | SHUFFLE_BOTTOM | 1 | 9 | `&""` | -1 |
| 4 | SHUFFLE_BOTTOM | 1 | 9 | `&""` | -1 |
| 5 | TRIGGER_ON_BLOCK | 1 | 0 | `&""`（目标地块） | -1 |
| 6 | SHUFFLE_BOTTOM | 1 | 5 | `&""` | -1 |
| 7 | TRIGGER_ON_REVEAL | 1 | 0 | `&""` | 0 |
| 8 | TRIGGER_ON_BLOCK | 1 | 0 | `&""`（目标地块） | -1 |
| 9 | SHUFFLE_INTO_DECK | 2 | 0 | `&""` | -1 |
| 10 | TRIGGER_ON_MARKER | 1 | 0 | `&""` | 1 |
| 11 | SHUFFLE_LOWER_HALF | 1 | 0 | `&""` | -1 |
| 12 | SHUFFLE_PLUS_BOTTOM | 2 | 0 | `&""` | -1 |

> 任务 5/8 的 `trigger_block = &""` 表示"目标地块"（由 `target_markers[0]` 动态决定），由任务系统运行时解析。
> 首领卡洗入怪物牌库底的操作见 10-Deck.md Q10（`MonsterDeck.insert_at_bottom()`，待 06-MissionCard.md 同步设计——已在本节定义）。

---

## 7. TargetMarkerConfig（目标标记配置）

```text
class_name TargetMarkerConfig extends Resource

@export var constraint_type: MarkerConstraint = MarkerConstraint.NONE  # 位置约束类型（见 7.1）
@export var min_distance_from_van: int = 0     # 距面包车最小地块距离（任务 5 用 5）
@export var min_distance_from_base: int = 0    # 距基地最小地块距离（任务 8 用 5，任务 11 用 3）
@export var min_mutual_distance: int = 0       # 与其他标记彼此最小距离（任务 10 用 2，任务 11/12 用 3）
@export var initial_monster_tokens: int = 0    # 初始放置的怪物标记数（任务 9/11 用 3）
@export var on_first_arrival_skill: StringName = &""  # 首个到达者触发的 skill_id（任务 10 标记 1/2/3 各不同）
```

### 7.1 MarkerConstraint 枚举

```text
enum MarkerConstraint {
    NONE,                           # 无约束
    DISTANCE_FROM_VAN,              # 距面包车至少 N 地块（任务 5）
    DISTANCE_FROM_BASE,             # 距基地至少 N 地块（任务 8）
    MUTUAL_DISTANCE,                # 彼此距离至少 N 地块（任务 10/12）
    DISTANCE_FROM_BASE_AND_MUTUAL,  # 距基地 + 彼此距离（任务 11）
}
```

### 7.2 各任务目标标记配置

| 任务 | 标记数 | constraint_type | min_dist_van | min_dist_base | min_mutual | monster_tokens | on_first_arrival |
|---|---|---|---|---|---|---|---|
| 0-4、6 | 0 | - | - | - | - | - | - |
| 5 | 1 | DISTANCE_FROM_VAN | 5 | 0 | 0 | 0 | (抓首领卡，由 boss_config 处理) |
| 7 | 1 | NONE | 0 | 0 | 0 | 0 | (展示触发首领，由 boss_config 处理) |
| 8 | 1 | DISTANCE_FROM_BASE | 0 | 5 | 0 | 0 | (抓首领卡) |
| 9 | 2 | MUTUAL_DISTANCE | 0 | 0 | 0 | 3 | - |
| 10 | 3 | MUTUAL_DISTANCE | 0 | 0 | 2 | 0 | 标记 1/2/3 各不同 skill |
| 11 | 3 | DISTANCE_FROM_BASE_AND_MUTUAL | 0 | 3 | 3 | 3 | - |
| 12 | 3 | MUTUAL_DISTANCE | 0 | 0 | 3 | 0 | - |

> 目标标记的放置算法（满足约束条件）由 `GameSession` 在地图生成阶段执行，详见 09-MapBlock.md（待编写）。

---

## 8. 13 个任务总览

引用 v1 文档 `GameDesignDocs_v1/08-任务系统设计.md` 第 3 节（完整表格含任务名/难度/怪物包/地图大小/燃料需求/起始地块/终点/必需地块）。

本文档不重复，仅列章节分组：

| 章节 | 任务编号 | 怪物包 | 主题 |
|---|---|---|---|
| 第一章 僵尸篇 | 0、1、2、3 | ZOMBIE | 僵尸末日、解药研制 |
| 第二章 突变体篇 | 4、5、6 | MUTANT | 核冬天、拆弹、核辐射 |
| 第三章 外星人篇 | 7、8、9 | ALIEN | 侦查、情报、反击 |
| 第四章 机器人篇 | 10、11、12 | ROBOT | 运输、防御、反攻 |

> 各任务的特殊规则、首领卡机制、目标标记配置详见 v1 文档第 4 节。数据录入阶段将每个任务提取为 `.tres` 文件存放在 `data/missions/` 目录。

---

## 9. 胜利与失败条件

### 9.1 通用失败条件（所有任务）

- 全员死亡
- 怪物标记达到上限（D16，`monster_token_limit`）
- 求生者牌库空且无法抓牌时该玩家被淘汰（D10）

### 9.2 特殊失败条件

| 任务 | 特殊失败条件 |
|---|---|
| 8 | 潜行检定失败且玩家没有日记本 |
| 5 | 炸弹爆炸（3 回合内未返回面包车，D20） |
| 6 | 核辐射吞噬地块导致被困 |

### 9.3 胜利条件模式

| 胜利模式 | 任务 | fuel_required |
|---|---|---|
| 收集燃料 + 回面包车逃离 | 0(4)、1(4)、2(4)、5(3)、6(3)、7(4)、12(3) | > 0 |
| 到达特定地点（不需燃料，D18） | 3（医院）、4（避难所）、8（军事基地）、9（现场）、11（军事基地） | = 0 |
| 收集物资 + 回基地 | 10（军事基地，6 燃料） | = 6 |

> 任务 4 的 3 燃料是任务交付物（R4），不用于启动面包车，`fuel_required` 仍为 0。
> 胜利条件检查由 `GameSession` 在特定时机（回合结束 / 玩家到达地块 / 任务事件）调用，详见 11-GameSession.md（待编写）。

---

## 10. MVP 任务范围（D13）

MVP 阶段仅实现**任务 0（教程）**：

| 范围 | 内容 |
|---|---|
| 任务 | 任务 0（教程，13 块地图，4 燃料） |
| 角色 | 1 名（建议外科医生，31 张牌库，见 07-CharacterCard.md 第 7 节） |
| 怪物包 | 僵尸包（见 05-MonsterCard.md 第 12 节） |
| 拾荒卡 | 任务 0 配置的三色牌堆子集（见 04-ScavengerCard.md 第 10 节） |
| 首领卡 | 无（`boss_config.mechanic = NONE`） |
| 目标标记 | 无（`target_markers = []`） |

任务 0 配置要点：
- `map_layout`：3×6 网格，购物中心起始展示，面包车在 (1,5)（见 4.1 节）
- `scavenger_decks`：三色牌堆各 12 张（共 36 张，见第 5 节）
- `fuel_required`：4
- `monster_pack`：ZOMBIE
- `boss_config.mechanic`：NONE
- `monster_token_limit`：30（默认）

> 验证核心循环（移动 / 拾荒 / 战斗 / 饥饿 / 燃料 / 胜利）后逐步扩展任务 1-12。

---

## 11. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | 任务 1-12 的 `map_layout` 具体值 | 待数据录入阶段根据原版地块清单设计，需保证连通性 |
| 2 | 任务 6 核辐射扩散机制"外围"定义 | 倾向 BFS 从面包车扩展，最外层非空地块为"外围"。待 09-MapBlock.md 定义地块邻接图后实现 |
| 3 | 任务 10 多目标标记效果奖励来源 | 原版明确标记 3 的"2 燃料 + 1 医疗用品"不从拾荒牌库拿取；标记 1/2 奖励来源待确认（倾向都不从牌库拿取，由任务系统直接发出） |
| 4 | `BossConfig.trigger_block` 用 StringName 还是 BlockType 枚举 | 倾向 StringName（地块类型由 09-MapBlock.md 定义，避免循环依赖；StringName 与 `CardData.card_id` 风格一致） |
| 5 | 任务 5/8 的 `trigger_block = &""` 表示"目标地块"的运行时解析 | 由任务系统在目标标记放置后回填 `trigger_block`，或在 `boss_config` 增加一个 `use_marker_as_trigger: bool` 字段。倾向后者（显式标记） |
| 6 | `special_rules` 字段是自然语言还是结构化 | 倾向自然语言（UI 提示用），结构化规则用 `special_rule_skill_ids` 引用 Skill 实现（如任务 6 核辐射、任务 12 地块摧毁） |
| 7 | 任务特殊规则（核辐射 / 地块摧毁 / 拆弹倒计时）是否用 Skill 实现 | 倾向用 `forced=true TRIGGER` 技能实现，`TriggerTiming` 按需扩展（如 `ON_MONSTER_SPAWN` 投出 7 时触发核辐射） |
| 8 | `fuel_required = 0` 表示不需燃料的语义是否清晰 | 倾向 0 = 不需燃料（D18），> 0 = 需要的燃料数。任务 4 的 3 燃料是交付物，`fuel_required` 仍为 0 |
| 9 | `target_markers` 上限 3 个是否在数据层约束 | 倾向不强制（`@export Array` 无上限），由任务设计者保证 ≤ 3（原版配件上限） |
| 10 | `BossConfig` 是否需要 `boss_id` 字段（指定具体首领卡） | 倾向不加：首领卡由怪物包决定（每包 2 张首领），`count` 表示洗入几张；如需指定具体首领再扩展 |
| 11 | 任务 5 回合限制（D20）的倒计时数据存哪 | 倾向 `GameSession` 持有 `turns_remaining: int` 字段，由任务特殊规则 Skill 在拆弹时初始化，每回合开始自减，归零触发失败 |
| 12 | `scavenger_decks` 的 `Dictionary[DeckColor, Array[Dictionary]]` 在 `.tres` 编辑器中的编辑体验 | Godot 4 的 Dictionary 嵌套编辑体验一般，但可接受。若体验差可后续改为 `Array[ScavengerDeckEntry]` 独立 Resource 子类 |

---

## 附：决策应用索引

本文档应用的决策：
- D3 任务卡内置布局 + 地块随机填充（`map_layout` 字段）
- D5 燃料机制（部分任务需收集燃料交付）
- D13 MVP 最小可玩闭环（仅任务 0）
- D16 怪物标记上限由任务卡配置（默认 30）
- D17 初始怪物抓取按座次顺序
- D18 任务 3/4/8/9/11 无需燃料（`fuel_required = 0`）
- D19 任务 2 首领卡洗入牌库底 + 警察局触发额外效果
- D20 任务 5 回合限制 + 倒计时 UI
- R4 任务 4 的 3 燃料是任务交付物
- 用户决策：`scavenger_decks` 用 `Array[Dictionary]`
- 用户决策：`boss_config` / `target_markers` 用独立 Resource 子类
- 用户决策：13 个任务总览引用 v1 不重复
- 沿用 02-Card.md 第 12 节 `MissionCardData` 基类
- 沿用 05-MonsterCard.md 第 4 节 `MonsterPack` 枚举
- 沿用 10-Deck.md 第 4 节 `scavenger_decks` 数据结构
- 沿用 04-ScavengerCard.md 第 4 节 `DeckColor` 枚举
