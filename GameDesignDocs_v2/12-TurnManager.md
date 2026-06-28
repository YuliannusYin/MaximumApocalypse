# 12 - TurnManager（回合管理器）

> MA 的回合管理器：管理玩家回合内的 4 阶段流程（怪物出生→抓牌→行动→回合结束结算）、行动点机制、骰子机制。
> TurnManager 由 GameSession 持有（子节点），通过 `game_session` 字段反查 GameSession。
> 本文档定义基类与方法签名，并完整列出行动类型与免费行动规则（不引用 v1，使本文档成为完整的回合规则文档）。
> 应用 v1 决策：R2（回合结束顺序：地块→饥饿→怪物）、D5（燃料机制）、D9（装备卡先进手牌）、D12（拾荒牌库空）、D16（怪物标记上限）、D17（初始抓怪按座次）。

---

## 1. 设计原则

- **TurnManager 由 GameSession 持有**：作为 GameSession 的子节点，通过 `game_session` 字段反查 GameSession。每局游戏随 GameSession 创建/销毁（与 11-GameSession.md 决策一致）。
- **4 阶段回合流程**：沿用 v1 原版规则，每回合分怪物出生→抓牌→行动→回合结束结算 4 阶段。R2 决策定义回合结束结算顺序为地块→饥饿→怪物。
- **DiceRoller 独立工具类**：骰子机制抽离为静态工具类，便于怪物出生阶段、战斗系统、潜行检定等复用（ponytail：无状态工具函数）。
- **行动点机制集中管理**：TurnManager 集中管理行动点的增减与校验，行动消耗统一通过 `spend_action(cost)` 接口。
- **完整列出行动规则**：本文档完整列出所有行动类型与免费行动规则，不引用 v1 01-游戏规则总纲.md（使本文档自包含）。

---

## 2. TurnManager 类定义

```text
class_name TurnManager extends Node

const MAX_ACTION_POINTS: int = 4  # 每回合最大行动点（v1 原版规则）

# === 引用 ===
var game_session: GameSession            # 反查 GameSession
var current_player: Survivor             # 当前回合玩家
var current_phase: TurnPhase = TurnPhase.MONSTER_SPAWN  # 当前回合阶段

# === 行动点 ===
var action_points: int = 0               # 当前剩余标准行动点
var extra_actions: int = 0               # 额外行动数（D81：接下来 N 次行动不扣标准行动点）

# === 免费行动使用追踪（每回合重置） ===
var discard_2_draw_1_used: bool = false  # 弃 2 抓 1 是否已用
var trade_used: bool = false             # 交易拾荒卡是否已用

# === 信号（UI 通知） ===
signal turn_phase_changed(new_phase: TurnPhase)
signal action_points_changed(remaining: int, max: int)
signal monster_spawn_rolled(dice_sum: int)
signal monster_token_spawned(block: MapBlockInstance)
signal monster_card_drawn(player: Survivor, card: CardInstance)

# === 主流程 ===

# 开始玩家回合（由 GameSession._start_first_turn / _next_player 调用）
func start_turn(player: Survivor) -> void:
    current_player = player
    current_phase = TurnPhase.PREPARATION
    discard_2_draw_1_used = false
    trade_used = false
    action_points = 0
    extra_actions = 0
    turn_phase_changed.emit(current_phase)
    _phase_preparation()

# === 阶段 0：准备阶段（D99） ===

func _phase_preparation() -> void:
    # 准备阶段：结算击晕到期、重置每回合状态等
    current_player.on_turn_start()
    for monster in current_player.engaged_monsters:
        monster.on_turn_start(current_player)
    current_phase = TurnPhase.MONSTER_SPAWN
    turn_phase_changed.emit(current_phase)
    _phase_monster_spawn()

# === 阶段 1：怪物出生 ===

func _phase_monster_spawn() -> void:
    # 投 2 颗大骰子，点数之和为 X（2-12）
    var x = DiceRoller.roll_2d6()
    monster_spawn_rolled.emit(x)
    _spawn_monster_tokens(x)
    current_phase = TurnPhase.DRAW_CARD
    turn_phase_changed.emit(current_phase)
    _phase_draw_card()

# 在匹配 monster_spawn_value == x 的已展示地块上放置怪物标记
func _spawn_monster_tokens(x: int) -> void:
    for block in game_session.map_grid.get_revealed_blocks():
        if block.get_monster_spawn_value() != x:
            continue
        if x == 0:  # 军事基地安全地块，跳过
            continue
        if block.monster_tokens < 3:  # 每个地块怪物标记上限 3
            block.monster_tokens += 1
            monster_token_spawned.emit(block)
            game_session.notify_monster_token_changed()
        else:
            # 地块已有 3 个标记 → 该地块上所有玩家各抓 1 张怪物卡
            _spawn_monster_card_for_players_on_block(block)

# 地块怪物标记已满时，玩家直接抓怪物卡
func _spawn_monster_card_for_players_on_block(block: MapBlockInstance) -> void:
    for survivor in game_session.survivors:
        if not survivor.is_alive:
            continue
        if survivor.current_block != block:
            continue
        var card = game_session.monster_deck.draw()
        if card == null:
            DeckUtils.reshuffle_monster_discard(game_session.monster_deck, game_session.monster_discard_pile)
            card = game_session.monster_deck.draw()
        if card != null:
            monster_card_drawn.emit(survivor, card)
            # 创建 Monster Node, engage(survivor)（见 05-MonsterCard.md）

# === 阶段 2：抓求生者卡 ===

func _phase_draw_card() -> void:
    # 玩家从个人求生者牌库抓 1 张牌
    # 牌库空了不能抓牌时玩家被淘汰（D10，见 10-Deck.md 第 8 节）
    current_player.draw_from_survivor_deck(1)
    current_phase = TurnPhase.ACTION
    action_points = MAX_ACTION_POINTS
    action_points_changed.emit(action_points, MAX_ACTION_POINTS)
    turn_phase_changed.emit(current_phase)
    # 阶段 3：等待玩家通过 UI 执行行动

# === 阶段 3：执行行动（由玩家 UI 驱动） ===

# 玩家主动结束行动阶段（UI"结束回合"按钮）
func player_end_action_phase() -> void:
    if current_phase != TurnPhase.ACTION:
        return
    _phase_turn_end()

# 消耗行动点（返回 true 表示成功，false 表示行动点不足）
# 优先消耗 extra_actions；标准行动点归零时自动进入回合结束结算
func spend_action(cost: int = 1) -> bool:
    if extra_actions > 0:
        # D81：额外行动不扣除标准行动点
        extra_actions -= cost
        if extra_actions < 0:
            action_points += extra_actions  # 若额外行动不足，差额从标准行动点扣
            extra_actions = 0
    else:
        if action_points < cost:
            return false
        action_points -= cost
    action_points_changed.emit(action_points + extra_actions, MAX_ACTION_POINTS)
    if action_points == 0 and extra_actions == 0:
        _phase_turn_end()
    return true

# 增加行动点（D81：不能超过每回合上限 MAX_ACTION_POINTS）
func add_action_points(n: int) -> void:
    action_points = mini(action_points + n, MAX_ACTION_POINTS)
    action_points_changed.emit(action_points + extra_actions, MAX_ACTION_POINTS)

# 增加额外行动数（D81：接下来 N 次行动不扣标准行动点）
func add_extra_actions(n: int) -> void:
    extra_actions += n
    action_points_changed.emit(action_points + extra_actions, MAX_ACTION_POINTS)

func get_remaining_actions() -> int:
    return action_points + extra_actions

# === 阶段 4：回合结束结算（R2：地块→饥饿→怪物） ===

func _phase_turn_end() -> void:
    current_phase = TurnPhase.TURN_END
    turn_phase_changed.emit(current_phase)
    _step_block_end_effects()  # 4a. 地块结束效果
    _step_hunger_check()       # 4b. 饥饿 +1
    _step_monster_attack()     # 4c. 怪物攻击
    end_turn()

# 4a. 地块结束效果（ON_TURN_END_ON_BLOCK）
func _step_block_end_effects() -> void:
    var block = current_player.current_block
    if block != null:
        game_session.skill_executor.dispatch(TriggerTiming.ON_TURN_END_ON_BLOCK, block)

# 4b. 饥饿 +1，触发饥饿伤害检查
func _step_hunger_check() -> void:
    current_player.hunger_level += 1
    # 饥饿伤害检查（饥饿值 ≥ 6 时进入饥饿状态，见饥饿系统设计）
    # 触发 ON_HUNGER 时机（待 01-Skill.md 确认是否作为独立时机）

# 4c. 怪物攻击（纠缠怪物攻击玩家）
func _step_monster_attack() -> void:
    for monster in current_player.engaged_monsters:
        monster.attack(current_player)

# 结束回合，通知 GameSession 切换下一玩家
func end_turn() -> void:
    current_phase = TurnPhase.FINISHED
    turn_phase_changed.emit(current_phase)
    action_points = 0
    game_session.on_player_turn_end()

# === 免费行动检查 ===

func can_use_discard_2_draw_1() -> bool:
    return not discard_2_draw_1_used

func can_trade() -> bool:
    return not trade_used

func use_discard_2_draw_1() -> void:
    discard_2_draw_1_used = true

func use_trade() -> void:
    trade_used = true
```

---

## 3. TurnPhase 枚举

```text
enum TurnPhase {
    PREPARATION,     # 阶段 0：准备阶段（重置状态、结算击晕到期等）
    MONSTER_SPAWN,   # 阶段 1：怪物出生（投 2D6，放置怪物标记）
    DRAW_CARD,       # 阶段 2：抓求生者卡（从个人牌库抓 1 张）
    ACTION,          # 阶段 3：执行行动（玩家消耗行动点执行行动）
    TURN_END,        # 阶段 4：回合结束结算（R2：地块→饥饿→怪物）
    FINISHED,        # 回合结束，等待 GameSession 切换下一玩家
}
```

> 玩家完整回合流程（D99）：开始 → 准备阶段 → 怪物出生 → 抓一张牌 → 行动阶段 → 饥饿增加 → 怪物攻击 → 结束阶段 → 结束。
> 回合阶段按顺序执行：PREPARATION → MONSTER_SPAWN → DRAW_CARD → ACTION → TURN_END → FINISHED。阶段 3（ACTION）由玩家 UI 驱动，玩家执行行动或点击"结束回合"按钮后进入阶段 4。

---

## 4. 回合流程详解

### 4.0 阶段 0：准备阶段（D99）

```text
1. 当前玩家触发 on_turn_start()：重置本回合状态（如 hunger_damage_this_turn = false）
2. 结算玩家面前纠缠怪物的击晕到期：
   - 若怪物.stunned_until_turn_owner == current_player，则解除击晕
3. 进入阶段 1：怪物出生
```

> 击晕在击晕者下回合开始时解除，解除后的怪物当回合正常攻击（D92）。

### 4.1 阶段 1：怪物出生

```text
1. 系统投 2 颗大骰子（DiceRoller.roll_2d6()），点数之和为 X（范围 2-12）
2. 在每个正面朝上（is_revealed=true）且 get_monster_spawn_value() == X 的地块上：
   - 若地块怪物标记 < 3：monster_tokens += 1
   - 若地块怪物标记 == 3（已满）：该地块上所有存活玩家各抓 1 张怪物卡（直接 engage）
3. 特殊值 0（军事基地）：永不通过骰子机制放置怪物标记（安全地块）
4. 全局怪物标记总数 ≥ 上限（默认 30，D16）→ 游戏失败
```

> 见 09-MapBlock.md 第 10 节 monster_spawn_value 字段含义。

### 4.2 阶段 2：抓求生者卡

```text
1. 玩家从个人求生者牌库抓 1 张牌（Survivor.draw_from_survivor_deck(1)）
2. 牌库空 + 弃牌堆非空 → 惰性重洗弃牌堆为新牌库（D10，DeckUtils.reshuffle_survivor_deck）
3. 牌库空 + 弃牌堆空 → 玩家被淘汰（D10）
```

> 抓牌可能触发 ON_CARD_DRAWN 时机（如事件卡"一无所获"/"伏击"，见 04-ScavengerCard.md）。

### 4.3 阶段 3：执行行动

玩家有 4 个标准行动点（`MAX_ACTION_POINTS = 4`），可按任意组合执行行动，可多次执行同一行动。行动点不可累积，回合结束未用完的行动点作废。

行动点相关效果（D81）：
- **"额外执行 N 个行动"**：增加 `extra_actions`，接下来 N 次行动优先消耗 `extra_actions` 而不扣除 `action_points`。
- **"增加 1 点行动数"**：`action_points += 1`，但不能超过 `MAX_ACTION_POINTS`（即每回合上限 4）。

行动类型与免费行动见第 5、6 节。

玩家点击"结束回合"按钮或行动点归零时，进入阶段 4。

### 4.4 阶段 4：回合结束结算（R2）

按 R2 决策，结算顺序为 **地块 → 饥饿 → 怪物**：

| 子步骤 | 触发 | 说明 |
|---|---|---|
| 4a. 地块结束效果 | `ON_TURN_END_ON_BLOCK` | 玩家所在地块有"结束"关键词效果时触发（如绿洲止渴、医院休养、游乐园余兴） |
| 4b. 饥饿 +1 | 饥饿值自增 | 饥饿值 +1，触发饥饿伤害检查（饥饿值 ≥ 6 进入饥饿状态，见饥饿系统设计） |
| 4c. 怪物攻击 | 纠缠怪物攻击 | 玩家面前所有纠缠怪物造成伤害（见 05-MonsterCard.md 怪物攻击） |

> R2 顺序的关键：地块结束效果先于饥饿结算，饥饿结算先于怪物攻击。这保证了"避难所免疫伤害"（地块效果）能免疫本回合的饥饿伤害与怪物攻击。

---

## 5. 行动类型（每个消耗 1 行动点）

| 行动 | 方法签名 | 规则要点 |
|---|---|---|
| **移动** | `move_to_adjacent_block(dir: Direction)` | 横/竖向移动 1 格到相邻地块；不能斜向。移动到未知地块的时序：展示未知地块 → 离开当前地块 → 进入刚展示地块（D93）。进入时展示地块并执行地块效果（ON_REVEAL + ON_ENTER）；监狱 ON_REVEAL 触发"立即结束回合"后终止所有流程并跳过行动阶段。若进入有怪物标记的地块且自己面前无怪物，需做潜行检定 |
| **抓牌** | `draw_from_survivor_deck(n: int = 1)` | 从个人求生者牌库抓 n 张牌 |
| **打牌** | `play_card(card: CardInstance)` | 从手牌打出 1 张即时行动卡（结算后 discard） |
| **执行卡牌行动** | `execute_card_action(card: CardInstance)` | 执行已装备卡牌上的行动（如武器开火，需消耗弹药） |
| **拾荒** | `scavenge(color: DeckColor)` | 当前地块有拾荒标记时，从对应色堆抓 1 张（见 D12 牌库空处理） |
| **装填武器** | `reload_weapon(weapon: CardInstance, ammo: CardInstance)` | 装填武器弹药（消耗弹药卡） |
| **吃食物** | `eat_food(food: CardInstance)` | 打出食物卡降低饥饿值 |
| **治疗玩家** | `heal_player(medical: CardInstance)` | 打出医疗用品等治疗玩家 |
| **使用装备** | `equip_from_hand(card: CardInstance)` | 从手牌"使用"装备卡使其进入装备区（D9：装备卡先进手牌） |
| **给面包车加油** | `fuel_van(fuel_card: CardInstance)` | 在面包车地块使用装备区燃料卡加油（D5） |
| **地块行动** | `execute_block_action()` | 执行地块特殊行动（如机场传送、隧道穿梭，ON_ACTION 时机） |
| **捡起掉落卡** | `pick_up_dropped_card(card: CardInstance)` | 同地块捡起死亡玩家掉落的拾荒卡/装备卡（次数无限制） |

> 所有行动（除"捡起掉落卡"标注次数无限制外）每回合可多次执行，只要行动点足够。行动点消耗统一通过 `TurnManager.spend_action(cost)` 接口校验。

---

## 6. 免费行动

免费行动不消耗行动点，但有使用限制：

| 免费行动 | 使用限制 | 规则 |
|---|---|---|
| **弃 2 抓 1** | 每回合 1 次 | 弃 2 张求生者卡，从牌库抓 1 张新牌 |
| **交易拾荒卡** | 每回合 1 次 | 与同地块玩家交易拾荒卡（不能交易求生者卡） |
| **按目标卡打出** | 无限制 | 按任务卡指示打出（如把燃料加进面包车） |

使用限制由 TurnManager 的布尔字段追踪：

```text
var discard_2_draw_1_used: bool = false  # 弃 2 抓 1 是否已用（每回合重置）
var trade_used: bool = false             # 交易拾荒卡是否已用（每回合重置）
```

> "按目标卡打出"无使用限制，不需要追踪字段。`start_turn()` 中重置所有布尔字段。

---

## 7. DiceRoller 工具类

```text
class_name DiceRoller

# 投 1 颗 D6（返回 1-6）
static func roll_d6() -> int:
    return randi_range(1, 6)

# 投 n 颗 D6（返回各骰结果数组）
static func roll_d6_pool(n: int) -> Array[int]:
    var result: Array[int] = []
    for i in n:
        result.append(randi_range(1, 6))
    return result

# 投 2 颗 D6 求和（返回 2-12，用于怪物出生阶段）
static func roll_2d6() -> int:
    return roll_d6() + roll_d6()

# 投 n 颗 D6 求和
static func roll_d6_sum(n: int) -> int:
    var total = 0
    for i in n:
        total += randi_range(1, 6)
    return total
```

> `DiceRoller` 是无状态静态工具类，与 `DeckUtils` 风格一致。暂用 Godot 默认随机数（`randi_range`）。需要确定性随机时（如录像回放 / 种子复现）再加 `seed` 参数（见 10-Deck.md Q8）。

### 7.1 骰子使用场景

| 场景 | 方法 | 说明 |
|---|---|---|
| 怪物出生阶段 | `roll_2d6()` | 投 2 颗大骰子求和，匹配地块 monster_spawn_value |
| 潜行检定 | `roll_2d6()` | 进入有怪物标记的地块时检定（见 09-MapBlock.md 河流渡河检定） |
| 战斗检定 | `roll_d6()` / `roll_2d6()` | 攻击/防御检定（待战斗系统设计文档定义） |

---

## 8. 与 SkillExecutor 的交互

TurnManager 在各阶段调用 SkillExecutor 调度对应时机：

| 阶段 | SkillExecutor 调度 | target | 说明 |
|---|---|---|---|
| 阶段 2 抓牌 | `dispatch(ON_CARD_DRAWN, card)` | 抓到的卡 | 触发事件卡（一无所获/伏击） |
| 阶段 3 移动 | `dispatch(ON_REVEAL, block)` | 被展示的地块 | 地块展示效果（如百货商店免费拾荒） |
| 阶段 3 移动 | `dispatch(ON_ENTER, block)` | 进入的地块 | 地块进入效果（如城市街道抓怪物卡） |
| 阶段 3 移动 | `dispatch(ON_LEAVE, block)` | 离开的地块 | 地块离开效果（如森林穿越抓怪） |
| 阶段 3 地块行动 | `dispatch(ON_ACTION, block)` | 当前地块 | 地块行动效果（如机场传送） |
| 阶段 4a 地块结束 | `dispatch(ON_TURN_END_ON_BLOCK, block)` | 玩家所在地块 | 地块结束效果（如绿洲止渴） |
| 阶段 4c 怪物攻击 | `dispatch(ON_DAMAGE_TAKEN, player)` | 受伤玩家 | 减伤技能调度（如焊接头盔） |

> SkillExecutor 的扫描范围与调度流程见 01-Skill.md（待补充 SkillExecutor 章节）。

---

## 9. 与 GameSession 的交互

```text
GameSession._start_first_turn() / _next_player()
  ↓
TurnManager.start_turn(player)
  ↓
  ... 4 阶段流程 ...
  ↓
TurnManager.end_turn()
  ↓
GameSession.on_player_turn_end()
  ↓
GameSession._check_win_loss()  →  _next_player()  →  TurnManager.start_turn(next_player)
```

TurnManager 通过 `game_session` 字段反查 GameSession：
- `game_session.map_grid`：查询地块（怪物出生阶段遍历已展示地块）
- `game_session.monster_deck` / `monster_discard_pile`：抓怪物卡
- `game_session.survivors`：查询地块上的玩家
- `game_session.skill_executor`：调度技能
- `game_session.on_player_turn_end()`：通知回合结束
- `game_session.notify_monster_token_changed()`：通知怪物标记变化

---

## 10. 信号（UI 通知）

TurnManager 发出的信号供 UI 层监听：

| 信号 | 参数 | 触发时机 | UI 用途 |
|---|---|---|---|
| `turn_phase_changed` | new_phase | 回合阶段切换时 | 更新阶段指示器 / 高亮可用行动 |
| `action_points_changed` | remaining, max | 行动点增减时 | 更新行动点显示 |
| `monster_spawn_rolled` | dice_sum | 阶段 1 投骰后 | 显示骰子动画 / 结果 |
| `monster_token_spawned` | block | 怪物标记放置时 | 地块上怪物标记 +1 动画 |
| `monster_card_drawn` | player, card | 玩家直接抓怪物卡时 | 怪物卡出场动画 |

---

## 11. 待定问题

### Q1. Survivor.current_block 字段（已决）

Survivor 有 `current_block: MapBlockInstance` 字段表示当前所在地块，见 [07-CharacterCard.md](07-CharacterCard.md)。

### Q2. Survivor.engaged_monsters 字段（已决）

Survivor 有 `engaged_monsters: Array[Monster]` 字段表示面前的纠缠怪物列表，见 [07-CharacterCard.md](07-CharacterCard.md) / [05-MonsterCard.md](05-MonsterCard.md)。

### Q3. 饥饿系统设计

阶段 4b 的"饥饿 +1，触发饥饿伤害检查"具体逻辑待饥饿系统设计文档定义。当前假设 Survivor 有 `hunger_level: int` 字段，饥饿值 ≥ 6 进入饥饿状态（R1）。

### Q4. ON_HUNGER 时机

饥饿结算是否作为独立 TriggerTiming（ON_HUNGER）？还是合并到 ON_TURN_END？待 01-Skill.md TriggerTiming 枚举同步时确认（与 ON_HEAL/ON_DEATH/地块触发时机一起更新）。

### Q5. 潜行检定机制

"移动到有怪物标记的地块且自己面前无怪物，需做潜行检定"的具体机制待确认：
- 检定方式：投 2D6 对比潜行值？
- 成功/失败后果：成功→进入地块；失败→？留在原地 / 受到伤害 / 抓怪物卡？
- 见 09-MapBlock.md 河流渡河检定（stealth_check_or_return 效果）

### Q6. 怪物标记上限 3 的处理

每个地块怪物标记上限 3（v1 原版规则）。当地块已有 3 个标记且骰子点数匹配时，该地块上所有玩家各抓 1 张怪物卡。这个规则是否在所有任务中一致？还是部分任务有特殊规则？

### Q7. 任务 11 起始异常

任务 11（保护基地）任务开始时不抓取怪物卡（见 11-GameSession.md `_init_initial_monsters`）。但每回合的怪物出生阶段是否正常执行？还是任务 11 有特殊规则？

### Q8. 行动点增减效果（D81）

**已决**："额外执行 N 个行动"用 `extra_actions` 追踪，接下来 N 次行动不扣 `action_points`；"增加 1 点行动数"用 `add_action_points(n)`，上限 `MAX_ACTION_POINTS = 4`。详见第 4.3 节。

---

## 附：决策应用索引

本文档应用的决策：

- R2 回合结束顺序（地块→饥饿→怪物，阶段 4 子步骤）
- D5 燃料机制（给面包车加油行动）
- D9 装备卡先进手牌（使用装备行动）
- D10 求生者牌库空玩家淘汰（阶段 2 抓牌）
- D12 拾荒牌库空无法拾荒（拾荒行动）
- D16 怪物标记上限（阶段 1 怪物出生 + 全局上限判定）
- D17 初始抓怪按座次顺序（GameSession 初始化，非 TurnManager 职责）
- D81 额外行动与增加行动点（`extra_actions` 不扣标准行动点，`add_action_points` 上限 4）
- D92 击晕在准备阶段解除后当回合正常攻击
- D93 移动到未知地块时序：展示 → 离开 → 进入；监狱立即结束回合跳过行动阶段
- D99 玩家完整回合流程含准备阶段
- 用户决策：DiceRoller 独立工具类
- 用户决策：完整列出行动规则（不引用 v1）
- 用户决策：免费行动用布尔字段追踪
