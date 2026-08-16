# Godot 项目结构

> 本文档描述 `MxApoc_GDScript/` 目录的实际结构、autoload 注册与资源组织，与代码现状对齐。
> 数据格式见 [DataFormat.md](DataFormat.md)；标识符中英映射见 [IdentifierMapping.md](IdentifierMapping.md)。

---

## 一、项目根目录

`MxApoc_GDScript/` 根目录下的文件与子目录：

| 条目 | 类型 | 说明 |
| --- | --- | --- |
| `Build/` | 目录 | 导出产物，含 `MxApoc_GDScript-v0.0.0.exe` |
| `addons/` | 目录 | 第三方插件，目前仅 `gut/` |
| `data/` | 目录 | 运行时数据文件（JSON），详见第三节 |
| `docs/` | 目录 | 工程内临时文档 |
| `images/` | 目录 | 图片资源，详见第六节 |
| `src/` | 目录 | GDScript 源码，详见第二节 |
| `.editorconfig` | 文件 | 编辑器配置 |
| `.gitattributes` | 文件 | Git 属性配置 |
| `.gitignore` | 文件 | Git 忽略规则 |
| `.gutconfig.json` | 文件 | GUT 测试框架配置 |
| `default_bus_layout.tres` | 文件 | 默认音频总线布局 |
| `export_presets.cfg` | 文件 | 导出预设 |
| `icon.svg` | 文件 | 项目图标 |
| `project.godot` | 文件 | Godot 项目配置（含 autoload 注册） |

---

## 二、src/ 源码目录

### 2.1 src/common/

通用基础结构：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `pile.gd` | `Pile` | 牌堆类 |
| `role_card.gd` | `RoleCard` | 角色卡类 |
| `skill.gd` | `Skill` | 技能结构（运行时） |
| `log_colors.gd` | `LogColors` | 日志着色工具 |

### 2.2 src/core/

核心系统：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `entity.gd` | `Entity` | 实体基类（技能挂载、伤害流程、触发） |
| `event_bus.gd` | `EventBus` | 全局事件总线（autoload） |
| `event_system.gd` | `EventSystem` | 事件工厂与取消机制（静态工具类） |
| `game_state_machine.gd` | `GameStateMachine` | 游戏状态机与回合队列 |
| `player_stats.gd` | `PlayerStats` | 单玩家统计数据 |
| `stats_tracker.gd` | `StatsTracker` | 全局统计跟踪器 |

### 2.3 src/data/

数据加载层（详见 [DataFormat.md](DataFormat.md)）：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `data_manager.gd` | `DataManager` | 数据管理器（autoload） |
| `code_executor.gd` | `CodeExecutor` | 代码字段编译沙箱（详见 [CodeExecutor.md](CodeExecutor.md)） |
| `map_block_data.gd` | `MapBlockData` | 地图块静态数据 |
| `mission_data.gd` | `MissionData` | 任务静态数据 |
| `monster_card_data.gd` | `MonsterCardData` | 怪物卡静态数据 |
| `scavenge_card_data.gd` | `ScavengeCardData` | 拾荒卡静态数据 |
| `skill_data.gd` | `SkillData` | 技能静态数据 |
| `survivor_data.gd` | `SurvivorData` | 求生者静态数据 |
| `variant_data.gd` | `VariantData` | 变体静态数据 |

### 2.4 src/entities/

运行时实体类：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `card.gd` | `Card` | 卡牌基类 |
| `equipment.gd` | `Equipment` | 装备区实体类（填充物接口委托来源） |
| `equipment_card.gd` | `EquipmentCard` | 装备牌（继承 `SurvivorGameCard`） |
| `map_block.gd` | `MapBlock` | 地图块类 |
| `monster.gd` | `Monster` | 怪物类 |
| `monster_card.gd` | `MonsterCard` | 怪物卡（实体化前） |
| `player.gd` | `Player` | 玩家类 |
| `scavenge_card.gd` | `ScavengeCard` | 拾荒卡（继承 `EquipmentCard`） |
| `survivor_game_card.gd` | `SurvivorGameCard` | 求生者游戏牌（继承 `Card`） |

> 卡牌继承链：`ScavengeCard` → `EquipmentCard` → `SurvivorGameCard` → `Card` → `Entity`。

### 2.5 src/game/

游戏全局层：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `game.gd` | `Game` | 游戏全局类（autoload），持全局牌堆/地图/玩家，承担状态机委托 |
| `mission_config.gd` | `MissionConfig` | 任务运行时配置 |

### 2.6 src/ui/

UI 与输入层。全部 `.gd` 文件如下：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `action_selection_controller.gd` | `ActionSelectionController` | 行动选择控制器 |
| `active_skill_bar.gd` | `ActiveSkillBar` | 主动技能栏 |
| `card_view.gd` | `CardView` | 卡牌视图 |
| `cli_player_input.gd` | `CliPlayerInput` | 命令行玩家输入（开发期） |
| `event_log_panel.gd` | `EventLogPanel` | 事件日志面板 |
| `game_result.gd` | `GameResult` | 游戏结果界面 |
| `game_room.gd` | `GameRoom` | 游戏房间 |
| `game_scene.gd` | `GameScene` | 游戏场景 |
| `game_scene_2d.gd` | `GameScene2D` | 2D 游戏场景 |
| `gui_player_input.gd` | `GuiPlayerInput` | 图形界面玩家输入 |
| `hand_display_area.gd` | `HandDisplayArea` | 手牌展示区 |
| `i_player_input.gd` | `IPlayerInput` | 玩家输入接口 |
| `image_cache.gd` | `ImageCache` | 图片缓存（预加载 `image_manifest.json`） |
| `loading_screen.gd` | `LoadingScreen` | 加载界面 |
| `main_menu.gd` | `MainMenu` | 主菜单 |
| `map_block_view.gd` | `MapBlockView` | 地图块视图 |
| `pile_manager.gd` | `PileManager` | 牌堆管理器 |
| `player_panel.gd` | `PlayerPanel` | 玩家面板 |
| `popup_manager.gd` | `PopupManager` | 弹窗管理器 |
| `room_state.gd` | `RoomState` | 房间状态（autoload） |
| `seat_item.gd` | `SeatItem` | 座位项 |
| `settings.gd` | `Settings` | 全局设置（autoload） |
| `settings_dialog.gd` | `SettingsDialog` | 设置对话框 |
| `settings_scene.gd` | `SettingsScene` | 设置场景 |
| `table_map_controller.gd` | `TableMapController` | 桌面地图控制器 |
| `tutorial_dialog.gd` | `TutorialDialog` | 教程对话框 |
| `tutorial_manager.gd` | `TutorialManager` | 教程管理器 |

### 2.7 src/tools/

工具脚本：

| 文件 | 类名 | 说明 |
| --- | --- | --- |
| `generate_image_manifest.gd` | `GenerateImageManifest` | 扫描 `images/` 生成 `image_manifest.json` |

---

## 三、data/ 数据目录

### 3.1 data/survivors/（6 文件）

求生者数据：`firefighter.json`、`gunslinger.json`、`hunter.json`、`mechanic.json`、`surgeon.json`、`veteran.json`。

### 3.2 data/scavenge/（4 文件）

拾荒牌堆数据：`blue.json`、`gray.json`、`green.json`、`red.json`。

### 3.3 data/monsters/（4 文件）

怪物包数据：`alien.json`、`mutant.json`、`robot.json`、`zombie.json`。

### 3.4 data/missions/（13 文件）

任务数据：`mission_0.json` ~ `mission_12.json`。

### 3.5 data/map_blocks/（1 文件）

地图块定义：`map_blocks.json`。

### 3.6 data/variants/（3 文件）

变体数据：`crisis.json`、`famine.json`、`shared_fate.json`。

### 3.7 data/ 根文件

| 文件 | 说明 |
| --- | --- |
| `common_skills.json` | 通用主动技能数据（顶层为数组） |
| `image_manifest.json` | 图片资源清单 |

---

## 四、autoload 注册

在 `project.godot` 的 `[autoload]` 段注册以下 5 个全局单例：

| Autoload 名 | 路径 | 说明 |
| --- | --- | --- |
| `DataManager` | `res://src/data/data_manager.gd` | 数据加载与管理 |
| `EventBus` | `res://src/core/event_bus.gd` | 全局事件总线，供 UI 订阅 |
| `Game` | `res://src/game/game.gd` | 游戏全局实例，管理全局区域、地图、任务配置、状态机委托 |
| `RoomState` | `res://src/ui/room_state.gd` | 房间状态 |
| `Settings` | `res://src/ui/settings.gd` | 全局设置（`dev_mode` 等开关） |

初始化顺序按注册顺序：`DataManager` → `EventBus` → `Game` → `RoomState` → `Settings`。`DataManager` 无依赖最先加载；`Game` 依赖 `DataManager` 提供的静态数据；`EventBus` 供 UI 层订阅游戏事件。

---

## 五、addons/gut/

第三方测试框架 [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)，包含 `cli/`、`gui/`、`fonts/`、`images/` 等子目录及核心脚本（`gut.gd`、`doubler.gd`、`dynamic_gdscript.gd` 等）。本工程不修改该目录内容。

`code_executor.gd` 的动态编译参考了 `addons/gut/dynamic_gdscript.gd` 的模式。

---

## 六、images/ 资源目录

| 子目录 / 文件 | 内容 |
| --- | --- |
| `gamemark/` | 游戏标记图片（中毒/任务/弹药/怪物/燃料标记） |
| `mapblock/` | 地图块图片（含地块背面） |
| `monster/alien/` | 外星人怪物图片 |
| `monster/mutant/` | 突变体怪物图片 |
| `monster/robot/` | 机器人怪物图片 |
| `monster/zombie/` | 僵尸怪物图片 |
| `scavenging/` | 拾荒卡图片 |
| `survivor/<english_name>/` | 各求生者相关图片（角色牌、头像、游戏牌） |
| `game-logo.png` | 游戏 Logo |
| `home.png` | 主页图 |
| `main-menu.png` | 主菜单背景 |

> `images/` 下的图片路径由 `src/tools/generate_image_manifest.gd` 扫描汇总为 `data/image_manifest.json`，供 `image_cache.gd` 预加载。
