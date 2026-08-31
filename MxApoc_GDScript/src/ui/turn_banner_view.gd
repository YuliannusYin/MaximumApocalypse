class_name TurnBannerView
extends Control

## 回合切换横幅组件（纯代码构建，无 .tscn）。
## 回合开始时画面中央显示「座位X XX的回合」金色大字横幅（黑描边，风格与骰子动画名称一致），
## 时间轴：淡入 0.2s → 停留 1.0s → 淡出 0.3s → 自动隐藏。
## 全程 mouse_filter 均为 IGNORE：不遮挡输入、不阻塞游戏流程（fire-and-forget）；
## 连续触发时新横幅替换旧的（kill 旧 Tween 后重新播放时间轴）。

# === 时间轴常量（秒） ===
const FADE_IN_DURATION: float = 0.2    # 淡入
const HOLD_DURATION: float = 1.0       # 停留
const FADE_OUT_DURATION: float = 0.3   # 淡出

# === 布局常量（视口约 1430x800，横幅以 (715, 330) 为中心——屏幕中央略偏上，避开手牌区） ===
const CENTER_X: float = 715.0
const CENTER_Y: float = 330.0
const BANNER_SIZE: Vector2 = Vector2(600.0, 60.0)

# === 样式常量 ===
const BANNER_COLOR: Color = Color(1.0, 0.85, 0.3)  # 金色大字（与骰子动画检定名称同色）
const BANNER_OUTLINE_SIZE: int = 6                 # 黑描边宽度

# === 成员变量 ===
var _label: Label
var _banner_tween: Tween = null


# === 生命周期 ===

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false


# === UI 构建 ===

## 纯代码构建中央大字 Label：以 (CENTER_X, CENTER_Y) 为中心、水平垂直居中对齐。
func _build_ui() -> void:
	_label = Label.new()
	_label.position = Vector2(CENTER_X - BANNER_SIZE.x * 0.5, CENTER_Y - BANNER_SIZE.y * 0.5)
	_label.size = BANNER_SIZE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", BANNER_COLOR)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", BANNER_OUTLINE_SIZE)
	add_child(_label)


# === 动画播放 ===

## 播放一次回合横幅：淡入 0.2s → 停留 1.0s → 淡出 0.3s → 隐藏。
## fire-and-forget（无 await，不阻塞调用方）；连续触发时旧时间轴被 kill，新横幅立即替换。
func play(text: String) -> void:
	_kill_banner_tween()
	_label.text = text
	visible = true
	modulate.a = 0.0
	# 单 Tween 链串联完整时间轴；Tween 由自身创建（自动绑定本节点），节点释放时自动失效
	_banner_tween = create_tween()
	_banner_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_banner_tween.tween_interval(HOLD_DURATION)
	_banner_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	_banner_tween.tween_callback(hide)


# === 内部辅助 ===

## 终止旧 Tween（防泄漏 / 连续触发时替换旧横幅时间轴）。
func _kill_banner_tween() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = null
