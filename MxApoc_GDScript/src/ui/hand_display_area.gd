class_name HandDisplayArea
extends Control

## 手牌显示区。
## 水平排列当前玩家的手牌。支持悬停上浮、单击选中。
## 选中状态由外部（game_scene_2d.gd 的确认按钮）驱动卡牌使用流程。

const AREA_X := 315
const AREA_Y := 620
const AREA_W := 800
const AREA_H := 150
const CARD_W := 110
const CARD_H := 150
const CARD_GAP := 8
const CARD_Y := 0.0  # 卡牌在手牌区内的 y 偏移（垂直居中）
# 差量刷新动画参数
const REPOSITION_DURATION := 0.2  # 保留卡平滑重排时长（秒）
const SLIDE_IN_DURATION := 0.25  # 新卡滑入时长（秒）
const SLIDE_OUT_DURATION := 0.25  # 消失卡滑出时长（秒）
const SLIDE_IN_OFFSET := Vector2(120, -30)  # 新卡滑入起点偏移（牌堆方向：右上外侧）
const SLIDE_OUT_OFFSET := Vector2(80, 40)  # 消失卡滑出偏移（弃牌堆方向：右下外侧）
const DIFF_MATCH_RATIO := 0.5  # 差量刷新最低匹配率，低于则降级全量重建

signal card_selected(card: Variant)
signal card_deselected()

var _player: Variant = null
var _card_views: Array = []
var _selected_view: CardView = null
var _is_stacked: bool = false
var _last_player_id: int = -1  # 上次刷新对应玩家的实例 id，玩家变化时降级全量重建


func _ready() -> void:
	position = Vector2(AREA_X, AREA_Y)
	size = Vector2(AREA_W, AREA_H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(_on_mouse_exited)


func _init() -> void:
	custom_minimum_size = Vector2(AREA_W, AREA_H)


## 设置当前玩家并刷新手牌显示。
func set_player(player: Variant) -> void:
	_player = player
	refresh()


## 刷新手牌区（差量实现：匹配保留 / 新建滑入 / 移除滑出 / 位置平滑重排）。
func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		_last_player_id = -1
		_clear_cards()
		return
	var hand: Array = _player.get("hand")
	var player_id: int = _player.get_instance_id()
	# 玩家切换（或首次刷新）时降级为全量重建
	if player_id != _last_player_id:
		_last_player_id = player_id
		_full_rebuild(hand)
		return
	# 既有卡匹配率过低时降级为全量重建，避免产生错误动画
	var existing := _build_existing_map()
	if not _can_diff_refresh(hand, existing):
		_full_rebuild(hand)
		return
	_diff_refresh(hand, existing)


## 按卡数计算目标位置（正常居中 / 超宽堆叠），同时维护 _is_stacked 标志。
func _compute_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		_is_stacked = false
		return positions
	# 计算总宽度（含间隔）
	var total_w: float = count * CARD_W + maxi(count - 1, 0) * CARD_GAP
	if total_w <= AREA_W:
		# 正常排列，居中
		_is_stacked = false
		var start_x: float = max((AREA_W - total_w) / 2.0, 0.0)
		for i in range(count):
			positions.append(Vector2(start_x + i * (CARD_W + CARD_GAP), CARD_Y))
	else:
		# 堆叠排列，从左开始
		_is_stacked = true
		var overlap: float = (float(count) * CARD_W - AREA_W) / float(maxi(count - 1, 1))
		var step: float = CARD_W - overlap
		for i in range(count):
			positions.append(Vector2(i * step, CARD_Y))
	return positions


## 构建既有卡视图映射（键：卡牌实例 id，值：CardView）。
func _build_existing_map() -> Dictionary:
	var existing := {}
	for view in _card_views:
		if view == null or not is_instance_valid(view):
			continue
		var card: Variant = view.get_card()
		if card == null or not is_instance_valid(card):
			continue
		existing[card.get_instance_id()] = view
	return existing


## 判断是否可走差量刷新：既有卡在新手牌中的匹配率需达标。
func _can_diff_refresh(hand: Array, existing: Dictionary) -> bool:
	if existing.is_empty():
		return true  # 无既有卡（如清空后重新抽牌），全部按新卡滑入
	var new_ids := {}
	for card in hand:
		if card != null and is_instance_valid(card):
			new_ids[card.get_instance_id()] = true
	var matched: int = 0
	for card_id in existing:
		if new_ids.has(card_id):
			matched += 1
	return float(matched) / float(existing.size()) >= DIFF_MATCH_RATIO


## 全量重建（降级路径：直接重建所有视图，无动画）。
func _full_rebuild(hand: Array) -> void:
	_clear_cards()
	var positions := _compute_positions(hand.size())
	for i in range(hand.size()):
		var card: Variant = hand[i]
		if card == null or not is_instance_valid(card):
			continue
		var view := CardView.new()
		add_child(view)
		view.set_card(card)
		view.set_hover_lift_enabled(true)
		view.set_base_position(positions[i])
		_card_views.append(view)


## 差量刷新：保留匹配卡并平滑重排、新卡从牌堆方向滑入、消失卡滑向弃牌堆方向淡出。
func _diff_refresh(hand: Array, existing: Dictionary) -> void:
	var positions := _compute_positions(hand.size())
	var new_views: Array = []
	var kept_ids := {}  # 保留视图的实例 id 集合
	for i in range(hand.size()):
		var card: Variant = hand[i]
		if card == null or not is_instance_valid(card):
			continue
		var card_id: int = card.get_instance_id()
		var view: CardView = existing.get(card_id)
		var target: Vector2 = positions[i]
		if view != null and is_instance_valid(view):
			# 保留的卡：更新数据与基点，位置变化时经统一通道平滑重排（选中卡保持上浮偏移）
			kept_ids[view.get_instance_id()] = true
			existing.erase(card_id)
			view.set_card(card)
			if view.get_base_position() != target:
				var tween_target: Vector2 = target
				if view.is_selected():
					tween_target = target + Vector2(0, -CardView.SELECTED_OFFSET)
				view.update_base_position(target)
				view.move_to(tween_target, REPOSITION_DURATION)
		else:
			# 新增的卡：从牌堆方向（右上外侧）滑入到位（位置走统一通道，淡入独立）
			view = CardView.new()
			add_child(view)
			view.set_card(card)
			view.set_hover_lift_enabled(true)
			view.update_base_position(target)
			view.position = target + SLIDE_IN_OFFSET
			view.modulate.a = 0.0
			view.move_to(target, SLIDE_IN_DURATION)
			var tw := view.create_tween()
			tw.tween_property(view, "modulate:a", 1.0, SLIDE_IN_DURATION)
		new_views.append(view)
	# 消失的卡：滑向弃牌堆方向（右下外侧）淡出后释放
	for view in _card_views:
		if view == null or not is_instance_valid(view):
			continue
		if kept_ids.has(view.get_instance_id()):
			continue
		_animate_card_out(view)
	_card_views = new_views
	# 按新手牌顺序重排子节点，保证堆叠重叠时遮挡顺序与手牌一致
	for i in range(new_views.size()):
		var ordered: CardView = new_views[i]
		move_child(ordered, i)
	# 选中卡被移除时清空选中并发信号
	if _selected_view == null or not is_instance_valid(_selected_view):
		_selected_view = null
	elif not kept_ids.has(_selected_view.get_instance_id()):
		clear_selection()


## 消失卡滑出动画：滑向弃牌堆方向（右下外侧）淡出后释放。
func _animate_card_out(view: CardView) -> void:
	# 禁用悬停上浮以终止其内部动画，避免与滑出 Tween 冲突
	view.set_hover_lift_enabled(false)
	var tw := view.create_tween()
	tw.set_parallel(true)
	tw.tween_property(view, "position", view.position + SLIDE_OUT_OFFSET, SLIDE_OUT_DURATION)
	tw.tween_property(view, "modulate:a", 0.0, SLIDE_OUT_DURATION)
	var free_cb := func() -> void:
		if view != null and is_instance_valid(view):
			view.queue_free()
	tw.chain().tween_callback(free_cb)


## 清除选中状态。
func clear_selection() -> void:
	if _selected_view != null and is_instance_valid(_selected_view):
		_selected_view.set_selected(false)
		_selected_view = null
		card_deselected.emit()


# === 鼠标交互 ===

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)
	elif event is InputEventMouseMotion:
		_update_hover(event.position)


## 鼠标移出手牌区：清除所有卡牌的悬停状态（修复移出后保持放大的问题）。
func _on_mouse_exited() -> void:
	for view in _card_views:
		if view == null or not is_instance_valid(view):
			continue
		view.set_hovered(false)


# === 悬停/点击 ===

func _update_hover(local_pos: Vector2) -> void:
	var hovered := _find_card_at(local_pos)
	for view in _card_views:
		if view == null or not is_instance_valid(view):
			continue
		view.set_hovered(view == hovered)


func _handle_click(local_pos: Vector2) -> void:
	var view := _find_card_at(local_pos)
	if view == null:
		# Click empty space - deselect
		if _selected_view != null and is_instance_valid(_selected_view):
			_selected_view.set_selected(false)
			_selected_view = null
			card_deselected.emit()
		return
	if _selected_view == view:
		return  # Already selected
	if _selected_view != null and is_instance_valid(_selected_view):
		_selected_view.set_selected(false)
	_selected_view = view
	view.set_selected(true)
	card_selected.emit(view.get_card())


# === 工具方法 ===

func _find_card_at(local_pos: Vector2) -> CardView:
	for i in range(_card_views.size() - 1, -1, -1):
		var view: CardView = _card_views[i]
		if view == null or not is_instance_valid(view):
			continue
		var rect := Rect2(view.position, Vector2(CARD_W, CARD_H))
		if rect.has_point(local_pos):
			return view
	return null


func _clear_cards() -> void:
	for view in _card_views:
		if view != null and is_instance_valid(view):
			view.queue_free()
	_card_views.clear()
	_selected_view = null
