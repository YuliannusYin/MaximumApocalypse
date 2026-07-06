# 事件对象（Event）

> 本文档定义游戏中所有事件对象（Event）的数据结构。
> 事件对象在 `entity.trigger(triggerName, event)` 流程中由系统构建并传给技能 content，作为技能与流程之间的上下文载体。
> 与 [EventTrigger.md](EventTrigger.md)（触发机制）、[entity.md](entity.md)（实体）、[skill.md](skill.md)（技能）配套。
> 文档创建日期：2026-07-04 · 事件结构补全日期：2026-07-07

---

## 目录

- [1. Event 基础结构](#1-event-基础结构)
- [2. 各流程的 event 成员](#2-各流程的-event-成员)
  - [2.1 伤害流程](#21-伤害流程damageflow)
  - [2.2 玩家移动流程](#22-玩家移动流程movement)
  - [2.3 抓取游戏牌流程](#23-抓取游戏牌流程draw)
  - [2.4 抓取拾荒牌流程](#24-抓取拾荒牌流程drawscavenge)
  - [2.5 抓取怪物卡流程](#25-抓取怪物卡流程drawmonster)
  - [2.6 怪物死亡流程](#26-怪物死亡流程monsterdeath)
  - [2.7 玩家死亡流程](#27-玩家死亡流程playerdeath)
  - [2.8 弃置牌流程](#28-弃置牌流程discard)
  - [2.9 销毁牌流程](#29-销毁牌流程removecard)
  - [2.10 回复生命值流程](#210-回复生命值流程recover)
  - [2.11 怪物行动流程](#211-怪物行动流程怪物攻击时)
  - [2.12 检定流程](#212-检定流程提案)
- [3. 待澄清的 event 成员](#3-待澄清的-event-成员)
- [4. event 成员命名约定](#4-event-成员命名约定)

---

## 1. Event 基础结构

**类声明**：`class_name Event extends RefCounted`
**职责**：在 `trigger`/`damage`/`draw`/`discard` 等流程中传递上下文。
**代码对齐**：[scripts/system/event.gd](../../../scripts/system/event.gd) · [docs/system-classes.md](../../../docs/system-classes.md#Event)

### 1.1 基础成员变量（已实现）

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `trigger_name` | `String` | `""` | 触发名。由 `entity.trigger()` 在循环外赋值，技能 content 内可通过 `trigger == "xxx"` 判断分支 |
| `source` | `Variant` | `null` | 事件来源。`null` 表示无来源（如饥饿伤害、中毒伤害）。伤害流程中为造成伤害的实体；移动流程中为离开的地块 |
| `target` | `Variant` | `null` | 事件目标。伤害流程中为受到伤害的实体；移动流程中为进入的地块；抓牌流程中为当前抓的牌 |
| `num` | `int` | `0` | 数值参数（伤害点数、抓牌数、回复量、计划弃置数等）。**可被钩子修改** |
| `type` | `String` | `""` | 类型标签。取值如 `"饥饿伤害"`、`"poison"` |
| `cancelled` | `bool` | `false` | 是否已取消。`cancel()` 后为 `true`，`trigger` 循环检测到后中断后续技能 |

### 1.2 公有方法

| 方法签名 | 说明 |
|----------|------|
| `cancel() -> void` | 取消事件。`trigger` 循环检测到 `cancelled` 后中断后续技能。取消后流程立即终止，已执行的钩子不回滚（[移动流程](#22-玩家移动流程movement) 会回滚地块技能为例外） |

### 1.3 设计原则

- **字段复用**：`source`/`target`/`num` 等字段在不同流程中语义不同（如移动流程中 `source` 是离开的地块、`target` 是进入的地块）。技能 content 内通过 `trigger_name` 判断当前流程上下文。
- **可变性**：`num`、`cancelled` 可被技能 content 修改；其他字段为只读上下文。
- **延迟字段**：[event.gd](../../../scripts/system/event.gd) 当前仅实现基础成员，流程相关的扩展字段（`card`/`cards`/`player`/`pile`/`result` 等）待按需添加，详见 [§2](#2-各流程的-event-成员)。

---

## 2. 各流程的 event 成员

> 每个流程在构建 Event 时会按需设置不同字段。下表列出各流程中 event 成员的语义。
> 标注 **\[待实现]** 的成员表示 [event.gd](../../../scripts/system/event.gd) 当前未声明该字段，需后续按流程需求添加。

### 2.1 伤害流程（DamageFlow）

> 调用方法：`target.damage(num, source, type=NULL)`
> 详见 [DamageFlow.md](DamageFlow.md) · [J_gameEventFlow.md §1](../../GameInstructions/J_gameEventFlow.md#1-source攻击target流程伤害结算)

| 成员 | 类型 | 说明 |
|------|------|------|
| `target` | `Entity` | 受到伤害的实体（玩家或怪物） |
| `source` | `Entity \| null` | 造成伤害的来源。`null` 表示无来源伤害（饥饿伤害、中毒伤害） |
| `num` | `int` | 伤害点数。**可被钩子修改**（"造成伤害时"加成、"受到伤害时"减免） |
| `type` | `String` | 伤害类型标签。取值如 `"饥饿伤害"`、`"poison"`，普通伤害为 `""` |
| `cancelled` | `bool` | 是否取消。"受到伤害时"节点可调用 `event.cancel()` 取消本次伤害 |
| `trigger_name` | `String` | 当前触发名：`"造成伤害前"` / `"造成伤害时"` / `"造成伤害后"` / `"受到伤害前"` / `"受到伤害时"` / `"受到伤害后"` |

> **特殊规则**：`source = null` 时跳过所有 source 侧钩子（造成伤害前/时/后），仅触发 target 侧。

### 2.2 玩家移动流程（Movement）

> 调用方法：`player.moveTo(target)`
> 详见 [Movement.md](../2_player/Movement.md) · [J_gameEventFlow.md §2](../../GameInstructions/J_gameEventFlow.md#2-玩家移动流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 移动的玩家 |
| `source` | `MapBlock` | 离开的地块（与伤害流程的 source 复用字段名，语义不同） |
| `target` | `MapBlock` | 进入的地块（与伤害流程的 target 复用字段名，语义不同） |
| `cancelled` | `bool` | 是否取消。"进入地块前"节点可调用 `event.cancel()` 取消移动 |
| `trigger_name` | `String` | 当前触发名：`"离开地块前"` / `"离开地块时"` / `"离开地块后"` / `"进入地块前"` / `"进入地块时"` / `"进入地块后"` |

> **回滚**：移动流程取消时会回滚目标地块技能（移除刚获取的目标地块技能），是唯一会回滚已执行钩子的流程。

### 2.3 抓取游戏牌流程（draw）

> 调用方法：`player.draw(n)`
> 详见 [DrawFlow.md](../DrawFlow.md) · [J_gameEventFlow.md §13](../../GameInstructions/J_gameEventFlow.md#13-抓取游戏牌流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 抓牌的玩家 |
| `num` | `int` | 计划抓取的牌数。**可被钩子修改**（"抓取游戏牌时"加摸 1 张） |
| `cards` | `Array[Card]` **\[待实现]** | 实际抓到的牌列表。"抓取游戏牌后"节点可访问 |
| `cancelled` | `bool` | 是否取消。"抓取游戏牌前"/"抓取游戏牌时"均可调用 `event.cancel()` 取消本次抓牌 |
| `trigger_name` | `String` | 当前触发名：`"抓取游戏牌前"` / `"抓取游戏牌时"` / `"抓取游戏牌后"` |

> **死亡规则**：逐张抓取，每张抓取前检查牌堆；牌堆为空时尝试抓取 → 调用 `player.playerDeath(NULL)` 并 return（跳过"抓取游戏牌后"节点）。

### 2.4 抓取拾荒牌流程（drawScavenge）

> 调用方法：`player.drawScavenge(n, pile)`
> 详见 [DrawFlow.md](../DrawFlow.md) · [J_gameEventFlow.md §10](../../GameInstructions/J_gameEventFlow.md#10-抓取拾荒牌流程提案)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 抓牌的玩家 |
| `pile` | `Pile` **\[待实现]** | 拾荒牌堆对象 |
| `num` | `int` | 计划抓取的牌数 |
| `cards` | `Array[Card]` **\[待实现]** | 实际抓到的牌列表。"抓取拾荒牌后"节点可访问 |
| `card` | `Card \| null` **\[待实现]** | 当前抓取的牌。"抓取拾荒牌时"阶段可访问（每张触发一次） |
| `cancelled` | `bool` | 是否取消。"抓取拾荒牌前"节点可调用 `event.cancel()` 取消（如手电筒替代为"看2留1放1"） |
| `trigger_name` | `String` | 当前触发名：`"抓取拾荒牌前"` / `"抓取拾荒牌时"` / `"抓取拾荒牌后"` |

> **牌堆耗尽**：牌堆为空时停止抓取（**不重洗**拾荒弃牌堆）。

### 2.5 抓取怪物卡流程（drawMonster）

> 调用方法：`player.drawMonster(num)`
> 详见 [DrawFlow.md](../DrawFlow.md) · [J_gameEventFlow.md §3](../../GameInstructions/J_gameEventFlow.md#3-玩家抓取怪物流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 抓取怪物卡的玩家 |
| `num` | `int` | 计划抓取的怪物卡数 |
| `target` | `Monster \| null` **\[待实现]** | 当前怪物卡（实体化后的怪物对象）。"抓取怪物卡时"及之后阶段可访问；"抓取怪物卡后"指向最后一张 |
| `cards` | `Array[Monster]` **\[待实现]** | 实际抓到的怪物卡列表。"抓取怪物卡后"节点可访问 |
| `cancelled` | `bool` | 是否取消。"抓取怪物卡前"节点可调用 `event.cancel()` 取消（如 firefighter「梯子」） |
| `trigger_name` | `String` | 当前触发名：`"抓取怪物卡前"` / `"抓取怪物卡时"` / `"怪物卡进入求生者怪物区前"` / `"怪物卡进入求生者怪物区时"` / `"怪物卡进入求生者怪物区后"` / `"抓取怪物卡后"` |

> **牌堆耗尽**：怪物牌堆空时重洗怪物弃牌堆；重洗后仍为空（所有怪物卡都在场上） → `game.gameOver("lose")`。
> **递归调用**：节点 5 内 zombie 一大波僵尸、僵尸步行者会递归调用 `drawMonster`。

### 2.6 怪物死亡流程（monsterDeath）

> 调用方法：`target.monsterDeath(source)`
> 详见 [DeathFlow.md](DeathFlow.md) · [J_gameEventFlow.md §4](../../GameInstructions/J_gameEventFlow.md#4-怪物死亡流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `target` | `Monster` | 死亡的怪物 |
| `source` | `Entity \| null` | 击杀者。可为 `null`（如饥饿伤害致死？实际怪物不会饥饿） |
| `trigger_name` | `String` | 当前触发名：`"死亡前"` / `"死亡时"` / `"死亡后"` |

> **trigger 别名**：「杀死怪物时」统一映射为「怪物死亡时」（见 [SurvivorPacks/gunslinger.md](../../Resource/SurvivorPacks/gunslinger.md) 搜索尸体技能）。
> **取消点**：无（死亡流程不可取消）。

### 2.7 玩家死亡流程（playerDeath）

> 调用方法：`target.playerDeath(source)`
> 详见 [DeathFlow.md](DeathFlow.md) · [J_gameEventFlow.md §5](../../GameInstructions/J_gameEventFlow.md#5-玩家死亡流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `target` | `Player` | 死亡的玩家 |
| `source` | `Entity \| null` | 击杀者。`null` 表示无来源死亡（如游戏牌堆空、饥饿致死） |
| `trigger_name` | `String` | 当前触发名：`"死亡前"` / `"死亡时"` / `"死亡后"` |

> **取消点**：无（死亡流程不可取消）。
> **触发场景**：`damage` 流程节点 8 中玩家生命值 ≤ 0；或 `draw` 流程中游戏牌堆无牌时摸牌。

### 2.8 弃置牌流程（discard）

> 调用方法：`player.discard(target, position=NULL, quantity=1, type=NULL)`
> 详见 [DiscardFlow.md](../DiscardFlow.md) · [J_gameEventFlow.md §14](../../GameInstructions/J_gameEventFlow.md#14-弃置牌流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 弃牌者 |
| `card` | `Card \| null` **\[待实现]** | 当前弃置的牌。"弃置牌时"阶段可访问（每张触发一次） |
| `cards` | `Array[Card]` **\[待实现]** | 实际弃置的牌列表。"弃置牌后"节点可访问 |
| `num` | `int` | 计划弃置数 |
| `cancelled` | `bool` | 是否取消。"弃置牌前"节点可调用 `event.cancel()` 取消本次弃牌 |
| `trigger_name` | `String` | 当前触发名：`"弃置牌前"` / `"弃置牌时"` / `"弃置牌后"` |

> **弃牌堆分派**：按卡牌 `source` 自动分派（`scavenge` → 对应颜色拾荒弃牌堆，`game` → 游戏牌弃牌堆）。

### 2.9 销毁牌流程（removeCard）

> 调用方法：`player.removeCard(target, position=NULL, quantity=1)`
> 详见 [DiscardFlow.md](../DiscardFlow.md) · [J_gameEventFlow.md §15](../../GameInstructions/J_gameEventFlow.md#15-销毁牌流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 销毁者 |
| `card` | `Card \| null` **\[待实现]** | 当前销毁的牌 |
| `cards` | `Array[Card]` **\[待实现]** | 实际销毁的牌列表 |
| `num` | `int` | 计划销毁数 |
| `cancelled` | `bool` | 是否取消。"销毁牌前"节点可调用 `event.cancel()` 取消 |
| `trigger_name` | `String` | 当前触发名：`"销毁牌前"` / `"销毁牌时"` / `"销毁牌后"` |

> **与弃置的区别**：销毁的牌不进入弃牌堆，而是移出游戏（`game.removeCard(card)`）。

### 2.10 回复生命值流程（recover）

> 调用方法：`player.recover(num)`
> 详见 [PlayerState.md](../2_player/PlayerState.md) · [J_gameEventFlow.md §16](../../GameInstructions/J_gameEventFlow.md#16-回复生命值流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 回复目标（与 `target` 复用？当前代码用 `target`，设计文档用 `player`） |
| `target` | `Player` | 回复目标（当前 [player.gd](../../../scripts/system/player.gd) 实际使用 `event.target = self`） |
| `num` | `int` | 回复量。**可被钩子修改**（"回复生命时"节点如 surgeon 手术刀·回复、手套：`event.num += 1`） |
| `cancelled` | `bool` | 是否取消（参考 [K_gameTerminology.md §7.1](../../GameInstructions/K_gameTerminology.md#71-伤害类) 标注为"否"，但保留接口以备扩展） |
| `trigger_name` | `String` | 当前触发名：`"回复生命前"` / `"回复生命时"` / `"回复生命后"` |

> **数值约束**：节点 3 系统加血时受最大生命值上限约束（`min(event.num, player.get_max_hp() - player.get_hp())`）。
> **代码差异**：[player.gd](../../../scripts/system/player.gd) 中 `recover` 实际设置 `event.target = self`，未设置 `event.player`。设计文档（J_gameEventFlow.md §16）使用 `event.player`。**待统一**。

### 2.11 怪物行动流程（怪物攻击时）

> 触发场景：玩家回合节点 17「面前怪物行动时」 → 怪物行动流程节点 4「怪物攻击时」
> 详见 [I_monsterAction.md](../../GameInstructions/I_monsterAction.md) · [J_gameEventFlow.md §9](../../GameInstructions/J_gameEventFlow.md#9-怪物行动流程)

| 成员 | 类型 | 说明 |
|------|------|------|
| `目标玩家` | `Player \| Array[Player]` **\[待实现]** | 受到怪物攻击的玩家。按射程可为单值或列表，**待澄清**，见 [§3.1](#31-event目标玩家-的单值与列表歧义) |
| `trigger_name` | `String` | 当前触发名：`"怪物行动前"` / `"怪物行动时"` / `"怪物攻击前"` / `"怪物攻击时"` / `"怪物攻击后"` / `"怪物行动后"` |

> **触发对象**：怪物行动流程的 trigger 触发对象是怪物自身（`monster.trigger(...)`），而非玩家。

### 2.12 检定流程（提案）

> 详见 [J_gameEventFlow.md §11](../../GameInstructions/J_gameEventFlow.md#11-潜行检定流程)（潜行检定）、[§12](../../GameInstructions/J_gameEventFlow.md#12-怪物出生检定流程)（怪物出生检定）

#### 2.12.1 潜行检定流程

> 调用方法：`player.sneakJudge()`

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 检定的玩家 |
| `result` | `int` **\[提案]** | 检定结果（两骰点数和） |
| `trigger_name` | `String` | 当前触发名：`"潜行检定前"` / `"潜行检定时"` / `"潜行检定后"` **\[提案]** |

> **关联技能**：robot（激光无人机）、firefighter（猎犬）、gray（科学家，可修改检定结果为失败）。

#### 2.12.2 怪物出生检定流程

> 调用方法：`player.monsterSpawnJudge()`

| 成员 | 类型 | 说明 |
|------|------|------|
| `player` | `Player` | 检定的玩家 |
| `result` | `int` **\[提案]** | 检定结果（两骰点数和） |
| `trigger_name` | `String` | 当前触发名：`"怪物出生检定前"` / `"怪物出生检定时"` / `"怪物出生检定后"` **\[提案]** |

> **注**：本流程的所有 trigger 名均为提案，尚未在技能中出现。

---

## 3. 待澄清的 event 成员

### 3.1 `event.目标玩家` 的单值与列表歧义

**调用位置**：[MonsterPacks/alien.md](../../Resource/MonsterPacks/alien.md)（外星收割者-烧毁）单值处理；[MonsterPacks/mutant.md](../../Resource/MonsterPacks/mutant.md)（狂暴的突变体）列表遍历

**问题**：怪物射程不同时攻击的玩家数量不同（"无"射程单值，"短距离"以上为列表）。`event.目标玩家` 应统一为列表（单值时长度为 1）。

详见 [待定义方法.md §9.11](../待定义方法.md#911-event目标玩家-的单值与列表歧义)。

### 3.2 `event.name` 与 `event.trigger_name` 的关系

**调用位置**：[SurvivorPacks/firefighter.md](../../Resource/SurvivorPacks/firefighter.md)（梯子）用 `event.name == "河流"`；[EventTrigger.md](EventTrigger.md) 定义 `event.trigger_name`

**问题**：`event.name` 是触发来源地块的名字？还是与 `trigger_name` 同义？需明确。

详见 [待定义方法.md §9.12](../待定义方法.md#912-eventname-与-eventtriggername-的关系)。

### 3.3 `event.player` vs `event.target` 在回复生命流程的复用

**问题**：[player.gd](../../../scripts/system/player.gd) `recover` 中设置 `event.target = self`；设计文档 [J_gameEventFlow.md §16](../../GameInstructions/J_gameEventFlow.md#16-回复生命值流程) 使用 `event.player`。

**建议**：统一为 `event.player`（与其他玩家流程对齐），代码后续轮次调整。

### 3.4 怪物事件成员 `event.玩家`

**调用位置**：[MonsterPacks/](../../Resource/MonsterPacks/) 各怪物包，trigger: "怪物卡进入求生者怪物区后"

**问题**：`event.玩家` 与 `event.player` 是否同义？应统一为 `event.player`。

详见 [待定义方法.md §6.2](../待定义方法.md#62-怪物事件成员)。

---

## 4. event 成员命名约定

| 字段名 | 类型 | 语义 | 出现流程 |
|--------|------|------|----------|
| `trigger_name` | `String` | 当前触发的触发名（代码字段名为 `trigger_name`，技能 content 内常用 `trigger` 局部变量） | 所有流程 |
| `source` | `Variant` | 来源（造成伤害的实体 / 离开的地块 / 击杀者） | 伤害、移动、死亡 |
| `target` | `Variant` | 目标（受到伤害的实体 / 进入的地块 / 当前抓的牌 / 死亡的实体） | 伤害、移动、抓牌、死亡 |
| `player` | `Player` | 流程主体玩家 | 移动、抓牌、弃置、销毁、回复生命、检定 |
| `num` | `int` | 数值参数（伤害值/抓牌数/回复量/弃置数）。可被钩子修改 | 伤害、抓牌、弃置、回复生命 |
| `type` | `String` | 类型标签 | 伤害 |
| `card` | `Card` | 当前操作的牌（"时"阶段可访问） | 抓拾荒牌、弃置、销毁 |
| `cards` | `Array[Card]` | 实际操作的牌列表（"后"阶段可访问） | 抓牌、弃置、销毁 |
| `pile` | `Pile` | 牌堆对象 | 抓拾荒牌 |
| `cancelled` | `bool` | 是否取消 | 所有有取消点的流程 |
| `result` | `int` | 检定结果 **\[提案]** | 检定 |
| `目标玩家` | `Player \| Array[Player]` | 怪物攻击的玩家 **\[待澄清]** | 怪物行动 |
| `name` | `String` | 触发来源地块名？**\[待澄清]** | firefighter 梯子 |

> **命名风格**：英文标识符用于代码字段（`trigger_name`/`source`/`target`/`num`/`card`/`cards`/`pile`/`result`）；中文标识符用于事件钩子名（`"造成伤害前"`）和部分待澄清的中文成员（`目标玩家`、`玩家`、`name`）。
