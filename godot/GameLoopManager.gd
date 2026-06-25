# GameLoopManager.gd
extends Node

# 引用其他的管理器（根据你项目的实际节点路径调整）
@onready var rule_engine = $RuleEngine
@onready var map_board = $MapBoard
@onready var ui_manager = $UIManager

# 启动游戏循环
func start_game():
	print("游戏开始，初始化数据...")
	# 1. 铺设地图、洗牌、初始化玩家等（调用之前的 MapGenerator）
	# 2. 决定先手玩家

	GameState.current_turn = 1
	GameState.active_player_id = GameState.players.keys()[0]
	
	# 进入无限回合循环，直到游戏结束
	while GameState.game_status == Enums.GameStatus.PLAYING:
		await run_player_turn(GameState.active_player_id)
		
		# 回合交替逻辑：顺时针切换当前玩家
		rule_engine._switch_to_next_player()
		
	# 循环跳出，说明游戏结束
	rule_engine._handle_game_over()

# 处理单个玩家的完整回合
func run_player_turn(player_id: String):
	print("--- 玩家 " + player_id + " 的回合开始 ---")
	
	# 阶段 1: 怪物出生
	GameState.current_phase = Enums.GamePhase.SPAWN
	GameState.phase_changed.emit(GameState.current_phase)
	await rule_engine._process_spawn_phase()
	if rule_engine._is_game_over(): return

	# 阶段 2: 玩家抽牌
	GameState.current_phase = Enums.GamePhase.DRAW
	GameState.phase_changed.emit(GameState.current_phase)
	await rule_engine._process_draw_phase(player_id)
	if rule_engine._is_game_over(): return

	# 阶段 3: 执行行动（核心交互阶段）
	GameState.current_phase = Enums.GamePhase.ACTION
	GameState.phase_changed.emit(GameState.current_phase)
	await rule_engine._process_action_phase(player_id)
	if rule_engine._is_game_over(): return

	# 阶段 4: 增加饥饿值与结算伤害
	GameState.current_phase = Enums.GamePhase.HUNGER
	GameState.phase_changed.emit(GameState.current_phase)
	await rule_engine._process_hunger_phase(player_id)
	if rule_engine._is_game_over(): return

	# 阶段 5: 怪物攻击
	GameState.current_phase = Enums.GamePhase.MONSTER_ATTACK
	GameState.phase_changed.emit(GameState.current_phase)
	await rule_engine._process_monster_attack_phase(player_id)
	
	print("--- 玩家 " + player_id + " 的回合结束 ---")
