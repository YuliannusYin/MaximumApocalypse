# MapBlock 地图块类

> 继承：[Entity](../Core/Entity.md)
> 职责：地图块属性、坐标定位、展示机制、怪物标记管理、地块技能挂载、目标标记管理与摧毁机制。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 设计原则

### 1. 地块技能挂载到玩家

**所有地图块技能全部挂载到玩家身上，由 `player.trigger()` 统一触发。**

玩家进入地块时，地块技能挂载到 Player 身上（`player.获取地块技能(target)`）；离开时清理（`source.清除技能(player)`）。这样玩家身上的所有技能（角色固有、装备、地块、临时）都能通过 `player.trigger()` 统一遍历。

> 详见 [Player.moveTo](Player.md#moveto) 节点 4/7。

### 2. 坐标定位与相邻关系

每个地块持有一个二维坐标 `(x, y)`，对应任务地图要求二维数组中的位置（`map[y][x]`）。相邻关系基于**四向**（上下左右），不含对角线。距离计算使用**曼哈顿距离** `|x1-x2| + |y1-y2|`。

> 相邻与距离的规则定义见 [K_gameTerminology.md §1](../../GameInstructions/K_gameTerminology.md#1-地图) 与 [§6 距离与射程](../../GameInstructions/K_gameTerminology.md#6-距离与射程)。

### 3. 地块状态与摧毁

地块有两种状态：**存活**（alive）与**已摧毁**（destroyed）。被大炸药等效果摧毁的地块从 `game.地图区域` 移除，其上的玩家被弹出到相邻存活地块，怪物标记消灭。摧毁流程见 [Game.destroyMapBlock](../Game/Game.md#destroymapblockblock-source)。

### 4. 目标标记

部分任务（如任务 10、12）在地图上放置目标标记。目标标记挂载到地块上，玩家进入地块时触发效果（一次性）。标记效果由任务包定义，详见 [Resource/README.md 任务包格式](../../Resource/README.md#任务包missionpacks)。

---

## 字段

### 基础字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 名字 | String | 地图块名称（如"避难所"、"面包车"、"军事基地"） |
| 坐标 | { x: Int, y: Int } | 地块在地图网格中的位置。x=列（横向），y=行（纵向）。对应任务地图要求二维数组 `map[y][x]` |
| 技能 | List\<Skill\> | 地块技能（继承自 Entity 的 skills） |
| 怪物生成点数 | Int | monster_spawn_value。怪物出生检定时，投骰结果匹配的地块生成怪物 |
| 拾荒颜色 | Set\<String\> | 该地块可拾荒的牌堆颜色集合（红/绿/蓝子集）。空集合表示不可拾荒 |
| 是否展示 | Bool | revealed 状态。玩家首次进入时翻开（展示），触发「展示地块时」效果 |
| 怪物标记数 | Int | 地块上的怪物标记数，最多 3 个 |
| 地块状态 | String | `"存活"` / `"已摧毁"`。默认 `"存活"`。摧毁后从 `game.地图区域` 移除 |
| 目标标记 | List\<ObjectiveMark\> 或 NULL | 任务目标标记列表。NULL 表示无标记。玩家进入时触发未触发的标记 |

### 目标标记结构（ObjectiveMark）

```
ObjectiveMark {
    标记ID: String          # 如 "标记1"、"标记2"
    标记描述: String        # 自然语言描述，如 "收集 3 个多余零件和 2 个医疗用品"
    标记效果: Function      # (player) => { ... }，玩家进入地块时调用
    已触发: Bool            # 是否已触发（一次性）。默认 false
    初始怪物标记数: Int     # 地图构建时为地块预置的怪物标记数。默认 0。用于任务 9/11 等标记地块需守卫的场景
    移除条件: Function      # (block) => { ... return Bool }，默认 NULL。每次 removeMonsterMark 后检查，满足时自动移除标记。如任务 11：return block.countMonsterMark() == 0
    已移除: Bool            # 是否已被移除（区别于"已触发"）。默认 false。移除后不再参与任务胜利条件检查
}
```

> 标记效果由任务包定义（伪代码），在地图构建时挂载到地块上。详见 [Game.buildMap](../Game/Game.md#buildmapmissionconfig)。
>
> **初始怪物标记数**：buildMap 在 addObjectiveMark 后调用 `block.addMonsterMark(mark.初始怪物标记数)` 预置怪物标记。
>
> **移除条件**：仅在 `removeMonsterMark` 后检查（怪物标记减少时）；`addMonsterMark` 不触发检查。条件返回 true 时调用 `removeObjectiveMark(mark)`。典型场景：任务 11「清除所有怪物标记后移除目标标记」。

### 地图块配置格式

> 详见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。
> 格式：`地图块名字[拾荒牌堆颜色][地块刷怪点数]`，例：`游乐园[红、蓝、绿][6]`、`城市[红][8]`。

---

## 信号量（triggers）

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 展示地块时 | 地块首次翻开时 | 地块技能（挂载到 player 后由 player.trigger 触发） | 否 |
| 摧毁地块前 | 地块被摧毁前 | 所有 player（按座位顺序） | **是** |
| 摧毁地块时 | 地块摧毁系统结算时（玩家弹出、怪物标记消灭、状态变更） | 所有 player | 否 |
| 摧毁地块后 | 地块摧毁完成后 | 所有 player | 否 |
| 触发目标标记时 | 玩家进入地块且触发未触发的目标标记后 | player | 否 |

> 地块的其他 trigger（如「回合开始时」、「行动阶段结束时」、「受到伤害时」）由地块技能声明，挂载到 player 后在对应流程触发。例：避难所声明 `trigger: 回合开始时、受到伤害时`。

> 摧毁地块类 trigger 由 [Game.destroyMapBlock](../Game/Game.md#destroymapblockblock-source) 触发；触发目标标记时由 [Player.moveTo](Player.md#moveto) 节点 11 触发。

---

## 方法

### 展示(触发效果, player)

> 翻开未展示的地块。
> 触发场景：[Player.moveTo](Player.md#moveto) 节点 9 中目标地块未展示时。

```gdscript
function block.展示(触发效果, player) {
    block.是否展示 = true

    if (触发效果) {
        # 触发「展示地块时」效果（如百货商店：执行一次免费拾荒）
        # 地块技能已挂载到 player 身上，由 player.trigger 触发
        player.trigger("展示地块时", {player: player, block: block})
    }
}
```

---

### 怪物标记管理

| 方法 | 说明 |
|------|------|
| `addMonsterMark(n)` | 增加 n 个怪物标记（上限 3）。**不触发**目标标记移除条件检查 |
| `removeMonsterMark(n)` | 移除 n 个怪物标记。移除后检查地块上所有目标标记的 `移除条件`，满足时自动调用 `removeObjectiveMark(mark)` |
| `countMonsterMark()` | 返回当前怪物标记数 |
| `hasMonsterMark()` | 是否有怪物标记（countMonsterMark() > 0） |
| `countMonster()` | 返回地块上当前纠缠玩家的怪物总数（怪物卡数） |
| `hasPlayer()` | 是否有玩家在此地块 |
| `hasColor()` | 是否可拾荒（拾荒颜色集合非空） |
| `hasSkill(name)` | 是否具备指定名字的地块技能 |

#### 怪物标记规则

- 地块怪物标记最多 3 个
- 怪物出生检定时，匹配地块若标记 < 3 → +1 标记；标记 = 3 且有玩家 → 每位玩家抓 1 怪物卡（见 [Player.monsterSpawnJudge](Player.md#monsterspawnjudge)）
- 玩家进入有怪物标记的地块时进行潜行检定，失败 → 移除所有标记并抓等量怪物卡（见 [Player.moveTo](Player.md#moveto) 节点 10）
- **目标标记移除条件检查**：`removeMonsterMark` 后遍历地块上所有未移除且声明了 `移除条件` 的目标标记，条件返回 true 时移除该标记。典型场景：任务 11「清除所有怪物标记后移除目标标记」

---

### 地块技能挂载

| 方法 | 说明 |
|------|------|
| `获取地块技能(player)` | 将地块技能挂载到 player 身上（由 player.获取地块技能 调用） |
| `清除技能(player)` | 从 player 身上移除地块技能 |

> 这两个方法实际定义在 Player 类（`player.获取地块技能(block)` / `block.清除技能(player)`），通过 `player.addSkill` / `player.removeSkill` 操作。详见 [Player.moveTo](Player.md#moveto)。

---

### 拾荒

| 方法 | 说明 |
|------|------|
| `hasColor()` | 该地块是否可拾荒 |
| `getColors()` | 返回可拾荒的颜色集合 |

> 玩家在该地块拾荒时，从对应颜色的拾荒牌堆抓牌（见 [Player.drawScavenge](Player.md#drawscavenge)）。

---

### 坐标与位置查询

| 方法 | 说明 |
|------|------|
| `getCoordinate()` | 返回 `{ x, y }` 坐标 |
| `setCoordinate(x, y)` | 设置坐标（地图构建时使用） |
| `isAlive()` | 地块状态是否为 `"存活"` |
| `isDestroyed()` | 地块状态是否为 `"已摧毁"` |

```gdscript
function block.getCoordinate() {
    return block.坐标
}

function block.setCoordinate(x, y) {
    block.坐标 = { x: x, y: y }
}

function block.isAlive() {
    return block.地块状态 == "存活"
}

function block.isDestroyed() {
    return block.地块状态 == "已摧毁"
}
```

---

### 相邻地块查询

> 基于四向（上下左右）查询相邻的存活地块。用于玩家移动目标选择、工厂技能（向相邻地块加怪物标记）、地块摧毁时玩家弹出等场景。

```gdscript
function block.getAdjacentBlocks() {
    adjacent = []
    # 四向：上、下、左、右
    directions = [(0, -1), (0, 1), (-1, 0), (1, 0)]
    for (dx, dy) in directions {
        x = block.坐标.x + dx
        y = block.坐标.y + dy
        neighbor = game.getBlockByCoord(x, y)
        # 过滤掉无地块（NULL）和已摧毁的地块
        if (neighbor != NULL && neighbor.isAlive()) {
            adjacent.add(neighbor)
        }
    }
    return adjacent
}
```

> `game.getBlockByCoord(x, y)` 通过坐标查询地块，见 [Game.md](../Game/Game.md#getblockbycoordx-y)。

---

### 距离计算

> 计算当前地块到目标地块的曼哈顿距离。用于射程判定（短距离 1 格 / 中距离 1-2 格 / 长距离 2-3 格 / Infinity 任意）。

```gdscript
function block.distanceTo(other) {
    return abs(block.坐标.x - other.坐标.x) + abs(block.坐标.y - other.坐标.y)
}
```

> 射程与距离的完整定义见 [F_gameRange.md](../../GameInstructions/F_gameRange.md) 与 [K_gameTerminology.md §6](../../GameInstructions/K_gameTerminology.md#6-距离与射程)。

#### 射程范围查询

| 方法 | 说明 |
|------|------|
| `getBlocksInRange(range)` | 返回指定射程范围内的所有存活地块。range 为 `"短距离"` / `"中距离"` / `"长距离"` / `"Infinity"` |
| `getPlayersInRange(range)` | 返回指定射程范围内的所有玩家 |

```gdscript
function block.getBlocksInRange(range) {
    result = []
    for (b in game.地图区域) {
        if (!b.isAlive()) {
            continue
        }
        d = block.distanceTo(b)
        if (range == "短距离" && d == 1) {
            result.add(b)
        } else if (range == "中距离" && d >= 1 && d <= 2) {
            result.add(b)
        } else if (range == "长距离" && d >= 2 && d <= 3) {
            result.add(b)
        } else if (range == "Infinity") {
            result.add(b)
        }
    }
    return result
}

function block.getPlayersInRange(range) {
    players = []
    blocks = block.getBlocksInRange(range)
    for (b in blocks) {
        players.addAll(b.getPlayers())
    }
    return players
}
```

> **长距离特殊规则**：长距离不包含 1 格内的目标（距离 2-3 格）。玩家射程以自己所在地块为中心；怪物射程以其纠缠玩家所在地块为中心。

---

### 玩家查询

| 方法 | 说明 |
|------|------|
| `getPlayers()` | 返回该地块上的所有存活玩家 |
| `hasPlayer()` | 是否有存活玩家在此地块（已定义，此处明确语义） |

```gdscript
function block.getPlayers() {
    players = []
    for (player in game.所有玩家) {
        if (player.isAlive() && player.get_current_block() == block) {
            players.add(player)
        }
    }
    return players
}
```

---

### 目标标记管理

| 方法 | 说明 |
|------|------|
| `hasObjectiveMark()` | 是否有目标标记（且至少一个未移除） |
| `getObjectiveMarks()` | 返回目标标记列表（可能为 NULL） |
| `addObjectiveMark(mark)` | 添加目标标记（地图构建时使用） |
| `removeObjectiveMark(mark)` | 移除指定目标标记（设 `已移除 = true` 并从列表移除）。由 `removeMonsterMark` 检查移除条件后调用，或由炸药等技能直接调用 |
| `removeAllObjectiveMarks()` | 移除地块上所有未移除的目标标记。由炸药等技能调用 |
| `triggerObjectiveMarks(player)` | 触发所有未触发且未移除的目标标记效果 |

```gdscript
function block.hasObjectiveMark() {
    if (block.目标标记 == NULL) {
        return false
    }
    for (mark in block.目标标记) {
        if (!mark.已移除) {
            return true
        }
    }
    return false
}

function block.addObjectiveMark(mark) {
    if (block.目标标记 == NULL) {
        block.目标标记 = []
    }
    block.目标标记.add(mark)
}

function block.removeObjectiveMark(mark) {
    if (block.目标标记 == NULL) {
        return
    }
    mark.已移除 = true
    block.目标标记.remove(mark)
    # 任务胜利条件检查由任务系统在合适时机调用（如回合结束时）
}

function block.removeAllObjectiveMarks() {
    if (block.目标标记 == NULL) {
        return
    }
    # 复制列表以避免遍历时修改
    toRemove = block.目标标记.copy()
    for (mark in toRemove) {
        if (!mark.已移除) {
            block.removeObjectiveMark(mark)
        }
    }
}

function block.triggerObjectiveMarks(player) {
    if (block.目标标记 == NULL) {
        return
    }
    for (mark in block.目标标记) {
        if (!mark.已触发 && !mark.已移除) {
            # 1. 系统结算：执行标记效果（任务定义的效果函数）
            mark.标记效果(player)
            mark.已触发 = true

            # 2. 触发「触发目标标记时」trigger（通知其他技能响应）
            event = {
                player: player,
                block: block,
                mark: mark,
                cancelled: false,
            }
            player.trigger("触发目标标记时", event)
        }
    }
}
```

> **触发时机**：在 [Player.moveTo](Player.md#moveto) 节点 11 中调用（进入地块后、潜行检定之后）。
> **一次性**：标记触发后 `已触发 = true`，不会再次触发。
> **移除 vs 触发**：`已触发` 表示标记效果已执行（一次性）；`已移除` 表示标记已从地块上移除（不再参与任务胜利条件检查）。两者独立：已触发的标记仍可被移除（如任务 12 标记触发后还需用大炸药摧毁地块）；未触发的标记也可被直接移除（如炸药移除任务 9 的外星发射器标记）。

---

## 地图块类型示例

> 完整地块列表见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。

| 地块名 | 拾荒颜色 | 刷怪点数 | 关键效果 |
|--------|---------|---------|---------|
| 面包车 | — | 6 | 多数任务的出生点与结束点 |
| 避难所 | — | 12/2 | 回合开始时不在则本回合受击免疫 |
| 军事基地 | 红、蓝 | 0 | 进入时造成伤害 |
| 监狱 | 红、绿、蓝 | 9 | 进入时减行动次数 |
| 旷野 | — | 6/8 | 进入时抓怪物 |
| 森林 | — | 5/8 | 同回合内进入又离开 → 抓怪物 |
| 河流 | — | 10/11 | 进入需潜行检定，失败 → 阻止移动 |
| 游乐园 | 红、蓝、绿 | 6 | 回合结束时触发效果 |
| 百货商店 | 绿 | 9 | 展示时免费拾荒 |
| 电厂 | — | 10 | 弃置食物类牌 |
| 机场 | 红、绿 | 8 | 行动：移动到另一个已展示且无怪物标记的地块 |
| 隧道 | — | 10/4 | 行动：移动到另一个已展示的隧道地块 |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。地块技能通过 Entity 机制挂载与触发 |
| [Player](Player.md) | 玩家位于地块上；地块技能挂载到 Player 身上；玩家移动触发地块钩子 |
| [Game](../Game/Game.md) | Game 管理地图区域（所有存活地块）；Game 负责地图构建、地块查询与摧毁流程 |
| [Skill](../Common/Skill.md) | 地块技能遵循 Skill 结构 |
