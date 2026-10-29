extends TestBase

## 手牌交互回归：中心缩放、视觉命中、选择清理、双击与差量移除。

var _previous_animation_speed: int


func before_each() -> void:
	super.before_each()
	_previous_animation_speed = Settings.animation_speed
	Settings.animation_speed = Settings.AnimationSpeed.STANDARD


func after_each() -> void:
	Settings.animation_speed = _previous_animation_speed
	super.after_each()


func _make_area_with_cards(cards: Array) -> HandDisplayArea:
	var player := _make_player()
	player.hand = cards
	var area := HandDisplayArea.new()
	add_child_autofree(area)
	area.set_player(player)
	return area


func test_hover_uses_center_pivot_and_visual_rect() -> void:
	var card := _make_card("悬停牌")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	var view := area.get_card_view(card)
	assert_eq(view.pivot_offset, view.size * 0.5)
	view.set_hovered(true)
	await get_tree().create_timer(CardView.HOVER_DURATION + 0.03).timeout
	assert_almost_eq(view.scale.x, CardView.HOVER_SCALE.x, 0.01)
	var rect := view.get_visual_rect()
	assert_true(rect.size.x > view.size.x, "视觉命中框应包含放大后的尺寸")
	assert_eq(area._find_card_at(rect.get_center()), view)


func test_select_after_hover_restores_unit_scale() -> void:
	var card := _make_card("选中牌")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	var view := area.get_card_view(card)
	view.set_hovered(true)
	await get_tree().create_timer(CardView.HOVER_DURATION + 0.02).timeout
	view.set_selected(true)
	await get_tree().create_timer(CardView.HOVER_DURATION + 0.02).timeout
	assert_almost_eq(view.scale.x, 1.0, 0.01, "选中态不能残留 hover 放大")


func test_last_card_uses_diff_removal_and_clears_selection() -> void:
	var card := _make_card("最后一张")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	watch_signals(area)
	area._handle_click(area.get_card_view(card).get_visual_rect().get_center())
	area._player.hand.clear()
	area.refresh()
	assert_eq(area._card_views.size(), 0)
	assert_signal_emitted(area, "card_deselected")
	await get_tree().create_timer(HandDisplayArea.SLIDE_OUT_DURATION + 0.05).timeout


func test_double_click_selects_and_emits_card() -> void:
	var card := _make_card("双击牌")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	watch_signals(area)
	var point := area.get_card_view(card).get_visual_rect().get_center()
	area._handle_double_click(point)
	assert_eq(area._selected_view.get_card(), card)
	assert_signal_emitted_with_parameters(area, "card_double_clicked", [card])


func test_availability_provider_dims_but_keeps_hit_testing() -> void:
	var card := _make_card("不可用牌")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	area.set_availability_provider(func(_card: Variant) -> Dictionary:
		return {"usable": false, "reason": "行动点不足"})
	var view := area.get_card_view(card)
	assert_false(view.is_usable())
	assert_eq(view.get_unusable_reason(), "行动点不足")
	assert_eq(area._find_card_at(view.get_visual_rect().get_center()), view)


func test_hidden_motion_source_cannot_be_clicked() -> void:
	var card := _make_card("飞行中的牌")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	var view := area.get_card_view(card)
	var point := view.get_visual_rect().get_center()
	area.set_card_visual_hidden(card, true)
	assert_null(area._find_card_at(point), "隐藏源卡不能在动画请求期间继续响应双击")


func test_hover_lift_stays_inside_hand_area() -> void:
	var card := _make_card("上浮边界")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	var view := area.get_card_view(card)
	view.set_hovered(true)
	await get_tree().create_timer(CardView.HOVER_DURATION + 0.03).timeout
	var rect := view.get_visual_rect()
	assert_true(rect.position.y >= 0.0, "悬停上浮不能越过手牌区上沿")
	assert_true(rect.end.y <= HandDisplayArea.AREA_H + 0.5, "悬停放大后仍应落在手牌区内")


func test_stacked_overlap_hits_rightmost_card() -> void:
	var cards: Array = []
	for index in range(8):
		cards.append(_make_card("堆叠%d" % index))
	var area := _make_area_with_cards(cards)
	await get_tree().process_frame
	assert_true(area._is_stacked)
	var left := area.get_card_view(cards[0])
	var right := area.get_card_view(cards[1])
	var overlap_x: float = right.get_base_position().x + 4.0
	var point := Vector2(overlap_x, HandDisplayArea.CARD_Y + 40.0)
	assert_true(left.get_visual_rect().has_point(point))
	assert_true(right.get_visual_rect().has_point(point))
	assert_eq(area._find_card_at(point), right, "重叠命中应优先右侧更靠上的牌")


func test_double_click_unusable_card_still_selects() -> void:
	var card := _make_card("非法双击")
	var area := _make_area_with_cards([card])
	await get_tree().process_frame
	area.set_availability_provider(func(_card: Variant) -> Dictionary:
		return {"usable": false, "reason": "当前条件不满足"})
	watch_signals(area)
	var view := area.get_card_view(card)
	area._handle_double_click(view.get_visual_rect().get_center())
	assert_eq(area._selected_view, view, "不可用牌仍应能选中查看")
	assert_signal_emitted_with_parameters(area, "card_double_clicked", [card])
	assert_false(view.is_usable())


func test_consecutive_draws_keep_existing_views_and_slide_in() -> void:
	var first := _make_card("原有手牌")
	var second := _make_card("连抽第一张")
	var third := _make_card("连抽第二张")
	var area := _make_area_with_cards([first])
	await get_tree().process_frame
	var first_view := area.get_card_view(first)
	area._player.hand.append(second)
	area.refresh()
	var second_view := area.get_card_view(second)
	assert_eq(area.get_card_view(first), first_view, "连抽不应重建已有手牌视图")
	assert_not_null(second_view)
	assert_almost_eq(
		second_view.position.x,
		second_view.get_base_position().x + HandDisplayArea.SLIDE_IN_OFFSET.x,
		1.0,
		"新抽入的牌应从牌堆方向滑入，而不是瞬移到位")
	area._player.hand.append(third)
	area.refresh()
	assert_eq(area.get_card_view(first), first_view)
	assert_eq(area.get_card_view(second), second_view)
	assert_not_null(area.get_card_view(third))
	assert_eq(area._card_views.size(), 3)
