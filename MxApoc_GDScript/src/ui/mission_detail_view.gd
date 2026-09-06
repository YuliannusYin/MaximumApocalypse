class_name MissionDetailView
extends VBoxContainer

## 任务详情共用视图：分区卡片展示背景 / 清单 / 次要配置。
## 游戏房间中栏与对局弹窗共用；不显示独立燃料元数据行。

const CARD_PRIMARY_BG := Color("#26241e")
const CARD_SECONDARY_BG := Color("#1a1916")
const PLACEHOLDER_RANDOM := "随机任务（开局时抽取）"
## 弹窗首次布局前 ScrollContainer 宽度常为 0；必须给自动换行一个有限宽度，否则 Label 会按逐字换行把高度撑爆并卡死。
const FALLBACK_WRAP_WIDTH := 540
const CARD_BODY_INSET := 28

const MAP_GRID_COLUMNS := 4
const MAP_GRID_H_SEP := 10
const MAP_GRID_V_SEP := 4
const SCAVENGE_COL_SEP := 12

const _SCAVENGE_COLOR_ORDER := ["red", "green", "blue"]
const _SCAVENGE_COLOR_NAMES := {
	"red": "红色",
	"green": "绿色",
	"blue": "蓝色",
}
const _SCAVENGE_HEADER_COLORS := {
	"red": Color(0.78, 0.42, 0.38, 1.0),
	"green": Color(0.48, 0.64, 0.42, 1.0),
	"blue": Color(0.46, 0.58, 0.78, 1.0),
}

var _wrap_width: int = FALLBACK_WRAP_WIDTH


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disable_h_scroll()


## 填充任务详情。mission 为 null 时显示 placeholder（空字符串则留白）。
func populate(mission: Variant, placeholder: String = "") -> void:
	_clear_children()
	_disable_h_scroll()
	_ensure_wrap_width()
	if mission == null:
		_show_placeholder(placeholder)
		return
	var pack_type := str(_field(mission, "monster_pack_type", ""))
	var pack_name: String = WikiIndex.MONSTER_PACK_NAMES.get(pack_type, pack_type)
	if pack_name != "":
		_add_meta("怪物包  ·  %s" % pack_name)
	var intro := str(_field(mission, "intro_text", "")).strip_edges()
	if intro != "":
		var bg_inner := _make_card("任务背景", true)
		_add_body(bg_inner, intro, HudTheme.TEXT_MAIN, 13)
	var objective := str(_field(mission, "objective_text", "")).strip_edges()
	if objective != "":
		var list_inner := _make_card("任务清单", true)
		for item in split_checklist(objective):
			_add_body(list_inner, "·  %s" % item, HudTheme.TEXT_MAIN, 13)
	var setup := str(_field(mission, "special_setup", "")).strip_edges()
	if setup != "":
		var setup_inner := _make_card("特殊设置", false)
		_add_body(setup_inner, setup, HudTheme.TEXT_DIM, 12)
	_add_config_card(mission)


## 按中文分号拆清单；无分号则整段一条。
static func split_checklist(objective_text: String) -> PackedStringArray:
	var items: PackedStringArray = []
	for part in objective_text.split("；", false):
		var text := part.strip_edges()
		if text != "":
			items.append(text)
	if items.is_empty():
		var fallback := objective_text.strip_edges()
		if fallback != "":
			items.append(fallback)
	return items


func _disable_h_scroll() -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll != null:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _ensure_wrap_width() -> void:
	var w := FALLBACK_WRAP_WIDTH
	var scroll := get_parent() as ScrollContainer
	if scroll != null and scroll.size.x > 80:
		w = maxi(int(scroll.size.x) - 20, 200)
	elif int(custom_minimum_size.x) > 80:
		w = int(custom_minimum_size.x)
	_wrap_width = w
	custom_minimum_size.x = w


func _body_wrap_width() -> int:
	return maxi(_wrap_width - CARD_BODY_INSET, 200)


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _show_placeholder(text: String) -> void:
	var msg := text.strip_edges()
	if msg == "":
		return
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.custom_minimum_size.x = _wrap_width
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_color_override("default_color", HudTheme.TEXT_DIM)
	rtl.text = "[i]%s[/i]" % msg
	add_child(rtl)


func _add_meta(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = _wrap_width
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
	add_child(label)


func _make_card(title: String, primary: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = _wrap_width
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_PRIMARY_BG if primary else CARD_SECONDARY_BG
	style.border_width_left = 3
	style.border_color = HudTheme.GOLD_BORDER if primary else HudTheme.SLOT_BORDER
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12 if primary else 11)
	title_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM if primary else HudTheme.TEXT_DIM)
	inner.add_child(title_label)
	add_child(panel)
	return inner


func _add_body(parent: Control, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = _body_wrap_width()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _add_config_card(mission: Variant) -> void:
	var map_blocks: Dictionary = {}
	var scavenge_config: Dictionary = {}
	var raw_blocks: Variant = _field(mission, "map_blocks_config", {})
	if raw_blocks is Dictionary:
		map_blocks = raw_blocks
	var raw_scavenge: Variant = _field(mission, "scavenge_config", {})
	if raw_scavenge is Dictionary:
		scavenge_config = raw_scavenge
	if map_blocks.is_empty() and scavenge_config.is_empty():
		return
	var inner := _make_card("任务配置", false)
	if not map_blocks.is_empty():
		_add_body(inner, "地图块", HudTheme.GOLD_TEXT_DIM, 11)
		_add_map_block_grid(inner, map_blocks)
	if not scavenge_config.is_empty():
		_add_body(inner, "拾荒牌堆", HudTheme.GOLD_TEXT_DIM, 11)
		_add_scavenge_columns(inner, scavenge_config)


func _add_map_block_grid(parent: Control, map_blocks: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = MAP_GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size.x = _body_wrap_width()
	grid.add_theme_constant_override("h_separation", MAP_GRID_H_SEP)
	grid.add_theme_constant_override("v_separation", MAP_GRID_V_SEP)
	for block_name in map_blocks:
		var cell := Label.new()
		cell.text = "%s *%d" % [block_name, int(map_blocks[block_name])]
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_font_size_override("font_size", 12)
		cell.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
		grid.add_child(cell)
	parent.add_child(grid)


func _add_scavenge_columns(parent: Control, scavenge_config: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", SCAVENGE_COL_SEP)
	var col_w: int = maxi(int((_body_wrap_width() - SCAVENGE_COL_SEP * 2) / 3.0), 80)
	row.custom_minimum_size.x = _body_wrap_width()
	for color in _SCAVENGE_COLOR_ORDER:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.custom_minimum_size.x = col_w
		col.add_theme_constant_override("separation", 2)
		var header := Label.new()
		header.text = _SCAVENGE_COLOR_NAMES[color]
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", _SCAVENGE_HEADER_COLORS[color])
		col.add_child(header)
		var card_entries: Array = scavenge_config.get(color, [])
		for entry in card_entries:
			if not (entry is Dictionary):
				continue
			var line := Label.new()
			line.text = "%s *%d" % [entry.get("card_name", ""), int(entry.get("count", 0))]
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = col_w
			line.add_theme_font_size_override("font_size", 12)
			line.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
			col.add_child(line)
		if card_entries.is_empty():
			var empty := Label.new()
			empty.text = "（无）"
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
			col.add_child(empty)
		row.add_child(col)
	parent.add_child(row)


func _field(mission: Variant, key: String, default: Variant = null) -> Variant:
	if mission is MissionData:
		match key:
			"monster_pack_type":
				return mission.monster_pack_type
			"intro_text":
				return mission.intro_text
			"objective_text":
				return mission.objective_text
			"special_setup":
				return mission.special_setup
			"map_blocks_config":
				return mission.map_blocks_config
			"scavenge_config":
				return mission.scavenge_config
			_:
				return default
	if mission is Dictionary:
		return mission.get(key, default)
	if mission is Object and is_instance_valid(mission):
		var value: Variant = mission.get(key)
		return default if value == null else value
	return default
