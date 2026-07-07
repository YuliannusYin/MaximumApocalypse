# 游戏设计文档（GameDesignDocus）

> 《末日启示录》(Maximum Apocalypse) 桌游数字化项目的游戏设计文档总入口。
> 技术栈：Godot 4.7 + GDScript。项目背景见 [AGENTS.md](../AGENTS.md)。

---

## 目录结构

```
GameDesignDocus/
│
├── GameSystem/          # 游戏系统设计（面向开发者）
│   底层架构：按 class 组织的字段/信号量/方法设计，含伪代码流程
│
├── GameInstructions/   # 游戏规则说明（面向玩家/设计师）
│   玩家可读的规则文档，A-L 字母编号，按主题分章
│
└── Resource/            # 数据定义（卡牌/地图块/任务包）
    各类卡牌、地图块、任务的具体数据定义与技能伪代码
```

---

## 三个子目录

| 目录 | 定位 | 读者 | 入口 |
|------|------|------|------|
| [GameSystem/](GameSystem/README.md) | 底层系统设计：类继承、字段、方法、事件机制、伪代码流程 | 开发者 | [GameSystem/README.md](GameSystem/README.md) |
| [GameInstructions/](GameInstructions/README.md) | 游戏规则说明：从概述到术语的完整规则文档 | 设计师 / 玩家 | [GameInstructions/README.md](GameInstructions/README.md) |
| [Resource/](Resource/README.md) | 数据定义：求生者/拾荒/怪物/任务/地图块的具体内容 | 设计师 / 开发者 | [Resource/README.md](Resource/README.md) |

---

## 阅读路线图

### 初次了解项目

1. [AGENTS.md](../AGENTS.md) — 项目总体说明书
2. [A_overview.md](GameInstructions/A_overview.md) — 游戏概述
3. [GameSystem/README.md](GameSystem/README.md) — 系统架构总览（类继承图 + 设计原则）

### 理解游戏规则

按字母顺序阅读 [GameInstructions/](GameInstructions/) 各文档，或按以下主题路线：

- **快速上手**：A（概述）→ C（开始游戏）→ D（游戏流程）→ G（游戏结束）
- **战斗与检定**：D（流程）→ E（检定）→ F（射程）→ I（怪物行动）
- **卡牌使用**：H（使用卡牌）→ J（事件流程）→ K（术语表）
- **任务与变体**：B（任务目标）→ L（变体）

### 理解系统实现

1. [GameSystem/README.md](GameSystem/README.md) — 架构总览与类继承关系
2. [Core/Entity.md](GameSystem/Core/Entity.md) — Entity 基类（技能挂载 + trigger + damage 流程）
3. [Core/EventSystem.md](GameSystem/Core/EventSystem.md) — 事件触发机制与全 trigger 索引
4. [Entities/Player.md](GameSystem/Entities/Player.md) — Player 类（最大文档，含所有玩家流程方法）
5. [J_gameEventFlow.md](GameInstructions/J_gameEventFlow.md) — 事件流程汇总（trigger 名 + 节点表）

### 查阅卡牌/地图数据

1. [Resource/README.md](Resource/README.md) — 数据格式与包索引
2. 按需查阅各子包（如 [SurvivorPacks/firefighter.md](Resource/SurvivorPacks/firefighter.md)）

---

## 三目录关系

```
GameSystem/（源定义）  ←──实现──→  GameInstructions/（规则说明）
       ↑
       └── 数据引用 ──→  Resource/（卡牌/地图块/任务数据）
```

- **GameSystem/** 是底层源定义：类结构、方法签名、流程节点都在此定义
- **GameInstructions/** 是玩家可读的规则说明：同一套流程，但以自然语言描述，附带 trigger 名索引
- **Resource/** 是数据层：卡牌技能的 `content` 伪代码在 GameSystem/ 定义的流程中被调用

核心设计模式：
- **钩子驱动**：所有流程采用「XX前 / XX时 / XX后」三段式钩子 + 取消点
- **event 对象**：流程间通信载体（按流程含 `event.target` / `event.targetBlock` / `event.card` / `event.targets` / `event.num` / `event.cancel()` 等字段，详见 [GameSystem/Core/EventSystem.md §2.2](GameSystem/Core/EventSystem.md#22-按流程类型的字段)）
- **技能统一挂载**：所有技能挂到 Entity.skills，由 `entity.trigger()` 统一遍历
- **地块技能挂载到玩家**：玩家进入地块时地块技能挂载到 Player，离开时清理

---

## 文档约定

- **伪代码风格**：GDScript 风味伪代码，`function` 关键字声明方法，`#` 注释
- **trigger 命名**：中文「XX前/时/后」，复合触发用「、」分隔（如 `trigger: 游戏开始时、受到伤害时`）
- **标注约定**：`[提案]` 表示尚未落地的提案性命名，`待定义` 表示语义待定
