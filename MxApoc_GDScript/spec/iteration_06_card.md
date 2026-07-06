# 轮次 06:Card 实体 + DrawFlow + DiscardFlow

> 状态: `[ ] 未开始`(规划待用户审阅)
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md)
> 规则来源:[GameSystem/DrawFlow.md](../GameDesignDocus/GameSystem/DrawFlow.md) | [GameSystem/DiscardFlow.md](../GameDesignDocus/GameSystem/DiscardFlow.md) | [GameInstructions/H_useCard.md](../GameDesignDocus/GameInstructions/H_useCard.md) | [GameInstructions/C_gameSetup.md](../GameDesignDocus/GameInstructions/C_gameSetup.md)

---

## 1. 范围

本轮实现卡牌实体双层类、Pile 牌堆对象、最小 game 对象骨架,并在其上落地 5 个已定义方法的真实逻辑。包含:

### 1.1 新增系统类(11 个文件)

**数据层(Resource,4 个)**:
1. `scripts/system/card_data.gd` — `CardData extends Resource`:卡牌静态数据基类
2. `scripts/system/scavenge_card_data.gd` — `ScavengeCardData extends CardData`:拾荒卡数据
3. `scripts/system/survivor_game_card_data.gd` — `SurvivorGameCardData extends CardData`:求生者游戏牌数据
4. `scripts/system/monster_card_data.gd` — `MonsterCardData extends CardData`:怪物卡数据

**实体层(extends Entity,5 个)**:
5. `scripts/system/card.gd` — `Card extends Entity`:卡牌实体基类(名字/source/skill)
6. `scripts/system/item_card.gd` — `ItemCard extends Card`:物品卡中间类(填充物系统,被拾荒卡与游戏牌共用)
7. `scripts/system/scavenge_card.gd` — `ScavengeCard extends ItemCard`:拾荒卡实体
8. `scripts/system/survivor_game_card.gd` — `SurvivorGameCard extends ItemCard`:求生者游戏牌实体
9. `scripts/system/monster_card.gd` — `MonsterCard extends Card`:怪物卡实体(含纠缠对象/生命值等)

**辅助对象(2 个)**:
10. `scripts/system/pile.gd` — `Pile extends RefCounted`:通用牌堆对象
11. `scripts/system/game.gd` — `Game extends RefCounted`:最小 game 对象骨架

### 1.2 修改现有类

- `scripts/system/player.gd`:
  - 新增卡牌区域(手牌区/装备区/游戏牌堆/游戏牌弃牌堆/怪物区)
  - 持有 game 引用
  - **实现真实逻辑**:`draw`/`drawScavenge`/`drawMonster`/`discard`/`removeCard`
  - 新增辅助方法:`getAllGameCards`/`getCards(source=)`/`get_pile(name)` 等(待定义方法,本轮实现)

### 1.3 本轮实现的已定义方法(5 个)

- `player.draw(n)` — 4 节点钩子链,牌堆空触发 `playerDeath(NULL)`
- `player.drawScavenge(n, pile)` — 4 节点钩子链,逐张触发「时」,牌堆空停止
- `player.drawMonster(num)` — 6 节点钩子链,逐张实体化,牌堆空重洗弃牌堆
- `player.discard(target, position=NULL, quantity=1, type=NULL)` — 3 节点钩子链,按 source 分派弃牌堆
- `player.removeCard(target, position=NULL, quantity=1)` — 3 节点钩子链,销毁不进弃牌堆

### 1.4 本轮实现的相关待定义方法

- `player.getAllGameCards()` — 手牌+装备+牌堆+弃牌堆
- `player.getCards(source=)` — 按来源过滤
- `player.getPile(name)` — 按名字获取牌堆
- `game.getScavengePile(color)` — 按颜色获取拾荒牌堆
- `game.removeCard(card)` — 卡牌移出游戏
- `game.allPlayersDead()` — stub(本轮不实现真实逻辑)
- `game.gameOver(result)` — stub

### 1.5 本轮不实现

- `player.playerDeath(source)` / `monsterDeath(source)` 真实逻辑(仍 stub,iteration_07)
- `game.gameOver` / `game.allPlayersDead` 真实逻辑(stub)
- 手牌上限校验(由上层回合流程处理)
- 卡牌结算区(C_gameSetup §"卡牌结算区",未使用)
- 装备/卸下装备的真实流程(`player.装备(card)` 等待定义方法,本轮不实现)
- §9.14 `card.在玩家装备区内`(本轮 stub)
- 卡牌技能的运行时挂载(本轮 Card.get_all_skills 返回 data.skill,不支持动态 add_skill 到卡)
- 拾荒卡/怪物卡数据落地到 `data/`(本轮代码内联)

---

## 2. 前置依赖

- **代码**: 01 EventTrigger、02 Player 骨架、03 DamageFlow、04 PlayerState、05 Judge
- **文档**: 已读 `GameSystem/DrawFlow.md`、`GameSystem/DiscardFlow.md`、`GameInstructions/C_gameSetup.md`、`GameInstructions/H_useCard.md`、4 个 ScavengePacks、4 个 MonsterPacks、SurvivorPacks/firefighter.md

---

## 3. 设计要点(从设计文档提炼)

### 3.1 卡牌种类与字段

| 卡牌种类 | source | 独有字段 | 共有字段 |
|---------|--------|---------|---------|
| 拾荒卡(ScavengeCard) | `"scavenge"` | `color`(red/green/blue)、`category`(食物/战备/补给/其他)、`value`(数值,可选) | `name`、`type`(行动/装备)、`size`、`filler_*`、`skill` |
| 求生者游戏牌(SurvivorGameCard) | `"game"` | `deck_count`(牌堆中数量,组堆用) | `name`、`type`、`size`、`filler_*`、`skill` |
| 怪物卡(MonsterCard) | `"monster"` | `level`(首领/精英/普通)、`monster_type`、`max_hp`、`atk`、`range`、纠缠对象 | `name`、`skill` |

填充物字段(仅装备卡用,行动卡为空):
- `filler_type`(弹药/燃料/空尖弹等,可空)
- `filler_max`(上限,0 表示无填充物)
- `filler_init`(初始填充数)
- `filler_count`(运行时当前填充数)

### 3.2 全局与玩家区域(C_gameSetup §"游戏初始化")

**全局区域**(game 对象持有):
- 怪物牌堆(`Pile`)+ 怪物弃牌堆(`Pile`)
- 三色拾荒牌堆(`Dictionary<String, Pile>`,键 red/green/blue)
- 拾荒弃牌堆(单一 `Pile`,**不分色** — 见 §3.5 歧义解决)

**玩家区域**(Player 持有):
- 手牌区(`Pile`)
- 装备区(`Array[Card]`,有大小限制,按位置查询)
- 怪物区(`Array[MonsterCard]`,有顺序,先入先行动)
- 游戏牌堆(`Pile`)+ 游戏牌弃牌堆(`Pile`)

### 3.3 draw 流程要点(DrawFlow.md)

**`player.draw(n)`** — 4 节点:
1. 抓取游戏牌前(取消点)
2. 抓取游戏牌时(取消点,可改 `event.num`)
3. 逐张抓取:每张前检查牌堆,空 → `playerDeath(NULL)` 并 return
4. 抓取游戏牌后

`event` 成员:`player`/`num`/`cards`/`cancelled`。手牌上限由上层校验,本轮不处理。

**`player.drawScavenge(n, pile)`** — 4 节点:
1. 抓取拾荒牌前(取消点,如手电筒替代)
2. 逐张抓取:抓1张→入手牌区→触发「时」→抓下一张。牌堆空时停止(不重洗)
3. 抓取拾荒牌后

`event` 成员:`player`/`pile`/`num`/`cards`/`card`(当前)/`cancelled`。

**`player.drawMonster(num)`** — 6 节点(每张怪物卡走 a-f,全部抓完后走节点 3):
1. 抓取怪物卡前(取消点,如 firefighter 梯子)
2. 逐张抓取:
   - a. 牌堆空时重洗怪物弃牌堆;重洗后仍为空 → `game.gameOver("lose")`
   - b. 抓取怪物卡时
   - c. 怪物卡进入求生者怪物区前
   - d. 实体化:设置纠缠对象=player、生命值=max_hp
   - e. 怪物卡进入求生者怪物区时(加入怪物区)
   - f. 怪物卡进入求生者怪物区后(如 zombie 一大波僵尸在此递归 drawMonster)
3. 抓取怪物卡后(整体触发,如 mechanic 感应地雷)

`event` 成员:`player`/`num`/`cards`/`target`(当前怪物卡)/`cancelled`。

### 3.4 discard / removeCard 流程要点(DiscardFlow.md)

**`player.discard(target, position=NULL, quantity=1, type=NULL)`** — 3 节点:
1. 弃置牌前(取消点)
2. 逐张弃置:从原位置移除 → 进入对应弃牌堆 → 触发「弃置牌时」
3. 弃置牌后

`target` 重载形态:
- `discard(card)` — 单张牌对象
- `discard(cards)` — 牌列表
- `discard(name, position=, quantity=1)` — 按名字+位置+数量
- `discard(type, type=true)` — 按卡牌类型弃置所有

**弃牌堆分派**(按 `card.source`):
- `source == "scavenge"` → 进入**单一**拾荒弃牌堆(不分色,见 §3.5)
- `source == "game"` 或其他 → 玩家游戏牌弃牌堆
- `source == "monster"` → 怪物弃牌堆

**`player.removeCard(target, position=NULL, quantity=1)`** — 3 节点:
1. 销毁牌前(取消点)
2. 逐张销毁:从原位置移除 → `game.removeCard(card)` 移出游戏 → 触发「销毁牌时」
3. 销毁牌后

`target` 重载:`removeCard(card)` / `removeCard(cards)` / `removeCard(name, position=, quantity=1)`。销毁的牌**不进入弃牌堆**。

### 3.5 歧义解决:拾荒弃牌堆分色

**冲突**:
- `C_gameSetup.md`:"拾荒弃牌堆 # 不分颜色(所有颜色的拾荒牌弃置后都进入此弃牌堆)"
- `DiscardFlow.md`:`game.getScavengePile(card.颜色).discardPile.add(card)` 按色分派

**本轮处理**(用户确认): 采用 `C_gameSetup.md` 的描述,**拾荒弃牌堆不分色,单一堆**。

**文档修订**: 本轮修订 `GameSystem/DiscardFlow.md` 的伪代码,将 `game.getScavengePile(card.颜色).discardPile.add(card)` 改为 `game.scavenge_discard_pile.add(card)`。同时在 `待设计方法.md` §9.20 登记此解决。

**DeathFlow 影响**: `playerDeath` 死亡流程 3c "拾荒卡按颜色洗回对应拾荒牌堆"需要从单一拾荒弃牌堆中按 `card.颜色` 筛选,分别洗回。本轮 `playerDeath` 仍 stub,但 §9.20 解决应记入待设计文档供 iteration_07 使用。

---

## 4. 设计决策(需确认)

### 4.1 类层级设计(提议)

```
Resource
└── CardData                      # 基类:id/display_name/source/skill
    ├── ScavengeCardData          # +color/category/value/type/size/filler_*
    ├── SurvivorGameCardData      # +type/size/filler_*/deck_count
    └── MonsterCardData           # +level/monster_type/max_hp/atk/range

Entity
└── Card                          # 基类:持有 CardData,共有的名字/source/skill
    ├── ItemCard                  # 中间类:填充物系统(7 方法 + 3 字段)
    │   ├── ScavengeCard          # +color/category getter
    │   └── SurvivorGameCard      # (无额外字段,类型独立)
    └── MonsterCard               # +怪物属性 + 纠缠对象 + 实体化方法
```

**理由**:
- 数据层与实体层一一对应,4 子类 ↔ 4 子类(中间 ItemCard 仅实体层有,数据层无对应 — 因 ScavengeCardData 与 SurvivorGameCardData 字段重复但语义独立)
- ItemCard 中间类提取填充物系统(7 方法 + 3 字段),避免 ScavengeCard 与 SurvivorGameCard 代码重复
- MonsterCard 不继承 ItemCard(怪物卡无填充物)
- `card is ScavengeCard` / `card is MonsterCard` 类型判断清晰

**替代方案**(未采用):
- 单一 Card 类所有字段内联:简单但类型不清晰,违反用户"Card + CardData 双层(都有子类)"选择
- Card 基类含填充物:MonsterCard 不应有的字段污染

**此层级需用户确认。** 若用户希望简化(如合并 ScavengeCard 与 SurvivorGameCard 为 ItemCard,用 source 区分),本轮调整。

### 4.2 Card 实体与 CardData 的关系

类比 `SurvivorData`(静态) vs `Player`(运行时):
- `CardData` 是静态描述(从设计文档落地,本轮代码内联)
- `Card` 是运行时实体,持有 `CardData` 引用,维护运行时状态(当前填充数/纠缠对象/当前生命值等)
- 同一 `CardData`(如"手枪")在场上可有多个 `Card` 实例(每个独立维护填充数)

```gdscript
# 示例:ItemCard 的填充物系统
class_name ItemCard extends Card

var _data: SurvivorGameCardData  # 或 ScavengeCardData,构造时传入
var _filler_count: int = 0

func _init(data: Variant) -> void:
    _data = data
    _filler_count = data.filler_init

func get_filler_count() -> int:
    return _filler_count

func get_filler_max() -> int:
    return _data.filler_max

func get_filler_type() -> String:
    return _data.filler_type

# 添加 n 个 type 类型填充物(type 与 filler_type 必须一致)
# 规则引用: 待设计方法.md §4.1
func add_filler(n: int, type: String = "") -> void:
    if n <= 0:
        return
    var t := type if type != "" else _data.filler_type
    if t != _data.filler_type and not _change_filler_type_impl(t):
        return
    _filler_count = min(_filler_count + n, _data.filler_max)

# 添加到最大值(关键字 max)
func add_filler_to_max(type: String = "") -> void:
    _filler_count = _data.filler_max

# 补满填充物(无参版,Scav:gunslinger 空尖弹/Sur:mechanic 自制子弹用)
func refill_filler() -> void:
    _filler_count = _data.filler_max

# 改变填充物类型(如空尖弹)
func change_filler_type(type: String) -> void:
    _change_filler_type_impl(type)
```

**API 命名说明**(中文 → 英文):
- `card.名字` → `card.get_name()` 或 `card.name`(属性)
- `card.颜色` → `card.get_color()`
- `card.类型` → `card.get_type()`
- `card.填充物类型` → `card.get_filler_type()`
- `card.填充物上限` → `card.get_filler_max()`
- `card.当前填充数` → `card.get_filler_count()`
- `card.大小` → `card.get_size()`
- `card.添加填充物(n, type)` → `card.add_filler(n, type="")`(type 默认空表示用卡自身 filler_type)
- `card.添加填充物(max, type)` → `card.add_filler_to_max(type="")`(关键字 max 用专门方法)
- `card.补满填充物()` → `card.refill_filler()`
- `card.改变填充物类型(type)` → `card.change_filler_type(type)`

**此命名方案需用户确认。** 若用户希望严格保留设计文档的 camelCase 中文混合写法(如 `card.添加填充物`),本轮调整。

### 4.3 Card.get_all_skills 设计

设计文档中卡牌技能挂在卡牌 data 上(如 blue.md 背包技能)。Card 实体需在 trigger 时返回自身技能。

```gdscript
# Card 基类
func get_all_skills() -> Array[Skill]:
    var skills: Array[Skill] = []
    skills.append_array(_skills)  # 动态添加的(本轮基本不用)
    if _data.skill != null:
        skills.append(_data.skill)
    return skills
```

- `_data.skill` 是卡牌定义里的技能(Skill 资源)
- `_skills` 是运行时动态添加的技能(本轮基本不使用,留扩展点)

**背包技能触发说明**: blue.md 背包 `trigger: 卡牌进入装备区时、卡牌离开装备区时`,`filter: return event.card.名字 == "背包"`。这意味着技能挂在某处(可能是 Player 上由系统路由,或 Card 自身),trigger 时 `event.card` 判断。

**本轮处理**: 装备/卸下装备的真实流程(`player.装备(card)`)未实现(待定义方法),因此本轮 `卡牌进入装备区时`/`离开装备区时` 触发节点**不接入实际流程**。Card.get_all_skills 返回 data.skill 即可,后续装备流程轮次接入。

### 4.4 Pile 牌堆对象设计(提议)

```gdscript
class_name Pile extends RefCounted

var _cards: Array = []  # Array[Card],顶在数组末尾

# 抓顶牌(移除并返回)。空时返回 null。
func draw() -> Variant:
    if _cards.is_empty():
        return null
    return _cards.pop_back()

# 查看顶 n 张(不抓取)。n 大于剩余数时返回全部。
func peek_top(n: int) -> Array:
    var start := max(0, _cards.size() - n)
    return _cards.slice(start)

# 加到底部。
func add(card: Variant) -> void:
    if card != null:
        _cards.push_front(card)

# 加到顶部。
func add_to_top(card: Variant) -> void:
    if card != null:
        _cards.push_back(card)

# 加到底部(别名,与 add 一致)。
func add_to_bottom(card: Variant) -> void:
    add(card)

# 移除指定卡。返回是否成功。
func remove(card: Variant) -> bool:
    return _cards.erase(card)

# 获取所有卡(副本)。
func get_all() -> Array:
    return _cards.duplicate()

# 是否为空。
func is_empty() -> bool:
    return _cards.is_empty()

# 牌数。
func size() -> int:
    return _cards.size()

# 洗牌(原地)。
func shuffle() -> void:
    _cards.shuffle()

# 把本堆全部洗入 other 堆(本堆清空)。
func shuffle_into(other: Pile) -> void:
    var cards := _cards.duplicate()
    cards.shuffle()
    for c in cards:
        other.add(c)
    _cards.clear()

# 直接设置卡牌列表(测试用)。
func set_cards(cards: Array) -> void:
    _cards = cards.duplicate()

# 按名字查找(不移除)。返回首张匹配或 null。
func find_by_name(card_name: String) -> Variant:
    for c in _cards:
        if c.get_name() == card_name:
            return c
    return null

# 按名字+数量查找(不移除)。返回列表。
func find_by_name_qty(card_name: String, quantity: int) -> Array:
    var result: Array = []
    for c in _cards:
        if c.get_name() == card_name:
            result.append(c)
            if result.size() >= quantity:
                break
    return result
```

**说明**:
- 顶在数组末尾(`pop_back` 抓顶,`push_front` 加底,与 DrawFlow.md `pile.draw()`/`pile.置于底()` 对齐)
- `add` 默认加到底部(符合"弃牌堆/手牌区加牌"语义)
- 卡牌类型用 `Variant` 规避循环依赖(同 MapBlock.addPlayer)
- `find_by_name`/`find_by_name_qty` 支持 `discard(name, quantity=, position=)` 重载

**此设计需用户确认。**

### 4.5 Game 对象最小骨架(提议)

```gdscript
class_name Game extends RefCounted

# 全局牌堆
var _monster_deck: Pile = Pile.new()
var _monster_discard: Pile = Pile.new()
var _scavenge_piles: Dictionary = {}  # {"red": Pile, "green": Pile, "blue": Pile}
var _scavenge_discard: Pile = Pile.new()  # 不分色单一堆(§3.5)

func _init() -> void:
    for color in ["red", "green", "blue"]:
        _scavenge_piles[color] = Pile.new()

# 按颜色获取拾荒牌堆。
# 规则引用: 待设计方法.md §5
func getScavengePile(color: String) -> Variant:
    return _scavenge_piles.get(color, null)

# 怪物牌堆。
func get_monster_deck() -> Pile:
    return _monster_deck

# 怪物弃牌堆。
func get_monster_discard() -> Pile:
    return _monster_discard

# 拾荒弃牌堆(不分色)。
func get_scavenge_discard() -> Pile:
    return _scavenge_discard

# 卡牌移出游戏(本轮 stub:仅日志)。
# 真实逻辑:从所有区域移除,加入"移出游戏"区。
# 规则引用: 待设计方法.md §5
func removeCard(card: Variant) -> void:
    push_warning("[game.removeCard stub] card=%s" % str(card))

# 所有玩家是否死亡(本轮 stub)。
# 真实逻辑:遍历所有 Player 检查 _hp <= 0。
# 规则引用: 待设计方法.md §5
func allPlayersDead() -> bool:
    push_warning("[game.allPlayersDead stub] returns false")
    return false

# 结束游戏(本轮 stub)。
# 真实逻辑:设置游戏状态,触发结束流程。
# 规则引用: 待设计方法.md §5
func gameOver(result: String) -> void:
    push_warning("[game.gameOver stub] result=%s" % result)

# 测试用:直接设置怪物牌堆。
func set_monster_deck(cards: Array) -> void:
    _monster_deck.set_cards(cards)

# 测试用:直接设置拾荒牌堆。
func set_scavenge_pile(color: String, cards: Array) -> void:
    if _scavenge_piles.has(color):
        (_scavenge_piles[color] as Pile).set_cards(cards)
```

**说明**:
- 持有 5 类全局牌堆(怪物牌堆/怪物弃牌堆/3 色拾荒牌堆/单一拾荒弃牌堆)
- 提供 `getScavengePile(color)`/`removeCard`/`allPlayersDead`/`gameOver` 接口(后 3 个 stub)
- 不持有玩家列表(后续轮次扩展)
- 不实现回合流程/任务系统/地图(后续轮次)
- Player 通过 `set_game(game)` 注入引用

**此设计需用户确认。**

### 4.6 Player 卡牌区域与 game 引用

```gdscript
# Player 类追加成员
var _game: Game = null  # game 对象引用,通过 set_game 注入
var _hand: Pile = Pile.new()  # 手牌区
var _equipment: Array = []  # 装备区 Array[Card]
var _monster_zone: Array = []  # 怪物区 Array[MonsterCard]
var _game_deck: Pile = Pile.new()  # 游戏牌堆
var _game_discard: Pile = Pile.new()  # 游戏牌弃牌堆
var _equipment_capacity: int = 5  # 装备栏格数上限(默认 5,可被技能改变)

# 注入 game 对象(测试与后续 game 初始化流程用)
func set_game(game: Game) -> void:
    _game = game

# 按名字获取牌堆
# 规则引用: 待设计方法.md §1.6
func getPile(name: String) -> Variant:
    match name:
        "游戏牌堆":
            return _game_deck
        "游戏牌弃牌堆":
            return _game_discard
        "手牌区":
            return _hand
        "怪物区":
            return _monster_zone  # 注意:怪物区是 Array 不是 Pile
        _:
            return null

# 获取玩家所有游戏牌(手牌+装备+牌堆+弃牌堆)
# 规则引用: 待设计方法.md §1.6
func getAllGameCards() -> Array:
    var cards: Array = []
    cards.append_array(_hand.get_all())
    cards.append_array(_equipment)
    cards.append_array(_game_deck.get_all())
    cards.append_array(_game_discard.get_all())
    return cards

# 按来源获取玩家牌
# 规则引用: 待设计方法.md §1.6
func getCards(source: String = "") -> Array:
    var all: Array = []
    all.append_array(_hand.get_all())
    all.append_array(_equipment)
    var result: Array = []
    for c in all:
        if source == "" or c.get_source() == source:
            result.append(c)
    return result
```

**说明**:
- `getCards(source=)` 当前仅搜手牌+装备区(死亡流程 3c 拾荒卡查询用)。后续轮次可扩展到牌堆+弃牌堆
- 装备栏格数默认 5(C_gameSetup 未明确,后续轮次确认)
- `getPile` 返回 Variant(怪物区是 Array,其他是 Pile)

**此设计需用户确认。**

### 4.7 discard / removeCard 的 target 解析

设计文档 `discard(target, position, quantity, type)` 的 target 多态。GDScript 不支持重载,用类型判断:

```gdscript
func discard(target: Variant, position: String = "", quantity: int = 1, type: bool = false) -> void:
    var cards_to_discard: Array = []
    
    if type:
        # target 是类型字符串(如 "食物"),按类型弃置
        var all_cards := _get_cards_in_position(position)
        for c in all_cards:
            if c.get_type() == String(target):
                cards_to_discard.append(c)
    elif target is Array:
        # 牌列表
        cards_to_discard = target.duplicate()
    elif target is Object and target is Card:
        # 单张牌对象
        cards_to_discard.append(target)
    else:
        # name 字符串:按名字+位置+数量查找
        cards_to_discard = _find_cards_by_name(String(target), position, quantity)
    
    if cards_to_discard.is_empty():
        return
    
    # ... 后续走 3 节点钩子链
```

**注意**:
- 设计文档的 `discard(type, type=true)` 第二个 `type` 是参数名(布尔)。GDScript 参数名 `type` 与变量类型易混淆,但保留以匹配设计文档
- `_get_cards_in_position(position)`:position 为空时搜手牌+装备区;否则按 position 匹配("手牌区"/"装备区")
- `_find_cards_by_name(name, position, quantity)`:从对应位置找前 quantity 张匹配名字的牌

### 4.8 怪物卡实体化(drawMonster 节点 d)

DrawFlow.md 节点 d "实体化:设置纠缠对象、初始化生命值":

```gdscript
# 在 drawMonster 内部循环中,节点 c 之后:
# d. 实体化
card.set纠缠对象(player)  # card._tangle_target = player
card.set_hp(card.get_max_hp())  # 当前生命值 = 最大生命值

# e. 加入怪物区
player._monster_zone.append(card)
player.trigger("怪物卡进入求生者怪物区时", event)

# f. 怪物卡进入求生者怪物区后
player.trigger("怪物卡进入求生者怪物区后", event)
```

**MonsterCard 实体化方法**:
```gdscript
class_name MonsterCard extends Card

var _tangle_target: Variant = null  # 纠缠对象(Player)
var _hp: int = 0  # 当前生命值

func set_tangle_target(target: Variant) -> void:
    _tangle_target = target

func get_tangle_target() -> Variant:
    return _tangle_target

# 当前生命值(MonsterCard 重写 Entity.get_hp)
func get_hp() -> int:
    return _hp

func set_hp(hp: int) -> void:
    _hp = hp

# 最大生命值(从 data 读取)
func get_max_hp() -> int:
    return _data.max_hp

# 攻击伤害
func get_atk() -> int:
    return _data.atk

# 射程
func get_range() -> String:
    return _data.range

# 怪物级别
func get_level() -> String:
    return _data.level

# 怪物类型
func get_monster_type() -> String:
    return _data.monster_type

func is_monster() -> bool:
    return true

# reduce_hp 重写(Entity 要求)
func reduce_hp(num: int) -> void:
    if num <= 0:
        return
    _hp -= num

# _on_death 重写为 monsterDeath(本轮仍 stub)
func _on_death(source: Variant) -> void:
    monsterDeath(source)

# monsterDeath 本轮 stub
func monsterDeath(source: Variant) -> void:
    push_warning("monsterDeath stub called on %s. source=%s" % [get_name(), str(source)])
```

**说明**:
- MonsterCard 是 Entity 子类,可被 `damage(...)` 攻击(03 轮 DamageFlow 已实现)
- 死亡时调用 `monsterDeath`(本轮 stub,iteration_07 实现真实流程)
- 怪物卡进入怪物区时已实体化(节点 d),`get_hp()` 返回当前生命值

### 4.9 卡牌 source 字段

`CardData.source` 取值:
- `"scavenge"` — 拾荒卡
- `"game"` — 求生者游戏牌
- `"monster"` — 怪物卡

```gdscript
# Card 基类
func get_source() -> String:
    return _data.source
```

`discard` 时按 `card.get_source()` 分派弃牌堆(§3.4)。

### 4.10 目录结构(本轮后)

```
scripts/system/
├── entity.gd              # 01 轮(无改动)
├── event.gd               # 01 轮(无改动)
├── skill.gd               # 01 轮(无改动)
├── role_card.gd           # 02 轮(无改动)
├── dice.gd                # 05 轮(无改动)
├── map_block.gd           # 05 轮(无改动)
├── player.gd              # 02-05 轮 + 追加卡牌区域 + draw*/discard/removeCard 真实逻辑
├── card_data.gd           # 06 轮新增
├── scavenge_card_data.gd  # 06 轮新增
├── survivor_game_card_data.gd  # 06 轮新增
├── monster_card_data.gd   # 06 轮新增
├── card.gd                # 06 轮新增
├── item_card.gd           # 06 轮新增
├── scavenge_card.gd       # 06 轮新增
├── survivor_game_card.gd  # 06 轮新增
├── monster_card.gd        # 06 轮新增
├── pile.gd                # 06 轮新增
└── game.gd                # 06 轮新增
```

---

## 5. 实施任务清单

1. [ ] 与用户确认 §4.1(类层级)、§4.2(API 命名)、§4.4(Pile)、§4.5(Game)、§4.6(Player 区域)
2. [ ] 修订 `GameDesignDocus/GameSystem/DiscardFlow.md`:按色分派 → 不分色单一堆(§3.5)
3. [ ] 在 `GameDesignDocus/待设计方法.md` §9.20 登记拾荒弃牌堆不分色解决;§10.4-10.8 登记 5 个已定义方法实现状态
4. [ ] 新建 `scripts/system/card_data.gd`(§4.1)
5. [ ] 新建 `scripts/system/scavenge_card_data.gd`
6. [ ] 新建 `scripts/system/survivor_game_card_data.gd`
7. [ ] 新建 `scripts/system/monster_card_data.gd`
8. [ ] 新建 `scripts/system/card.gd`(§4.1, §4.2, §4.3, §4.9)
9. [ ] 新建 `scripts/system/item_card.gd`(填充物系统)
10. [ ] 新建 `scripts/system/scavenge_card.gd`
11. [ ] 新建 `scripts/system/survivor_game_card.gd`
12. [ ] 新建 `scripts/system/monster_card.gd`(§4.8)
13. [ ] 新建 `scripts/system/pile.gd`(§4.4)
14. [ ] 新建 `scripts/system/game.gd`(§4.5)
15. [ ] 修改 `scripts/system/player.gd`:
    - 新增卡牌区域成员(§4.6)
    - 新增 `set_game`/`getPile`/`getAllGameCards`/`getCards`
    - 实现 `draw(n)` 真实逻辑(§3.3)
    - 实现 `drawScavenge(n, pile)` 真实逻辑
    - 实现 `drawMonster(num)` 真实逻辑(替换 05 轮 stub)
    - 实现 `discard(target, position, quantity, type)` 真实逻辑(§3.4, §4.7)
    - 实现 `removeCard(target, position, quantity)` 真实逻辑
16. [ ] 新建 `tests/unit/test_card.gd`(§6.1)
17. [ ] 新建 `tests/unit/test_pile.gd`(§6.2)
18. [ ] 新建 `tests/unit/test_game.gd`(§6.3)
19. [ ] 新建 `tests/unit/test_draw_flow.gd`(§6.4)
20. [ ] 新建 `tests/unit/test_discard_flow.gd`(§6.5)
21. [ ] 运行 GUT 测试,全部通过
22. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI(用户手动验证)
23. [ ] 更新 `docs/system-classes.md` 与 `docs/data-layer.md`(本轮新增类)
24. [ ] 更新 `docs/API_CONTRACTS.md`(5 个已定义方法状态变更)

---

## 6. 验收标准(测试用例)

测试文件 5 个,均继承 `GutTest`。

### 6.1 test_card.gd — Card 实体类

**CardData 子类构造**:
- `test_scavenge_card_data_fields`: 构造 ScavengeCardData("弹药(少量)", color="blue", category="战备", type="行动", value=2, ...),断言各字段
- `test_survivor_game_card_data_fields`: 构造 SurvivorGameCardData("手枪", type="装备", filler_max=4, ...),断言各字段
- `test_monster_card_data_fields`: 构造 MonsterCardData("僵尸狗", level="普通", monster_type="僵尸", max_hp=5, atk=4, range="无", ...),断言各字段

**Card 子类实例化**:
- `test_scavenge_card_get_name`: ScavengeCard 实例 `get_name()` 返回 data.display_name
- `test_scavenge_card_get_color`: 返回 data.color
- `test_scavenge_card_get_source`: 返回 "scavenge"
- `test_monster_card_get_max_hp`: 返回 data.max_hp
- `test_monster_card_set_tangle_target`: `set_tangle_target(player)` → `get_tangle_target()` == player
- `test_monster_card_set_hp`: `set_hp(5)` → `get_hp()` == 5

**填充物系统(ItemCard)**:
- `test_item_card_init_filler_count`: filler_max=4, filler_init=4 → `get_filler_count()` == 4
- `test_item_card_add_filler`: filler_count=2, `add_filler(2, "弹药")` → count=4
- `test_item_card_add_filler_capped_at_max`: filler_count=3, filler_max=4, `add_filler(5, "弹药")` → count=4
- `test_item_card_add_filler_wrong_type`: filler_type="弹药", `add_filler(2, "燃料")` → count 不变(类型不匹配)
- `test_item_card_add_filler_default_type`: filler_type="弹药", `add_filler(2)` → count+2(type 默认用卡自身)
- `test_item_card_add_filler_to_max`: `add_filler_to_max()` → count == filler_max
- `test_item_card_refill_filler`: count=1, `refill_filler()` → count == filler_max
- `test_item_card_change_filler_type`: filler_type="弹药", `change_filler_type("空尖弹")` → `get_filler_type()` == "空尖弹"
- `test_item_card_no_filler`: filler_max=0(无填充物装备), `add_filler(2, "弹药")` → count 不变

**Card.get_all_skills**:
- `test_card_get_all_skills_returns_data_skill`: data.skill != null → `get_all_skills()` 含 data.skill
- `test_card_get_all_skills_empty_when_no_skill`: data.skill == null → `get_all_skills()` 为空

**MonsterCard 继承 Entity**:
- `test_monster_card_is_monster`: `is_monster()` == true
- `test_monster_card_reduce_hp`: `set_hp(5)`, `reduce_hp(2)` → `get_hp()` == 3
- `test_monster_card_damage_triggers_death_stub`: `set_hp(1)`, `damage(2, null)` → `monsterDeath` stub 被调用(push_warning 验证)

### 6.2 test_pile.gd — Pile 牌堆

- `test_pile_empty_by_default`: `is_empty()` == true, `size()` == 0
- `test_pile_add_and_size`: `add(c1)`, `add(c2)` → `size()` == 2
- `test_pile_draw_returns_top`: 加 c1 再加 c2(顶),`draw()` == c2
- `test_pile_draw_empty_returns_null`: `draw()` == null
- `test_pile_peek_top_n`: 加 3 张,`peek_top(2)` 返回顶 2 张(不移除)
- `test_pile_peek_top_more_than_size`: 加 2 张,`peek_top(5)` 返回 2 张
- `test_pile_remove`: 加 c1/c2,`remove(c1)` → `size()` == 1
- `test_pile_remove_nonexistent`: `remove(c1)`(未加)→ 返回 false,`size()` 不变
- `test_pile_get_all_returns_copy`: 加 2 张,`get_all()` 修改后不影响原堆
- `test_pile_shuffle_keeps_size`: 加 3 张,`shuffle()` → `size()` == 3
- `test_pile_shuffle_into`: pile A 加 3 张,pile B 加 2 张,`A.shuffle_into(B)` → A.size()==0, B.size()==5
- `test_pile_find_by_name`: 加"手枪"/"防火头盔",`find_by_name("手枪")` 返回手枪卡
- `test_pile_find_by_name_not_found`: `find_by_name("不存在")` 返回 null
- `test_pile_find_by_name_qty`: 加 3 张"手枪",`find_by_name_qty("手枪", 2)` 返回 2 张
- `test_pile_set_cards_for_testing`: `set_cards([c1, c2])` → `size()` == 2(测试注入用)
- `test_pile_add_to_top_vs_bottom`: `add(c1)`(底),`add_to_top(c2)`(顶),`draw()` == c2

### 6.3 test_game.gd — Game 对象

- `test_game_init_creates_3_scavenge_piles`: `getScavengePile("red"/"green"/"blue")` 均非 null
- `test_game_get_scavenge_pile_invalid_color`: `getScavengePile("yellow")` == null
- `test_game_monster_deck_default_empty`: `get_monster_deck().is_empty()` == true
- `test_game_monster_discard_default_empty`: `get_monster_discard().is_empty()` == true
- `test_game_scavenge_discard_default_empty`: `get_scavenge_discard().is_empty()` == true
- `test_game_set_monster_deck_for_testing`: `set_monster_deck([c1, c2])` → `get_monster_deck().size()` == 2
- `test_game_set_scavenge_pile_for_testing`: `set_scavenge_pile("red", [c1, c2])` → `getScavengePile("red").size()` == 2
- `test_game_remove_card_stub_no_crash`: `removeCard(card)` 不崩溃
- `test_game_all_players_dead_stub_returns_false`: `allPlayersDead()` == false
- `test_game_game_over_stub_no_crash`: `gameOver("lose")` 不崩溃

### 6.4 test_draw_flow.gd — DrawFlow 三个方法

**player.draw(n)**:
- `test_draw_4_cards_from_game_deck`: 游戏牌堆 4 张,`draw(4)` → 手牌区 4 张,牌堆 0 张
- `test_draw_triggers_抓取游戏牌前`: 注入 spy 技能到 trigger "抓取游戏牌前",`draw(1)` → spy 被调用
- `test_draw_cancel_at_抓取游戏牌前`: spy 在"抓取游戏牌前"调 `event.cancel()` → 不抓牌
- `test_draw_triggers_抓取游戏牌时`: 注入 spy 到"抓取游戏牌时",`draw(1)` → spy 被调用
- `test_draw_modify_num_at_抓取游戏牌时`: spy 在"抓取游戏牌时"设 `event.num = 2`,原 `draw(1)` → 抓 2 张
- `test_draw_cancel_at_抓取游戏牌时`: spy 在"抓取游戏牌时" cancel → 不抓牌
- `test_draw_triggers_抓取游戏牌后`: `draw(1)` 后"抓取游戏牌后"被触发
- `test_draw_empty_deck_calls_playerDeath`: 空牌堆,`draw(1)` → `playerDeath(NULL)` 被调用(stub push_warning 验证)
- `test_draw_zero_or_negative_no_op`: `draw(0)` / `draw(-1)` → 无变化
- `test_draw_partial_then_empty`: 牌堆 1 张,`draw(3)` → 抓 1 张后牌堆空,触发 playerDeath

**player.drawScavenge(n, pile)**:
- `test_draw_scavenge_2_cards`: 拾荒牌堆 2 张,`drawScavenge(2, pile)` → 手牌区 2 张,pile 0 张
- `test_draw_scavenge_triggers_抓取拾荒牌前`: spy 验证
- `test_draw_scavenge_cancel_at_前`: 手电筒场景:cancel → 不抓牌
- `test_draw_scavenge_triggers_抓取拾荒牌时_each_card`: 抓 2 张,"时" 触发 2 次
- `test_draw_scavenge_triggers_抓取拾荒牌后`: 整体触发 1 次
- `test_draw_scavenge_empty_pile_stops`: pile 1 张,`drawScavenge(3, pile)` → 抓 1 张后停止(不重洗,不 playerDeath)
- `test_draw_scavenge_zero_no_op`: `drawScavenge(0, pile)` → 无变化
- `test_draw_scavenge_event_card_set`: "时" 阶段 `event.card` 是当前抓的牌

**player.drawMonster(num)**:
- `test_draw_monster_1_card`: 怪物牌堆 1 张,`drawMonster(1)` → 怪物区 1 张,牌堆 0 张
- `test_draw_monster_triggers_6_nodes_per_card`: 注入 spy 验证 6 节点(抓取怪物卡前/时/进入前/进入时/进入后 + 抓取怪物卡后)均被触发
- `test_draw_monster_cancel_at_抓取怪物卡前`: 梯子场景:cancel → 不抓怪
- `test_draw_monster_empty_deck_reshuffles_discard`: 牌堆空,弃牌堆 1 张,`drawMonster(1)` → 重洗弃牌堆成新牌堆,抓 1 张
- `test_draw_monster_empty_deck_and_empty_discard_calls_gameOver`: 牌堆+弃牌堆都空 → `game.gameOver("lose")` 被调用
- `test_draw_monster_entity_sets_tangle_target`: `drawMonster(1)` → 抓到的 MonsterCard `get_tangle_target()` == player
- `test_draw_monster_entity_sets_hp`: data max_hp=5,`drawMonster(1)` → MonsterCard `get_hp()` == 5
- `test_draw_monster_zero_no_op`: `drawMonster(0)` → 无变化
- `test_draw_monster_event_target_set`: "时" 阶段 `event.target` 是当前抓的怪物卡

### 6.5 test_discard_flow.gd — DiscardFlow 两个方法

**player.discard(target, ...)**:
- `test_discard_single_card`: 手牌 1 张,`discard(card)` → 手牌 0 张,游戏牌弃牌堆 1 张
- `test_discard_card_list`: 手牌 3 张,`discard([c1, c2])` → 手牌 1 张,弃牌堆 2 张
- `test_discard_by_name`: 手牌含"手枪",`discard("手枪")` → "手枪"进弃牌堆
- `test_discard_by_name_with_quantity`: 手牌含 3 张"手枪",`discard("手枪", quantity=2)` → 2 张进弃牌堆
- `test_discard_by_name_with_position`: 装备区有"防火头盔",`discard("防火头盔", position="装备区")` → 装备区移除,进弃牌堆
- `test_discard_by_type`: 手牌含 2 张"行动"牌+1 张"装备"牌,`discard("行动", type=true)` → 2 张行动牌进弃牌堆
- `test_discard_scavenge_card_goes_to_scavenge_discard`: 拾荒卡(手牌),`discard(card)` → 进 game.scavenge_discard(单一堆),不进游戏牌弃牌堆
- `test_discard_monster_card_goes_to_monster_discard`: (本轮怪物区 stub,此项可跳过或用 MonsterCard 手动加入手牌测试)
- `test_discard_triggers_弃置牌前`: spy 验证
- `test_discard_cancel_at_弃置牌前`: cancel → 不弃牌
- `test_discard_triggers_弃置牌时_each_card`: 弃 2 张,"时" 触发 2 次
- `test_discard_triggers_弃置牌后`: 整体触发 1 次
- `test_discard_empty_list_no_op`: `discard([])` → 无变化
- `test_discard_nonexistent_name_no_op`: `discard("不存在")` → 无变化

**player.removeCard(target, ...)**:
- `test_remove_card_single`: 手牌 1 张,`removeCard(card)` → 手牌 0 张,弃牌堆 0 张(销毁不进弃牌堆)
- `test_remove_card_calls_game_remove_card`: spy 验证 `game.removeCard(card)` 被调用
- `test_remove_card_by_name`: 手牌含"手枪",`removeCard("手枪")` → 手牌移除,不进弃牌堆
- `test_remove_card_triggers_销毁牌前`: spy 验证
- `test_remove_card_cancel_at_销毁牌前`: cancel → 不销毁
- `test_remove_card_triggers_销毁牌时_each_card`: 销毁 2 张,"时" 触发 2 次
- `test_remove_card_triggers_销毁牌后`: 整体触发 1 次

### 6.6 集成测试(可选,本轮可省)

- `test_player_get_all_game_cards`: 手牌 2 + 装备 1 + 牌堆 3 + 弃牌堆 1 → `getAllGameCards()` 长度 7
- `test_player_get_cards_by_source`: 手牌含 2 scavenge + 1 game → `getCards("scavenge")` 长度 2

---

## 7. 风险与待澄清

| 项 | 说明 | 处理 |
|----|------|------|
| 拾荒弃牌堆分色冲突 | C_gameSetup vs DiscardFlow | §3.5 用户确认不分色,修订 DiscardFlow.md |
| `discard(type, type=true)` 参数名 type 易混淆 | GDScript 参数名 | §4.7 保留以匹配设计文档,加注释 |
| 装备栏格数默认值 | C_gameSetup 未明确 | §4.6 默认 5,后续轮次确认 |
| `getCards(source=)` 搜索范围 | 设计文档未明确是否含牌堆/弃牌堆 | §4.6 仅搜手牌+装备区,后续轮次扩展 |
| MonsterCard 进入手牌 | drawMonster 实体化后 MonsterCard 在怪物区,不应入手牌 | 测试用例不构造此场景 |
| 卡牌技能动态挂载 | 蓝色装备卡等需要 trigger 卡牌进出装备区 | §4.3 本轮不接入,留扩展点 |
| 装备/卸下流程未实现 | `player.装备(card)` 待定义方法 | 本轮不实现,留 iteration_07+ |
| 手牌上限 10 | C_gameSetup 开局说明 | 本轮不实现,上层校验 |
| 怪物区顺序 | I_monsterAction "按进入先后顺序行动" | `_monster_zone` 用 Array,append 到末尾,先入先行动 |
| ItemCard 中间类是否过度设计 | 4 层继承 | §4.1 提议,用户确认。若过度可扁平化 |
| SurvivorGameCard 无额外字段 | 与 ItemCard 字段相同 | §4.1 提议保留独立子类(类型清晰),用户确认 |
| §9.14 card.在玩家装备区内 | 属性 vs 方法 | 用户已确认本轮不解决(stub) |
| 拾荒卡"数值"字段 | green/red/blue 卡有"数值"(弹药数/恢复量等),仅描述用 | 数据层保留,运行时不用 |
| `game.gameOver` 后续流程是否中断 | stub 不中断当前流程 | 后续轮次实现真实逻辑时明确 |

---

## 8. 不做的事

- 不实现 `playerDeath`/`monsterDeath` 真实逻辑(iteration_07)
- 不实现 `game.allPlayersDead`/`game.gameOver` 真实逻辑(stub)
- 不实现装备/卸下装备流程(`player.装备(card)` 等)
- 不实现 §9.14 `card.在玩家装备区内`(stub)
- 不实现手牌上限校验
- 不实现卡牌结算区
- 不实现卡牌技能动态挂载(本轮 Card.get_all_skills 仅返回 data.skill)
- 不实现拾荒卡/怪物卡/求生者游戏牌数据落地到 `data/`(代码内联)
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不修改 01-05 轮现有类的已有方法签名(仅 Player 追加新成员与新方法)
- 不解决 §9.x 其他歧义(除非本轮实现受阻)
- 不重构 GameScene(仍只显示 `RoomState.snapshot()`)

---

## 9. 与现有迭代的衔接

### 9.1 替换的 stub

- `player.drawMonster(num)` — 05 轮 stub,本轮替换为真实逻辑
- `player.playerDeath(source)` — 仍 stub(iteration_07 实现)
- `Entity._on_death` — 不变(MonsterCard 重写为 monsterDeath stub)
- `player._game_log_stub` — 仍 stub(game 对象未提供 log)

### 9.2 后续轮次依赖

- **iteration_07(DeathFlow)**: 实现 playerDeath/monsterDeath 真实逻辑,依赖本轮 Card/Pile/Game/Player 卡牌区域
- **iteration_08+(装备/卸下)**: 实现装备流程,接入 `卡牌进入装备区时`/`离开装备区时` 触发节点
- **iteration_09+(回合流程)**: 实现回合阶段/行动次数,接入手牌上限校验
- **数据层落地轮次**: 拾荒卡/怪物卡/求生者游戏牌落地到 `data/`

### 9.3 文档更新清单

实施完成后需更新:
- `GameDesignDocus/GameSystem/DiscardFlow.md` — 拾荒弃牌堆不分色(§3.5)
- `GameDesignDocus/待设计方法.md` — §9.20 登记、§10.x 实现状态、§1.6/§5 标注已实现
- `GameDesignDocus/已设计方法.md` — 5 个方法标注"已实现"
- `docs/system-classes.md` — 新增 Card/ItemCard/ScavengeCard/SurvivorGameCard/MonsterCard/Pile/Game 类文档
- `docs/data-layer.md` — 新增 CardData/ScavengeCardData/SurvivorGameCardData/MonsterCardData 数据类文档
- `docs/API_CONTRACTS.md` — 5 个已定义方法状态从"已定义"改为"已实现"
- `spec/README.md` — 添加 06 行
- `spec/roadmap.md` — 标记 06 完成
