class_name EventLogPanel
extends Control

## 常驻游戏事件日志面板。
## 显示最近的 16 条游戏事件日志，实时更新。

const MAX_LINES: int = 16
const PANEL_POS: Vector2 = Vector2(10, 210)
const PANEL_SIZE: Vector2 = Vector2(200, 300)
const BG_COLOR: Color = Color("#1E2228")

var _panel: Panel = null
var _title_label: Label = null
var _log_label: RichTextLabel = null
var _messages: Array[String] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Panel 容器
	_panel = Panel.new()
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0)
	bg_style.content_margin_left = 4
	bg_style.content_margin_right = 4
	bg_style.content_margin_top = 4
	bg_style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_panel)

	# 标题
	_title_label = Label.new()
	_title_label.text = "事件日志"
	_title_label.position = Vector2(4, 4)
	_title_label.size = Vector2(PANEL_SIZE.x - 8, 20)
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color("#cccccc"))
	_panel.add_child(_title_label)

	# RichTextLabel
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.position = Vector2(4, 28)
	_log_label.size = Vector2(PANEL_SIZE.x - 8, PANEL_SIZE.y - 32)
	_log_label.add_theme_color_override("default_color", Color("#cccccc"))
	_log_label.add_theme_font_size_override("normal_font_size", 10)
	_log_label.scroll_active = true
	_log_label.scroll_following = true
	_log_label.selection_enabled = false
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_log_label)


## 追加一条日志消息，仅保留最近 MAX_LINES 条。
func add_message(message: String) -> void:
	_messages.append(message)
	while _messages.size() > MAX_LINES:
		_messages.pop_front()
	_refresh_display()


## 批量设置日志内容（取最近 MAX_LINES 条）。
func set_messages(messages: Array) -> void:
	_messages.clear()
	var start_idx: int = maxi(0, messages.size() - MAX_LINES)
	for i in range(start_idx, messages.size()):
		_messages.append(messages[i])
	_refresh_display()


func _refresh_display() -> void:
	if _log_label == null:
		return
	var text: String = ""
	for i in range(_messages.size()):
		if i > 0:
			text += "\n"
		text += _messages[i]
	_log_label.text = text
	# 自动滚动到底部
	_log_label.scroll_to_line(_log_label.get_line_count() - 1)
