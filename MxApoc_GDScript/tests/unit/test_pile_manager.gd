extends TestBase

## 个人牌堆计数跟 display 座位；未设置 display 时回退 acting（单机热座）。


func _make_seat(player_name: String, deck_n: int, discard_n: int) -> Player:
	var player: Player = _make_player(player_name)
	for i in range(deck_n):
		player.game_deck.add(_make_card("%s_deck_%d" % [player_name, i]))
	for i in range(discard_n):
		player.game_discard_pile.add(_make_card("%s_discard_%d" % [player_name, i]))
	return player


func test_personal_pile_counts_follow_acting_without_display() -> void:
	var manager := PileManager.new()
	add_child_autofree(manager)
	var acting: Player = _make_seat("Acting", 3, 1)
	manager.set_acting_player(acting)
	assert_eq(manager._get_current_player_deck_count(), 3, "未设 display 时应跟 acting 牌堆")
	assert_eq(manager._get_current_player_discard_count(), 1, "未设 display 时应跟 acting 弃牌")
	assert_eq(manager._get_display_player(), acting)


func test_personal_pile_counts_follow_display_not_acting() -> void:
	var manager := PileManager.new()
	add_child_autofree(manager)
	var acting: Player = _make_seat("TurnSeat", 5, 2)
	var local_seat: Player = _make_seat("LocalSeat", 1, 7)
	manager.set_acting_player(acting)
	manager.set_display_player(local_seat)
	assert_eq(manager._get_current_player_deck_count(), 1, "联机个人牌堆应显示本机座位")
	assert_eq(manager._get_current_player_discard_count(), 7, "联机角色弃牌应显示本机座位")
	assert_eq(manager._get_acting_player(), acting, "操作座位仍是回合/行动座位")
	assert_eq(manager._get_display_player(), local_seat)


func test_play_draw_pulse_without_wired_panels_is_safe() -> void:
	var manager := PileManager.new()
	add_child_autofree(manager)
	manager.play_draw_pulse("game_deck")
	manager.play_draw_pulse("")
	assert_true(manager._pile_tweens.is_empty(), "未接线牌堆不应创建脉冲 Tween")
