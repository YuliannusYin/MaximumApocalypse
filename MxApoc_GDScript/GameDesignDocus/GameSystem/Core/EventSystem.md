# 事件触发系统

> 游戏所有流程的钩子编排机制。
> trigger 方法定义在 [Entity.md](Entity.md#1-事件触发) 的 `entity.trigger()`。
> 本文聚焦：机制原理、event 对象规范、命名规范、全 trigger 索引。

---

## 1. 机制原理

### 1.1 触发流程

`entity.trigger(triggerName, event)` 的工作步骤：

1. 设置 `event.triggerName = triggerName`
2. 调用 `entity.getAllSkills()` 获取实体身上的所有技能
3. 遍历每个技能 `s`：
   - 将 `s.trigger` 字段按「、」分割为 triggerList（支持复合触发）
   - 若 `triggerList.contains(triggerName)` 且 `s.filter(event)` 返回 true：
     - 执行 `s.content(event)`
     - 若 `event.cancelled` 为 true，break 跳出循环

### 1.2 技能的 trigger 字段

- **单触发**：`trigger: "造成伤害时"`
- **复合触发**：`trigger: "游戏开始时、受到伤害时"`（「、」分隔，content 内用 `trigger == "xxx"` 判断分支）

### 1.3 技能执行上下文

技能 `content` 执行时可访问：

| 变量 | 说明 |
|------|------|
| `event` | 事件对象（见 [§2 event schema](#2-event-对象-schema)） |
| `trigger` | 当前触发的 trigger 名字符串（用于多触发技能分支判断） |

---

## 2. event 对象 schema

### 2.1 通用字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `triggerName` | String | 由 `trigger()` 设置，当前触发的 trigger 名 |
| `cancelled` | Bool | 是否已取消。技能调用 `event.cancel()` 后置 true |
| `cancel()` | Method | 取消当前事件。调用后流程立即终止（移动流程会回滚地块技能） |

### 2.2 按流程类型的字段

> **target 字段命名约定**：为避免歧义，不同流程使用不同字段名表达「目标」语义：
> - `event.target`：**实体目标**（伤害流程的受伤实体、死亡流程的死亡实体）
> - `event.targetBlock`：**地块目标**（移动流程的进入地块）
> - `event.card`：**当前卡牌**（抓牌流程当前抓到的牌、弃置/销毁流程当前处理的牌）
> - `event.targets`：**目标列表**（主动技能经 filter 筛选后的目标列表，复数）

| 流程 | event 字段 |
|------|-----------|
| 伤害流程 | `target`（受伤实体）、`source`（可 NULL）、`num`（可读写）、`type` |
| 回复生命 | `player`、`num`（可读写） |
| 移动流程 | `player`、`source`（离开地块）、`targetBlock`（进入地块） |
| 抓游戏牌 | `player`、`num`（可读写）、`cards`（实际抓到的牌列表） |
| 抓拾荒牌 | `player`、`pile`、`num`（可读写）、`cards`、`card`（当前牌） |
| 抓怪物卡 | `player`、`num`、`cards`、`card`（当前怪物卡，实体化后） |
| 弃置/销毁牌 | `player`、`card`（当前牌）、`cards`、`num` |
| 怪物死亡 | `target`（死亡的怪物）、`source`（击杀者） |
| 玩家死亡 | `target`（死亡的玩家）、`source`（击杀者，可 NULL） |
| 装备进入/离开 | `player`、`card` |
| 检定流程 | `player`、`sneakValue`（潜行检定阈值）、`result`（结构体 `{ value, success }`）、`skipJudge`（是否跳过投骰） |
| 摧毁地块流程 | `source`（摧毁者，可 NULL）、`block`（被摧毁的地块） |
| 触发目标标记 | `player`、`block`、`mark`（ObjectiveMark 结构，见 [MapBlock](../Entities/MapBlock.md#目标标记结构objectivemark)） |
| 主动技能 | `player`、`targets`（filter 筛选后的目标列表，复数） |

### 2.3 cancel() 语义

- 调用 `event.cancel()` 后，`event.cancelled = true`
- `trigger()` 循环立即 break，不再执行后续技能
- 流程方法检测到 `event.cancelled` 后 return，跳过后续节点
- **已执行的钩子不回滚**，例外：移动流程会回滚地块技能挂载（见 [Player.md moveTo](../Entities/Player.md#moveto) 节点 5）

---

## 3. 命名规范

### 3.1 trigger 命名模式

采用「**XX前 / XX时 / XX后**」三段式，对称包围系统结算节点：

- `XX前`：系统结算前，可取消
- `XX时`：系统结算时，可修改 event.num 等参数，部分为取消点
- `XX后`：系统结算后，仅通知

### 3.2 取消点约定

- 并非所有「时」节点都是取消点
- 取消点在「时」节点：如「受到伤害时」「抓取游戏牌时」「进入地块前」（注意「前」也可作取消点）
- 取消点完整列表见 [§4 全 trigger 索引](#4-全-trigger-索引) 的「取消点」列

### 3.3 复合触发

`trigger` 字段支持「、」分隔的多个触发名，content 内通过 `trigger == "xxx"` 判断分支。例：

```
trigger: 回合开始时、受到伤害时
content: {
    if (trigger == "回合开始时") { ... }
    else if (trigger == "受到伤害时") { ... }
}
```

---

## 4. 全 trigger 索引

> 按领域分组。标注 **[提案]** 的 trigger 名为尚未在伪代码流程中落地的提案性命名。

### 4.1 伤害类

> 所属流程：[Entity.damage](Entity.md#3-伤害流程通用)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 造成伤害前 | source 造成伤害前 | source | 否 |
| 造成伤害时 | source 造成伤害时（可修改 event.num） | source | 否 |
| 造成伤害后 | source 造成伤害后 | source | 否 |
| 受到伤害前 | target 受到伤害前 | target | 否 |
| 受到伤害时 | target 受到伤害时（可修改 event.num / cancel()） | target | **是** |
| 受到伤害后 | target 受到伤害后 | target | 否 |

> source = NULL 时跳过所有 source 侧 trigger。

### 4.2 回复类

> 所属流程：[Player.recover](../Entities/Player.md#recover)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 回复生命前 | 玩家回复生命值前 | player | 否 |
| 回复生命时 | 玩家回复生命值时（可修改 event.num） | player | 否 |
| 回复生命后 | 玩家回复生命值后 | player | 否 |

### 4.3 移动类

> 所属流程：[Player.moveTo](../Entities/Player.md#moveto)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 离开地块前 | 玩家离开当前地块前 | player | 否 |
| 离开地块时 | 玩家离开当前地块时 | player | 否 |
| 离开地块后 | 玩家离开当前地块后 | player | 否 |
| 进入地块前 | 玩家进入目标地块前（准入检定） | player | **是** |
| 进入地块时 | 玩家进入目标地块时（一次性效果） | player | 否 |
| 进入地块后 | 玩家进入目标地块后 | player | 否 |
| 展示地块时 | 地块首次翻开时（衍生） | 地块技能 | 否 |

### 4.4 怪物类

> 所属流程：[Player.drawMonster](../Entities/Player.md#drawmonster)、[Monster 行动流程](../Entities/Monster.md#行动流程)、[Monster.monsterDeath](../Entities/Monster.md#monsterdeath)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 怪物卡进入求生者怪物区前 | 怪物卡实体化前 | player | 否 |
| 怪物卡进入求生者怪物区时 | 怪物卡置入怪物区时 | player | 否 |
| 怪物卡进入求生者怪物区后 | 怪物卡已进入怪物区 | player | 否 |
| 怪物行动前 | 单个怪物行动前 | monster | 否 |
| 怪物行动时 | 单个怪物开始行动 | monster | 否 |
| 怪物行动后 | 单个怪物行动结束 | monster | 否 |
| 怪物攻击前 | 怪物攻击前 | monster | 否 |
| 怪物攻击时 | 怪物根据射程对目标发动攻击 | monster | 否 |
| 怪物攻击后 | 怪物攻击后 | monster | 否 |
| 怪物死亡前 | 怪物死亡前 | target（怪物） | 否 |
| 怪物死亡时 | 怪物死亡时（如僵尸女王、爆破机器人、方阵机器人） | target（怪物） | 否 |
| 怪物死亡后 | 怪物死亡后 | target（怪物） | 否 |
| 玩家死亡前 | 玩家死亡前 | target（玩家） | 否 |
| 玩家死亡时 | 玩家死亡时 | target（玩家） | 否 |
| 玩家死亡后 | 玩家死亡后 | target（玩家） | 否 |

### 4.5 回合类

> 所属流程：玩家回合流程（[D_gameFlow.md](../../GameInstructions/D_gameFlow.md)）

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 回合开始前 | 玩家回合开始前 | player | 否 |
| 回合开始时 | 玩家回合开始时 | player | 否 |
| 怪物出生前 | 怪物出生检定前 | player | 否 |
| 怪物出生时 | 怪物出生检定时 | player | 否 |
| 摸牌阶段前 | 摸牌阶段前 | player | 否 |
| 行动阶段前 | 行动阶段前 | player | 否 |
| 行动阶段结束前 | 行动阶段结束前 | player | 否 |
| 行动阶段结束时 | 行动阶段结束时 | player | 否 |
| 求生者饥饿状态结算前 | 饥饿结算前 | player | 否 |
| 求生者饥饿状态结算时 | 饥饿结算时 | player | 否 |
| 求生者中毒状态结算前 | 中毒结算前 | player | 否 |
| 求生者中毒状态结算时 | 中毒结算时 | player | 否 |
| 面前怪物行动前 | 面前怪物行动前 | player | 否 |
| 面前怪物行动时 | 面前怪物行动时 | player | 否 |
| 回合结束前 | 玩家回合结束前 | player | 否 |
| 回合结束时 | 玩家回合结束时 | player | 否 |

### 4.6 抓牌类

> 所属流程：[Player.draw](../Entities/Player.md#draw) / [drawScavenge](../Entities/Player.md#drawscavenge) / [drawMonster](../Entities/Player.md#drawmonster)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 抓取游戏牌前 | 抓取游戏牌前 | player | **是** |
| 抓取游戏牌时 | 抓取游戏牌时（可修改 event.num） | player | **是** |
| 抓取游戏牌后 | 抓取游戏牌后 | player | 否 |
| 抓取怪物卡前 | 抓取怪物卡前 | player | **是** |
| 抓取怪物卡时 | 抓取怪物卡时（每张触发一次） | player | 否 |
| 怪物卡进入求生者怪物区前 | 见 4.4 | player | 否 |
| 怪物卡进入求生者怪物区时 | 见 4.4 | player | 否 |
| 怪物卡进入求生者怪物区后 | 见 4.4 | player | 否 |
| 抓取怪物卡后 | 抓取怪物卡后（整体触发一次） | player | 否 |
| 抓取拾荒牌前 | 抓取拾荒牌前 | player | **是** |
| 抓取拾荒牌时 | 抓取拾荒牌时（每张牌触发一次） | player | 否 |
| 抓取拾荒牌后 | 抓取拾荒牌后 | player | 否 |

### 4.7 使用卡牌类

> 所属流程：[Player.useCard](../Entities/Player.md#usecardcard)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 使用卡牌前 | 从手牌使用卡牌前 | player | **是** |
| 使用卡牌时 | 从手牌使用卡牌时（装备牌/行动牌分流的最后拦截点） | player | **是** |
| 使用卡牌后 | 从手牌使用卡牌后（整体触发一次） | player | 否 |

### 4.8 装备类

> 所属流程：[Player.装备](../Entities/Player.md#装备card) / [Player.卸下](../Entities/Player.md#卸下card) / [Player.消耗填充物](../Entities/Player.md#消耗填充物equipment-num)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 卡牌进入装备区前 | 装备进入装备区前 | player | **是** |
| 卡牌进入装备区时 | 装备置入装备区时 | player | 否 |
| 卡牌进入装备区后 | 装备进入装备区后 | player | 否 |
| 卡牌离开装备区前 | 装备离开装备区前 | player | **是** |
| 卡牌离开装备区时 | 装备离开装备区时 | player | 否 |
| 卡牌离开装备区后 | 装备离开装备区后 | player | 否 |
| 消耗填充物前 | 装备填充物消耗前 | player | **是** |
| 消耗填充物时 | 装备填充物消耗时（可修改 event.num） | player | **是** |
| 消耗填充物后 | 装备填充物消耗后 | player | 否 |
| 填充物耗尽时 | 装备填充物耗尽时（衍生） | player | 否 |

### 4.9 检定类

> 所属流程：[Player.sneakJudge](../Entities/Player.md#sneakjudge) / [Player.monsterSpawnJudge](../Entities/Player.md#monsterspawnjudge)
> **event.result 类型**：结构体 `{ value: 骰子点数, success: 布尔值 }`（怪物出生检定的 success 无意义，恒为 true）
> **跳过投骰**：技能在「前」节点设置 `event.skipJudge = true` + `event.result = { value, success }` 可跳过投骰并指定结果
> **修改结果**：技能在「时」节点可直接赋值 `event.result = { value, success }` 覆盖投骰结果

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 潜行检定前 | 潜行检定前（可设置 skipJudge 跳过投骰） | player | 否 |
| 潜行检定时 | 潜行检定执行时（可修改 event.result） | player | 否 |
| 潜行检定后 | 潜行检定结果出来后 | player | 否 |
| 怪物出生检定前 | 怪物出生检定前（可设置 skipJudge 跳过投骰） | player | 否 |
| 怪物出生检定时 | 怪物出生检定执行时（可修改 event.result） | player | 否 |
| 怪物出生检定后 | 怪物出生检定结果出来后 | player | 否 |

### 4.10 弃牌类

> 所属流程：[Player.discard](../Entities/Player.md#discard)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 弃置牌前 | 弃置牌前（整体一次） | player | **是** |
| 弃置牌时 | 弃置牌时（每张触发一次） | player | 否 |
| 弃置牌后 | 弃置牌后（整体一次） | player | 否 |

### 4.11 销毁类

> 所属流程：[Player.removeCard](../Entities/Player.md#removecard)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 销毁牌前 | 销毁牌前（整体一次） | player | **是** |
| 销毁牌时 | 销毁牌时（每张触发一次） | player | 否 |
| 销毁牌后 | 销毁牌后（整体一次） | player | 否 |

### 4.12 游戏类

> 所属流程：[Game.startGame](../Game/Game.md#startgame) / [Game.gameOver](../Game/Game.md#gameoverresult)

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 游戏开始时 | 游戏开局时（抓初始怪物卡后、第一玩家回合前） | player | 否 |
| 游戏结束时 | 游戏结束时（gameOver 设置状态后） | player | 否 |

### 4.13 地图类

> 所属流程：[Game.destroyMapBlock](../Game/Game.md#destroymapblockblock-source) / [Player.moveTo](../Entities/Player.md#moveto) 节点 11

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| 摧毁地块前 | 地块被摧毁前 | 所有 player（按座位顺序） | **是** |
| 摧毁地块时 | 地块摧毁系统结算时（玩家已弹出、怪物标记已消灭、状态未变更） | 所有 player | 否 |
| 摧毁地块后 | 地块摧毁完成后（地块已从地图区域移除） | 所有 player | 否 |
| 触发目标标记时 | 玩家进入地块且触发未触发的目标标记后 | player | 否 |

> **摧毁地块类 trigger**：Game 类不继承 Entity，通过遍历 `game.所有玩家` 调用 `player.trigger()` 实现。event 字段：`source`（摧毁者，可 NULL）、`block`（被摧毁的地块）。
> **触发目标标记时**：在 [Player.moveTo](../Entities/Player.md#moveto) 节点 11 中触发。event 字段：`player`、`block`、`mark`（ObjectiveMark 结构）。标记效果在 trigger 之前由系统结算执行，trigger 仅作通知。

---

## 5. 与其他文档的关系

| 文档 | 关系 |
|------|------|
| [Entity.md](Entity.md) | `entity.trigger()` 方法定义处 |
| [Player.md](../Entities/Player.md) | Player 类的流程方法定义各 trigger 的触发节点 |
| [Monster.md](../Entities/Monster.md) | Monster 类的死亡/行动/攻击 trigger |
| [Skill.md](../Common/Skill.md) | Skill 结构的 `trigger` 字段引用本文的 trigger 名 |
| [J_gameEventFlow.md](../../GameInstructions/J_gameEventFlow.md) | GameInstructions 侧的事件流程汇总，本文为其源定义 |
| [K_gameTerminology.md](../../GameInstructions/K_gameTerminology.md) | 术语表的 trigger 索引，本文为其权威来源 |
