# Game 游戏全局类

> 职责：游戏全局状态管理与跨玩家/跨区域操作。
> Game 类**不继承** Entity（无技能、无 trigger），是全局管理器。
> 游戏初始化与开局流程见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md)。
> 状态管理（游戏阶段/游戏结果/当前回合玩家/回合队列）已委托给 [GameStateMachine](../Core/GameStateMachine.md)。

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
| 地图区域 | List\<MapBlock\> | 所有存活的地块。地块被摧毁后从列表中移除 |
| 地图宽度 | Int | 地图网格的列数（x 方向），由任务地图要求二维数组确定 |
| 地图高度 | Int | 地图网格的行数（y 方向），由任务地图要求二维数组确定 |
| 卡牌结算区 | List\<Card\> | 卡牌结算时的临时区域 |
| 所有玩家 | List\<Player\> | 本局游戏的所有玩家（按座位顺序） |

### 状态机

| 字段 | 类型 | 说明 |
|------|------|------|
| 状态机 | GameStateMachine | 游戏状态机实例。管理游戏阶段、游戏结果、当前回合玩家、回合队列等。详见 [GameStateMachine.md](../Core/GameStateMachine.md) |

> **代理字段**（向后兼容）：以下字段通过代理访问状态机，已有引用无需修改：
>
> | 代理字段 | 实际访问 | 类型 | 说明 |
> |---------|---------|------|------|
> | `game.游戏阶段` | `game.状态机.游戏状态` | String | `"setup"` / `"playing"` / `"gameOver"` |
> | `game.游戏结果` | `game.状态机.游戏结果` | String | `"win"` / `"lose"` / NULL（进行中） |
> | `game.当前回合玩家` | `game.状态机.当前回合玩家` | Player | 当前正在行动的玩家。`"setup"` / `"gameOver"` 状态下为 NULL |

### 任务与变体

| 字段 | 类型 | 说明 |
|------|------|------|
| 任务配置 | MissionConfig | 本局任务配置。由任务包加载，含启动面包车所需燃料、检查胜利条件函数、任务状态字典等。详见 [任务配置结构](#任务配置结构missionconfig) |
| 同生共死模式 | Boolean | 可选难度变体。开启后任一玩家死亡即所有求生者输掉游戏（见 [L_gameVariants.md](../../GameInstructions/L_gameVariants.md)）。默认 false |

#### 任务配置结构（MissionConfig）

> 任务配置由任务包加载，存储本局任务的所有可配置项与运行时状态。

| 字段 | 类型 | 说明 |
|------|------|------|
| 启动面包车所需燃料 | Int / NULL | 启动面包车所需的燃料值。NULL 表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时 [checkWinCondition](../Core/GameStateMachine.md#checkwincondition) 跳过面包车相关检查，仅依赖 `检查胜利条件()` |
| 检查胜利条件 | () => Boolean | 任务包提供的胜利条件检查函数。返回 true 表示任务特定胜利条件已满足。由 [game.检查任务胜利条件()](#检查任务胜利条件) 调用 |
| 任务状态 | Dict\<String, Any\> | 任务特定运行时状态存储。各任务自行约定键名，如任务 8 的 `"已记录科学家信息"` / `"已解救科学家"`、任务 9 的 `"已摧毁发射器数"` 等 |

> **典型任务配置示例**：
>
> ```gdscript
> # 任务 5「拆除炸弹」配置
> 任务配置 = {
>     启动面包车所需燃料: 3,
>     检查胜利条件: () => {
>         return game.任务配置.任务状态.get("炸弹已拆除", false)
>     },
>     任务状态: {},
> }
>
> # 任务 8「情报恢复」配置（不通过面包车胜利）
> 任务配置 = {
>     启动面包车所需燃料: NULL,
>     检查胜利条件: () => {
>         if (!game.任务配置.任务状态.get("已记录科学家信息", false)) {
>             return false
>         }
>         军事基地 = game.getBlocksByName("军事基地")[0]
>         if (军事基地 == NULL) { return false }
>         for (player in game.所有玩家) {
>             if (player.isAlive() && player.get_current_block() != 军事基地) {
>                 return false
>             }
>         }
>         return true
>     },
>     任务状态: {
>         已记录科学家信息: false,
>         已解救科学家: false,
>         科学家装备牌: NULL,  # 预存储的科学家装备牌（任务设置"把科学家拾荒卡放到一边"）
>     },
> }
> ```

---

## 方法

### startGame()

> 游戏开局流程：在游戏初始化完成后执行（初始化见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md) 步骤 1-6）。
> **委托给** [GameStateMachine.startGame()](../Core/GameStateMachine.md#startgame)，依次执行：状态转换 setup → playing → 抓初始手牌（含可选重调）→ 抓初始怪物卡 → 触发「游戏开始时」trigger → 进入第一玩家回合。
> 落地 [EventSystem §4.12](../Core/EventSystem.md#412-游戏类) 的「游戏开始时」trigger。

```gdscript
function game.startGame() {
    game.状态机.startGame()
}
```

> **注**：完整实现见 [GameStateMachine.startGame()](../Core/GameStateMachine.md#startgame)。
> 游戏初始化（步骤 1-6：加载角色/牌堆/地图/玩家位置/区域）由上层调用方完成，不在 startGame() 内。startGame() 仅负责开局流程（步骤 7-9）。
> **手牌上限**：每名玩家手牌上限 10，初始 4 张不会触顶。重调不会触顶（最多 4 张换 4 张）。

---

### gameOver(result)

> 游戏结束流程。
> **委托给** [GameStateMachine.gameOver(result)](../Core/GameStateMachine.md#gameoverresult)，依次执行：状态转换 playing → gameOver → 设置结果 → 触发「游戏结束时」trigger。
> 触发场景：所有玩家死亡（lose）；或胜利条件达成（win）。
> 落地 [EventSystem §4.12](../Core/EventSystem.md#412-游戏类) 的「游戏结束时」trigger。

```gdscript
function game.gameOver(result) {
    game.状态机.gameOver(result)
}
```

> **注**：完整实现见 [GameStateMachine.gameOver(result)](../Core/GameStateMachine.md#gameoverresult)。

### 游戏失败条件

> 失败条件为**即时检查**，由各流程触发后调用 `game.gameOver("lose")`。详见 [GameStateMachine.md 游戏失败条件](../Core/GameStateMachine.md#游戏失败条件)。

- **所有玩家死亡** → `game.allPlayersDead()` 为真 → `game.gameOver("lose")`（[Player.playerDeath](../Entities/Player.md#playerdeath) 末尾检查）
- **怪物牌堆重洗后仍空**（所有怪物卡都在场上）→ `game.gameOver("lose")`（见 [Player.drawMonster](../Entities/Player.md#drawmonster) 节点 2a）
- **同生共死变体**：`game.同生共死模式` 为真时，任一玩家死亡即 `game.gameOver("lose")`（[Player.playerDeath](../Entities/Player.md#playerdeath) 末尾在全灭判定之前检查；见 [L_gameVariants.md](../../GameInstructions/L_gameVariants.md)）
- **任务特定失败**：任务系统检查后调用 `game.gameOver("lose")`（如任务 8 潜行检定失败且无日记本）

### 游戏胜利条件

> 胜利条件为**回合结束时检查**，在 [GameStateMachine.checkWinCondition()](../Core/GameStateMachine.md#checkwincondition) 中实现。
> 详见 [G_gameOver.md](../../GameInstructions/G_gameOver.md)。
> 在玩家的回合结束时，胜利条件才触发（玩家依然会在回合结束前受到伤害）。

- 玩家完成了任务（`game.检查任务胜利条件()` 委托给 `game.任务配置.检查胜利条件()`）
- 往「面包车」添加了所需要的燃料值（`game.任务配置.启动面包车所需燃料`；为 NULL 时跳过此条件及以下条件）
- 所有存活玩家都返回到了地图块「面包车」上
- 地图块「面包车」内没有任何怪物和怪物标记

> **燃料值为 NULL**：表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时仅检查任务胜利条件。详见 [任务配置结构](#任务配置结构missionconfig)。

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

### 地图管理

#### buildMap(missionConfig)

> 根据任务包配置构建游戏地图。
> 触发场景：[C_gameSetup.md](../../GameInstructions/C_gameSetup.md) 步骤 4「根据任务说明构建地图」。
>
> **构建逻辑**（模板+指定+随机）：
> 1. 读取任务包的「任务地图要求」二维数组，确定地图宽高
> 2. 读取任务包的「任务地图块配置」地块列表，构建地块池（按数量展开）
> 3. 遍历二维数组，按编码实例化地块：
>    - `-1`（无地块）→ 跳过
>    - `0`（出生点）→ 使用任务包指定的地块名实例化
>    - `1`（未知随机地块）→ 从地块池中随机抽取一个实例化
>    - `2`（游戏结束点）→ 使用任务包指定的地块名实例化
>    - `3`（标记地块）→ 从地块池中随机抽取一个实例化，并添加目标标记
> 4. 每个实例化的地块设置坐标 `(x, y)`，添加到 `game.地图区域`
>
> **任务地图要求编码**：
> - `-1` = 无地块
> - `0` = 出生点（任务包指定地块名，如"购物中心"）
> - `1` = 未知随机地块（从地块池随机抽取）
> - `2` = 游戏结束点（任务包指定地块名，如"面包车"）
> - `3` = 标记地块（从地块池随机抽取 + 添加目标标记 + 预置怪物标记）

```gdscript
function game.buildMap(missionConfig) {
    mapTemplate = missionConfig.任务地图要求.默认地图  # 二维数组
    game.地图高度 = mapTemplate.length       # 行数
    game.地图宽度 = mapTemplate[0].length    # 列数

    # 构建地块池：从任务地图块配置中按数量展开
    # 例：面包车 ×1、加油站 ×2 → ["面包车", "加油站", "加油站"]
    blockPool = []
    for (entry in missionConfig.任务地图块配置) {
        for (i = 0; i < entry.数量; i++) {
            blockPool.add(entry.地图块名)
        }
    }

    # 遍历二维数组，按编码实例化地块
    for (y = 0; y < game.地图高度; y++) {
        for (x = 0; x < game.地图宽度; x++) {
            code = mapTemplate[y][x]

            if (code == -1) {
                # 无地块，跳过
                continue
            }

            if (code == 0) {
                # 出生点：使用任务包指定的地块名
                blockName = missionConfig.任务地图要求.出生点地块名
                block = createMapBlock(blockName)
            } else if (code == 1) {
                # 未知随机地块：从地块池随机抽取
                index = random(0, blockPool.length - 1)
                blockName = blockPool.remove(index)  # 抽取并移除
                block = createMapBlock(blockName)
            } else if (code == 2) {
                # 游戏结束点：使用任务包指定的地块名
                blockName = missionConfig.任务地图要求.结束点地块名
                block = createMapBlock(blockName)
            } else if (code == 3) {
                # 标记地块：从地块池随机抽取 + 添加目标标记 + 预置怪物标记
                index = random(0, blockPool.length - 1)
                blockName = blockPool.remove(index)
                block = createMapBlock(blockName)
                # 添加任务定义的目标标记
                mark = missionConfig.任务地图要求.获取下一个目标标记()
                block.addObjectiveMark(mark)
                # 预置怪物标记（如任务9 每个2个、任务11 每个3个）
                if (mark.初始怪物标记数 > 0) {
                    block.addMonsterMark(mark.初始怪物标记数)
                }
            }

            # 设置坐标并添加到地图区域
            block.setCoordinate(x, y)
            game.地图区域.add(block)
        }
    }
}
```

> **地块实例化**：`createMapBlock(blockName)` 根据 MapBlocksPack 中的地块定义创建 MapBlock 实例（名字、技能、怪物生成点数、拾荒颜色等）。
> **地块池耗尽**：如果地块池不够（`1` 和 `3` 位置过多），抛出配置错误。
> **目标标记**：任务包通过 `获取下一个目标标记()` 返回 ObjectiveMark 结构（标记ID、描述、效果函数、初始怪物标记数、移除条件），详见 [Resource/README.md 任务包格式](../../Resource/README.md#任务包missionpacks)。
> **预置怪物标记**：标记地块可根据目标标记的 `初始怪物标记数` 字段预置怪物标记（任务 9/11）。预置的怪物标记与怪物出生检定添加的标记共用同一字段，上限 3。

---

#### getBlockByCoord(x, y)

> 通过坐标查询存活的地块。
> 触发场景：[MapBlock.getAdjacentBlocks](../Entities/MapBlock.md#相邻地块查询)、距离计算、射程判定等。

```gdscript
function game.getBlockByCoord(x, y) {
    for (block in game.地图区域) {
        if (block.isAlive() && block.坐标.x == x && block.坐标.y == y) {
            return block
        }
    }
    return NULL
}
```

> 已摧毁的地块已从 `game.地图区域` 移除，不会被查询到。坐标越界时返回 NULL。

---

#### getBlocksByName(name)

> 按名字查询所有同名的存活地块。
> 触发场景：隧道技能（移动到另一个已展示的隧道地块）、机场技能等。

```gdscript
function game.getBlocksByName(name) {
    result = []
    for (block in game.地图区域) {
        if (block.isAlive() && block.名字 == name) {
            result.add(block)
        }
    }
    return result
}
```

---

#### getAdjacentAliveBlocks(block)

> 返回地块的四向相邻存活地块。
> 用于地块摧毁时玩家弹出目标选择。

```gdscript
function game.getAdjacentAliveBlocks(block) {
    return block.getAdjacentBlocks()
}
```

> 实际逻辑由 [MapBlock.getAdjacentBlocks](../Entities/MapBlock.md#相邻地块查询) 实现。

---

#### destroyMapBlock(block, source)

> 摧毁地块流程。
> 触发场景：[blue.md 大炸药](../../Resource/ScavengePacks/blue.md)「行动：摧毁一个地图板块」。
> 落地 [EventSystem §4.13](../Core/EventSystem.md#413-地图类) 的「摧毁地块前/时/后」trigger。
>
> **处理逻辑**：
> 1. 触发「摧毁地块前」（取消点，可阻止摧毁）
> 2. 地块上的玩家弹出到相邻存活地块（玩家选择方向）
> 3. 消灭地块上的所有怪物标记
> 4. 触发「摧毁地块时」（系统结算）
> 5. 地块状态变更为「已摧毁」，从 `game.地图区域` 移除
> 6. 触发「摧毁地块后」
>
> **trigger 触发对象**：所有 player（按座位顺序）。Game 类不继承 Entity，无自身 trigger。
>
> **玩家弹出规则**：
> - 玩家选择一个相邻存活地块（`player.chooseMapBlock(adjacentBlocks)`）
> - 弹出不消耗行动次数，不触发完整移动钩子（非主动移动）
> - 清理旧地块技能 → 底层坐标变更 → 获取新地块技能 → 展示未展示的地块
> - 无相邻存活地块时，玩家受到 5 点无源伤害（紧急逃生失败）

```gdscript
function game.destroyMapBlock(block, source) {
    event = {
        source: source,    # 摧毁者（玩家，可 NULL）
        block: block,      # 被摧毁的地块
        cancelled: false,
    }

    # 1. 摧毁地块前（取消点）
    #    技能可调用 event.cancel() 阻止摧毁
    for (player in game.所有玩家) {
        player.trigger("摧毁地块前", event)
    }
    if (event.cancelled) {
        return false
    }

    # 2. 处理地块上的玩家（弹出到相邻存活地块）
    players = block.getPlayers()
    for (player in players) {
        adjacentBlocks = block.getAdjacentBlocks()
        if (adjacentBlocks.isEmpty()) {
            # 无相邻存活地块，玩家受到 5 点无源伤害（紧急逃生失败）
            game.log(player.名字 + "无处可逃，受到 5 点伤害")
            player.damage(5, NULL, "地块摧毁")
        } else {
            # 玩家选择一个相邻存活地块
            target = player.chooseMapBlock(adjacentBlocks)
            # 清理旧地块技能
            block.清除技能(player)
            # 底层坐标变更（不触发完整移动钩子，非主动移动）
            player.moveToMapBlock(target)
            # 获取新地块技能
            target.获取地块技能(player)
            # 如果目标地块未展示，展示（触发「展示地块时」效果）
            if (!target.is_revealed()) {
                target.展示(触发效果 = true, player)
            }
        }
    }

    # 3. 消灭地块上的所有怪物标记
    block.怪物标记数 = 0

    # 4. 摧毁地块时（系统结算：玩家已弹出、怪物标记已消灭）
    for (player in game.所有玩家) {
        player.trigger("摧毁地块时", event)
    }

    # 5. 地块状态变更，从地图区域移除
    block.地块状态 = "已摧毁"
    game.地图区域.remove(block)

    # 6. 摧毁地块后（通知）
    for (player in game.所有玩家) {
        player.trigger("摧毁地块后", event)
    }

    return true
}
```

> **注**：地块上的怪物卡（纠缠玩家的怪物）不随地块摧毁而死亡，怪物纠缠的是玩家而非地块。玩家弹出后，怪物继续纠缠该玩家。
> **地块技能清理**：玩家弹出时清理旧地块技能（`block.清除技能(player)`），获取新地块技能（`target.获取地块技能(player)`）。
> **目标标记**：地块被摧毁时，其上的目标标记一并销毁（未触发的标记不会再触发）。

---

### 其他管理方法

| 方法 | 说明 |
|------|------|
| `getAllPlayers()` | 返回所有玩家列表 |
| `getAlivePlayers()` | 返回所有存活玩家 |
| `getCurrentPlayer()` | 返回当前回合玩家。**委托给** [GameStateMachine.getCurrentPlayer()](../Core/GameStateMachine.md#查询方法) |
| `nextTurn()` | 进入下一玩家回合。**委托给** [GameStateMachine.nextTurn()](../Core/GameStateMachine.md#nextturn)，按座位顺序循环并处理跳过/额外回合 |
| `getAllDiscardPileEquipments()` | 返回场上所有弃牌堆中的装备牌列表（含所有玩家游戏牌弃牌堆 + 拾荒弃牌堆）。调用场景：[hunter.md 神通广大](../../Resource/SurvivorPacks/hunter.md)、[mechanic.md 维修](../../Resource/SurvivorPacks/mechanic.md) |
| `hasEquipmentInDiscardPiles()` | 场上所有弃牌堆中是否至少有 1 张装备牌（filter 用，比 `getAllDiscardPileEquipments().size() > 0` 更高效） |
| `getStepToward(source, target)` | 返回从 source 朝 target 方向的相邻存活地块（用于 surgeon「拉近」技能的 `向玩家拉近一格不触发效果`）。已在 source 与 target 相邻或重合时返回 target，无路径时返回 NULL |
| `检查任务胜利条件()` | 检查任务特定胜利条件。**委托给** [任务配置.检查胜利条件()](#任务配置结构missionconfig)。由 [GameStateMachine.checkWinCondition()](../Core/GameStateMachine.md#checkwincondition) 调用 |
| `createScavengeCard(卡牌名)` | 根据卡牌名创建一张新的拾荒卡实例（不消耗任何牌堆）。调用场景：[Player.收集物品](../Entities/Player.md#收集物品卡牌名-数量) |

---

### 检查任务胜利条件()

> 检查任务特定胜利条件。委托给任务配置提供的 `检查胜利条件()` 函数。
> 由 [GameStateMachine.checkWinCondition()](../Core/GameStateMachine.md#checkwincondition) 调用，作为胜利判定的第一项条件。

```gdscript
function game.检查任务胜利条件() {
    return game.任务配置.检查胜利条件()
}
```

> **设计说明**：
> - 任务胜利条件由任务包自行定义，支持任意复杂逻辑（如任务 8 检查"已记录科学家信息 + 所有玩家在军事基地"、任务 9 检查"已摧毁 2 个发射器 + 科学家在坠碎点"等）
> - 任务状态存储在 `game.任务配置.任务状态` 字典中，由任务包各方法（如 `player.记录科学家信息()`）写入
> - 与面包车胜利条件的关系：若 `启动面包车所需燃料 == NULL`，[checkWinCondition](../Core/GameStateMachine.md#checkwincondition) 仅依赖本方法；否则两者均需满足

---

### createScavengeCard(卡牌名)

> 根据卡牌名创建一张新的拾荒卡实例。**不消耗任何牌堆**中的牌，直接根据 ScavengePacks 中的卡牌定义克隆一张新卡。
> 调用场景：[Player.收集物品](../Entities/Player.md#收集物品卡牌名-数量)（任务物品直接生成加入手牌区）。

```gdscript
function game.createScavengeCard(卡牌名) {
    # 从 ScavengePacks 定义中查找卡牌定义
    definition = game.拾荒卡定义表[卡牌名]
    if (definition == NULL) {
        game.log("找不到卡牌定义：" + 卡牌名)
        return NULL
    }
    # 克隆一张新卡实例
    card = clone(definition)
    card.实例ID = newID()  # 唯一实例 ID
    return card
}
```

> **设计说明**：
> - 直接生成新卡牌而不从牌堆抽取，是因为任务物品（如「满是灰尘的日记本」）作为拾荒卡虽存在于拾荒牌堆中，但任务设计上希望玩家通过触发目标标记获得，而非随机抽到
> - 这可能造成牌堆中仍存在同名卡（可接受，任务设计已考虑）
> - `拾荒卡定义表` 在游戏初始化时从 ScavengePacks/*.md 加载，是卡牌名到卡牌定义的映射

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
| [GameStateMachine](../Core/GameStateMachine.md) | Game 持有状态机实例；startGame/gameOver/getCurrentPlayer/nextTurn 委托给状态机；游戏阶段/游戏结果/当前回合玩家为代理字段 |
| [Player](../Entities/Player.md) | Game 管理所有玩家；玩家死亡触发全灭判定 |
| [Monster](../Entities/Monster.md) | Game 管理怪物牌堆/弃牌堆 |
| [Card](../Entities/Card.md) | Game 管理各类牌堆；removeCard 移出游戏 |
| [MapBlock](../Entities/MapBlock.md) | Game 管理地图区域 |
| [Pile](../Common/Pile.md) | 各牌堆为 Pile 实例 |
