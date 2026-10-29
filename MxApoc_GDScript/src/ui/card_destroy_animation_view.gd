class_name CardDestroyAnimationView
extends Control

## 卡牌移出游戏演出：居中展示卡面，随后碎裂并淡出消失。
## 纯代码构建；由 GameScene2D 挂载到 UI 层，并由 GUIPlayerInput 队列阻塞等待播放结束。

const FADE_IN_DURATION: float = 0.12
const HOLD_DURATION: float = 0.28
const DESTROY_DURATION: float = 0.38
const CARD_SCALE: float = 1.5

var _background: ColorRect
var _card: CardView
var _shards: Control
var _playing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = Color(0.0, 0.0, 0.0, 0.35)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_card = CardView.new()
	_card.scale = Vector2.ONE * CARD_SCALE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	_shards = Control.new()
	_shards.size = Vector2(CardView.PANEL_W, CardView.PANEL_H)
	_shards.pivot_offset = _shards.size * 0.5
	_shards.scale = Vector2.ONE * CARD_SCALE
	_shards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shards)


## 播放居中卡牌焚毁动画；调用方可 await 本方法以阻塞后续结算。
## GAME_EVENT 与 INPUT_REQUEST 可能同时触发：已在播时只等待当前轮结束，不重播。
func is_playing() -> bool:
	return _playing


func play(card: Card) -> void:
	if _playing:
		await _await_current_play()
		return
	if card == null or not is_instance_valid(card):
		return
	_playing = true
	_card.set_card(card)
	_reset()
	var fade_in_duration := Settings.get_animation_duration(FADE_IN_DURATION)
	var hold_duration := Settings.get_animation_duration(HOLD_DURATION)
	var destroy_duration := Settings.get_animation_duration(DESTROY_DURATION)
	if fade_in_duration <= 0.0:
		_finish_play()
		return
	visible = true

	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	fade_in.tween_property(_card, "scale", Vector2.ONE * CARD_SCALE, fade_in_duration)
	await fade_in.finished

	await get_tree().create_timer(hold_duration).timeout

	_card.visible = false
	_build_shards(card)
	await _play_shatter(destroy_duration)

	_finish_play()


func _await_current_play() -> void:
	while _playing:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		await tree.process_frame


func _reset() -> void:
	modulate.a = 0.0
	_card.modulate = Color.WHITE
	_card.scale = Vector2.ONE * (CARD_SCALE * 0.88)
	_card.pivot_offset = Vector2(CardView.PANEL_W, CardView.PANEL_H) * 0.5
	_card.position = _viewport_center_local() \
		- Vector2(CardView.PANEL_W, CardView.PANEL_H) * 0.5
	_card.visible = true
	_shards.position = _card.position
	_shards.visible = false
	_clear_shards()


## 将完整卡面裁成 3×4 个碎片，分别飞散并淡出，形成真实碎裂的视觉效果。
func _build_shards(card: Card) -> void:
	const COLUMNS := 3
	const ROWS := 4
	var shard_size := Vector2(float(CardView.PANEL_W) / COLUMNS, float(CardView.PANEL_H) / ROWS)
	for row in range(ROWS):
		for column in range(COLUMNS):
			var shard := Control.new()
			shard.position = Vector2(column * shard_size.x, row * shard_size.y)
			shard.size = shard_size
			shard.clip_contents = true
			shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var shard_card := CardView.new()
			shard_card.set_card(card)
			shard_card.position = -shard.position
			shard_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shard.add_child(shard_card)
			_shards.add_child(shard)
	_shards.visible = true


func _play_shatter(duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var center := _shards.size * 0.5
	for shard_index in range(_shards.get_child_count()):
		var shard: Control = _shards.get_child(shard_index)
		var direction := (shard.position + shard.size * 0.5 - center).normalized()
		var distance := 42.0 + float(shard_index % 3) * 16.0
		tween.tween_property(shard, "position", shard.position + direction * distance, duration)
		tween.tween_property(shard, "rotation", (float(shard_index) - 5.5) * 0.10, duration)
		tween.tween_property(shard, "modulate:a", 0.0, duration)
	await tween.finished


func _viewport_center_local() -> Vector2:
	var viewport_center := get_viewport_rect().size * 0.5
	return get_global_transform().affine_inverse() * viewport_center


func _clear_shards() -> void:
	for child in _shards.get_children():
		_shards.remove_child(child)
		child.queue_free()


## 隐藏并清理到最终状态；关闭动画时立即走此路径。
func _finish_play() -> void:
	visible = false
	modulate.a = 1.0
	_card.visible = true
	_shards.visible = false
	_clear_shards()
	_playing = false
