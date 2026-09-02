class_name HudTheme
extends RefCounted

## 对局 HUD 共用皮肤：废土金属槽按钮与角色牌相框。
## 颜色与 PlayerPanel 资源槽一致，避免各处 StyleBox 各写一套。

const SLOT_BG := Color(0.13, 0.12, 0.11, 1.0)
const SLOT_BG_HOVER := Color(0.20, 0.18, 0.15, 1.0)
const SLOT_BG_PRESSED := Color(0.10, 0.09, 0.08, 1.0)
const SLOT_BG_DISABLED := Color(0.10, 0.10, 0.10, 1.0)
const SLOT_BORDER := Color(0.38, 0.32, 0.24, 1.0)
const GOLD_BORDER := Color(1.0, 0.80, 0.30, 1.0)
const GOLD_TEXT := Color(1.0, 0.85, 0.45, 1.0)
const GOLD_TEXT_DIM := Color(0.70, 0.60, 0.35, 1.0)
const TEXT_MAIN := Color(0.92, 0.90, 0.84, 1.0)
const TEXT_DIM := Color(0.62, 0.60, 0.55, 1.0)
const FRAME_WIDTH := 2


static func apply_slot_button(btn: Button, font_size: int = 12, border: Color = SLOT_BORDER, text: Color = TEXT_MAIN) -> void:
	if btn == null:
		return
	btn.clip_text = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", text)
	btn.add_theme_color_override("font_hover_color", text)
	btn.add_theme_color_override("font_pressed_color", text)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	btn.add_theme_color_override("font_focus_color", text)
	btn.add_theme_stylebox_override("normal", make_slot_style(SLOT_BG, border))
	btn.add_theme_stylebox_override("hover", make_slot_style(SLOT_BG_HOVER, border))
	btn.add_theme_stylebox_override("pressed", make_slot_style(SLOT_BG_PRESSED, border))
	btn.add_theme_stylebox_override("disabled", make_slot_style(SLOT_BG_DISABLED, Color(0.22, 0.20, 0.18, 1.0)))
	btn.add_theme_stylebox_override("focus", make_slot_style(SLOT_BG, border))


static func apply_mission_slot_button(btn: Button, font_size: int = 12) -> void:
	apply_slot_button(btn, font_size, GOLD_BORDER, GOLD_TEXT)
	btn.add_theme_color_override("font_disabled_color", GOLD_TEXT_DIM)


static func make_slot_style(bg: Color, border: Color = SLOT_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


static func make_picture_frame_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = FRAME_WIDTH
	style.border_width_top = FRAME_WIDTH
	style.border_width_right = FRAME_WIDTH
	style.border_width_bottom = FRAME_WIDTH
	style.border_color = SLOT_BORDER
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


## 非角色牌卡面使用的 2px 废土金属相框。
## 与角色面板相框保持同色系，但独立方法避免影响角色牌现有样式。
static func make_card_frame_style(bg: Color = Color.BLACK) -> StyleBoxFlat:
	var style := make_picture_frame_style(bg)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 4
	style.shadow_offset = Vector2(1, 2)
	return style
