class_name MonsterCardView
extends Control

## 共享怪物卡面组件（自 PopupManager._build_monster_card 抽取）。
## 布局基准：内卡 120×180 + 5px 黑边外框（整体 130×190）。
## 内卡：深色底 + 立绘铺底（KEEP_ASPECT_COVERED，无图保持深色底）
## + 右上 HP（hp/max_hp）+ 攻击力 + 中下名称 + 名称下射程 + 左上眩晕标识。
## new(w, h) 指定内卡尺寸，内部整体按 w/120 等比缩放，任意尺寸视觉一致。
## set_monster() 接收 Monster 或 MonsterCard（MonsterCard 无 hp/stunned 字段时
## hp 取 max_hp、不显示眩晕）。抓取怪物牌动画与怪物区弹窗共用本组件。

const BASE_W: float = 120.0
const BASE_H: float = 180.0
const BORDER: float = 5.0

var _outer: Panel
var _inner: Panel
var _img: TextureRect
var _hp_label: Label
var _atk_label: Label
var _name_label: Label
var _range_label: Label
var _stun_label: Label


func _init(w: float = BASE_W, h: float = BASE_H) -> void:
	var factor: float = w / BASE_W
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total: Vector2 = Vector2(BASE_W + BORDER * 2.0, BASE_H + BORDER * 2.0) * factor
	custom_minimum_size = total
	size = total
	# 外层黑框
	_outer = Panel.new()
	_outer.size = total
	_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color.BLACK
	_outer.add_theme_stylebox_override("panel", outer_style)
	add_child(_outer)
	# 基准尺寸内卡（含全部子节点），整体缩放到目标尺寸
	var wrapper := Control.new()
	wrapper.position = Vector2(BORDER, BORDER) * factor
	wrapper.scale = Vector2(factor, factor)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outer.add_child(wrapper)
	_build_inner(wrapper)


## 构建基准内卡（120×180）及全部子节点。
func _build_inner(parent: Control) -> void:
	_inner = Panel.new()
	_inner.size = Vector2(BASE_W, BASE_H)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	_inner.add_theme_stylebox_override("panel", inner_style)
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_inner)

	# 怪物立绘（铺满内卡）
	_img = TextureRect.new()
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_img.visible = false
	_inner.add_child(_img)

	# HP/MaxHP（右上角）
	_hp_label = Label.new()
	_hp_label.position = Vector2(BASE_W - 58.0, 4.0)
	_hp_label.size = Vector2(54.0, 16.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_label.add_theme_constant_override("outline_size", 3)
	_inner.add_child(_hp_label)

	# 攻击力（HP 下方）
	_atk_label = Label.new()
	_atk_label.position = Vector2(BASE_W - 58.0, 21.0)
	_atk_label.size = Vector2(54.0, 16.0)
	_atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_atk_label.add_theme_font_size_override("font_size", 11)
	_atk_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_atk_label.add_theme_constant_override("outline_size", 3)
	_inner.add_child(_atk_label)

	# 怪物名（中下）
	_name_label = Label.new()
	_name_label.position = Vector2(4.0, BASE_H - 52.0)
	_name_label.size = Vector2(BASE_W - 8.0, 20.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_inner.add_child(_name_label)

	# 射程（名字下方：短/中/长彩色，纠缠白字）
	_range_label = Label.new()
	_range_label.position = Vector2(4.0, BASE_H - 32.0)
	_range_label.size = Vector2(BASE_W - 8.0, 18.0)
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_font_size_override("font_size", 11)
	_range_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_range_label.add_theme_constant_override("outline_size", 3)
	_inner.add_child(_range_label)

	# 眩晕标识（左上角，默认隐藏）
	_stun_label = Label.new()
	_stun_label.text = "眩晕"
	_stun_label.position = Vector2(4.0, 4.0)
	_stun_label.size = Vector2(34.0, 16.0)
	_stun_label.add_theme_font_size_override("font_size", 10)
	_stun_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	_stun_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_stun_label.add_theme_constant_override("outline_size", 2)
	_stun_label.visible = false
	_inner.add_child(_stun_label)


## 填充怪物数据：接收 Monster 或 MonsterCard。
## MonsterCard 无 hp/stunned 字段：hp 显示 max_hp/max_hp，不显示眩晕。
func set_monster(m: Variant) -> void:
	var name_val: Variant = m.get("monster_name")
	if name_val == null or not (name_val is String) or name_val == "":
		name_val = m.get("card_name")
	var mon_name: String = name_val if name_val is String else ""
	var max_hp_val: Variant = m.get("max_hp")
	var max_hp: int = max_hp_val if max_hp_val is int else 0
	var hp_val: Variant = m.get("hp")
	var hp: int = hp_val if hp_val is int else max_hp
	var dmg_val: Variant = m.get("damage_value")
	var dmg: int = dmg_val if dmg_val is int else 0
	var range_val: Variant = m.get("range")
	var range_str: String = range_val if range_val is String else ""
	var stunned: bool = bool(m.get("stunned")) if m.get("stunned") != null else false

	# 立绘（有图时铺满并按眩晕变色）
	var tex: Texture2D = ImageCache.get_monster_texture(mon_name)
	_img.texture = tex
	_img.visible = tex != null
	_img.modulate = Color(0.5, 0.5, 0.8, 0.7) if stunned else Color.WHITE

	_hp_label.text = "%d/%d" % [hp, max_hp]
	_atk_label.text = "攻 %d" % dmg
	_name_label.text = mon_name
	_stun_label.visible = stunned

	# 射程文案与配色（与原 PopupManager._build_monster_card 一致）
	if CardView.RANGE_MAP.has(range_str):
		_range_label.text = CardView.RANGE_MAP[range_str]
		_range_label.add_theme_color_override("font_color", CardView.RANGE_COLORS[range_str])
	elif range_str == "none":
		_range_label.text = "纠缠"
		_range_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		_range_label.text = "无限" if range_str == "infinity" else range_str
		_range_label.add_theme_color_override("font_color", Color.WHITE)


## 返回基准内卡面板（供外部叠加标签，如"纠缠: 玩家名"）。
func get_inner() -> Panel:
	return _inner


## 选中态高亮外框（金色描边），供目标选择弹窗复用。
func set_selected(selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	if selected:
		style.set_border_width_all(3)
		style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	_outer.add_theme_stylebox_override("panel", style)
