# GameSystem 游戏系统设计文档

> 《末日启示录》(Maximum Apocalypse) 数字化的底层系统设计文档。
> 面向对象视角组织：按 class 聚合字段、信号量（triggers）与方法（含伪代码流程）。
> 项目背景见 [AGENTS.md](../../AGENTS.md)。

---

## 系统总览

游戏系统由 **核心基础设施** + **实体类** + **全局管理** + **通用组件** 四部分组成。所有可挂载技能、可触发事件的对象继承 `Entity` 基类，通过统一的 `trigger()` 机制编排流程钩子（前/时/后 + 取消点），以 `event` 对象作为流程间通信载体。

---

## 类继承关系

```
Entity（实体基类：挂载 skill + 触发 event + 通用 damage 流程）
│   位置：Core/Entity.md
│
├── Player（玩家：状态/区域/抓牌/弃牌/移动/检定/死亡）
│       位置：Entities/Player.md
│
├── Monster（怪物：属性/行动/攻击/死亡）
│       位置：Entities/Monster.md
│
├── Card（卡牌基类）
│   │   位置：Entities/Card.md
│   ├── ScavengeCard（拾荒卡：颜色）
│   ├── SurvivorGameCard（求生者游戏牌）
│   │   └── EquipmentCard（装备牌：含填充物）
│   └── MonsterCard（怪物卡：实体化前卡面数据）
│
└── MapBlock（地图块：属性/展示/怪物标记/地块技能挂载）
        位置：Entities/MapBlock.md


非 Entity 类（无技能、无 trigger）：

Game（游戏全局管理）         位置：Game/Game.md
Pile（通用牌堆）             位置：Common/Pile.md
RoleCard（角色卡）           位置：Common/RoleCard.md
Skill（技能结构定义）         位置：Common/Skill.md
```

---

## 目录结构

```
GameSystem/
├── README.md                       # 本文档：架构总览
│
├── Core/                           # 核心基础设施层
│   ├── Entity.md                   # Entity 实体基类
│   └── EventSystem.md              # 事件触发系统（机制/event schema/全 trigger 索引）
│
├── Entities/                       # 继承 Entity 的具体类
│   ├── Player.md                   # 玩家类
│   ├── Monster.md                  # 怪物类
│   ├── Card.md                     # 卡牌基类与子类
│   └── MapBlock.md                 # 地图块类
│
├── Game/                           # 游戏全局管理（非 Entity）
│   └── Game.md                     # Game 类
│
└── Common/                         # 通用组件（非 Entity）
    ├── Pile.md                     # 牌堆类
    ├── RoleCard.md                 # 角色卡类
    └── Skill.md                    # 技能结构定义 + 6 个通用行动技能
```

---

## 设计原则

### 1. 钩子驱动的流程编排

游戏所有主要流程采用「**XX前 / XX时 / XX后**」三段式钩子，对称包围系统结算节点：

- `XX前`：系统结算前，部分为取消点
- `XX时`：系统结算时，可修改 event 参数，部分为取消点
- `XX后`：系统结算后，仅通知

取消点处技能可调用 `event.cancel()` 终止流程（已执行钩子不回滚，移动流程例外会回滚地块技能）。

### 2. event 对象作为通信载体

流程方法构建 `event` 对象，贯穿所有钩子节点。技能通过 `event` 读写流程参数（如 `event.num` 修改伤害/回复量）、查询上下文（`event.target` / `event.source` / `event.card`）、控制流程（`event.cancel()`）。

完整 event schema 见 [EventSystem.md §2](Core/EventSystem.md#2-event-对象-schema)。

### 3. 实体技能统一触发

所有技能（角色固有、装备、地块、临时、怪物）挂载到 Entity 的 `skills` 列表，由 `entity.trigger(triggerName, event)` 统一遍历执行。技能 `trigger` 字段支持「、」分隔的复合触发。

机制详见 [Entity.md](Core/Entity.md#1-事件触发) 与 [EventSystem.md](Core/EventSystem.md)。

### 4. 多态处理子类差异

跨子类的通用流程定义在 Entity 基类（如 `damage`），子类差异通过抽象方法多态处理（如 `death` → Player 走 `playerDeath`，Monster 走 `monsterDeath`）。优先使用多态而非 `isPlayer()` / `isMonster()` 类型判断。

### 5. 地块技能挂载到玩家

所有地图块技能在玩家进入地块时挂载到 Player 身上，由 `player.trigger()` 统一触发；离开时清理。这样玩家身上的所有技能都能通过同一机制遍历。详见 [MapBlock.md](Entities/MapBlock.md#设计原则) 与 [Player.moveTo](Entities/Player.md#moveto)。

---

## 文件索引

### Core/ 核心基础设施

| 文件 | 职责 |
|------|------|
| [Entity.md](Core/Entity.md) | Entity 实体基类：技能挂载、trigger 方法、通用 damage 流程、生命值接口、death 抽象方法 |
| [EventSystem.md](Core/EventSystem.md) | 事件触发系统：机制原理、event schema、命名规范、全 trigger 索引（按领域分组） |

### Entities/ 实体类

| 文件 | 职责 |
|------|------|
| [Player.md](Entities/Player.md) | Player 类：状态管理（recover/饥饿/poison）、抓牌（draw/drawScavenge/drawMonster）、弃牌与销毁、移动、检定、死亡、装备、填充物 |
| [Monster.md](Entities/Monster.md) | Monster 类：属性、行动/攻击流程、monsterDeath、实体化 |
| [Card.md](Entities/Card.md) | Card 基类 + ScavengeCard / SurvivorGameCard / EquipmentCard / MonsterCard 子类定义 |
| [MapBlock.md](Entities/MapBlock.md) | MapBlock 类：属性、展示、怪物标记管理、地块技能挂载 |

### Game/ 全局管理

| 文件 | 职责 |
|------|------|
| [Game.md](Game/Game.md) | Game 类：全局区域、gameOver、allPlayersDead、removeCard、getScavengePile、log |

### Common/ 通用组件

| 文件 | 职责 |
|------|------|
| [Pile.md](Common/Pile.md) | Pile 牌堆类：draw / isEmpty / add / shuffle / shuffleInto |
| [RoleCard.md](Common/RoleCard.md) | RoleCard 角色卡类：flip / is_front，饥饿翻面机制 |
| [Skill.md](Common/Skill.md) | Skill 结构定义（字段规范）+ 6 个通用行动技能实例（移动/拾荒/摸牌/制衡/交易/加油） |

---

## 核心流程速查

> 完整事件流程汇总见 [J_gameEventFlow.md](../GameInstructions/J_gameEventFlow.md)（GameInstructions 侧索引，本文档为源定义）。

| 流程 | 定义位置 | 调用方法 |
|------|---------|---------|
| 伤害结算 | [Entity.md](Core/Entity.md#3-伤害流程通用) | `target.damage(num, source, type)` |
| 玩家死亡 | [Player.md](Entities/Player.md#playerdeath) | `player.playerDeath(source)` |
| 怪物死亡 | [Monster.md](Entities/Monster.md#monsterdeath) | `monster.monsterDeath(source)` |
| 玩家移动 | [Player.md](Entities/Player.md#moveto) | `player.moveTo(target)` |
| 抓游戏牌 | [Player.md](Entities/Player.md#draw) | `player.draw(n)` |
| 抓拾荒牌 | [Player.md](Entities/Player.md#drawscavenge) | `player.drawScavenge(n, pile)` |
| 抓怪物卡 | [Player.md](Entities/Player.md#drawmonster) | `player.drawMonster(n)` |
| 弃置牌 | [Player.md](Entities/Player.md#discard) | `player.discard(...)` |
| 销毁牌 | [Player.md](Entities/Player.md#removecard) | `player.removeCard(...)` |
| 回复生命 | [Player.md](Entities/Player.md#recover) | `player.recover(num)` |
| 增加饥饿 | [Player.md](Entities/Player.md#increasehunger) | `player.increaseHunger(num)` |
| 减少饥饿 | [Player.md](Entities/Player.md#decreasehunger) | `player.decreaseHunger(num)` |
| 中毒结算 | [Player.md](Entities/Player.md#poison) | `player.poison()` |
| 潜行检定 | [Player.md](Entities/Player.md#sneakjudge) | `player.sneakJudge()` |
| 怪物出生检定 | [Player.md](Entities/Player.md#monsterspawnjudge) | `player.monsterSpawnJudge()` |
| 怪物行动 | [Monster.md](Entities/Monster.md#行动流程) | `monster.行动()` |
| 装备进入装备区 | [Player.md](Entities/Player.md#装备) [提案] | `player.装备(card)` |
| 装备离开装备区 | [Player.md](Entities/Player.md#卸下) [提案] | `player.卸下(card)` |
| 游戏结束 | [Game.md](Game/Game.md#gameoverresult) | `game.gameOver(result)` |

---

## 与其他目录的关系

| 目录 | 关系 |
|------|------|
| [GameInstructions/](../GameInstructions/) | 玩家可读的规则说明文档（A-L 编号）。本文档是其底层实现参考：[J_gameEventFlow.md](../GameInstructions/J_gameEventFlow.md) 汇总事件流程，[K_gameTerminology.md](../GameInstructions/K_gameTerminology.md) 收录术语与 trigger 索引，本文档为两者源定义 |
| [Resource/](../Resource/) | 卡牌/地图块/任务等数据定义。SurvivorPacks / ScavengePacks / MonsterPacks / MissionPacks / MapBlocksPack 中的技能 content 在本文档定义的流程中被调用 |
| [AGENTS.md](../../AGENTS.md) | 项目总体说明书 |

> **注**：当前 Resource/ 下仍保留原有9个系统流程文件（PlayerState/DamageFlow/DeathFlow/DrawFlow/DiscardFlow/Movement/Judge/EventTrigger/PlayerSkill），与本 GameSystem/ 内容重叠。GameSystem/ 为重构后的新架构，待定稿后统一修复 GameInstructions/ 与 Resource/ 的链接引用，并清理 Resource/ 下的冗余文件。

---

## 后续待完善

- [ ] 装备进入/离开装备区流程（[Player.装备](Entities/Player.md#装备) / [Player.卸下](Entities/Player.md#卸下)）落地为正式 trigger
- [ ] 填充物消耗流程（[Player.消耗填充物](Entities/Player.md#消耗填充物)）与「弹药耗尽时」trigger
- [ ] 游戏开始流程与「游戏开始时」trigger
- [ ] 检定流程的「后」节点 trigger（潜行检定后 / 怪物出生检定后）
- [ ] `event.目标玩家` 的单值与列表歧义（怪物攻击多目标场景）
- [ ] `player.立即执行一个行动` 的语义定义
- [ ] 修复 GameInstructions/ 与 Resource/ 对 GameSystem/ 的路径引用
