# MissionConfig 任务运行时配置

> 以 `src/game/mission_config.gd` 为准。
> 职责：单局任务的运行时配置与状态容器。
> 类名 `MissionConfig`，继承 `RefCounted`。无 autoload、无 class_name 注册（由 Game 显式 `MissionConfig.new()` 创建）。

---

## 设计意图

> 任务配置由 [Game.initialize_game](./Game.md#initialize_game) 在游戏开始时从 MissionData 构造：
> - `van_fuel_required` 直接从 `mission.van_fuel_required` 复制（mission 字段为 null 时置 -1）
> - `check_win_condition` 由 [Game._compile_win_condition](./Game.md#_compile_win_condition) 编译 `mission.win_condition_code` 注入；若该 code 为空字符串则保持默认空 Callable（视为任务不靠自定义代码胜利）
> - `mission_state` 初始化为空字典，由任务包各方法在运行时写入

> `van_fuel_required == -1` 表示 NULL（哨兵值），即该任务不通过启动面包车胜利（如任务 4/8/9/11）。
> 此时 [GameStateMachine.check_win_condition](../Core/GameStateMachine.md) 跳过面包车相关检查，仅依赖 `check_win_condition` Callable 的返回值。

---

## 字段

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `van_fuel_required` | int | -1 | 启动面包车所需的燃料值。-1 表 NULL，表示该任务不通过启动面包车胜利（如任务 4/8/9/11）。由 [GameStateMachine.check_win_condition](../Core/GameStateMachine.md) 检查 |
| `check_win_condition` | Callable | Callable()（空） | 任务包提供的胜利条件检查函数。返回 true 表示任务特定胜利条件已满足。由 [Game.check_mission_win_condition](./Game.md#check_mission_win_condition) 通过 `call()` 调用，再由 [GameStateMachine.check_win_condition](../Core/GameStateMachine.md) 调用。空 Callable 视为返回 false |
| `mission_state` | Dictionary | {} | 任务特定运行时状态存储。各任务自行约定键名（如任务 8 的 `scientist_info_recorded` / `scientist_rescued`、任务 9 的 `bomb_defused` 等，键名详见 `IdentifierMapping.md`） |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](./Game.md) | Game 持有 `mission_config` 实例，由 `initialize_game` 从 MissionData 构造 |
| [GameStateMachine](../Core/GameStateMachine.md) | `check_win_condition` 读取 `van_fuel_required` 与 `check_win_condition` 字段判定胜利 |
| [MissionData](../../Engineering/DataFormat.md) | `*Data` 类，由 DataManager 加载，作为 MissionConfig 的构造来源 |
