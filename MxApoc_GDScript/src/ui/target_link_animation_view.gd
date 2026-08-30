class_name TargetLinkAnimationView
extends Control

## 目标确认演出：绘制 A→B 金色细线，再让 Stealth Arrow 沿线前进并淡出。
## 怪物目标会在画面中央临时显示与目标选择窗口相同样式的怪物牌。

const LINE_COLOR := Color(1.0, 0.84, 0.0, 1.0)
const LINE_WIDTH := 1.0
const LINE_HOLD_DURATION := 0.12
const ARROW_DURATION := 0.42
const FADE_DURATION := 0.18
const ARROW_HEAD_LENGTH := 34.0
const ARROW_HEAD_HALF_WIDTH := 18.0
const ARROW_SHAFT_LENGTH := 56.0
const ARROW_SHAFT_HALF_WIDTH := 8.0
const MONSTER_CARD_SIZE := Vector2(120.0, 180.0)
const MONSTER_CARD_GAP := 8.0
const CARD_ROW_MAX_WIDTH := 780.0

var _source_local := Vector2.ZERO
var _target_locals: Array[Vector2] = []
var _arrow_progress := 0.0:
	set(value):
		_arrow_progress = value
		queue_redraw()
var _playing := false
var _effect_tween: Tween = null
var _monster_cards: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	size = get_viewport_rect().size
	visible = false


## 播放目标确认动画。玩家目标逐一播放，怪物目标共享中央临时卡牌组并同步播放。
func play(source_position: Vector2, player_target_positions: Array[Vector2], monsters: Array) -> void:
	if _playing or source_position == Vector2.ZERO or not source_position.is_finite():
		return
	_playing = true
	visible = true
	modulate = Color.WHITE
	_source_local = _to_local(source_position)
	for target_position in player_target_positions:
		if target_position != Vector2.ZERO and target_position.is_finite():
			await _play_links([_to_local(target_position)])
	if not monsters.is_empty():
		var monster_targets := _build_monster_cards(monsters)
		await _play_links(monster_targets)
	_clear_monster_cards()
	visible = false
	_playing = false


## 同一批目标共用一条时间轴，确保多怪物箭头同时出现、移动与淡出。
func _play_links(target_positions: Array[Vector2]) -> void:
	_source_local = _source_local.clamp(Vector2.ZERO, size)
	_target_locals.clear()
	for target_position in target_positions:
		if target_position != Vector2.ZERO and target_position.is_finite():
			_target_locals.append(target_position.clamp(Vector2.ZERO, size))
	if _target_locals.is_empty():
		return
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
	draw_line(_source_local, target_local, LINE_COLOR, LINE_WIDTH, true)
	var direction := target_local - _source_local
	if direction.length_squared() < 1.0:
		return
	var forward := direction.normalized()
	var normal := Vector2(-forward.y, forward.x)
	# 初始帧的箭尾尖端固定在发起者角色牌中心；箭头整体随后沿线前进至目标。
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
	draw_colored_polygon(arrow_points, LINE_COLOR)


func _build_monster_cards(monsters: Array) -> Array[Vector2]:
	_clear_monster_cards()
	var centers: Array[Vector2] = []
	var count := monsters.size()
	var layout := calculate_monster_row_layout(count, size.x)
	var total_width: float = layout["total_width"]
	var step: float = layout["step"]
	var row_origin := Vector2(layout["origin_x"], (size.y - MONSTER_CARD_SIZE.y) * 0.5)
	for index in range(count):
		var monster: Variant = monsters[index]
		if monster == null or not is_instance_valid(monster) or not monster is Monster:
			continue
		var card_view := MonsterCardView.new(MONSTER_CARD_SIZE.x, MONSTER_CARD_SIZE.y)
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_view.z_index = -1  # Control 自身的 _draw 箭线/箭头保持在临时怪物牌之上
		card_view.set_monster(monster)
		card_view.position = row_origin + Vector2(step * index, 0.0)
		add_child(card_view)
		_monster_cards.append(card_view)
		centers.append(card_view.position + card_view.size * 0.5)
	return centers


## 计算怪物临时卡牌的水平布局；超出最大宽度时按手牌区规则重叠。
static func calculate_monster_row_layout(count: int, viewport_width: float) -> Dictionary:
	if count <= 0:
		return {"origin_x": viewport_width * 0.5, "step": 0.0, "total_width": 0.0}
	var total_width := count * MONSTER_CARD_SIZE.x + maxi(count - 1, 0) * MONSTER_CARD_GAP
	var step := MONSTER_CARD_SIZE.x + MONSTER_CARD_GAP
	if total_width > CARD_ROW_MAX_WIDTH and count > 1:
		step = (CARD_ROW_MAX_WIDTH - MONSTER_CARD_SIZE.x) / float(count - 1)
		total_width = MONSTER_CARD_SIZE.x + step * float(count - 1)
	return {
		"origin_x": (viewport_width - total_width) * 0.5,
		"step": step,
		"total_width": total_width,
	}


func _clear_monster_cards() -> void:
	for card in _monster_cards:
		if is_instance_valid(card):
			card.queue_free()
	_monster_cards.clear()


func _to_local(global_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_position


func _kill_effect_tween() -> void:
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
