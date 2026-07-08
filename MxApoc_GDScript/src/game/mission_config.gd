class_name MissionConfig
extends RefCounted

## 任务配置结构。由任务包加载，存储本局任务的可配置项与运行时状态。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md#任务配置结构missionconfig

## 启动面包车所需燃料值。-1 表示 NULL（该任务不通过面包车胜利，如任务 4/8/9/11）。
var van_fuel_required: int = -1

## 任务包提供的胜利条件检查函数。返回 true 表示任务特定胜利条件已满足。
## 由 GameStateMachine.check_win_condition() 通过 Game.check_mission_win_condition() 调用。
var check_win_condition: Callable = Callable()

## 任务特定运行时状态存储。各任务自行约定键名。
## 常用键见 IdentifierMapping.md §八（如 scientist_info_recorded / scientist_rescued / bomb_defused）。
var mission_state: Dictionary = {}
