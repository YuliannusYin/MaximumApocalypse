# 游戏设计文档

本目录是《末日启示录》PC 版的设计文档，与 `MxApoc_GDScript/` 实现对齐。规则以代码与 `data/**/*.json` 为准；文档落后时以代码修正文档。

## 目录结构

| 目录 | 面向 | 内容 |
| --- | --- | --- |
| [GameInstructions/](GameInstructions/) | 规则与流程 | 概述、开局、判定术语、事件流与变体 |
| [GameSystem/](GameSystem/) | 引擎类设计 | Common / Core / Entities / Game / System |
| [Engineering/](Engineering/) | 工程规范 | 数据格式、标识符映射、CodeExecutor、项目结构 |
| [Resource/](Resource/) | 静态资源包 | 任务 / 求生者 / 怪物 / 拾荒 / 地图块 |

### GameInstructions

| 文档 | 说明 |
| --- | --- |
| [01_概述与任务目标.md](GameInstructions/01_概述与任务目标.md) | 合作概述、13 个任务总览、难度、解锁 |
| [02_开局与流程.md](GameInstructions/02_开局与流程.md) | 房间、初始化、回合阶段、胜负 |
| [03_判定与术语.md](GameInstructions/03_判定与术语.md) | 射程、检定、卡牌使用 |
| [04_事件流与变体.md](GameInstructions/04_事件流与变体.md) | 领域事件节点与危机 / 饥荒 / 同生共死 |

### GameSystem（按代码分层）

- **Common**：`Pile` / `RoleCard` / `Skill` / `LogColors`
- **Core**：`Entity` / `Mark` / `EventScheduler` / `EventSystem` / `GameStateMachine`
- **Entities**：`Player` / `Card` / `Equipment` / `MapBlock` / `Monster`
- **Game**：`Game` / `MissionConfig` / `MissionComponent`
- **System**：`EventBus` / `ArchiveManager` / `StatsTracker` / `PlayerStats`

### Engineering

| 文档 | 说明 |
| --- | --- |
| [DataFormat.md](Engineering/DataFormat.md) | `data/` JSON schema、DataManager 加载与查询 |
| [IdentifierMapping.md](Engineering/IdentifierMapping.md) | 中英标识符、trigger、mission_state 键 |
| [CodeExecutor.md](Engineering/CodeExecutor.md) | JSON 代码字段编译沙箱 |
| [GodotProjectStructure.md](Engineering/GodotProjectStructure.md) | 源码树、autoload、资源目录 |

### Resource

| 目录 | 说明 |
| --- | --- |
| [MissionPacks/](Resource/MissionPacks/) | 任务 0–12（含组件声明） |
| [SurvivorPacks/](Resource/SurvivorPacks/) | 求生者（老兵正在重新设计，玩家模式锁定） |
| [MonsterPacks/](Resource/MonsterPacks/) | zombie / mutant / alien / robot |
| [ScavengePacks/](Resource/ScavengePacks/) | 红 / 绿 / 蓝 / 灰拾荒 |
| [MapBlocksPack/](Resource/MapBlocksPack/MapBlocks.md) | 地图块定义 |

## 文档约定

- 类文档以对应 `.gd` 为准，文首写明源文件路径。
- 任务逻辑用三层架构：**JSON 声明** → **可复用组件** → **专用脚本（当前无内置）**。不要再写 `win_condition_code`。
- 游戏内 Wiki（`MxApoc_GDScript/data/wiki/`）是玩家可读百科，规则条文须与 [GameInstructions/](GameInstructions/) 同步；图鉴条目由运行时数据生成，不在本目录重复。
- CodeExecutor 只维护一份：[Engineering/CodeExecutor.md](Engineering/CodeExecutor.md)。`GameSystem/System/CodeExecutor.md` 为跳转页。
