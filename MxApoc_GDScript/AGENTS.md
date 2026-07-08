# AGENTS.md — Maximum Apocalypse 项目说明书

> 《末日启示录》(Maximum Apocalypse) 桌游数字化项目的总体说明书与 AI Agent 协作规范。
> 技术栈：Godot 4.7 + GDScript。设计文档入口：[GameDesignDocus/README.md](GameDesignDocus/README.md)。

---

## 一、项目概述

### 1.1 项目背景

将合作类桌游《Maximum Apocalypse》数字化为 3D 视频游戏。每名玩家扮演一名后启示录求生者，通过卡牌执行行动、获取装备，在怪物威胁下探索地区、填饱肚子、收集资源，最终共同完成任务逃脱，或一起死在废土。

### 1.2 技术栈

| 维度 | 选型 |
|------|------|
| 引擎 | Godot 4.7（Forward Plus 渲染，Windows 下 D3D12） |
| 脚本 | GDScript（Tab 缩进、显式类型注解） |
| 物理 | Jolt Physics（3D） |
| 测试 | [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)（已安装于 `addons/gut/`） |
| 主场景 | `res://scenes/MainMenu.tscn` |
| 运行分辨率 | 1430 × 780（最小 1024 × 600） |

### 1.3 项目目标（按阶段）

1. **阶段 1 — 核心逻辑层**：GameSystem 全部类（Entity/Player/Monster/Card/MapBlock/Game/GameStateMachine）+ Resource 数据加载 + 单元测试
2. **阶段 2 — 单机热座**：3D 表现层 + 单机多人轮流操作
3. **阶段 3 — 人机合作**：AI 玩家 + 存档系统
4. **阶段 4 — 多人联机**：房间系统 + 状态同步 + 断线重连

> 阶段划分与支撑系统补充清单详见 [docs/feasibility-analysis.md](docs/feasibility-analysis.md) 与 [docs/design-gaps.md](docs/design-gaps.md)。

---

## 二、目录结构

### 2.1 目标结构（以 [GodotProjectStructure.md](GameDesignDocus/Engineering/GodotProjectStructure.md) 为准）

```
MxApoc_GDScript/
├── project.godot                  # Godot 项目配置
├── AGENTS.md                      # 本文件
├── GameDesignDocus/               # 设计文档（不参与编译）
├── docs/                          # 工程报告（可行性分析、设计待完善）
├── src/                           # 源代码（GDScript）
│   ├── core/                      # GameSystem/Core：entity/event_system/game_state_machine
│   ├── entities/                  # GameSystem/Entities：player/monster/card/map_block
│   ├── game/                      # GameSystem/Game：game
│   ├── common/                    # GameSystem/Common：pile/role_card/skill
│   ├── data/                      # 数据加载层：data_manager + 各 loader + *_data.gd
│   ├── ui/                        # UI 层（接口 + 命令行 UI + 图形 UI）
│   ├── ai/                        # AI 玩家层（阶段 3）
│   ├── network/                   # 网络层（阶段 4）
│   └── save/                      # 存档层（阶段 3+）
├── data/                          # 运行时数据文件（JSON）
│   ├── survivors/                 # 6 个 JSON
│   ├── scavenge/                  # 4 个 JSON
│   ├── monsters/                  # 4 个 JSON
│   ├── missions/                  # 13 个 JSON
│   └── map_blocks/                # map_blocks.json
├── scenes/                        # Godot 场景（.tscn）
├── assets/                        # 美术/音效资源
├── tests/                         # GUT 测试（unit/integration/data）
└── tools/                         # 工具脚本（markdown_to_json / data_validator）
```

### 2.2 当前现状（临时占位）

当前代码尚未迁移到 `src/`，暂存于以下位置：

| 现状路径 | 内容 | 对应目标路径 |
|---------|------|-------------|
| `scripts/autoload/settings.gd` | 全屏设置 autoload | `src/ui/settings.gd` 或保留 autoload 目录 |
| `scripts/autoload/room_state.gd` | 房间状态 autoload（任务/变体/座位） | `src/ui/room_state.gd` 或保留 autoload 目录 |
| `scripts/ui/*.gd` | 主菜单/游戏房间/设置对话框 | `src/ui/` |
| `data/survivor_data.gd` 等 | GDScript 硬编码数据类（临时方案，见 §五） | `src/data/` |
| `data/survivors.gd` 等 | 静态数据集合（临时方案） | 待迁移到 JSON + DataManager |
| `scenes/*.tscn` | MainMenu/GameRoom/GameScene/SettingsDialog/SeatItem | `scenes/`（无需迁移） |

### 2.3 当前 autoload 配置

```ini
[autoload]
RoomState="*res://scripts/autoload/room_state.gd"
Settings="*res://scripts/autoload/settings.gd"
```

**目标 autoload**（按 [GodotProjectStructure.md §二](GameDesignDocus/Engineering/GodotProjectStructure.md)）：

| Autoload | 类 | 路径 | 初始化顺序 |
|----------|---|------|-----------|
| `DataManager` | `DataManager` | `res://src/data/data_manager.gd` | 1（先加载数据） |
| `Game` | `Game` | `res://src/game/game.gd` | 2（依赖 DataManager） |
| `EventBus` | `EventBus` | `res://src/core/event_bus.gd` | 3（供 UI 订阅） |

> 迁移期间 `RoomState`/`Settings` 可保留为 UI 层 autoload，与游戏逻辑 autoload（Game/DataManager/EventBus）并存。

---

## 三、核心架构概念

> 完整设计见 [GameSystem/README.md](GameDesignDocus/GameSystem/README.md)。本节为 AI Agent 快速参考。

### 3.1 钩子驱动的流程编排

所有主要流程采用「**XX前 / XX时 / XX后**」三段式钩子：

- `XX前`：系统结算前，部分为取消点
- `XX时`：系统结算时，可修改 event 参数，部分为取消点
- `XX后`：系统结算后，仅通知

取消点处技能可调用 `event.cancel()` 终止流程（已执行钩子不回滚，移动流程例外会回滚地块技能）。

### 3.2 event 对象作为通信载体

流程方法构建 `event` 对象，贯穿所有钩子节点。技能通过 `event` 读写流程参数、查询上下文、控制流程。

**target 字段命名约定**（易混淆，务必区分）：

| 字段 | 语义 | 示例流程 |
|------|------|---------|
| `event.target` | **实体目标**（受伤/死亡实体） | 伤害流程、死亡流程 |
| `event.target_block` | **地块目标**（进入的地块） | 移动流程 |
| `event.card` | **当前卡牌**（抓到的牌/处理的牌） | 抓牌、弃置、销毁 |
| `event.targets` | **目标列表**（主动技能经 filter 筛选后，复数） | 主动技能 |

完整 event schema 见 [EventSystem.md §2](GameDesignDocus/GameSystem/Core/EventSystem.md#2-event-对象-schema)。

### 3.3 实体技能统一触发

所有技能（角色固有、装备、地块、临时、怪物）挂载到 Entity 的 `skills` 列表，由 `entity.trigger(trigger_name, event)` 统一遍历执行。技能 `trigger` 字段支持「、」分隔的复合触发。

### 3.4 地块技能挂载到玩家

地图块技能在玩家**进入地块时挂载到 Player**，由 `player.trigger()` 统一触发；**离开时清理**。这样玩家身上的所有技能都能通过同一机制遍历。详见 [MapBlock.md](GameDesignDocus/GameSystem/Entities/MapBlock.md) 与 [Player.moveTo](GameDesignDocus/GameSystem/Entities/Player.md)。

### 3.5 多态优先于类型判断

跨子类的通用流程定义在 Entity 基类（如 `damage`），子类差异通过抽象方法多态处理（如 `death` → Player 走 `player_death`，Monster 走 `monster_death`）。**优先使用多态而非 `is_player()` / `is_monster()` 类型判断**。

---

## 四、类继承关系

```
Entity（实体基类：挂载 skill + 触发 event + 通用 damage 流程）
├── Player      玩家：状态/区域/抓牌/弃牌/移动/检定/死亡/回合流程
├── Monster     怪物：属性/行动/攻击/死亡/实体化
├── Card        卡牌基类
│   ├── ScavengeCard        拾荒卡
│   ├── SurvivorGameCard    求生者游戏牌
│   │   └── EquipmentCard   装备牌（含填充物）
│   └── MonsterCard         怪物卡（实体化前卡面数据）
└── MapBlock    地图块：属性/展示/怪物标记/地块技能挂载

非 Entity 类（无技能、无 trigger）：
Game                  游戏全局管理
GameStateMachine      状态机（状态/回合队列/胜负判定）
Pile                  通用牌堆
RoleCard              角色卡（饥饿翻面机制）
Skill                 技能结构定义
```

> 完整字段/方法/trigger 索引见 [IdentifierMapping.md](GameDesignDocus/Engineering/IdentifierMapping.md)。

---

## 五、数据层策略

### 5.1 目标方案：markdown → JSON → DataManager

**设计源**：`GameDesignDocus/Resource/*.md`（人类可读的设计文档）
**运行时数据**：`data/*.json`（Godot 解析的机器可读数据）
**转换工具**：`tools/markdown_to_json.gd`（待实现）
**加载入口**：`DataManager` autoload

数据流与 JSON Schema 见 [DataFormat.md](GameDesignDocus/Engineering/DataFormat.md)。

### 5.2 当前现状（临时方案）

当前 `data/` 目录下是 GDScript 硬编码数据类，**非 JSON**，且字段简化：

| 文件 | 内容 | 与设计文档差异 |
|------|------|---------------|
| `data/survivor_data.gd` | `SurvivorData extends Resource`，9 字段 | 缺 `deck`（角色专属牌堆）、`intrinsic_skills` 完整结构 |
| `data/survivors.gd` | 静态 `_ALL` 数组硬编码 6 个角色 | 应来自 JSON |
| `data/mission_data.gd` | `MissionData extends Resource`，11 字段 | 缺 `map_layout`、`map_legend`、`objective_marks`、`scavenge_config`、`win_condition_code` |
| `data/missions.gd` | 静态 `_ALL` 数组 | 应来自 JSON |
| `data/variants.gd` / `variant_data.gd` | 3 个变体（危机四伏/大饥荒/同生共死） | 字段完整，仅需迁移到 JSON |

### 5.3 迁移步骤

1. **实现转换工具** `tools/markdown_to_json.gd`：按 [DataFormat.md §七](GameDesignDocus/Engineering/DataFormat.md#七-markdown--json-转换规范) 解析 Resource markdown → JSON
2. **生成 JSON 数据**：运行转换工具，输出到 `data/survivors/`、`data/missions/` 等子目录
3. **实现数据类** `src/data/survivor_data.gd` 等：`extends RefCounted`（按设计文档，非 Resource），`_init(data: Dictionary)` 解析 JSON
4. **实现 DataManager** `src/data/data_manager.gd`：autoload，`_ready()` 时加载所有 JSON，提供查询接口
5. **实现验证工具** `tools/data_validator.gd`：按 [DataFormat.md §六](GameDesignDocus/Engineering/DataFormat.md#六-数据验证规则) 检查必填字段/类型/枚举/引用完整性
6. **替换现有硬编码引用**：将 `Survivors.get_all()` 等静态调用替换为 `DataManager.get_survivor(id)` 等
7. **删除临时文件**：`data/survivors.gd`、`data/missions.gd`、`data/variants.gd` 及对应 `_data.gd`（迁移到 `src/data/`）

> **注意**：迁移期间 `RoomState`（房间状态 autoload）引用了 `MissionData`/`SurvivorData`/`Variants`，需同步更新引用路径。

---

## 六、编码规范

> 完整规范见 [GodotProjectStructure.md §四](GameDesignDocus/Engineering/GodotProjectStructure.md#四编码规范)。

### 6.1 命名规范

| 类型 | 风格 | 示例 |
|------|------|------|
| 类名 | PascalCase | `Player`、`GameStateMachine` |
| 文件名 | snake_case | `player.gd`、`game_state_machine.gd` |
| 方法名/变量名 | snake_case | `draw_card()`、`current_hp` |
| 常量/枚举值 | UPPER_SNAKE_CASE | `MAX_HP`、`MonsterLevel.BOSS` |
| 信号 | snake_case | `player_died` |
| 私有方法/变量 | `_` 前缀 | `_update_internal_state()` |

### 6.2 GDScript 风格要点

- 缩进：**Tab**（非空格）
- 行尾：无分号
- 类型注解：显式声明（`var hp: int = 10`）
- 函数返回类型：显式声明（`func draw_card() -> Card:`）
- 类继承：`class_name Player extends Entity`

### 6.3 中文 → 英文标识符映射

设计文档使用中文标识符（如 `玩家.生命值`、`player.消耗填充物()`），代码必须用英文（`player.hp`、`player.consume_charge()`）。**完整映射表见 [IdentifierMapping.md](GameDesignDocus/Engineering/IdentifierMapping.md)**，涵盖：

- 类名映射（Entity/Player/Monster/...）
- 枚举值映射（MonsterLevel/Range/Phase/Difficulty/...）
- 字段映射（Player/Monster/Card/MapBlock/Game/...）
- 方法映射（Entity/Player/Monster/MapBlock/Game/GameStateMachine/Pile）
- Trigger 名映射（中文「XX前/时/后」→ 英文 `before_/on_/after_` snake_case）
- Event 字段映射（`triggerName` → `"trigger_name"`、`targetBlock` → `"target_block"` 等）

---

## 七、AI Agent 协作规范

### 7.1 任务工作流

接到开发任务时，按以下步骤推进：

1. **理解设计文档**：先读 [GameSystem/README.md](GameDesignDocus/GameSystem/README.md) 的「核心流程速查表」，定位任务涉及的方法/流程的定义位置
2. **查阅标识符映射**：在 [IdentifierMapping.md](GameDesignDocus/Engineering/IdentifierMapping.md) 中查中文 → 英文映射，**不得自创英文标识符**
3. **实现代码**：按目录结构（§二）放置文件，按编码规范（§六）编写
4. **编写测试**：核心类方法/流程必须有 GUT 测试，放在 `tests/unit/` 或 `tests/integration/`
5. **同步文档**：若新增/修改字段/方法/trigger，同步更新 [IdentifierMapping.md](GameDesignDocus/Engineering/IdentifierMapping.md) 与对应 GameSystem 文档

### 7.2 设计文档与代码同步规则

- **设计文档是源定义**：GameSystem/ 定义类结构与方法签名，代码必须严格遵循
- **代码变更触发文档同步**：新增字段/方法/trigger 时，必须同步更新：
  - [IdentifierMapping.md](GameDesignDocus/Engineering/IdentifierMapping.md)（映射表）
  - 对应 GameSystem 文档（字段表/方法表/流程节点）
  - 若涉及规则变更，还需更新 GameInstructions/ 对应文档
- **文档变更触发代码评估**：设计文档变更时，评估是否需要重构代码

### 7.3 常见陷阱

#### 陷阱 1：trigger 名中英文混用

设计文档用中文（如「受到伤害时」），JSON 数据用英文（如 `"on_take_damage"`），代码中用英文常量。**三处必须一致**，映射见 [IdentifierMapping.md §五](GameDesignDocus/Engineering/IdentifierMapping.md#五trigger-名映射)。

#### 陷阱 2：技能 content/filter 代码执行

技能的 `filter` / `filter_target` / `filter_card` / `content` / `effect_code` / `win_condition_code` 字段是 **GDScript 代码字符串**，运行时通过 `Expression` 类编译执行。需建立安全沙箱，仅允许调用白名单 API（Player/Game/Monster/MapBlock 的公开方法）。详见 [DataFormat.md §三](GameDesignDocus/Engineering/DataFormat.md#三技能结构-json-schema)。

#### 陷阱 3：取消点语义

并非所有「XX前/时」都是取消点。**只有标注为取消点的 trigger 才能通过 `event.cancel()` 终止流程**。例如：
- `before_enter_block`（进入地块前）— ✅ 取消点
- `on_take_damage`（受到伤害时）— ✅ 取消点
- `before_deal_damage`（造成伤害前）— ❌ 非取消点

完整取消点清单见 [IdentifierMapping.md §五](GameDesignDocus/Engineering/IdentifierMapping.md#五trigger-名映射) 的「取消点」列。

#### 陷阱 4：移动流程的回滚例外

移动流程（`player.move_to`）被 `event.cancel()` 取消时，**会回滚地块技能挂载**（已挂载的进入地块技能会被清理）。其他流程取消时不回滚已执行钩子。详见 [Player.md moveTo](GameDesignDocus/GameSystem/Entities/Player.md) 节点 5。

#### 陷阱 5：NULL 燃料值的特殊处理

任务 4/8/9/11 的 `van_fuel_required` 为 `NULL`，表示**不通过启动面包车胜利**。此时 `check_win_condition()` 跳过面包车相关检查，仅依赖 `检查胜利条件()` 函数。详见 [Game.md 任务配置结构](GameDesignDocus/GameSystem/Game/Game.md#任务配置结构missionconfig)。

#### 陷阱 6：地块技能挂载到玩家

地块技能**不挂在 MapBlock 上触发**，而是在玩家进入地块时**挂载到 Player.skills**，由 `player.trigger()` 统一触发；离开时清理。**不要在 MapBlock 上实现 trigger 方法**。

#### 陷阱 7：目录结构处于迁移期

当前代码在 `scripts/` 与 `data/`（GDScript 硬编码），目标结构是 `src/` + `data/`（JSON）。新增代码应放在 `src/` 对应子目录，不要继续往 `scripts/` 塞游戏逻辑代码（UI 临时代码可暂留 `scripts/`）。

### 7.4 测试要求

| 维度 | 覆盖目标 | 优先级 |
|------|---------|--------|
| 核心类方法 | 95 个方法 100% 覆盖 | P0 |
| 核心流程 | 20 个流程 100% 覆盖 | P0 |
| 13 个任务 | 地图构建 + 胜负条件 100% 覆盖 | P1 |
| 6 个角色 | 初始牌堆 + 技能 API 调用 | P1 |
| 4 个怪物包 | 实体化 + 行动流程 | P2 |

测试框架：GUT，测试目录 `tests/`（待创建，当前未启用）。运行方式：

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests
```

---

## 八、文档导航

### 8.1 设计文档入口

| 入口 | 用途 |
|------|------|
| [GameDesignDocus/README.md](GameDesignDocus/README.md) | 设计文档总入口（含阅读路线图） |
| [GameDesignDocus/GameSystem/README.md](GameDesignDocus/GameSystem/README.md) | 系统架构总览 + 类继承图 + 核心流程速查表 |
| [GameDesignDocus/GameInstructions/README.md](GameDesignDocus/GameInstructions/README.md) | 游戏规则说明（A-L 编号） |
| [GameDesignDocus/Resource/README.md](GameDesignDocus/Resource/README.md) | 数据定义（卡牌/地图块/任务） |
| [GameDesignDocus/Engineering/GodotProjectStructure.md](GameDesignDocus/Engineering/GodotProjectStructure.md) | Godot 工程结构 + 编码规范 |
| [GameDesignDocus/Engineering/IdentifierMapping.md](GameDesignDocus/Engineering/IdentifierMapping.md) | 中文 → 英文标识符完整映射 |
| [GameDesignDocus/Engineering/DataFormat.md](GameDesignDocus/Engineering/DataFormat.md) | markdown → JSON 数据格式规范 |

### 8.2 工程文档

| 文档 | 用途 |
|------|------|
| [docs/feasibility-analysis.md](docs/feasibility-analysis.md) | 核心逻辑层开发可行性分析（已结论：可开始） |
| [docs/design-gaps.md](docs/design-gaps.md) | 6 大支撑系统缺失清单（UI/3D/AI/网络/存档/工程结构） |

### 8.3 快速定位

| 需求 | 查阅位置 |
|------|---------|
| 某个方法的伪代码 | [GameSystem/README.md 核心流程速查表](GameDesignDocus/GameSystem/README.md#核心流程速查) |
| 某个 trigger 的英文常量与取消点 | [IdentifierMapping.md §五](GameDesignDocus/Engineering/IdentifierMapping.md#五trigger-名映射) |
| 某个 event 字段 | [IdentifierMapping.md §六](GameDesignDocus/Engineering/IdentifierMapping.md#六event-字段映射) 或 [EventSystem.md §2.2](GameDesignDocus/GameSystem/Core/EventSystem.md#22-按流程类型的字段) |
| 某张卡牌/角色的数据 | [Resource/](GameDesignDocus/Resource/) 对应子包 |
| 某个任务的地图与胜利条件 | [Resource/MissionPacks/basic-mission_N.md](GameDesignDocus/Resource/MissionPacks/) |
| 完整事件流程节点表 | [J_gameEventFlow.md](GameDesignDocus/GameInstructions/J_gameEventFlow.md) |
| 游戏术语与 trigger 索引 | [K_gameTerminology.md](GameDesignDocus/GameInstructions/K_gameTerminology.md) |

---

## 九、待决策与已知差异

| # | 项 | 现状 | 目标 | 决策 |
|---|----|------|------|------|
| 1 | 目录结构 | `scripts/` + `data/`(GDScript) | `src/` + `data/`(JSON) + `tests/` + `tools/` | 按 [GodotProjectStructure.md](GameDesignDocus/Engineering/GodotProjectStructure.md) 迁移 |
| 2 | 数据加载 | GDScript 硬编码（`Survivors._ALL` 等） | markdown → JSON → DataManager | 见 §五.3 迁移步骤 |
| 3 | 数据类基类 | `extends Resource` | `extends RefCounted`（按设计文档） | 迁移时调整 |
| 4 | autoload | RoomState / Settings | + Game / DataManager / EventBus | 阶段 1 核心逻辑实现时新增 |
| 5 | UI 交互接口 | 未定义 | IPlayerInput 接口（命令行 UI 先行） | 见 [docs/design-gaps.md §2.2](docs/design-gaps.md) |
| 6 | 3D 表现层 | 未开始 | 3D 场景 + 动画 + 特效 | 阶段 2 前补充设计 |
| 7 | AI 玩家 | 未开始 | AI 决策架构 + 难度等级 | 阶段 3 前补充设计 |
| 8 | 网络/联机 | 未开始 | 状态同步 + 房间系统 | 阶段 4 前补充设计 |
| 9 | 存档系统 | 未开始 | JSON（开发期）+ Godot Resource（发布期） | 阶段 3 前补充设计 |

---

## 十、约定

- **伪代码风格**：GDScript 风味伪代码，`function` 关键字声明方法，`#` 注释
- **trigger 命名**：中文「XX前/时/后」，复合触发用「、」分隔（如 `trigger: 游戏开始时、受到伤害时`）
- **标注约定**：`[提案]` 表示尚未落地的提案性命名，`待定义` 表示语义待定
- **文档引用路径**：AGENTS.md 引用 GameDesignDocus/ 下的文档时用相对路径（如 `[Entity.md](GameDesignDocus/GameSystem/Core/Entity.md)`）
