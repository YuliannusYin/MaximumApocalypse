# 游戏循环管理类，负责控制游戏的主循环流程
class_name GameLoopManager
extends Node

var rule_engine: RuleEngine
var ui_manager: UIManager

func _ready() -> void:
	# 等待父节点准备好后获取其他节点
	await get_tree().create_timer(0.3).timeout
	rule_engine = get_parent().get_node("RuleEngine")
	ui_manager = get_parent().get_node("UIManager")

	# 连接RuleEngine的阶段完成信号
	rule_engine.spawn_phase_complete.connect(_on_spawn_phase_complete)
	rule_engine.draw_phase_complete.connect(_on_draw_phase_complete)
	rule_engine.action_phase_complete.connect(_on_action_phase_complete)
	rule_engine.turn_end_phase_complete.connect(_on_turn_end_phase_complete)

	# 连接UIManager的武器攻击信号
	ui_manager.weapon_attack_triggered.connect(_on_weapon_attack_triggered)
	# 连接UIManager的弃装备信号
	ui_manager.equipment_discarded.connect(_on_equipment_discarded)
	# 提供RuleEngine引用给UIManager用于查询装备栏槽位
	ui_manager.rule_engine_ref = rule_engine

func start_game():
	print("[GameLoop] 游戏开始，初始化数据...")
	ui_manager.add_log_message("游戏开始！")

	# 安全检查：如果没有玩家，无法开始游戏
	if GameState.players.is_empty():
		push_error("[GameLoop] 错误：没有玩家数据，无法启动游戏")
		ui_manager.add_log_message("错误：没有玩家数据")
		GameState.game_status = Enums.GameStatus.DEFEAT
		if rule_engine:
			rule_engine._handle_game_over()
		return

	GameState.current_turn = 1
	GameState.active_player_id = GameState.players.keys()[0]

	# 开始游戏循环
	while GameState.game_status == Enums.GameStatus.PLAYING:
		await run_player_turn(GameState.active_player_id)

		# 切换到下一个玩家
		if GameState.players.is_empty():
			break

		rule_engine._switch_to_next_player()

	if rule_engine:
		rule_engine._handle_game_over()

func run_player_turn(player_id: String):
	print("[GameLoop] === 玩家 " + player_id + " 的回合开始 ===")

	# 设置当前玩家
	rule_engine.set_current_player(player_id)

	# 回合开始时更新玩家信息
	ui_manager.update_player_info(player_id)
	ui_manager.update_turn_display(GameState.current_turn)

	# === 怪物出生阶段 ===
	GameState.current_phase = Enums.GamePhase.SPAWN
	GameState.phase_changed.emit(GameState.current_phase)
	ui_manager.update_phase_display(GameState.current_phase)
	ui_manager.add_log_message("回合 " + str(GameState.current_turn) + " - 怪物出生阶段")
	ui_manager.show_phase_buttons(Enums.GamePhase.SPAWN, player_id)

	# 等待玩家丢筛子
	await rule_engine.spawn_phase_complete
	if rule_engine._is_game_over(): return

	# === 抽牌阶段 ===
	GameState.current_phase = Enums.GamePhase.DRAW
	GameState.phase_changed.emit(GameState.current_phase)
	ui_manager.update_phase_display(GameState.current_phase)
	ui_manager.add_log_message("抽牌阶段")
	ui_manager.show_phase_buttons(Enums.GamePhase.DRAW, player_id)

	# 等待玩家点击抽牌按钮
	await rule_engine.draw_phase_complete
	if rule_engine._is_game_over(): return

	# === 行动阶段 ===
	GameState.current_phase = Enums.GamePhase.ACTION
	GameState.phase_changed.emit(GameState.current_phase)
	ui_manager.update_phase_display(GameState.current_phase)

	# 重置行动点
	var player = GameState.players[player_id]
	player.action_points = 40
	ui_manager.update_player_info(player_id)
	ui_manager.add_log_message("行动阶段 (行动点: 4)")

	# 显示行动阶段按钮（结束回合按钮）
	ui_manager.show_phase_buttons(Enums.GamePhase.ACTION, player_id)
	ui_manager.status_label.text = "行动阶段 - 点击地图移动或点击手牌出牌，点击结束回合完成"

	# 等待玩家点击"结束回合"
	await rule_engine.action_phase_complete
	if rule_engine._is_game_over(): return

	# === 回合结束阶段（合并饥饿结算和怪物攻击） ===
	GameState.current_phase = Enums.GamePhase.MONSTER_ATTACK  # 使用怪物攻击阶段表示回合结束
	GameState.phase_changed.emit(GameState.current_phase)
	ui_manager.update_phase_display(GameState.current_phase)
	ui_manager.add_log_message("回合结束阶段")
	ui_manager.show_phase_buttons(Enums.GamePhase.MONSTER_ATTACK, player_id)
	ui_manager.status_label.text = "回合结束 - 点击结算饥饿和怪物攻击"

	# 等待玩家点击回合结束按钮
	await rule_engine.turn_end_phase_complete
	if rule_engine._is_game_over(): return

	print("[GameLoop] === 玩家 " + player_id + " 的回合结束 ===")

# 阶段完成回调
func _on_spawn_phase_complete() -> void:
	print("[GameLoop] 怪物出生阶段完成")

func _on_draw_phase_complete() -> void:
	print("[GameLoop] 抽牌阶段完成")

func _on_action_phase_complete() -> void:
	print("[GameLoop] 行动阶段完成")

func _on_turn_end_phase_complete() -> void:
	print("[GameLoop] 回合结束阶段完成")

# 武器攻击回调
func _on_weapon_attack_triggered(player_id: String, equipment_index: int) -> void:
	rule_engine.use_weapon_attack(player_id, equipment_index)

# 弃装备回调
func _on_equipment_discarded(player_id: String, equipment_index: int) -> void:
	rule_engine.discard_equipment(player_id, equipment_index)