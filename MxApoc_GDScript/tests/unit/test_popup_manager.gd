extends TestBase

## PopupManager 生命周期与卡牌视觉展示回归测试。

const GAME_SCENE := preload("res://scenes/GameScene2D.tscn")


func _make_popup_manager() -> Dictionary:
	var layer := CanvasLayer.new()
	add_child(layer)
	var manager := PopupManager.new()
	manager.setup(layer)
	layer.add_child(manager)
	return {"layer": layer, "manager": manager}


func _cleanup_popup_fixture(fixture: Dictionary) -> void:
	var layer: CanvasLayer = fixture["layer"]
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	await get_tree().process_frame


func test_card_preview_is_non_modal_and_replaced() -> void:
	var fixture := _make_popup_manager()
	var layer: CanvasLayer = fixture["layer"]
	var manager: PopupManager = fixture["manager"]

	manager.show_card_preview(_make_card("第一张"))
	await get_tree().process_frame
	assert_false(manager.is_popup_open(), "卡牌视觉展示不应占用交互弹窗状态")
	assert_eq(layer.get_child_count(), 2, "应只有 PopupManager 和一张卡牌展示")
	var first_preview: Control = manager._card_preview
	assert_not_null(first_preview)
	assert_eq(first_preview.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	manager.show_card_preview(_make_card("第二张"))
	await get_tree().process_frame
	assert_false(manager.is_popup_open(), "替换卡牌展示不应打开模态弹窗")
	assert_eq(layer.get_child_count(), 2, "替换后不应残留旧卡牌展示节点")
	assert_ne(manager._card_preview, first_preview, "新卡牌应替换旧卡牌")

	await _cleanup_popup_fixture(fixture)


func test_card_preview_does_not_replace_interactive_popup() -> void:
	var fixture := _make_popup_manager()
	var layer: CanvasLayer = fixture["layer"]
	var manager: PopupManager = fixture["manager"]

	manager.show_option_popup(["选项"], "请选择")
	await get_tree().process_frame
	var interactive_overlay: ColorRect = manager._popup_overlay
	assert_true(manager.is_popup_open())

	manager.show_card_preview(_make_card("展示牌"))
	await get_tree().process_frame
	assert_true(manager.is_popup_open(), "卡牌展示不应清除等待中的交互弹窗")
	assert_eq(manager._popup_overlay, interactive_overlay)
	assert_eq(layer.get_child_count(), 3, "应同时存在管理器、交互弹窗和非模态卡牌展示")

	manager._on_card_preview_hold_elapsed(
		manager._card_preview, manager._card_preview_generation)
	assert_true(manager.is_popup_open(), "卡牌展示自动关闭不能关闭交互弹窗")

	manager.close_popup()
	await _cleanup_popup_fixture(fixture)


func test_replacing_interactive_popup_does_not_leave_old_overlay() -> void:
	var fixture := _make_popup_manager()
	var layer: CanvasLayer = fixture["layer"]
	var manager: PopupManager = fixture["manager"]

	manager.show_option_popup(["旧弹窗"], "请选择")
	await get_tree().process_frame
	manager.show_block_select_popup([_make_block("新弹窗")], "请选择地块")
	await get_tree().process_frame
	assert_true(manager.is_popup_open())
	assert_eq(layer.get_child_count(), 2, "替换交互弹窗时不应残留旧遮罩")

	await _cleanup_popup_fixture(fixture)


func test_close_popup_removes_overlay_without_residual_blocker() -> void:
	var fixture := _make_popup_manager()
	var layer: CanvasLayer = fixture["layer"]
	var manager: PopupManager = fixture["manager"]
	var closed_events: Array = []
	manager.closed.connect(func() -> void: closed_events.append(true))

	manager.show_option_popup(["选项"], "请选择")
	await get_tree().process_frame
	assert_true(manager.is_popup_open())

	manager.close_popup()
	assert_false(manager.is_popup_open())
	assert_eq(closed_events.size(), 1, "显式关闭应只发出一次 closed")
	await get_tree().process_frame
	assert_eq(layer.get_child_count(), 1, "关闭后不应残留全屏遮罩")

	await _cleanup_popup_fixture(fixture)


func test_hosting_layer_is_above_popup_layer() -> void:
	var scene := GAME_SCENE.instantiate()
	var popup_layer: CanvasLayer = scene.get_node("PopupLayer")
	var hosting_layer: CanvasLayer = scene.get_node("HostingLayer")
	assert_gt(hosting_layer.layer, popup_layer.layer, "取消托管层必须高于普通弹窗层")
	scene.queue_free()
	await get_tree().process_frame
