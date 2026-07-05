extends GutTest

# 测试 scripts/system/dice.gd / map_block.gd 与 player.gd 的 judge 系列。
# 覆盖 spec/iteration_05_judge.md §6.1-6.5 全部用例。


class _SpyPlayer extends Player:
	var draw_monster_calls: Array[int] = []
	func drawMonster(num: int) -> void:
		draw_monster_calls.append(num)


func _make_fixed_roller(value: int) -> Callable:
	return func() -> int: return value


func _make_counting_roller(values: Array[int]) -> Callable:
	var idx := [0]
	return func() -> int:
		var value := values[idx[0]]
		idx[0] += 1
		return value


# --- 6.1 judge ---

func test_judge_returns_value_in_2_to_12() -> void:
	var player := Player.new()
	for i in range(100):
		var result := player.judge()
		assert_true(result >= 2 and result <= 12, "judge() 第 %d 次结果 %d ∈ [2,12]" % [i, result])


func test_judge_can_return_extremes() -> void:
	var player := Player.new()
	player.set_dice_roller(_make_fixed_roller(2))
	assert_eq(player.judge(), 2, "注入骰子=2,judge 返回 2")
	player.set_dice_roller(_make_fixed_roller(12))
	assert_eq(player.judge(), 12, "注入骰子=12,judge 返回 12")


func test_judge_uses_roll_two_dice() -> void:
	var player := Player.new()
	var call_count := [0]
	player.set_dice_roller(func() -> int:
		call_count[0] += 1
		return 7)
	var result := player.judge()
	assert_eq(call_count[0], 1, "judge 调用 roller 一次")
	assert_eq(result, 7, "返回值 = roller 返回值")


# --- 6.2 sneakJudge ---

func test_sneakJudge_success_when_result_le_sneakValue() -> void:
	var player := Player.new()
	player.set_sneak(8)
	player.set_dice_roller(_make_fixed_roller(8))
	assert_true(player.sneakJudge(), "result=8 <= sneakValue=8 → true")


func test_sneakJudge_fail_when_result_gt_sneakValue() -> void:
	var player := Player.new()
	player.set_sneak(8)
	player.set_dice_roller(_make_fixed_roller(9))
	assert_false(player.sneakJudge(), "result=9 > sneakValue=8 → false")


func test_sneakJudge_reduces_by_monster_count() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	block.addMonsterMark(1)
	# stub countMonster:直接往 _monsters 加 2 个占位
	block._monsters.append("m1")
	block._monsters.append("m2")
	var player := Player.new()
	player.set_sneak(8)
	player.set_current_block(block)
	# sneakValue = 8 - (2 怪物 + 1 标记) = 5
	player.set_dice_roller(_make_fixed_roller(5))
	assert_true(player.sneakJudge(), "result=5 <= sneakValue=5 → true")
	player.set_dice_roller(_make_fixed_roller(6))
	assert_false(player.sneakJudge(), "result=6 > sneakValue=5 → false")


func test_sneakJudge_with_null_block_treats_as_zero() -> void:
	var player := Player.new()
	player.set_sneak(8)
	# get_current_block() = null(默认)
	player.set_dice_roller(_make_fixed_roller(8))
	assert_true(player.sneakJudge(), "null block 无减成,sneakValue=8,result=8 → true")


func test_sneakJudge_negative_sneakValue() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	for i in range(5):
		block._monsters.append("m%d" % i)
	var player := Player.new()
	player.set_sneak(2)
	player.set_current_block(block)
	# sneakValue = 2 - 5 = -3
	player.set_dice_roller(_make_fixed_roller(2))
	assert_false(player.sneakJudge(), "sneakValue=-3,result=2 > -3 → false")


# --- 6.3 monsterSpawnJudge ---

func test_monsterSpawnJudge_adds_mark_when_below_3() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	block.monster_spawn_value = 7
	block._monster_marks = 0
	var player := Player.new()
	player.set_dice_roller(_make_fixed_roller(7))
	player.monsterSpawnJudge([block])
	assert_eq(block.countMonsterMark(), 1, "countMonsterMark 0→1")


func test_monsterSpawnJudge_adds_mark_at_2() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	block.monster_spawn_value = 5
	block._monster_marks = 2
	var player := Player.new()
	player.set_dice_roller(_make_fixed_roller(5))
	player.monsterSpawnJudge([block])
	assert_eq(block.countMonsterMark(), 3, "countMonsterMark 2→3")


func test_monsterSpawnJudge_at_3_with_player_calls_drawMonster() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	block.monster_spawn_value = 6
	block._monster_marks = 3
	var spy := _SpyPlayer.new()
	spy.set_current_block(block)
	block.addPlayer(spy)
	spy.set_dice_roller(_make_fixed_roller(6))
	spy.monsterSpawnJudge([block])
	assert_eq(spy.draw_monster_calls.size(), 1, "drawMonster 被调用一次")
	assert_eq(spy.draw_monster_calls[0], 1, "n=1")


func test_monsterSpawnJudge_at_3_without_player_no_drawMonster() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	block.monster_spawn_value = 6
	block._monster_marks = 3
	# 不 addPlayer
	var spy := _SpyPlayer.new()
	spy.set_dice_roller(_make_fixed_roller(6))
	spy.monsterSpawnJudge([block])
	assert_eq(spy.draw_monster_calls.size(), 0, "无玩家时不调用 drawMonster")
	assert_eq(block.countMonsterMark(), 3, "标记不变(==3 不 +1)")


func test_monsterSpawnJudge_skips_non_matching_blocks() -> void:
	var block := MapBlock.new()
	block.set_revealed(true)
	block.monster_spawn_value = 5
	block._monster_marks = 0
	var player := Player.new()
	player.set_dice_roller(_make_fixed_roller(7))
	player.monsterSpawnJudge([block])
	assert_eq(block.countMonsterMark(), 0, "点数不匹配,不变")


func test_monsterSpawnJudge_skips_unrevealed_blocks() -> void:
	var block := MapBlock.new()
	# _revealed = false(默认)
	block.monster_spawn_value = 7
	block._monster_marks = 0
	var player := Player.new()
	player.set_dice_roller(_make_fixed_roller(7))
	player.monsterSpawnJudge([block])
	assert_eq(block.countMonsterMark(), 0, "未展示地块,不变")


func test_monsterSpawnJudge_multiple_matching_blocks() -> void:
	var b1 := MapBlock.new()
	b1.set_revealed(true)
	b1.monster_spawn_value = 8
	b1._monster_marks = 0
	var b2 := MapBlock.new()
	b2.set_revealed(true)
	b2.monster_spawn_value = 8
	b2._monster_marks = 1
	var player := Player.new()
	player.set_dice_roller(_make_fixed_roller(8))
	player.monsterSpawnJudge([b1, b2])
	assert_eq(b1.countMonsterMark(), 1, "b1 0→1")
	assert_eq(b2.countMonsterMark(), 2, "b2 1→2")


# --- 6.4 MapBlock stub ---

func test_map_block_countMonsterMark_default_0() -> void:
	var block := MapBlock.new()
	assert_eq(block.countMonsterMark(), 0, "默认 0")


func test_map_block_addMonsterMark_increases() -> void:
	var block := MapBlock.new()
	block.addMonsterMark(2)
	assert_eq(block.countMonsterMark(), 2, "+2")


func test_map_block_hasPlayer_default_false() -> void:
	var block := MapBlock.new()
	assert_false(block.hasPlayer(), "默认无玩家")


func test_map_block_addPlayer_then_has() -> void:
	var block := MapBlock.new()
	var player := Player.new()
	block.addPlayer(player)
	assert_true(block.hasPlayer(), "addPlayer 后 hasPlayer=true")


func test_map_block_is_revealed_default_false() -> void:
	var block := MapBlock.new()
	assert_false(block.is_revealed(), "默认未展示")


# --- 6.5 Player 集成 ---

func test_player_set_current_block() -> void:
	var player := Player.new()
	var block := MapBlock.new()
	player.set_current_block(block)
	assert_eq(player.get_current_block(), block, "set_current_block 后 get_current_block == block")
