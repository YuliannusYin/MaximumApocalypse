class_name DiceAnimationView
extends Control

## 骰子投掷动画组件（纯代码构建，无 .tscn）。
## 全屏覆盖层：半透明黑背景 + 检定名称 + 两颗翻滚骰子 + 结果文本。
## 用法：实例化后加入 CanvasLayer，await play(d1, d2, label, outcome) 播放完整动画。
## 所有节点 mouse_filter 均为 IGNORE，播放期间不遮挡其他 UI 点击。

# === 时间轴常量（秒） ===
const FADE_IN_DURATION: float = 0.15    # 整体淡入
const ROLL_DURATION: float = 2.0        # 翻滚总时长
const ROLL_STEP: float = 0.08           # 翻滚步进间隔
const SETTLE_DURATION: float = 0.2      # 定格复位
const HOLD_DURATION: float = 0.9        # 定格停留
const FADE_OUT_DURATION: float = 0.25   # 整体淡出

# === 布局常量（视口约 1430x800，中央元素以 (715, 300) 附近居中） ===
const CENTER_X: float = 715.0
const NAME_Y: float = 195.0             # 检定名称顶部
const DICE_Y: float = 250.0             # 骰子行顶部
const RESULT_Y: float = 375.0           # 结果文本顶部
const DICE_GAP: float = 40.0            # 两骰水平间距

# === 结果文本配色 ===
const COLOR_NAME: Color = Color(1.0, 0.85, 0.3)      # 默认/检定名称：黄
const COLOR_SUCCESS: Color = Color(0.35, 0.9, 0.45)  # 含"成功"：绿
const COLOR_FAILURE: Color = Color(1.0, 0.4, 0.4)    # 含"失败"：红

# === 成员变量 ===
var _background: ColorRect
var _name_label: Label
var _result_label: Label
var _dice1: DiceFace
var _dice2: DiceFace
var _playing: bool = false
var _fade_tween: Tween = null
var _settle_tween: Tween = null


# === 单颗骰子（内部类） ===

## 骰子面：白色圆角面板 + 3x3 网格 9 个圆点，按标准骰面 1-6 显隐。
class DiceFace extends Panel:
	const FACE_SIZE: Vector2 = Vector2(96, 96)
	const DOT_SIZE: float = 16.0
	# 圆点中心位于面板 20% / 50% / 80% 的网格位置
	const GRID_FRACTIONS: Array = [0.2, 0.5, 0.8]
	# 各面值显示的圆点索引（0左上 1中上 2右上 3左中 4中心 5右中 6左下 7中下 8右下）
	const FACE_DOTS: Dictionary = {
		1: [4],
		2: [0, 8],
		3: [0, 4, 8],
		4: [0, 2, 6, 8],
		5: [0, 2, 4, 6, 8],
		6: [0, 2, 3, 5, 6, 8],
	}

	var _dots: Array = []
	var _home_position: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = FACE_SIZE
		size = FACE_SIZE
		pivot_offset = FACE_SIZE * 0.5
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(20)
		style.set_border_width_all(3)
		style.border_color = Color(0.2, 0.2, 0.2)
		add_theme_stylebox_override("panel", style)
		_build_dots()
		set_face(1)

	## 构建 3x3 网格的 9 个黑色圆形圆点。
	func _build_dots() -> void:
		for row in 3:
			for col in 3:
				var dot := Panel.new()
				dot.size = Vector2(DOT_SIZE, DOT_SIZE)
				dot.position = Vector2(
					FACE_SIZE.x * float(GRID_FRACTIONS[col]) - DOT_SIZE * 0.5,
					FACE_SIZE.y * float(GRID_FRACTIONS[row]) - DOT_SIZE * 0.5
				)
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var dot_style := StyleBoxFlat.new()
				dot_style.bg_color = Color.BLACK
				dot_style.set_corner_radius_all(int(DOT_SIZE * 0.5))
				dot.add_theme_stylebox_override("panel", dot_style)
				add_child(dot)
				_dots.append(dot)

	## 按标准骰面显示圆点（1:中 2:左上右下 3:左上中右下 4:四角 5:四角+中 6:左右两列各三）。
	func set_face(value: int) -> void:
		var face_dots: Array = FACE_DOTS[clampi(value, 1, 6)]
		for i in _dots.size():
			_dots[i].visible = face_dots.has(i)

	## 设置基准位置（晃动偏移与定格复位均以此为原点）。
	func set_home_position(pos: Vector2) -> void:
		_home_position = pos
		position = pos

	## 返回基准位置。
	func get_home_position() -> Vector2:
		return _home_position

	## 随机晃动：rotation ±0.3 弧度，position 小随机偏移。
	func jiggle() -> void:
		rotation = randf_range(-0.3, 0.3)
		position = _home_position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))


# === 生命周期 ===

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 父为 CanvasLayer 时锚点可能不生效，先设全屏锚点再按视口尺寸显式铺满
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_build_ui()
	visible = false


# === UI 构建 ===

## 纯代码构建覆盖层：半透明背景、检定名称、两颗骰子、结果文本。
func _build_ui() -> void:
	# 半透明黑色全屏背景
	_background = ColorRect.new()
	_background.color = Color(0.0, 0.0, 0.0, 0.35)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	# 检定名称（黄色大字 + 黑描边）
	_name_label = Label.new()
	_name_label.position = Vector2(CENTER_X - 200.0, NAME_Y)
	_name_label.size = Vector2(400.0, 30.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", COLOR_NAME)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_name_label)
	# 两颗骰子：水平排列、间距 40，整体以 (CENTER_X, DICE_Y+48) 为中心
	var total_width: float = DiceFace.FACE_SIZE.x * 2.0 + DICE_GAP
	_dice1 = DiceFace.new()
	_dice1.set_home_position(Vector2(CENTER_X - total_width * 0.5, DICE_Y))
	add_child(_dice1)
	_dice2 = DiceFace.new()
	_dice2.set_home_position(Vector2(CENTER_X + total_width * 0.5 - DiceFace.FACE_SIZE.x, DICE_Y))
	add_child(_dice2)
	# 结果文本（颜色随成败切换，初始隐藏）
	_result_label = Label.new()
	_result_label.position = Vector2(CENTER_X - 300.0, RESULT_Y)
	_result_label.size = Vector2(600.0, 34.0)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.visible = false
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_label.add_theme_color_override("font_color", COLOR_NAME)
	_result_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_result_label.add_theme_constant_override("outline_size", 4)
	add_child(_result_label)


# === 动画播放 ===

## 播放一次完整的骰子投掷动画（协程，可 await，播完整轮后才返回）。
## d1/d2：定格点数；label：检定名称；outcome：成败标注（如"成功"/"失败"，可为空）。
## 时间轴：淡入 0.15s → 翻滚 2.0s → 定格复位 0.2s → 停留 0.9s → 淡出 0.25s。
func play(d1: int, d2: int, label: String, outcome: String) -> void:
	# 防重入：等待上一轮播放结束
	while _playing:
		await (Engine.get_main_loop() as SceneTree).process_frame
	_playing = true
	# --- 准备：设置文案、随机初始面、复位变换、淡入 ---
	_name_label.text = label
	_result_label.visible = false
	_reset_dice(_dice1, randi_range(1, 6))
	_reset_dice(_dice2, randi_range(1, 6))
	visible = true
	modulate.a = 0.0
	_kill_tween(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	await get_tree().create_timer(FADE_IN_DURATION).timeout
	# --- 翻滚：每步随机变面 + 随机晃动 ---
	var steps: int = int(ROLL_DURATION / ROLL_STEP)
	for i in steps:
		await get_tree().create_timer(ROLL_STEP).timeout
		_dice1.set_face(randi_range(1, 6))
		_dice2.set_face(randi_range(1, 6))
		_dice1.jiggle()
		_dice2.jiggle()
	# --- 定格：结果面 + 变换复位 + 结果文本 ---
	_dice1.set_face(d1)
	_dice2.set_face(d2)
	_kill_tween(_settle_tween)
	_settle_tween = create_tween()
	_settle_tween.set_parallel(true)
	_settle_tween.tween_property(_dice1, "rotation", 0.0, SETTLE_DURATION)
	_settle_tween.tween_property(_dice1, "position", _dice1.get_home_position(), SETTLE_DURATION)
	_settle_tween.tween_property(_dice2, "rotation", 0.0, SETTLE_DURATION)
	_settle_tween.tween_property(_dice2, "position", _dice2.get_home_position(), SETTLE_DURATION)
	_show_result(d1, d2, outcome)
	await get_tree().create_timer(SETTLE_DURATION).timeout
	# --- 定格停留 ---
	await get_tree().create_timer(HOLD_DURATION).timeout
	# --- 整体淡出并复位 ---
	_kill_tween(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	await get_tree().create_timer(FADE_OUT_DURATION).timeout
	visible = false
	_playing = false


# === 内部辅助 ===

## 复位单颗骰子变换（rotation/position）并显示指定面。
func _reset_dice(dice: DiceFace, face: int) -> void:
	dice.set_face(face)
	dice.rotation = 0.0
	dice.position = dice.get_home_position()


## 设置并显示结果文本：`d1 + d2 = 总和`，outcome 非空时追加；颜色按成败切换。
func _show_result(d1: int, d2: int, outcome: String) -> void:
	var text: String = str(d1) + " + " + str(d2) + " = " + str(d1 + d2)
	if outcome != "":
		text += "  " + outcome
	_result_label.text = text
	if outcome.contains("成功"):
		_result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	elif outcome.contains("失败"):
		_result_label.add_theme_color_override("font_color", COLOR_FAILURE)
	else:
		_result_label.add_theme_color_override("font_color", COLOR_NAME)
	_result_label.visible = true


## 终止旧 Tween（防泄漏）。
func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
