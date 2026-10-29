class_name CardMotionAnimationView
extends Control

## 轻量卡牌轨迹层。始终使用临时 CardView，避免手牌刷新释放源节点后中断演出。

const DEFAULT_CARD_SIZE := Vector2(CardView.PANEL_W, CardView.PANEL_H)

var _active_count: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func is_playing() -> bool:
	return _active_count > 0


func get_active_count() -> int:
	return _active_count


func play(card: Variant, from_rect: Rect2, to_rect: Rect2,
		base_duration: float = 0.24, fade_out: bool = false,
		delay: float = 0.0) -> void:
	if card == null or (not card is Dictionary and not is_instance_valid(card)):
		return
	if from_rect.size == Vector2.ZERO:
		from_rect = Rect2(to_rect.get_center() - DEFAULT_CARD_SIZE * 0.25,
			DEFAULT_CARD_SIZE * 0.5)
	if to_rect.size == Vector2.ZERO:
		to_rect = Rect2(from_rect.get_center() - DEFAULT_CARD_SIZE * 0.5,
			DEFAULT_CARD_SIZE)
	var duration := _scaled_duration(base_duration)
	if delay > 0.0 and duration > 0.0:
		await get_tree().create_timer(_scaled_duration(delay)).timeout

	var ghost := CardView.new()
	add_child(ghost)
	ghost.set_card(card)
	ghost.set_hover_lift_enabled(false)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.pivot_offset = DEFAULT_CARD_SIZE * 0.5
	var start_center := from_rect.get_center()
	var end_center := to_rect.get_center()
	var start_scale := _rect_scale(from_rect)
	var end_scale := _rect_scale(to_rect)
	ghost.position = start_center - DEFAULT_CARD_SIZE * 0.5
	ghost.scale = Vector2.ONE * start_scale
	ghost.z_index = 100
	_active_count += 1

	if duration <= 0.0:
		ghost.position = end_center - DEFAULT_CARD_SIZE * 0.5
		ghost.scale = Vector2.ONE * end_scale
		ghost.queue_free()
		_active_count -= 1
		return

	var control_point := (start_center + end_center) * 0.5
	control_point.y -= clampf(absf(end_center.x - start_center.x) * 0.08 + 55.0, 55.0, 120.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_method(func(progress: float) -> void:
		if not is_instance_valid(ghost):
			return
		var inv := 1.0 - progress
		var center := inv * inv * start_center \
			+ 2.0 * inv * progress * control_point \
			+ progress * progress * end_center
		ghost.position = center - DEFAULT_CARD_SIZE * 0.5
		ghost.scale = Vector2.ONE * lerpf(start_scale, end_scale, progress),
		0.0, 1.0, duration)
	tween.tween_property(ghost, "rotation", 0.035, duration * 0.45)
	if fade_out:
		tween.tween_property(ghost, "modulate:a", 0.0, duration * 0.75) \
			.set_delay(duration * 0.25)
	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	_active_count -= 1


func _rect_scale(rect: Rect2) -> float:
	if rect.size == Vector2.ZERO:
		return 1.0
	return maxf(minf(rect.size.x / DEFAULT_CARD_SIZE.x,
		rect.size.y / DEFAULT_CARD_SIZE.y), 0.15)


func _scaled_duration(base_duration: float) -> float:
	if Settings != null and Settings.has_method("get_animation_duration"):
		return float(Settings.get_animation_duration(base_duration))
	return base_duration
