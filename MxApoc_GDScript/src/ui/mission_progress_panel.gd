class_name MissionProgressPanel
extends Panel

## 任务进度面板。
## 常驻 UI 层右侧固定位置：实时显示当前任务全部进度条件的求值结果。
## 条件数据源为 Game.current_mission.progress_conditions（每项 {text, type, params?}），
## 支持类型：van_fuel / van_boarding / state_flag / state_count / hold_items /
## submitted_count / all_at_block / escort_at_block / marks_cleared / all_revealed。
## 求值核心（build_lines / build_lines_from / _eval_condition）为纯数据方法，
## 不依赖节点树与渲染，可被单元测试直接调用（headless 下 _process 不会自动运行）。

const PANEL_POS: Vector2 = Vector2(1210, 300)
const PANEL_SIZE: Vector2 = Vector2(200, 150)
const TITLE_COLOR: Color = Color(1.0, 0.85, 0.45)
const CONTENT_MIN_WIDTH: int = 176  # 内容 Label 最小宽度（面板宽 200 - 左右边距），保证换行

var _content_label: Label = null
var _cached_text: String = ""
var _reported_errors: Dictionary = {}  # 已报错的配置错误（_process 每帧调用，避免同一错误刷屏）


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	if Game == null or not is_instance_valid(Game) or Game.current_mission == null:
		visible = false
		return
	visible = true
	var lines: Array = build_lines()
	var new_text: String = "\n".join(PackedStringArray(lines))
	if new_text != _cached_text:
		_cached_text = new_text
		_content_label.text = new_text


# === 布局构建 ===

func _build_ui() -> void:
	position = PANEL_POS
	size = PANEL_SIZE
	# 无边框透明背景：StyleBoxEmpty 不绘制任何背景与边框
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# 标题：12px 加粗（FontVariation 对回退字体加粗）
	var title_label := Label.new()
	title_label.text = "任务进度"
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	var bold_font := FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 1.0
	title_label.add_theme_font_override("font", bold_font)
	vbox.add_child(title_label)

	# 滚动内容区：垂直自动滚动、水平禁用
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	# 内容 Label：自动换行，最小宽度保证换行生效
	_content_label = Label.new()
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.add_theme_font_size_override("font_size", 11)
	_content_label.custom_minimum_size = Vector2(CONTENT_MIN_WIDTH, 0)
	_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_content_label)


# === 进度求值（纯数据方法，供单元测试直接调用） ===

## 计算全部条件行的显示文本（不含标题）。默认数据路径：Game.current_mission.progress_conditions；
## Game / 当前任务 / mission_config 缺失时返回空数组。
func build_lines() -> Array:
	if Game == null or not is_instance_valid(Game):
		return []
	var mission: Variant = Game.current_mission
	if mission == null or Game.mission_config == null:
		return []
	# is_instance_valid 对 Dictionary 恒为 false，需先放行 Dictionary 分支（current_mission 可能是 Dictionary 或 Object）
	if not (mission is Dictionary) and not is_instance_valid(mission):
		return []
	var conditions: Variant = null
	if mission is Dictionary:
		conditions = mission.get("progress_conditions", [])
	elif mission is Object:
		conditions = mission.get("progress_conditions")
	if not (conditions is Array):
		return []
	return build_lines_from(conditions)


## 参数化版本：对传入条件数组计算全部显示行，不依赖 Game.current_mission（可测入口）。
## 每行格式："{序号}. {✔ 前缀}{文案}{(x/n) 后缀}"，序号按显示行自动从 1 递增。
## 未知类型的条件行报错并跳过（不显示、不占序号）。
func build_lines_from(conditions: Array) -> Array:
	var lines: Array = []
	var index: int = 0
	for cond in conditions:
		if not (cond is Dictionary):
			_report_config_error("非法条件项（应为 Dictionary）: %s" % str(cond))
			continue
		var result: Dictionary = _eval_condition(cond)
		if not result.get("known", true):
			continue
		index += 1
		var text: String = str(cond.get("text", ""))
		var check_mark: String = "✔ " if result.get("done", false) else ""
		lines.append("%d. %s%s%s" % [index, check_mark, text, result.get("progress", "")])
	return lines


## 单条件求值。返回 Dictionary：{done: bool, progress: String, known: bool}
## （progress 形如 "(1/4)" 或 ""；known 为 false 表示未知类型，调用方跳过该行不显示）。
func _eval_condition(cond: Dictionary) -> Dictionary:
	var cond_type: String = str(cond.get("type", ""))
	var params: Variant = cond.get("params", {})
	if not (params is Dictionary):
		params = {}
	match cond_type:
		"van_fuel":
			return _eval_van_fuel()
		"van_boarding":
			return _eval_van_boarding()
		"state_flag":
			return _eval_state_flag(params)
		"state_count":
			return _eval_state_count(params)
		"hold_items":
			return _eval_hold_items(params)
		"submitted_count":
			return _eval_submitted_count(params)
		"all_at_block":
			return _eval_all_at_block(params)
		"escort_at_block":
			return _eval_escort_at_block(params)
		"marks_cleared":
			return _eval_marks_cleared(params)
		"all_revealed":
			return _eval_all_revealed()
	_report_config_error("未知进度类型: %s" % cond_type)
	return {done = false, progress = "", known = false}


# === 各类型求值实现 ===

## van_fuel：面包车燃料 (当前/需求)。需求值 <= 0 或无面包车地块时容错为未完成（无后缀）。
func _eval_van_fuel() -> Dictionary:
	if Game == null or not is_instance_valid(Game):
		return _result_binary(false)
	if Game.mission_config == null or Game.mission_config.van_fuel_required <= 0:
		return _result_binary(false)
	var van: Variant = _get_first_block("面包车")
	if van == null:
		return _result_binary(false)
	return _result_count(van.get_van_fuel(), Game.mission_config.van_fuel_required)


## van_boarding：全员登车二态。与 GameStateMachine.check_win_condition 面包车段一致：
## 所有存活玩家都在面包车地块（首块）、面包车无怪物标记且同地块玩家怪物卡之和为 0。
func _eval_van_boarding() -> Dictionary:
	var van: Variant = _get_first_block("面包车")
	if van == null:
		return _result_binary(false)
	for player in _get_alive_players():
		if player.current_block != van:
			return _result_binary(false)
	if not _is_block_clear(van):
		return _result_binary(false)
	return _result_binary(true)


## state_flag：mission_state 布尔标记二态。
func _eval_state_flag(params: Dictionary) -> Dictionary:
	var key: String = str(params.get("key", ""))
	return _result_binary(_get_mission_state().get(key, false) == true)


## state_count：mission_state 计数 (x/目标)。name 为空读 mission_state[key]，
## 非空读 mission_state[key][name]；显示值钳制到目标。
func _eval_state_count(params: Dictionary) -> Dictionary:
	var key: String = str(params.get("key", ""))
	var state_name: String = str(params.get("name", ""))
	var target: int = int(params.get("target", 0))
	var value: int = 0
	if state_name.is_empty():
		value = int(_get_mission_state().get(key, 0))
	else:
		var container: Variant = _get_mission_state().get(key, {})
		if container is Dictionary:
			value = int(container.get(state_name, 0))
	return {done = value >= target, progress = "(%d/%d)" % [mini(value, target), target], known = true}


## hold_items：全队随身携带计数（存活玩家手牌 + 装备区，变体族匹配），(x/count)。
func _eval_hold_items(params: Dictionary) -> Dictionary:
	var card_name: String = str(params.get("card_name", ""))
	var required: int = int(params.get("count", 0))
	var count: int = 0
	for player in _get_alive_players():
		for card in player.hand:
			if card != null and is_instance_valid(card) and _matches_item_family(card.card_name, card_name):
				count += 1
		for card in player.equipment_zone:
			if card != null and is_instance_valid(card) and _matches_item_family(card.card_name, card_name):
				count += 1
	return _result_count(count, required)


## submitted_count：mission_state.submitted_items 已提交计数，(x/count)。
func _eval_submitted_count(params: Dictionary) -> Dictionary:
	var card_name: String = str(params.get("card_name", ""))
	var required: int = int(params.get("count", 0))
	var submitted: int = 0
	var items: Variant = _get_mission_state().get("submitted_items", {})
	if items is Dictionary:
		submitted = int(items.get(card_name, 0))
	return _result_count(submitted, required)


## all_at_block：全员抵达指定地块二态。与 MissionComponentAllPlayersAtBlock 判定一致：
## 所有存活玩家 current_block 非空且地块名匹配；no_monster 时还需所在地块无怪物标记
## 且玩家面前无怪物卡。无存活玩家视为未完成。
func _eval_all_at_block(params: Dictionary) -> Dictionary:
	var block_name: String = str(params.get("block_name", ""))
	var no_monster: bool = params.get("no_monster", false) == true
	var alive_players: Array = _get_alive_players()
	if alive_players.is_empty():
		return _result_binary(false)
	var checked_blocks: Array = []
	for player in alive_players:
		if player == null or not is_instance_valid(player):
			return _result_binary(false)
		var block: Variant = player.current_block
		if block == null or not is_instance_valid(block):
			return _result_binary(false)
		if block.block_name != block_name:
			return _result_binary(false)
		if no_monster:
			if not checked_blocks.has(block):
				checked_blocks.append(block)
				if block.count_monster_mark() > 0:
					return _result_binary(false)
			if player.monster_zone.size() > 0:
				return _result_binary(false)
	return _result_binary(true)


## escort_at_block：护送装备抵达地块二态。与 MissionComponentEscortEquipmentAtBlock 判定一致：
## 存在存活玩家装备指定卡（has_equipment）且 current_block 地块名匹配；no_monster 时还需该地块无怪。
func _eval_escort_at_block(params: Dictionary) -> Dictionary:
	var card_name: String = str(params.get("card_name", ""))
	var block_name: String = str(params.get("block_name", ""))
	var no_monster: bool = params.get("no_monster", false) == true
	for player in _get_alive_players():
		if not player.has_equipment(card_name):
			continue
		var block: Variant = player.current_block
		if block == null or not is_instance_valid(block):
			continue
		if block.block_name != block_name:
			continue
		if no_monster and not _is_block_clear(block):
			continue
		return _result_binary(true)
	return _result_binary(false)


## marks_cleared：任务标记已移除计数 (x/count)。
## 已移除数 = initial_objective_mark_count - 存活地块剩余 objective_marks 之和（负数钳 0）。
func _eval_marks_cleared(params: Dictionary) -> Dictionary:
	var target: int = int(params.get("count", 0))
	var removed: int = 0
	if Game != null and is_instance_valid(Game) and Game.mission_config != null:
		var remaining: int = 0
		for block in Game.map_area:
			if block != null and is_instance_valid(block) and block.is_alive():
				remaining += block.objective_marks.size()
		removed = maxi(Game.mission_config.initial_objective_mark_count - remaining, 0)
	return _result_count(removed, target)


## all_revealed：存活地块已揭示计数 (x/存活总数)；无存活地块时容错为未完成（无后缀）。
func _eval_all_revealed() -> Dictionary:
	if Game == null or not is_instance_valid(Game):
		return _result_binary(false)
	var total: int = 0
	var revealed_count: int = 0
	for block in Game.map_area:
		if block == null or not is_instance_valid(block) or not block.is_alive():
			continue
		total += 1
		if block.revealed:
			revealed_count += 1
	if total == 0:
		return _result_binary(false)
	return _result_count(revealed_count, total)


# === 求值辅助 ===

## 卡名是否属于物品族：精确匹配或变体前缀（与 MissionComponentCollectItems 相同逻辑，
## 如 "医疗用品" 匹配 "医疗用品（便携）"）。
func _matches_item_family(card_name: String, item_name: String) -> bool:
	return card_name == item_name or card_name.begins_with(item_name + "（")


## 当前任务运行时状态 mission_state（Game / mission_config 缺失时返回空 Dictionary）。
func _get_mission_state() -> Dictionary:
	if Game == null or not is_instance_valid(Game) or Game.mission_config == null:
		return {}
	return Game.mission_config.mission_state


## 按地块名取第一块存活地块（无则返回 null）。
func _get_first_block(block_name: String) -> Variant:
	if Game == null or not is_instance_valid(Game):
		return null
	var blocks: Array = Game.get_blocks_by_name(block_name)
	if blocks.is_empty():
		return null
	return blocks[0]


## 存活玩家列表（Game 无效时返回空数组）。
func _get_alive_players() -> Array:
	if Game == null or not is_instance_valid(Game):
		return []
	return Game.get_alive_players()


## 地块是否无怪：无怪物标记（count_monster_mark）且同地块存活玩家 monster_zone 之和为 0。
func _is_block_clear(block: Variant) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	if block.count_monster_mark() > 0:
		return false
	var monster_total: int = 0
	for player in _get_alive_players():
		if player.current_block == block:
			monster_total += player.monster_zone.size()
	return monster_total == 0


## 二态条件结果（无计数后缀）。
func _result_binary(done: bool) -> Dictionary:
	return {done = done, progress = "", known = true}


## 计数条件结果（"(x/target)" 后缀，x >= target 为完成）。
func _result_count(value: int, target: int) -> Dictionary:
	return {done = value >= target, progress = "(%d/%d)" % [value, target], known = true}


## 配置错误只报错一次（_process 每帧调用，避免同一错误刷屏）。
func _report_config_error(err: String) -> void:
	if _reported_errors.has(err):
		return
	_reported_errors[err] = true
	push_error("MissionProgressPanel: " + err)
