# 游戏事件流程

> 本文档汇总游戏所有主要事件流程的 trigger 名与节点说明。
> 完整规则详见各流程引用的源文件（[GameSystem/](../GameSystem/) 与 [GameInstructions/](.)）。
> 标注 **\[提案]** 的 trigger 名为尚未在 GameSystem/ 中定义的提案性命名，供后续实现参考。
> 文档创建日期：2026-07-04

***

## 目录

- [1. source攻击target流程（伤害结算）](#1-source攻击target流程伤害结算)
- [2. 玩家移动流程](#2-玩家移动流程)
- [3. 玩家抓取怪物流程](#3-玩家抓取怪物流程)
- [4. 怪物死亡流程](#4-怪物死亡流程)
- [5. 玩家死亡流程](#5-玩家死亡流程)
- [6. 使用卡牌流程](#6-使用卡牌流程)
- [7. 装备进入装备区流程](#7-装备进入装备区流程)
- [8. 装备离开装备区流程](#8-装备离开装备区流程)
- [9. 填充物消耗流程](#9-填充物消耗流程)
- [10. 玩家回合流程](#10-玩家回合流程)
- [11. 怪物行动流程](#11-怪物行动流程)
- [12. 抓取拾荒牌流程](#12-抓取拾荒牌流程提案)
- [13. 潜行检定流程](#13-潜行检定流程)
- [14. 怪物出生检定流程](#14-怪物出生检定流程)
- [15. 抓取游戏牌流程](#15-抓取游戏牌流程)
- [16. 弃置牌流程](#16-弃置牌流程)
- [17. 销毁牌流程](#17-销毁牌流程)
- [18. 回复生命值流程](#18-回复生命值流程)
- [19. 游戏开始流程](#19-游戏开始流程)
- [20. 游戏结束流程](#20-游戏结束流程)
- [21. 摧毁地块流程](#21-摧毁地块流程)

***

## 1. source攻击target流程（伤害结算）

> **定义位置**：[GameSystem/Core/Entity.md](../GameSystem/Core/Entity.md)
> **调用方法**：`target.damage(num, source, type=NULL)`
> **取消点**：节点 4「受到伤害时」可调用 `event.cancel()`
> **特殊规则**：source = NULL 时跳过所有 source 侧钩子（节点 1/3/6），仅触发 target 侧

| 节点 | trigger 名 | 触发对象   | 说明                                                               |
| -- | --------- | ------ | ---------------------------------------------------------------- |
| 1  | 造成伤害前     | source | source != NULL 时触发                                               |
| 2  | 受到伤害前     | target | 始终触发（含无来源伤害）                                                     |
| 3  | 造成伤害时     | source | source != NULL 时触发；可修改 `event.num`（伤害加成）                         |
| 4  | 受到伤害时     | target | **取消点**；可修改 `event.num`（伤害减免）或调用 `event.cancel()`                |
| 5  | （系统扣血）    | —      | `target.生命值 -= event.num`，非钩子节点                                  |
| 6  | 造成伤害后     | source | source != NULL 时触发                                               |
| 7  | 受到伤害后     | target | 始终触发（含无来源伤害）                                                     |
| 8  | （死亡判定）    | —      | `target.生命值 <= 0` → 进入 [玩家死亡流程](#5-玩家死亡流程) 或 [怪物死亡流程](#4-怪物死亡流程) |

**event 成员**：`event.target`、`event.source`（可为 NULL）、`event.num`（可读写）、`event.type`、`event.card`（可为 NULL，造成伤害的武器牌，供「造成伤害时」filter 判断）、`event.cancelled`、`event.cancel()`

***

## 2. 玩家移动流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.moveTo(target)`
> **取消点**：节点 5「进入地块前」可调用 `event.cancel()`，取消时回滚目标地块技能
> **核心原则**：所有地块技能挂载到玩家身上，由 `player.trigger()` 统一触发

| 节点 | trigger 名  | 说明                                        |
| -- | ---------- | ----------------------------------------- |
| 1  | 离开地块前      | 玩家离开当前地块前触发                               |
| 2  | 离开地块时      | 如森林：同回合内进入又离开 → 抓怪物                       |
| 3  | 离开地块后      | 离开完成                                      |
| 4  | （获取目标地块技能） | `player.获取地块技能(target)`，将目标地块技能挂载到玩家      |
| 5  | 进入地块前      | **取消点**；准入检定（如河流：潜行失败 → `event.cancel()`） |
| 6  | （移动时）      | 坐标变更：`player.moveToMapBlock(target)`      |
| 7  | （清理旧地块技能）  | `source.清除技能(player)`，移动成功后才清理            |
| 8  | 进入地块时      | 一次性进入效果（军事基地造成伤害、监狱减行动、旷野抓怪物等）            |
| 9  | 进入地块后      | 展示未展示的地块（触发「展示地块时」）；player.trigger        |
| 10 | （潜行检定）     | 目标地块有怪物标记时进行潜行检定，失败 → 移除标记并抓怪物            |
| 11 | 触发目标标记时    | 玩家进入地块且触发未触发的目标标记后；`target.triggerObjectiveMarks(player)`，每张未触发标记调用一次标记效果 |

**衍生 trigger**：

- `展示地块时`：节点 9 中地块首次翻开时触发（地块技能）
- `触发目标标记时`：节点 11 中触发目标标记后触发（player.trigger）；典型场景：任务目标收集、日志记录（见 [任务包](../Resource/MissionPacks/) basic-mission_10、basic-mission_12）

**event 成员**：`event.player`、`event.source`（离开的地块）、`event.targetBlock`（进入的地块）、`event.cancelled`、`event.cancel()`

> **节点 11 衍生 event**（触发目标标记时）：`event.player`、`event.block`、`event.mark`（ObjectiveMark 结构）、`event.cancelled`

***

## 3. 玩家抓取怪物流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.drawMonster(n)`
> **取消点**：节点 1「抓取怪物卡前」可调用 `event.cancel()`（firefighter「梯子」在此取消跳过抓怪）
> **牌堆耗尽**：怪物牌堆空时重洗怪物弃牌堆；重洗后仍为空 → `game.gameOver("lose")`（见 [C\_gameSetup.md](C_gameSetup.md)）
> **实体化**：每张怪物卡在节点 3-4 之间实体化（设置纠缠对象、初始化生命值）
> **递归调用**：节点 5 内 zombie 一大波僵尸、僵尸步行者会递归调用 drawMonster

| 节点 | trigger 名    | 触发对象   | 说明                                                 |
| -- | ------------ | ------ | -------------------------------------------------- |
| 1  | 抓取怪物卡前       | player | **取消点**；如 firefighter「梯子」(event.cancel() 跳过抓怪)     |
| 2  | 抓取怪物卡时       | player | 每张触发；抓取动作执行                                        |
| 3  | 怪物卡进入求生者怪物区前 | player | 每张触发；怪物卡实体化前                                       |
| 4  | 怪物卡进入求生者怪物区时 | player | 每张触发；实体化后置入怪物区                                     |
| 5  | 怪物卡进入求生者怪物区后 | player | 每张触发；如 zombie(一大波僵尸、僵尸步行者)、alien/robot/mutant 多处技能 |
| 6  | 抓取怪物卡后       | player | 整体触发一次；如 mechanic「感应地雷」(对 event.card 造成伤害)       |

**event 成员**：`event.player`（抓取者）、`event.card`（当前怪物卡，实体化后的怪物对象）、`event.num`（可读写）、`event.cards`（实际抓到的怪物卡列表）、`event.cancelled`、`event.cancel()`

> **注**：节点 2-5 每张怪物卡触发一次（逐张走完整流程后抓下一张）；节点 6 整体触发一次。节点 1 的取消点对应 firefighter「梯子」技能（原 J 骨架误记为「感应地雷」，感应地雷实际属于 mechanic，trigger 为节点 6）。

***

## 4. 怪物死亡流程

> **定义位置**：[GameSystem/Entities/Monster.md](../GameSystem/Entities/Monster.md)
> **调用方法**：`target.monsterDeath(source)`
> **取消点**：无（死亡流程不可取消）
> **触发场景**：`target.damage` 流程节点 8 中怪物生命值 ≤ 0

| 节点 | trigger 名 | 触发对象       | 说明                                         |
| -- | --------- | ---------- | ------------------------------------------ |
| 1  | 怪物死亡前       | target（怪物） | 死亡前最后时机                                    |
| 2  | 怪物死亡时       | target（怪物） | 触发怪物死亡事件；如 zombie（僵尸女王）、robot（爆破机器人、方阵机器人） |
| 3  | （清理）      | —          | 将怪物卡从纠缠玩家怪物区移除，置入怪物弃牌堆                     |
| 4  | 怪物死亡后       | target（怪物） | 死亡完成                                       |

**event 成员**：`event.target`（死亡的怪物）、`event.source`（击杀者）

> **注意**：地图块/技能效果「弃置怪物」（如 hunter 迷彩服）为纯移除，不触发怪物死亡流程。

***

## 5. 玩家死亡流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`target.playerDeath(source)`
> **取消点**：无（死亡流程不可取消）
> **触发场景**：`target.damage` 流程节点 8 中玩家生命值 ≤ 0；或游戏牌堆无牌时摸牌（见 [G\_gameOver.md](G_gameOver.md)）

| 节点 | trigger 名 | 触发对象       | 说明                                                   |
| -- | --------- | ---------- | ---------------------------------------------------- |
| 1  | 玩家死亡前       | target（玩家） | 死亡前最后时机                                              |
| 2  | 玩家死亡时       | target（玩家） | 死亡事件触发                                               |
| 3  | （清理怪物区）   | —          | 怪物区怪物 → 弃牌堆，等量怪物标记（最多3个）放回地块                         |
| 4  | （清理游戏牌）   | —          | 所有求生者游戏牌移出游戏（手牌+装备+牌堆+弃牌堆）                           |
| 5  | （清理拾荒卡）   | —          | 拾荒卡按颜色洗回对应拾荒牌堆，各色分别洗牌                                |
| 6  | 玩家死亡后       | target（玩家） | 死亡完成                                                 |
| 7  | （全灭判定）    | —          | `game.allPlayersDead()` 为真 → `game.gameOver("lose")` |

**event 成员**：`event.target`（死亡的玩家）、`event.source`（击杀者，可为 NULL）

***

## 6. 使用卡牌流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md) §七 useCard
> **调用方法**：`player.useCard(card)`
> **使用规则**：[H_useCard.md](H_useCard.md)
> **取消点**：节点 1/2 均可调用 `event.cancel()`
> **行动次数**：useCard 统一消耗 1 点行动次数（装备牌和行动牌均消耗）
> **卡牌分流**：装备牌 → 调用 `player.装备(card)` 进入装备区；行动牌 → 技能系统独立执行 content 后弃掉

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 使用卡牌前 | player | **取消点**；可校验行动次数、手牌合法性 |
| 2 | 使用卡牌时 | player | **取消点**；装备牌/行动牌分流的最后拦截点 |
| 3 | （系统结算） | — | 扣 1 点行动次数 → 按类型分流（装备/行动），非钩子节点 |
| 4 | 使用卡牌后 | player | 整体触发一次 |

**event 成员**：`event.player`、`event.card`、`event.cancelled`、`event.cancel()`

> **装备牌分流**：节点 3 中装备牌调用 `player.装备(card)`（见 [§7 装备进入装备区流程](#7-装备进入装备区流程)），装备栏容量校验失败时由 `装备()` 内部取消并提示。
> **行动牌分流**：节点 3 中行动牌的技能 content 由技能系统独立执行（useCard 不直接调用 `card.技能.content()`），执行后调用 `player.discard(card)` 弃掉（按 `card.source` 分派弃牌堆，见 [§16 弃置牌流程](#16-弃置牌流程)）。

***

## 7. 装备进入装备区流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md) §八 装备(card)
> **调用方法**：`player.装备(card)`
> **取消点**：节点 1 可调用 `event.cancel()`
> **系统预校验**（节点 1 之后、节点 2 之前，非钩子节点）：同名装备校验（弃置同名装备）+ 装备栏容量校验（玩家选择弃置装备直到能容下，无法容下则取消装备并提示）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 卡牌进入装备区前 | player | **取消点** |
| — | （系统预校验） | — | 同名装备校验 + 装备栏容量校验，非钩子节点 |
| 2 | 卡牌进入装备区时 | player | 装备置入装备区 + 技能挂载 |
| 3 | 卡牌进入装备区后 | player | 装备进入完成 |

**event 成员**：`event.player`、`event.card`、`event.cancelled`、`event.cancel()`

> **关联技能**：[SurvivorPacks/gunslinger.md](../Resource/SurvivorPacks/gunslinger.md)、[SurvivorPacks/hunter.md](../Resource/SurvivorPacks/hunter.md)、[ScavengePacks/blue.md](../Resource/ScavengePacks/blue.md)（背包增加装备栏）、[SurvivorPacks/veteran.md](../Resource/SurvivorPacks/veteran.md) 均含 trigger「卡牌进入装备区时」

***

## 8. 装备离开装备区流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md) §八 卸下(card)
> **调用方法**：`player.卸下(card)`
> **取消点**：节点 1 可调用 `event.cancel()`
> **调用场景**：`player.discard(card)` 检测到牌在装备区时先调用卸下；装备流程中同名装备校验也通过 discard 调用卸下

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 卡牌离开装备区前 | player | **取消点** |
| 2 | 卡牌离开装备区时 | player | 从装备区移除 + 技能移除 |
| 3 | 卡牌离开装备区后 | player | 装备离开完成 |

**event 成员**：`event.player`、`event.card`、`event.cancelled`、`event.cancel()`

***

## 9. 填充物消耗流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md) §九 消耗填充物(equipment, num)
> **调用方法**：`player.消耗填充物(equipment, num)`（equipment 为装备对象，需先通过 `player.getEquipment(name)` 获取）
> **取消点**：节点 1、2 可调用 `event.cancel()`
> **填充物不足**：`equipment.填充物当前量 < num` 时取消执行并提示（不扣减、不触发任何 trigger）
> **调用场景**：装备技能消耗弹药/燃料时调用（如手枪、打火机、摩托车、空尖弹特殊弹药等）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 消耗填充物前 | player | **取消点** |
| 2 | 消耗填充物时 | player | **取消点**；可修改 event.num |
| 3 | （系统扣减） | — | `equipment.填充物当前量 -= event.num` |
| 4 | 消耗填充物后 | player | 消耗完成 |
| 5 | 填充物耗尽时 | player | **衍生**：扣减后若 `填充物当前量 <= 0` 则触发 |

**event 成员**：`event.player`、`event.equipment`、`event.card`（同 event.equipment）、`event.num`、`event.cancelled`、`event.cancel()`

> **典型应用**：
>
> - `填充物耗尽时`：gunslinger 空尖弹 subSkill remove 在此弃置武器牌（见 [SurvivorPacks/gunslinger.md](../Resource/SurvivorPacks/gunslinger.md)）

***

## 10. 玩家回合流程

> **规则定义**：[D\_gameFlow.md](D_gameFlow.md)（玩家可读规则）
> **实现位置**：[Player.开始回合()](../GameSystem/Entities/Player.md#十回合流程)（线性 21 节点流程，由 [GameStateMachine.nextTurn()](../GameSystem/Core/GameStateMachine.md#nextturn) 调用）
> **本文档仅列 trigger 名 + 节点说明**，详细阶段说明与伪代码见源文件

| 节点 | trigger 名  | 说明                                                            |
| -- | ---------- | ------------------------------------------------------------- |
| 1  | （进入玩家回合）   | 非钩子节点。重置行动次数与回合临时标记，`inPhase = "回合开始"`                        |
| 2  | 回合开始前      | 回合开始前触发                                                       |
| 3  | 回合开始时      | 回合开始；如 MapBlocks（避难所、电厂）                                      |
| 4  | 怪物出生前      | 怪物出生检定前。`inPhase = "怪物出生"`                                    |
| 5  | 怪物出生时      | 进行怪物出生检定（见 [怪物出生检定流程](#14-怪物出生检定流程)）                          |
| 6  | 摸牌阶段前      | 摸牌前。`inPhase = "摸牌阶段"`                                        |
| 7  | （摸牌阶段）     | 从游戏牌堆抓 1 张牌；牌堆空 → 玩家死亡                                        |
| 8  | 行动阶段前      | 行动阶段前；含潜行检定（地块有怪物标记时，检定在 trigger 之前执行）。`inPhase = "行动阶段"`     |
| 9  | （行动阶段）     | 执行 4 个行动 + 免费行动（制衡、交易）                                        |
| 10 | 行动阶段结束前    | 行动阶段结束前；如 gunslinger（扣动扳机让我快乐 subSkill）                       |
| 11 | 行动阶段结束时    | 行动阶段结束                                                        |
| 12 | 求生者饥饿状态结算前 | 饥饿结算前；如 firefighter（野地夹克 subSkill）。`inPhase = "饥饿结算"`         |
| 13 | 求生者饥饿状态结算时 | `player.increaseHunger(1)`                                    |
| 14 | 求生者中毒状态结算前 | 中毒结算前。`inPhase = "中毒结算"`                                      |
| 15 | 求生者中毒状态结算时 | `player.poison()`（有中毒标记时）                                     |
| 16 | 面前怪物行动前    | 面前怪物行动前。`inPhase = "怪物行动"`                                    |
| 17 | 面前怪物行动时    | 面前怪物按进入顺序行动（见 [怪物行动流程](#11-怪物行动流程)）                            |
| 18 | 回合结束前      | 回合结束前；如 gunslinger（扣动扳机让我快乐 subSkill）、MapBlocks（游乐园、警察局、城市街道）。`inPhase = "回合结束"` |
| 19 | 回合结束时      | 回合结束；如 MapBlocks（游乐园）                                         |
| 20 | （退出玩家回合）   | 非钩子节点。`inPhase = "回合外"`                                       |
| 21 | （胜利判定）     | 由 [GameStateMachine.checkWinCondition()](../GameSystem/Core/GameStateMachine.md#checkwincondition) 在 `开始回合()` 返回后执行，不在玩家流程内 |

> **死亡中断**：玩家可能在节点 7（牌堆空）、13（饥饿伤害致死）、15（中毒伤害致死）、17（怪物攻击致死）后死亡，死亡后立即 return，后续节点不再执行。
> **trigger 触发对象**：所有 trigger 均为 `player.trigger`（玩家身上的技能，含已挂载的地块技能）。

***

## 11. 怪物行动流程

> **定义位置**：[I\_monsterAction.md](I_monsterAction.md)（完整规则）
> **触发场景**：玩家回合节点 17「面前怪物行动时」；按怪物卡进入怪物区的先后顺序行动

| 节点 | trigger 名 | 触发对象    | 说明                                                               |
| -- | --------- | ------- | ---------------------------------------------------------------- |
| 1  | 怪物行动前     | monster | 单个怪物行动前                                                          |
| 2  | 怪物行动时     | monster | 怪物开始行动                                                           |
| 3  | 怪物攻击前     | monster | 攻击前                                                              |
| 4  | 怪物攻击时     | monster | 根据射程对目标发动攻击；如 alien（外星收割者、外星指挥官、外星入侵者、外星飞船）、mutant（狂暴的突变体、突变体老鼠） |
| 5  | 怪物攻击后     | monster | 攻击后；如 zombie（僵尸潜行者）                                              |
| 6  | 怪物行动后     | monster | 单个怪物行动结束                                                         |

**event 成员**：`event.目标玩家`（受攻击玩家列表，统一为 `List<Player>`；射程「无」时列表只含 1 个元素，其他射程时含多个元素；技能 content 内用 `for 目标玩家 in event.目标玩家` 遍历）

> **注**：「怪物行动前/时/后」与玩家回合流程中的「面前怪物行动前/时」是不同层级的 trigger。前者是单个怪物级别的 trigger，后者是玩家回合阶段级别的 trigger。

***

## 12. 抓取拾荒牌流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.drawScavenge(n, pile)`
> **取消点**：节点 1「抓取拾荒牌前」可调用 `event.cancel()`（手电筒在此取消并替代为「看2留1放1」）
> **牌堆耗尽**：牌堆为空时停止抓取（不重洗弃牌堆，见 [C\_gameSetup.md](C_gameSetup.md)）
> **关联技能**：[ScavengePacks/blue.md](../Resource/ScavengePacks/blue.md)（手电筒 trigger「抓取拾荒牌前」）、[ScavengePacks/red.md](../Resource/ScavengePacks/red.md)（燃料 trigger「抓取拾荒牌时」）、[ScavengePacks/gray.md](../Resource/ScavengePacks/gray.md)（一无所获、伏击！trigger「抓取拾荒牌时」）

| 节点 | trigger 名 | 触发对象   | 说明                                                       |
| -- | --------- | ------ | -------------------------------------------------------- |
| 1  | 抓取拾荒牌前    | player | 取消点；如 blue（手电筒，event.cancel() 替代为「看2留1放1」）               |
| 2  | （逐张抓取）    | —      | 抓1张→入手牌区→触发「时」→抓下一张；牌堆空则停止                               |
| 3  | 抓取拾荒牌时    | player | 每张牌触发一次；如 red（燃料：装备或弃掉）、gray（一无所获：弃掉；伏击！：drawMonster+弃掉） |
| 4  | 抓取拾荒牌后    | player | 所有牌抓取完成                                                  |

**event 成员**：`event.player`、`event.pile`（拾荒牌堆对象）、`event.num`（可读写）、`event.cards`（实际抓到的牌列表）、`event.card`（当前抓取的牌，「时」阶段可访问）、`event.cancelled`、`event.cancel()`

> **注**：pile 参数统一为 pile 对象（颜色字符串通过 `game.getScavengePile(颜色)` 转换）。手牌上限由上层校验。

***

## 13. 潜行检定流程

> **定义位置**：[E\_gameJudge.md](E_gameJudge.md)（流程说明）、[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)（方法定义）
> **调用方法**：`player.sneakJudge()`
> **触发场景**：玩家进入有怪物标记的地块时（[移动流程](#2-玩家移动流程) 节点 10）；玩家回合行动阶段前（地块有怪物标记时）
> **检定公式**：潜行值 = 玩家潜行值 - (地块怪物数 + 怪物标记数)；检定结果 ≤ 潜行值则成功
> **event.result 类型**：结构体 `{ value: 骰子点数, success: 布尔值 }`

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 潜行检定前 | player | 技能可设置 `skipJudge=true` + `result={...}` 跳过投骰；如 robot（激光无人机）、firefighter（猎犬，河流地块自动通过） |
| 2 | （系统投骰） | — | 若未跳过：投骰并计算 result；若跳过：使用技能指定的 result |
| 3 | 潜行检定时 | player | 技能可修改 event.result；如 gray（科学家，设为失败） |
| 4 | 潜行检定后 | player | 非取消点；可查询 event.result |

**event 成员**：`event.player`、`event.sneakValue`（检定阈值）、`event.result`（结构体 `{ value, success }`）、`event.skipJudge`（布尔值，是否跳过投骰）

> **失败处理**：由调用方负责（如 moveTo 节点 10：移除所有怪物标记，每移除一个抓一张怪物卡）。sneakJudge() 返回 `event.result.success`。

***

## 14. 怪物出生检定流程

> **定义位置**：[E\_gameJudge.md](E_gameJudge.md)（流程说明）、[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)（方法定义）
> **调用方法**：`player.monsterSpawnJudge()`
> **触发场景**：玩家回合节点 5「怪物出生时」
> **检定规则**：投两颗大骰子，匹配已展示地块的 monster_spawn_value
> **event.result 类型**：结构体 `{ value: 骰子点数, success: 布尔值 }`（success 无意义，恒为 true）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 怪物出生检定前 | player | 技能可设置 `skipJudge=true` + `result={...}` 跳过投骰 |
| 2 | （系统投骰） | — | 若未跳过：投骰并计算 result；若跳过：使用技能指定的 result |
| 3 | 怪物出生检定时 | player | 技能可修改 event.result |
| 4 | 怪物出生检定后 | player | 非取消点；可查询 event.result |
| 5 | （结果处理） | — | 匹配地块：标记 < 3 → +1 标记；标记 = 3 且有玩家 → 每位玩家抓 1 怪物 |

**event 成员**：`event.player`、`event.result`（结构体 `{ value, success }`，success 无意义）、`event.skipJudge`（布尔值，是否跳过投骰）

> **注**：D_gameFlow.md 中的「怪物出生前/时」是玩家回合阶段级别的 trigger，与此处的检定流程 trigger 不同层级。

***

## 15. 抓取游戏牌流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.draw(n)`
> **取消点**：节点 1「抓取游戏牌前」、节点 2「抓取游戏牌时」均可调用 `event.cancel()`
> **死亡规则**：逐张抓取，每张抓取前检查牌堆；牌堆为空时尝试抓取 → 调用 `player.playerDeath(NULL)` 并 return（跳过节点 4）

| 节点 | trigger 名 | 触发对象   | 说明                                                             |
| -- | --------- | ------ | -------------------------------------------------------------- |
| 1  | 抓取游戏牌前    | player | 取消点；可调用 `event.cancel()` 取消本次抓牌                                |
| 2  | 抓取游戏牌时    | player | 取消点；可修改 `event.num`（如技能加摸 1 张），可调用 `event.cancel()`            |
| 3  | （逐张抓取）    | —      | 每张抓取前检查牌堆，牌堆为空 → `playerDeath(NULL)` 并 return；否则从游戏牌堆抓 1 张到手牌区 |
| 4  | 抓取游戏牌后    | player | 所有牌抓取完成；可访问 `event.cards`（实际抓到的牌列表）                            |

**event 成员**：`event.player`、`event.num`（可读写）、`event.cards`（实际抓到的牌列表）、`event.cancelled`、`event.cancel()`

> **注**：手牌上限（10 张）由上层校验，draw() 不处理。牌堆不足 n 张时逐张抓取，抓到剩余牌后下一次尝试抓取时触发死亡。

***

## 16. 弃置牌流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.discard(target, position=NULL, quantity=1, type=NULL)`
> **取消点**：节点 1「弃置牌前」可调用 `event.cancel()`
> **重载签名**：target 支持 card 对象 / cards 列表 / name 字符串 / type 字符串（type 参数非空时按 `card.类型` 弃置）
> **弃牌堆分派**：按卡牌 source 自动分派（scavenge → 对应颜色拾荒弃牌堆，game → 游戏牌弃牌堆）

| 节点 | trigger 名 | 触发对象   | 说明                                  |
| -- | --------- | ------ | ----------------------------------- |
| 1  | 弃置牌前      | player | **取消点**；可调用 `event.cancel()` 取消本次弃牌 |
| 2  | 弃置牌时      | player | 每张触发；从原位置移除 → 进入对应弃牌堆 → 触发          |
| 3  | 弃置牌后      | player | 整体触发一次                              |

**event 成员**：`event.player`（弃牌者）、`event.card`（当前弃置的牌，「时」阶段可访问）、`event.cards`（实际弃置的牌列表）、`event.num`（计划弃置数）、`event.cancelled`、`event.cancel()`

> **注**：多张弃置时逐张触发「弃置牌时」（与 drawScavenge/drawMonster 模式对齐）。position=NULL 时搜索所有区域（手牌区+装备区）。

***

## 17. 销毁牌流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.removeCard(target, position=NULL, quantity=1)`
> **取消点**：节点 1「销毁牌前」可调用 `event.cancel()`
> **与弃置的区别**：销毁的牌不进入弃牌堆，而是移出游戏（调用 `game.removeCard(card)`）
> **命名统一**：原 MapBlocks(坠毁点) 的 `player.remove(card)` 已统一为 `player.removeCard(card)`

| 节点 | trigger 名 | 触发对象   | 说明                                  |
| -- | --------- | ------ | ----------------------------------- |
| 1  | 销毁牌前      | player | **取消点**；可调用 `event.cancel()` 取消本次销毁 |
| 2  | 销毁牌时      | player | 每张触发；从原位置移除 → 移出游戏 → 触发             |
| 3  | 销毁牌后      | player | 整体触发一次                              |

**event 成员**：`event.player`（销毁者）、`event.card`（当前销毁的牌）、`event.cards`（实际销毁的牌列表）、`event.num`、`event.cancelled`、`event.cancel()`

> **注**：多张销毁时逐张触发「销毁牌时」。重载签名支持 card 对象 / cards 列表 / name+position+quantity。

***

## 18. 回复生命值流程

> **定义位置**：[GameSystem/Entities/Player.md](../GameSystem/Entities/Player.md)
> **调用方法**：`player.recover(num)`
> **取消点**：无（参考 [K\_gameTerminology.md §7.1](K_gameTerminology.md#71-伤害类) 中「回复生命时」标记为「否」）
> **数值约束**：节点 3 系统加血时受最大生命值上限约束（`min(event.num, player.get_max_hp() - player.get_hp())`）
> **关联技能**：[SurvivorPacks/surgeon.md](../Resource/SurvivorPacks/surgeon.md)（手术刀·回复、希波克拉底誓言、缝合）、surgeon 游戏牌「手套」均使用 trigger「回复生命时」修改 `event.num`

| 节点 | trigger 名       | 触发对象   | 说明                                                       |
| -- | --------------- | ------ | -------------------------------------------------------- |
| 1  | 回复生命前           | player | 回复前触发                                                    |
| 2  | 回复生命时           | player | 可修改 `event.num`（如 surgeon 手术刀·回复、手套：`event.num += 1`）    |
| 3  | （系统加血）          | —      | `player.add_hp(min(event.num, player.get_max_hp() - player.get_hp()))`，受最大值约束，非钩子节点 |
| 4  | 回复生命后           | player | 回复完成后触发                                                  |

**event 成员**：`event.player`（回复目标）、`event.num`（可读写）、`event.cancelled`、`event.cancel()`

> **注**：节点 2 为 surgeon 手术刀·回复、手套使用的 trigger（forced:true 强制发动并修改 `event.num`）；节点 1/4 按命名模式对称包围系统加血节点，目前无具体技能引用，保留为通用 trigger。
> **与伤害流程的差异**：无 source 侧（回复无来源概念）；无取消点（K\_gameTerminology.md §7.1 标注为「否」），但保留 `event.cancel()` 接口以备未来扩展。
> **与** **`player.add_hp(n)`** **的区别**：`add_hp` 为底层原子方法，直接修改生命值数值，不触发钩子且不受最大值约束；`recover` 走完整 4 节点流程。

***

## 19. 游戏开始流程

> **定义位置**：[GameSystem/Core/GameStateMachine.md](../GameSystem/Core/GameStateMachine.md) §方法 startGame()（Game 类委托调用）
> **调用方法**：`game.startGame()` → `状态机.startGame()`
> **前置条件**：游戏初始化（[C_gameSetup.md](C_gameSetup.md) 步骤 1-6）已完成；`游戏状态 == "setup"`
> **取消点**：无（全局事件，不提供取消）
> **trigger 触发对象**：所有 player（按座位顺序依次触发）。Game 类不继承 Entity，无自身 trigger。

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | （抓初始手牌） | — | 每个玩家抓 4 张牌（可选一次重调，按座位顺序） |
| 2 | （抓初始怪物卡） | — | 每个玩家抓 1 张怪物卡（按座位顺序） |
| 3 | 游戏开始时 | player | 按座位顺序对所有 player 触发；典型场景：gunslinger「快速拔枪」从牌堆中装备【柯尔特手枪】 |
| 4 | （进入第一回合） | — | `game.当前回合玩家 = game.所有玩家[0]`，开始第一玩家回合 |

**event 成员**：`event.player`、`event.cancelled`（无 cancel() 调用，全局事件不取消）

> **典型应用**：
>
> - `游戏开始时`：gunslinger「快速拔枪」从游戏牌堆中找到【柯尔特手枪】装备到装备区（见 [SurvivorPacks/gunslinger.md](../Resource/SurvivorPacks/gunslinger.md)）
> - trigger 字段支持复合触发：`trigger: 游戏开始时、受到伤害时`，content 内用 `if (trigger == "游戏开始时")` 判断分支

***

## 20. 游戏结束流程

> **定义位置**：[GameSystem/Core/GameStateMachine.md](../GameSystem/Core/GameStateMachine.md) §方法 gameOver(result)（Game 类委托调用）
> **调用方法**：`game.gameOver(result)` → `状态机.gameOver(result)`（result = "win" / "lose"）
> **触发场景**：所有玩家死亡（lose）；或胜利条件达成（win，见 [G_gameOver.md](G_gameOver.md)）；或怪物牌堆重洗后仍空（lose）
> **取消点**：无（游戏结束不可逆）
> **trigger 触发对象**：所有 player（按座位顺序依次触发）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | （设置状态） | — | `game.游戏阶段 = "gameOver"`；`game.游戏结果 = result`；输出胜负日志 |
| 2 | （日志输出） | — | "win" → "求生者成功逃离启示录的废土！"；"lose" → "所有求生者死亡，游戏失败。" |
| 3 | 游戏结束时 | player | 按座位顺序对所有 player 触发；event.result 携带 "win" / "lose" |

**event 成员**：`event.player`、`event.result`（"win" / "lose"）、`event.cancelled`（无 cancel() 调用，游戏结束不可逆）

> **注**：当前无技能使用「游戏结束时」trigger，作为对称设计与未来扩展点保留。技能可按 `event.result` 分支处理胜负场景。

***

## 21. 摧毁地块流程

> **定义位置**：[GameSystem/Game/Game.md](../GameSystem/Game/Game.md) §方法 destroyMapBlock(block, source)
> **调用方法**：`game.destroyMapBlock(block, source)`（source 可为 NULL，如无来源效果摧毁地块）
> **触发场景**：大炸药（[ScavengePacks/blue.md](../Resource/ScavengePacks/blue.md)）摧毁已展示存活地块；任务 12 中摧毁标记地块达成胜利条件
> **取消点**：节点 1「摧毁地块前」可调用 `event.cancel()`（取消后地块不被摧毁，已触发的前置钩子不回滚）
> **trigger 触发对象**：所有 player（按座位顺序依次触发，Game 类不继承 Entity，通过遍历 `game.所有玩家` 调用 `player.trigger()` 实现）
> **核心原则**：地块摧毁是非可逆事件；流程顺序为「前取消点 → 玩家弹出 → 怪物标记消灭 → 时节点 → 状态变更 → 后节点」

| 节点 | trigger 名  | 触发对象      | 说明                                                                                                |
| -- | ---------- | --------- | ------------------------------------------------------------------------------------------------- |
| 1  | 摧毁地块前      | 所有 player | **取消点**；如任务特殊规则可在此阻止关键地块被摧毁（`event.cancel()`）。source 为 NULL 时也触发                                     |
| 2  | （玩家弹出）     | —         | 处理地块上的玩家：依次查询 `block.getPlayers()`；有相邻存活地块 → 玩家选择 `target = player.chooseMapBlock(adjacentBlocks)` 后弹出；无相邻存活地块 → `player.damage(5, NULL, "地块摧毁")`。弹出**不触发完整移动钩子**（非主动移动），仅清理旧地块技能、设置坐标、获取新地块技能（若新地块未展示则展示并触发效果） |
| 3  | （怪物标记消灭）   | —         | `block.怪物标记数 = 0`，地块上的怪物标记全部消灭（不触发怪物死亡流程，纯标记清理）                                                    |
| 4  | 摧毁地块时      | 所有 player | 系统结算点；此时玩家已弹出、怪物标记已消灭，但地块状态仍为"存活"。可在此读取地块信息做最后处理                                                  |
| 5  | （状态变更）     | —         | `block.地块状态 = "已摧毁"`；`game.地图区域.remove(block)`，地块从地图区域移除                                           |
| 6  | 摧毁地块后      | 所有 player | 地块摧毁完成；典型用途：检查任务胜利条件（如任务 12 检查 3 个标记地块是否全部被摧毁）                                                     |

**event 成员**：`event.source`（摧毁者，可为 NULL）、`event.block`（被摧毁的地块）、`event.cancelled`、`event.cancel()`

> **玩家弹出规则细节**（节点 2）：
>
> - 弹出**不调用** `player.moveTo(target)`，避免触发完整的离开/进入地块钩子（防止重复触发地块技能、潜行检定等）
> - 弹出流程：
>   1. `block.清除技能(player)` — 清理被摧毁地块上的技能
>   2. `player.moveToMapBlock(target)` — 仅更新坐标
>   3. `target.获取地块技能(player)` — 挂载新地块技能
>   4. 若 `!target.is_revealed()` → `target.展示(触发效果=true, player)` — 展示新地块并触发展示效果
> - 若相邻存活地块为空，玩家受到 5 点无来源伤害（`player.damage(5, NULL, "地块摧毁")`）
>
> **典型应用**：
>
> - `大炸药`（[ScavengePacks/blue.md](../Resource/ScavengePacks/blue.md)）：行动阶段消耗 1 行动次数，摧毁中距离内的已展示存活地块
> - 任务 12「烧死那群机器人」（[MissionPacks/basic-mission_12.md](../Resource/MissionPacks/basic-mission_12.md)）：3 个标记地块需用大炸药摧毁，全部摧毁后达成胜利条件之一

