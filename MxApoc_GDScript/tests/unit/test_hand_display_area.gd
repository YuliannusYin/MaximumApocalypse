extends TestBase

## 手牌差量离场：打出优先于弃牌，避免 settlement/discard 连续刷新冲掉演出。


func test_queue_outgoing_kind_play_wins_over_discard() -> void:
	var area := HandDisplayArea.new()
	add_child_autofree(area)
	area.queue_outgoing_kind("discard")
	assert_eq(area._pending_out_kind, "discard")
	area.queue_outgoing_kind("play")
	assert_eq(area._pending_out_kind, "play", "play 应覆盖已排队的 discard")
	area.queue_outgoing_kind("discard")
	assert_eq(area._pending_out_kind, "play", "已排队 play 不被 discard 覆盖")


func test_diff_refresh_consumes_outgoing_kind() -> void:
	var area := HandDisplayArea.new()
	add_child_autofree(area)
	var player: Player = _make_player()
	var kept: Card = _make_card("留下")
	var gone: Card = _make_card("打出")
	player.hand = [kept, gone]
	area.set_player(player)
	await get_tree().process_frame
	assert_eq(area._card_views.size(), 2)
	area.queue_outgoing_kind("play")
	player.hand = [kept]
	area.refresh()
	assert_eq(area._pending_out_kind, "", "差量刷新后应消费离手种类")
	assert_eq(area._card_views.size(), 1)
