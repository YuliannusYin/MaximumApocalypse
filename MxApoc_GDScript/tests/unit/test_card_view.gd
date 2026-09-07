extends TestBase

## CardView 区域标签：进树前 set_zone_label 必须在 _ready 后生效。


func test_set_zone_label_before_enter_tree_is_applied() -> void:
	var view := CardView.new()
	var card := Card.new()
	card.card_name = "砍刀"
	view.set_card(card)
	view.set_zone_label("装备区")
	add_child_autofree(view)
	await get_tree().process_frame
	assert_not_null(view._zone_label, "进树后应已创建区域标签")
	assert_eq(view._zone_label.text, "装备区", "进树前设置的区域文本应保留")
	assert_true(view._zone_label.visible, "非空区域标签应显示")


func test_set_zone_label_after_enter_tree_is_applied() -> void:
	var view := CardView.new()
	var card := Card.new()
	card.card_name = "砍刀"
	view.set_card(card)
	add_child_autofree(view)
	await get_tree().process_frame
	view.set_zone_label("手牌区")
	assert_eq(view._zone_label.text, "手牌区")
	assert_true(view._zone_label.visible)


func test_empty_zone_label_is_hidden() -> void:
	var view := CardView.new()
	var card := Card.new()
	card.card_name = "砍刀"
	view.set_card(card)
	view.set_zone_label("装备区")
	add_child_autofree(view)
	await get_tree().process_frame
	assert_true(view._zone_label.visible)
	view.set_zone_label("")
	assert_false(view._zone_label.visible, "空文本应隐藏区域标签")
