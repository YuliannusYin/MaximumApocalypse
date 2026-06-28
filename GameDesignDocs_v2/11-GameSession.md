# 11 - GameSession（游戏会话总控）

> MA 的游戏会话总控：负责初始化所有子系统、协调子系统间交互、胜负判定、全局状态管理。
> GameSession 是场景根节点（每局新建，状态干净），持有所有子系统（MapGrid / 各牌堆 / Survivor 列表 / TurnManager / SkillExecutor）。
> 本文档只定义基类与方法签名，不含具体回合流程（见 12-TurnManager.md，待编写）与技能调度实现。
> 应用 v1 决策：D8（死亡后卡牌按来源处理）、D13（MVP 范围）、D16（怪物标记上限）、D17（初始抓怪按座次）、D18（任务燃料机制）、D19（首领卡机制）、D20（回合限制）。

---

## 1. 设计原则

- **场景根节点**：GameSession 继承 Node，每局游戏新建实例作为场景根节点。状态自然干净，无需 reset 逻辑（ponytail 风格，避免 autoload 单例的状态残留问题）。
- **GameSession 持有所有子系统**：MapGrid / ScavengerDeckStack / ScavengerDiscardPile / MonsterDeck / MonsterDiscardPile / Survivor 列表 / TurnManager / SkillExecutor 均作为 GameSession 的子节点或字段存在，集中管理生命周期（避免全局单例泛滥）。
- **协调者而非执行者**：GameSession 负责子系统初始化、轮转协调、胜负判定；具体回合流程委托给 TurnManager，技能调度委托给 SkillExecutor，地图操作委托给 MapGrid，牌堆操作委托给各牌堆类。
- **引用已有文档不重复**：初始化流程引用 10-Deck.md 第 9 节，胜负条件引用 08-MissionCard.md 第 9 节，地块填充引用 09-MapBlock.md 第 8 节。
- **信号驱动 UI 通知**：GameSession 发出 game 级信号（game_started / game_ended / player_changed 等），UI 层监听信号更新显示。细粒度信号（卡牌抓取 / 地块翻面等）由各自类发出。

---

## 2. GameSession 类定义

```text
class_name GameSession extends Node

# === 任务与全局状态 ===
var current_mission: MissionCardData           # 当前任务卡数据
var game_phase: GamePhase = GamePhase.SETUP    # 当前游戏阶段
var turn_count: int = 0                        # 当前回合数（从 1 开始）
var current_player_index: int = 0              # 当前玩家索引（survivors 数组下标）
var is_game_over: bool = false                 # 游戏是否结束
var game_result: GameResult = GameResult.DRAW  # 游戏结果（结束时设置）

# === 子系统持有 ===
var map_grid: MapGrid                          # 地图网格（Node2D 子节点）
var scavenger_deck_stack: ScavengerDeckStack   # 三色拾荒牌堆
var scavenger_discard_pile: ScavengerDiscardPile  # 拾荒弃牌堆（全局 1 个）
var monster_deck: MonsterDeck                  # 怪物牌库
var monster_discard_pile: MonsterDiscardPile   # 怪物弃牌堆（全局 1 个）
var survivors: Array[Survivor] = []            # 求生者列表（按座次顺序）
var turn_manager: TurnManager                  # 回合管理器（子节点）
var skill_executor: SkillExecutor              # 技能调度器（子节点）

# === 信号（UI 通知） ===
signal game_started(mission_data: MissionCardData)
signal game_ended(result: GameResult)
signal player_changed(current_player: Survivor)
signal turn_started(player: Survivor, turn_count: int)
signal turn_ended(player: Survivor, turn_count: int)
signal phase_changed(new_phase: GamePhase)
signal monster_token_count_changed(total: int, limit: int)
signal player_killed(survivor: Survivor)

# === 主流程 ===

# 开始新游戏（入口方法，由 UI 层调用）
# mission_data: 玩家选择的任务卡
# selected_characters: 玩家选择的角色卡列表（按座次顺序）
func start_new_game(mission_data: MissionCardData, selected_characters: Array[CharacterCardData]) -> void:
    current_mission = mission_data
    game_phase = GamePhase.SETUP
    _init_subsystems(selected_characters)
    game_phase = GamePhase.PLAYING
    phase_changed.emit(game_phase)
    game_started.emit(mission_data)
    _start_first_turn()

# === 初始化子系统 ===

func _init_subsystems(selected_characters: Array[CharacterCardData]) -> void:
    _init_map()                    # 1. 地图填充（09-MapBlock.md 第 8 节）
    _init_scavenger_decks()        # 2. 拾荒牌堆（10-Deck.md 第 9 节步骤 3-4）
    _init_monster_deck()           # 3. 怪物牌库（10-Deck.md 第 9 节步骤 5）
    _init_survivors(selected_characters)  # 4. 求生者（10-Deck.md 第 9 节步骤 6）
    _init_scientist_equipment()    # 5. 科学家装备（任务 3/8/9，D102 / D111）
    _init_initial_monsters()       # 6. 初始抓怪（10-Deck.md 第 9 节步骤 7，D17）
    _init_boss()                   # 7. 首领卡处理（08-MissionCard.md boss_config）
    _init_target_markers()         # 8. 目标标记放置（08-MissionCard.md target_markers）
    _init_block_scavenger_piles()  # 9. 地块拾荒牌堆初始化（09-MapBlock.md 第 9 节）
    _init_managers()               # 10. TurnManager / SkillExecutor

# 1. 地图填充（引用 09-MapBlock.md 第 8 节）
func _init_map() -> void:
    map_grid = MapGrid.new()
    add_child(map_grid)
    var instance_pool = MapGrid.build_instance_pool()  # 38 实例池
    # 调用填充算法遍历 current_mission.map_layout
    # 按 0/1/2/3 编码填充地块到 map_grid（见 09-MapBlock.md 第 8.3 节）
    # 起始地块 is_revealed = true（若 starting_block 匹配）

# 2. 拾荒牌堆（引用 10-Deck.md 第 9 节步骤 3-4）
func _init_scavenger_decks() -> void:
    scavenger_deck_stack = ScavengerDeckStack.new()
    scavenger_deck_stack.init_from_mission(current_mission)
    scavenger_discard_pile = ScavengerDiscardPile.new()

# 3. 怪物牌库（引用 10-Deck.md 第 9 节步骤 5）
func _init_monster_deck() -> void:
    monster_deck = MonsterDeck.new()
    monster_deck.init_from_monster_pack(current_mission.monster_pack)
    monster_discard_pile = MonsterDiscardPile.new()

# 4. 求生者（引用 10-Deck.md 第 9 节步骤 6）
func _init_survivors(selected_characters: Array[CharacterCardData]) -> void:
    for character_data in selected_characters:
        var survivor = Survivor.new()
        survivor.data = character_data
        # 实例化求生者牌库
        for card_id in character_data.survivor_deck_card_ids:
            var card_data = CardRegistry.get_card_data(card_id)
            var instance = CardInstance.new()
            instance.data = card_data
            instance.source = CardSource.SURVIVOR_DECK
            instance.location = CardLocation.DECK
            survivor.deck.append(instance)
        DeckUtils.shuffle(survivor.deck)
        survivors.append(survivor)
        add_child(survivor)

# 5. 科学家装备（任务 3/8/9，D102 / D111）
# 科学家为任务专属装备，source = MISSION，不进拾荒牌堆
# 初始位置：第一个进行回合的玩家（survivors[0]）的装备区
func _init_scientist_equipment() -> void:
    var mission_scientists = [&"mission_3", &"mission_8", &"mission_9"]
    if not mission_scientists.has(current_mission.mission_id):
        return
    var scientist_data = CardRegistry.get_card_data(&"scientist")
    if scientist_data == null:
        push_error("GameSession: mission %s requires scientist card but not found" % current_mission.mission_id)
        return
    var first_player = survivors[0]
    var instance = CardInstance.new()
    instance.data = scientist_data
    instance.source = CardSource.MISSION
    instance.location = CardLocation.EQUIPMENT
    first_player.equip(instance)

# 6. 初始抓怪（引用 10-Deck.md 第 9 节步骤 7，D17）
func _init_initial_monsters() -> void:
    # 任务 11 例外：任务开始时不抓取怪物卡
    if current_mission.mission_id == &"mission_11":
        return
    # D17：按座次顺序依次执行
    for survivor in survivors:
        var card = monster_deck.draw()
        if card == null:
            DeckUtils.reshuffle_monster_discard(monster_deck, monster_discard_pile)
            card = monster_deck.draw()
        # 创建 Monster Node, engage(survivor)（见 05-MonsterCard.md）

# 6. 首领卡处理（引用 08-MissionCard.md boss_config）
func _init_boss() -> void:
    var boss_config = current_mission.boss_config
    if boss_config == null or boss_config.mechanic == BossMechanic.NONE:
        return  # 无首领
    # 根据 boss_config.mechanic 分类处理：
    # - 初始化时处理：SHUFFLE_BOTTOM / SHUFFLE_INTO_DECK / SHUFFLE_LOWER_HALF / SHUFFLE_PLUS_BOTTOM
    # - 运行时触发：TRIGGER_ON_BLOCK / TRIGGER_ON_REVEAL / TRIGGER_ON_MARKER（由 SkillExecutor 或地块事件处理，此处不处理）
    match boss_config.mechanic:
        BossMechanic.SHUFFLE_BOTTOM:
            # 抓 setup_cards 张牌 + 首领卡洗混放牌库底
            _shuffle_boss_to_bottom(boss_config)
        BossMechanic.SHUFFLE_INTO_DECK:
            # 首领卡洗入怪物牌库
            _shuffle_boss_into_deck(boss_config)
        BossMechanic.SHUFFLE_LOWER_HALF:
            # 首领卡洗入怪物牌库下半部
            _shuffle_boss_lower_half(boss_config)
        BossMechanic.SHUFFLE_PLUS_BOTTOM:
            # 随机洗入 + 牌库底额外 1 张（共 2 张首领卡）
            _shuffle_boss_plus_bottom(boss_config)
        # TRIGGER_ON_BLOCK / TRIGGER_ON_REVEAL / TRIGGER_ON_MARKER：运行时触发，此处不处理

# 7. 目标标记放置（引用 08-MissionCard.md target_markers）
func _init_target_markers() -> void:
    for marker_config in current_mission.target_markers:
        # 根据 marker_config.constraint_type 选择符合约束的地块
        var candidates = _find_valid_marker_positions(marker_config)
        var pos = candidates.pick_random()
        # 在地块上放置目标标记
        # 设置 initial_monster_tokens（如任务 9/11 的 3 个怪物标记）
        # 记录 on_first_arrival_skill 供后续触发
    # 验证所有目标标记已放置

# 8. 地块拾荒牌堆初始化（引用 09-MapBlock.md 第 9 节）
func _init_block_scavenger_piles() -> void:
    for block in map_grid.get_all_blocks():
        if block.get_scavenger_piles().is_empty():
            continue
        for color in block.get_scavenger_piles():
            # 默认每个地块的每种拾荒色堆可拾荒 1 次（具体张数待原版数据确认）
            block.scavenger_pile_remaining[color] = 1

# 9. TurnManager / SkillExecutor
func _init_managers() -> void:
    skill_executor = SkillExecutor.new()
    add_child(skill_executor)
    turn_manager = TurnManager.new()
    turn_manager.game_session = self
    add_child(turn_manager)

# === 回合管理 ===

func _start_first_turn() -> void:
    turn_count = 1
    current_player_index = 0
    var first_player = survivors[current_player_index]
    player_changed.emit(first_player)
    turn_manager.start_turn(first_player)

# 玩家回合结束（由 TurnManager 调用）
func on_player_turn_end() -> void:
    var current_player = survivors[current_player_index]
    turn_ended.emit(current_player, turn_count)
    _check_win_loss()
    if is_game_over:
        return
    _next_player()

func _next_player() -> void:
    current_player_index = (current_player_index + 1) % survivors.size()
    if current_player_index == 0:
        turn_count += 1
    var next_player = survivors[current_player_index]
    player_changed.emit(next_player)
    turn_manager.start_turn(next_player)

# === 胜负判定 ===

# 检查胜负条件（每回合结束 / 玩家死亡 / 怪物标记变化时调用）
func _check_win_loss() -> void:
    if is_game_over:
        return
    # 通用失败条件（引用 08-MissionCard.md 第 9 节）
    if _check_all_players_dead():
        end_game(GameResult.MONSTERS_WIN)
        return
    if _check_monster_token_limit():
        end_game(GameResult.MONSTERS_WIN)
        return
    # 任务特殊失败条件（见 08-MissionCard.md 第 9.2 节）
    if _check_mission_failure():
        end_game(GameResult.MONSTERS_WIN)
        return
    # 胜利条件（见 08-MissionCard.md 第 9.3 节）
    if _check_mission_victory():
        end_game(GameResult.PLAYERS_WIN)
        return

func _check_all_players_dead() -> bool:
    return survivors.all(func(s: Survivor) -> bool: return not s.is_alive)

func _check_monster_token_limit() -> bool:
    var total = map_grid.get_total_monster_tokens()
    monster_token_count_changed.emit(total, current_mission.monster_token_limit)
    return total >= current_mission.monster_token_limit

func _check_mission_failure() -> bool:
    # 任务特殊失败条件（见 08-MissionCard.md 第 9.2 节）
    # 任务 8：潜行检定失败且玩家没有日记本
    # 任务 5：炸弹爆炸（3 回合内未返回面包车，D20）
    # 任务 6：核辐射吞噬地块导致被困
    return false  # 待具体任务实现

func _check_mission_victory() -> bool:
    # 胜利条件（见 08-MissionCard.md 第 9.3 节）
    # 模式 1：收集燃料 + 回面包车逃离（任务 0/1/2/5/6/7/12）
    # 模式 2：到达特定地点（任务 3/4/8/9/11）
    # 模式 3：收集物资 + 回基地（任务 10）
    return false  # 待具体任务实现

# 玩家死亡处理（由 Survivor.die() 调用）
func on_player_killed(survivor: Survivor) -> void:
    player_killed.emit(survivor)
    # D8：死亡后卡牌按 source 处理
    # - SURVIVOR_DECK：随玩家死亡 remove() 移出游戏
    # - SCAVENGER_DECK：留在死亡地块，可被同地块玩家花 1 行动捡起
    # - MONSTER_DECK：进怪物弃牌堆
    # - MISSION：按任务系统规则处理
    # 纠缠该玩家的怪物处理（见 05-MonsterCard.md）
    _check_win_loss()

# 结束游戏
func end_game(result: GameResult) -> void:
    is_game_over = true
    game_result = result
    game_phase = GamePhase.GAME_OVER
    phase_changed.emit(game_phase)
    game_ended.emit(result)

# === 查询方法 ===

func get_current_player() -> Survivor:
    return survivors[current_player_index]

func get_alive_players() -> Array[Survivor]:
    return survivors.filter(func(s: Survivor) -> bool: return s.is_alive)

# 获取位于指定地块上的所有存活玩家（D108 地块摧毁等场景使用）
func get_survivors_on_block(block: MapBlockInstance) -> Array[Survivor]:
    var result: Array[Survivor] = []
    for survivor in survivors:
        if survivor.is_alive and survivor.current_block == block:
            result.append(survivor)
    return result

# 怪物标记变化时调用（地块 monster_tokens 增减时）
func notify_monster_token_changed() -> void:
    var total = map_grid.get_total_monster_tokens()
    monster_token_count_changed.emit(total, current_mission.monster_token_limit)
    if total >= current_mission.monster_token_limit:
        _check_win_loss()
```

---

## 3. GamePhase 枚举

```text
enum GamePhase {
    SETUP,       # 初始化阶段（start_new_game 调用到 _init_subsystems 完成）
    PLAYING,     # 游戏进行中（回合轮转）
    GAME_OVER,   # 游戏结束（胜利或失败）
}
```

> 粗粒度枚举：GameSession 只关心三个大阶段。细粒度的回合阶段（行动阶段 / 拾荒阶段 / 战斗阶段 / 结束阶段等）由 TurnManager 管理（见 12-TurnManager.md，待编写）。

---

## 4. GameResult 枚举

```text
enum GameResult {
    PLAYERS_WIN,   # 玩家胜利（达成任务胜利条件）
    MONSTERS_WIN,  # 怪物胜利（全员死亡 / 怪物标记上限 / 任务特殊失败）
    DRAW,          # 平局（默认值，正常情况下不会以此结束）
}
```

---

## 5. 子系统持有关系

| 子系统 | 类型 | 归属方式 | 初始化时机 | 引用文档 |
|---|---|---|---|---|
| `map_grid` | MapGrid (Node2D) | add_child 子节点 | `_init_map()` | 09-MapBlock.md 第 8 节 |
| `scavenger_deck_stack` | ScavengerDeckStack (RefCounted) | 字段 | `_init_scavenger_decks()` | 10-Deck.md 第 4 节 |
| `scavenger_discard_pile` | ScavengerDiscardPile (RefCounted) | 字段 | `_init_scavenger_decks()` | 10-Deck.md 第 5 节 |
| `monster_deck` | MonsterDeck (RefCounted) | 字段 | `_init_monster_deck()` | 10-Deck.md 第 6 节 |
| `monster_discard_pile` | MonsterDiscardPile (RefCounted) | 字段 | `_init_monster_deck()` | 10-Deck.md 第 7 节 |
| `survivors` | Array[Survivor] | add_child 子节点 | `_init_survivors()` | 07-CharacterCard.md 第 3 节 |
| `skill_executor` | SkillExecutor (Node) | add_child 子节点 | `_init_managers()` | 01-Skill.md（待编写 SkillExecutor 章节） |
| `turn_manager` | TurnManager (Node) | add_child 子节点 | `_init_managers()` | 12-TurnManager.md（待编写） |
| `CardRegistry` | autoload 单例 | 全局访问 | 启动时自动 | 10-Deck.md 第 2 节 |

> Node 类型子系统（MapGrid / Survivor / SkillExecutor / TurnManager）作为 GameSession 子节点挂载到场景树，随 GameSession 生命周期自动释放。RefCounted 类型子系统（各牌堆）作为字段持有，随 GameSession 被 GC 回收。

---

## 6. 初始化流程

### 6.1 完整初始化流程（引用 10-Deck.md 第 9 节 + 补充）

| 步骤 | 方法 | 引用文档 | 说明 |
|---|---|---|---|
| 0 | CardRegistry._ready() | 10-Deck.md 第 2 节 | autoload 启动时自动扫描 .tres（游戏启动时已完成，非每局调用） |
| 1 | `_init_map()` | 09-MapBlock.md 第 8 节 | 地图填充：build_instance_pool + map_layout 遍历 |
| 2 | `_init_scavenger_decks()` | 10-Deck.md 第 9 节步骤 3-4 | 拾荒牌堆 + 弃牌堆初始化 |
| 3 | `_init_monster_deck()` | 10-Deck.md 第 9 节步骤 5 | 怪物牌库 + 弃牌堆初始化 |
| 4 | `_init_survivors()` | 10-Deck.md 第 9 节步骤 6 | 求生者牌库实例化（按座次顺序） |
| 5 | `_init_scientist_equipment()` | 本文档第 2 节 | 任务 3/8/9 的科学家装备给第一个玩家（D102 / D111） |
| 6 | `_init_initial_monsters()` | 10-Deck.md 第 9 节步骤 7 | 初始抓怪（D17，任务 11 例外） |
| 7 | `_init_boss()` | 08-MissionCard.md 第 6 节 | 首领卡处理（按 boss_config.mechanic） |
| 8 | `_init_target_markers()` | 08-MissionCard.md 第 7 节 | 目标标记放置（按 target_markers 约束） |
| 9 | `_init_block_scavenger_piles()` | 09-MapBlock.md 第 9 节 | 地块拾荒牌堆剩余张数初始化 |
| 10 | `_init_managers()` | 本文档第 2 节 | TurnManager / SkillExecutor 初始化 |

### 6.2 首领卡处理分类

`_init_boss()` 根据 `boss_config.mechanic` 分类处理：

| 机制 | 处理时机 | 处理方式 | 任务 |
|---|---|---|---|
| `NONE` | - | 无首领 | 0 |
| `SHUFFLE_BOTTOM` | 初始化 | 抓 setup_cards 张牌 + 首领卡洗混放牌库底 | 2、3、4、6 |
| `SHUFFLE_INTO_DECK` | 初始化 | 首领卡洗入怪物牌库 | 9 |
| `SHUFFLE_LOWER_HALF` | 初始化 | 首领卡洗入怪物牌库下半部 | 11 |
| `SHUFFLE_PLUS_BOTTOM` | 初始化 | 随机洗入 + 牌库底额外 1 张（共 2 张） | 12 |
| `TRIGGER_ON_BLOCK` | 运行时 | 到达 trigger_block 时抓首领卡（由 SkillExecutor 处理） | 1、5、8 |
| `TRIGGER_ON_REVEAL` | 运行时 | 展示目标标记地块时抓首领牌（由 SkillExecutor 处理） | 7 |
| `TRIGGER_ON_MARKER` | 运行时 | 标记触发首领（由 SkillExecutor 处理） | 10 |

> 初始化时处理的首领卡机制在 `_init_boss()` 中完成；运行时触发的机制由 SkillExecutor 在对应事件时调用 `monster_deck.draw()` 抓取首领卡。

### 6.3 目标标记放置算法

`_init_target_markers()` 根据 `target_markers` 配置放置标记：

```text
对每个 marker_config in current_mission.target_markers:
  1. 获取所有已放置地块（map_grid.get_all_blocks()）
  2. 根据 marker_config.constraint_type 过滤：
     - NONE: 所有地块
     - DISTANCE_FROM_VAN: 距面包车 ≥ min_distance_from_van 的地块
     - DISTANCE_FROM_BASE: 距基地 ≥ min_distance_from_base 的地块
     - MUTUAL_DISTANCE: 距已放置标记 ≥ min_mutual_distance 的地块
     - DISTANCE_FROM_BASE_AND_MUTUAL: 同时满足上述两个约束
  3. 从候选地块中随机选一个
  4. 在该地块上放置目标标记
  5. 设置 initial_monster_tokens（如任务 9/11 的 3 个怪物标记）
  6. 记录 on_first_arrival_skill 供后续 SkillExecutor 触发
```

> 距离计算用 BFS（地图网格的最短路径），不用曼哈顿距离（地图形状可能不规则）。

---

## 7. 回合管理

GameSession 负责玩家轮转，具体回合流程委托给 TurnManager：

```text
GameSession._start_first_turn()
  ↓
TurnManager.start_turn(player)  # 委托给 TurnManager 管理回合内流程
  ↓
  ... 玩家执行行动 ...
  ↓
TurnManager 调用 GameSession.on_player_turn_end()
  ↓
GameSession._check_win_loss()  # 胜负判定
  ↓
GameSession._next_player()  # 切换到下一玩家
  ↓
TurnManager.start_turn(next_player)
```

> TurnManager 的具体回合流程（行动阶段 / 拾荒阶段 / 战斗阶段 / 结束阶段 / 怪物出生阶段）见 12-TurnManager.md（待编写）。

### 7.1 玩家轮转规则

- 按座次顺序轮转（survivors 数组顺序）
- 所有存活玩家各行动一回合后，turn_count + 1
- 死亡玩家跳过（`_next_player()` 中检查 is_alive，若当前玩家已死亡则继续切换）
- 任务 11 例外：起始异常（玩家在军事基地开始，任务开始时不抓取怪物卡）

### 7.2 回合限制（D20）

任务 5（拆除炸弹）有 3 回合限制（解除炸弹后只有 3 个回合返回面包车）：

- GameSession 需追踪 `turn_limit: int`（默认 -1 = 无限制）
- 任务 5 解除炸弹时设置 `turn_limit = 3`
- `_next_player()` 中检查 `turn_count >= start_turn + turn_limit` 触发失败

---

## 8. 胜负判定

### 8.1 判定时机

`_check_win_loss()` 在以下时机调用：

| 时机 | 触发条件 | 说明 |
|---|---|---|
| 每回合结束 | `on_player_turn_end()` | 检查回合结束后的胜负状态 |
| 玩家死亡 | `on_player_killed()` | 检查是否全员死亡 |
| 怪物标记变化 | `notify_monster_token_changed()` | 检查是否达到上限（D16） |
| 任务特殊事件 | 任务系统调用 | 如任务 5 炸弹爆炸、任务 8 潜行检定失败 |

### 8.2 胜负条件引用

胜负条件定义见 [08-MissionCard.md](08-MissionCard.md) 第 9 节：

- **通用失败条件**：全员死亡 / 怪物标记达到上限（D16）/ 求生者牌库空且无法抓牌时该玩家被淘汰
- **任务特殊失败条件**：见 08-MissionCard.md 第 9.2 节
- **胜利条件模式**：见 08-MissionCard.md 第 9.3 节（收集燃料 + 回面包车 / 到达特定地点 / 收集物资 + 回基地）

> GameSession 只定义判定流程与时机，具体胜负条件逻辑引用 08-MissionCard.md。

---

## 9. 信号（UI 通知）

GameSession 发出的信号供 UI 层监听：

| 信号 | 参数 | 触发时机 | UI 用途 |
|---|---|---|---|
| `game_started` | mission_data | `start_new_game()` 完成初始化后 | 显示任务介绍 / 目标 |
| `game_ended` | result | `end_game()` 调用时 | 显示胜利/失败画面 |
| `player_changed` | current_player | `_next_player()` 切换玩家时 | 高亮当前玩家头像 |
| `turn_started` | player, turn_count | `TurnManager.start_turn()` | 显示回合数 / 玩家提示 |
| `turn_ended` | player, turn_count | `on_player_turn_end()` | 回合结束动画 |
| `phase_changed` | new_phase | 游戏阶段变化时 | 切换 UI 状态（SETUP/PLAYING/GAME_OVER） |
| `monster_token_count_changed` | total, limit | 怪物标记数变化时 | 更新标记计数 UI |
| `player_killed` | survivor | `on_player_killed()` | 死亡动画 / 提示 |

> 细粒度信号（卡牌抓取 / 地块翻面 / 装备变化等）由各自类发出，不由 GameSession 集中转发。UI 层按需监听具体类的信号。

---

## 10. 待定问题

### Q1. SkillExecutor 的具体接口

SkillExecutor 的扫描范围、调度流程、与 GameSession 的交互方式待 01-Skill.md 补充 SkillExecutor 章节（或单独文档）定义。当前假设 SkillExecutor 是 Node 子类，由 GameSession 持有。

### Q2. TurnManager 的具体接口

TurnManager 的回合阶段划分（行动 / 拾荒 / 战斗 / 结束 / 怪物出生）、与 GameSession 的交互方式待 12-TurnManager.md 定义。当前假设 TurnManager 是 Node 子类，由 GameSession 持有，通过 `game_session` 字段反查 GameSession。

### Q3. Monster Node 的创建与归属

`_init_initial_monsters()` 中"创建 Monster Node, engage(survivor)"的具体实现待 05-MonsterCard.md 补充。Monster Node 作为 Survivor 的子节点还是 GameSession 的子节点？倾向 GameSession 子节点（统一管理所有 Monster）。

### Q4. 首领卡处理的具体实现

`_init_boss()` 中 4 种初始化时首领卡机制（SHUFFLE_BOTTOM / SHUFFLE_INTO_DECK / SHUFFLE_LOWER_HALF / SHUFFLE_PLUS_BOTTOM）的具体实现待代码阶段细化。需要 MonsterDeck 提供 `insert_at_bottom(card, offset)` 等方法（见 10-Deck.md Q10）。

### Q5. 目标标记的数据结构

目标标记作为 MapBlockInstance 的字段还是独立类？当前假设在 MapBlockInstance 上新增字段（如 `has_target_marker: bool` / `target_marker_config: TargetMarkerConfig`），待 09-MapBlock.md 确认是否需要补充字段。

### Q6. 任务特殊胜负条件的实现方式

`_check_mission_failure()` / `_check_mission_victory()` 当前返回 false（占位）。具体实现方式待确认：
- 选项 A：GameSession 内部 match mission_id 实现各任务胜负条件
- 选项 B：MissionCardData 提供 `check_victory(session)` / `check_failure(session)` 方法，由任务卡数据子类实现
- 倾向 B（数据 + 逻辑分离，任务卡自带胜负判定逻辑）

### Q7. 多人游戏的座次与并发

当前设计按座次顺序轮转（单人控制多个角色也适用）。是否需要支持真正的多人联机？MVP 阶段假设单机多人（同一设备轮流操作）。

### Q8. 游戏存档/读档

GameSession 是否需要支持存档/读档？MVP 阶段假设不支持，每局重新开始。未来扩展时需序列化所有子系统状态。

---

## 附：决策应用索引

本文档应用的决策：

- D8 死亡后卡牌按 source 处理（`on_player_killed()` 中分类处理）
- D13 MVP 最小可玩闭环（任务 0 配置子集）
- D16 怪物标记上限由任务卡配置（`_check_monster_token_limit()`）
- D17 初始抓怪按座次顺序（`_init_initial_monsters()`）
- D18 任务燃料机制（胜负判定引用 08-MissionCard.md）
- D19 首领卡机制（`_init_boss()` 按 boss_config.mechanic 分类处理）
- D20 回合限制（任务 5 的 3 回合限制，`turn_limit` 字段）
- D102 科学家初始位置（`_init_scientist_equipment()` 装备给第一个玩家）
- D108 任务 12 地块摧毁（`get_survivors_on_block()` 配合 09-MapBlock.md `destroy()`）
- D111 科学家卡牌来源（`_init_scientist_equipment()` 中 `source = MISSION`）
- 用户决策：GameSession 是场景根节点（每局新建，状态干净）
- 用户决策：GameSession 持有 TurnManager / SkillExecutor（集中管理生命周期）
- 用户决策：初始化流程引用 10-Deck.md 第 9 节不重复
- 用户决策：胜负判定引用 08-MissionCard.md 不重复
