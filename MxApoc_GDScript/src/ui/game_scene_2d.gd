extends Control

## 2D 试玩版游戏主场景。
## 层结构：TableLayer（桌子+地图，可平移）/ UILayer（固定 UI）/ PopupLayer（弹窗）。
## 游戏流程：_ready() → 创建子模块 → initialize_game() → 注入 GUIPlayerInput → start_game()。

const SETTINGS_DIALOG_SCENE := preload("res://scenes/SettingsDialog.tscn")
const TUTORIAL_DIALOG_SCENE := preload("res://scenes/TutorialDialog.tscn")
const TutorialManager = preload("res://src/ui/tutorial_manager.gd")

# === 层节点（来自 .tscn）===
@onready var _table_layer: CanvasLayer = $TableLayer
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _popup_layer: CanvasLayer = $PopupLayer

# === UI 元素（来自 .tscn）===
@onready var _top_bar: HBoxContainer = $UILayer/TopBar
@onready var _phase_label: Label = $UILayer/TopBar/PhaseLabel
@onready var _current_player_label: Label = $UILayer/TopBar/CurrentPlayerLabel
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

# === 游戏状态 ===
var _gui_input: GUIPlayerInput

# === 设置弹出菜单 ===
var _settings_popup: PopupMenu

# === 玩家面板 ===
var _player_panels: Array = []
var _player_to_panel_idx: Dictionary = {}

# === 手牌区 ===
var _hand_area: HandDisplayArea

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

	_active_skill_bar = ActiveSkillBar.new()
	_active_skill_bar.setup(_active_skill_grid)
	add_child(_active_skill_bar)

	_event_log_panel = EventLogPanel.new()
	_ui_layer.add_child(_event_log_panel)

	_table_map_controller.block_clicked.connect(_on_block_clicked)
	_table_map_controller.avatar_clicked.connect(_on_avatar_clicked)
	_pile_manager.pile_clicked.connect(_on_pile_clicked)
	_pile_manager.discard_pile_clicked.connect(_on_discard_pile_clicked)
	_action_selection_controller.action_requested.connect(_on_action_from_controller)
	_action_selection_controller.confirm_responded.connect(_on_confirm_from_controller)
	_action_selection_controller.move_mode_changed.connect(_on_move_mode_changed)
	_action_selection_controller.card_move_select_completed.connect(_on_card_move_select_completed)
	_active_skill_bar.skill_pressed.connect(_on_skill_pressed)


func _wire_static_buttons() -> void:
	_log_button.pressed.connect(_on_log_button_pressed)
	_mission_button.pressed.connect(_on_mission_button_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)


# === 游戏流程 ===

func _start_game_flow() -> void:
	var mission: MissionData = RoomState.selected_mission
	if RoomState.selected_mission_is_random:
		mission = null
	var variants: Dictionary = RoomState.variants
	var seats: Array = RoomState.seats

	Game.initialize_game(mission, variants, seats)
	_table_map_controller.build_table_and_map()
	_build_player_panels()
	_build_hand_area()
	_assign_player_panels()
	_pile_manager.refresh_pile_counts()

	_gui_input = GUIPlayerInput.new()
	_gui_input.action_requested.connect(_on_action_requested)
	_gui_input.choose_requested.connect(_on_choose_requested)
	_gui_input.choose_card_requested.connect(_on_choose_card_requested)
	_gui_input.choose_target_requested.connect(_on_choose_target_requested)
	_gui_input.choose_block_requested.connect(_on_choose_block_requested)
	_gui_input.choose_block_inline_requested.connect(_on_choose_block_inline_requested)
	_gui_input.confirm_requested.connect(_on_confirm_requested)
	_gui_input.show_card_requested.connect(_on_show_card_requested)
	_gui_input.set_prompt_requested.connect(_on_set_prompt_requested)
	_gui_input.redraw_decision_requested.connect(_on_redraw_decision_requested)
	_popup_manager.option_selected.connect(_gui_input.respond_choose)
	_popup_manager.confirm_responded.connect(_gui_input.respond_confirm)
	_popup_manager.cards_selected.connect(_gui_input.respond_choose_card)
	_popup_manager.targets_selected.connect(_gui_input.respond_choose_target)
	_popup_manager.block_selected.connect(_on_popup_block_selected)
	_action_selection_controller.redraw_decision_responded.connect(_gui_input.respond_redraw_decision)
	for player in Game.players:
		if player != null and is_instance_valid(player):
			player.input = _gui_input

	if EventBus != null and is_instance_valid(EventBus):
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
		EventBus.monster_died.connect(_on_monster_changed)
		EventBus.player_hp_changed.connect(_on_player_stat_changed)
		EventBus.player_hunger_changed.connect(_on_player_stat_changed)
		EventBus.player_died.connect(_on_player_stat_changed)
		EventBus.equipment_equipped.connect(_on_player_stat_changed)
		EventBus.equipment_unequipped.connect(_on_player_stat_changed)
		EventBus.action_consumed.connect(_on_player_stat_changed)
		EventBus.card_drawn.connect(_on_player_stat_changed)
		EventBus.card_discarded.connect(_on_player_stat_changed)
		EventBus.card_used.connect(_on_player_stat_changed)
		EventBus.scavenge_drawn.connect(_on_pile_drawn)
		EventBus.monster_card_drawn.connect(_on_pile_drawn)

	# 教程系统
	if Settings.tutorial_mode:
		var tutorial_dialog: CanvasLayer = TUTORIAL_DIALOG_SCENE.instantiate()
		add_child(tutorial_dialog)
		var tutorial_manager: Node = TutorialManager.new()
		add_child(tutorial_manager)
		tutorial_manager.start(tutorial_dialog)

	Game.start_game()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_action_selection_controller.handle_shortcut(event.keycode, _popup_manager.is_popup_open())


# === 玩家面板 ===

func _build_player_panels() -> void:
	_player_panels.clear()
	_player_to_panel_idx.clear()
	# 面板 0 = self（底部大面板），面板 1-3 = teammates
	for i in range(4):
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
	var current: Variant = Game.get_current_player()
	var others: Array = []
	for player in Game.players:
		if player == null or not is_instance_valid(player):
			continue
		if current != null and is_instance_valid(current) and player == current:
			continue
		others.append(player)
	# self 面板
	if _player_panels.size() > 0:
		var self_panel: PlayerPanel = _player_panels[0]
		if current != null and is_instance_valid(current):
			self_panel.set_player(current, true)
			self_panel.set_current_turn(true)
			_player_to_panel_idx[current.get_instance_id()] = 0
		else:
			self_panel.set_player(null, true)
	# teammate 面板（最多 3 个）
	for i in range(mini(others.size(), 3)):
		var teammate_panel: PlayerPanel = _player_panels[i + 1]
		teammate_panel.set_player(others[i], false)
		teammate_panel.set_current_turn(false)
		_player_to_panel_idx[others[i].get_instance_id()] = i + 1
	# 隐藏多余的面板
	for i in range(others.size() + 1, 4):
		if i < _player_panels.size():
			var empty_panel: PlayerPanel = _player_panels[i]
			empty_panel.set_player(null, i == 0)
			empty_panel.set_current_turn(false)


## 刷新显示指定玩家的面板。
func _refresh_panel_for_player(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var idx: Variant = _player_to_panel_idx.get(player.get_instance_id())
	if idx == null:
		return
	var panel: PlayerPanel = _player_panels[idx]
	if panel != null and is_instance_valid(panel):
		panel.refresh(true)


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


## 刷新手牌区（显示当前玩家的手牌）。
func _refresh_hand_area() -> void:
	if _hand_area == null or not is_instance_valid(_hand_area):
		return
	var current: Variant = Game.get_current_player()
	_hand_area.set_player(current)


# === Block/Avatar 点击 ===

func _on_block_clicked(block: Variant) -> void:
	if _action_selection_controller.is_in_move_mode():
		_action_selection_controller.on_move_block_selected(block)
	else:
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
	if _settings_popup == null or not is_instance_valid(_settings_popup):
		_build_settings_popup()
	# 在设置按钮下方弹出菜单
	var btn_rect: Rect2 = _settings_button.get_global_rect()
	_settings_popup.position = Vector2i(int(btn_rect.position.x), int(btn_rect.end.y))
	_settings_popup.popup()


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
	_update_phase_indicator()
	_active_skill_bar.refresh(Game.get_current_player())
	_action_selection_controller.refresh_confirm_cancel_buttons()
	_pile_manager.refresh_pile_highlights()


func _on_choose_requested(options: Array, prompt: String) -> void:
	_popup_manager.show_option_popup(options, prompt)


func _on_confirm_requested(message: String) -> void:
	_action_selection_controller.set_confirm_mode(message)


func _on_choose_card_requested(n: int, param: Variant, filter: Variant) -> void:
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
	_popup_manager.show_card_select_popup(cards, n, label, zone_labels)


func _on_choose_target_requested(n: int, skill: Variant) -> void:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		_gui_input.respond_choose_target([])
		return
	var current_block: Variant = current.get("current_block")
	# 读取 skill 的 target_type / filter_target_range（兼容 skill 为 null 的旧调用方）
	var target_type: String = ""
	var filter_target_range: String = "short"
	if skill != null and is_instance_valid(skill):
		var tt: Variant = skill.get("target_type")
		if tt != null:
			target_type = tt
		var ftr: Variant = skill.get("filter_target_range")
		if ftr != null and ftr != "":
			filter_target_range = ftr
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
	if select_n == -1:
		# 自动选取全部过滤后候选，不弹 UI
		_gui_input.respond_choose_target.call_deferred(filtered)
		return
	if filtered.is_empty():
		_gui_input.respond_choose_target.call_deferred([])
		return
	if select_n >= filtered.size():
		# 候选数 ≤ 所需数，直接全选
		_gui_input.respond_choose_target.call_deferred(filtered)
		return
	# 弹出目标选择区
	var zone_labels: Array = []
	if target_type == "equipment":
		zone_labels = ["装备区"]
		for i in range(1, filtered.size()):
			zone_labels.append("装备区")
	_popup_manager.show_target_select_area(filtered, select_n, zone_labels)


## 判断 target 是否通过 skill.filter_target 过滤。
## skill 为 null 时视为无过滤（恒通过）；filter_target 为空 Callable 时亦恒通过。
## filter_target 的 Callable 签名为 (player, target, event, game) -> bool。
func _is_valid_target(skill: Variant, target: Variant, event: Dictionary, player: Variant) -> bool:
	if skill == null or not is_instance_valid(skill):
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


# === EventBus 信号处理 ===

func _on_turn_started(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	_current_player_label.text = "座位%d %s的回合" % [player.get("seat_number") + 1, player.player_name]
	_update_phase_indicator()
	_assign_player_panels()
	_table_map_controller.refresh_map()
	_refresh_hand_area()
	_pile_manager.refresh_pile_counts()
	_action_selection_controller.refresh_confirm_cancel_buttons()


func _on_phase_changed(_player: Variant, _old_phase: String, new_phase: String) -> void:
	_update_phase_indicator()
	_action_selection_controller.refresh_confirm_cancel_buttons()
	_pile_manager.refresh_pile_highlights()
	if new_phase != "action":
		_active_skill_bar.clear()
		_action_selection_controller.clear_for_non_action_phase()


func _on_player_moved(_player: Variant, _source_block: Variant, _target_block: Variant) -> void:
	_table_map_controller.refresh_map()
	_refresh_all_panels()
	_pile_manager.refresh_pile_highlights()


func _on_block_revealed(_block: Variant, _player: Variant) -> void:
	_table_map_controller.refresh_map()


func _on_block_destroyed(block: Variant, _source: Variant) -> void:
	# 已摧毁的地块从 Game.map_area 移除，但仍保留视图显示"已摧毁"状态
	if block == null or not is_instance_valid(block):
		return
	var block_views: Dictionary = _table_map_controller.get_block_views()
	var view: Variant = block_views.get(block.get_instance_id())
	if view != null and is_instance_valid(view):
		view.refresh(false)


func _on_block_mark_changed(block: Variant) -> void:
	if block == null or not is_instance_valid(block):
		return
	var block_views: Dictionary = _table_map_controller.get_block_views()
	var view: Variant = block_views.get(block.get_instance_id())
	if view != null and is_instance_valid(view):
		var current: Variant = Game.get_current_player()
		var current_block: Variant = null
		if current != null and is_instance_valid(current):
			current_block = current.get("current_block")
		var is_current: bool = (current_block != null and is_instance_valid(current_block)
			and block == current_block)
		view.refresh(is_current, current)


func _on_monster_changed(_monster: Variant, _player: Variant) -> void:
	# 怪物生成/死亡影响地块上的怪物标记显示和玩家面板的怪物区
	_table_map_controller.refresh_map()
	_refresh_all_panels()
	_pile_manager.refresh_pile_counts()


func _on_player_stat_changed(player: Variant, _arg1: Variant = null, _arg2: Variant = null) -> void:
	_refresh_panel_for_player(player)
	# 若是当前玩家，刷新手牌区、牌堆数与主动技能区（装备变化会增减主动技能）
	var current: Variant = Game.get_current_player()
	if player != null and is_instance_valid(player) and current != null and is_instance_valid(current) and player == current:
		_refresh_hand_area()
		_pile_manager.refresh_pile_counts()
		_pile_manager.refresh_pile_highlights()
		_active_skill_bar.refresh(current)
		_action_selection_controller.refresh_confirm_cancel_buttons()
	_update_phase_indicator()


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


# === 回合指示器 ===

func _update_phase_indicator() -> void:
	var current: Variant = Game.get_current_player()
	var phase: String = "等待中"
	var action_info: String = ""
	if current != null and is_instance_valid(current):
		phase = _phase_display(current.get("in_phase"))
		if current.get("in_phase") == "action":
			action_info = "（剩余 %d/%d 行动）" % [current.get("action_count"), current.get("max_action_count")]
	_phase_label.text = "第 %d 轮 | %s%s" % [Game.state_machine.turn_number, phase, action_info]


func _phase_display(phase: String) -> String:
	match phase:
		"round_zero":
			return "重调阶段"
		"idle":
			return "等待中"
		"turn_start":
			return "回合开始"
		"monster_spawn":
			return "怪物生成"
		"draw":
			return "抽牌阶段"
		"action":
			return "行动阶段"
		"hunger":
			return "饥饿阶段"
		"poison":
			return "中毒阶段"
		"monster_action":
			return "怪物行动"
		"turn_end":
			return "回合结束"
		_:
			return phase


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
