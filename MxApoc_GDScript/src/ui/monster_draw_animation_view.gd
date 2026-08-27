class_name MonsterDrawAnimationView
extends Control

## 怪物抓取动画组件（纯代码构建，无 .tscn）。
## 全屏覆盖层：半透明黑背景 + 一张怪物卡（牌背淡入 → 翻面 → 正面定格 → 飞向目标点）。
## 牌面图片优先：牌背用 images/monster/怪物卡牌背面.jpg；正面有怪物立绘时
## 参考 CardView 以图片为底、信息叠加渲染（级别/名称/数值行），无图回退纯文字卡面。
## 用法：实例化后加入 CanvasLayer，await play(card, target_position) 播放完整动画。
## 所有节点 mouse_filter 均为 IGNORE，播放期间不遮挡其他 UI 点击。

# === 时间轴常量（秒），总时长约 1.85s ===
const FADE_IN_DURATION: float = 0.15    # 淡入 + 牌背居中
const FLIP_DURATION: float = 0.4        # 翻面总时长（牌背收窄与正面展开各占一半）
const HOLD_DURATION: float = 0.8        # 正面定格停留
const FLY_DURATION: float = 0.5         # 飞向目标点
const FLY_END_SCALE: float = 0.3        # 飞行结束时的缩放

# === 布局常量（视口约 1430x800，卡中心以 (715, 300) 附近居中） ===
const CENTER_X: float = 715.0
const CARD_CENTER_Y: float = 300.0

# === 成员变量 ===
var _background: ColorRect
var _card: MonsterCardFace
var _playing: bool = false
var _fade_tween: Tween = null
var _flip_tween: Tween = null
var _fly_tween: Tween = null


# === 怪物卡（内部类） ===

## 怪物卡：牌背（真实牌背图，无图回退深色 + "?"）与正面（图片叠加信息，无图回退文字卡面）
## 双层节点，翻面时切换显隐。scale:x 收窄/展开由外部 Tween 驱动，pivot 为卡中心。
class MonsterCardFace extends Control:
	const CARD_SIZE: Vector2 = Vector2(200.0, 280.0)

	# === 正面布局（卡内坐标） ===
	const ROW_WIDTH: float = 180.0        # 文本行宽（左右留边 10）
	const NAME_Y: float = 26.0            # 怪物名称顶部
	const LEVEL_Y: float = 78.0           # 级别标签顶部
	const TYPE_Y: float = 116.0           # 怪物类型顶部
	const HP_Y: float = 154.0             # 生命值顶部
	const DAMAGE_Y: float = 190.0         # 攻击伤害顶部
	const RANGE_Y: float = 226.0          # 射程顶部

	# === 正面文案映射 ===
	# 怪物类型
	const MONSTER_TYPE_NAMES: Dictionary = {
		"alien": "外星人",
		"mutant": "突变体",
		"zombie": "僵尸",
		"robot": "机器人",
	}
	# 怪物级别
	const MONSTER_LEVEL_NAMES: Dictionary = {
		"boss": "首领",
		"elite": "精英",
		"normal": "普通",
	}
	# 射程
	const RANGE_NAMES: Dictionary = {
		"none": "无",
		"short": "短程",
		"medium": "中程",
		"long": "远程",
		"infinity": "无限",
	}
	# 级别标签配色：首领=红 / 精英=橙 / 普通=灰白
	const LEVEL_COLORS: Dictionary = {
		"boss": Color(1.0, 0.35, 0.35),
		"elite": Color(1.0, 0.62, 0.2),
		"normal": Color(0.85, 0.85, 0.88),
	}

	# 正面文案配色
	const COLOR_NAME: Color = Color(1.0, 1.0, 1.0)     # 名称：白
	const COLOR_TYPE: Color = Color(0.65, 0.65, 0.7)   # 类型：灰
	const COLOR_STAT: Color = Color(0.92, 0.92, 0.92)  # 数值行：灰白

	var _back: Panel
	var _back_label: Label
	var _back_texture_rect: TextureRect
	var _front: Panel
	var _front_texture_rect: TextureRect
	var _name_label: Label
	var _level_label: Label
	var _type_label: Label
	var _hp_label: Label
	var _damage_label: Label
	var _range_label: Label
	var _home_position: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = CARD_SIZE
		size = CARD_SIZE
		pivot_offset = CARD_SIZE * 0.5
		_build_back()
		_build_front()
		_apply_back_texture()
		show_back()

	## 构建牌背：真实牌背图打底（无图时回退深色底 + 边框 + 居中"?"大字）。
	func _build_back() -> void:
		_back = Panel.new()
		_back.size = CARD_SIZE
		_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.13)
		style.set_corner_radius_all(12)
		style.set_border_width_all(3)
		style.border_color = Color(0.45, 0.45, 0.55)
		_back.add_theme_stylebox_override("panel", style)
		_back_texture_rect = TextureRect.new()
		_back_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_back_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_back_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_back_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_back_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_texture_rect.visible = false
		_back.add_child(_back_texture_rect)
		_back_label = Label.new()
		_back_label.position = Vector2.ZERO
		_back_label.size = CARD_SIZE
		_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_back_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_label.add_theme_font_size_override("font_size", 72)
		_back_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		_back_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_back_label.add_theme_constant_override("outline_size", 4)
		_back_label.text = "?"
		_back.add_child(_back_label)
		add_child(_back)

	## 应用牌背纹理：有真实牌背图时铺满牌背并隐藏"?"，无图保持占位样式。
	func _apply_back_texture() -> void:
		var tex: Texture2D = ImageCache.get_monster_card_back_texture()
		if tex == null:
			return
		_back_texture_rect.texture = tex
		_back_texture_rect.visible = true
		_back_label.visible = false

	## 构建正面：图片打底（有立绘时叠加信息），无图回退文字卡面
	## （名称 / 级别 / 类型 / 生命值 / 攻击伤害 / 射程）。
	func _build_front() -> void:
		_front = Panel.new()
		_front.size = CARD_SIZE
		_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.2)
		style.set_corner_radius_all(12)
		style.set_border_width_all(3)
		style.border_color = Color(0.55, 0.55, 0.62)
		_front.add_theme_stylebox_override("panel", style)
		add_child(_front)
		_front_texture_rect = TextureRect.new()
		_front_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_front_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_front_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_front_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_front_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_texture_rect.visible = false
		_front.add_child(_front_texture_rect)
		_name_label = _make_row_label(NAME_Y, 40.0, 26, COLOR_NAME, true)
		_level_label = _make_row_label(LEVEL_Y, 28.0, 18, LEVEL_COLORS["normal"], true)
		_type_label = _make_row_label(TYPE_Y, 24.0, 16, COLOR_TYPE, false)
		_hp_label = _make_row_label(HP_Y, 24.0, 16, COLOR_STAT, false)
		_damage_label = _make_row_label(DAMAGE_Y, 24.0, 16, COLOR_STAT, false)
		_range_label = _make_row_label(RANGE_Y, 24.0, 16, COLOR_STAT, false)

	## 构建正面单行居中文本标签（可选黑描边），加入 _front。
	func _make_row_label(y: float, height: float, font_size: int, color: Color, outlined: bool) -> Label:
		var label := Label.new()
		label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, y)
		label.size = Vector2(ROW_WIDTH, height)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		if outlined:
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
		_front.add_child(label)
		return label

	## 填充正面数据：有怪物立绘时走图片布局（参考 CardView），无图回退文字卡面。
	func set_card_data(card: MonsterCard) -> void:
		var tex: Texture2D = ImageCache.get_monster_texture(card.card_name)
		if tex != null:
			_apply_image_layout(card, tex)
		else:
			_apply_text_layout(card)

	## 图片布局：立绘铺满卡面 + 顶部级别徽章 + 中下名称 + 名称下数值行（均黑描边）。
	func _apply_image_layout(card: MonsterCard, tex: Texture2D) -> void:
		_front_texture_rect.texture = tex
		_front_texture_rect.visible = true
		# 级别徽章：顶部居中，配色随级别
		_level_label.text = MONSTER_LEVEL_NAMES.get(card.monster_level, "普通")
		_level_label.add_theme_color_override("font_color", LEVEL_COLORS.get(card.monster_level, LEVEL_COLORS["normal"]))
		_level_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, 12.0)
		_level_label.size = Vector2(ROW_WIDTH, 26.0)
		_level_label.add_theme_font_size_override("font_size", 18)
		_level_label.visible = true
		# 名称：中下
		_name_label.text = card.card_name
		_name_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, CARD_SIZE.y - 84.0)
		_name_label.size = Vector2(ROW_WIDTH, 40.0)
		_name_label.add_theme_font_size_override("font_size", 24)
		_name_label.visible = true
		# 数值行：名称下方一行合并展示（生命/伤害/射程），复用生命值标签
		_hp_label.text = "生命 %d · 伤害 %d · 射程 %s" % [
			card.max_hp,
			card.damage_value,
			RANGE_NAMES.get(card.range, card.range),
		]
		_hp_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, CARD_SIZE.y - 42.0)
		_hp_label.size = Vector2(ROW_WIDTH, 26.0)
		_hp_label.add_theme_font_size_override("font_size", 15)
		_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_hp_label.add_theme_constant_override("outline_size", 4)
		_hp_label.visible = true
		# 图片模式不单独显示类型/伤害/射程行
		_type_label.visible = false
		_damage_label.visible = false
		_range_label.visible = false

	## 文字布局：纯文字卡面（名称 / 级别 / 类型 / 生命值 / 攻击伤害 / 射程）。
	func _apply_text_layout(card: MonsterCard) -> void:
		_front_texture_rect.visible = false
		_name_label.text = card.card_name
		_name_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, NAME_Y)
		_name_label.size = Vector2(ROW_WIDTH, 40.0)
		_name_label.add_theme_font_size_override("font_size", 26)
		_name_label.visible = true
		_level_label.text = MONSTER_LEVEL_NAMES.get(card.monster_level, "普通")
		_level_label.add_theme_color_override("font_color", LEVEL_COLORS.get(card.monster_level, LEVEL_COLORS["normal"]))
		_level_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, LEVEL_Y)
		_level_label.size = Vector2(ROW_WIDTH, 28.0)
		_level_label.add_theme_font_size_override("font_size", 18)
		_level_label.visible = true
		_type_label.text = MONSTER_TYPE_NAMES.get(card.monster_type, card.monster_type)
		_type_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, TYPE_Y)
		_type_label.size = Vector2(ROW_WIDTH, 24.0)
		_type_label.add_theme_font_size_override("font_size", 16)
		_type_label.visible = true
		_hp_label.text = "生命值 " + str(card.max_hp)
		_hp_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, HP_Y)
		_hp_label.size = Vector2(ROW_WIDTH, 24.0)
		_hp_label.add_theme_font_size_override("font_size", 16)
		_hp_label.visible = true
		_damage_label.text = "攻击伤害 " + str(card.damage_value)
		_damage_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, DAMAGE_Y)
		_damage_label.size = Vector2(ROW_WIDTH, 24.0)
		_damage_label.visible = true
		_range_label.text = "射程 " + RANGE_NAMES.get(card.range, card.range)
		_range_label.position = Vector2((CARD_SIZE.x - ROW_WIDTH) * 0.5, RANGE_Y)
		_range_label.size = Vector2(ROW_WIDTH, 24.0)
		_range_label.visible = true

	## 显示牌背（隐藏正面）。
	func show_back() -> void:
		_back.visible = true
		_front.visible = false

	## 显示正面（隐藏牌背）。
	func show_front() -> void:
		_back.visible = false
		_front.visible = true

	## 设置基准位置（飞行起点与复位均以此为原点）。
	func set_home_position(pos: Vector2) -> void:
		_home_position = pos
		position = pos

	## 返回基准位置。
	func get_home_position() -> Vector2:
		return _home_position


# === 生命周期 ===

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 父为 CanvasLayer 时锚点可能不生效，先设全屏锚点再按视口尺寸显式铺满
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_build_ui()
	visible = false


# === UI 构建 ===

## 纯代码构建覆盖层：半透明背景 + 居中怪物卡。
func _build_ui() -> void:
	# 半透明黑色全屏背景
	_background = ColorRect.new()
	_background.color = Color(0.0, 0.0, 0.0, 0.35)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	# 怪物卡：整体以 (CENTER_X, CARD_CENTER_Y) 为中心
	_card = MonsterCardFace.new()
	_card.set_home_position(Vector2(CENTER_X, CARD_CENTER_Y) - MonsterCardFace.CARD_SIZE * 0.5)
	add_child(_card)


# === 动画播放 ===

## 播放一次完整的怪物抓取动画（协程，可 await，播完整轮后才返回）。
## card：要展示的怪物卡；target_position：飞行终点全局坐标（Vector2.ZERO 或无效则原地淡出）。
## 时间轴：淡入 0.15s → 翻面 0.4s → 定格停留 0.8s → 飞行 0.5s，总时长约 1.85s。
func play(card: MonsterCard, target_position: Vector2) -> void:
	# 防重入：播放中再次调用直接返回
	if _playing:
		return
	_playing = true
	# --- 准备：填充卡面数据、显示牌背、复位变换 ---
	_card.set_card_data(card)
	_reset_card()
	visible = true
	modulate.a = 0.0
	# --- 淡入：整体淡入，牌背居中 ---
	_kill_tween(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	await _fade_tween.finished
	# --- 翻面：牌背 scale:x 1→0，切换正面后 0→1 ---
	_kill_tween(_flip_tween)
	_flip_tween = create_tween()
	_flip_tween.tween_property(_card, "scale:x", 0.0, FLIP_DURATION * 0.5)
	await _flip_tween.finished
	_card.show_front()
	_flip_tween = create_tween()
	_flip_tween.tween_property(_card, "scale:x", 1.0, FLIP_DURATION * 0.5)
	await _flip_tween.finished
	# --- 定格停留 ---
	await get_tree().create_timer(HOLD_DURATION).timeout
	# --- 飞行：飞向目标点，同时缩小 + 淡出（无效目标则原地缩小淡出） ---
	_kill_tween(_fly_tween)
	_fly_tween = create_tween()
	_fly_tween.set_parallel(true)
	_fly_tween.tween_property(_card, "position", _fly_end_position(target_position), FLY_DURATION)
	_fly_tween.tween_property(_card, "scale", Vector2.ONE * FLY_END_SCALE, FLY_DURATION)
	_fly_tween.tween_property(_card, "modulate:a", 0.0, FLY_DURATION)
	await _fly_tween.finished
	# --- 结束：隐藏自身并复位卡牌 ---
	visible = false
	_reset_card()
	_playing = false


# === 内部辅助 ===

## 复位卡牌状态（牌面 / 缩放 / 透明度 / 位置），供下次播放。
func _reset_card() -> void:
	_card.show_back()
	_card.scale = Vector2.ONE
	_card.modulate.a = 1.0
	_card.position = _card.get_home_position()


## 计算飞行终点：全局坐标转 self 局部坐标，并按终点缩放补偿中心偏移，
## 使缩小后的卡中心恰好落在目标点；目标无效（ZERO 或非有限值）时返回基准位置。
func _fly_end_position(target_position: Vector2) -> Vector2:
	if target_position == Vector2.ZERO or not target_position.is_finite():
		return _card.get_home_position()
	var local: Vector2 = get_global_transform().affine_inverse() * target_position
	return local - MonsterCardFace.CARD_SIZE * 0.5 * FLY_END_SCALE


## 终止旧 Tween（防泄漏）。
func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
