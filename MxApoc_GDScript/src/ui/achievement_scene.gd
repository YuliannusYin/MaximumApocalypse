extends Control

## 成就档案场景（TabContainer 四页签：成就 / 求生者 / 任务 / 怪物）。
## 从主菜单「成就」按钮进入，展示 ArchiveManager 档案数据：
## - 成就页：成就定义（data/achievements.json）+ 档案达成记录（首次达成时间/达成次数），未达成整行灰显；
## - 求生者页：每个求生者统计为列式布局（5 列 × 2 格，总量在上、单局最佳在下；
##   中文名取自 DataManager 求生者数据）；
## - 任务页：每个任务按玩家数（1~6）分档展示通关次数与最短通关时间（mm:ss，无记录显示 "-"）；
## - 怪物页：按怪物包分组展示每只怪物（english_name）累计被击杀数，boss 带标记。
## 页签/滚动容器骨架在 AchievementScene.tscn 中搭建，行内容在此动态构建
## （构建风格参考 src/ui/game_result.gd）。空档案时四页显示 0 / 未达成，不报错。

## 怪物包展示顺序（monster_type → 包中文名），与 data/monsters/ 四个包对应。
## 档案 monsters 块以怪物卡 english_name 为键（旧类型级键加载时已被 ArchiveManager 丢弃）；
## 档案中存在但数据包缺失的键追加在「其他」分组下回退显示原始 id（容忍，不崩溃）。
const MONSTER_PACKS := [
	{"type": "zombie", "name": "僵尸"},
	{"type": "alien", "name": "外星人"},
	{"type": "mutant", "name": "突变体"},
	{"type": "robot", "name": "机器人"},
]

## 求生者统计列式布局：每列上下两格（总量在上、单局最佳在下），从左往右 5 列。
## 字段与 spec 档案结构一致；wins 为成就求值增补字段，档案缺失时该格留空。
const SURVIVOR_STAT_COLUMNS := [
	{"top": {"field": "total_damage", "label": "全部造成伤害"}, "bottom": {"field": "best_damage", "label": "单局最高造成伤害"}},
	{"top": {"field": "total_kills", "label": "全部击杀"}, "bottom": {"field": "best_kills", "label": "单局最多击杀"}},
	{"top": {"field": "boss_kills", "label": "击杀首领数"}, "bottom": {"field": "wins", "label": "胜利局数", "blank_if_missing": true}},
	{"top": {"field": "total_healing", "label": "全部治疗量"}, "bottom": {"field": "best_healing", "label": "单局最高治疗量"}},
	{"top": {"field": "total_turns", "label": "全部回合数"}, "bottom": {"field": "best_turns", "label": "单局最多回合数"}},
]

## 任务页固定展示的玩家数分档（spec：player_count 1~6）。
const MISSION_PLAYER_COUNTS := [1, 2, 3, 4, 5, 6]

const _COLOR_TEXT := Color(0.92, 0.92, 0.92)
const _COLOR_DIM := Color(0.62, 0.62, 0.66)
const _COLOR_ACCENT := Color(1.0, 0.85, 0.3)
const _COLOR_ROW_BG := Color(0.16, 0.16, 0.2)
const _COLOR_CELL_BG := Color(0.12, 0.12, 0.15)
const _COLOR_HEADER_BG := Color(0.22, 0.22, 0.28)
## 未达成成就整行灰显透明度。
const _LOCKED_MODULATE := Color(1, 1, 1, 0.45)

const _MISSION_NAME_COL_WIDTH := 210.0
const _MISSION_COL_WIDTH := 170.0
const _MISSION_NAME_ROW_HEIGHT := 34.0
const _MISSION_ROW_HEIGHT := 48.0

@onready var _tab_container: TabContainer = $Margin/Panel/TabContainer
@onready var _achievements_list: VBoxContainer = $Margin/Panel/TabContainer/AchievementsTab/AchievementsList
@onready var _survivors_list: VBoxContainer = $Margin/Panel/TabContainer/SurvivorsTab/SurvivorsList
@onready var _missions_list: VBoxContainer = $Margin/Panel/TabContainer/MissionsTab/MissionsList
@onready var _monsters_list: VBoxContainer = $Margin/Panel/TabContainer/MonstersTab/MonstersList
@onready var _back_button: Button = $Margin/Panel/BackButton
@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $Margin/Panel/TitleLabel


func _ready() -> void:
	HudTheme.apply_screen_background(_background, Color("#101110"))
	HudTheme.add_wasteland_backdrop(self, _background)
	HudTheme.apply_title(_title_label, 28)
	HudTheme.apply_mission_slot_button(_back_button, 16)
	HudTheme.apply_section_panel(_tab_container, Color("#1d1c19"))
	_tab_container.set_tab_title(0, "成就")
	_tab_container.set_tab_title(1, "求生者")
	_tab_container.set_tab_title(2, "任务")
	_tab_container.set_tab_title(3, "怪物")
	_fill_achievements_page()
	_fill_survivors_page()
	_fill_missions_page()
	_fill_monsters_page()
	_back_button.pressed.connect(_on_back_pressed)


# === 成就页 ===

func _fill_achievements_page() -> void:
	var definitions: Array = []
	if ArchiveManager != null and is_instance_valid(ArchiveManager):
		definitions = ArchiveManager.get_achievement_definitions()
	if definitions.is_empty():
		_add_empty_hint(_achievements_list, "（暂无成就定义）")
		return
	var achievements := _archive_block("achievements")
	for def in definitions:
		var ach_id := str(def.get("id", ""))
		var entry: Variant = achievements.get(ach_id)
		var count := 0
		var first_at := ""
		if entry is Dictionary:
			count = int(entry.get("count", 0))
			first_at = str(entry.get("first_at", ""))
		var achieved := count > 0
		var row := _make_row_panel()
		if not achieved:
			row.modulate = _LOCKED_MODULATE
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)
		var name_color := _COLOR_TEXT if achieved else _COLOR_DIM
		info.add_child(_make_label(str(def.get("name", ach_id)), 17, name_color))
		info.add_child(_make_label(str(def.get("description", "")), 13, _COLOR_DIM))
		var stats := VBoxContainer.new()
		stats.size_flags_horizontal = Control.SIZE_SHRINK_END
		stats.add_theme_constant_override("separation", 2)
		hbox.add_child(stats)
		var time_text := "未达成"
		if achieved:
			time_text = first_at.replace("T", " ")
		var time_color := _COLOR_ACCENT if achieved else _COLOR_DIM
		stats.add_child(_make_label("首次达成：" + time_text, 13, time_color))
		stats.add_child(_make_label("达成次数：%d" % count, 13, _COLOR_TEXT))
		_achievements_list.add_child(row)


# === 求生者页 ===

func _fill_survivors_page() -> void:
	var survivors: Array = []
	if DataManager != null and is_instance_valid(DataManager):
		survivors = DataManager.get_all_survivors()
	if survivors.is_empty():
		_add_empty_hint(_survivors_list, "（暂无求生者数据）")
		return
	var archive_survivors := _archive_block("survivors")
	for survivor in survivors:
		var sid := str(survivor.english_name)
		var display_name := str(survivor.character_name)
		if display_name == "":
			display_name = sid
		var entry: Variant = archive_survivors.get(sid)
		var stats: Dictionary = {}
		if entry is Dictionary:
			stats = entry
		var row := _make_row_panel()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		row.add_child(vbox)
		vbox.add_child(_make_label(display_name, 17, _COLOR_ACCENT))
		# 列式布局：每列上下两格（总量在上、单局最佳在下），从左往右 5 列
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 10)
		vbox.add_child(columns)
		for raw_column in SURVIVOR_STAT_COLUMNS:
			var column_def: Dictionary = raw_column
			var column := VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_theme_constant_override("separation", 10)
			columns.add_child(column)
			column.add_child(_make_survivor_stat_cell(column_def.get("top", {}), stats))
			column.add_child(_make_survivor_stat_cell(column_def.get("bottom", {}), stats))
		_survivors_list.add_child(row)


# === 任务页 ===

func _fill_missions_page() -> void:
	var missions: Array = []
	if DataManager != null and is_instance_valid(DataManager):
		missions = DataManager.get_all_missions()
	if missions.is_empty():
		_add_empty_hint(_missions_list, "（暂无任务数据）")
		return
	var archive_missions := _archive_block("missions")
	var grid := GridContainer.new()
	grid.columns = MISSION_PLAYER_COUNTS.size() + 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_missions_list.add_child(grid)
	# 表头行：任务名 + 各人数分档
	grid.add_child(_make_grid_cell("任务", _MISSION_NAME_COL_WIDTH, _MISSION_NAME_ROW_HEIGHT, HORIZONTAL_ALIGNMENT_LEFT, _COLOR_DIM, _COLOR_HEADER_BG, 13))
	for pc in MISSION_PLAYER_COUNTS:
		grid.add_child(_make_grid_cell("%d人" % pc, _MISSION_COL_WIDTH, _MISSION_NAME_ROW_HEIGHT, HORIZONTAL_ALIGNMENT_CENTER, _COLOR_DIM, _COLOR_HEADER_BG, 13))
	# 数据行：每任务一行，按玩家数分档展示通关次数与最短通关时间
	for mission in missions:
		var mid_key := str(mission.mission_id)
		var mission_name := str(mission.mission_name)
		if mission_name == "":
			mission_name = mid_key
		var buckets: Variant = archive_missions.get(mid_key)
		var mission_buckets: Dictionary = {}
		if buckets is Dictionary:
			mission_buckets = buckets
		grid.add_child(_make_grid_cell(mission_name, _MISSION_NAME_COL_WIDTH, _MISSION_ROW_HEIGHT, HORIZONTAL_ALIGNMENT_LEFT, _COLOR_TEXT, _COLOR_ROW_BG, 15))
		for pc in MISSION_PLAYER_COUNTS:
			var bucket: Variant = mission_buckets.get(str(pc))
			var text := "-"
			var text_color := _COLOR_DIM
			if bucket is Dictionary and int(bucket.get("win_count", 0)) > 0:
				var win_count := int(bucket.get("win_count", 0))
				text = "×%d\n%s" % [win_count, _format_mission_time(int(bucket.get("best_time_msec", 0)))]
				text_color = _COLOR_TEXT
			grid.add_child(_make_grid_cell(text, _MISSION_COL_WIDTH, _MISSION_ROW_HEIGHT, HORIZONTAL_ALIGNMENT_CENTER, text_color, _COLOR_ROW_BG, 13))


# === 怪物页 ===

## 按怪物包分组展示：包名小标题 + 该包全部怪物（boss 带标记）及累计击杀数
## （击杀键为怪物卡 english_name，缺失为 0）。
func _fill_monsters_page() -> void:
	if DataManager == null or not is_instance_valid(DataManager):
		_add_empty_hint(_monsters_list, "（暂无怪物数据）")
		return
	var archive_monsters := _archive_block("monsters")
	var shown := {}
	var has_any := false
	for raw_pack in MONSTER_PACKS:
		var pack: Dictionary = raw_pack
		var cards: Array = DataManager.get_monster_pack(str(pack.get("type", "")))
		if cards.is_empty():
			continue
		has_any = true
		_monsters_list.add_child(_make_pack_header(str(pack.get("name", ""))))
		for card in cards:
			var english_name := str(card.english_name)
			shown[english_name] = true
			var kills := int(archive_monsters.get(english_name, 0))
			_monsters_list.add_child(_make_monster_row(_monster_display_name(card), kills))
	# 档案中存在但数据包中不存在的 english_name：追加在「其他」分组下回退显示原始 id
	var extra_ids: Array = []
	for key in archive_monsters.keys():
		var key_str := str(key)
		if not shown.has(key_str):
			extra_ids.append(key_str)
	if not extra_ids.is_empty():
		extra_ids.sort()
		has_any = true
		_monsters_list.add_child(_make_pack_header("其他"))
		for raw_id in extra_ids:
			var english_name := str(raw_id)
			var kills := int(archive_monsters.get(english_name, 0))
			_monsters_list.add_child(_make_monster_row(english_name, kills))
	if not has_any:
		_add_empty_hint(_monsters_list, "（暂无怪物数据）")


## 怪物显示名：中文名（缺失回退 english_name）+ boss 标记（仅 monster_level == "boss"）。
func _monster_display_name(card: MonsterCardData) -> String:
	var display_name := str(card.monster_name)
	if display_name == "":
		display_name = str(card.english_name)
	if str(card.monster_level) == "boss":
		display_name += "（首领）"
	return display_name


# === 通用构建辅助（风格参考 game_result.gd） ===

## 取档案顶层块；ArchiveManager 不可用或块非法时返回空字典（空档案展示 0 / 未达成）。
func _archive_block(key: String) -> Dictionary:
	if ArchiveManager == null or not is_instance_valid(ArchiveManager):
		return {}
	var value: Variant = ArchiveManager.archive.get(key)
	if value is Dictionary:
		return value
	return {}


func _add_empty_hint(parent: VBoxContainer, text: String) -> void:
	var hint := _make_label(text, 14, _COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hint)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_stylebox(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.38, 0.32, 0.24, 0.72)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _make_row_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_stylebox(_COLOR_ROW_BG))
	return panel


func _make_stat_cell(label_text: String, value_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(_COLOR_CELL_BG))
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	panel.add_child(cell)
	var label := _make_label(label_text, 12, _COLOR_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	var value_label := _make_label(value_text, 17, _COLOR_TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(value_label)
	return panel


## 求生者统计格：常规字段缺失按 0 展示；blank_if_missing 字段（如 wins）缺失时留空。
func _make_survivor_stat_cell(item: Variant, stats: Dictionary) -> PanelContainer:
	var def: Dictionary = item if item is Dictionary else {}
	var field := str(def.get("field", ""))
	var value_text := str(int(stats.get(field, 0)))
	if bool(def.get("blank_if_missing", false)) and not stats.has(field):
		value_text = ""
	return _make_stat_cell(str(def.get("label", "")), value_text)


## 怪物包小标题（与上一分组留出额外间距）。
func _make_pack_header(text: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_child(_make_label(text, 16, _COLOR_ACCENT))
	return margin


## 怪物行：怪物名（含 boss 标记）+ 累计击杀 ×N。
func _make_monster_row(display_name: String, kills: int) -> PanelContainer:
	var row := _make_row_panel()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)
	var name_label := _make_label(display_name, 15, _COLOR_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	var count_label := _make_label("累计击杀 ×%d" % kills, 15, _COLOR_ACCENT)
	count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(count_label)
	return row


func _make_grid_cell(text: String, min_width: float, min_height: float, align: int, color: Color, bg_color: Color, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(bg_color))
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, min_height)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return panel


## 毫秒 → mm:ss（如 12:34）；非正值返回 "-"（无有效记录）。
func _format_mission_time(msec: int) -> String:
	if msec <= 0:
		return "-"
	var total_sec: int = msec / 1000
	return "%02d:%02d" % [total_sec / 60, total_sec % 60]


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
