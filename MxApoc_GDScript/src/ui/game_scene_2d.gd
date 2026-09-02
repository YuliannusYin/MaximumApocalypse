extends Control

## 2D 试玩版游戏主场景。
## 层结构：TableLayer（桌子+地图，可平移）/ UILayer（固定 UI）/ PopupLayer（弹窗）。
## 游戏流程：_ready() → 创建子模块 → initialize_game() → 注入 GUIPlayerInput → start_game()。

const SETTINGS_DIALOG_SCENE := preload("res://scenes/SettingsDialog.tscn")
const TUTORIAL_DIALOG_SCENE := preload("res://scenes/TutorialDialog.tscn")
const WIKI_OVERLAY_SCENE := preload("res://scenes/WikiOverlay.tscn")
const TutorialManager = preload("res://src/ui/tutorial_manager.gd")

# === 层节点（来自 .tscn）===
@onready var _table_layer: CanvasLayer = $TableLayer
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _popup_layer: CanvasLayer = $PopupLayer

# === UI 元素（来自 .tscn）===
@onready var _log_button: Button = $UILayer/LogButton
@onready var _mission_button: Button = $UILayer/MissionButton
@onready var _settings_button: Button = $UILayer/SettingsButton
@onready var _wiki_button: Button = $UILayer/WikiButton
@onready var _active_skill_grid: GridContainer = $UILayer/ActiveSkillPanel/ActiveSkillGrid

# === 子模块 ===
var _popup_manager: PopupManager
var _table_map_controller: TableMapController
var _pile_manager: PileManager
var _action_selection_controller: ActionSelectionController
var _active_skill_bar: ActiveSkillBar
var _event_log_panel: EventLogPanel
var _animation_controller: AnimationController

# === 游戏状态 ===
var _gui_input: GUIPlayerInput
var _pending_target_source: Variant = null

# === 客机模式状态 ===
var _net_view_ctx: Dictionary = {}
var _net_input: NetClientInput = null
var _net_ui_built := false
var _net_client_started := false
var _net_game_over_shown := false

# === 设置弹出菜单 ===
var _settings_popup: PopupMenu
var _wiki_overlay: Control = null

# === 玩家面板 ===
var _player_panels: Array = []
var _player_to_panel_idx: Dictionary = {}

# === 手牌区 ===
var _hand_area: HandDisplayArea

# === 任务进度 ===
var _progress_panel: MissionProgressPanel

# === 事件日志 ===
var _event_log: Array = []


func _ready() -> void:
	_create_modules()
	_wire_static_buttons()
	_start_game_flow()


# === 子模块创建与信号接线 ===

func _create_modules() -> void:
	_popup_manager = PopupManager.new()
	_popup_manager.setup(_popup_layer)
	_popup_layer.add_child(_popup_manager)

	_table_map_controller = TableMapController.new()
	_table_map_controller.setup(_table_layer)
	_table_layer.add_child(_table_map_controller)

	_pile_manager = PileManager.new()
	_pile_manager.setup(_ui_layer)
	add_child(_pile_manager)
	_pile_manager.wire_pile_nodes()
	_pile_manager.apply_pile_styles()

	_action_selection_controller = ActionSelectionController.new()
	_action_selection_controller.setup(_ui_layer)
	add_child(_action_selection_controller)
	_action_selection_controller.build_buttons()

	# 统一动画控制器：集中持有全屏演出、目标指向演出和回合横幅。
	_animation_controller = AnimationController.new()
	_ui_layer.add_child(_animation_controller)

	_active_skill_bar = ActiveSkillBar.new()
	_active_skill_bar.setup(_active_skill_grid)
	add_child(_active_skill_bar)

	_event_log_panel = EventLogPanel.new()
	_ui_layer.add_child(_event_log_panel)

	_table_map_controller.block_clicked.connect(_on_block_clicked)
	_table_map_controller.block_inspected.connect(_on_block_inspected)
	_table_map_controller.avatar_clicked.connect(_on_avatar_clicked)
	_pile_manager.pile_clicked.connect(_on_pile_clicked)
	_pile_manager.discard_pile_clicked.connect(_on_discard_pile_clicked)
	_action_selection_controller.action_requested.connect(_on_action_from_controller)
	_action_selection_controller.confirm_responded.connect(_on_confirm_from_controller)
	_action_selection_controller.move_mode_changed.connect(_on_move_mode_changed)
	_action_selection_controller.card_move_select_completed.connect(_on_card_move_select_completed)
	_active_skill_bar.skill_pressed.connect(_on_skill_pressed)


func _wire_static_buttons() -> void:
	# 右上角固定操作入口与牌堆采用同一套废土金属槽视觉。
	HudTheme.apply_slot_button(_log_button, 11)
	HudTheme.apply_mission_slot_button(_mission_button, 11)
	HudTheme.apply_slot_button(_settings_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(_wiki_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	_log_button.pressed.connect(_on_log_button_pressed)
	_mission_button.pressed.connect(_on_mission_button_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_wiki_button.pressed.connect(_on_wiki_pressed)


# === 游戏流程 ===

func _start_game_flow() -> void:
	# 客机模式：不运行本地模拟，基于主机快照渲染并转发输入
	if NetSession.mode == NetSession.Mode.CLIENT:
		_start_client_game_flow()
		return
	var mission: MissionData = RoomState.selected_mission
	if RoomState.selected_mission_is_random:
		mission = null
	var variants: Dictionary = RoomState.variants
	var seats: Array = RoomState.seats

	Game.initialize_game(mission, variants, seats)
	_table_map_controller.build_table_and_map()
	# 任务进度面板：常驻 UI 层右侧固定位置，_process 自刷新任务条件进度
	_progress_panel = MissionProgressPanel.new()
	_ui_layer.add_child(_progress_panel)
	_build_player_panels()
	_build_hand_area()
	_assign_player_panels()
	_pile_manager.refresh_pile_counts()

	_gui_input = GUIPlayerInput.new()
	_wire_input(_gui_input)
	for player in Game.players:
		if player != null and is_instance_valid(player):
			player.input = _assign_player_input(player)

	_connect_event_bus_handlers()
	# 主机：客机掉线 → 其角色改为 AI 托管，避免请求挂起卡死
	if NetSession.mode == NetSession.Mode.HOST:
		NetSession.peer_disconnected.connect(_on_net_peer_disconnected)

	# 教程系统：任务 0 默认开启；设置勾选后任意任务也播
	if _should_start_tutorial():
		var tutorial_dialog: CanvasLayer = TUTORIAL_DIALOG_SCENE.instantiate()
		add_child(tutorial_dialog)
		var tutorial_manager: Node = TutorialManager.new()
		add_child(tutorial_manager)
		tutorial_manager.start(tutorial_dialog, get_tutorial_hole)

	# 联机：开局广播一次全量快照
	if NetSession.mode == NetSession.Mode.HOST:
		_schedule_snapshot()

	Game.start_game()


## 连接输入对象的请求信号到本地 UI 处理器与弹窗响应（主机/客机共用）。
func _wire_input(input: GUIPlayerInput) -> void:
	input.action_requested.connect(_on_action_requested)
	input.choose_requested.connect(_on_choose_requested)
	input.choose_card_requested.connect(_on_choose_card_requested)
	input.choose_target_requested.connect(_on_choose_target_requested)
	input.choose_block_requested.connect(_on_choose_block_requested)
	input.choose_block_inline_requested.connect(_on_choose_block_inline_requested)
	input.confirm_requested.connect(_on_confirm_requested)
	input.show_card_requested.connect(_on_show_card_requested)
	input.set_prompt_requested.connect(_on_set_prompt_requested)
	input.redraw_decision_requested.connect(_on_redraw_decision_requested)
	input.judge_confirm_requested.connect(_on_judge_confirm_requested)
	input.dice_animation_requested.connect(_on_dice_animation_requested)
	input.monster_draw_animation_requested.connect(_on_monster_draw_animation_requested)
	input.scavenge_draw_animation_requested.connect(_on_scavenge_draw_animation_requested)
	input.card_destroy_animation_requested.connect(_on_card_destroy_animation_requested)
	input.monster_skill_trigger_animation_requested.connect(_on_monster_skill_trigger_animation_requested)
	input.monster_attack_animation_requested.connect(_on_monster_attack_animation_requested)
	_popup_manager.option_selected.connect(input.respond_choose)
	_popup_manager.confirm_responded.connect(input.respond_confirm)
	_popup_manager.cards_selected.connect(input.respond_choose_card)
	_popup_manager.targets_selected.connect(_on_popup_targets_selected)
	_popup_manager.block_selected.connect(_on_popup_block_selected)
	_action_selection_controller.redraw_decision_responded.connect(input.respond_redraw_decision)
	_action_selection_controller.judge_confirm_responded.connect(input.respond_judge_confirm)


## 连接 EventBus 信号到刷新处理器（主机/客机共用）。
func _connect_event_bus_handlers() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.log_message.connect(_on_log_message)
	EventBus.log_message.connect(_event_log_panel.add_message)
	_event_log_panel.set_messages(_event_log)
	EventBus.game_over.connect(_on_game_over)
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.block_revealed.connect(_on_block_revealed)
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.monster_mark_changed.connect(_on_block_mark_changed)
	EventBus.objective_mark_changed.connect(_on_block_mark_changed)
	EventBus.monster_spawned.connect(_on_monster_changed)
	EventBus.monster_died.connect(_on_monster_died)
	EventBus.monster_engaged_target_changed.connect(_on_monster_engaged_target_changed)
	EventBus.player_hp_changed.connect(_on_player_stat_changed)
	EventBus.damage_taken.connect(_on_damage_taken)
	EventBus.hp_recovered.connect(_on_hp_recovered)
	EventBus.player_hunger_changed.connect(_on_hunger_changed)
	EventBus.player_died.connect(_on_player_stat_changed)
	EventBus.equipment_equipped.connect(_on_player_stat_changed)
	EventBus.equipment_unequipped.connect(_on_player_stat_changed)
	EventBus.action_consumed.connect(_on_action_consumed)
	EventBus.card_drawn.connect(_on_player_stat_changed)
	EventBus.card_discarded.connect(_on_player_stat_changed)
	EventBus.card_used.connect(_on_player_stat_changed)
	EventBus.card_settlement_started.connect(_on_player_stat_changed)
	EventBus.card_settlement_finished.connect(_on_player_stat_changed)
	EventBus.scavenge_drawn.connect(_on_pile_drawn)
	EventBus.monster_card_drawn.connect(_on_pile_drawn)
	# 主机侧：状态变更即调度全量快照广播（客机端 _schedule_snapshot 为 no-op）
	EventBus.turn_started.connect(_schedule_snapshot)
	EventBus.phase_changed.connect(_schedule_snapshot)
	EventBus.player_moved.connect(_schedule_snapshot)
	EventBus.block_revealed.connect(_schedule_snapshot)
	EventBus.block_destroyed.connect(_schedule_snapshot)
	EventBus.monster_mark_changed.connect(_schedule_snapshot)
	EventBus.objective_mark_changed.connect(_schedule_snapshot)
	EventBus.monster_spawned.connect(_schedule_snapshot)
	EventBus.monster_died.connect(_schedule_snapshot)
	EventBus.player_hp_changed.connect(_schedule_snapshot)
	EventBus.player_hunger_changed.connect(_schedule_snapshot)
	EventBus.player_died.connect(_schedule_snapshot)
	EventBus.equipment_equipped.connect(_schedule_snapshot)
	EventBus.equipment_unequipped.connect(_schedule_snapshot)
	EventBus.action_consumed.connect(_schedule_snapshot)
	EventBus.card_drawn.connect(_schedule_snapshot)
	EventBus.card_discarded.connect(_schedule_snapshot)
	EventBus.card_used.connect(_schedule_snapshot)
	EventBus.scavenge_drawn.connect(_schedule_snapshot)
	EventBus.monster_card_drawn.connect(_schedule_snapshot)
	EventBus.game_over.connect(_schedule_snapshot)
	# 联机动画同步：主机据此把攻击/怪物技能动画广播到各客机（客机端模式自守卫为空操作）
	EventBus.monster_attack_played.connect(_on_host_monster_attack_played)
	EventBus.monster_skill_played.connect(_on_host_monster_skill_played)
	EventBus.dice_played.connect(_on_host_dice_played)
	EventBus.player_attack_played.connect(_on_host_player_attack_played)


## 按玩家座位归属分配输入：
## 主机本地座位用 GUI；远端客机座位用 NetPlayerInput（请求转发给对应客机）。
func _assign_player_input(player: Player) -> IPlayerInput:
	var seat_idx := int(player.seat_number)
	if seat_idx >= 0 and seat_idx < RoomState.seats.size():
		var pid := int(RoomState.seats[seat_idx].get("peer_id", 0))
		if pid != 0 and pid != NetSession.HOST_PEER_ID:
			var net_input := NetPlayerInput.new()
			net_input.peer_id = pid
			net_input.player = player
			NetSession.register_remote_input(pid, net_input)
			return net_input
	return _gui_input


# === 联机快照广播（主机侧） ===

var _snapshot_dirty := false
## 快照广播最小间隔（秒），防止高频大快照过载 ENet。
const SNAPSHOT_INTERVAL := 0.2
var _last_snapshot_time := 0.0

## 标记状态已变更，下一帧广播全量快照（合并同一帧内的多次变更）。
## 作为多个 EventBus 信号的连接目标，需容忍信号携带任意参数。
func _schedule_snapshot(_a = null, _b = null, _c = null, _d = null) -> void:
	if NetSession.mode != NetSession.Mode.HOST:
		return
	_snapshot_dirty = true


func _broadcast_snapshot() -> void:
	if NetSession.mode != NetSession.Mode.HOST:
		return
	NetSession.host_broadcast_snapshot(GameStateSerializer.serialize(Game))


func _process_snapshot(delta: float) -> void:
	if not _snapshot_dirty:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_snapshot_time < SNAPSHOT_INTERVAL:
		return  # 节流：保留脏标记，稍后再发
	_snapshot_dirty = false
	_last_snapshot_time = now
	_broadcast_snapshot()


func _process(delta: float) -> void:
	_process_snapshot(delta)


## 主机：客机掉线 → 结算其挂起请求并将角色改为 AI 托管（CliPlayerInput 自动行动）。
func _on_net_peer_disconnected(pid: int) -> void:
	NetSession.unregister_remote_input(pid)
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		var input: Variant = player.input
		if input is NetPlayerInput and (input as NetPlayerInput).peer_id == pid:
			(input as NetPlayerInput).on_peer_disconnected()
			player.input = CliPlayerInput.new()


# === 联机动画同步（攻击 / 怪物技能 → 广播到所有客机） ===

## 主机：怪物攻击动画 → 广播给除拥有者外的客机；拥有者为远端时主机本地也播。
func _on_host_monster_attack_played(monster: Variant, targets: Array) -> void:
	if NetSession.mode != NetSession.Mode.HOST:
		return
	if monster == null or not is_instance_valid(monster):
		return
	var owner_pid := _net_owner_peer_id(monster)
	_broadcast_game_event_except(owner_pid, {
		"type": "monster_attack", "monster": monster.net_id, "targets": _target_seats(targets),
	})
	if owner_pid != NetSession.HOST_PEER_ID and owner_pid != 0:
		_play_attack_locally(monster, targets)


## 主机：怪物技能触发动画 → 广播给除拥有者外的客机；拥有者为远端时主机本地也播。
func _on_host_monster_skill_played(monster: Variant) -> void:
	if NetSession.mode != NetSession.Mode.HOST:
		return
	if monster == null or not is_instance_valid(monster):
		return
	var owner_pid := _net_owner_peer_id(monster)
	_broadcast_game_event_except(owner_pid, {
		"type": "monster_skill", "monster": monster.net_id,
	})
	if owner_pid != NetSession.HOST_PEER_ID and owner_pid != 0:
		_play_skill_locally(monster)


## 主机：骰子动画 → 广播给除掷骰玩家外的客机；掷骰者为远端时主机本地也播。
func _on_host_dice_played(player: Variant, d1: int, d2: int, label: String, outcome: String) -> void:
	if NetSession.mode != NetSession.Mode.HOST:
		return
	var pid := _net_player_peer_id(player)
	_broadcast_game_event_except(pid, {
		"type": "dice", "d1": d1, "d2": d2, "label": label, "outcome": outcome,
	})
	if pid != NetSession.HOST_PEER_ID and pid != 0:
		_play_dice_locally(d1, d2, label, outcome)


## 主机：玩家选定攻击/效果目标 → 广播给除该玩家外的客机；为远端时主机本地也播。
func _on_host_player_attack_played(player: Variant, targets: Array) -> void:
	if NetSession.mode != NetSession.Mode.HOST:
		return
	if player == null or not is_instance_valid(player):
		return
	var pid := _net_player_peer_id(player)
	var encoded: Array = []
	for target in targets:
		if target is Monster and is_instance_valid(target):
			encoded.append({"type": "monster", "id": target.net_id})
		elif target is Player and is_instance_valid(target):
			encoded.append({"type": "player", "seat": target.seat_number})
	_broadcast_game_event_except(pid, {
		"type": "player_attack", "source": player.seat_number, "targets": encoded,
	})
	if pid != NetSession.HOST_PEER_ID and pid != 0:
		_play_player_attack_locally(player, targets)


## 玩家所属 peer id（按座位 peer_id 映射）。
func _net_player_peer_id(player: Variant) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var seat_idx := int(player.seat_number)
	if seat_idx >= 0 and seat_idx < RoomState.seats.size():
		return int(RoomState.seats[seat_idx].get("peer_id", 0))
	return 0


func _play_dice_locally(d1: int, d2: int, label: String, outcome: String) -> void:
	await _animation_controller.play_dice(d1, d2, label, outcome)


func _play_player_attack_locally(player: Variant, targets: Array) -> void:
	var source_panel: PlayerPanel = _get_panel_for_player(player)
	if source_panel == null:
		return
	var player_positions: Array[Vector2] = []
	var monsters: Array = []
	for target in targets:
		if target is Player and is_instance_valid(target):
			var target_panel: PlayerPanel = _get_panel_for_player(target)
			if target_panel != null:
				player_positions.append(target_panel.get_role_card_global_position())
		elif target is Monster and is_instance_valid(target):
			monsters.append(target)
	await _animation_controller.play_target_links(source_panel.get_role_card_global_position(), player_positions, monsters)


## 向除指定 peer 外的所有客机发送 GAME_EVENT。
func _broadcast_game_event_except(except_pid: int, data: Dictionary) -> void:
	for pid in NetSession.get_peer_ids():
		if pid == except_pid:
			continue
		NetSession.host_send_to(pid, NetProtocol.Msg.GAME_EVENT, {"event": data})


## 怪物所属玩家的 peer id（按座位 peer_id 映射）。
func _net_owner_peer_id(monster: Variant) -> int:
	if monster == null or not is_instance_valid(monster):
		return 0
	var owner: Variant = monster.get_owner_player()
	if owner == null:
		return 0
	var seat_idx := int(owner.seat_number)
	if seat_idx >= 0 and seat_idx < RoomState.seats.size():
		return int(RoomState.seats[seat_idx].get("peer_id", 0))
	return 0


func _target_seats(targets: Array) -> Array:
	var out: Array = []
	for t in targets:
		if t is Player:
			out.append(t.seat_number)
	return out


func _play_attack_locally(monster: Variant, targets: Array) -> void:
	var positions: Array = []
	for target in targets:
		if target is Player and is_instance_valid(target):
			var target_panel: PlayerPanel = _get_panel_for_player(target)
			if target_panel != null:
				positions.append(target_panel.get_role_card_global_position())
	await _animation_controller.play_monster_attack(monster, positions)


func _play_skill_locally(monster: Variant) -> void:
	await _animation_controller.play_monster_skill_trigger(monster)


## 客机：收到主机 GAME_EVENT 后播放对应动画（非阻塞，不 respond）。
func _on_client_game_event(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"monster_attack":
			var monster: Variant = _monster_by_id(int(event.get("monster", 0)))
			if monster != null:
				var positions: Array = []
				for seat in event.get("targets", []):
					var t: Variant = _player_by_seat(int(seat))
					if t != null:
						var target_panel: PlayerPanel = _get_panel_for_player(t)
						if target_panel != null:
							positions.append(target_panel.get_role_card_global_position())
				await _animation_controller.play_monster_attack(monster, positions)
		"monster_skill":
			var monster2: Variant = _monster_by_id(int(event.get("monster", 0)))
			if monster2 != null:
				await _animation_controller.play_monster_skill_trigger(monster2)
		"dice":
			await _animation_controller.play_dice(
				int(event.get("d1", 0)), int(event.get("d2", 0)),
				str(event.get("label", "")), str(event.get("outcome", "")))
		"player_attack":
			var source: Variant = _player_by_seat(int(event.get("source", -1)))
			if source != null:
				var source_panel: PlayerPanel = _get_panel_for_player(source)
				if source_panel != null:
					var player_positions: Array[Vector2] = []
					var monsters: Array = []
					for tdata in event.get("targets", []):
						match str(tdata.get("type", "")):
							"player":
								var tp: Variant = _player_by_seat(int(tdata.get("seat", -1)))
								if tp != null:
									var tp_panel: PlayerPanel = _get_panel_for_player(tp)
									if tp_panel != null:
										player_positions.append(tp_panel.get_role_card_global_position())
							"monster":
								var tm: Variant = _monster_by_id(int(tdata.get("id", 0)))
								if tm != null:
									monsters.append(tm)
					await _animation_controller.play_target_links(
						source_panel.get_role_card_global_position(), player_positions, monsters)
	_refresh_all_from_snapshot()


func _monster_by_id(nid: int) -> Variant:
	if nid <= 0:
		return null
	for p in Game.players:
		if p == null:
			continue
		for m in p.monster_zone:
			if m != null and m.net_id == nid:
				return m
	return null


func _player_by_seat(seat: int) -> Variant:
	if seat < 0:
		return null
	for p in Game.players:
		if p != null and int(p.seat_number) == seat:
			return p
	return null


# === 客机模式：基于主机快照的渲染 + 输入转发 ===

func _start_client_game_flow() -> void:
	_net_view_ctx = GameStateSerializer.make_context()
	_net_input = NetClientInput.new()
	# 复用动画处理器里的 _gui_input.respond_* 调用（NetClientInput 继承自 GUIPlayerInput）
	_gui_input = _net_input
	_wire_input(_net_input)
	_connect_event_bus_handlers()
	# 任务进度面板：常驻 UI 层右侧，_process 自刷新
	_progress_panel = MissionProgressPanel.new()
	_ui_layer.add_child(_progress_panel)
	NetSession.snapshot_received.connect(_on_client_snapshot)
	NetSession.input_request_received.connect(_on_client_input_request)
	NetSession.game_event_received.connect(_on_client_game_event)
	NetSession.disconnected.connect(func() -> void:
		NetSession.stop()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	_net_client_started = true


func _on_client_snapshot(state: Dictionary) -> void:
	if not _net_client_started:
		return
	GameStateSerializer.apply_to_view(Game, state, _net_view_ctx)
	if not _net_ui_built:
		_build_client_ui()
		_net_ui_built = true
	_refresh_all_from_snapshot()
	# 同步主机事件日志
	if state.has("log"):
		_event_log_panel.set_messages(state["log"])
	# 游戏结束：主机快照携带 game_state
	if int(state.get("game_state", 0)) == GameStateMachine.GameState.GAME_OVER:
		_show_client_game_over(state)


func _build_client_ui() -> void:
	_table_map_controller.build_table_and_map()
	_build_player_panels()
	_build_hand_area()
	_assign_player_panels()
	_pile_manager.refresh_pile_counts()


func _refresh_all_from_snapshot() -> void:
	if not _net_ui_built:
		return
	_table_map_controller.refresh_map()
	_assign_player_panels()
	_refresh_hand_area()
	_pile_manager.refresh_pile_counts()
	_pile_manager.refresh_pile_highlights()
	_action_selection_controller.refresh_confirm_cancel_buttons()
	_active_skill_bar.refresh(_net_local_player())


func _on_client_input_request(req_id: int, req_type: String, params: Dictionary) -> void:
	if _net_input == null:
		return
	match req_type:
		"action":
			_net_input.net_wait_action(req_id, Game.get_current_player())
		"choose":
			var opts: Array = params.get("options", [])
			_net_input.net_choose(req_id, opts, str(params.get("prompt", "")))
		"choose_card":
			var cards := _cards_from_ids(params.get("cards", []))
			_net_input.net_choose_card(req_id, int(params.get("n", 1)), cards, str(params.get("prompt", "")), int(params.get("min_n", -1)))
		"choose_target":
			var targets := _targets_from_encoded(params.get("targets", []))
			var view_skill = _current_view_skill(str(params.get("skill", "")))
			_net_input.net_choose_target(req_id, int(params.get("n", 1)), view_skill, str(params.get("prompt", "")), int(params.get("min_n", -1)))
		"choose_block":
			var blocks := _blocks_from_coords(params.get("blocks", []))
			_net_input.net_choose_block(req_id, blocks, str(params.get("prompt", "")))
		"choose_block_inline":
			var blocks2 := _blocks_from_coords(params.get("blocks", []))
			_net_input.net_choose_block_inline(req_id, blocks2, str(params.get("prompt", "")), int(params.get("count", 1)))
		"confirm":
			_net_input.net_confirm(req_id, str(params.get("message", "")))
		"redraw":
			_net_input.net_redraw(req_id)
		"judge_confirm":
			_net_input.net_judge_confirm(req_id, str(params.get("prompt", "")), bool(params.get("allow_cancel", true)))
		"show_card":
			_net_input.net_show_card(req_id, _card_by_id(int(params.get("card", 0))), null)
		"set_prompt":
			_net_input.net_set_prompt(req_id, str(params.get("text", "")))
		_:
			# 动画等：即时回执推进流程
			_net_input.net_anim(req_id, req_type, params)


## 按 net_id 从视图上下文取卡牌。
func _cards_from_ids(ids: Array) -> Array:
	var out: Array = []
	for nid in ids:
		var c: Variant = _net_view_ctx.cards.get(int(nid), null)
		if c != null:
			out.append(c)
	return out


func _card_by_id(nid: int) -> Variant:
	return _net_view_ctx.cards.get(nid, null)


## 按坐标从视图取地块。
func _blocks_from_coords(coords: Array) -> Array:
	var out: Array = []
	for c in coords:
		for b in Game.map_area:
			if b != null and b.coordinate == c:
				out.append(b)
				break
	return out


## 解码主机下发的目标候选为视图对象。
func _targets_from_encoded(targets: Array) -> Array:
	var out: Array = []
	for td in targets:
		match str(td.get("t", "")):
			"player":
				var p: Variant = _net_view_ctx.players.get(int(td.get("id", 0)), null)
				if p != null:
					out.append(p)
			"monster":
				var m: Variant = _net_view_ctx.monsters.get(int(td.get("id", 0)), null)
				if m != null:
					out.append(m)
			"card":
				var c: Variant = _net_view_ctx.cards.get(int(td.get("id", 0)), null)
				if c != null:
					out.append(c)
			"block":
				var b: Variant = _block_by_coord(td)
				if b != null:
					out.append(b)
	return out


func _block_by_coord(td: Dictionary) -> Variant:
	var tx := int(td.get("x", -999))
	var ty := int(td.get("y", -999))
	for b in Game.map_area:
		if b != null and int(b.coordinate.get("x", -999)) == tx and int(b.coordinate.get("y", -999)) == ty:
			return b
	return null


## 按英文名取当前玩家视图技能（供 choose_target 正确重算候选）。
func _current_view_skill(english_name: String) -> Variant:
	if english_name == "":
		return null
	var current: Variant = Game.get_current_player()
	if current == null:
		return null
	for s in current.skills:
		if s is Skill and s.english_name == english_name:
			return s
	return null


## 客机端游戏结束：显示结果浮层（胜负由主机快照携带）。
func _show_client_game_over(state: Dictionary) -> void:
	if _net_game_over_shown:
		return
	_net_game_over_shown = true
	var result_text := "游戏结束"
	match int(state.get("game_result", -1)):
		GameStateMachine.GameResult.WIN:
			result_text = "胜利！\n\n幸存者们完成了任务。"
		GameStateMachine.GameResult.LOSE:
			result_text = "失败\n\n全员阵亡，末日降临。"
		_:
			result_text = "游戏结束"
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.name = "NetGameOverOverlay"
	add_child(overlay)
	var label := Label.new()
	label.text = result_text
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	add_child(label)
	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.set_anchors_preset(Control.PRESET_CENTER)
	back_btn.position = Vector2(back_btn.position.x, back_btn.position.y + 90)
	back_btn.custom_minimum_size = Vector2(180, 44)
	HudTheme.apply_slot_button(back_btn, 14)
	add_child(back_btn)
	back_btn.pressed.connect(func() -> void:
		NetSession.stop()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)


## 是否开启教程。以设置项为唯一开关（关闭则不播任何教程，含任务 0）。
func _should_start_tutorial() -> bool:
	return Settings.tutorial_mode


## 教程挖洞：按锚点名返回全局矩形；缺失时返回空矩形。
func get_tutorial_hole(anchor_id: String) -> Rect2:
	match anchor_id:
		"mission":
			if _progress_panel != null and is_instance_valid(_progress_panel):
				return _progress_panel.get_global_rect()
		"hp", "ap", "hunger", "monster_zone", "sneak":
			var self_panel: PlayerPanel = _get_self_panel()
			if self_panel != null:
				return self_panel.get_element_rect(anchor_id)
		"hand":
			if _hand_area != null and is_instance_valid(_hand_area):
				return _hand_area.get_global_rect()
		"game_deck":
			return _pile_manager.get_pile_rect("game_deck")
		"scavenge":
			return _pile_manager.get_piles_union_rect(["red_scavenge", "green_scavenge", "blue_scavenge"])
		"action_rest":
			return _pile_manager.get_piles_union_rect([
				"game_deck", "red_scavenge", "green_scavenge", "blue_scavenge",
			])
		"avatar":
			return _table_map_controller.get_current_player_avatar_rect()
		"spawn_mark":
			return _table_map_controller.get_marked_blocks_rect()
		"skills":
			return _active_skill_bar.get_bar_rect()
	return Rect2()


func _get_self_panel() -> PlayerPanel:
	if _player_panels.is_empty():
		return null
	var panel: PlayerPanel = _player_panels[0]
	if panel != null and is_instance_valid(panel):
		return panel
	return null


func _input(event: InputEvent) -> void:
	if _is_wiki_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_action_selection_controller.handle_shortcut(event.keycode, _popup_manager.is_popup_open())


# === 玩家面板 ===

func _build_player_panels() -> void:
	_player_panels.clear()
	_player_to_panel_idx.clear()
	# 面板 0 = self（底部大面板），面板 1-5 = teammates（最多 6 人）
	for i in range(6):
		var panel := PlayerPanel.new()
		panel.set_anchors_preset(PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui_layer.add_child(panel)
		panel.set_panel_index(i)
		panel.monster_zone_clicked.connect(_on_monster_zone_clicked)
		panel.equipment_zone_clicked.connect(_on_equipment_zone_clicked)
		panel.hand_clicked.connect(_on_hand_clicked)
		_player_panels.append(panel)


## 将玩家分配到面板：当前回合玩家 → self 面板，其他玩家 → teammate 面板（按座位顺序）。
func _assign_player_panels() -> void:
	_player_to_panel_idx.clear()
	var turn_player: Variant = Game.get_current_player()
	# self 玩家：主机为当前回合玩家；客机为本地玩家（他人手牌隐藏）
	var self_player: Variant = _net_local_player()
	var others: Array = []
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		if self_player != null and is_instance_valid(self_player) and player == self_player:
			continue
		others.append(player)
	# self 面板
	if _player_panels.size() > 0:
		var self_panel: PlayerPanel = _player_panels[0]
		if self_player != null and is_instance_valid(self_player):
			self_panel.set_player(self_player, true)
			self_panel.set_current_turn(self_player == turn_player)
			_player_to_panel_idx[self_player.get_instance_id()] = 0
		else:
			self_panel.set_player(null, true)
	# teammate 面板（最多 5 个）
	for i in range(mini(others.size(), 5)):
		var teammate_panel: PlayerPanel = _player_panels[i + 1]
		teammate_panel.set_player(others[i], false)
		teammate_panel.set_current_turn(others[i] == turn_player)
		_player_to_panel_idx[others[i].get_instance_id()] = i + 1
	# 隐藏多余的面板
	for i in range(others.size() + 1, 6):
		if i < _player_panels.size():
			var empty_panel: PlayerPanel = _player_panels[i]
			empty_panel.set_player(null, i == 0)
			empty_panel.set_current_turn(false)


## 刷新显示指定玩家的面板。
func _refresh_panel_for_player(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var panel: PlayerPanel = _get_panel_for_player(player)
	if panel != null:
		panel.refresh(true)


## 查找玩家对应的面板（未分配面板或面板失效时返回 null）。
func _get_panel_for_player(player: Variant) -> PlayerPanel:
	if player == null or not is_instance_valid(player):
		return null
	var idx: Variant = _player_to_panel_idx.get(player.get_instance_id())
	if idx == null:
		return null
	var panel: PlayerPanel = _player_panels[idx]
	if panel != null and is_instance_valid(panel):
		return panel
	return null


## 刷新所有玩家面板。
func _refresh_all_panels() -> void:
	for panel in _player_panels:
		if panel != null and is_instance_valid(panel):
			panel.refresh(true)


# === 手牌区 ===

func _build_hand_area() -> void:
	_hand_area = HandDisplayArea.new()
	_hand_area.card_selected.connect(_action_selection_controller.on_card_selected)
	_hand_area.card_deselected.connect(_action_selection_controller.on_card_deselected)
	_ui_layer.add_child(_hand_area)
	_hand_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_selection_controller.set_hand_area(_hand_area)


## 刷新手牌区（主机显示当前回合玩家；客机只显示本地玩家手牌，隐藏他人手牌）。
func _refresh_hand_area() -> void:
	if _hand_area == null or not is_instance_valid(_hand_area):
		return
	var target: Variant = _net_local_player()
	_hand_area.set_player(target)


## 返回"我"的玩家视图：客机为本地座位对应玩家；主机有客户端连接时为主机自己的玩家，否则为当前回合玩家；单机为当前回合玩家。
func _net_local_player() -> Variant:
	if NetSession.mode == NetSession.Mode.HOST:
		if NetSession.get_peer_ids().is_empty():
			return Game.get_current_player()
		for i in range(RoomState.seats.size()):
			if int(RoomState.seats[i].get("peer_id", 0)) == NetSession.HOST_PEER_ID:
				for p in Game.players:
					if p != null and int(p.seat_number) == i:
						return p
				return Game.get_current_player()
		return Game.get_current_player()
	if NetSession.mode == NetSession.Mode.CLIENT:
		for i in range(RoomState.seats.size()):
			if int(RoomState.seats[i].get("peer_id", 0)) == NetSession.peer_id:
				for p in Game.players:
					if p != null and int(p.seat_number) == i:
						return p
				return null
		return Game.get_current_player()
	return Game.get_current_player()


## 当前是否轮到本地玩家行动：单机恒为 true；联网时仅当本地玩家 == 当前回合玩家。
func _net_is_local_action() -> bool:
	if NetSession.mode == NetSession.Mode.NONE:
		return true
	return _net_local_player() != null and Game.get_current_player() != null and _net_local_player() == Game.get_current_player()


# === Block/Avatar 点击 ===

func _on_block_clicked(block: Variant) -> void:
	if _action_selection_controller.is_in_move_mode():
		_action_selection_controller.on_move_block_selected(block)


func _on_block_inspected(block: Variant) -> void:
	_popup_manager.show_block_detail_popup(block)


func _on_avatar_clicked(_block: Variant) -> void:
	_action_selection_controller.enter_move_select_mode()


# === Move mode changed ===

func _on_move_mode_changed(active: bool) -> void:
	var valid_blocks: Array = []
	var selected_blocks: Array = []
	if active:
		selected_blocks = _action_selection_controller.get_move_selected_blocks()
		if _action_selection_controller.is_card_move_mode():
			valid_blocks = _action_selection_controller.get_card_move_valid_blocks()
		else:
			var current: Variant = Game.get_current_player()
			if current != null and is_instance_valid(current):
				var current_block: Variant = current.get("current_block")
				if current_block != null and is_instance_valid(current_block):
					valid_blocks = current_block.get_adjacent_blocks()
	_table_map_controller.refresh_move_highlights(active, valid_blocks, selected_blocks)
	if not active:
		_table_map_controller.refresh_map()
	_action_selection_controller.refresh_confirm_cancel_buttons()


func _on_card_move_select_completed(blocks: Variant) -> void:
	_gui_input.respond_choose_block(blocks)


# === Pile 点击 ===

func _on_pile_clicked(pile_key: String) -> void:
	if _action_selection_controller.is_busy():
		return
	if not _pile_manager.is_pile_clickable(pile_key):
		return
	_action_selection_controller.on_pile_selected(pile_key, _pile_manager.pile_display_name(pile_key))


func _on_discard_pile_clicked(pile_type: String) -> void:
	if pile_type == "scavenge":
		_popup_manager.show_scavenge_discard_popup()
	elif pile_type == "game":
		_popup_manager.show_game_discard_popup()


# === Skill pressed ===

func _on_skill_pressed(skill: Variant) -> void:
	if _action_selection_controller.is_busy():
		return
	_action_selection_controller.enter_skill_confirm_mode(skill)


# === Action/Confirm from controller ===

func _on_action_from_controller(action: Dictionary) -> void:
	if action.is_empty():
		_gui_input.respond_action(null)
	else:
		_gui_input.respond_action(action)


func _on_confirm_from_controller(result: bool) -> void:
	_gui_input.respond_confirm(result)


func _on_popup_block_selected(block: Variant) -> void:
	if _action_selection_controller.is_in_move_mode():
		return
	_gui_input.respond_choose_block(block)


# === Settings ===

func _on_settings_pressed() -> void:
	if _is_wiki_open():
		return
	if _settings_popup == null or not is_instance_valid(_settings_popup):
		_build_settings_popup()
	# 在设置按钮下方弹出菜单
	var btn_rect: Rect2 = _settings_button.get_global_rect()
	_settings_popup.position = Vector2i(int(btn_rect.position.x), int(btn_rect.end.y))
	_settings_popup.popup()


func _is_wiki_open() -> bool:
	return _wiki_overlay != null and is_instance_valid(_wiki_overlay)


func _on_wiki_pressed() -> void:
	if _is_wiki_open():
		return
	_wiki_overlay = WIKI_OVERLAY_SCENE.instantiate()
	_popup_layer.add_child(_wiki_overlay)
	_wiki_overlay.closed.connect(func() -> void: _wiki_overlay = null)


## 构建设置弹出菜单（"设置" + "返回主菜单"）。
func _build_settings_popup() -> void:
	_settings_popup = PopupMenu.new()
	_settings_popup.add_item("设置", 0)
	_settings_popup.add_item("返回主菜单", 1)
	_settings_popup.id_pressed.connect(_on_settings_popup_id_pressed)
	add_child(_settings_popup)


## 设置弹出菜单项点击处理。
func _on_settings_popup_id_pressed(id: int) -> void:
	match id:
		0:
			# 打开设置对话框
			var dialog := SETTINGS_DIALOG_SCENE.instantiate()
			add_child(dialog)
			dialog.popup_centered(Vector2i(360, 180))
		1:
			# 返回主菜单
			Game.state_machine.current_state = GameStateMachine.GameState.WAITING
			Game.players.clear()
			Game.map_area.clear()
			RoomState.clear()
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# === GUIPlayerInput 信号处理 ===

func _on_action_requested(_player: Variant) -> void:
	_active_skill_bar.refresh(_net_local_player())
	_action_selection_controller.refresh_confirm_cancel_buttons()
	_pile_manager.refresh_pile_highlights()


func _on_choose_requested(options: Array, prompt: String) -> void:
	_popup_manager.show_option_popup(options, prompt)


func _on_confirm_requested(message: String) -> void:
	_action_selection_controller.set_confirm_mode(message)


func _on_choose_card_requested(n: int, param: Variant, filter: Variant, prompt: String, min_n: int) -> void:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		_gui_input.respond_choose_card([])
		return
	var cards: Array = []
	var label: String = ""
	if typeof(param) == TYPE_ARRAY:
		# Array 模式：直接作为候选卡牌列表，绕过 position 查询
		cards = param
		label = "候选列表"
	else:
		# String 模式（原有行为）：按 position 查询玩家区域卡牌
		var position: String = param
		if current.has_method("get_cards"):
			cards = current.get_cards(position)
		label = position
	# filter_card 过滤候选卡牌
	if filter is Callable and filter.is_valid():
		var filtered: Array = []
		for card in cards:
			if filter.call(current, card, {}, Game):
				filtered.append(card)
		cards = filtered
	# 构建区域标签（单一区域时不显示，混合区域时自动显示）
	var zone_labels: Array = []
	var zone_name: String = ""
	if typeof(param) == TYPE_ARRAY:
		# Array 模式：根据每张卡牌实际所在区域设置标签
		for card in cards:
			if card is Equipment:
				zone_labels.append("装备区")
			elif current.has_method("get") and "hand" in current and current.hand.has(card):
				zone_labels.append("手牌区")
			else:
				zone_labels.append("候选列表")
	else:
		match param:
			"hand":
				zone_name = "手牌区"
			"equipment":
				zone_name = "装备区"
			_:
				zone_name = str(param)
		for i in range(cards.size()):
			zone_labels.append(zone_name)
	_popup_manager.show_card_select_popup(cards, n, label, zone_labels, prompt, min_n)


## 目标弹窗确认后先播放 A→B 指向动画，再恢复等待中的 choose_target 请求。
func _on_popup_targets_selected(targets: Array) -> void:
	var source: Variant = _pending_target_source
	_pending_target_source = null
	if targets.is_empty() or source == null or not is_instance_valid(source):
		_gui_input.respond_choose_target(targets)
		return
	var source_panel: PlayerPanel = _get_panel_for_player(source)
	if source_panel == null:
		_gui_input.respond_choose_target(targets)
		return
	var player_positions: Array[Vector2] = []
	var monsters: Array = []
	for target in targets:
		if target is Player and is_instance_valid(target):
			var target_panel: PlayerPanel = _get_panel_for_player(target)
			if target_panel != null:
				player_positions.append(target_panel.get_role_card_global_position())
		elif target is Monster and is_instance_valid(target):
			monsters.append(target)
	if player_positions.is_empty() and monsters.is_empty():
		_gui_input.respond_choose_target(targets)
		return
	await _animation_controller.play_target_links(source_panel.get_role_card_global_position(), player_positions, monsters)
	_gui_input.respond_choose_target(targets)


func _on_choose_target_requested(n: int, skill: Variant, prompt: String, min_n: int) -> void:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		_gui_input.respond_choose_target([])
		return
	_pending_target_source = current
	var current_block: Variant = current.get("current_block")
	# 读取 skill 的 target_type / filter_target_range（兼容 skill 为 null / Dictionary / Object）
	var target_type: String = ""
	var filter_target_range: String = "short"
	if skill != null:
		var tt: Variant = null
		var ftr: Variant = null
		if skill is Dictionary:
			tt = skill.get("target_type", null)
			ftr = skill.get("filter_target_range", null)
		elif is_instance_valid(skill):
			tt = skill.get("target_type")
			ftr = skill.get("filter_target_range")
		if tt != null:
			target_type = str(tt)
		if ftr != null and str(ftr) != "":
			filter_target_range = str(ftr)
	# 按 target_type 构建候选
	var candidates: Array = []
	match target_type:
		"block":
			# 候选为地块：当前地块射程内的所有存活地块
			if current_block != null and is_instance_valid(current_block):
				candidates = current_block.get_blocks_in_range(filter_target_range)
		"equipment":
			# 候选为当前玩家装备区
			var eqz: Variant = current.get("equipment_zone")
			if eqz != null:
				candidates = eqz
		_:
			# entity（缺省）：当前地块射程内玩家 + 当前地块所有玩家（含当前玩家自身） + 当前玩家怪物区怪物
			if current_block != null and is_instance_valid(current_block):
				candidates = current_block.get_players_in_range(filter_target_range)
				# 追加当前地块所有玩家（含当前玩家自身），保证 self-targeting 技能可选自己
				candidates.append_array(current_block.get_players())
			var monster_zone: Variant = current.get("monster_zone")
			if monster_zone != null:
				for m in monster_zone:
					if m != null and is_instance_valid(m):
						candidates.append(m)
			# 新增：射程内其他玩家怪物区的怪物（用于 target.is_monster() 类型的卡牌如套索/闪光棒）
			if current_block != null and is_instance_valid(current_block):
				var players_in_range: Array = current_block.get_players_in_range(filter_target_range)
				for other_player in players_in_range:
					if other_player == null or not is_instance_valid(other_player):
						continue
					if other_player == current:
						continue  # 自己的怪物区已在上面处理
					if "monster_zone" in other_player:
						for m in other_player.monster_zone:
							if m != null and is_instance_valid(m) and not candidates.has(m):
								candidates.append(m)
			# 去重（按实例 id，避免 get_players_in_range 与 get_players 重叠）
			var seen: Dictionary = {}
			var deduped: Array = []
			for c in candidates:
				if c == null or not is_instance_valid(c):
					continue
				var key: int = c.get_instance_id()
				if seen.has(key):
					continue
				seen[key] = true
				deduped.append(c)
			candidates = deduped
	# filter_target 过滤候选
	var filtered: Array = []
	for target in candidates:
		if target == null or not is_instance_valid(target):
			continue
		var event := {"player": current, "target": target, "card": null}
		if _is_valid_target(skill, target, event, current):
			filtered.append(target)
	# 处理 select_target
	var select_n: int = n
	# 构建装备区 zone_labels（下方弹窗调用共用）
	var zone_labels: Array = []
	if target_type == "equipment":
		zone_labels = ["装备区"]
		for i in range(1, filtered.size()):
			zone_labels.append("装备区")
	# 合并 prompt 来源：优先参数 prompt，为空时从 skill 读 window_prompt
	var merged_prompt: String = prompt
	if merged_prompt.is_empty() and skill != null:
		if skill is Dictionary:
			merged_prompt = skill.get("window_prompt", "")
		elif is_instance_valid(skill):
			var wp: Variant = skill.get("window_prompt")
			if wp != null:
				merged_prompt = str(wp)
	if filtered.is_empty():
		# 无合法候选：直接返回空，不弹 UI
		_gui_input.respond_choose_target.call_deferred([])
		return
	if select_n == -1:
		# 全选模式
		if Settings.skip_target_selection:
			# 设置开启：自动选取全部过滤后候选，不弹 UI
			_gui_input.respond_choose_target.call_deferred(filtered)
		else:
			# 设置关闭：弹出目标选择区并预选全部，玩家确认后经 targets_selected -> respond_choose_target 回传
			_popup_manager.show_target_select_area(filtered, filtered.size(), zone_labels, merged_prompt, -1, true)
		return
	if select_n >= filtered.size():
		# 候选数 ≤ 所需数
		if Settings.skip_target_selection:
			# 设置开启：直接全选
			_gui_input.respond_choose_target.call_deferred(filtered)
		else:
			# 设置关闭：以候选数为选择数弹窗并预选全部，玩家确认后经 targets_selected -> respond_choose_target 回传
			_popup_manager.show_target_select_area(filtered, filtered.size(), zone_labels, merged_prompt, min_n, true)
		return
	# 弹出目标选择区
	_popup_manager.show_target_select_area(filtered, select_n, zone_labels, merged_prompt, min_n)


## 判断 target 是否通过 skill.filter_target 过滤。
## skill 为 null 时视为无过滤（恒通过）；filter_target 为空 Callable 时亦恒通过。
## filter_target 的 Callable 签名为 (player, target, event, game) -> bool。
func _is_valid_target(skill: Variant, target: Variant, event: Dictionary, player: Variant) -> bool:
	if skill == null:
		return true
	# Dictionary 类型：filter_target 为 String，需编译
	if skill is Dictionary:
		var fc_str: Variant = skill.get("filter_target", null)
		if fc_str == null:
			return true
		if fc_str is String:
			var filter_code: String = fc_str
			if filter_code.is_empty() or filter_code.strip_edges() == "true":
				return true
			var compiled: Callable = CodeExecutor.compile_filter_target(filter_code)
			if not compiled.is_valid():
				return true
			return compiled.call(player, target, event, Game)
		if fc_str is Callable:
			var filter_callable: Callable = fc_str
			if not filter_callable.is_valid():
				return true
			return filter_callable.call(player, target, event, Game)
		return true
	# Object 类型（Skill 实例）：filter_target 为 Callable
	if not is_instance_valid(skill):
		return true
	var fc: Variant = skill.get("filter_target")
	if fc == null or not (fc is Callable):
		return true
	var filter_callable: Callable = fc
	if not filter_callable.is_valid():
		return true
	return filter_callable.call(player, target, event, Game)


func _on_choose_block_requested(blocks: Array, prompt: String) -> void:
	_popup_manager.show_block_select_popup(blocks, prompt)


func _on_choose_block_inline_requested(valid_blocks: Array, prompt: String, count: int) -> void:
	_action_selection_controller.enter_block_select_mode(prompt, valid_blocks, count, "card")


func _on_show_card_requested(card: Card, _target: Variant) -> void:
	if card == null or not is_instance_valid(card):
		return
	_popup_manager.show_card_detail_popup(card)


func _on_set_prompt_requested(text: String) -> void:
	_action_selection_controller.set_prompt_text(text)


func _on_redraw_decision_requested() -> void:
	_action_selection_controller.enter_round_zero_mode("是否执行\"重调\": 重新抓取初始手牌", 30.0)


# 检定确认门：进入确认模式，5 秒超时默认确定
func _on_judge_confirm_requested(prompt: String, allow_cancel: bool) -> void:
	_action_selection_controller.enter_judge_confirm_mode(prompt, 5.0, allow_cancel)


# 骰子投掷动画：播放完毕后结算响应，阻塞后续请求派发
func _on_dice_animation_requested(d1: int, d2: int, label: String, outcome: String) -> void:
	await _animation_controller.play_dice(d1, d2, label, outcome)
	_gui_input.respond_dice_animation()


# 怪物抓取动画：飞行终点取该玩家面板怪物区按钮的全局中心位置，
# 面板不存在或按钮无效时终点为 Vector2.ZERO（视图原地淡出）；播放完毕后结算响应，阻塞后续请求派发
func _on_monster_draw_animation_requested(player: Variant, card: Variant) -> void:
	var target_position: Vector2 = Vector2.ZERO
	var panel: PlayerPanel = _get_panel_for_player(player)
	if panel != null:
		target_position = panel.get_monster_zone_button_global_position()
	await _animation_controller.play_monster_draw(card, target_position)
	_gui_input.respond_monster_draw_animation()


# 拾荒牌"抓取时"技能触发动画：原地放大淡出（无飞行终点）；播放完毕后结算响应，阻塞后续请求派发
func _on_scavenge_draw_animation_requested(_player: Variant, card: Variant) -> void:
	await _animation_controller.play_scavenge_draw(card)
	_gui_input.respond_scavenge_draw_animation()


## 卡牌销毁动画：居中焚毁卡面，结束后释放等待中的销毁事件。
func _on_card_destroy_animation_requested(card: Card) -> void:
	await _animation_controller.play_card_destroy(card)
	_gui_input.respond_card_destroy_animation()
	# 回执会恢复 Player.remove_card 的后续流程，实际从 hand 移除发生在下一帧。
	# 若不在实体移除后刷新，HandDisplayArea 会继续保留已经销毁的 CardView。
	await get_tree().process_frame
	_refresh_hand_area()


# 怪物技能触发动画：播放完毕后结算响应，阻塞后续请求派发
func _on_monster_skill_trigger_animation_requested(monster: Variant) -> void:
	await _animation_controller.play_monster_skill_trigger(monster)
	_gui_input.respond_monster_skill_trigger_animation()


# 怪物攻击动画：飞行终点取各目标玩家面板角色牌的全局中心位置，
# 面板不存在或目标无效时跳过该目标；播放完毕后结算响应，阻塞后续请求派发
func _on_monster_attack_animation_requested(monster: Variant, targets: Array) -> void:
	var positions: Array = []
	for target in targets:
		if target is Player and is_instance_valid(target):
			var target_panel: PlayerPanel = _get_panel_for_player(target)
			if target_panel != null:
				positions.append(target_panel.get_role_card_global_position())
	await _animation_controller.play_monster_attack(monster, positions)
	_gui_input.respond_monster_attack_animation()


# === EventBus 信号处理 ===

func _on_turn_started(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	_assign_player_panels()
	_table_map_controller.refresh_map()
	_refresh_hand_area()
	_pile_manager.refresh_pile_counts()
	_action_selection_controller.refresh_confirm_cancel_buttons()
	# 回合切换横幅
	_animation_controller.play_turn_banner("座位%d %s的回合" % [player.get("seat_number") + 1, player.player_name])
	# 当前回合玩家面板呼吸高亮，其余面板恢复普通边框（死亡面板由 set_turn_highlight 内部处理）
	for panel in _player_panels:
		if panel != null and is_instance_valid(panel):
			panel.set_turn_highlight(panel._player == player)


func _on_phase_changed(_player: Variant, _old_phase: String, new_phase: String) -> void:
	_action_selection_controller.refresh_confirm_cancel_buttons()
	_pile_manager.refresh_pile_highlights()
	if new_phase != "action" or not _net_is_local_action():
		_active_skill_bar.clear()
		_action_selection_controller.clear_for_non_action_phase()


func _on_player_moved(player: Variant, source_block: Variant, target_block: Variant) -> void:
	var src_view: Variant = _table_map_controller.get_block_view(source_block)
	var dst_view: Variant = _table_map_controller.get_block_view(target_block)
	if src_view != null and dst_view != null and player != null and is_instance_valid(player):
		await _table_map_controller.play_avatar_move(player, source_block, target_block)
	_table_map_controller.refresh_map()
	_refresh_all_panels()
	_pile_manager.refresh_pile_highlights()
	# 移动完成后地块技能/任务行动技能已挂载/卸载，刷新技能栏
	_active_skill_bar.refresh(_net_local_player())


func _on_block_revealed(block: Variant, _player: Variant) -> void:
	# refresh 前先取该地块视图，refresh 后播放翻入动画（叠加在揭示样式之上）
	var view: Variant = _table_map_controller.get_block_view(block)
	_table_map_controller.refresh_map()
	if view != null and is_instance_valid(view):
		view.play_reveal_animation()


func _on_block_destroyed(block: Variant, _source: Variant) -> void:
	# 已摧毁的地块从 Game.map_area 移除，但仍保留视图显示"已摧毁"状态
	if block == null or not is_instance_valid(block):
		return
	var view: Variant = _table_map_controller.get_block_view(block)
	if view != null and is_instance_valid(view):
		view.refresh(false)
		# 摧毁灰化下沉动画（fire-and-forget，叠加在摧毁样式之上）
		view.play_destroyed_animation()


func _on_block_mark_changed(block: Variant) -> void:
	if block == null or not is_instance_valid(block):
		return
	var view: Variant = _table_map_controller.get_block_view(block)
	if view != null and is_instance_valid(view):
		# refresh 末尾会把 _last_mark_count 覆盖为当前值，旧值必须在 refresh 之前读取
		var old_count: int = view.get_last_mark_count()
		var new_count: int = block.count_monster_mark()
		var current: Variant = Game.get_current_player()
		var current_block: Variant = null
		if current != null and is_instance_valid(current):
			current_block = current.get("current_block")
		var is_current: bool = (current_block != null and is_instance_valid(current_block)
			and block == current_block)
		view.refresh(is_current, current)
		# 标记数变化时播放弹入/淡出反馈（objective_mark_changed 复用本 handler，标记数不变则不播）
		if new_count != old_count:
			view.play_mark_pulse(new_count > old_count)
		_refresh_all_panels()


func _on_monster_changed(_monster: Variant, _player: Variant) -> void:
	# 怪物生成/死亡影响地块上的怪物标记显示和玩家面板的怪物区
	_table_map_controller.refresh_map()
	_refresh_all_panels()
	_pile_manager.refresh_pile_counts()


## 怪物死亡：保留 _on_monster_changed 的刷新逻辑，并令持有者面板怪物区按钮脉冲（fire-and-forget）。
func _on_monster_died(monster: Variant, source: Variant) -> void:
	_on_monster_changed(monster, source)
	var holder: Variant = _find_monster_holder(monster)
	if holder == null:
		return
	var panel: PlayerPanel = _get_panel_for_player(holder)
	if panel != null:
		panel.play_monster_pulse()


## 查找怪物持有者（怪物区中包含该怪物的玩家）。
## 怪物死亡发射 monster_died 前已被移出怪物区，此时回退以其纠缠对象（attack_target，即原持有者）判定。
func _find_monster_holder(monster: Variant) -> Variant:
	if monster == null or not is_instance_valid(monster):
		return null
	if Game != null and is_instance_valid(Game):
		for p in Game.players:
			if p == null or not is_instance_valid(p):
				continue
			if "monster_zone" in p and p.monster_zone.has(monster):
				return p
	var engaged: Variant = monster.get("attack_target")
	if engaged != null and is_instance_valid(engaged):
		return engaged
	return null


func _on_monster_engaged_target_changed(_monster: Variant, old_target: Variant, new_target: Variant) -> void:
	# 纠缠目标变更后，刷新原目标与新目标各自面板的怪物区显示
	_refresh_panel_for_player(old_target)
	if new_target != old_target:
		_refresh_panel_for_player(new_target)


func _on_player_stat_changed(player: Variant, _arg1: Variant = null, _arg2: Variant = null) -> void:
	_refresh_panel_for_player(player)
	# 若是当前玩家，刷新手牌区、牌堆数与主动技能区（装备变化会增减主动技能）
	var current: Variant = Game.get_current_player()
	if player != null and is_instance_valid(player) and current != null and is_instance_valid(current) and player == current:
		_refresh_hand_area()
		_pile_manager.refresh_pile_counts()
		_pile_manager.refresh_pile_highlights()
		_active_skill_bar.refresh(_net_local_player())
		_action_selection_controller.refresh_confirm_cancel_buttons()


## 玩家受伤反馈：目标面板红闪 +「-N」飘字；来源为怪物时面板再震动（均 fire-and-forget）。
func _on_damage_taken(target: Variant, source: Variant, amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (target.has_method("is_player") and target.is_player()):
		return
	var panel: PlayerPanel = _get_panel_for_player(target)
	if panel == null:
		return
	panel.play_damage_feedback(amount)
	# 怪物判定与 tutorial_manager 一致：get("monster_type") 非 null 即怪物
	if source != null and is_instance_valid(source) and source.get("monster_type") != null:
		panel.play_shake()


## 玩家回血反馈：面板绿色「+N」飘字（fire-and-forget）。
func _on_hp_recovered(player: Variant, amount: int) -> void:
	var panel: PlayerPanel = _get_panel_for_player(player)
	if panel != null:
		panel.play_heal_feedback(amount)


## 饥饿值变化：保留原 _on_player_stat_changed 刷新逻辑，并令面板黄闪提醒（fire-and-forget）。
func _on_hunger_changed(player: Variant, old_value: int, new_value: int) -> void:
	_on_player_stat_changed(player, old_value, new_value)
	var panel: PlayerPanel = _get_panel_for_player(player)
	if panel != null:
		panel.play_hunger_flash()


## 行动数消耗：保留原 _on_player_stat_changed 刷新逻辑，并令面板行动标签弹跳（fire-and-forget）。
func _on_action_consumed(player: Variant, num: int) -> void:
	_on_player_stat_changed(player, num)
	var panel: PlayerPanel = _get_panel_for_player(player)
	if panel != null:
		panel.play_action_bounce()


func _on_pile_drawn(_player: Variant, _card: Variant) -> void:
	_pile_manager.refresh_pile_counts()
	_pile_manager.refresh_pile_highlights()
	_refresh_panel_for_player(_player)
	# 若摸牌玩家为当前回合玩家，刷新手牌展示区
	var current: Variant = Game.get_current_player()
	if _player != null and is_instance_valid(_player) and current != null and is_instance_valid(current) and _player == current:
		_refresh_hand_area()


# === 玩家面板点击处理 ===

func _on_monster_zone_clicked(player: Variant) -> void:
	_popup_manager.show_monster_zone_popup(player)


func _on_equipment_zone_clicked(player: Variant) -> void:
	_popup_manager.show_equipment_zone_popup(player)


func _on_hand_clicked(player: Variant) -> void:
	_popup_manager.show_hand_popup(player)


# === Log/Mission ===

func _on_log_button_pressed() -> void:
	_popup_manager.show_event_log_popup(_event_log)


func _on_mission_button_pressed() -> void:
	_popup_manager.show_mission_detail_popup()


# === 事件日志 ===

func _on_log_message(message: String) -> void:
	_event_log.append(message)
	if _event_log.size() > 500:
		_event_log.pop_front()


# === Game over ===

func _on_game_over(_result: int) -> void:
	_popup_manager.close_popup()
	# 黑色全屏覆盖层，渐变过渡到结算场景
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_popup_layer.add_child(overlay)
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.5)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/GameResult.tscn")
	)
