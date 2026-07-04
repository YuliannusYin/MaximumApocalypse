# 游戏事件流程

> 本文档汇总游戏所有主要事件流程的 trigger 名与节点说明。
> 完整规则详见各流程引用的源文件（[GameSystem/](../GameSystem/) 与 [GameInstructions/](.)）。
> 标注 **[提案]** 的 trigger 名为尚未在 GameSystem/ 中定义的提案性命名，供后续实现参考。
> 文档创建日期：2026-07-04

---

## 目录

- [1. source攻击target流程（伤害结算）](#1-source攻击target流程伤害结算)
- [2. 玩家移动流程](#2-玩家移动流程)
- [3. 玩家抓取怪物流程](#3-玩家抓取怪物流程)
- [4. 怪物死亡流程](#4-怪物死亡流程)
- [5. 玩家死亡流程](#5-玩家死亡流程)
- [6. 装备进入装备区流程](#6-装备进入装备区流程提案)
- [7. 装备离开装备区流程](#7-装备离开装备区流程提案)
- [8. 玩家回合流程](#8-玩家回合流程)
- [9. 怪物行动流程](#9-怪物行动流程)
- [10. 抓取拾荒牌流程](#10-抓取拾荒牌流程提案)
- [11. 潜行检定流程](#11-潜行检定流程)
- [12. 怪物出生检定流程](#12-怪物出生检定流程)
- [13. 抓取游戏牌流程](#13-抓取游戏牌流程)
- [14. 弃置牌流程](#14-弃置牌流程)
- [15. 销毁牌流程](#15-销毁牌流程)

---

## 1. source攻击target流程（伤害结算）

> **定义位置**：[GameSystem/DamageFlow.md](../GameSystem/DamageFlow.md)
> **调用方法**：`target.damage(num, source, type=NULL)`
> **取消点**：节点 4「受到伤害时」可调用 `event.cancel()`
> **特殊规则**：source = NULL 时跳过所有 source 侧钩子（节点 1/3/6），仅触发 target 侧

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 造成伤害前 | source | source != NULL 时触发 |
| 2 | 受到伤害前 | target | 始终触发（含无来源伤害） |
| 3 | 造成伤害时 | source | source != NULL 时触发；可修改 `event.num`（伤害加成） |
| 4 | 受到伤害时 | target | **取消点**；可修改 `event.num`（伤害减免）或调用 `event.cancel()` |
| 5 | （系统扣血） | — | `target.生命值 -= event.num`，非钩子节点 |
| 6 | 造成伤害后 | source | source != NULL 时触发 |
| 7 | 受到伤害后 | target | 始终触发（含无来源伤害） |
| 8 | （死亡判定） | — | `target.生命值 <= 0` → 进入 [玩家死亡流程](#5-玩家死亡流程) 或 [怪物死亡流程](#4-怪物死亡流程) |

**event 成员**：`event.target`、`event.source`（可为 NULL）、`event.num`（可读写）、`event.type`、`event.cancelled`、`event.cancel()`

---

## 2. 玩家移动流程

> **定义位置**：[GameSystem/Movement.md](../GameSystem/Movement.md)
> **调用方法**：`player.moveTo(target)`
> **取消点**：节点 5「进入地块前」可调用 `event.cancel()`，取消时回滚目标地块技能
> **核心原则**：所有地块技能挂载到玩家身上，由 `player.trigger()` 统一触发

| 节点 | trigger 名 | 说明 |
|------|------------|------|
| 1 | 离开地块前 | 玩家离开当前地块前触发 |
| 2 | 离开地块时 | 如森林：同回合内进入又离开 → 抓怪物 |
| 3 | 离开地块后 | 离开完成 |
| 4 | （获取目标地块技能） | `player.获取地块技能(target)`，将目标地块技能挂载到玩家 |
| 5 | 进入地块前 | **取消点**；准入检定（如河流：潜行失败 → `event.cancel()`） |
| 6 | （移动时） | 坐标变更：`player.moveToMapBlock(target)` |
| 7 | （清理旧地块技能） | `source.清除技能(player)`，移动成功后才清理 |
| 8 | 进入地块时 | 一次性进入效果（军事基地造成伤害、监狱减行动、旷野抓怪物等） |
| 9 | 进入地块后 | 展示未展示的地块（触发「展示地块时」）；player.trigger |
| 10 | （潜行检定） | 目标地块有怪物标记时进行潜行检定，失败 → 移除标记并抓怪物 |

**衍生 trigger**：
- `展示地块时`：节点 9 中地块首次翻开时触发（地块技能）

**event 成员**：`event.player`、`event.source`（离开的地块）、`event.target`（进入的地块）、`event.cancelled`、`event.cancel()`

---

## 3. 玩家抓取怪物流程

> **定义位置**：[GameSystem/DrawFlow.md](../GameSystem/DrawFlow.md)
> **调用方法**：`player.drawMonster(n)`
> **取消点**：节点 1「抓取怪物卡前」可调用 `event.cancel()`（firefighter「梯子」在此取消跳过抓怪）
> **牌堆耗尽**：怪物牌堆空时重洗怪物弃牌堆；重洗后仍为空 → `game.gameOver("lose")`（见 [C_gameSetup.md](C_gameSetup.md)）
> **实体化**：每张怪物卡在节点 3-4 之间实体化（设置纠缠对象、初始化生命值）
> **递归调用**：节点 5 内 zombie 一大波僵尸、僵尸步行者会递归调用 drawMonster

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 抓取怪物卡前 | player | **取消点**；如 firefighter「梯子」(event.cancel() 跳过抓怪) |
| 2 | 抓取怪物卡时 | player | 每张触发；抓取动作执行 |
| 3 | 怪物卡进入求生者怪物区前 | player | 每张触发；怪物卡实体化前 |
| 4 | 怪物卡进入求生者怪物区时 | player | 每张触发；实体化后置入怪物区 |
| 5 | 怪物卡进入求生者怪物区后 | player | 每张触发；如 zombie(一大波僵尸、僵尸步行者)、alien/robot/mutant 多处技能 |
| 6 | 抓取怪物卡后 | player | 整体触发一次；如 mechanic「感应地雷」(对 event.target 造成伤害) |

**event 成员**：`event.player`（抓取者）、`event.target`（当前怪物卡，实体化后的怪物对象）、`event.num`（可读写）、`event.cards`（实际抓到的怪物卡列表）、`event.cancelled`、`event.cancel()`

> **注**：节点 2-5 每张怪物卡触发一次（逐张走完整流程后抓下一张）；节点 6 整体触发一次。节点 1 的取消点对应 firefighter「梯子」技能（原 J 骨架误记为「感应地雷」，感应地雷实际属于 mechanic，trigger 为节点 6）。

---

## 4. 怪物死亡流程

> **定义位置**：[GameSystem/DeathFlow.md](../GameSystem/DeathFlow.md)
> **调用方法**：`target.monsterDeath(source)`
> **取消点**：无（死亡流程不可取消）
> **触发场景**：`target.damage` 流程节点 8 中怪物生命值 ≤ 0

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 死亡前 | target（怪物） | 死亡前最后时机 |
| 2 | 死亡时 | target（怪物） | 触发怪物死亡事件；如 zombie（僵尸女王）、robot（爆破机器人、方阵机器人） |
| 3 | （清理） | — | 将怪物卡从纠缠玩家怪物区移除，置入怪物弃牌堆 |
| 4 | 死亡后 | target（怪物） | 死亡完成 |

**event 成员**：`event.target`（死亡的怪物）、`event.source`（击杀者）

> **trigger 别名**：「杀死怪物时」统一映射为「怪物死亡时」（见 [SurvivorPacks/gunslinger.md](../SurvivorPacks/gunslinger.md) 搜索尸体技能，与 [MonsterPacks/zombie.md](../MonsterPacks/zombie.md) 注释对齐）。
> **注意**：地图块/技能效果「弃置怪物」（如 hunter 迷彩服）为纯移除，不触发怪物死亡流程。

---

## 5. 玩家死亡流程

> **定义位置**：[GameSystem/DeathFlow.md](../GameSystem/DeathFlow.md)
> **调用方法**：`target.playerDeath(source)`
> **取消点**：无（死亡流程不可取消）
> **触发场景**：`target.damage` 流程节点 8 中玩家生命值 ≤ 0；或游戏牌堆无牌时摸牌（见 [G_gameOver.md](G_gameOver.md)）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 死亡前 | target（玩家） | 死亡前最后时机 |
| 2 | 死亡时 | target（玩家） | 死亡事件触发 |
| 3 | （清理怪物区） | — | 怪物区怪物 → 弃牌堆，等量怪物标记（最多3个）放回地块 |
| 4 | （清理游戏牌） | — | 所有求生者游戏牌移出游戏（手牌+装备+牌堆+弃牌堆） |
| 5 | （清理拾荒卡） | — | 拾荒卡按颜色洗回对应拾荒牌堆，各色分别洗牌 |
| 6 | 死亡后 | target（玩家） | 死亡完成 |
| 7 | （全灭判定） | — | `game.allPlayersDead()` 为真 → `game.gameOver("lose")` |

**event 成员**：`event.target`（死亡的玩家）、`event.source`（击杀者，可为 NULL）

---

## 6. 装备进入装备区流程 **[提案]**

> **定义位置**：尚未定义；trigger 名从技能 trigger 字段提取
> **调用方法**：`player.装备(card)`（待定义）
> **关联技能**：[SurvivorPacks/gunslinger.md](../SurvivorPacks/gunslinger.md)、[SurvivorPacks/hunter.md](../SurvivorPacks/hunter.md)、[ScavengePacks/blue.md](../ScavengePacks/blue.md)、[SurvivorPacks/veteran.md](../SurvivorPacks/veteran.md) 均含 trigger「卡牌进入装备区时」

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 卡牌进入装备区前 **[提案]** | player | 装备进入前；可校验装备栏容量 |
| 2 | 卡牌进入装备区时 | player | 装备置入装备区；已确认 trigger |
| 3 | 卡牌进入装备区后 **[提案]** | player | 装备进入完成 |

**event 成员**：`event.card`（进入的装备卡，**[提案]**）、`event.player`（**[提案]**）

> **注**：节点 2 为已确认 trigger（多张装备技能使用）；节点 1/3 为按命名模式提案。

---

## 7. 装备离开装备区流程 **[提案]**

> **定义位置**：尚未定义；trigger 名从技能 trigger 字段提取
> **调用方法**：待定义（可能为 `player.卸下(card)` 或 `player.discard(card)` 的一部分）
> **关联技能**：[SurvivorPacks/gunslinger.md](../SurvivorPacks/gunslinger.md)、[SurvivorPacks/hunter.md](../SurvivorPacks/hunter.md)、[ScavengePacks/blue.md](../ScavengePacks/blue.md) 均含 trigger「卡牌离开装备区时」

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 卡牌离开装备区前 **[提案]** | player | 装备离开前 |
| 2 | 卡牌离开装备区时 | player | 装备离开装备区；已确认 trigger |
| 3 | 卡牌离开装备区后 **[提案]** | player | 装备离开完成 |

**event 成员**：`event.card`（离开的装备卡，**[提案]**）、`event.player`（**[提案]**）

> **衍生 trigger**：
> - `弹药耗尽时`：装备填充物耗尽时触发（见 [SurvivorPacks/gunslinger.md](../SurvivorPacks/gunslinger.md) 空尖弹 subSkill remove）。需在 `player.消耗填充物` 中检测并触发。

---

## 8. 玩家回合流程

> **定义位置**：[GameInstructions/D_gameFlow.md](D_gameFlow.md)（完整规则）
> **本文档仅列 trigger 名 + 节点说明**，详细阶段说明见源文件

| 节点 | trigger 名 | 说明 |
|------|------------|------|
| 1 | （进入玩家回合） | 非钩子节点 |
| 2 | 回合开始前 | 回合开始前触发 |
| 3 | 回合开始时 | 回合开始；如 MapBlocks（避难所、电厂） |
| 4 | 怪物出生前 | 怪物出生检定前 |
| 5 | 怪物出生时 | 进行怪物出生检定（见 [怪物出生检定流程](#12-怪物出生检定流程)） |
| 6 | 摸牌阶段前 | 摸牌前 |
| 7 | （摸牌阶段） | 从游戏牌堆抓 1 张牌；牌堆空 → 玩家死亡 |
| 8 | 行动阶段前 | 行动阶段前；含潜行检定（地块有怪物标记时） |
| 9 | （行动阶段） | 执行 4 个行动 + 免费行动（制衡、交易） |
| 10 | 行动阶段结束前 | 行动阶段结束前；如 gunslinger（扣动扳机让我快乐 subSkill） |
| 11 | 行动阶段结束时 | 行动阶段结束 |
| 12 | 求生者饥饿状态结算前 | 饥饿结算前；如 firefighter（野地夹克 subSkill） |
| 13 | 求生者饥饿状态结算时 | `player.increaseHunger(1)` |
| 14 | 求生者中毒状态结算前 | 中毒结算前 |
| 15 | 求生者中毒状态结算时 | `player.poison()`（有中毒标记时） |
| 16 | 面前怪物行动前 | 面前怪物行动前 |
| 17 | 面前怪物行动时 | 面前怪物按进入顺序行动（见 [怪物行动流程](#9-怪物行动流程)） |
| 18 | 回合结束前 | 回合结束前；如 gunslinger（扣动扳机让我快乐 subSkill）、MapBlocks（游乐园、警察局、城市街道） |
| 19 | 回合结束时 | 回合结束；如 MapBlocks（游乐园） |
| 20 | （退出玩家回合） | 非钩子节点 |
| 21 | （胜利判定） | 回合结束时检查胜利条件（见 [G_gameOver.md](G_gameOver.md)） |

> **trigger 命名差异**：firefighter 野地夹克 subSkill 使用「饥饿状态结算前」，D_gameFlow.md 使用「求生者饥饿状态结算前」。建议统一为 D_gameFlow 的完整形式。

---

## 9. 怪物行动流程

> **定义位置**：[GameInstructions/I_monsterAction.md](I_monsterAction.md)（完整规则）
> **触发场景**：玩家回合节点 17「面前怪物行动时」；按怪物卡进入怪物区的先后顺序行动

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 怪物行动前 | monster | 单个怪物行动前 |
| 2 | 怪物行动时 | monster | 怪物开始行动 |
| 3 | 怪物攻击前 | monster | 攻击前 |
| 4 | 怪物攻击时 | monster | 根据射程对目标发动攻击；如 alien（外星收割者、外星指挥官、外星入侵者、外星飞船）、mutant（狂暴的突变体、突变体老鼠） |
| 5 | 怪物攻击后 | monster | 攻击后；如 zombie（僵尸潜行者） |
| 6 | 怪物行动后 | monster | 单个怪物行动结束 |

**event 成员**：`event.目标玩家`（受攻击玩家，按射程可为列表，见 [待定义方法.md §9.11](../待定义方法.md#911-event目标玩家-的单值与列表歧义)）

> **注**：「怪物行动前/时/后」与玩家回合流程中的「面前怪物行动前/时」是不同层级的 trigger。前者是单个怪物级别的 trigger，后者是玩家回合阶段级别的 trigger。

---

## 10. 抓取拾荒牌流程

> **定义位置**：[GameSystem/DrawFlow.md](../GameSystem/DrawFlow.md)
> **调用方法**：`player.drawScavenge(n, pile)`
> **取消点**：节点 1「抓取拾荒牌前」可调用 `event.cancel()`（手电筒在此取消并替代为「看2留1放1」）
> **牌堆耗尽**：牌堆为空时停止抓取（不重洗弃牌堆，见 [C_gameSetup.md](C_gameSetup.md)）
> **关联技能**：[ScavengePacks/blue.md](../ScavengePacks/blue.md)（手电筒 trigger「抓取拾荒牌前」）、[ScavengePacks/red.md](../ScavengePacks/red.md)（燃料 trigger「抓取拾荒牌时」）、[ScavengePacks/gray.md](../ScavengePacks/gray.md)（一无所获、伏击！trigger「抓取拾荒牌时」）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 抓取拾荒牌前 | player | 取消点；如 blue（手电筒，event.cancel() 替代为「看2留1放1」） |
| 2 | （逐张抓取） | — | 抓1张→入手牌区→触发「时」→抓下一张；牌堆空则停止 |
| 3 | 抓取拾荒牌时 | player | 每张牌触发一次；如 red（燃料：装备或弃掉）、gray（一无所获：弃掉；伏击！：drawMonster+弃掉） |
| 4 | 抓取拾荒牌后 | player | 所有牌抓取完成 |

**event 成员**：`event.player`、`event.pile`（拾荒牌堆对象）、`event.num`（可读写）、`event.cards`（实际抓到的牌列表）、`event.card`（当前抓取的牌，「时」阶段可访问）、`event.cancelled`、`event.cancel()`

> **注**：pile 参数统一为 pile 对象（颜色字符串通过 `game.getScavengePile(颜色)` 转换）。手牌上限由上层校验。

---

## 11. 潜行检定流程

> **定义位置**：[GameInstructions/E_gameJudge.md](E_gameJudge.md)（流程说明）、[GameSystem/Judge.md](../GameSystem/Judge.md)（方法定义）
> **调用方法**：`player.sneakJudge()`
> **触发场景**：玩家进入有怪物标记的地块时（[移动流程](#2-玩家移动流程) 节点 10）；玩家回合行动阶段前（地块有怪物标记时）
> **检定公式**：潜行值 = 玩家潜行值 - (地块怪物数 + 怪物标记数)；检定结果 ≤ 潜行值则成功

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 潜行检定前 | player | 检定前；如 robot（激光无人机）、firefighter（猎犬）、gray（科学家，可修改检定结果为失败） |
| 2 | 潜行检定时 | player | 检定执行；如 gray（科学家） |
| 3 | 潜行检定后 **[提案]** | player | 检定结果出来后 |
| 4 | （结果处理） | — | 成功：无事发生；失败：移除所有怪物标记，每移除一个抓一张怪物卡 |

**event 成员**：`event.player`、`event.result`（检定结果，**[提案]**）、`event.cancel()`（**[提案]**，可取消检定）

> **注**：节点 1/2 为已确认 trigger；节点 3 为按命名模式提案。

---

## 12. 怪物出生检定流程

> **定义位置**：[GameInstructions/E_gameJudge.md](E_gameJudge.md)（流程说明）、[GameSystem/Judge.md](../GameSystem/Judge.md)（方法定义）
> **调用方法**：`player.monsterSpawnJudge()`
> **触发场景**：玩家回合节点 5「怪物出生时」
> **检定规则**：投两颗大骰子，匹配已展示地块的怪物生成点数

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 怪物出生检定前 **[提案]** | player | 检定前 |
| 2 | 怪物出生检定时 **[提案]** | player | 检定执行 |
| 3 | 怪物出生检定后 **[提案]** | player | 检定结果出来后 |
| 4 | （结果处理） | — | 匹配地块：标记 < 3 → +1 标记；标记 = 3 且有玩家 → 每位玩家抓 1 怪物 |

**event 成员**：`event.player`、`event.result`（检定结果，**[提案]**）

> **注**：本流程的所有 trigger 名均为提案，尚未在技能中出现。D_gameFlow.md 中的「怪物出生前/时」是玩家回合阶段级别的 trigger，与此处的检定流程 trigger 不同层级。

---

## 13. 抓取游戏牌流程

> **定义位置**：[GameSystem/DrawFlow.md](../GameSystem/DrawFlow.md)
> **调用方法**：`player.draw(n)`
> **取消点**：节点 1「抓取游戏牌前」、节点 2「抓取游戏牌时」均可调用 `event.cancel()`
> **死亡规则**：逐张抓取，每张抓取前检查牌堆；牌堆为空时尝试抓取 → 调用 `player.playerDeath(NULL)` 并 return（跳过节点 4）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 抓取游戏牌前 | player | 取消点；可调用 `event.cancel()` 取消本次抓牌 |
| 2 | 抓取游戏牌时 | player | 取消点；可修改 `event.num`（如技能加摸 1 张），可调用 `event.cancel()` |
| 3 | （逐张抓取） | — | 每张抓取前检查牌堆，牌堆为空 → `playerDeath(NULL)` 并 return；否则从游戏牌堆抓 1 张到手牌区 |
| 4 | 抓取游戏牌后 | player | 所有牌抓取完成；可访问 `event.cards`（实际抓到的牌列表） |

**event 成员**：`event.player`、`event.num`（可读写）、`event.cards`（实际抓到的牌列表）、`event.cancelled`、`event.cancel()`

> **注**：手牌上限（10 张）由上层校验，draw() 不处理。牌堆不足 n 张时逐张抓取，抓到剩余牌后下一次尝试抓取时触发死亡。

---

## 14. 弃置牌流程

> **定义位置**：[GameSystem/DiscardFlow.md](../GameSystem/DiscardFlow.md)
> **调用方法**：`player.discard(target, position=NULL, quantity=1, type=NULL)`
> **取消点**：节点 1「弃置牌前」可调用 `event.cancel()`
> **重载签名**：target 支持 card 对象 / cards 列表 / name 字符串 / type 字符串（type 参数非空时按 `card.类型` 弃置）
> **弃牌堆分派**：按卡牌 source 自动分派（scavenge → 对应颜色拾荒弃牌堆，game → 游戏牌弃牌堆）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 弃置牌前 | player | **取消点**；可调用 `event.cancel()` 取消本次弃牌 |
| 2 | 弃置牌时 | player | 每张触发；从原位置移除 → 进入对应弃牌堆 → 触发 |
| 3 | 弃置牌后 | player | 整体触发一次 |

**event 成员**：`event.player`（弃牌者）、`event.card`（当前弃置的牌，「时」阶段可访问）、`event.cards`（实际弃置的牌列表）、`event.num`（计划弃置数）、`event.cancelled`、`event.cancel()`

> **注**：多张弃置时逐张触发「弃置牌时」（与 drawScavenge/drawMonster 模式对齐）。position=NULL 时搜索所有区域（手牌区+装备区）。

---

## 15. 销毁牌流程

> **定义位置**：[GameSystem/DiscardFlow.md](../GameSystem/DiscardFlow.md)
> **调用方法**：`player.removeCard(target, position=NULL, quantity=1)`
> **取消点**：节点 1「销毁牌前」可调用 `event.cancel()`
> **与弃置的区别**：销毁的牌不进入弃牌堆，而是移出游戏（调用 `game.removeCard(card)`）
> **命名统一**：原 MapBlocks(坠毁点) 的 `player.remove(card)` 已统一为 `player.removeCard(card)`（见 [待定义方法.md §9.5](../待定义方法.md#95-playerremovecard-与-playerremove-的命名不一致)）

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|------------|---------|------|
| 1 | 销毁牌前 | player | **取消点**；可调用 `event.cancel()` 取消本次销毁 |
| 2 | 销毁牌时 | player | 每张触发；从原位置移除 → 移出游戏 → 触发 |
| 3 | 销毁牌后 | player | 整体触发一次 |

**event 成员**：`event.player`（销毁者）、`event.card`（当前销毁的牌）、`event.cards`（实际销毁的牌列表）、`event.num`、`event.cancelled`、`event.cancel()`

> **注**：多张销毁时逐张触发「销毁牌时」。重载签名支持 card 对象 / cards 列表 / name+position+quantity。
