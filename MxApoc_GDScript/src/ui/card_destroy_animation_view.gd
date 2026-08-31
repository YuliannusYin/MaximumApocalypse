class_name CardDestroyAnimationView
extends Control

## 卡牌移出游戏演出：居中展示卡面，随后碎裂并淡出消失。
## 纯代码构建；由 GameScene2D 挂载到 UI 层，并由 GUIPlayerInput 队列阻塞等待播放结束。

const FADE_IN_DURATION: float = 0.15
const HOLD_DURATION: float = 0.35
const DESTROY_DURATION: float = 0.45
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
func play(card: Card) -> void:
	if _playing or card == null or not is_instance_valid(card):
		return
	_playing = true
	_card.set_card(card)
	_reset()
	visible = true

	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	fade_in.tween_property(_card, "scale", Vector2.ONE * CARD_SCALE, FADE_IN_DURATION)
	await fade_in.finished

	await get_tree().create_timer(HOLD_DURATION).timeout

	_card.visible = false
	_build_shards(card)
	await _play_shatter()

	visible = false
	_playing = false


func _reset() -> void:
	modulate.a = 0.0
	_card.modulate = Color.WHITE
	_card.scale = Vector2.ONE * (CARD_SCALE * 0.88)
	_card.pivot_offset = Vector2(CardView.PANEL_W, CardView.PANEL_H) * 0.5
	_card.position = size * 0.5 - Vector2(CardView.PANEL_W, CardView.PANEL_H) * CARD_SCALE * 0.5
	_card.visible = true
	_shards.position = _card.position
	_shards.visible = false
	for child in _shards.get_children():
		child.queue_free()


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


func _play_shatter() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var center := _shards.size * 0.5
	for shard_index in range(_shards.get_child_count()):
		var shard: Control = _shards.get_child(shard_index)
		var direction := (shard.position + shard.size * 0.5 - center).normalized()
		var distance := 42.0 + float(shard_index % 3) * 16.0
		tween.tween_property(shard, "position", shard.position + direction * distance, DESTROY_DURATION)
		tween.tween_property(shard, "rotation", (float(shard_index) - 5.5) * 0.10, DESTROY_DURATION)
		tween.tween_property(shard, "modulate:a", 0.0, DESTROY_DURATION)
	await tween.finished
