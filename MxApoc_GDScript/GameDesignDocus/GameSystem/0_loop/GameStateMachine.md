# 游戏状态机（GameStateMachine）

> 本文档定义游戏整体状态机，分为两层：
> - **上层生命周期**：主菜单 → 游戏房间 → 游戏中 → 游戏结束 → 返回主菜单
> - **内层回合循环**：座位轮转 + 玩家回合阶段（21 节点，与 [D_gameFlow.md](../../GameInstructions/D_gameFlow.md) 对齐）
> 文档创建日期：2026-07-04 · 状态机定义补全日期：2026-07-07

---

## 目录

- [1. 概述](#1-概述)
- [2. 状态机分层](#2-状态机分层)
- [3. 上层生命周期状态机](#3-上层生命周期状态机)
  - [3.1 状态列表](#31-状态列表)
  - [3.2 状态转换图](#32-状态转换图)
  - [3.3 状态转换条件表](#33-状态转换条件表)
  - [3.4 各状态说明](#34-各状态说明)
- [4. 内层回合循环状态机](#4-内层回合循环状态机)
  - [4.1 游戏初始化阶段](#41-游戏初始化阶段)
  - [4.2 座位轮转循环](#42-座位轮转循环)
  - [4.3 玩家回合阶段（21 节点）](#43-玩家回合阶段21-节点)
  - [4.4 游戏结束判定](#44-游戏结束判定)
- [5. 状态与 UI 控制器映射](#5-状态与-ui-控制器映射)
- [6. 状态与 RoomState 关系](#6-状态与-roomstate-关系)
- [7. 实现状态](#7-实现状态)

---

## 1. 概述

游戏状态机管控整个游戏流程的状态切换。设计原则：

- **单源真理**：状态由 [RoomState](../../../scripts/autoload/room_state.gd) autoload 单例跨场景持有；UI 控制器仅做绑定与切换。
- **场景与状态对应**：每个上层状态对应一个 `.tscn` 场景文件（[MainMenu.tscn](../../../scenes/MainMenu.tscn) / [GameRoom.tscn](../../../scenes/GameRoom.tscn) / [GameScene.tscn](../../../scenes/GameScene.tscn)）。
- **回合流程事件化**：玩家回合内的阶段切换通过事件钩子暴露给技能（见 [J_gameEventFlow.md §8](../../GameInstructions/J_gameEventFlow.md#8-玩家回合流程)）。
- **AI 玩家复用流程**：AI 座位与真人座位走相同的回合流程，仅在"行动阶段"内的决策逻辑不同（待实现）。

---

## 2. 状态机分层

```
┌─────────────────────────────────────────────────────────────┐
│ 上层生命周期（场景级）                                       │
│                                                             │
│  MainMenu ──► GameRoom ──► GameScene(初始化)                │
│      ▲           │                │                         │
│      │           ◄────────────────┘                         │
│      │                                                       │
│      │                GameScene(游戏中)                      │
│      │                       │                               │
│      └───────────────────────┘                              │
│                  GameScene(游戏结束)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 内层回合循环（GameScene 内）                                 │
│                                                             │
│  游戏初始化                                                  │
│      │                                                      │
│      ▼                                                      │
│  ┌─► 座位轮转 ──► 玩家回合（21 节点）──┐                    │
│  │                                       │                  │
│  │                                       ▼                  │
│  └───────────── 胜利/失败判定？ ◄─────────┘                  │
│                    │                                        │
│                    ▼                                        │
│              游戏结束                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 上层生命周期状态机

### 3.1 状态列表

| 状态 | 场景 | UI 控制器 | RoomState 状态 | 说明 |
|------|------|-----------|----------------|------|
| `MAIN_MENU` | [MainMenu.tscn](../../../scenes/MainMenu.tscn) | [main_menu.gd](../../../scripts/ui/main_menu.gd) | 初始（或 `clear()` 后） | 主菜单：开始游戏/设置/退出 |
| `GAME_ROOM` | [GameRoom.tscn](../../../scenes/GameRoom.tscn) | [game_room.gd](../../../scripts/ui/game_room.gd) | 配置中（任务/变体/座位） | 房间配置：选任务、变体、座位、求生者 |
| `GAME_INITIALIZING` | [GameScene.tscn](../../../scenes/GameScene.tscn) | [game_scene.gd](../../../scripts/ui/game_scene.gd) | 已确定配置 | 游戏初始化：加载资源、洗牌、放置立像、抓初始手牌 |
| `GAME_RUNNING` | GameScene.tscn | game_scene.gd | 已确定配置 | 游戏进行中：座位轮转 + 玩家回合循环 |
| `GAME_OVER` | GameScene.tscn | game_scene.gd | 已确定配置 + 结果 | 游戏结束：显示胜利/失败结果 |
| `QUITTING` | — | — | — | 退出游戏进程 |

### 3.2 状态转换图

```
                    [启动游戏]
                        │
                        ▼
                 ┌─────────────┐
                 │  MAIN_MENU  │◄────────────────────────┐
                 └─────────────┘                         │
                   │       │                             │
        [开始游戏] │       │ [退出]                      │
                   ▼       ▼                             │
          ┌──────────┐  QUITTING                        │
          │ GAME_ROOM│                                  │
          └──────────┘                                  │
             │       ▲                                  │
   [开始游戏]│       │ [返回]                           │
             ▼       │                                  │
    ┌─────────────────────┐                            │
    │  GAME_INITIALIZING  │                            │
    └─────────────────────┘                            │
             │                                        │
   [初始化完成]│                                        │
             ▼                                        │
       ┌──────────────┐  [全灭/牌堆耗尽]               │
       │ GAME_RUNNING ├─────────────┐                  │
       └──────────────┘             ▼                  │
             │                ┌──────────┐             │
   [胜利条件达成]│                │ GAME_OVER│             │
             ▼                └──────────┘             │
       ┌──────────┐                  │                  │
       │ GAME_OVER│                  │ [返回主菜单]     │
       └──────────┘──────────────────┼─────────────────►
             │                        │
             └────────────────────────┘
             [返回主菜单]
```

### 3.3 状态转换条件表

| 源状态 | 目标状态 | 触发条件 | 触发位置 |
|--------|----------|----------|----------|
| `MAIN_MENU` | `GAME_ROOM` | 玩家点击"开始游戏"按钮 | [main_menu.gd `_on_start_pressed()`](../../../scripts/ui/main_menu.gd) |
| `MAIN_MENU` | `QUITTING` | 玩家点击"退出"按钮 | [main_menu.gd `_on_quit_pressed()`](../../../scripts/ui/main_menu.gd) |
| `GAME_ROOM` | `MAIN_MENU` | 玩家点击"返回"按钮 | [game_room.gd `_on_back()`](../../../scripts/ui/game_room.gd) |
| `GAME_ROOM` | `GAME_INITIALIZING` | 玩家点击"开始游戏"按钮 + `RoomState.is_ready_to_start()` 为 `true` | [game_room.gd `_on_start_game()`](../../../scripts/ui/game_room.gd) |
| `GAME_INITIALIZING` | `GAME_RUNNING` | 游戏初始化流程完成（见 [§4.1](#41-游戏初始化阶段)） | game_scene.gd（待实现） |
| `GAME_RUNNING` | `GAME_OVER` | 胜利条件达成 / 失败条件达成（见 [§4.4](#44-游戏结束判定)） | game_scene.gd（待实现） |
| `GAME_OVER` | `MAIN_MENU` | 玩家点击"返回主菜单"按钮 | game_scene.gd `_on_back_pressed()`（清空 `RoomState`） |

### 3.4 各状态说明

#### 3.4.1 `MAIN_MENU` 主菜单

- **入口**：游戏启动 / 从 `GAME_ROOM` 或 `GAME_OVER` 返回。
- **行为**：显示主菜单按钮（开始游戏、设置、退出）。设置对话框（[SettingsDialog.tscn](../../../scenes/SettingsDialog.tscn)）可在此弹出。
- **状态**：`RoomState` 为初始值（1 个真人座，无任务，无变体）。
- **出口**：玩家选择"开始游戏" → `GAME_ROOM`；或"退出" → `QUITTING`。

#### 3.4.2 `GAME_ROOM` 游戏房间

- **入口**：从 `MAIN_MENU` 进入。
- **行为**：房主配置任务（或随机任务）、变体（危机四伏/大饥荒/同生共死）、座位（1-4 个，类型为真人/AI/空，每个座位选求生者）。详见 [C_gameSetup.md "游戏房间界面"](../../GameInstructions/C_gameSetup.md)。
- **状态**：`RoomState.selected_mission` / `selected_mission_is_random` / `variants` / `seats` 被持续同步。
- **出口**：玩家点击"开始游戏"且 `RoomState.is_ready_to_start()` 为 `true`（非空座位均已选择求生者） → `GAME_INITIALIZING`；或点击"返回" → `MAIN_MENU`。

#### 3.4.3 `GAME_INITIALIZING` 游戏初始化

- **入口**：从 `GAME_ROOM` 进入。
- **行为**：执行 [C_gameSetup.md "游戏初始化"](../../GameInstructions/C_gameSetup.md#游戏初始化) + ["游戏开局"](../../GameInstructions/C_gameSetup.md#游戏开局) 流程，详见 [§4.1](#41-游戏初始化阶段)。
- **状态**：`RoomState` 已确定；构建 game 对象（待实现）持有运行时状态（地图、牌堆、玩家区域等）。
- **出口**：初始化完成 → `GAME_RUNNING`。

#### 3.4.4 `GAME_RUNNING` 游戏进行中

- **入口**：从 `GAME_INITIALIZING` 进入。
- **行为**：按座位顺序轮流进行回合，详见 [§4.2](#42-座位轮转循环) 与 [§4.3](#43-玩家回合阶段21-节点)。
- **状态**：game 对象持有运行时状态；`RoomState` 配置不再变。
- **出口**：胜利条件或失败条件触发 → `GAME_OVER`。

#### 3.4.5 `GAME_OVER` 游戏结束

- **入口**：从 `GAME_RUNNING` 进入。
- **行为**：显示游戏结果（胜利/失败）与原因。
- **状态**：`RoomState` 仍持有配置（用于复盘），game 对象持有最终状态。
- **出口**：玩家点击"返回主菜单" → `MAIN_MENU`（清空 `RoomState`）。

---

## 4. 内层回合循环状态机

### 4.1 游戏初始化阶段

> 详见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md) "游戏初始化" + "游戏开局"。

进入 `GAME_INITIALIZING` 状态后，按顺序执行以下步骤：

| 步骤 | 操作 | 对应文档 |
|------|------|----------|
| 1 | 加载本局游戏的所有求生者角色卡、立像和求生者游戏牌堆 | [SurvivorPacks/](../../Resource/SurvivorPacks/) |
| 2 | 根据任务加载本局游戏的所有怪物卡，洗混组成怪物牌堆 | [MonsterPacks/](../../Resource/MonsterPacks/) · [任务怪物包类型](../../Resource/MissionPacks/) |
| 3 | 根据任务说明构建三个不同的拾荒牌堆（蓝、绿、红），分别洗乱 | [ScavengePacks/](../../Resource/ScavengePacks/) |
| 4 | 根据任务说明构建地图 | [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md) · [任务地图块配置](../../Resource/MissionPacks/) |
| 5 | 根据任务说明，将玩家立像放到游戏地图中的初始地图块（出生点 = 编号 0 的地块） | [C_gameSetup.md](../../GameInstructions/C_gameSetup.md) |
| 6 | 初始化全局区域（怪物牌堆/怪物弃牌堆/三色拾荒牌堆/拾荒弃牌堆/地图区域/卡牌结算区/所有玩家区域） | [entity.md §8](../0_event/entity.md#8-实体与区域对象待定义) |
| 7 | 初始化每个玩家区域（角色卡/手牌区/装备区/怪物区/游戏牌堆/游戏牌弃牌堆） | [entity.md §8](../0_event/entity.md#8-实体与区域对象待定义) |
| 8 | 每个玩家从求生者游戏牌堆抓 4 张牌作为初始手牌（手牌上限 10） | `player.draw(4)` |
| 9 | 每名玩家可选进行一次重调：把最多 4 张刚抓的卡牌洗回牌堆，抓等量的牌 | `player.洗牌(pile)` |
| 10 | 每名玩家抓取一张怪物卡，放到自己的角色面前 | `player.drawMonster(1)` |
| 11 | 正式开始游戏，按座位次序依次进行回合 | 进入 [§4.2](#42-座位轮转循环) |

> **"游戏开始时" trigger**：步骤 1-7 完成后、步骤 8 开始前触发「游戏开始时」事件（如 gunslinger 快速拔枪在此装备柯尔特手枪）。**待澄清**：确切触发时机需明确，见 [待定义方法.md §9](../待定义方法.md#9-待澄清的歧义)。

### 4.2 座位轮转循环

> 详见 [D_gameFlow.md](../../GameInstructions/D_gameFlow.md)。

```
游戏开局
    │
    ▼
┌─► seat1 玩家回合 ──► seat2 玩家回合 ──► seat3 玩家回合 ──► seat4 玩家回合 ──┐
│                                                                              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
    │
    ▼ (每个回合结束时检查胜利/失败条件)
游戏结束
```

- **座位顺序**：按 `RoomState.seats` 数组顺序（0-3）。
- **空座位跳过**：`seat.type == "empty"` 的座位直接跳过。
- **死亡玩家跳过**：已 `playerDeath` 的玩家在后续轮次中跳过。
- **AI 玩家**：`seat.type == "ai"` 的座位由 AI 决策逻辑接管（待实现，见 [§7](#7-实现状态)）。

### 4.3 玩家回合阶段（21 节点）

> 详见 [D_gameFlow.md](../../GameInstructions/D_gameFlow.md) · [J_gameEventFlow.md §8](../../GameInstructions/J_gameEventFlow.md#8-玩家回合流程)。

每个玩家的回合按以下 21 节点顺序执行：

| 节点 | 阶段 | trigger 名 | 系统操作 |
|------|------|------------|----------|
| 1 | 进入玩家回合 | — | 非钩子节点 |
| 2 | 回合开始前 | `回合开始前` | — |
| 3 | 回合开始时 | `回合开始时` | 如 MapBlocks（避难所、电厂） |
| 4 | 怪物出生前 | `怪物出生前` | — |
| 5 | 怪物出生时 | `怪物出生时` | 进行怪物出生检定（[§4.3.1](#431-怪物出生检定)） |
| 6 | 摸牌阶段前 | `摸牌阶段前` | — |
| 7 | 摸牌阶段 | — | 从游戏牌堆抓 1 张牌；牌堆空 → 玩家死亡 |
| 8 | 行动阶段前 | `行动阶段前` | 含潜行检定（地块有怪物标记时，[§4.3.2](#432-潜行检定)） |
| 9 | 行动阶段 | — | 执行 4 个行动 + 免费行动（制衡、交易） |
| 10 | 行动阶段结束前 | `行动阶段结束前` | 如 gunslinger（扣动扳机让我快乐 subSkill） |
| 11 | 行动阶段结束时 | `行动阶段结束时` | — |
| 12 | 求生者饥饿状态结算前 | `求生者饥饿状态结算前` | 如 firefighter（野地夹克 subSkill） |
| 13 | 求生者饥饿状态结算时 | `求生者饥饿状态结算时` | `player.increaseHunger(1)` |
| 14 | 求生者中毒状态结算前 | `求生者中毒状态结算前` | — |
| 15 | 求生者中毒状态结算时 | `求生者中毒状态结算时` | `player.poison()`（有中毒标记时） |
| 16 | 面前怪物行动前 | `面前怪物行动前` | — |
| 17 | 面前怪物行动时 | `面前怪物行动时` | 面前怪物按进入顺序行动（[§4.3.3](#433-面前怪物行动)） |
| 18 | 回合结束前 | `回合结束前` | 如 gunslinger（扣动扳机让我快乐 subSkill）、MapBlocks（游乐园、警察局、城市街道） |
| 19 | 回合结束时 | `回合结束时` | 如 MapBlocks（游乐园） |
| 20 | 退出玩家回合 | — | 非钩子节点 |
| 21 | 胜利判定 | — | 检查胜利条件（见 [§4.4](#44-游戏结束判定)） |

#### 4.3.1 怪物出生检定（节点 5）

> 详见 [E_gameJudge.md](../../GameInstructions/E_gameJudge.md) · [Judge.md](../4_judge/Judge.md)。

调用 `player.monsterSpawnJudge()`：
1. 投两颗大骰子得 `result`（2-12）
2. 找出所有已展示且 `monster_spawn_value == result` 的地图块
3. 对每个匹配地块：
   - 标记数 < 3 → 标记数 +1
   - 标记数 = 3 且地块上有玩家 → 该地块上每位玩家抓 1 张怪物卡（`player.drawMonster(1)`）

#### 4.3.2 潜行检定（节点 8 前置）

> 详见 [E_gameJudge.md](../../GameInstructions/E_gameJudge.md) · [Judge.md](../4_judge/Judge.md)。

**触发条件**：玩家所在地块上有怪物标记。

调用 `player.sneakJudge()`：
- 潜行值 = 玩家潜行值 - (地块怪物数 + 怪物标记数)
- 投两颗大骰子得 `result`
- `result ≤ 潜行值` → 检定成功，无事发生
- `result > 潜行值` → 检定失败：移除该地图块上的所有怪物标记，每移除一个怪物标记就抓一张怪物卡

#### 4.3.3 面前怪物行动（节点 17）

> 详见 [I_monsterAction.md](../../GameInstructions/I_monsterAction.md) · [J_gameEventFlow.md §9](../../GameInstructions/J_gameEventFlow.md#9-怪物行动流程)。

玩家面前的怪物按进入怪物区的先后顺序逐个行动（先进入的先行动）：

| 子节点 | trigger 名 | 触发对象 | 说明 |
|--------|------------|----------|------|
| 1 | `怪物行动前` | monster | 单个怪物行动前 |
| 2 | `怪物行动时` | monster | 怪物开始行动 |
| 3 | `怪物攻击前` | monster | 攻击前 |
| 4 | `怪物攻击时` | monster | 根据射程对目标发动攻击 |
| 5 | `怪物攻击后` | monster | 攻击后 |
| 6 | `怪物行动后` | monster | 单个怪物行动结束 |

> **击晕怪物跳过**：被击晕的怪物跳过整个行动流程（节点 1-6）。

### 4.4 游戏结束判定

> 详见 [G_gameOver.md](../../GameInstructions/G_gameOver.md)。

#### 4.4.1 失败条件

| 条件 | 触发位置 | 行为 |
|------|----------|------|
| 所有玩家死亡 | [DeathFlow.md](../0_event/DeathFlow.md) `playerDeath` 节点 7 | `game.allPlayersDead()` 为 `true` → `game.gameOver("lose")` |
| 同生共死变体下任何玩家死亡 | [DeathFlow.md](../0_event/DeathFlow.md) `playerDeath` | 启用 `shared_fate` 变体时，任何玩家死亡即所有求生者输掉游戏 |
| 怪物牌堆耗尽 | [DrawFlow.md](../DrawFlow.md) `drawMonster` | 重洗怪物弃牌堆后仍为空 → `game.gameOver("lose")` |

#### 4.4.2 胜利条件

| 条件 | 触发位置 | 行为 |
|------|----------|------|
| 完成任务 + 加足燃料 + 所有存活玩家回到面包车 + 面包车无怪物/标记 | 玩家回合节点 21（回合结束时） | `game.gameOver("win")` |

**胜利条件细则**（[G_gameOver.md](../../GameInstructions/G_gameOver.md)）：
1. 玩家完成了任务（任务卡上的目标）
2. 往"面包车"添加了所需要的燃料值（所需燃料值在任务卡上查看）
3. 所有存活玩家都返回到了地图块"面包车"上
4. 地图块"面包车"内没有任何怪物和怪物标记

> **时机**：在玩家的回合结束时才触发胜利判定（玩家依然会在回合结束前受到伤害）。

---

## 5. 状态与 UI 控制器映射

| 状态 | UI 控制器 | 关键方法 | 行为 |
|------|-----------|----------|------|
| `MAIN_MENU` | [main_menu.gd](../../../scripts/ui/main_menu.gd) | `_on_start_pressed()` | 切换到 GameRoom 场景 |
| `MAIN_MENU` | main_menu.gd | `_on_settings_pressed()` | 弹出 SettingsDialog |
| `MAIN_MENU` | main_menu.gd | `_on_quit_pressed()` | 退出游戏 |
| `GAME_ROOM` | [game_room.gd](../../../scripts/ui/game_room.gd) | `_on_mission_selected(idx)` | 选择任务，更新 `RoomState.selected_mission` |
| `GAME_ROOM` | game_room.gd | `_on_variant_toggled(id, toggled)` | 切换变体，更新 `RoomState.variants` |
| `GAME_ROOM` | game_room.gd | `_on_add_seat()` / `_on_remove_seat()` | 增减座位，更新 `RoomState.seats` |
| `GAME_ROOM` | game_room.gd | `_on_seat_changed(idx)` | 座位类型/求生者变更 |
| `GAME_ROOM` | game_room.gd | `_on_start_game()` | 检查 `is_ready_to_start()`，切换到 GameScene |
| `GAME_ROOM` | game_room.gd | `_on_back()` | 返回主菜单 |
| `GAME_INITIALIZING` | [game_scene.gd](../../../scripts/ui/game_scene.gd) | `_ready()` | 执行初始化流程（待实现） |
| `GAME_RUNNING` | game_scene.gd | — | 渲染游戏状态，处理玩家输入（待实现） |
| `GAME_OVER` | game_scene.gd | — | 显示结果，提供"返回主菜单"按钮（待实现） |
| `GAME_OVER` | game_scene.gd | `_on_back_pressed()` | 清空 `RoomState`，返回主菜单 |

> **当前实现**：`GameScene` 仅显示 `RoomState.snapshot()` 文本，实际游戏逻辑未实现（见 [AGENTS.md §6.2](../../../AGENTS.md)）。

---

## 6. 状态与 RoomState 关系

> 详见 [docs/autoloads.md](../../../docs/autoloads.md) · [scripts/autoload/room_state.gd](../../../scripts/autoload/room_state.gd)。

`RoomState` 是跨场景共享的 autoload 单例，持有开局配置：

| RoomState 字段 | 类型 | 在哪个状态被读写 |
|----------------|------|------------------|
| `selected_mission` | `MissionData` | `GAME_ROOM` 写入；`GAME_INITIALIZING` 读取（构建地图/牌堆） |
| `selected_mission_is_random` | `bool` | `GAME_ROOM` 写入；`GAME_INITIALIZING` 读取（随机抽取任务） |
| `variants` | `Dictionary` | `GAME_ROOM` 写入；`GAME_RUNNING` 读取（应用变体规则如同生共死） |
| `seats` | `Array` | `GAME_ROOM` 写入；`GAME_INITIALIZING` 读取（创建玩家实体） |

**生命周期**：
- `MAIN_MENU` 进入时：`RoomState.clear()` 重置为初始值（1 个真人座，无任务，无变体）
- `GAME_OVER` 返回 `MAIN_MENU` 时：`RoomState.clear()` 清空

**待引入**：`game` 对象（持有运行时状态：地图、牌堆、玩家区域、当前回合玩家等）。当前轮次无 `game` 对象，相关方法（`game.log`/`game.gameOver`/`game.allPlayersDead`/`game.getScavengePile`/`game.removeCard` 等）为 stub 或由调用方注入参数，详见 [待定义方法.md §5](../待定义方法.md#5-game-方法gamexxx)。

---

## 7. 实现状态

### 7.1 已实现

- 上层生命周期状态切换（`MAIN_MENU` ↔ `GAME_ROOM` ↔ `GameScene`）
- `RoomState` 跨场景状态持有
- UI 控制器绑定（MainMenu/GameRoom/GameScene/SeatItem/SettingsDialog）
- 设置持久化（`Settings` autoload，全屏切换）

### 7.2 待实现

| 待实现项 | 说明 | 依赖 |
|----------|------|------|
| `GAME_INITIALIZING` 流程 | 加载资源、构建地图/牌堆、放置立像、抓初始手牌 | game 对象、MapBlock 数据落地、怪物包/拾荒包/地图块包数据落地 |
| `GAME_RUNNING` 回合循环 | 座位轮转 + 21 节点回合流程 | game 对象、Player 完整实现、Monster 实现 |
| `GAME_OVER` 结果展示 | 胜利/失败原因、返回主菜单 | game 对象 |
| `game` 对象 | 持有运行时状态、提供 game.xxx 方法 | — |
| AI 玩家决策 | AI 在行动阶段内的决策逻辑 | 行动阶段实现 |
| 怪物行动流程 | 节点 17 的面前怪物行动 | Monster 实现 |
| 胜利/失败判定 | 节点 21 检查胜利条件、`game.allPlayersDead`/`game.gameOver` | game 对象 |

> **当前状态**：5 轮自底向上迭代已完成（01 EventTrigger → 02 Player 骨架 → 03 DamageFlow → 04 PlayerState → 05 Judge），详见 [spec/roadmap.md](../../../spec/roadmap.md)。`GameScene` 仅显示 `RoomState.snapshot()` 文本占位。
