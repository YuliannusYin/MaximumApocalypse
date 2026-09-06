class_name GameStateMachine
extends RefCounted

## 游戏状态机。
## 职责：游戏级状态管理、回合队列管理、胜利/失败条件检查。
## 独立类，不继承 Entity（无技能、无 trigger），由 Game 持有。
## 正式/额外回合排队在 Game.event_scheduler，不走领域操作 enqueue/flush。
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

## 游戏结束时保存的最后回合玩家，供结算场景高亮。
var last_player: Variant = null

## 回合队列门面：实际队列在 Game.event_scheduler._turn_queue。
## 赋值会整体替换调度器中尚未执行的回合；读取返回副本。
var turn_queue: Array:
	get:
		var scheduler: Variant = _turn_scheduler()
		if scheduler == null:
			return []
		return scheduler.get_pending_turn_players()
	set(value):
		var scheduler: Variant = _turn_scheduler()
		if scheduler == null:
			return
		scheduler.set_pending_turn_players(value if value is Array else [])

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
	_clear_pending_turns()
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

## 游戏开局流程：WAITING → PLAYING + 触发游戏开始时 + 抓初始手牌 + 抓初始怪物卡 + 进入第一玩家回合。
## runtime 为可选的统一事件调度 runtime，见 Entity.damage 说明。
func start_game(runtime: Variant = null) -> void:
	var session_id: int = Game.get_session_id() if Game != null else 0
	var scheduler: Variant = runtime if runtime != null else Game.event_scheduler
	await scheduler.dispatch("game_start", func() -> void:
		if _session_aborted(session_id):
			return
		transition_to(GameState.PLAYING)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.game_started.emit()
		if Game != null and is_instance_valid(Game) and Game.stats_tracker != null:
			Game.stats_tracker.reset(Game.players)
			Game.stats_tracker.start_timer()
		if Game == null or not is_instance_valid(Game):
			return
		# 1. 触发「游戏开始时」trigger
		for player in Game.players:
			if _session_aborted(session_id):
				return
			if player == null or not is_instance_valid(player):
				continue
			var event: GameEvent = EventSystem.create_event({"player": player})
			await player.trigger("on_game_start", event)
		if _session_aborted(session_id):
			return
		# 2. 每个玩家抓 4 张初始手牌（豁免超限弹窗：从空手牌抓起，初始手牌数不会超过上限）
		for player in Game.players:
			if _session_aborted(session_id):
				return
			if player == null or not is_instance_valid(player):
				continue
			await player.draw(4, scheduler)
		if _session_aborted(session_id):
			return
		# 3. 每个玩家抓 1 张初始怪物卡（任务声明 no_initial_monster_draw 时跳过，如任务 11）
		if Game.mission_config == null or not Game.mission_config.no_initial_monster_draw:
			for player in Game.players:
				if _session_aborted(session_id):
					return
				if player == null or not is_instance_valid(player):
					continue
				await player.draw_monster(1, scheduler)
		if _session_aborted(session_id):
			return
		# 4. 第零轮：重调阶段
		await _round_zero(session_id)
		if _session_aborted(session_id):
			return
		# 5. 进入第一玩家回合
		await next_turn(),
		{})


# === 第零轮：重调阶段 ===

## 第零轮：每个存活玩家依次进行特殊重调回合。
## 玩家可选择"确定"返回全部手牌并重新抓取等量牌，或"取消"跳过。
## 此回合不执行 start_turn() 的21节点流程，不增加饥饿值、不被怪物攻击。
func _round_zero(session_id: int = -1) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	if session_id < 0:
		session_id = Game.get_session_id()
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.log_message.emit("==== 第0轮（重调阶段）====")
	for player in Game.players:
		if _session_aborted(session_id):
			return
		if player == null or not is_instance_valid(player):
			continue
		if not player.is_alive():
			continue
		# 设置当前回合玩家
		current_player = player
		player._create_turn_context(turn_number, 0)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.turn_started.emit(player)
			EventBus.player_turn_started.emit(player)
		var scheduler: Variant = Game.event_scheduler
		await player.execute_turn_event(scheduler, func(_ev: Variant) -> void:
			await player.run_turn_phase("round_zero", func() -> void:
				while true:
					if _session_aborted(session_id):
						return
					var redraw: bool = await player.wait_redraw_decision()
					if _session_aborted(session_id):
						return
					if not redraw:
						break
					var count: int = player.hand.size()
					for card in player.hand:
						player.game_deck.add(card)
					player.hand.clear()
					player.game_deck.shuffle()
					await player.draw(count, scheduler)
					if _session_aborted(session_id):
						return
					if EventBus != null and is_instance_valid(EventBus):
						EventBus.log_message.emit(LogColors.player(player.player_name) + " 执行了重调。")
			, "context_started")
			if _session_aborted(session_id):
				if player.get_turn_event() != null and not player.get_turn_event().is_finished():
					player.get_turn_event().mark_cancelled()
				return
			await player.run_turn_phase("idle", func() -> void:
				pass
			, "round_zero_finished")
		)
		player.finish_turn_context()
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.turn_ended.emit(player)
		if _session_aborted(session_id):
			return
	current_player = null


# === 游戏结束 ===

## 游戏结束流程：→ GAME_OVER + 设置结果 + 触发游戏结束时。
## 可从 PLAYING 或 WAITING 状态调用（WAITING 时直接强制进入 GAME_OVER，用于测试/异常场景）。
## reason 非空时替代默认的 WIN/LOSE 结束日志（如任务特定失败原因）。
## runtime 为可选的统一事件调度 runtime，见 Entity.damage 说明。
func game_over(result: int, reason: String = "", runtime: Variant = null) -> void:
	if current_state == GameState.GAME_OVER:
		return
	# 先同步进入终态，让回合循环/等待输入在结束触发跑完前就能停下来。
	current_state = GameState.GAME_OVER
	game_result = result
	last_player = current_player
	current_player = null
	_clear_pending_turns()
	var scheduler: Variant = runtime if runtime != null else Game.event_scheduler
	await scheduler.dispatch("game_over", func() -> void:
		if Game != null and is_instance_valid(Game) and Game.stats_tracker != null:
			Game.stats_tracker.stop_timer()
		if Game != null and is_instance_valid(Game):
			if result == GameResult.WIN:
				Game.log_message(reason if reason != "" else "求生者成功逃离启示录的废土！")
			elif result == GameResult.LOSE:
				Game.log_message(reason if reason != "" else "所有求生者死亡，游戏失败。")
			for player in Game.players:
				if player == null or not is_instance_valid(player):
					continue
				var event: GameEvent = EventSystem.create_event({
					"player": player,
					"result": result,
				})
				await player.trigger("on_game_over", event)
			Game.game_over_called = true
			Game.game_result = "win" if result == GameResult.WIN else "lose"
			if EventBus != null and is_instance_valid(EventBus):
				EventBus.game_over.emit(result),
		{"result": result})


# === 回合循环 ===

## 切换到下一个玩家并执行其回合。用 while 循环避免递归栈溢出。
## 玩家顺序来自调度器回合队列；每回合仍 `start_turn` → TurnEvent。
func next_turn() -> void:
	var session_id: int = Game.get_session_id() if Game != null else 0
	while current_state == GameState.PLAYING:
		if _session_aborted(session_id):
			return
		# 1. 获取下一个玩家
		var player: Variant = _get_next_player()
		if player == null:
			await game_over(GameResult.LOSE)
			return
		# 2. 设置当前回合玩家
		current_player = player
		if Game != null and is_instance_valid(Game):
			Game.log_message("==== " + LogColors.player(player.player_name) + " 回合开始 ====")
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.turn_started.emit(player)
			if current_player != null:
				EventBus.player_turn_started.emit(current_player)
		# 3. 执行玩家回合
		await player.start_turn(Game.event_scheduler if Game != null else null)
		if _session_aborted(session_id):
			return
		if current_state != GameState.PLAYING:
			return
		if Game != null and is_instance_valid(Game):
			Game.log_message("==== " + LogColors.player(player.player_name) + " 回合结束 ====")
		# 4. 检查胜利条件
		if await check_win_condition():
			return
		# 5. 若游戏未结束，循环继续下一个回合


## 内部方法：从调度器回合队列中取出下一个玩家，处理跳过标记与死亡玩家。
func _get_next_player() -> Variant:
	var scheduler: Variant = _turn_scheduler()
	if scheduler == null:
		return null
	if not scheduler.has_pending_turns():
		_fill_new_turn_queue()
	var skipped_any: bool = true
	while skipped_any:
		skipped_any = false
		while scheduler.has_pending_turns():
			var player: Variant = scheduler.pop_turn()
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


## 内部方法：按座位顺序将所有存活玩家填入调度器回合队列，开始新一轮。
func _fill_new_turn_queue() -> void:
	turn_number += 1
	if Game == null or not is_instance_valid(Game):
		return
	Game.log_message("==== 第%d轮 ====" % turn_number)
	var scheduler: Variant = _turn_scheduler()
	if scheduler == null:
		return
	for player in Game.players:
		if player != null and is_instance_valid(player) and player.is_alive():
			scheduler.enqueue_turn(player)


# === 额外回合与跳过 ===

## 插入额外回合。将指定玩家插入调度器回合队列队首。
func queue_extra_turn(player: Variant) -> void:
	if current_state != GameState.PLAYING:
		return
	if player == null or not is_instance_valid(player) or not player.is_alive():
		return
	var scheduler: Variant = _turn_scheduler()
	if scheduler == null:
		return
	scheduler.enqueue_turn(player, true)
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
	# 0. 任务特定失败条件（优先于胜利检查）
	if Game.mission_config != null and Game.mission_config.check_lose(Game):
		await game_over(GameResult.LOSE, "任务目标失败，游戏结束。")
		return true
	# 1. 玩家完成了任务（由任务系统检查）
	if not _check_mission_win_condition():
		return false
	await game_over(GameResult.WIN)
	return true


## 内部方法：委托给 mission_config.check_win（三层架构组件/脚本编排）。
func _check_mission_win_condition() -> bool:
	if Game == null or not is_instance_valid(Game):
		return false
	if Game.mission_config == null:
		return false
	return Game.mission_config.check_win(Game)


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


func _session_aborted(session_id: int) -> bool:
	return Game == null or not is_instance_valid(Game) or not Game.is_session(session_id)


func _turn_scheduler() -> Variant:
	if Game != null and is_instance_valid(Game):
		return Game.event_scheduler
	return null


func _clear_pending_turns() -> void:
	var scheduler: Variant = _turn_scheduler()
	if scheduler != null:
		scheduler.clear_turn_queue()
