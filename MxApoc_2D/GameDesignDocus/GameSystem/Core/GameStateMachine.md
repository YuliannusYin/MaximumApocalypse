# GameStateMachine 游戏状态机

> 职责：游戏级状态管理、回合队列管理、胜利/失败条件检查。
> 独立类，不继承 Entity（无技能、无 trigger），由 [Game](../Game/Game.md) 持有。
> 游戏初始化与开局流程见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md)，玩家回合流程见 [Player.开始回合](../Entities/Player.md#开始回合)。

---

## 设计职责

GameStateMachine 负责：

1. **游戏级状态管理**：定义 `setup` → `playing` → `gameOver` 三个状态及其合法转换
2. **回合队列管理**：按座位顺序循环执行玩家回合，支持额外回合插入与跳过回合
3. **胜利/失败检查**：回合结束时检查胜利条件；失败条件由各流程即时触发

> **设计原则**：Game 类持有状态机实例，状态相关字段（游戏阶段/游戏结果/当前回合玩家）由状态机管理，Game 方法委托给状态机。Player.开始回合() 由状态机调用。

---

## 游戏状态

### 状态定义

| 状态 | 说明 | 允许的操作 |
|------|------|-----------|
| `"setup"` | 游戏初始化阶段。加载角色/牌堆/地图/玩家位置/区域 | 初始化各区域、buildMap、startGame |
| `"playing"` | 游戏进行中。玩家按座位顺序轮流进行回合 | 玩家回合、技能执行、状态查询 |
| `"gameOver"` | 游戏已结束。不再接受任何操作 | 仅允许查询游戏结果 |

### 状态转换图

```
setup ──startGame()──> playing ──gameOver(result)──> gameOver
                                              │
                              ┌───────────────┘
                              │（胜利或失败条件触发）
                              └──> gameOver
```

> **合法转换**：`setup → playing`（仅一次）、`playing → gameOver`（仅一次）。其他转换均非法。
> **非法转换处理**：`transitionTo()` 遇到非法转换时抛出异常（严格模式）。

---

## 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 游戏状态 | String | `"setup"` / `"playing"` / `"gameOver"`。默认 `"setup"` |
| 游戏结果 | String | `"win"` / `"lose"` / NULL（进行中）。默认 NULL |
| 当前回合玩家 | Player | 当前正在行动的玩家。`"setup"` / `"gameOver"` 状态下为 NULL |
| 回合队列 | Queue\<Player\> | 待执行的回合队列。队首为下一个行动玩家。包含标准回合与额外回合 |
| 跳过标记 | Set\<Player\> | 需要跳过下个回合的玩家集合。跳过是一次性的，执行后移除标记 |
| 回合数 | Int | 当前是第几轮（所有玩家各执行一次为一轮）。从 1 开始 |

> **回合队列说明**：
> - 标准情况下，回合队列按座位顺序填充所有存活玩家
> - 额外回合通过 `insertExtraTurn(player)` 插入队首（当前玩家之后）
> - 跳过回合通过 `skipTurn(player)` 加入跳过标记，轮到时跳过并移除标记

---

## 方法

### init()

> 初始化状态机。在游戏初始化（C_gameSetup.md 步骤 1-6）完成后、startGame() 前调用。

```gdscript
function gsm.init() {
    gsm.游戏状态 = "setup"
    gsm.游戏结果 = NULL
    gsm.当前回合玩家 = NULL
    gsm.回合队列 = new Queue<Player>()
    gsm.跳过标记 = new Set<Player>()
    gsm.回合数 = 0
}
```

---

### startGame()

> 游戏开局流程：`setup → playing` 转换 + 抓初始手牌 + 抓初始怪物卡 + 触发「游戏开始时」trigger + 进入第一玩家回合。
> 落地 [EventSystem §4.12](EventSystem.md#412-游戏类) 的「游戏开始时」trigger。
>
> **trigger 触发对象**：所有 player（按座位顺序依次触发）。
> **前置条件**：`gsm.游戏状态 == "setup"`，否则抛异常。

```gdscript
function gsm.startGame() {
    # 1. 状态转换：setup → playing
    gsm.transitionTo("playing")

    # 2. 每个玩家抓 4 张初始手牌（按座位顺序，含可选重调）
    for (player in game.所有玩家) {
        player.draw(4)
        # 可选一次重调：把最多 4 张刚抓的牌洗回牌堆，抓等量牌
        if (player.choose(["进行重调", "不进行重调"]) == "进行重调") {
            maxReturn = min(4, player.手牌区.size())
            toReturn = player.chooseCard(maxReturn, position="手牌区")
            if (toReturn.length > 0) {
                for (card in toReturn) {
                    player.手牌区.remove(card)
                    player.游戏牌堆.add(card)
                }
                player.游戏牌堆.shuffle()
                player.draw(toReturn.length)
            }
        }
    }

    # 3. 每个玩家抓 1 张初始怪物卡（按座位顺序）
    for (player in game.所有玩家) {
        player.drawMonster(1)
    }

    # 4. 触发「游戏开始时」trigger（按座位顺序对所有 player 触发）
    for (player in game.所有玩家) {
        event = {
            player: player,
            cancelled: false,
        }
        player.trigger("游戏开始时", event)
    }

    # 5. 进入第一玩家回合
    gsm.nextTurn()
}
```

> **注**：游戏初始化（步骤 1-6：加载角色/牌堆/地图/玩家位置/区域）由上层调用方完成，不在 startGame() 内。

---

### gameOver(result)

> 游戏结束流程：`playing → gameOver` 转换 + 设置结果 + 触发「游戏结束时」trigger。
> 落地 [EventSystem §4.12](EventSystem.md#412-游戏类) 的「游戏结束时」trigger。
>
> **trigger 触发对象**：所有 player（按座位顺序依次触发）。
> **前置条件**：`gsm.游戏状态 == "playing"`。
> **不可逆**：gameOver 状态不可回退，不再接受任何操作。

```gdscript
function gsm.gameOver(result) {
    if (gsm.游戏状态 == "gameOver") {
        return  # 已结束，防止重复触发
    }

    # 1. 状态转换：playing → gameOver
    gsm.transitionTo("gameOver")
    gsm.游戏结果 = result
    gsm.当前回合玩家 = NULL
    gsm.回合队列.clear()

    # 2. 日志输出
    if (result == "win") {
        game.log("求生者成功逃离启示录的废土！")
    } else if (result == "lose") {
        game.log("所有求生者死亡，游戏失败。")
    }

    # 3. 触发「游戏结束时」trigger（按座位顺序对所有 player 触发）
    for (player in game.所有玩家) {
        event = {
            player: player,
            result: result,
            cancelled: false,
        }
        player.trigger("游戏结束时", event)
    }
}
```

> **调用场景**：
> - 胜利：`gsm.checkWinCondition()` 在回合结束时检查通过 → `gsm.gameOver("win")`
> - 失败（所有玩家死亡）：玩家死亡流程后 `game.allPlayersDead()` 为真 → `gsm.gameOver("lose")`
> - 失败（怪物牌堆重洗后仍空）：见 [Player.drawMonster](../Entities/Player.md#drawmonster) 节点 2a → `gsm.gameOver("lose")`
> - 失败（同生共死变体）：任一玩家死亡 → `gsm.gameOver("lose")`（见 [L_gameVariants.md](../../GameInstructions/L_gameVariants.md)）

---

### nextTurn()

> 切换到下一个玩家并执行其回合。
> 由 `gsm.startGame()` 首次调用，之后在每轮 `player.开始回合()` 返回后由状态机自动调用。
>
> **流程**：获取下一个玩家 → 设置当前回合玩家 → 调用 `player.开始回合()` → 检查胜利条件 → 若游戏继续则递归调用 nextTurn()。

```gdscript
function gsm.nextTurn() {
    if (gsm.游戏状态 != "playing") {
        return
    }

    # 1. 获取下一个玩家（处理跳过标记与死亡玩家）
    player = gsm.获取下一个玩家()

    if (player == NULL) {
        # 没有存活的玩家，游戏失败
        gsm.gameOver("lose")
        return
    }

    # 2. 设置当前回合玩家
    gsm.当前回合玩家 = player

    # 3. 执行玩家回合（线性 21 节点流程）
    #    player.开始回合() 返回后表示回合结束
    player.开始回合()

    # 4. 检查胜利条件（仅在回合结束时）
    if (gsm.checkWinCondition()) {
        return
    }

    # 5. 若游戏未结束，继续下一个回合
    if (gsm.游戏状态 == "playing") {
        gsm.nextTurn()
    }
}
```

> **递归说明**：伪代码阶段使用递归表示回合循环。实际实现时可改为事件驱动（回合结束后发出事件，状态机监听后调用 nextTurn()）。

---

### 获取下一个玩家()

> 内部方法。从回合队列中取出下一个玩家，处理跳过标记与死亡玩家。

```gdscript
function gsm.获取下一个玩家() {
    # 如果回合队列为空，填充新一轮
    if (gsm.回合队列.isEmpty()) {
        gsm.填充新一轮回合队列()
    }

    while (!gsm.回合队列.isEmpty()) {
        player = gsm.回合队列.poll()

        # 跳过已死亡玩家
        if (!player.isAlive()) {
            continue
        }

        # 处理跳过标记
        if (gsm.跳过标记.contains(player)) {
            gsm.跳过标记.remove(player)  # 跳过是一次性的
            game.log(player.名字 + " 的回合被跳过。")
            continue
        }

        return player
    }

    # 回合队列空且无法填充（所有玩家死亡）
    return NULL
}
```

---

### 填充新一轮回合队列()

> 内部方法。按座位顺序将所有存活玩家填入回合队列，开始新一轮。

```gdscript
function gsm.填充新一轮回合队列() {
    gsm.回合数 += 1
    for (player in game.所有玩家) {
        if (player.isAlive()) {
            gsm.回合队列.add(player)
        }
    }
}
```

---

### insertExtraTurn(player)

> 插入额外回合。将指定玩家插入回合队列队首（当前玩家之后立即执行）。
> 典型场景：部分技能效果让玩家获得额外回合。

```gdscript
function gsm.insertExtraTurn(player) {
    if (gsm.游戏状态 != "playing") {
        return
    }
    if (!player.isAlive()) {
        return
    }
    # 插入队首：当前玩家回合结束后立即执行
    gsm.回合队列.pushFront(player)
    game.log(player.名字 + " 获得了一个额外回合。")
}
```

> **位置说明**：`pushFront` 将玩家插入队首，确保在当前玩家回合结束后、下一个标准回合前执行。
> **多次插入**：若连续插入多个额外回合，后插入的先执行（栈结构）。

---

### skipTurn(player)

> 标记玩家跳过下个回合。跳过是一次性的，轮到该玩家时跳过并移除标记。
> 典型场景：怪物击晕等效果让玩家跳过回合。

```gdscript
function gsm.skipTurn(player) {
    if (gsm.游戏状态 != "playing") {
        return
    }
    gsm.跳过标记.add(player)
    game.log(player.名字 + " 的下个回合将被跳过。")
}
```

> **一次性**：跳过标记在 `获取下一个玩家()` 中检测到后立即移除，不会跨回合持续。
> **死亡玩家**：若被标记的玩家在回合前死亡，标记自然失效（`获取下一个玩家()` 跳过死亡玩家）。

---

### checkWinCondition()

> 检查胜利条件。仅在玩家回合结束时（`player.开始回合()` 返回后）调用。
> 胜利条件见 [G_gameOver.md](../../GameInstructions/G_gameOver.md)。
>
> **燃料值为 NULL 的处理**：若 `game.任务配置.启动面包车所需燃料 == NULL`，表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时跳过面包车相关检查（条件 2/3/4），仅依赖 `game.检查任务胜利条件()`。

```gdscript
function gsm.checkWinCondition() {
    if (gsm.游戏状态 != "playing") {
        return false
    }

    # 1. 玩家完成了任务（由任务系统检查）
    if (!game.检查任务胜利条件()) {
        return false
    }

    # 若该任务不通过面包车胜利（燃料值为 NULL），跳过条件 2/3/4
    if (game.任务配置.启动面包车所需燃料 == NULL) {
        gsm.gameOver("win")
        return true
    }

    # 2. 往「面包车」添加了所需要的燃料值
    面包车 = game.getBlocksByName("面包车")[0]
    if (面包车 == NULL) {
        return false
    }
    if (面包车.当前燃料 < game.任务配置.启动面包车所需燃料) {
        return false
    }

    # 3. 所有存活玩家都返回到了「面包车」上
    for (player in game.所有玩家) {
        if (player.isAlive() && player.get_current_block() != 面包车) {
            return false
        }
    }

    # 4. 地图块「面包车」内没有任何怪物和怪物标记
    if (面包车.hasMonsterMark() || 面包车.countMonster() > 0) {
        return false
    }

    # 所有胜利条件满足
    gsm.gameOver("win")
    return true
}
```

> **检查时机**：仅在 `gsm.nextTurn()` 中 `player.开始回合()` 返回后调用。
> **注意**：玩家依然会在回合结束前受到伤害（如中毒结算、面前怪物行动），胜利检查在所有伤害结算之后。
> **任务胜利条件**：`game.检查任务胜利条件()` 委托给 `game.任务配置.检查胜利条件()`，由任务包定义具体逻辑（如任务 5 检查"炸弹已拆除"、任务 8 检查"已记录科学家信息 + 所有玩家在军事基地"、任务 12 检查 3 个标记地块是否全部被摧毁等）。详见 [Game.md 任务配置结构](../Game/Game.md#任务配置结构missionconfig)。

---

### transitionTo(newState)

> 状态转换（带合法性校验）。非法转换抛异常。

```gdscript
function gsm.transitionTo(newState) {
    current = gsm.游戏状态

    # 合法转换检查
    valid = false
    if (current == "setup" && newState == "playing") {
        valid = true
    } else if (current == "playing" && newState == "gameOver") {
        valid = true
    }

    if (!valid) {
        throw "非法状态转换：" + current + " → " + newState
    }

    gsm.游戏状态 = newState
}
```

---

### 查询方法

| 方法 | 说明 |
|------|------|
| `getCurrentPlayer()` | 返回当前回合玩家（`"setup"` / `"gameOver"` 状态下返回 NULL） |
| `getGameState()` | 返回当前游戏状态 |
| `getGameResult()` | 返回游戏结果（`"win"` / `"lose"` / NULL） |
| `isPlaying()` | 是否在游戏中（`游戏状态 == "playing"`） |
| `isGameOver()` | 是否游戏结束（`游戏状态 == "gameOver"`） |
| `getTurnNumber()` | 返回当前轮数 |

```gdscript
function gsm.getCurrentPlayer() {
    return gsm.当前回合玩家
}

function gsm.getGameState() {
    return gsm.游戏状态
}

function gsm.getGameResult() {
    return gsm.游戏结果
}

function gsm.isPlaying() {
    return gsm.游戏状态 == "playing"
}

function gsm.isGameOver() {
    return gsm.游戏状态 == "gameOver"
}

function gsm.getTurnNumber() {
    return gsm.回合数
}
```

---

## 游戏失败条件

> 失败条件为**即时检查**，在各流程中触发后直接调用 `gsm.gameOver("lose")`。

| 失败条件 | 触发位置 | 检查方式 |
|---------|---------|---------|
| 所有玩家死亡 | [Player.playerDeath](../Entities/Player.md#playerdeath) 末尾 | `game.allPlayersDead()` 为真 → `gsm.gameOver("lose")` |
| 怪物牌堆重洗后仍空 | [Player.drawMonster](../Entities/Player.md#drawmonster) 节点 2a | 直接 `gsm.gameOver("lose")` |
| 同生共死变体：任一玩家死亡 | [Player.playerDeath](../Entities/Player.md#playerdeath) 末尾 | `game.同生共死模式` 为真 → `gsm.gameOver("lose")`（在全灭判定之前检查） |
| 任务特定失败条件 | 任务系统定义 | 任务系统检查后调用 `gsm.gameOver("lose")`（如任务 8 潜行失败且无日记本） |

---

## 游戏胜利条件

> 胜利条件为**回合结束时检查**，在 `gsm.nextTurn()` 中 `player.开始回合()` 返回后调用 `gsm.checkWinCondition()`。
> 详见 [G_gameOver.md](../../GameInstructions/G_gameOver.md)。

| 胜利条件 | 检查方式 |
|---------|---------|
| 玩家完成了任务 | `game.检查任务胜利条件()`（委托给 `game.任务配置.检查胜利条件()`） |
| 面包车燃料足够 | `面包车.当前燃料 >= game.任务配置.启动面包车所需燃料`（燃料值为 NULL 时跳过此条件及以下条件） |
| 所有存活玩家在面包车 | 遍历 `game.所有玩家` 检查位置（燃料值为 NULL 时跳过） |
| 面包车无怪物和怪物标记 | `!面包车.hasMonsterMark() && 面包车.countMonster() == 0`（燃料值为 NULL 时跳过） |

> **注意**：在玩家的回合结束时，胜利条件才触发（玩家依然会在回合结束前受到伤害）。
> **燃料值为 NULL**：表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时仅检查任务胜利条件。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](../Game/Game.md) | Game 持有 `状态机: GameStateMachine` 字段；Game.startGame() / Game.gameOver() / Game.getCurrentPlayer() / Game.nextTurn() 委托给状态机 |
| [Player](../Entities/Player.md) | 状态机调用 `player.开始回合()` 执行回合流程；Player.inPhase 在回合流程中设置 |
| [EventSystem](EventSystem.md) | 状态机触发「游戏开始时」/「游戏结束时」trigger |
| [G_gameOver.md](../../GameInstructions/G_gameOver.md) | 胜利/失败条件的规则定义 |

---

## 与 Game 类的集成

Game 类持有状态机实例，状态相关方法委托给状态机：

```gdscript
# Game 类字段
game.状态机 = new GameStateMachine()

# Game 类方法委托
function game.startGame() {
    game.状态机.startGame()
}

function game.gameOver(result) {
    game.状态机.gameOver(result)
}

function game.getCurrentPlayer() {
    return game.状态机.getCurrentPlayer()
}

function game.nextTurn() {
    game.状态机.nextTurn()
}

# 代理字段（向后兼容）
function game.游戏阶段 -> game.状态机.游戏状态
function game.游戏结果 -> game.状态机.游戏结果
function game.当前回合玩家 -> game.状态机.当前回合玩家
```

> **向后兼容**：现有引用 `game.游戏阶段` / `game.当前回合玩家` / `game.游戏结果` 的代码无需修改，通过代理字段访问状态机。
