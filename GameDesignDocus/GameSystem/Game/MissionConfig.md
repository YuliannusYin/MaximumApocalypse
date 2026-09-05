# MissionConfig 任务运行时配置

> 以 `src/game/mission_config.gd` 为准。
> 职责：单局任务的运行时容器（三层架构第二/三层）：持有按 JSON 声明挂载的组件实例与任务脚本实例，编排胜负判定、事件转发与任务行动。
> 类名 `MissionConfig`，继承 `RefCounted`。无 autoload；由 [Game.initialize_game](./Game.md) 显式 `MissionConfig.new()` 创建。
> JSON 声明字段见 [DataFormat.md §3.4](../../Engineering/DataFormat.md)；组件 API 见 [MissionComponent.md](./MissionComponent.md)。

---

## 设计意图

任务 JSON 只做声明，不写胜利代码字符串。`Game.initialize_game` 从 `MissionData` 构造本对象：

1. `van_fuel_required`：`mission.van_fuel_required` 为 `null` 时置 `-1`，否则转 `int`
2. `no_initial_monster_draw`：复制任务同名字段（如任务 11）
3. `_mount_mission_components(mission)`：按 `win_conditions` / `lose_conditions` / `triggers` / `actions` / `mission_script` 实例化组件与脚本
4. `build_map` 之后统计 `initial_objective_mark_count`
5. `setup_components(Game)`：向全部组件与脚本注入 `game` 与本配置

`van_fuel_required == -1` 表示该任务不通过启动面包车胜利（如任务 4/8/9/11）。此时 [GameStateMachine.check_win_condition](../Core/GameStateMachine.md) 跳过面包车燃料/全员上车/车上无怪三项，仅依赖 `check_win()`。

无胜利组件且无脚本时 `check_win()` 返回 **true**（空真）。任务 0 教程即此：任务目标恒通过，胜负完全由面包车判定承担。`action_win_only` 组件的 `check_win` 恒为 false，防止「行动直胜」任务在回合结束时被空真误判（任务 8/9）。

---

## 字段

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `van_fuel_required` | int | -1 | 启动面包车所需燃料。-1 表不通过面包车胜利 |
| `no_initial_monster_draw` | bool | false | 开局跳过每名玩家的初始抓怪 |
| `initial_objective_mark_count` | int | 0 | 开局场上目标标记总数（`build_map` 后写入） |
| `win_condition_components` | Array | [] | 胜利条件组件。全部 `check_win` 为 true 才满足任务目标 |
| `lose_condition_components` | Array | [] | 失败条件组件。任一 `check_lose` 为 true 即任务失败 |
| `trigger_components` | Array | [] | 触发器组件。接收 `on_event` |
| `action_components` | Array | [] | 行动选项组件。提供任务专属行动 |
| `mission_script_instance` | MissionScript | null | 第三层脚本，当前无内置脚本 |
| `mission_state` | Dictionary | {} | 任务运行时状态。键名见 [IdentifierMapping.md §八](../../Engineering/IdentifierMapping.md) |

---

## 方法

### setup_components(game)

任务开始时由 `Game.initialize_game` 调用。对四类组件与脚本依次 `setup(game, self)`。

### check_win(game) -> bool

全部胜利组件 `check_win` 为 true，且（无脚本或脚本为 true）才返回 true。无组件且无脚本时返回 true。

### check_lose(game) -> bool

任一失败组件或脚本 `check_lose` 为 true 即 true。由状态机在**回合结束**的 `check_win_condition` 中优先于胜利检查调用；部分行动会当场 `Game.game_over("lose")`（如任务 8 潜行失败且无日记本），不走到本方法。

### on_event(game, event_name, event)

将游戏事件转发给全部触发器组件与脚本。`Game` 订阅 EventBus 后经 `_forward_mission_event` 转入。转发的事件名：

`turn_started` / `turn_ended` / `player_moved` / `block_revealed` / `block_destroyed` / `monster_died` / `objective_mark_triggered` / `equipment_equipped` / `card_discarded` / `player_died` / `monster_spawn_judged`

### get_action_options(game, player) -> Array

合并全部行动组件与脚本的选项。每项为 `{id, label, execute}`。玩家查询任务行动时调用；UI 主入口是技能栏（见下）。

### mount_action_skills(player, block) / unmount_action_skills(player)

玩家进入地块时挂载、离开时卸载任务行动技能。遍历行动组件 `get_action_skill_decl()`：`block_match` 命中则构建主动 Skill（`active="action"`、`skill_type="任务"`、`english_name="mission_action_<索引>"`）加入 `player.skills`。离开时按此前缀卸载。复用地块技能管线（灰化、确认门、`use_active_skill`）。每次挂载先卸载旧技能，重复调用不累积。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](./Game.md) | 持有本实例；初始化、事件转发、`setup_components` |
| [GameStateMachine](../Core/GameStateMachine.md) | `check_win_condition` 调用 `check_lose` / `check_win`，再按 `van_fuel_required` 做面包车判定 |
| [MissionComponent](./MissionComponent.md) | 四类组件的基类与注册表 |
| [MissionData](../../Engineering/DataFormat.md) | 静态声明来源 |
| [Player](../Entities/Player.md) | 进入/离开地块时挂载任务行动技能 |
