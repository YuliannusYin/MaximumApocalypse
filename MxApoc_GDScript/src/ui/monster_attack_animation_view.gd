class_name MonsterAttackAnimationView
extends Control

## 怪物攻击演出：居中怪物牌 + 血红色箭头射向目标玩家角色牌，多目标同时播放。

const ARROW_COLOR := Color(0.78, 0.08, 0.15, 1.0)
const LINE_WIDTH := 1.0
const LINE_HOLD_DURATION := 0.12
const ARROW_DURATION := 0.42
const FADE_DURATION := 0.18
const ARROW_HEAD_LENGTH := 34.0
const ARROW_HEAD_HALF_WIDTH := 18.0
const ARROW_SHAFT_LENGTH := 56.0
const ARROW_SHAFT_HALF_WIDTH := 8.0
const MONSTER_CARD_SIZE := Vector2(120.0, 180.0)

var _source_local := Vector2.ZERO
var _target_locals: Array[Vector2] = []
var _arrow_progress := 0.0:
	set(value):
		_arrow_progress = value
		queue_redraw()
var _playing := false
var _effect_tween: Tween = null
var _monster_card: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	size = get_viewport_rect().size
	visible = false


## 播放怪物攻击动画：中央怪物牌同时向多个目标射出箭头，全部箭头共享一条时间轴。
func play(monster: Variant, target_positions: Array) -> void:
	if _playing:
		return
	if monster == null or not is_instance_valid(monster) or not monster is Monster:
		return
	# 收集有效目标：全局坐标转局部坐标并夹在视口范围内。
	_target_locals.clear()
	for target_position in target_positions:
		if target_position != Vector2.ZERO and target_position.is_finite():
			_target_locals.append(_to_local(target_position).clamp(Vector2.ZERO, size))
	if _target_locals.is_empty():
		return
	_playing = true
	visible = true
	modulate = Color.WHITE
	_source_local = _build_monster_card(monster)
	await _play_links()
	_clear_monster_card()
	visible = false
	_playing = false


## 所有箭头共享同一条时间轴与同一个进度值，确保多目标同时出现、移动与淡出。
func _play_links() -> void:
	_arrow_progress = 0.0
	queue_redraw()
	await get_tree().create_timer(LINE_HOLD_DURATION).timeout
	_kill_effect_tween()
	_effect_tween = create_tween()
	_effect_tween.tween_property(self, "_arrow_progress", 1.0, ARROW_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _effect_tween.finished
	_effect_tween = create_tween()
	_effect_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await _effect_tween.finished
	modulate.a = 1.0
	_arrow_progress = 0.0
	queue_redraw()


func _draw() -> void:
	if not _playing or _target_locals.is_empty():
		return
	for target_local in _target_locals:
		_draw_link(target_local)


func _draw_link(target_local: Vector2) -> void:
	draw_line(_source_local, target_local, ARROW_COLOR, LINE_WIDTH, true)
	var direction := target_local - _source_local
	if direction.length_squared() < 1.0:
		return
	var forward := direction.normalized()
	var normal := Vector2(-forward.y, forward.x)
	# 初始帧的箭尾尖端固定在中央怪物牌中心；箭头整体随后沿线前进至目标。
	var arrow_length := ARROW_HEAD_LENGTH + ARROW_SHAFT_LENGTH
	var arrow_scale := minf(1.0, direction.length() / arrow_length)
	var start_tip := _source_local + forward * arrow_length * arrow_scale
	var tip := start_tip.lerp(target_local, _arrow_progress)
	var head_base := tip - forward * ARROW_HEAD_LENGTH * arrow_scale
	var tail_tip := head_base - forward * ARROW_SHAFT_LENGTH * arrow_scale
	# 头部和箭杆共用边界，构成与参考图一致的连续箭形；
	# 箭杆由头部根部平滑收窄至尖尾，始终绘制在怪物牌的上方。
	var arrow_points := PackedVector2Array([
		tail_tip,
		head_base + normal * ARROW_SHAFT_HALF_WIDTH * arrow_scale,
		head_base + normal * ARROW_HEAD_HALF_WIDTH * arrow_scale,
		tip,
		head_base - normal * ARROW_HEAD_HALF_WIDTH * arrow_scale,
		head_base - normal * ARROW_SHAFT_HALF_WIDTH * arrow_scale,
	])
	draw_colored_polygon(arrow_points, ARROW_COLOR)


## 在视口中央创建一张临时怪物牌，返回其中心点作为所有箭头的共同源点。
func _build_monster_card(monster: Monster) -> Vector2:
	_clear_monster_card()
	var card_view := MonsterCardView.new(MONSTER_CARD_SIZE.x, MONSTER_CARD_SIZE.y)
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view.z_index = -1  # Control 自身的 _draw 箭线/箭头保持在临时怪物牌之上
	card_view.set_monster(monster)
	card_view.position = size * 0.5 - card_view.size * 0.5
	add_child(card_view)
	_monster_card = card_view
	return card_view.position + card_view.size * 0.5


func _clear_monster_card() -> void:
	if _monster_card != null and is_instance_valid(_monster_card):
		_monster_card.queue_free()
	_monster_card = null


func _to_local(global_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_position


func _kill_effect_tween() -> void:
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
