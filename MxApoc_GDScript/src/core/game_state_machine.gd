class_name GameStateMachine
extends RefCounted

## 游戏状态机。
## 职责：游戏级状态管理、回合队列管理、胜利/失败条件检查。
## 独立类，不继承 Entity（无技能、无 trigger），由 Game 持有。
## 设计文档：GameDesignDocus/GameSystem/Core/GameStateMachine.md

# === 枚举 ===

enum GameState { WAITING, PLAYING, GAME_OVER }
enum GameResult { WIN, LOSE }

# === 字段 ===

## 当前游戏状态。
var current_state: int = GameState.WAITING

## 游戏结果。-1 表示未结束（NULL）。
var game_result: int = -1

## 当前回合玩家。
var current_player: Variant = null

## 回合队列。队首为下一个行动玩家。包含标准回合与额外回合。
var turn_queue: Array = []

## 跳过标记。键 = 玩家，值 = true。跳过是一次性的，执行后移除。
var skip_turn_marks: Dictionary = {}

## 当前轮数。所有玩家各执行一次为一轮。从 0 开始，首次填充队列时 +1。
var turn_number: int = 0


# === 初始化 ===

## 初始化状态机。在游戏初始化完成后、start_game() 前调用。
func init() -> void:
	current_state = GameState.WAITING
	game_result = -1
	current_player = null
	turn_queue.clear()
	skip_turn_marks.clear()
	turn_number = 0


# === 状态转换 ===

## 状态转换（带合法性校验）。非法转换抛异常。
func transition_to(new_state: int) -> void:
	var valid: bool = false
	if current_state == GameState.WAITING and new_state == GameState.PLAYING:
		valid = true
	elif current_state == GameState.PLAYING and new_state == GameState.GAME_OVER:
		valid = true
	if not valid:
		printerr("非法状态转换：", current_state, " → ", new_state)
		return
	current_state = new_state


# === 游戏开局 ===

## 游戏开局流程：WAITING → PLAYING + 抓初始手牌 + 抓初始怪物卡 + 触发游戏开始时 + 进入第一玩家回合。
func start_game() -> void:
	transition_to(GameState.PLAYING)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.game_started.emit()
	if Game == null or not is_instance_valid(Game):
		return
	# 1. 每个玩家抓 4 张初始手牌
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		player.draw(4)
		# 可选一次重调
		if player.has_method("choose"):
			var choice: Variant = await player.choose(["进行重调", "不进行重调"])
			if choice == "进行重调":
				# 把最多 4 张刚抓的牌洗回牌堆，抓等量牌
				var max_return: int = mini(4, player.hand.size())
				var to_return: Array = await player.choose_card(max_return, "hand") if player.has_method("choose_card") else []
				if to_return != null and to_return.size() > 0:
					for card in to_return:
						player.hand.erase(card)
						player.game_deck.add(card)
					player.game_deck.shuffle()
					player.draw(to_return.size())
	# 2. 每个玩家抓 1 张初始怪物卡
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		player.draw_monster(1)
	# 3. 触发「游戏开始时」trigger
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		var event: Dictionary = EventSystem.create_event({"player": player})
		await player.trigger("on_game_start", event)
	# 4. 进入第一玩家回合
	await next_turn()


# === 游戏结束 ===

## 游戏结束流程：→ GAME_OVER + 设置结果 + 触发游戏结束时。
## 可从 PLAYING 或 WAITING 状态调用（WAITING 时直接强制进入 GAME_OVER，用于测试/异常场景）。
func game_over(result: int) -> void:
	if current_state == GameState.GAME_OVER:
		return
	current_state = GameState.GAME_OVER
	game_result = result
	current_player = null
	turn_queue.clear()
	# 日志输出
	if Game != null and is_instance_valid(Game):
		if result == GameResult.WIN:
			Game.log_message("求生者成功逃离启示录的废土！")
		elif result == GameResult.LOSE:
			Game.log_message("所有求生者死亡，游戏失败。")
		# 触发「游戏结束时」trigger
		for player in Game.players:
			if player == null or not is_instance_valid(player):
				continue
			var event: Dictionary = EventSystem.create_event({
				"player": player,
				"result": result,
			})
			await player.trigger("on_game_over", event)
		Game.game_over_called = true
		Game.game_result = "win" if result == GameResult.WIN else "lose"
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.game_over.emit(result)


# === 回合循环 ===

## 切换到下一个玩家并执行其回合。用 while 循环避免递归栈溢出。
func next_turn() -> void:
	while current_state == GameState.PLAYING:
		# 1. 获取下一个玩家
		var player: Variant = _get_next_player()
		if player == null:
			game_over(GameResult.LOSE)
			return
		# 2. 设置当前回合玩家
		current_player = player
		if Game != null and is_instance_valid(Game):
			Game.log_message("==== " + LogColors.player(player.player_name) + " 回合开始 ====")
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.turn_started.emit(player)
		# 3. 执行玩家回合
		await player.start_turn()
		if Game != null and is_instance_valid(Game) and current_state == GameState.PLAYING:
			Game.log_message("==== " + LogColors.player(player.player_name) + " 回合结束 ====")
		# 4. 检查胜利条件
		if check_win_condition():
			return
		# 5. 若游戏未结束，循环继续下一个回合


## 内部方法：从回合队列中取出下一个玩家，处理跳过标记与死亡玩家。
func _get_next_player() -> Variant:
	if turn_queue.is_empty():
		_fill_new_turn_queue()
	var skipped_any: bool = true
	while skipped_any:
		skipped_any = false
		while not turn_queue.is_empty():
			var player: Variant = turn_queue.pop_front()
			# 跳过已死亡玩家
			if player == null or not is_instance_valid(player) or not player.is_alive():
				skipped_any = true
				continue
			# 处理跳过标记
			if skip_turn_marks.has(player):
				skip_turn_marks.erase(player)
				if Game != null and is_instance_valid(Game):
					Game.log_message(LogColors.player(player.player_name) + " 的回合被跳过。")
				skipped_any = true
				continue
			return player
		# 队列空了，尝试填充新一轮
		if skipped_any and Game != null and is_instance_valid(Game):
			var has_alive: bool = false
			for p in Game.players:
				if p != null and is_instance_valid(p) and p.is_alive():
					has_alive = true
					break
			if not has_alive:
				return null
			_fill_new_turn_queue()
	return null


## 内部方法：按座位顺序将所有存活玩家填入回合队列，开始新一轮。
func _fill_new_turn_queue() -> void:
	turn_number += 1
	if Game == null or not is_instance_valid(Game):
		return
	Game.log_message("==== 第%d轮 ====" % turn_number)
	for player in Game.players:
		if player != null and is_instance_valid(player) and player.is_alive():
			turn_queue.append(player)


# === 额外回合与跳过 ===

## 插入额外回合。将指定玩家插入回合队列队首。
func queue_extra_turn(player: Variant) -> void:
	if current_state != GameState.PLAYING:
		return
	if player == null or not is_instance_valid(player) or not player.is_alive():
		return
	turn_queue.push_front(player)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player.player_name) + " 获得了一个额外回合。")


## 标记玩家跳过下个回合。跳过是一次性的。
func skip_next_turn(player: Variant) -> void:
	if current_state != GameState.PLAYING:
		return
	skip_turn_marks[player] = true
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player.player_name) + " 的下个回合将被跳过。")


# === 胜利条件检查 ===

## 检查胜利条件。仅在玩家回合结束时调用。
func check_win_condition() -> bool:
	if current_state != GameState.PLAYING:
		return false
	if Game == null or not is_instance_valid(Game):
		return false
	# 1. 玩家完成了任务（由任务系统检查）
	if not _check_mission_win_condition():
		return false
	# 若该任务不通过面包车胜利（燃料值为 NULL/-1），直接胜利
	if Game.mission_config == null or Game.mission_config.van_fuel_required < 0:
		game_over(GameResult.WIN)
		return true
	# 2. 往面包车添加了所需要的燃料值
	var van_blocks: Array = Game.get_blocks_by_name("面包车")
	if van_blocks.is_empty():
		return false
	var van: MapBlock = van_blocks[0]
	if van == null:
		return false
	var fuel: Variant = van.get("current_fuel")
	if fuel == null:
		fuel = 0
	if fuel < Game.mission_config.van_fuel_required:
		return false
	# 3. 所有存活玩家都返回到了面包车
	for player in Game.players:
		if player != null and is_instance_valid(player) and player.is_alive():
			if player.get_current_block() != van:
				return false
	# 4. 面包车无怪物和怪物标记
	if van.has_method("has_monster_mark") and van.has_monster_mark():
		return false
	if van.has_method("count_monster") and van.count_monster() > 0:
		return false
	# 所有胜利条件满足
	game_over(GameResult.WIN)
	return true


## 内部方法：委托给 mission_config.check_win_condition。
func _check_mission_win_condition() -> bool:
	if Game == null or not is_instance_valid(Game):
		return false
	if Game.mission_config == null:
		return false
	if Game.mission_config.check_win_condition.is_valid():
		return Game.mission_config.check_win_condition.call()
	return false


# === 查询方法 ===

func get_current_player() -> Variant:
	return current_player


func get_game_state() -> int:
	return current_state


func get_game_result() -> int:
	return game_result


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER


func get_turn_number() -> int:
	return turn_number
