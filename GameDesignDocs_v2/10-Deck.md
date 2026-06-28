# 10 - Deck（牌堆系统）

> MA 的牌堆系统抽象：卡牌数据注册表（`CardRegistry`）+ 三类牌堆（拾荒 / 怪物 / 求生者）+ 工具函数（`DeckUtils`）。
> 各牌堆行为差异大（3 色混合 pile / 单 pile / Survivor 内嵌字段），**不抽象 Deck/DiscardPile 基类**，独立类 + `DeckUtils` 静态工具函数（ponytail YAGNI，用户决策）。
> 本文档只定义基类与方法签名，不含具体任务卡配置（任务 0-12 见 06-MissionCard.md，待编写）。
> 应用 v1 决策：D10（怪物牌库 / 求生者牌库弃牌堆可重洗）、D12（拾荒牌堆空无法拾荒、弃牌堆不可重洗）、D17（初始抓怪按座次）、D13（MVP 范围）。

---

## 1. 设计原则

- **不抽象基类**：`ScavengerDeckStack`（3 色 pile）/ `MonsterDeck`（单 pile）/ `Survivor.deck`（内嵌字段）行为差异大，独立类 + `DeckUtils` 静态工具函数更直接，避免勉强适配的虚接口（用户决策，ponytail YAGNI）。
- **Survivor 牌库保持内嵌字段**：沿用 07-CharacterCard.md 现状（`Survivor.deck` / `Survivor.discard_pile` 是 `Array[CardInstance]`），不引入 `SurvivorDeck` 类，`DeckUtils` 提供工具函数操作（用户决策）。
- **CardRegistry autoload + 自动扫描**：Godot autoload 单例，启动时扫描 `res://data/` 目录下所有 `.tres` 文件自动注册。新增卡牌只需丢文件，不需改代码（用户决策）。
- **数据 + 逻辑分离**：`CardRegistry` 只存不可变 `CardData`，运行时 `CardInstance` 由 `GameSession` 按任务卡配置实例化（沿用 02-Card.md 决策）。
- **牌堆循环规则三类区分**：拾荒（D12 不可重洗，空 → 无法拾荒）/ 怪物（D10 可重洗，空 → 重洗弃牌堆）/ 求生者（D10 可重洗，空 → 玩家淘汰）。

---

## 2. CardRegistry（autoload 单例）

```text
class_name CardRegistry extends Node
# 在 project.godot 中配置为 autoload（单例名 CardRegistry）
# 启动时自动扫描 res://data/ 下所有 .tres 文件并注册

# 表：card_id -> CardData
var _registry: Dictionary = {}

# === 启动时自动注册 ===
func _ready() -> void:
    _scan_and_register("res://data/cards/")
    _scan_and_register("res://data/monsters/")
    _scan_and_register("res://data/missions/")
    _scan_and_register("res://data/characters/")

# 递归扫描目录，加载所有 .tres Resource 文件
# 重复 card_id 报错并拒绝加载后者
func _scan_and_register(dir_path: String) -> void:
    # 遍历目录（递归子目录）：
    #   对每个 .tres 文件 load() 获取 CardData
    #   if _registry.has(card_data.card_id): push_error(重复)
    #   else: _registry[card_data.card_id] = card_data
    pass

# === 手动注册 ===
# 供代码动态创建的 CardData 用（如任务系统运行时生成的卡）
func register(card_data: CardData) -> void:
    if _registry.has(card_data.card_id):
        push_error("CardRegistry: duplicate card_id %s" % card_data.card_id)
        return
    _registry[card_data.card_id] = card_data

# === 查询 ===
func get_card_data(card_id: StringName) -> CardData:
    return _registry.get(card_id, null)

func has_card(card_id: StringName) -> bool:
    return _registry.has(card_id)

func get_all_card_ids() -> Array[StringName]:
    return _registry.keys()
```

> `CardRegistry` 是全局只读注册表：只存不可变 `CardData`，不存 `CardInstance`。`CardInstance` 由 `GameSession` 按任务卡配置（`scavenger_decks` / `survivor_deck_card_ids` / 怪物包扫描）实例化并分发到各牌堆。

### 2.1 推荐目录结构

```text
res://data/
├── cards/
│   ├── scavenger/
│   │   ├── red/         # 医疗用品、解毒剂、燃料
│   │   ├── blue/        # 弹药、炸药、装备（防弹背心/对讲机/手枪/背包/手电筒/双筒望远镜）
│   │   ├── green/       # 食物
│   │   └── gray/        # 事件卡 + 任务物品卡 + 科学家
│   └── survivor/
│       ├── surgeon/
│       ├── mechanic/
│       ├── hunter/
│       ├── firefighter/
│       └── cowboy/
├── monsters/
│   ├── zombie/
│   ├── mutant/
│   ├── alien/
│   └── robot/
├── missions/
│   ├── mission_0.tres
│   └── ...
└── characters/
    ├── surgeon.tres
    └── ...
```

> 按原版文件结构对照分目录，便于数据录入与原版 md 文件一一映射。

---

## 3. DeckUtils（静态工具函数）

```text
class_name DeckUtils

# === 洗混 ===
# Fisher-Yates 洗混算法（原地修改 array）
static func shuffle(array: Array) -> void:
    for i in range(array.size() - 1, 0, -1):
        var j = randi_range(0, i)
        var tmp = array[i]
        array[i] = array[j]
        array[j] = tmp

# === 抓牌 ===
# 从牌堆顶部抓 1 张（返回 null 表示牌堆空）
static func draw_top(array: Array) -> Variant:
    if array.is_empty():
        return null
    return array.pop_front()

# 从牌堆顶部抓 n 张（不足则返回实际抓到的）
static func draw_n(array: Array, n: int) -> Array:
    var result: Array = []
    for i in n:
        if array.is_empty():
            break
        result.append(array.pop_front())
    return result

# === 求生者牌库重洗（D10，操作 Survivor 内嵌字段） ===
# discard_pile 洗混后追加到 deck 末尾，清空 discard_pile
# 调用时机：deck 空且需抓牌时（惰性重洗，03-SurvivorCard.md Q1 倾向）
static func reshuffle_survivor_deck(survivor: Survivor) -> int:
    var count = survivor.discard_pile.size()
    shuffle(survivor.discard_pile)
    survivor.deck.append_array(survivor.discard_pile)
    survivor.discard_pile.clear()
    return count

# === 怪物弃牌堆重洗进怪物牌库（D10） ===
# discard.cards 洗混后追加到 deck.cards 末尾，清空 discard.cards
# 调用时机：怪物牌库空且需抓怪时（惰性重洗）
static func reshuffle_monster_discard(deck: MonsterDeck, discard: MonsterDiscardPile) -> int:
    var count = discard.cards.size()
    shuffle(discard.cards)
    deck.cards.append_array(discard.cards)
    discard.cards.clear()
    return count
```

> `DeckUtils` 只提供无状态的静态工具函数，不持有任何数据。各牌堆类通过组合使用这些函数实现具体行为。

---

## 4. ScavengerDeckStack（三色拾荒牌堆）

```text
class_name ScavengerDeckStack extends RefCounted

# 三色拾荒牌堆（每色一个混合牌堆，可含 4 色大类卡牌）
# piles: Dictionary[DeckColor, Array[CardInstance]]
var piles: Dictionary = {}

func _init():
    for color in [DeckColor.RED, DeckColor.BLUE, DeckColor.GREEN]:
        piles[color] = []

# === 抓牌 ===
# 从指定色牌堆抓 1 张
# 返回 null 表示该色牌堆空（D12：无法拾荒，UI 提示地块拾荒标记变灰）
# 调用方负责后续设置 card 的去向（进手牌 / 触发事件卡 / 燃料卡三选一等）
func draw(color: DeckColor) -> CardInstance:
    var pile: Array = piles[color]
    if pile.is_empty():
        return null
    var card: CardInstance = pile.pop_front()
    # location 由调用方按去向重设（HAND / IN_PLAY / DISCARD_PILE）
    return card

# === 查询 ===
func is_empty(color: DeckColor) -> bool:
    return piles[color].is_empty()

func get_count(color: DeckColor) -> int:
    return piles[color].size()

# === 洗混 ===
func shuffle(color: DeckColor) -> void:
    DeckUtils.shuffle(piles[color])

func shuffle_all() -> void:
    for color in piles.keys():
        DeckUtils.shuffle(piles[color])

# === 初始化（由 GameSession 调用） ===
# 从任务卡 scavenger_decks 配置实例化所有卡牌并按色分堆洗混
func init_from_mission(mission_data: MissionCardData) -> void:
    # mission_data.scavenger_decks: Dictionary[DeckColor, Array[Dictionary]]
    # 每条 Dictionary 含 card_id: StringName + count: int
    for color in mission_data.scavenger_decks.keys():
        for entry in mission_data.scavenger_decks[color]:
            var card_data = CardRegistry.get_card_data(entry.card_id)
            for i in entry.count:
                var instance = CardInstance.new()
                instance.data = card_data
                instance.location = CardLocation.DECK
                piles[color].append(instance)
        shuffle(color)
```

> 拾荒牌堆的 `draw()` 不设置 `card.location`：因为抓到的卡去向多样（进手牌 / 触发事件卡 forced TRIGGER 后进弃牌堆 / 燃料卡三选一），由调用方（`Survivor.draw_from_scavenger_deck` 或地块拾荒流程）按去向设置。
>
> **D12 关键约束**：拾荒牌堆空 → 该色无法拾荒；弃牌堆不可重洗。`ScavengerDeckStack` 不提供 reshuffle 方法。

---

## 5. ScavengerDiscardPile（引用 04）

`ScavengerDiscardPile`（1 个全局拾荒弃牌堆，所有色合并，不可重洗）已在 **04-ScavengerCard.md 第 6.1 节** 完整定义，本文档不重复。

关键签名回顾：

```text
class_name ScavengerDiscardPile extends RefCounted
var cards: Array[CardInstance] = []
func add(card: CardInstance) -> void           # card.location = DISCARD_PILE
func get_count_by_color(color: ScavengerColor) -> int   # UI 按色统计
```

> D12：拾荒弃牌堆不可重洗，无 `reshuffle_into()` 方法。

---

## 6. MonsterDeck（怪物牌库）

```text
class_name MonsterDeck extends RefCounted

# 怪物牌库（1 个 pile，含该怪物包的所有 ELITE + NORMAL 怪物卡）
# 首领卡（BOSS）不进普通牌库，由任务卡 boss_config 单独配置入场（05-MonsterCard.md 第 5 节）
var cards: Array[CardInstance] = []

# === 抓牌 ===
# 从牌堆顶部抓 1 张
# 返回 null 表示牌库空（需重洗弃牌堆 D10，调用方负责调用 DeckUtils.reshuffle_monster_discard）
# 调用方负责后续创建 Monster Node 并 engage(player)
func draw() -> CardInstance:
    if cards.is_empty():
        return null
    var card: CardInstance = cards.pop_front()
    card.location = CardLocation.IN_PLAY   # 怪物卡抓取后进场上场
    return card

# === 查询 ===
func is_empty() -> bool:
    return cards.is_empty()

func get_count() -> int:
    return cards.size()

# === 洗混 ===
func shuffle() -> void:
    DeckUtils.shuffle(cards)

# === 初始化（由 GameSession 调用） ===
# 从怪物包扫描所有 ELITE + NORMAL 怪物卡（首领卡除外），按 count 创建多份实例，洗混
func init_from_monster_pack(pack: MonsterPack) -> void:
    # 扫描 res://data/monsters/<pack>/ 下所有 .tres 文件
    # 对每个 MonsterCardData：
    #   if data.level == BOSS: 跳过（首领卡由 boss_config 配置）
    #   else: 按 data.count 创建 count 份 CardInstance，加入 cards
    # 洗混
    shuffle()
```

> 怪物卡的 `count`（该怪物在牌库中的张数）字段待 `MonsterCardData` 补充（见 Q5）。原版每种怪物有多张（如僵尸狗 6 张），靠 `count` 字段表达。

---

## 7. MonsterDiscardPile（怪物弃牌堆，可重洗 D10）

```text
class_name MonsterDiscardPile extends RefCounted

# 怪物弃牌堆（1 个全局，可重洗 D10）
var cards: Array[CardInstance] = []

# === 添加 ===
# 怪物被消灭 / 玩家死亡纠缠怪物置入 / 卡牌效果赶走 时调用
func add(card: CardInstance) -> void:
    card.location = CardLocation.DISCARD_PILE
    cards.append(card)

# === 查询 ===
func get_count() -> int:
    return cards.size()

func is_empty() -> bool:
    return cards.is_empty()

# === 重洗进怪物牌库（D10） ===
# 由调用方在怪物牌库空且需抓怪时调用（惰性重洗）
# 使用 DeckUtils.reshuffle_monster_discard(deck, self) 实现
# 此处不直接提供方法，避免与 DeckUtils 职责重复
```

> 与 `ScavengerDiscardPile`（不可重洗，D12）对比：`MonsterDiscardPile` 可重洗（D10），重洗逻辑由 `DeckUtils.reshuffle_monster_discard()` 工具函数提供，不在此类内实现（保持类职责单一）。

---

## 8. 求生者牌库（Survivor 内嵌字段 + 工具函数）

求生者牌库与弃牌堆是 `Survivor` 的内嵌字段（07-CharacterCard.md 第 3 节已定义），**不独立成类**（用户决策）：

```text
# 07-CharacterCard.md 已定义（此处回顾）
class_name Survivor extends Entity

var hand: Array[CardInstance] = []          # 手牌（上限 10）
var deck: Array[CardInstance] = []          # 求生者牌库（运行时实例化）
var discard_pile: Array[CardInstance] = []  # 求生者弃牌堆
```

牌库循环操作由 `DeckUtils` 工具函数提供：

```text
# 抓牌（Survivor.draw_from_survivor_deck 内部调用）
# deck 空 + 需抓牌 → 玩家被淘汰（D10，与拾荒/怪物不同）
# deck 空 + discard_pile 非空 → 惰性重洗（DeckUtils.reshuffle_survivor_deck）

# 重洗（D10）
DeckUtils.reshuffle_survivor_deck(survivor)
# → survivor.discard_pile 洗混后追加到 survivor.deck 末尾
# → survivor.discard_pile 清空
```

> **D10 关键约束**：求生者牌库空时玩家被淘汰（不像怪物牌库可重洗）。重洗发生在"deck 空 + discard_pile 非空 + 需抓牌"的惰性时机（03-SurvivorCard.md Q1 倾向）。

---

## 9. 牌堆初始化流程（GameSession 主导）

```text
GameSession 初始化阶段（游戏开始时）：

  1. CardRegistry._ready()
     → 自动扫描 res://data/ 下所有 .tres 文件并注册到 _registry

  2. 读取任务卡 MissionCardData（由玩家选择的任务决定）
     mission_data = CardRegistry.get_card_data(mission_id)

  3. 初始化拾荒牌堆
     scavenger_deck_stack = ScavengerDeckStack.new()
     scavenger_deck_stack.init_from_mission(mission_data)
     # → 按任务卡 scavenger_decks 配置实例化卡牌，按色分堆并洗混

  4. 初始化拾荒弃牌堆（全局 1 个）
     scavenger_discard_pile = ScavengerDiscardPile.new()

  5. 初始化怪物牌库 + 弃牌堆
     monster_deck = MonsterDeck.new()
     monster_deck.init_from_monster_pack(mission_data.monster_pack)
     # → 扫描该怪物包 .tres，实例化 ELITE + NORMAL 怪物卡（首领卡除外），洗混
     monster_discard_pile = MonsterDiscardPile.new()

  6. 初始化求生者（每个玩家一个 Survivor）
     for character_data in selected_characters:
       survivor = Survivor.new()
       survivor.data = character_data
       # 实例化求生者牌库
       for card_id in character_data.survivor_deck_card_ids:
         card_data = CardRegistry.get_card_data(card_id)
         instance = CardInstance.new()
         instance.data = card_data
         instance.source = CardSource.SURVIVOR_DECK
         instance.location = CardLocation.DECK
         survivor.deck.append(instance)
       DeckUtils.shuffle(survivor.deck)
       # hand / discard_pile 初始为空

  7. 初始抓怪（D17，按座次顺序每人抓 1 张怪物卡）
     for survivor in survivors_by_seat_order:
       card = monster_deck.draw()
       # → 创建 Monster Node, engage(survivor)

  8. 首领卡处理（由任务卡 boss_config 单独配置，待 06-MissionCard.md 定义）
```

> `GameSession` 是牌堆系统的持有者与初始化者，各牌堆实例作为 `GameSession` 的子节点或字段存在（待 11-GameSession.md 定义）。

---

## 10. 三种牌堆循环规则对比

| 维度 | 拾荒牌堆 | 怪物牌库 | 求生者牌库 |
|---|---|---|---|
| **归属** | 全局共享 | 全局共享 | 角色个人 |
| **牌堆数** | 3 个（RED/BLUE/GREEN 混合） | 1 个 | 每求生者 1 个 |
| **弃牌堆** | 1 个全局（`ScavengerDiscardPile`） | 1 个全局（`MonsterDiscardPile`） | 每求生者 1 个（`Survivor.discard_pile`） |
| **配置来源** | 任务卡 `scavenger_decks` | 任务卡 `monster_pack` + 怪物包 .tres | 角色卡 `survivor_deck_card_ids` |
| **牌堆空时** | 该色无法拾荒（D12） | 弃牌堆重洗为新牌库（D10） | 玩家被淘汰（D10） |
| **弃牌堆可重洗** | ❌ 不可（D12） | ✅ 可（D10） | ✅ 可（D10） |
| **重洗时机** | - | 惰性（牌库空 + 需抓怪时） | 惰性（牌库空 + 需抓牌时，03 Q1） |
| **首领卡** | 不进拾荒牌堆 | 不进普通牌库（`boss_config` 单独配置） | - |
| **数据结构类** | `ScavengerDeckStack` | `MonsterDeck` + `MonsterDiscardPile` | `Survivor` 内嵌字段 + `DeckUtils` |
| **抓牌 API** | `ScavengerDeckStack.draw(color)` | `MonsterDeck.draw()` | `Survivor.draw_from_survivor_deck(n)`（07 第 3 节） |

> 三类牌堆的核心差异在"牌堆空时行为"与"弃牌堆可否重洗"，由 D10（怪物/求生者可重洗）与 D12（拾荒不可重洗）决策决定。

---

## 11. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | 怪物牌库重洗时机（惰性 vs eager） | 倾向惰性重洗（牌库空 + 需抓怪时重洗，与求生者牌库 03 Q1 一致）。eager 重洗会导致"牌库空"相关效果无法触发 |
| 2 | `CardRegistry` 自动扫描的目录结构是否需要严格按色/角色/怪物包分 | 倾向按原版文件结构分目录（见 2.1 节），便于数据录入对照。但 `CardRegistry` 本身不依赖目录结构，只按 `card_id` 索引 |
| 3 | 同一 `card_id` 在多个 .tres 文件中定义的冲突处理 | `CardRegistry` 启动时检测重复 `card_id`，`push_error` 并拒绝加载后者（fail-fast） |
| 4 | 任务系统动态发出的卡（如科学家）是否注册到 `CardRegistry` | 倾向注册：科学家作为任务专属装备卡在 `data/cards/scavenger/gray/scientist.tres` 中定义，由任务系统通过 `card_id` 引用，`source` 可设为 `MISSION` 或 `SCAVENGER_DECK`（04 第 7.3 节） |
| 5 | 怪物包 .tres 文件如何表达"每种怪物多张"（如僵尸狗 6 张） | 倾向 `MonsterCardData` 增加 `count: int` 字段（该怪物在牌库中的张数），`init_from_monster_pack` 按 `count` 创建多份 `CardInstance`。待 05-MonsterCard.md 补充字段 |
| 6 | `ScavengerDeckStack` 是否需要 `peek`（窥视牌顶）方法 | 倾向不加公共 API：手电筒"窥视顶 2 张"效果在 Skill 内部直接访问 `piles[color]` 读取前 2 个元素，不暴露 peek 方法（YAGNI） |
| 7 | `MonsterDeck` 是否暴露 `peek` | 不需要（无效果需要窥视怪物牌库顶） |
| 8 | 牌堆洗混的随机源（`randi_range` 是否需要种子） | 暂用 Godot 默认随机数。需要确定性随机时（如录像回放 / 种子复现）再加 `seed` 参数到 `DeckUtils.shuffle()` |
| 9 | `ScavengerDeckStack` 是否需要"按色统计弃牌堆"用于 UI | 已由 `ScavengerDiscardPile.get_count_by_color()` 提供（04 第 6.1 节），不在此类重复 |
| 10 | 牌堆是否需要"底牌"操作（如任务 2 首领卡洗入牌库底 10 张，D19） | 倾向 `MonsterDeck` 增加 `insert_at_bottom(card, offset=0)` 方法，待 06-MissionCard.md 定义 `boss_config` 时同步设计 |

---

## 附：决策应用索引

本文档应用的决策：
- D10 怪物牌库 / 求生者牌库弃牌堆可重洗
- D12 拾荒牌堆空无法拾荒（弃牌堆不可重洗）
- D13 MVP 最小可玩闭环（任务 0 配置子集）
- D17 初始抓怪按座次顺序
- 用户决策：不抽象 Deck/DiscardPile 基类，独立类 + DeckUtils 工具函数
- 用户决策：Survivor 牌库保持内嵌字段，不独立成类
- 用户决策：CardRegistry autoload + 自动扫描 .tres
- 沿用 04-ScavengerCard.md 第 6.1 节 `ScavengerDiscardPile` 定义
- 沿用 07-CharacterCard.md 第 3 节 `Survivor.deck` / `discard_pile` 内嵌字段
- 沿用 05-MonsterCard.md 第 8 节怪物牌库循环规则
- 沿用 03-SurvivorCard.md 第 4 节求生者牌库循环规则（Q1 惰性重洗倾向）
