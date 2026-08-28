class_name MonsterDrawAnimationView
extends Control

## 怪物抓取动画组件（纯代码构建，无 .tscn）。
## 全屏覆盖层：半透明黑背景 + 一张怪物卡（牌背淡入 → 翻面 → 正面定格 → 飞向目标点）。
## 正面复用共享组件 MonsterCardView（玩家面板怪物区样式，120×180 基准等比放大 1.5 倍
## = 内卡 180×270），抓取阶段怪物 HP 显示 max_hp/max_hp；
## 牌背用固定图片 images/monster/怪物卡牌背面.jpg 拉伸铺满整卡，无图回退深色 + "?"。
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

## 怪物卡：牌背（固定牌背图拉伸铺满，无图回退深色 + "?"）与正面（共享组件
## MonsterCardView，怪物区样式放大 1.5 倍）双层节点，翻面时切换显隐。
## scale:x 收窄/展开由外部 Tween 驱动，pivot 为卡中心。
class MonsterCardFace extends Control:
	# 整卡尺寸：MonsterCardView 以 1.5 倍渲染（内卡 180×270 + 黑边外框）
	const CARD_SIZE: Vector2 = Vector2(195.0, 285.0)

	var _back: Panel
	var _back_label: Label
	var _back_texture_rect: TextureRect
	var _front_view: MonsterCardView
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

	## 构建牌背：固定牌背图打底（拉伸铺满整卡），无图时回退深色 + 边框 + 居中"?"大字。
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
		_back_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
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

	## 应用牌背纹理：有牌背图时拉伸铺满整卡并隐藏"?"，无图保持占位样式。
	func _apply_back_texture() -> void:
		var tex: Texture2D = ImageCache.get_monster_card_back_texture()
		if tex == null:
			return
		_back_texture_rect.texture = tex
		_back_texture_rect.visible = true
		_back_label.visible = false

	## 构建正面：共享组件 MonsterCardView（怪物区样式，内卡 180×270 = 放大 1.5 倍）。
	func _build_front() -> void:
		_front_view = MonsterCardView.new(180.0, 270.0)
		_front_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_front_view)

	## 填充正面数据：传入 MonsterCard（组件内 hp 取 max_hp，即显示 max_hp/max_hp）。
	func set_card_data(card: MonsterCard) -> void:
		_front_view.set_monster(card)

	## 显示牌背（隐藏正面）。
	func show_back() -> void:
		_back.visible = true
		_front_view.visible = false

	## 显示正面（隐藏牌背）。
	func show_front() -> void:
		_back.visible = false
		_front_view.visible = true

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
