# GameStateMachine 游戏状态机

> 职责：游戏级状态管理、回合队列管理、胜利/失败条件检查。
> 类名 `GameStateMachine`，继承 `RefCounted`。
> 独立类，**不继承** Entity（无技能、无 trigger），由 [Game](../Game/Game.md) 持有。
> 游戏初始化与开局流程见 [02_开局与流程.md](../../GameInstructions/02_开局与流程.md)，玩家回合流程见 [Player.md](../Entities/Player.md)。

> 对齐代码：`MxApoc_GDScript/src/core/game_state_machine.gd`

---

## 一、设计职责

GameStateMachine 负责：

1. **游戏级状态管理**：定义 `WAITING` / `PLAYING` / `GAME_OVER` 三个状态及其合法转换
2. **回合队列管理**：按座位顺序循环执行玩家回合，支持额外回合插入与跳过回合
3. **第零轮重调阶段**：游戏开局后、第一玩家回合前提供一次性重调阶段
4. **胜利/失败检查**：回合结束时检查胜利条件；失败条件由各流程即时触发

> **设计原则**：Game 类持有状态机实例，状态相关字段（游戏阶段/游戏结果/当前回合玩家）由状态机管理，Game 方法委托给状态机。`Player.start_turn()` 由状态机调用。

---

## 二、枚举

### 2.1 GameState

```gdscript
enum GameState { WAITING, PLAYING, GAME_OVER }
```

| 枚举值 | 整数值 | 说明 |
|--------|--------|------|
| `WAITING` | 0 | 游戏初始化等待阶段。加载角色/牌堆/地图/玩家位置/区域完成、尚未调用 `start_game()` |
| `PLAYING` | 1 | 游戏进行中。玩家按座位顺序轮流进行回合 |
| `GAME_OVER` | 2 | 游戏已结束。不再接受任何操作，仅允许查询游戏结果 |

> **首成员命名说明**：首成员为 `WAITING` 而非 `SETUP`。原因：等待态可被 `game_over()` 强制结束（用于测试/异常场景），`WAITING` 表达"等待开局"的语义更准确。

### 2.2 GameResult

```gdscript
enum GameResult { WIN, LOSE }
```

| 枚举值 | 整数值 | 说明 |
|--------|--------|------|
| `WIN` | 0 | 求生者胜利 |
| `LOSE` | 1 | 求生者失败 |

---

## 三、状态转换

### 3.1 合法转换

| 起始状态 | 目标状态 | 触发方法 |
|---------|---------|---------|
| `WAITING` | `PLAYING` | `start_game()` 内调用 `transition_to(PLAYING)` |
| `PLAYING` | `GAME_OVER` | `game_over(result)` 内直接赋值（绕过 `transition_to`） |
| `WAITING` | `GAME_OVER` | `game_over(result)` 内直接赋值（强制结束，用于测试/异常场景） |

### 3.2 状态转换图

```
WAITING ──start_game()──> PLAYING ──game_over(result)──> GAME_OVER
   │                                                         ▲
   └─────────────game_over(result)（强制结束）──────────────┘
```

> **`GAME_OVER` 状态不可逆**：进入后不再接受任何操作。
> **`game_over()` 不走 `transition_to()`**：直接赋值 `current_state = GameState.GAME_OVER`，从而允许从 `WAITING` 状态强制进入。

---

## 四、字段

| 字段名 | 类型 | 默认值 | 说明 |
|------|------|------|------|
| `current_state` | int (GameState) | `GameState.WAITING` | 当前游戏状态 |
| `game_result` | int (GameResult) | `-1` | 游戏结果。`-1` 表示未结束（NULL 哨兵） |
| `current_player` | Variant | `null` | 当前回合玩家。`WAITING` / `GAME_OVER` 状态下为 `null` |
| `last_player` | Variant | `null` | 游戏结束时保存的最后回合玩家，供结算场景高亮 |
| `turn_queue` | Array | `[]` | 待执行的回合队列。队首为下一个行动玩家。包含标准回合与额外回合 |
| `skip_turn_marks` | Dictionary | `{}` | 跳过标记。键 = 玩家，值 = `true`。跳过是一次性的，执行后移除 |
| `turn_number` | int | `0` | 当前轮数。所有玩家各执行一次为一轮。从 0 开始，首次填充队列时 +1 |

> **回合队列说明**：
> - 标准情况下，回合队列按座位顺序填充所有存活玩家
> - 额外回合通过 `queue_extra_turn(player)` 插入队首（当前玩家之后立即执行）
> - 跳过回合通过 `skip_next_turn(player)` 加入跳过标记，轮到时跳过并移除标记

---

## 五、方法

### 5.1 init()

初始化状态机。

| 签名 | 返回 |
|------|------|
| `init() -> void` | 无 |

- 在游戏初始化完成后、`start_game()` 前调用
- 重置所有字段：`current_state = WAITING`、`game_result = -1`、`current_player = null`、清空 `turn_queue` 与 `skip_turn_marks`、`turn_number = 0`

---

### 5.2 transition_to(new_state)

状态转换（带合法性校验）。

| 签名 | 参数 | 返回 |
|------|------|------|
| `transition_to(new_state: int) -> void` | `new_state` 目标状态 | 无 |

- **合法转换**：`WAITING → PLAYING`、`PLAYING → GAME_OVER`
- **非法转换处理**：输出 `printerr` 错误日志 + `return`，**不抛异常**
- 不在合法列表中的转换均视为非法

> `game_over()` 不调用此方法，直接赋值 `current_state`，从而允许从 `WAITING` 强制进入 `GAME_OVER`。

---

### 5.3 start_game()

游戏开局流程：`WAITING → PLAYING` 转换 + 抓初始手牌 + 抓初始怪物卡 + 触发「游戏开始时」trigger + 第零轮重调阶段 + 进入第一玩家回合。

| 签名 | 返回 |
|------|------|
| `start_game() -> void` | 无（异步 await） |

**执行步骤**：

1. 调用 `transition_to(GameState.PLAYING)` 转换状态
2. 发射 `EventBus.game_started` 信号；重置 `Game.stats_tracker` 并启动计时器
3. 每个玩家抓 4 张初始手牌（按座位顺序）
4. 每个玩家抓 1 张初始怪物卡（按座位顺序）
5. 触发「游戏开始时」trigger（`on_game_start`）：用 `EventSystem.create_event({"player": player})` 构建 event，对所有 player 按座位顺序触发
6. 调用 `_round_zero()` 执行第零轮重调阶段
7. 调用 `next_turn()` 进入第一玩家回合

---

### 5.4 _round_zero()

第零轮重调阶段。

| 签名 | 返回 |
|------|------|
| `_round_zero() -> void` | 无（异步 await） |

- **触发时机**：`start_game()` 抓初始手牌与怪物卡、触发游戏开始 trigger 之后，进入第一玩家回合之前
- **流程**：
  1. 发射 `EventBus.log_message` 信号输出 "==== 第0轮（重调阶段）===="
  2. 对每个存活玩家：
     - 设置 `current_player = player`、`player.in_phase = "round_zero"`
     - 发射 `EventBus.turn_started` 与 `EventBus.player_turn_started` 信号
     - **循环等待玩家重调决策**（支持多次重调，直到玩家选择取消或超时）：
       - 调用 `player.wait_redraw_decision()` 等待玩家决策
       - 玩家选择不重调 → break 退出循环
       - 玩家选择重调：将全部手牌洗回 `player.game_deck` → 清空 `player.hand` → `player.game_deck.shuffle()` → `player.draw(count)` 抓等量牌 → 输出重调日志
     - 结束第零轮回合：`player.in_phase = "idle"`，发射 `EventBus.turn_ended` 信号
  3. 重置 `current_player = null`

**与原伪代码差异**：原伪代码中重调在 `start_game()` 内一次性完成（每玩家仅一次），实际代码独立为 `_round_zero()` 方法，支持多次重调。

---

### 5.5 game_over(result)

游戏结束流程：直接赋值 `GAME_OVER` + 设置结果 + 触发「游戏结束时」trigger。

| 签名 | 参数 | 返回 |
|------|------|------|
| `game_over(result: int) -> void` | `result` 游戏结果（`GameResult.WIN` / `GameResult.LOSE`） | 无（异步 await） |

**执行步骤**：

1. 若 `current_state == GAME_OVER`：return（已结束，防止重复触发）
2. **直接赋值** `current_state = GameState.GAME_OVER`（绕过 `transition_to`，允许从 `WAITING` 强制进入）
3. 设置 `game_result = result`
4. 停止 `Game.stats_tracker` 计时器
5. 保存 `last_player = current_player`，置 `current_player = null`，清空 `turn_queue`
6. 输出日志：胜利输出"求生者成功逃离启示录的废土！"；失败输出"所有求生者死亡，游戏失败。"
7. 触发「游戏结束时」trigger（`on_game_over`）：用 `EventSystem.create_event({"player": player, "result": result})` 构建 event，对所有 player 按座位顺序触发
8. 设置 `Game.game_over_called = true`、`Game.game_result = "win" if result == WIN else "lose"`
9. 发射 `EventBus.game_over` 信号

> **调用场景**：
> - 胜利：`check_win_condition()` 在回合结束时检查通过 → `game_over(GameResult.WIN)`
> - 失败（所有玩家死亡）：玩家死亡流程后所有玩家死亡 → `game_over(GameResult.LOSE)`
> - 失败（怪物牌堆重洗后仍空）：见 [Player.md draw_monster](../Entities/Player.md) → `game_over(GameResult.LOSE)`
> - 失败（同生共死变体）：任一玩家死亡 → `game_over(GameResult.LOSE)`（见 [04_事件流与变体.md](../../GameInstructions/04_事件流与变体.md)）

---

### 5.6 next_turn()

切换到下一个玩家并执行其回合。

| 签名 | 返回 |
|------|------|
| `next_turn() -> void` | 无（异步 await） |

**执行步骤**（while 循环避免递归栈溢出）：

1. 当 `current_state == PLAYING` 时循环：
   - 调用 `_get_next_player()` 获取下一个玩家
   - 玩家为 `null`（无存活玩家）→ `game_over(GameResult.LOSE)` 并 return
   - 设置 `current_player = player`
   - 输出回合开始日志；发射 `EventBus.turn_started` 与 `EventBus.player_turn_started` 信号
   - `await player.start_turn()` 执行玩家回合
   - 回合结束输出日志（仅当仍为 `PLAYING` 状态）
   - 调用 `check_win_condition()` 检查胜利条件，通过则 return
   - 若游戏未结束，循环继续下一个回合

---

### 5.7 _get_next_player()（内部方法）

从回合队列中取出下一个玩家，处理跳过标记与死亡玩家。

| 签名 | 返回 |
|------|------|
| `_get_next_player() -> Variant` | 下一个玩家；无存活玩家时返回 `null` |

**流程**：

1. 若 `turn_queue` 为空，调用 `_fill_new_turn_queue()` 填充新一轮
2. 进入 `skipped_any` 外层循环：
   - 内层循环从队列 `pop_front` 取玩家：
     - 玩家已死亡或失效 → 标记 `skipped_any = true`，continue
     - 玩家在 `skip_turn_marks` 中 → 移除标记、输出"回合被跳过"日志、标记 `skipped_any = true`，continue
     - 否则返回该玩家
   - 内层循环结束后若 `skipped_any` 为 true 且仍有存活玩家，调用 `_fill_new_turn_queue()` 填充新一轮并再次扫描
3. 无存活玩家时返回 `null`

---

### 5.8 _fill_new_turn_queue()（内部方法）

按座位顺序将所有存活玩家填入回合队列，开始新一轮。

| 签名 | 返回 |
|------|------|
| `_fill_new_turn_queue() -> void` | 无 |

- `turn_number += 1`
- 输出 "==== 第 N 轮 ====" 日志
- 遍历 `Game.players`，将存活玩家追加到 `turn_queue` 末尾

---

### 5.9 queue_extra_turn(player)

插入额外回合。将指定玩家插入回合队列队首（当前玩家之后立即执行）。

| 签名 | 参数 | 返回 |
|------|------|------|
| `queue_extra_turn(player: Variant) -> void` | `player` 获得额外回合的玩家 | 无 |

- 前置守卫：`current_state != PLAYING` 时 return；玩家为 `null` / 失效 / 已死亡时 return
- 调用 `turn_queue.push_front(player)` 插入队首
- 输出日志：`"<玩家名> 获得了一个额外回合。"`

---

### 5.10 skip_next_turn(player)

标记玩家跳过下个回合。跳过是一次性的。

| 签名 | 参数 | 返回 |
|------|------|------|
| `skip_next_turn(player: Variant) -> void` | `player` 待跳过回合的玩家 | 无 |

- 前置守卫：`current_state != PLAYING` 时 return
- `skip_turn_marks[player] = true`
- 输出日志：`"<玩家名> 的下个回合将被跳过。"`

> **一次性**：跳过标记在 `_get_next_player()` 中检测到后立即移除，不会跨回合持续。
> **死亡玩家**：若被标记的玩家在回合前死亡，标记自然失效（`_get_next_player()` 跳过死亡玩家）。

---

### 5.11 check_win_condition()

检查胜利条件。仅在玩家回合结束时调用。

| 签名 | 返回 |
|------|------|
| `check_win_condition() -> bool` | 胜利返回 `true`，未胜利返回 `false` |

**执行步骤**：

1. 前置守卫：`current_state != PLAYING` 或 `Game` 失效时返回 `false`
2. 调用 `_check_mission_win_condition()` 委托给 `mission_config.check_win_condition`，未通过则返回 `false`
3. **面包车胜利判断**：若 `Game.mission_config.van_fuel_required < 0`（`-1` 哨兵表示无面包车胜利），直接 `game_over(GameResult.WIN)` 并返回 `true`
4. 查找名为"面包车"的地块：`Game.get_blocks_by_name("面包车")`，无则返回 `false`
5. 检查面包车燃料：`van.van_fuel < Game.mission_config.van_fuel_required` 时返回 `false`
6. 检查所有存活玩家位置：任一玩家不在面包车上时返回 `false`
7. 检查面包车无怪物和怪物标记：`van.has_monster_mark()` 为真或 `van.count_monster() > 0` 时返回 `false`
8. 所有胜利条件满足：`game_over(GameResult.WIN)` 并返回 `true`

> **`van_fuel_required < 0` 哨兵**：`-1` 表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时跳过面包车相关检查（步骤 4-7），仅依赖任务胜利条件。
> **任务胜利条件**：`_check_mission_win_condition()` 委托给 `Game.mission_config.check_win_condition`（Callable），由任务包定义具体逻辑（如任务 5 检查"炸弹已拆除"、任务 8 检查"已记录科学家信息 + 所有玩家在军事基地"、任务 12 检查 3 个标记地块是否全部被摧毁等）。详见 [MissionConfig.md](../Game/MissionConfig.md)。

---

### 5.12 _check_mission_win_condition()（内部方法）

委托给 `mission_config.check_win_condition`。

| 签名 | 返回 |
|------|------|
| `_check_mission_win_condition() -> bool` | 任务胜利条件是否满足 |

- 前置守卫：`Game` 失效或 `Game.mission_config` 为 `null` 时返回 `false`
- 若 `Game.mission_config.check_win_condition` 为有效 Callable，返回其调用结果
- 否则返回 `true`（无任务胜利条件，恒通过）

---

### 5.13 查询方法

| 方法 | 签名 | 返回 |
|------|------|------|
| `get_current_player()` | `get_current_player() -> Variant` | 当前回合玩家（`WAITING` / `GAME_OVER` 状态下为 `null`） |
| `get_game_state()` | `get_game_state() -> int` | 当前游戏状态（`GameState` 枚举值） |
| `get_game_result()` | `get_game_result() -> int` | 游戏结果（`GameResult` 枚举值；`-1` 表示未结束） |
| `is_playing()` | `is_playing() -> bool` | `current_state == GameState.PLAYING` |
| `is_game_over()` | `is_game_over() -> bool` | `current_state == GameState.GAME_OVER` |
| `get_turn_number()` | `get_turn_number() -> int` | 当前轮数 |

---

## 六、游戏失败条件

> 失败条件为**即时检查**，在各流程中触发后直接调用 `game_over(GameResult.LOSE)`。

| 失败条件 | 触发位置 | 检查方式 |
|---------|---------|---------|
| 所有玩家死亡 | [Player.md player_death](../Entities/Player.md) 末尾 | 所有玩家死亡 → `game_over(LOSE)` |
| 怪物牌堆重洗后仍空 | [Player.md draw_monster](../Entities/Player.md) | 直接 `game_over(LOSE)` |
| 同生共死变体：任一玩家死亡 | [Player.md player_death](../Entities/Player.md) 末尾 | 同生共死模式为真 → `game_over(LOSE)`（在全灭判定之前检查） |
| 任务特定失败条件 | 任务系统定义 | 任务系统检查后调用 `game_over(LOSE)`（如任务 8 潜行失败且无日记本） |

---

## 七、游戏胜利条件

> 胜利条件为**回合结束时检查**，在 `next_turn()` 中 `player.start_turn()` 返回后调用 `check_win_condition()`。

| 胜利条件 | 检查方式 |
|---------|---------|
| 玩家完成了任务 | `_check_mission_win_condition()` 委托给 `mission_config.check_win_condition` |
| 面包车燃料足够 | `van.van_fuel >= mission_config.van_fuel_required`（`van_fuel_required < 0` 时跳过此条件及以下条件） |
| 所有存活玩家在面包车 | 遍历 `Game.players` 检查位置（`van_fuel_required < 0` 时跳过） |
| 面包车无怪物和怪物标记 | `!van.has_monster_mark() && van.count_monster() == 0`（`van_fuel_required < 0` 时跳过） |

> **注意**：在玩家的回合结束时，胜利条件才触发（玩家依然会在回合结束前受到伤害）。
> **`van_fuel_required < 0`**：表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时仅检查任务胜利条件。

---

## 八、与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](../Game/Game.md) | Game 持有 `state_machine: GameStateMachine` 字段；Game 的 `start_game()` / `game_over()` / `get_current_player()` / `next_turn()` 委托给状态机 |
| [Player](../Entities/Player.md) | 状态机调用 `player.start_turn()` 执行回合流程；`Player.in_phase` 在回合流程中设置 |
| [EventSystem](EventSystem.md) | 状态机触发「游戏开始时」/「游戏结束时」trigger，用 `EventSystem.create_event()` 构建 event |
| [EventBus](../System/EventBus.md) | 状态机发射 `game_started` / `game_over` / `turn_started` / `turn_ended` / `player_turn_started` / `log_message` 等信号 |
| [MissionConfig](../Game/MissionConfig.md) | `check_win_condition` 委托给 `mission_config.check_win_condition`；`van_fuel_required` 字段决定是否检查面包车胜利 |
| [02_开局与流程.md](../../GameInstructions/02_开局与流程.md) | 开局与流程的规则定义 |
