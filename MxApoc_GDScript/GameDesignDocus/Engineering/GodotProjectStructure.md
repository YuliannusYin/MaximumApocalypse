# Godot 工程结构设计

> 本文档定义 Maximum Apocalypse Godot 项目的目录结构、autoload 配置、场景树组织、编码规范与测试结构。
> **编码规范**：方法名/变量名使用 **snake_case**（GDScript 官方推荐风格）。
> **数据格式**：Resource 数据使用 JSON 格式加载（详见 [DataFormat.md](DataFormat.md)）。
> **标识符映射**：中文设计标识符 → 英文代码标识符的完整映射见 [IdentifierMapping.md](IdentifierMapping.md)。

---

## 一、项目目录结构

```
MxApoc_GDScript/
│
├── project.godot                      # Godot 项目配置文件
├── AGENTS.md                          # AI Agent 项目说明书
│
├── GameDesignDocus/                   # 游戏设计文档（设计阶段产物，不参与编译）
│   ├── GameSystem/                    # 系统设计（伪代码）
│   ├── GameInstructions/              # 规则说明
│   ├── Resource/                      # 数据定义（markdown 格式）
│   └── Engineering/                   # 工程设计（本文档所在目录）
│
├── spec/                              # 规格文档（可行性分析、设计待完善报告等）
│
├── src/                               # 源代码（GDScript）
│   ├── core/                          # GameSystem/Core 对应实现
│   │   ├── entity.gd                  # Entity 基类
│   │   ├── event_system.gd            # EventSystem 事件系统
│   │   └── game_state_machine.gd      # GameStateMachine 状态机
│   │
│   ├── entities/                      # GameSystem/Entities 对应实现
│   │   ├── player.gd                  # Player 玩家类
│   │   ├── monster.gd                 # Monster 怪物类
│   │   ├── card.gd                    # Card 卡牌基类 + 子类
│   │   └── map_block.gd               # MapBlock 地图块类
│   │
│   ├── game/                          # GameSystem/Game 对应实现
│   │   └── game.gd                    # Game 游戏全局类
│   │
│   ├── common/                        # GameSystem/Common 对应实现
│   │   ├── pile.gd                    # Pile 牌堆类
│   │   ├── role_card.gd               # RoleCard 角色卡类
│   │   └── skill.gd                   # Skill 技能结构
│   │
│   ├── data/                          # 数据加载层
│   │   ├── data_manager.gd            # 数据管理器（autoload）
│   │   ├── survivor_loader.gd         # 求生者数据加载器
│   │   ├── scavenge_loader.gd         # 拾荒牌堆加载器
│   │   ├── monster_loader.gd          # 怪物包加载器
│   │   ├── mission_loader.gd          # 任务包加载器
│   │   └── map_block_loader.gd        # 地图块加载器
│   │
│   ├── ui/                            # UI 层（待设计，详见 design-gaps.md）
│   │   ├── ui_interface.gd            # IPlayerInput 接口定义
│   │   ├── cli_ui.gd                  # 命令行 UI（开发期测试用）
│   │   └── ...
│   │
│   ├── ai/                            # AI 玩家层（待设计，详见 design-gaps.md）
│   ├── network/                       # 网络层（待设计，详见 design-gaps.md）
│   └── save/                          # 存档层（待设计，详见 design-gaps.md）
│
├── data/                              # 运行时数据文件（JSON 格式）
│   ├── survivors/                     # 求生者数据（6 个 JSON 文件）
│   │   ├── firefighter.json
│   │   ├── gunslinger.json
│   │   ├── hunter.json
│   │   ├── mechanic.json
│   │   ├── surgeon.json
│   │   └── veteran.json
│   │
│   ├── scavenge/                      # 拾荒牌堆数据（4 个 JSON 文件）
│   │   ├── blue.json
│   │   ├── green.json
│   │   ├── red.json
│   │   └── gray.json
│   │
│   ├── monsters/                      # 怪物包数据（4 个 JSON 文件）
│   │   ├── alien.json
│   │   ├── mutant.json
│   │   ├── robot.json
│   │   └── zombie.json
│   │
│   ├── missions/                      # 任务包数据（13 个 JSON 文件）
│   │   ├── mission_0.json ~ mission_12.json
│   │
│   └── map_blocks/                    # 地图块数据
│       └── map_blocks.json
│
├── scenes/                            # Godot 场景文件（.tscn）
│   ├── main.tscn                      # 主场景
│   ├── game_board.tscn                # 游戏棋盘场景（3D，待设计）
│   └── ...
│
├── assets/                            # 美术/音效资源（待制作）
│   ├── models/                        # 3D 模型
│   ├── textures/                      # 贴图
│   ├── audio/                         # 音效/音乐
│   └── ui/                            # UI 图标
│
├── tests/                             # 单元测试
│   ├── unit/                          # 单元测试
│   │   ├── test_entity.gd
│   │   ├── test_player.gd
│   │   ├── test_monster.gd
│   │   ├── test_game.gd
│   │   └── ...
│   ├── integration/                   # 集成测试
│   │   ├── test_combat_flow.gd        # 伤害流程测试
│   │   ├── test_turn_flow.gd          # 回合流程测试
│   │   └── ...
│   └── data/                          # 数据验证测试
│       ├── test_mission_load.gd       # 任务加载测试
│       └── ...
│
└── tools/                             # 工具脚本
    ├── markdown_to_json.gd            # markdown → JSON 转换工具
    └── data_validator.gd              # 数据验证工具
```

> **设计文档 vs 源代码**：`GameDesignDocus/` 是设计源文档（markdown + 伪代码），`src/` 是 GDScript 实现。两者通过 [IdentifierMapping.md](IdentifierMapping.md) 建立映射关系。设计文档变更时需同步更新代码，反之亦然。

---

## 二、Autoload 配置

在 `project.godot` 中注册以下 autoload 单例：

| Autoload 名 | 类 | 路径 | 说明 |
|-------------|---|------|------|
| `Game` | `Game` | `res://src/game/game.gd` | 游戏全局实例，管理全局区域、地图、任务配置、状态机委托 |
| `DataManager` | `DataManager` | `res://src/data/data_manager.gd` | 数据加载与管理，负责从 JSON 加载所有 Resource 数据 |
| `EventBus` | `EventBus` | `res://src/core/event_bus.gd` | 全局事件总线（可选，用于 UI 层订阅游戏事件） |

### Autoload 初始化顺序

```
1. DataManager   # 先加载数据（无依赖）
2. Game          # 再初始化游戏（依赖 DataManager 提供的数据）
3. EventBus      # 最后初始化事件总线（供 UI 订阅）
```

### project.godot 配置示例

```ini
[autoload]

DataManager="*res://src/data/data_manager.gd"
Game="*res://src/game/game.gd"
EventBus="*res://src/core/event_bus.gd"
```

---

## 三、场景树组织

### 3.1 主场景结构（开发期）

```
Main (Node)
├── GameLogic (Node)           # 游戏逻辑节点
│   └── (Game autoload 实例管理所有游戏状态)
├── CLI (Control)              # 命令行 UI（开发期）
│   ├── Output (RichTextLabel)
│   └── Input (LineEdit)
└── TestRunner (Node)          # 测试运行器（仅 debug 模式）
```

### 3.2 游戏棋盘场景（阶段 2+，待设计）

```
GameBoard (Node3D)
├── Camera (Camera3D)
├── Lighting (DirectionalLight3D + AmbientLight)
├── Map (Node3D)
│   ├── MapBlocks (Node3D)
│   │   └── (MapBlock3D 实例 × N)
│   └── Marks (Node3D)
├── Players (Node3D)
│   └── (Player3D 实例 × 4)
├── Monsters (Node3D)
│   └── (Monster3D 实例 × N)
├── Cards (Node3D)
│   ├── HandAreas (Node3D)
│   ├── EquipmentAreas (Node3D)
│   └── MonsterZones (Node3D)
└── UI (CanvasLayer)
    ├── HUD (Control)
    ├── ActionPanel (Control)
    └── DialogLayer (Control)
```

---

## 四、编码规范

### 4.1 命名规范

| 类型 | 风格 | 示例 |
|------|------|------|
| 类名 | PascalCase | `Player`、`GameStateMachine`、`MapBlock` |
| 文件名 | snake_case | `player.gd`、`game_state_machine.gd`、`map_block.gd` |
| 方法名 | snake_case | `draw_card()`、`move_to()`、`check_win_condition()` |
| 变量名 | snake_case | `current_hp`、`action_count`、`monster_zone` |
| 常量 | UPPER_SNAKE_CASE | `MAX_HP`、`DEFAULT_HUNGER` |
| 枚举值 | UPPER_SNAKE_CASE | `MONSTER_LEVEL.BOSS`、`MONSTER_LEVEL.ELITE` |
| 信号 | snake_case | `player_died`、`card_drawn` |
| 私有方法/变量 | _前缀 | `_update_internal_state()`、`_cache` |

### 4.2 GDScript 风格要点

- 缩进：Tab（非空格）
- 行尾：无分号
- 类型注解：显式声明变量类型（`var hp: int = 10`）
- 函数返回类型：显式声明（`func draw_card() -> Card:`）
- 类继承：`class_name Player extends Entity`
- 信号定义：`signal player_died(player: Player, source: Entity)`

### 4.3 类定义模板

```gdscript
class_name Player extends Entity

# === 信号 ===
signal player_died(player: Player, source: Entity)
signal hp_changed(player: Player, old_value: int, new_value: int)

# === 常量 ===
const MAX_EQUIPMENT_SLOTS: int = 6
const MAX_MONSTER_MARKS: int = 3

# === 枚举 ===
enum Phase { OUT_OF_TURN, TURN_START, MONSTER_SPAWN, DRAW, ACTION, HUNGER, POISON, MONSTER_ACTION, TURN_END }

# === 字段 ===
var hp: int
var max_hp: int
var hunger: int
var stealth: int
var action_count: int
var max_action_count: int
var hand: Array[Card] = []
var equipment_zone: Array[EquipmentCard] = []
var monster_zone: Array[Monster] = []
var game_deck: Pile
var game_discard_pile: Pile
var current_block: MapBlock
var in_phase: Phase = Phase.OUT_OF_TURN

# === 方法 ===
func draw_card(n: int) -> void:
    # 方法实现
    pass

func move_to(target: MapBlock) -> void:
    # 方法实现
    pass
```

---

## 五、测试结构

### 5.1 测试框架

推荐使用 [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) 框架。

```
tests/
├── unit/                          # 单元测试（类级别）
│   ├── test_entity.gd             # Entity 基类测试
│   ├── test_player.gd             # Player 类测试
│   ├── test_monster.gd            # Monster 类测试
│   ├── test_card.gd               # Card 类测试
│   ├── test_map_block.gd          # MapBlock 类测试
│   ├── test_game.gd               # Game 类测试
│   ├── test_game_state_machine.gd # GameStateMachine 测试
│   ├── test_pile.gd               # Pile 类测试
│   └── test_skill.gd              # Skill 结构测试
│
├── integration/                   # 集成测试（流程级别）
│   ├── test_damage_flow.gd        # 伤害流程 8 节点测试
│   ├── test_turn_flow.gd          # 回合流程 21 节点测试
│   ├── test_draw_card_flow.gd     # 抓牌流程测试
│   ├── test_draw_monster_flow.gd  # 抓怪物流程测试
│   ├── test_move_flow.gd          # 移动流程测试
│   ├── test_use_card_flow.gd      # 使用卡牌流程测试
│   ├── test_equipment_flow.gd     # 装备进入/离开流程测试
│   ├── test_charge_flow.gd        # 填充物消耗流程测试
│   ├── test_judge_flow.gd         # 检定流程测试
│   ├── test_monster_action_flow.gd# 怪物行动流程测试
│   ├── test_death_flow.gd         # 死亡流程测试
│   └── test_win_condition.gd      # 胜负判定测试
│
└── data/                          # 数据验证测试
    ├── test_data_load.gd          # 数据加载测试
    ├── test_mission_build.gd      # 任务地图构建测试
    └── test_card_api.gd           # 卡牌技能 API 调用测试
```

### 5.2 测试覆盖目标

| 维度 | 覆盖目标 | 优先级 |
|------|---------|--------|
| 核心类方法 | 95 个方法 100% 覆盖 | P0 |
| 核心流程 | 20 个流程 100% 覆盖 | P0 |
| 13 个任务 | 地图构建 + 胜负条件 100% 覆盖 | P1 |
| 6 个角色 | 初始牌堆 + 技能 API 调用 | P1 |
| 4 个怪物包 | 实体化 + 行动流程 | P2 |

---

## 六、资源路径约定

### 6.1 资源路径前缀

| 前缀 | 含义 | 示例 |
|------|------|------|
| `res://` | 项目根目录 | `res://src/core/entity.gd` |
| `user://` | 用户数据目录（存档） | `user://saves/save_001.json` |

### 6.2 数据文件路径

```gdscript
# DataManager 中的数据路径常量
const PATH_SURVIVORS := "res://data/survivors/"
const PATH_SCAVENGE := "res://data/scavenge/"
const PATH_MONSTERS := "res://data/monsters/"
const PATH_MISSIONS := "res://data/missions/"
const PATH_MAP_BLOCKS := "res://data/map_blocks/map_blocks.json"
```

---

## 七、版本控制忽略规则

`.gitignore` 建议内容：

```
# Godot 编辑器生成的临时文件
.godot/
*.tmp

# 导出产物
export/
*.exe
*.zip

# IDE 文件
.vscode/
.idea/

# OS 文件
.DS_Store
Thumbs.db

# 测试输出
test_results/
```

---

## 八、与其他文档的关系

| 文档 | 说明 |
|------|------|
| [IdentifierMapping.md](IdentifierMapping.md) | 中文设计标识符 → 英文代码标识符完整映射 |
| [DataFormat.md](DataFormat.md) | Resource markdown → JSON 转换规范与 JSON Schema |
| [../GameSystem/README.md](../GameSystem/README.md) | GameSystem 设计文档索引（源定义） |
| [../../spec/feasibility-analysis.md](../../spec/feasibility-analysis.md) | 可行性分析报告 |
| [../../spec/design-gaps.md](../../spec/design-gaps.md) | 设计待完善报告（UI/AI/网络/存档等待补充系统） |
