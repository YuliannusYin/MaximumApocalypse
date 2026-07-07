# GameInstructions 游戏规则说明

> 玩家可读的游戏规则文档，按 A-L 字母编号分章。
> 底层实现定义见 [GameSystem/](../GameSystem/README.md)，卡牌/地图数据见 [Resource/](../Resource/README.md)。

---

## 文档索引

| 编号 | 文件 | 主题 | 说明 |
|------|------|------|------|
| A | [A_overview.md](A_overview.md) | 概述 | 游戏背景与合作求生玩法简介 |
| B | [B_missionObjectives.md](B_missionObjectives.md) | 任务目标 | 任务字段结构、胜利/失败条件、首领卡/目标标记/科学家机制、13 个任务概览 |
| C | [C_gameSetup.md](C_gameSetup.md) | 开始游戏 | 游戏房间设置、初始化、开局流程 |
| D | [D_gameFlow.md](D_gameFlow.md) | 游戏流程 | 玩家回合 21 节点完整流程（与 Player.开始回合() 同步） |
| E | [E_gameJudge.md](E_gameJudge.md) | 检定 | 怪物出生检定与潜行检定 |
| F | [F_gameRange.md](F_gameRange.md) | 射程 | 玩家射程与怪物射程的网格定义 |
| G | [G_gameOver.md](G_gameOver.md) | 游戏结束 | 死亡条件、胜利与失败条件 |
| H | [H_useCard.md](H_useCard.md) | 使用卡牌 | 行动牌与装备牌的使用规则 |
| I | [I_monsterAction.md](I_monsterAction.md) | 怪物行动 | 怪物行动流程（行动前/时/攻击/后） |
| J | [J_gameEventFlow.md](J_gameEventFlow.md) | 事件流程 | 全部事件流程的 trigger 名与节点表汇总 |
| K | [K_gameTerminology.md](K_gameTerminology.md) | 术语表 | 核心概念术语 + 完整 trigger 索引 |
| L | [L_gameVariants.md](L_gameVariants.md) | 变体 | 难度变体规则（危机四伏/大饥荒/同生共死） |

---

## 推荐阅读顺序

### 新玩家入门

A → C → D → G → F → E → I → H → B → L

1. **A** 了解游戏背景
2. **C** 学会如何开始一局游戏
3. **D** 理解回合流程（核心）
4. **G** 知道如何赢/输
5. **F + E** 理解射程与检定（战斗相关）
6. **I** 理解怪物如何行动
7. **H** 理解卡牌使用
8. **B** 了解任务目标
9. **L** 尝试难度变体

### 开发者查阅

- **J + K** 是核心参考文档：J 汇总所有事件流程的 trigger 名与节点，K 收录术语与完整 trigger 索引表
- 遇到流程细节时，J 中的「定义位置」会指向 [GameSystem/](../GameSystem/) 中的源定义

---

## 与 GameSystem/ 的关系

| 本目录（规则说明） | GameSystem/（源定义） |
|------|------|
| [D_gameFlow.md](D_gameFlow.md) 玩家回合流程 | [Player.md](../GameSystem/Entities/Player.md) §十 开始回合() 21 节点流程 |
| [E_gameJudge.md](E_gameJudge.md) 检定流程 | [Player.md](../GameSystem/Entities/Player.md) sneakJudge / monsterSpawnJudge |
| [I_monsterAction.md](I_monsterAction.md) 怪物行动 | [Monster.md](../GameSystem/Entities/Monster.md) 行动流程 |
| [B_missionObjectives.md](B_missionObjectives.md) 任务系统 | [Game.md](../GameSystem/Game/Game.md) MissionConfig + [Player.md](../GameSystem/Entities/Player.md) §十四 任务系统方法 |
| [J_gameEventFlow.md](J_gameEventFlow.md) 事件流程汇总 | [Entity.md](../GameSystem/Core/Entity.md) damage 流程 + [Player.md](../GameSystem/Entities/Player.md) 各流程 + [Monster.md](../GameSystem/Entities/Monster.md) 死亡流程 |
| [K_gameTerminology.md](K_gameTerminology.md) trigger 索引 | [EventSystem.md](../GameSystem/Core/EventSystem.md) 全 trigger 索引（权威来源） |

> **J 和 K 是桥接文档**：它们以表格形式汇总 trigger 名与流程节点，同时指向 GameSystem/ 中的源定义。开发时以 GameSystem/ 为准，玩家读规则时以本目录为准。

---

## 待扩展文档

以下文档内容较简略，后续将补充：

- [H_useCard.md](H_useCard.md) — 卡牌使用完整规则（可补充装备栏容量校验、同名校验等细节）

> **已扩展**：[B_missionObjectives.md](B_missionObjectives.md) 已扩展为完整任务系统说明，含任务字段结构、胜利/失败条件、首领卡/目标标记/科学家机制、13 个任务概览表。[D_gameFlow.md](D_gameFlow.md) 已同步为与 Player.开始回合() 一致的 21 节点流程。
