# Game 游戏全局类

> 职责：游戏全局状态管理与跨玩家/跨区域操作。
> Game 类**不继承** Entity（无技能、无 trigger），是全局管理器。
> 游戏初始化与开局流程见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md)。

---

## 字段

### 全局区域

| 字段 | 类型 | 说明 |
|------|------|------|
| 怪物牌堆 | Pile | 怪物卡牌堆。空了重洗怪物弃牌堆组成新牌堆 |
| 怪物弃牌堆 | Pile | 怪物卡弃牌区域 |
| 红色拾荒牌堆 | Pile | red 拾荒牌堆。最危险（含伏击！） |
| 绿色拾荒牌堆 | Pile | green 拾荒牌堆 |
| 蓝色拾荒牌堆 | Pile | blue 拾荒牌堆。最安全 |
| 拾荒弃牌堆 | Pile | 所有颜色的拾荒牌弃置后都进入此弃牌堆（不分颜色） |
| 地图区域 | List\<MapBlock\> | 所有地图块 |
| 卡牌结算区 | List\<Card\> | 卡牌结算时的临时区域 |
| 所有玩家 | List\<Player\> | 本局游戏的所有玩家（按座位顺序） |

### 游戏状态

| 字段 | 类型 | 说明 |
|------|------|------|
| 当前回合玩家 | Player | 当前正在行动的玩家 |
| 游戏阶段 | String | 当前游戏阶段（"setup" / "playing" / "gameOver"） |
| 游戏结果 | String | "win" / "lose" / NULL（进行中） |

---

## 方法

### startGame()

> 游戏开局流程：在游戏初始化完成后执行（初始化见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md) 步骤 1-6）。
> 依次执行：抓初始手牌（含可选重调）→ 抓初始怪物卡 → 触发「游戏开始时」trigger → 进入第一玩家回合。
> 落地 [EventSystem §4.12](../Core/EventSystem.md#412-游戏类) 的「游戏开始时」trigger。
>
> **trigger 触发对象**：所有 player（按座位顺序依次触发）。Game 类不继承 Entity，无自身 trigger。
> **触发时机**：在抓初始怪物卡后、第一玩家回合开始前。

```gdscript
function game.startGame() {
    game.游戏阶段 = "playing"

    # 1. 每个玩家抓 4 张初始手牌（按座位顺序）
    for (player in game.所有玩家) {
        player.draw(4)
        # 可选一次重调：把最多 4 张刚抓的牌洗回牌堆，抓等量牌
        # 由 UI 交互决定，玩家可选择不重调
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

    # 2. 每个玩家抓 1 张初始怪物卡（按座位顺序）
    for (player in game.所有玩家) {
        player.drawMonster(1)
    }

    # 3. 触发「游戏开始时」trigger（按座位顺序对所有 player 触发）
    #    典型场景：gunslinger「快速拔枪」从牌堆中装备【柯尔特手枪】
    for (player in game.所有玩家) {
        event = {
            player: player,
            cancelled: false,
        }
        player.trigger("游戏开始时", event)
    }

    # 4. 进入第一玩家回合
    game.当前回合玩家 = game.所有玩家[0]
    game.当前回合玩家.开始回合()
}
```

> **注**：游戏初始化（步骤 1-6：加载角色/牌堆/地图/玩家位置/区域）由上层调用方完成，不在 startGame() 内。startGame() 仅负责开局流程（步骤 7-9）。
> **手牌上限**：每名玩家手牌上限 10，初始 4 张不会触顶。重调不会触顶（最多 4 张换 4 张）。

---

### gameOver(result)

> 游戏结束流程。
> 触发场景：所有玩家死亡（lose）；或胜利条件达成（win）。
> 落地 [EventSystem §4.12](../Core/EventSystem.md#412-游戏类) 的「游戏结束时」trigger。
>
> **trigger 触发对象**：所有 player（按座位顺序依次触发）。
> **触发时机**：在 game.游戏阶段 / game.游戏结果 设置后，玩家可访问 event.result 判断胜负。

```gdscript
function game.gameOver(result) {
    game.游戏阶段 = "gameOver"
    game.游戏结果 = result

    if (result == "win") {
        game.log("求生者成功逃离启示录的废土！")
    } else if (result == "lose") {
        game.log("所有求生者死亡，游戏失败。")
    }

    # 触发「游戏结束时」trigger（按座位顺序对所有 player 触发）
    #    event.result 携带 "win" / "lose"，技能可按 result 分支
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

### 游戏失败条件

- **所有玩家死亡** → `game.allPlayersDead()` 为真 → `game.gameOver("lose")`
- **怪物牌堆重洗后仍空**（所有怪物卡都在场上）→ `game.gameOver("lose")`（见 [Player.drawMonster](../Entities/Player.md#drawmonster) 节点 2a）
- **同生共死变体**：开启后任何玩家死亡即所有求生者输掉游戏（见 [L_gameVariants.md](../../GameInstructions/L_gameVariants.md)）

### 游戏胜利条件

> 详见 [G_gameOver.md](../../GameInstructions/G_gameOver.md)。
> 在玩家的回合结束时，胜利条件才触发（玩家依然会在回合结束前受到伤害）。

- 玩家完成了任务
- 往「面包车」添加了所需要的燃料值（所需燃料值在任务卡上查看）
- 所有存活玩家都返回到了地图块「面包车」上
- 地图块「面包车」内没有任何怪物和怪物标记

---

### allPlayersDead()

> 检查是否所有玩家死亡。

```gdscript
function game.allPlayersDead() {
    for player in game.所有玩家 {
        if (player.isAlive()) {
            return false
        }
    }
    return true
}
```

> 由 [Player.playerDeath](../Entities/Player.md#playerdeath) 末尾调用，判定全灭。

---

### removeCard(card)

> 将卡牌移出游戏（区别于进入弃牌堆）。
> 触发场景：玩家死亡时所有求生者游戏牌移出游戏（见 [Player.playerDeath](../Entities/Player.md#playerdeath) 3b）；或 [Player.removeCard](../Entities/Player.md#removecard) 销毁流程。

```gdscript
function game.removeCard(card) {
    # 从所有区域移除该卡牌，不再进入任何弃牌堆
    game.移出游戏列表.add(card)
}
```

> **销毁 vs 弃置**：销毁（removeCard）移出游戏不进弃牌堆；弃置（discard）进入对应弃牌堆。详见 [K_gameTerminology.md §8.1](../../GameInstructions/K_gameTerminology.md#81-销毁-vs-弃置)。

---

### getScavengePile(颜色)

> 获取指定颜色的拾荒牌堆。
> 参数：颜色为 "red" / "green" / "blue" 字符串。

```gdscript
function game.getScavengePile(颜色) {
    if (颜色 == "red") {
        return game.红色拾荒牌堆
    } else if (颜色 == "green") {
        return game.绿色拾荒牌堆
    } else if (颜色 == "blue") {
        return game.蓝色拾荒牌堆
    }
    return NULL
}
```

> 拾荒牌堆对象含 `pile`（牌堆）与 `discardPile`（弃牌堆）两个 Pile 实例。

---

### log(message)

> 输出游戏日志（用于 UI 显示与调试）。

```gdscript
function game.log(message) {
    game.日志列表.add(message)
    # 同步到 UI 日志面板
}
```

---

### 其他管理方法

| 方法 | 说明 |
|------|------|
| `getAllPlayers()` | 返回所有玩家列表 |
| `getAlivePlayers()` | 返回所有存活玩家 |
| `getCurrentPlayer()` | 返回当前回合玩家 |
| `nextTurn()` | 进入下一玩家回合（按座位顺序） |

---

## 游戏初始化与开局流程

> 完整流程见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md)。
> 步骤 1-6 为初始化（上层调用方完成），步骤 7-9 由 [game.startGame()](#startgame) 执行。

1. 加载本局游戏的所有求生者角色卡、立像和求生者游戏牌堆
2. 根据任务加载本局游戏的所有怪物卡，洗混组成怪物牌堆
3. 根据任务说明构建三个不同的拾荒牌堆（蓝、绿、红），分别洗乱
4. 根据任务说明构建地图
5. 根据任务说明将玩家立像放到初始地图块上
6. 初始化全局区域与各玩家区域
7. `game.startGame()` → 每个玩家从游戏牌堆抓 4 张牌作为初始手牌（可选一次重调）
8. `game.startGame()` → 每名玩家抓取一张怪物卡放到角色面前
9. `game.startGame()` → 触发「游戏开始时」trigger（按座位顺序对所有 player 触发）→ 进入第一玩家回合

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Player](../Entities/Player.md) | Game 管理所有玩家；玩家死亡触发全灭判定 |
| [Monster](../Entities/Monster.md) | Game 管理怪物牌堆/弃牌堆 |
| [Card](../Entities/Card.md) | Game 管理各类牌堆；removeCard 移出游戏 |
| [MapBlock](../Entities/MapBlock.md) | Game 管理地图区域 |
| [Pile](../Common/Pile.md) | 各牌堆为 Pile 实例 |
