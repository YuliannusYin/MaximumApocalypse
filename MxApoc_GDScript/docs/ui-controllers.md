# UI 控制器 (scripts/ui/)

本目录记录项目 `scripts/ui/` 下已实现的 UI 控制器脚本。

UI 控制器仅做 UI 绑定与场景切换，不含游戏规则逻辑。与 `scenes/` 下的 `.tscn` 文件名一一对应。

---

## main_menu.gd

- **文件**: `scripts/ui/main_menu.gd`
- **场景**: `scenes/MainMenu.tscn`
- **基类**: `extends Control`
- **职责**: 主菜单界面，提供开始游戏、设置、退出按钮。

### 常量

| 常量 | 说明 |
|------|------|
| `SETTINGS_DIALOG_SCENE` | `preload("res://scenes/SettingsDialog.tscn")` |

### @onready 变量

| 变量 | 类型 | 节点路径 |
|------|------|----------|
| `start_button` | `Button` | `$MarginContainer/VBoxContainer/StartGameButton` |
| `settings_button` | `Button` | `$MarginContainer/VBoxContainer/SettingsButton` |
| `quit_button` | `Button` | `$MarginContainer/VBoxContainer/QuitButton` |

### 信号回调

| 回调 | 说明 |
|------|------|
| `_on_start_pressed()` | 切换到 GameRoom 场景。 |
| `_on_settings_pressed()` | 弹出 SettingsDialog。 |
| `_on_quit_pressed()` | 退出游戏。 |

---

## game_room.gd

- **文件**: `scripts/ui/game_room.gd`
- **场景**: `scenes/GameRoom.tscn`
- **基类**: `extends Control`
- **职责**: 房间配置界面，选择任务/变体/座位，然后开始游戏。

### 常量

| 常量 | 类型 | 说明 |
|------|------|------|
| `SEAT_ITEM_SCENE` | `PackedScene` | `preload("res://scenes/SeatItem.tscn")` |
| `MAX_SEATS` | `int` | `4` |
| `MIN_SEATS` | `int` | `1` |
| `RANDOM_MISSION_IDX` | `int` | `0` |

### @onready 变量

| 变量 | 类型 | 节点路径 |
|------|------|----------|
| `_back_button` | `Button` | `$MarginContainer/VBoxContainer/TopBar/BackButton` |
| `_mission_option` | `OptionButton` | `$MarginContainer/VBoxContainer/Content/LeftPanel/ScrollContainer/VBoxContainer/MissionSection/MissionOption` |
| `_variant_list` | `VBoxContainer` | `$MarginContainer/VBoxContainer/Content/LeftPanel/ScrollContainer/VBoxContainer/VariantSection/VariantList` |
| `_mission_name_label` | `Label` | `$MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/MissionNameLabel` |
| `_difficulty_label` | `Label` | `$MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/DifficultyLabel` |
| `_detail_rich` | `RichTextLabel` | `$MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/ScrollContainer/DetailRich` |
| `_start_game_button` | `Button` | `$MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/StartGameButton` |
| `_add_seat_button` | `Button` | `$MarginContainer/VBoxContainer/Content/RightPanel/VBoxContainer/SeatsHeader/AddSeatButton` |
| `_remove_seat_button` | `Button` | `$MarginContainer/VBoxContainer/Content/RightPanel/VBoxContainer/SeatsHeader/RemoveSeatButton` |
| `_seat_list` | `VBoxContainer` | `$MarginContainer/VBoxContainer/Content/RightPanel/VBoxContainer/SeatList` |

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_variant_checkboxes` | `Dictionary` | 变体 id → CheckBox 的映射。 |

### 私有方法

| 方法签名 | 说明 |
|----------|------|
| `_populate_missions() -> void` | 填充任务下拉框。 |
| `_populate_variants() -> void` | 填充变体复选框。 |
| `_restore_state() -> void` | 从 RoomState 恢复选择状态。 |
| `_rebuild_seats() -> void` | 重建座位列表 UI。 |
| `_update_seat_buttons() -> void` | 更新增减座位按钮的禁用状态。 |
| `_refresh_seats_disabled() -> void` | 刷新各座位求生者下拉框的禁用状态（防止重复选择）。 |
| `_sync_seats_to_state() -> void` | 同步座位 UI 到 RoomState。 |
| `_on_mission_selected(idx: int) -> void` | 任务选择变更。 |
| `_on_variant_toggled(id: String, toggled: bool) -> void` | 变体开关变更。 |
| `_on_add_seat() -> void` | 添加座位。 |
| `_on_remove_seat() -> void` | 移除座位。 |
| `_on_seat_changed(_idx: int) -> void` | 座位配置变更。 |
| `_refresh_detail_panel() -> void` | 刷新任务详情面板。 |
| `_update_start_button() -> void` | 更新开始游戏按钮的禁用状态。 |
| `_on_start_game() -> void` | 开始游戏，切换到 GameScene。 |
| `_on_back() -> void` | 返回主菜单。 |

---

## game_scene.gd

- **文件**: `scripts/ui/game_scene.gd`
- **场景**: `scenes/GameScene.tscn`
- **基类**: `extends Control`
- **职责**: 游戏场景（当前占位，仅显示 RoomState 快照文本）。

### @onready 变量

| 变量 | 类型 | 节点路径 |
|------|------|----------|
| `snapshot_rich` | `RichTextLabel` | `$MarginContainer/VBoxContainer/SnapshotRich` |
| `back_button` | `Button` | `$MarginContainer/VBoxContainer/BackButton` |

### 信号回调

| 回调 | 说明 |
|------|------|
| `_on_back_pressed()` | 清空 RoomState，返回主菜单。 |

---

## SeatItem

- **文件**: `scripts/ui/seat_item.gd`
- **类声明**: `class_name SeatItem extends PanelContainer`
- **场景**: `scenes/SeatItem.tscn`
- **职责**: 单个座位的 UI 控件，管理座位类型和求生者选择。

### 信号

| 信号 | 说明 |
|------|------|
| `changed(seat_index: int)` | 座位类型或求生者选择变更时发射。 |

### 常量

| 常量 | 类型 | 值 | 说明 |
|------|------|-----|------|
| `TYPE_HUMAN` | `int` | `0` | 真人座位索引。 |
| `TYPE_AI` | `int` | `1` | AI 座位索引。 |
| `TYPE_EMPTY` | `int` | `2` | 空座位索引。 |

### @export 变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `seat_index` | `int` | 座位序号，0 起。默认 `0`。 |

### @onready 变量

| 变量 | 类型 | 节点路径 |
|------|------|----------|
| `_seat_index_label` | `Label` | `$MarginContainer/VBoxContainer/SeatHeader/SeatIndexLabel` |
| `_type_option` | `OptionButton` | `$MarginContainer/VBoxContainer/SeatHeader/TypeOption` |
| `_survivor_option` | `OptionButton` | `$MarginContainer/VBoxContainer/SurvivorOption` |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `refresh_survivor_disabled(taken_ids: Array) -> void` | 根据已占用 id 禁用 OptionButton 中对应的求生者项。当前选择已被其他座位占用时重置为"未选择"。 |
| `setup(data: Dictionary) -> void` | 用 RoomState.seats 项的 `{type, survivor}` 数据初始化座位 UI。 |
| `collect() -> Dictionary` | 收集当前座位选择，返回 `{type: String, survivor: SurvivorData}` 字典。 |

### 私有方法

| 方法签名 | 说明 |
|----------|------|
| `_populate_survivors() -> void` | 填充求生者下拉框。 |
| `_on_selection_changed(_idx: int) -> void` | 类型或求生者选择变更回调。 |
| `_update_survivor_enabled() -> void` | 空座位时禁用求生者选择。 |
| `_get_current_survivor_id() -> String` | 获取当前选中的求生者 id。 |

---

## settings_dialog.gd

- **文件**: `scripts/ui/settings_dialog.gd`
- **场景**: `scenes/SettingsDialog.tscn`
- **基类**: `extends AcceptDialog`
- **职责**: 设置对话框（当前仅全屏切换）。

### @onready 变量

| 变量 | 类型 | 节点路径 |
|------|------|----------|
| `fullscreen_checkbox` | `CheckBox` | `$FullscreenCheckBox` |

### 信号回调

| 回调 | 说明 |
|------|------|
| `_on_fullscreen_toggled(pressed: bool)` | 全屏复选框变更。 |
| `_on_settings_fullscreen_changed(is_fullscreen: bool)` | Settings.fullscreen_changed 信号回调，同步复选框状态。 |
| `_on_closed()` | 对话框关闭时销毁。 |
