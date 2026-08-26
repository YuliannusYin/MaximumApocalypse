extends GutTest

## 集成测试：游戏房间任务解锁 UI（mission-unlock-progression spec Task 3）。
## 直接实例化 GameRoom 场景并加入场景树（_ready → 填充任务/变体）验证：
## - 玩家模式空档案：13 项任务恒显示，仅任务 0 可选、其余置灰附解锁提示；
##   无“随机任务”选项；变体 CheckBox 全部 disabled 且附提示；默认选中任务 0。
## - 部分通关（任务 0~5）：任务 0~6 可选、7+ 置灰；仍无随机任务。
## - 全部通关：随机任务出现且可选、默认选中；变体可勾选并写入 RoomState。
## - 开发者模式：空档案也全解锁（随机任务存在、任务/变体全部可选）。
## - RoomState 残留锁定任务/随机状态时回退到第一个可选项，不越权解锁。
## 防污染方案：直接替换 ArchiveManager autoload 的内存档案字典模拟解锁进度
## （不落盘、不调用 save），测试后原样还原；Settings.dev_mode 与 RoomState 测后还原。

const MISSION_LOCK_HINT := "（通关前一任务后解锁）"
const VARIANT_LOCK_HINT := "通关全部任务后解锁"

var _saved_archive: Dictionary
var _saved_dev_mode: bool


func before_each() -> void:
	_saved_archive = ArchiveManager.archive
	_saved_dev_mode = Settings.dev_mode
	Settings.dev_mode = false
	RoomState.clear()


func after_each() -> void:
	ArchiveManager.archive = _saved_archive
	Settings.dev_mode = _saved_dev_mode
	RoomState.clear()


# === 辅助方法 ===

func _make_archive(missions: Dictionary) -> Dictionary:
	return {
		"achievements": {},
		"survivors": {},
		"missions": missions,
		"monsters": {},
		"win_total": 0,
	}


func _set_empty_archive() -> void:
	ArchiveManager.archive = _make_archive({})


## 标记 from_id ~ to_id（含端点）的任务以 player_count 人档通关一次。
func _set_won_range(from_id: int, to_id: int, player_count: int = 1) -> void:
	var missions := {}
	for mid in range(from_id, to_id + 1):
		missions[str(mid)] = {str(player_count): {"win_count": 1, "best_time_msec": 60000}}
	ArchiveManager.archive = _make_archive(missions)


func _set_all_won() -> void:
	var missions := {}
	for mission in DataManager.get_all_missions():
		missions[str(mission.mission_id)] = {"1": {"win_count": 1, "best_time_msec": 60000}}
	ArchiveManager.archive = _make_archive(missions)


## 实例化 GameRoom 场景并加入场景树（触发 _ready 填充任务与变体）。
func _spawn_room():
	var room = load("res://scenes/GameRoom.tscn").instantiate()
	add_child_autofree(room)
	return room


func _option(room) -> OptionButton:
	return room._mission_option


func _has_random_item(room) -> bool:
	var option := _option(room)
	for i in range(option.item_count):
		if option.get_item_text(i) == "随机任务":
			return true
	return false


# === 玩家模式 + 空档案：仅任务 0 可选 ===

func test_player_empty_archive_13_missions_only_zero_selectable() -> void:
	_set_empty_archive()
	var room = _spawn_room()
	var option := _option(room)
	assert_eq(option.item_count, 13, "空档案玩家模式：无随机任务选项，恒显示 13 项任务")
	assert_false(_has_random_item(room), "空档案不应出现“随机任务”选项")
	var all_missions: Array = DataManager.get_all_missions()
	for i in range(13):
		var meta = option.get_item_metadata(i)
		assert_true(meta is MissionData, "第 %d 项应为 MissionData" % i)
		assert_eq(meta.mission_id, all_missions[i].mission_id, "任务应按 mission_id 升序填充")
		var should_lock: bool = meta.mission_id > 0
		assert_eq(option.is_item_disabled(i), should_lock,
			"任务 %d 置灰状态应为 %s" % [meta.mission_id, str(should_lock)])
		if should_lock:
			assert_true(option.get_item_text(i).ends_with(MISSION_LOCK_HINT),
				"锁定任务 %d 应附解锁提示文案" % meta.mission_id)
		else:
			assert_false(option.get_item_text(i).contains(MISSION_LOCK_HINT),
				"任务 0 不应附解锁提示")


## RoomState.clear() 后 selected_mission_is_random 为 true：
## 随机未解锁时该残留随机状态应被纠正为默认选中任务 0。
func test_player_empty_archive_defaults_to_mission_zero() -> void:
	_set_empty_archive()
	var room = _spawn_room()
	assert_eq(_option(room).selected, 0, "默认应选中第一个可选项（任务 0）")
	assert_false(RoomState.selected_mission_is_random, "随机任务未解锁，默认不应为随机模式")
	assert_not_null(RoomState.selected_mission, "默认应选中具体任务")
	assert_eq(RoomState.selected_mission.mission_id, 0, "默认选中任务 0")


func test_player_empty_archive_variants_disabled_with_hint() -> void:
	_set_empty_archive()
	var room = _spawn_room()
	assert_gt(room._variant_checkboxes.size(), 0, "前置：变体复选框应已生成")
	for key in room._variant_checkboxes:
		var cb: CheckBox = room._variant_checkboxes[key]
		assert_true(cb.disabled, "变体 %s 未解锁应 disabled" % key)
		assert_true(cb.tooltip_text.contains(VARIANT_LOCK_HINT), "变体 %s 应附解锁提示文案" % key)


func test_locked_variants_do_not_override_roomstate_values() -> void:
	_set_empty_archive()
	RoomState.variants["crisis"] = true
	var room = _spawn_room()
	assert_true(room._variant_checkboxes.has("crisis"), "前置：应含 crisis 变体")
	var cb: CheckBox = room._variant_checkboxes["crisis"]
	assert_true(cb.disabled, "变体未解锁应 disabled")
	assert_true(cb.button_pressed, "RoomState 既有勾选值应在 UI 上保留")
	assert_true(RoomState.variants["crisis"], "disabled 时机不应覆盖 RoomState.variants 既有值")


# === 部分通关：解锁下一任务，其余仍置灰 ===

func test_partial_completion_unlocks_next_missions_only() -> void:
	_set_won_range(0, 5, 2)
	var room = _spawn_room()
	var option := _option(room)
	assert_eq(option.item_count, 13, "未全通时不应出现“随机任务”选项")
	assert_false(_has_random_item(room), "未全通时无随机任务")
	for i in range(13):
		var meta = option.get_item_metadata(i)
		var should_lock: bool = meta.mission_id > 6
		assert_eq(option.is_item_disabled(i), should_lock,
			"通关任务 0~5 后任务 %d 置灰状态应为 %s" % [meta.mission_id, str(should_lock)])
		if should_lock:
			assert_true(option.get_item_text(i).ends_with(MISSION_LOCK_HINT),
				"锁定任务 %d 应附解锁提示文案" % meta.mission_id)


# === 全部通关：随机任务与变体解锁 ===

func test_all_completion_shows_random_and_enables_variants() -> void:
	_set_all_won()
	var room = _spawn_room()
	var option := _option(room)
	assert_eq(option.item_count, 14, "全通后：随机任务 + 13 项任务")
	assert_eq(option.get_item_text(0), "随机任务", "随机任务应为第 0 项")
	assert_null(option.get_item_metadata(0), "随机任务 metadata 应为 null")
	assert_false(option.is_item_disabled(0), "随机任务应可选")
	for i in range(1, 14):
		assert_false(option.is_item_disabled(i), "全通后任务应全部可选")
		assert_false(option.get_item_text(i).contains(MISSION_LOCK_HINT), "全通后任务不应附解锁提示")
	# 默认选中随机任务
	assert_eq(option.selected, 0, "全通后默认应选中第 0 项（随机任务）")
	assert_true(RoomState.selected_mission_is_random, "全通后默认随机任务模式")
	assert_null(RoomState.selected_mission, "随机任务模式下 selected_mission 应为 null")
	# 变体解锁：可勾选、无提示
	for key in room._variant_checkboxes:
		var cb: CheckBox = room._variant_checkboxes[key]
		assert_false(cb.disabled, "全通后变体 %s 应可勾选" % key)
		assert_false(cb.tooltip_text.contains(VARIANT_LOCK_HINT), "全通后变体 %s 不应附解锁提示" % key)
	# 勾选写入 RoomState（验证 toggled 信号到 RoomState 的接线完好）
	assert_true(room._variant_checkboxes.has("crisis"), "前置：应含 crisis 变体")
	var crisis: CheckBox = room._variant_checkboxes["crisis"]
	crisis.toggled.emit(true)
	assert_true(RoomState.variants["crisis"], "解锁后勾选变体应写入 RoomState.variants")


# === 开发者模式：全部可选 ===

func test_dev_mode_unlocks_everything_with_empty_archive() -> void:
	_set_empty_archive()
	Settings.dev_mode = true
	var room = _spawn_room()
	var option := _option(room)
	assert_eq(option.item_count, 14, "开发者模式：随机任务 + 13 项任务全部显示")
	assert_eq(option.get_item_text(0), "随机任务", "开发者模式应出现“随机任务”选项")
	for i in range(option.item_count):
		assert_false(option.is_item_disabled(i), "开发者模式第 %d 项应可选" % i)
		assert_false(option.get_item_text(i).contains(MISSION_LOCK_HINT), "开发者模式不应附解锁提示")
	assert_true(RoomState.selected_mission_is_random, "开发者模式默认随机任务")
	for key in room._variant_checkboxes:
		var cb: CheckBox = room._variant_checkboxes[key]
		assert_false(cb.disabled, "开发者模式变体 %s 应可勾选" % key)
		assert_false(cb.tooltip_text.contains(VARIANT_LOCK_HINT), "开发者模式变体不应附解锁提示")


# === 残留锁定选择回退 ===

func test_stale_locked_mission_selection_falls_back_to_default() -> void:
	_set_empty_archive()
	RoomState.selected_mission = DataManager.get_mission(5)
	RoomState.selected_mission_is_random = false
	var room = _spawn_room()
	assert_eq(RoomState.selected_mission.mission_id, 0, "残留的锁定任务选择应回退到任务 0")
	assert_eq(_option(room).selected, 0, "界面应回退选中第一个可选项")
