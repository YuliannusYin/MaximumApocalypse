# Autoload 单例 (scripts/autoload/)

本目录记录项目 `scripts/autoload/` 下已实现的 Autoload 单例。

Autoload 单例通过 `project.godot` 注册，脚本中直接以名字引用。`extends Node`，无 `class_name`。

---

## RoomState

- **文件**: `scripts/autoload/room_state.gd`
- **注册名**: `RoomState`（project.godot autoload）
- **基类**: `extends Node`
- **职责**: 跨场景房间状态，存储任务、变体、座位等开局配置。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `selected_mission` | `MissionData` | 当前选中的任务；`null` 表示未选择或随机任务。 |
| `selected_mission_is_random` | `bool` | 是否为随机任务模式。默认 `true`。 |
| `variants` | `Dictionary` | 变体启用状态。键为变体 id，值为是否启用。默认 `{"crisis": false, "famine": false, "shared_fate": false}`。 |
| `seats` | `Array` | 座位列表。每项为 `{type: String, survivor: SurvivorData}` 字典。 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `clear() -> void` | 重置房间状态为初始值（1 个真人座，无任务，无变体）。 |
| `is_ready_to_start() -> bool` | 是否满足开局条件：非空座位均已选择求生者。 |
| `snapshot() -> String` | 生成房间状态的文本快照，供 GameScene 占位展示。 |

---

## Settings

- **文件**: `scripts/autoload/settings.gd`
- **注册名**: `Settings`（project.godot autoload）
- **基类**: `extends Node`
- **职责**: 全屏等设置 + ConfigFile 持久化。

### 信号

| 信号 | 说明 |
|------|------|
| `fullscreen_changed(is_fullscreen: bool)` | 全屏状态变更时发射。 |

### 常量

| 常量 | 类型 | 值 | 说明 |
|------|------|-----|------|
| `CONFIG_PATH` | `String` | `"user://settings.cfg"` | 配置文件路径。 |
| `SECTION_DISPLAY` | `String` | `"display"` | 配置文件节名。 |
| `KEY_FULLSCREEN` | `String` | `"fullscreen"` | 全屏配置键名。 |

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `fullscreen` | `bool` | 是否全屏。默认 `false`。 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `toggle_fullscreen() -> void` | 切换全屏状态，应用并持久化，发射 `fullscreen_changed`。 |

### 生命周期方法

| 方法 | 说明 |
|------|------|
| `_ready()` | 加载配置并应用。 |
| `_unhandled_input(event: InputEvent)` | F11 切换全屏。 |
