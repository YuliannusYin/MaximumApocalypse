class_name MonsterSkillTriggerAnimationView
extends Control

## 怪物技能"触发"动画组件（纯代码构建，无 .tscn）。
## 全屏覆盖层（无背景遮罩）：屏幕中央临时显示一张与目标选择窗口
## 相同样式的怪物牌（共享组件 MonsterCardView，120×180），
## 先瞬间弹放制造打击感，再缩小淡出消失。
## 用法：实例化后加入 CanvasLayer，await play(monster) 播放完整动画。
## 卡牌只建一次，播完复位复用，不销毁。
## 所有节点 mouse_filter 均为 IGNORE，播放期间不遮挡其他 UI 点击。

# === 时间轴常量（秒），总时长约 0.47s ===
const IMPACT_DURATION: float = 0.12     # 突然放大（打击感）
const FADE_OUT_DURATION: float = 0.35   # 缩小 + 淡出
const IMPACT_END_SCALE: float = 1.4     # 打击段结束时的缩放
const FADE_OUT_END_SCALE: float = 0.6   # 消散段结束时的缩放

# === 布局常量（怪物牌与目标选择窗口同款尺寸） ===
const MONSTER_CARD_SIZE := Vector2(120.0, 180.0)

# === 成员变量 ===
var _card_view: MonsterCardView
var _playing: bool = false
var _impact_tween: Tween = null
var _fade_out_tween: Tween = null


# === 生命周期 ===

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 父为 CanvasLayer 时锚点可能不生效，先设全屏锚点再按视口尺寸显式铺满
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_build_ui()
	visible = false


# === UI 构建 ===

## 纯代码构建：仅一张居中怪物牌（无背景遮罩），实例只建一次、播放后复位复用。
func _build_ui() -> void:
	_card_view = MonsterCardView.new(MONSTER_CARD_SIZE.x, MONSTER_CARD_SIZE.y)
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# pivot 设为卡牌中心，缩放动画以中心为原点
	_card_view.pivot_offset = _card_view.size * 0.5
	# 卡牌中心对准视口中心
	_card_view.position = (size - _card_view.size) * 0.5
	add_child(_card_view)


# === 动画播放 ===

## 播放一次"触发怪物技能"动画（协程，可 await，播完整轮后才返回）。
## monster：要展示的 Monster 实例（无效或非 Monster 直接返回，不播）。
## 时间轴：scale 1.0 立即显示 → 突然放大至 1.4（0.12s，TRANS_BACK + EASE_OUT 打击感）
## → 并行缩小至 0.6 与淡出至 0（0.35s）→ 隐藏并复位，总时长约 0.47s。
func play(monster: Variant) -> void:
	# 防重入：播放中再次调用直接返回
	if _playing:
		return
	# 参数校验：仅接受有效的 Monster 实例
	if monster == null or not is_instance_valid(monster) or not monster is Monster:
		return
	_playing = true
	# --- 准备：填充怪物数据、复位卡牌、立即以原尺寸显示 ---
	_card_view.set_monster(monster)
	_reset_card()
	visible = true
	# --- 打击：突然放大（TRANS_BACK + EASE_OUT 制造冲击感） ---
	_kill_tween(_impact_tween)
	_impact_tween = create_tween()
	_impact_tween.tween_property(_card_view, "scale", Vector2.ONE * IMPACT_END_SCALE, IMPACT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _impact_tween.finished
	# --- 消散：并行缩小 + 淡出 ---
	_kill_tween(_fade_out_tween)
	_fade_out_tween = create_tween()
	_fade_out_tween.set_parallel(true)
	_fade_out_tween.tween_property(_card_view, "scale", Vector2.ONE * FADE_OUT_END_SCALE, FADE_OUT_DURATION)
	_fade_out_tween.tween_property(_card_view, "modulate:a", 0.0, FADE_OUT_DURATION)
	await _fade_out_tween.finished
	# --- 收尾：隐藏自身并复位卡牌（保留复用，不销毁） ---
	visible = false
	_reset_card()
	_playing = false


# === 内部辅助 ===

## 复位卡牌状态（缩放 / 透明度），供下次播放。
func _reset_card() -> void:
	_card_view.scale = Vector2.ONE
	_card_view.modulate.a = 1.0


## 终止旧 Tween（防泄漏）。
func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
