extends Control

## 2D 试玩版游戏主场景。
## 层结构：TableLayer（桌子+地图，可平移）/ UILayer（固定 UI）/ PopupLayer（弹窗）。
## 游戏流程：_ready() → initialize_game() → 注入 GUIPlayerInput → start_game()。

const WINDOW_W := 1430
const WINDOW_H := 780
const BLOCK_SIZE := 144
const BLOCK_GAP := 4
const TABLE_MARGIN := 200
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
const SETTINGS_DIALOG_SCENE := preload("res://scenes/SettingsDialog.tscn")

# === 层节点（来自 .tscn）===
@onready var _table_layer: Control = $TableLayer
@onready var _ui_layer: Control = $UILayer
@onready var _popup_layer: Control = $PopupLayer

# === 桌子/摄像头 ===
var _table_bg: ColorRect
var _map_container: Node2D
var _table_size: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# === UI 元素（来自 .tscn）===
@onready var _top_bar: HBoxContainer = $UILayer/TopBar
@onready var _phase_label: Label = $UILayer/TopBar/PhaseLabel
@onready var _current_player_label: Label = $UILayer/TopBar/CurrentPlayerLabel
@onready var _log_button: Button = $UILayer/LogButton
@onready var _mission_button: Button = $UILayer/MissionButton
@onready var _settings_button: Button = $UILayer/SettingsButton
@onready var _wiki_button: Button = $UILayer/WikiButton
@onready var _active_skill_panel: Panel = $UILayer/ActiveSkillPanel
@onready var _active_skill_grid: GridContainer = $UILayer/ActiveSkillPanel/ActiveSkillScroll/ActiveSkillGrid

# === 游戏状态 ===
var _gui_input: GUIPlayerInput

# === 设置弹出菜单 ===
var _settings_popup: PopupMenu

# === 地图块视图缓存 ===
var _block_views: Dictionary = {}

# === 玩家面板 ===
# 4 个面板：[0]=self(底部大面板), [1-3]=teammates(顶部队友面板)
var _player_panels: Array = []
# 玩家 → 显示该玩家的面板索引
var _player_to_panel_idx: Dictionary = {}

# === 手牌区 ===
var _hand_area: HandDisplayArea

# === 卡牌选中状态 ===
var _selected_card: Variant = null
var _confirm_button: Button
var _cancel_end_button: Button
var _prompt_label: Label

# === 右侧牌堆 ===
var _pile_views: Dictionary = {}  # pile_key → {panel, label}，_wire_static_nodes 填充

# === 主动技能按钮区 ===
var _active_skill_buttons: Array = []

# === 弹窗状态 ===
var _popup_overlay: ColorRect = null
var _popup_selected: Array = []
var _popup_required_n: int = 0
var _popup_ok_button: Button = null
var _popup_item_views: Array = []

# === 事件日志 ===
var _event_log: Array = []


func _ready() -> void:
	_wire_static_nodes()
	_start_game_flow()


# === 静态节点接线（.tscn 中已构建的节点在这里连接信号 + 填充引用）===

func _wire_static_nodes() -> void:
	_log_button.pressed.connect(_on_log_button_pressed)
	_mission_button.pressed.connect(_on_mission_button_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	for config in PILE_CONFIGS:
		var panel: Panel = get_node("UILayer/" + config["node"])
		var label: Label = panel.get_node("CountLabel")
		_pile_views[config["key"]] = {"panel": panel, "label": label}
	# 弃牌堆面板点击
	var scavenge_discard_entry: Variant = _pile_views.get("scavenge_discard")
	if scavenge_discard_entry != null:
		var sd_panel: Panel = scavenge_discard_entry["panel"]
		sd_panel.gui_input.connect(_on_discard_pile_gui_input.bind("scavenge"))
	var game_discard_entry: Variant = _pile_views.get("game_discard")
	if game_discard_entry != null:
		var gd_panel: Panel = game_discard_entry["panel"]
		gd_panel.gui_input.connect(_on_discard_pile_gui_input.bind("game"))
	_apply_styles()


func _apply_styles() -> void:
	for config in PILE_CONFIGS:
		var entry: Variant = _pile_views.get(config["key"])
		if entry == null:
			continue
		entry["panel"].add_theme_stylebox_override("panel", _make_pile_style(config["color"]))
	_active_skill_panel.add_theme_stylebox_override("panel", _make_active_skill_style())


func _make_active_skill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	return style


# === 游戏流程 ===

func _start_game_flow() -> void:
	var mission: MissionData = RoomState.selected_mission
	if RoomState.selected_mission_is_random:
		mission = null
	var variants: Dictionary = RoomState.variants
	var seats: Array = RoomState.seats

	Game.initialize_game(mission, variants, seats)
	_build_table_and_map()
	_build_player_panels()
	_build_hand_area()
	_assign_player_panels()
	_refresh_pile_counts()

	_gui_input = GUIPlayerInput.new()
	_gui_input.action_requested.connect(_on_action_requested)
	_gui_input.choose_requested.connect(_on_choose_requested)
	_gui_input.choose_card_requested.connect(_on_choose_card_requested)
	_gui_input.choose_target_requested.connect(_on_choose_target_requested)
	_gui_input.choose_block_requested.connect(_on_choose_block_requested)
	_gui_input.confirm_requested.connect(_on_confirm_requested)
	_gui_input.show_card_requested.connect(_on_show_card_requested)
	for player in Game.players:
		if player != null and is_instance_valid(player):
			player.input = _gui_input

	if EventBus != null and is_instance_valid(EventBus):
		EventBus.turn_started.connect(_on_turn_started)
		EventBus.phase_changed.connect(_on_phase_changed)
		EventBus.log_message.connect(_on_log_message)
		EventBus.game_over.connect(_on_game_over)
		EventBus.player_moved.connect(_on_player_moved)
		EventBus.block_revealed.connect(_on_block_revealed)
		EventBus.block_destroyed.connect(_on_block_destroyed)
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

	Game.start_game()


# === 桌子 + 摄像头 + 地图渲染 ===

func _build_table_and_map() -> void:
	var mw: int = max(Game.map_width, 1)
	var mh: int = max(Game.map_height, 1)
	var map_pw: float = mw * (BLOCK_SIZE + BLOCK_GAP) - BLOCK_GAP
	var map_ph: float = mh * (BLOCK_SIZE + BLOCK_GAP) - BLOCK_GAP
	_table_size = Vector2(map_pw + TABLE_MARGIN * 2, map_ph + TABLE_MARGIN * 2)

	_map_container = Node2D.new()
	_map_container.position = Vector2(WINDOW_W / 2.0, WINDOW_H / 2.0)
	_table_layer.add_child(_map_container)

	_table_bg = ColorRect.new()
	_table_bg.position = -_table_size / 2.0
	_table_bg.size = _table_size
	_table_bg.color = Color(0.30, 0.32, 0.34, 1.0)
	_map_container.add_child(_table_bg)

	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		var view := MapBlockView.new()
		var coord: Dictionary = block.coordinate
		var bx: float = -map_pw / 2.0 + coord["x"] * (BLOCK_SIZE + BLOCK_GAP)
		var by: float = -map_ph / 2.0 + coord["y"] * (BLOCK_SIZE + BLOCK_GAP)
		view.position = Vector2(bx, by)
		_map_container.add_child(view)
		view.setup(block)
		_block_views[block.get_instance_id()] = view

	_refresh_map()


func _refresh_map() -> void:
	var current: Variant = Game.get_current_player()
	var current_block: Variant = null
	if current != null and is_instance_valid(current):
		current_block = current.get("current_block")
	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		var view: Variant = _block_views.get(block.get_instance_id())
		if view == null or not is_instance_valid(view):
			continue
		var is_current: bool = (current_block != null and is_instance_valid(current_block)
				and block == current_block)
		view.refresh(is_current)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
		if _dragging:
			_drag_start = event.position
	elif event is InputEventMouseMotion and _dragging and _map_container != null:
		_map_container.position += event.relative
		_clamp_camera()
	elif event is InputEventMouseButton and _map_container != null and event.pressed and _dragging:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_map(event.position, 1.0 + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_map(event.position, 1.0 - ZOOM_STEP)


func _clamp_camera() -> void:
	if _map_container == null:
		return
	var scaled_size: Vector2 = _table_size * _map_container.scale.x
	var half: Vector2 = scaled_size / 2.0
	# 桌子边缘不超出窗口；桌子小于窗口时允许在窗口内移动（min/max 统一处理两种情形）
	var min_x: float = min(half.x, WINDOW_W - half.x)
	var max_x: float = max(half.x, WINDOW_W - half.x)
	var min_y: float = min(half.y, WINDOW_H - half.y)
	var max_y: float = max(half.y, WINDOW_H - half.y)
	_map_container.position.x = clampf(_map_container.position.x, min_x, max_x)
	_map_container.position.y = clampf(_map_container.position.y, min_y, max_y)


## 以鼠标位置为锚点缩放地图。
func _zoom_map(anchor: Vector2, factor: float) -> void:
	var old_scale: float = _map_container.scale.x
	var new_scale: float = clampf(old_scale * factor, ZOOM_MIN, ZOOM_MAX)
	if abs(new_scale - old_scale) < 0.001:
		return
	var local_before: Vector2 = (anchor - _map_container.position) / old_scale
	_map_container.scale = Vector2(new_scale, new_scale)
	_map_container.position = anchor - local_before * new_scale
	_clamp_camera()


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
	_hand_area.card_selected.connect(_on_card_selected)
	_hand_area.card_deselected.connect(_on_card_deselected)
	_ui_layer.add_child(_hand_area)
	_hand_area.mouse_filter = Control.MOUSE_FILTER_STOP
	# 确定按钮
	_confirm_button = Button.new()
	_confirm_button.position = Vector2(575, 550)
	_confirm_button.size = Vector2(120, 30)
	_confirm_button.text = "确定"
	_confirm_button.add_theme_font_size_override("font_size", 14)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_ui_layer.add_child(_confirm_button)
	# 取消/结束回合 双用途按钮
	_cancel_end_button = Button.new()
	_cancel_end_button.position = Vector2(735, 550)
	_cancel_end_button.size = Vector2(120, 30)
	_cancel_end_button.text = "结束回合"
	_cancel_end_button.add_theme_font_size_override("font_size", 14)
	_cancel_end_button.disabled = true
	_cancel_end_button.pressed.connect(_on_cancel_end_pressed)
	_ui_layer.add_child(_cancel_end_button)
	# prompt 区
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(315, 590)
	_prompt_label.size = Vector2(800, 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1.0))
	_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("outline_size", 3)
	_ui_layer.add_child(_prompt_label)


## 刷新手牌区（显示当前玩家的手牌）。
func _refresh_hand_area() -> void:
	if _hand_area == null or not is_instance_valid(_hand_area):
		return
	var current: Variant = Game.get_current_player()
	_hand_area.set_player(current)


# === 卡牌选中处理 ===

func _on_card_selected(card: Variant) -> void:
	_selected_card = card
	_update_prompt(card)
	_refresh_confirm_cancel_buttons()


func _on_card_deselected() -> void:
	_selected_card = null
	_update_prompt(null)
	_refresh_confirm_cancel_buttons()


func _update_prompt(card: Variant) -> void:
	if _prompt_label == null or not is_instance_valid(_prompt_label):
		return
	if card == null or not is_instance_valid(card):
		_prompt_label.text = ""
		return
	var skills: Array = card.get("skills")
	if skills.is_empty():
		_prompt_label.text = card.get("card_name")
		return
	var first: Variant = skills[0]
	if first == null or not is_instance_valid(first):
		_prompt_label.text = card.get("card_name")
		return
	var desc: String = first.get("skill_description")
	if desc.is_empty():
		_prompt_label.text = card.get("card_name")
	else:
		_prompt_label.text = desc


func _on_confirm_pressed() -> void:
	if _selected_card == null or not is_instance_valid(_selected_card):
		return
	var current: Variant = Game.get_current_player()
	if current != null and is_instance_valid(current) and current.get("action_count") <= 0:
		return
	var card = _selected_card
	# 清空选中状态（会触发 _on_card_deselected）
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.clear_selection()
	if _gui_input != null and is_instance_valid(_gui_input):
		_gui_input.respond_action({"type": "card", "card": card})


func _on_cancel_end_pressed() -> void:
	if _selected_card != null:
		# 有卡牌选中 → 取消选中
		if _hand_area != null and is_instance_valid(_hand_area):
			_hand_area.clear_selection()
	else:
		# 无卡牌选中 + 行动次数=0 → 结束回合
		if _gui_input != null and is_instance_valid(_gui_input):
			_gui_input.respond_action(null)


## 双用途按钮 + 确定按钮状态刷新。
func _refresh_confirm_cancel_buttons() -> void:
	var current: Variant = Game.get_current_player()
	var in_action: bool = false
	var action_count: int = 0
	if current != null and is_instance_valid(current):
		in_action = (current.get("in_phase") == "action")
		action_count = current.get("action_count")
	# 确定按钮：有选中卡牌 + 行动阶段 + 行动次数>0
	if _confirm_button != null and is_instance_valid(_confirm_button):
		_confirm_button.disabled = not (_selected_card != null and in_action and action_count > 0)
	# 取消/结束回合 双用途按钮
	if _cancel_end_button != null and is_instance_valid(_cancel_end_button):
		if _selected_card != null:
			_cancel_end_button.text = "取消"
			_cancel_end_button.disabled = false
		elif in_action and action_count <= 0:
			_cancel_end_button.text = "结束回合"
			_cancel_end_button.disabled = false
		else:
			_cancel_end_button.text = "结束回合"
			_cancel_end_button.disabled = true


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
			_on_back_pressed()


# === 右侧牌堆 ===

const PILE_CONFIGS: Array = [
	{"key": "red_scavenge", "node": "RedScavengePile", "color": Color(0.55, 0.25, 0.25, 1.0), "label": "红拾荒"},
	{"key": "green_scavenge", "node": "GreenScavengePile", "color": Color(0.25, 0.55, 0.30, 1.0), "label": "绿拾荒"},
	{"key": "blue_scavenge", "node": "BlueScavengePile", "color": Color(0.25, 0.40, 0.60, 1.0), "label": "蓝拾荒"},
	{"key": "game_deck", "node": "GameDeckPile", "color": Color(0.40, 0.25, 0.55, 1.0), "label": "游戏牌堆"},
	{"key": "monster_pile", "node": "MonsterPile", "color": Color(0.18, 0.18, 0.20, 1.0), "label": "怪物牌堆"},
	{"key": "scavenge_discard", "node": "ScavengeDiscardPile", "color": Color(0.35, 0.30, 0.25, 1.0), "label": "拾荒弃牌"},
	{"key": "game_discard", "node": "GameDiscardPile", "color": Color(0.30, 0.25, 0.35, 1.0), "label": "角色弃牌"},
]


func _refresh_pile_counts() -> void:
	_set_pile_count("red_scavenge", _get_pile_count(Game.red_scavenge_pile))
	_set_pile_count("green_scavenge", _get_pile_count(Game.green_scavenge_pile))
	_set_pile_count("blue_scavenge", _get_pile_count(Game.blue_scavenge_pile))
	_set_pile_count("game_deck", _get_current_player_deck_count())
	_set_pile_count("monster_pile", _get_pile_count(Game.monster_pile))
	_set_pile_count("scavenge_discard", _get_pile_count(Game.scavenge_discard_pile))
	_set_pile_count("game_discard", _get_current_player_discard_count())


func _get_current_player_discard_count() -> int:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		return 0
	var pile: Variant = current.get("game_discard_pile")
	if pile == null or not is_instance_valid(pile):
		return 0
	return pile.size() if pile.has_method("size") else pile.get("cards").size()


func _set_pile_count(key: String, count: int) -> void:
	var entry: Variant = _pile_views.get(key)
	if entry == null:
		return
	var label: Label = entry["label"]
	var config: Variant = null
	for c in PILE_CONFIGS:
		if c["key"] == key:
			config = c
			break
	if config != null:
		label.text = config["label"] + "\n×%d" % count


func _get_pile_count(pile: Variant) -> int:
	if pile == null or not is_instance_valid(pile):
		return 0
	return pile.size() if pile.has_method("size") else pile.get("cards").size()


func _get_current_player_deck_count() -> int:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		return 0
	var deck: Variant = current.get("game_deck")
	if deck == null or not is_instance_valid(deck):
		return 0
	return deck.size() if deck.has_method("size") else deck.get("cards").size()


func _make_pile_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.15, 0.15, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


# === 主动技能按钮区 ===

func _refresh_active_skill_buttons() -> void:
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_active_skill_buttons.clear()

	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		return
	if current.get("in_phase") != "action":
		return

	for skill in current.get("skills"):
		if skill == null or not is_instance_valid(skill):
			continue
		if skill.get("active") == "":
			continue
		var btn := Button.new()
		btn.text = skill.skill_name
		btn.add_theme_font_size_override("font_size", 12)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		btn.disabled = not skill.is_usable()
		btn.pressed.connect(_on_active_skill_pressed.bind(skill))
		_active_skill_grid.add_child(btn)
		_active_skill_buttons.append(btn)


func _on_active_skill_pressed(skill: Skill) -> void:
	if _gui_input != null and is_instance_valid(_gui_input):
		_gui_input.respond_action({"type": "skill", "skill": skill})


# === 右侧按钮处理 ===

func _on_mission_button_pressed() -> void:
	_show_mission_detail_popup()


func _on_log_button_pressed() -> void:
	_show_event_log_popup()


# === GUIPlayerInput 信号处理 ===

func _on_action_requested(_player: Variant) -> void:
	_update_phase_indicator()
	_refresh_active_skill_buttons()
	_refresh_confirm_cancel_buttons()


func _on_choose_requested(options: Array, prompt: String) -> void:
	_show_option_popup(options, prompt)


func _on_confirm_requested(message: String) -> void:
	_show_confirm_popup(message)


func _on_choose_card_requested(n: int, param: Variant) -> void:
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
	_show_card_select_popup(cards, n, label)


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
		_gui_input.respond_choose_target(filtered)
		return
	if filtered.is_empty():
		_gui_input.respond_choose_target([])
		return
	if select_n >= filtered.size():
		# 候选数 ≤ 所需数，直接全选
		_gui_input.respond_choose_target(filtered)
		return
	# 弹出目标选择区
	_show_target_select_area(filtered, select_n)


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
	_show_block_select_popup(blocks, prompt)


func _on_show_card_requested(card: Card, _target: Variant) -> void:
	if card == null or not is_instance_valid(card):
		return
	_show_card_detail_popup(card)


# === 弹窗工具 ===

func _create_modal_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.4)
	_popup_layer.add_child(overlay)
	_popup_overlay = overlay
	return overlay


func _close_popup() -> void:
	if _popup_overlay != null and is_instance_valid(_popup_overlay):
		_popup_overlay.queue_free()
	_popup_overlay = null
	_popup_selected.clear()
	_popup_required_n = 0
	_popup_ok_button = null
	_popup_item_views.clear()


func _option_display_name(option: Variant) -> String:
	if option == null:
		return "无"
	if option is String:
		return option
	if option is Monster:
		return "%s (HP %d/%d)" % [option.monster_name, option.hp, option.max_hp]
	if option is Player:
		return option.player_name
	if option is Card:
		return option.card_name
	return str(option)


## 选项弹窗（choose）：点击选项立即响应
func _show_option_popup(options: Array, prompt: String) -> void:
	if options.is_empty():
		_gui_input.respond_choose(null)
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(565, 200)
	panel.size = Vector2(300, 50 + options.size() * 38)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt if prompt != "" else "请选择"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	for option in options:
		var btn := Button.new()
		btn.text = _option_display_name(option)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_option_selected.bind(option))
		vbox.add_child(btn)


func _on_option_selected(choice: Variant) -> void:
	_close_popup()
	_gui_input.respond_choose(choice)


## 确认弹窗（confirm）：Yes/No
func _show_confirm_popup(message: String) -> void:
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(515, 330)
	panel.size = Vector2(400, 120)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "确认"
	yes_btn.custom_minimum_size = Vector2(80, 30)
	yes_btn.pressed.connect(_on_confirm_responded.bind(true))
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "取消"
	no_btn.custom_minimum_size = Vector2(80, 30)
	no_btn.pressed.connect(_on_confirm_responded.bind(false))
	hbox.add_child(no_btn)


func _on_confirm_responded(result: bool) -> void:
	_close_popup()
	_gui_input.respond_confirm(result)


## 卡牌选择弹窗（choose_card）：选择 N 张卡牌
func _show_card_select_popup(cards: Array, n: int, position: String) -> void:
	if cards.is_empty():
		_gui_input.respond_choose_card([])
		return
	var overlay := _create_modal_overlay()
	_popup_required_n = n
	_popup_selected.clear()

	var panel := Panel.new()
	panel.position = Vector2(215, 80)
	panel.size = Vector2(1000, 560)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "选择 %d 张卡牌（从 %s）" % [n, position]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	_popup_item_views.clear()
	for card in cards:
		var view := CardView.new()
		view.set_card(card)
		view.gui_input.connect(_on_card_select_clicked.bind(card, view))
		grid.add_child(view)
		_popup_item_views.append(view)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var ok_btn := Button.new()
	ok_btn.text = "确认（0/%d）" % n
	ok_btn.custom_minimum_size = Vector2(140, 30)
	ok_btn.disabled = true
	ok_btn.pressed.connect(_on_card_select_confirmed)
	hbox.add_child(ok_btn)
	_popup_ok_button = ok_btn

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.pressed.connect(_on_card_select_cancelled)
	hbox.add_child(cancel_btn)


func _on_card_select_clicked(event: InputEvent, card: Variant, view: CardView) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx: int = _popup_selected.find(card)
		if idx >= 0:
			_popup_selected.remove_at(idx)
			view.set_selected(false)
		else:
			if _popup_selected.size() >= _popup_required_n:
				return
			_popup_selected.append(card)
			view.set_selected(true)
		if _popup_ok_button != null and is_instance_valid(_popup_ok_button):
			_popup_ok_button.text = "确认（%d/%d）" % [_popup_selected.size(), _popup_required_n]
			_popup_ok_button.disabled = _popup_selected.size() != _popup_required_n


func _on_card_select_confirmed() -> void:
	var cards: Array = _popup_selected.duplicate()
	_close_popup()
	_gui_input.respond_choose_card(cards)


func _on_card_select_cancelled() -> void:
	_close_popup()
	_gui_input.respond_choose_card([])


## 目标选择区（315,120 800×420）：仅选目标时弹出。
func _show_target_select_area(targets: Array, n: int) -> void:
	if targets.is_empty():
		_gui_input.respond_choose_target([])
		return
	var overlay := _create_modal_overlay()
	_popup_required_n = n
	_popup_selected.clear()
	var panel := Panel.new()
	panel.position = Vector2(315, 120)
	panel.size = Vector2(800, 420)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "选择 %d 个目标" % n
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for target in targets:
		var btn := Button.new()
		btn.text = _option_display_name(target)
		btn.custom_minimum_size = Vector2(180, 40)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_target_area_clicked.bind(target, btn))
		grid.add_child(btn)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	var ok_btn := Button.new()
	ok_btn.text = "确认（0/%d）" % n
	ok_btn.custom_minimum_size = Vector2(140, 30)
	ok_btn.disabled = true
	ok_btn.pressed.connect(_on_target_area_confirmed)
	hbox.add_child(ok_btn)
	_popup_ok_button = ok_btn
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.pressed.connect(_on_target_area_cancelled)
	hbox.add_child(cancel_btn)


func _on_target_area_clicked(target: Variant, btn: Button) -> void:
	var idx: int = _popup_selected.find(target)
	if idx >= 0:
		_popup_selected.remove_at(idx)
		btn.modulate = Color(1, 1, 1, 1)
	else:
		if _popup_selected.size() >= _popup_required_n:
			return
		_popup_selected.append(target)
		btn.modulate = Color(0.4, 0.8, 0.4, 1.0)
	if _popup_ok_button != null and is_instance_valid(_popup_ok_button):
		_popup_ok_button.text = "确认（%d/%d）" % [_popup_selected.size(), _popup_required_n]
		_popup_ok_button.disabled = _popup_selected.size() != _popup_required_n


func _on_target_area_confirmed() -> void:
	var targets: Array = _popup_selected.duplicate()
	_close_popup()
	_gui_input.respond_choose_target(targets)


func _on_target_area_cancelled() -> void:
	_close_popup()
	_gui_input.respond_choose_target([])


## 地块选择弹窗（choose_block）：选择 1 个地块
func _show_block_select_popup(blocks: Array, prompt: String) -> void:
	if blocks.is_empty():
		_gui_input.respond_choose_block(null)
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(515, 200)
	panel.size = Vector2(400, 50 + blocks.size() * 38)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt if prompt != "" else "选择地块"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	for block in blocks:
		var btn := Button.new()
		var bname: String = block.block_name if block != null and is_instance_valid(block) else "?"
		var coord: String = ""
		if block != null and is_instance_valid(block) and block.get("coordinate") != null:
			var c: Dictionary = block.coordinate
			coord = " (%d,%d)" % [c.get("x", 0), c.get("y", 0)]
		btn.text = bname + coord
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_block_selected.bind(block))
		vbox.add_child(btn)


func _on_block_selected(block: Variant) -> void:
	_close_popup()
	_gui_input.respond_choose_block(block)


## 卡牌详情弹窗（show_card）
func _show_card_detail_popup(card: Card) -> void:
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(615, 250)
	panel.size = Vector2(200, 260)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 8
	vbox.offset_right = -10
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var view := CardView.new()
	view.set_card(card)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(view)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_on_card_detail_closed)
	vbox.add_child(ok_btn)


func _on_card_detail_closed() -> void:
	_close_popup()


# === 详情弹窗（任务 #91） ===

func _show_mission_detail_popup() -> void:
	var mission: Variant = Game.current_mission
	if mission == null or not is_instance_valid(mission):
		return
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(365, 120)
	panel.size = Vector2(700, 480)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "任务：%s（%s）" % [mission.get("mission_name"), mission.get("difficulty_display")]
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var fuel: String = "无需"
	if mission.get("van_fuel_required") != null:
		fuel = str(mission.get("van_fuel_required"))
	var info := Label.new()
	info.text = "面包车燃料需求：%s    怪物包：%s" % [fuel, mission.get("monster_pack_type")]
	info.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info)

	var obj_label := Label.new()
	obj_label.text = "目标："
	obj_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(obj_label)

	var obj_text := Label.new()
	obj_text.text = mission.get("objective_text")
	obj_text.add_theme_font_size_override("font_size", 12)
	obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_text.custom_minimum_size = Vector2(660, 0)
	vbox.add_child(obj_text)

	var intro_label := Label.new()
	intro_label.text = "简介："
	intro_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(intro_label)

	var intro_text := Label.new()
	intro_text.text = mission.get("intro_text")
	intro_text.add_theme_font_size_override("font_size", 12)
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.custom_minimum_size = Vector2(660, 0)
	intro_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(intro_text)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


func _show_event_log_popup() -> void:
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(415, 100)
	panel.size = Vector2(600, 520)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "事件日志（最近 %d 条）" % mini(_event_log.size(), 100)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 1)
	scroll.add_child(content)

	var start_idx: int = maxi(0, _event_log.size() - 100)
	for i in range(start_idx, _event_log.size()):
		var msg: String = _event_log[i]
		var lbl := Label.new()
		if msg.begins_with("===="):
			lbl.text = msg
			lbl.add_theme_font_size_override("font_size", 12)
		else:
			lbl.text = "  " + msg
			lbl.add_theme_font_size_override("font_size", 11)
		content.add_child(lbl)

	if _event_log.is_empty():
		var empty := Label.new()
		empty.text = "暂无日志"
		empty.add_theme_font_size_override("font_size", 12)
		content.add_child(empty)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


# === 弃牌堆面板点击 ===

func _on_discard_pile_gui_input(event: InputEvent, pile_type: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if pile_type == "scavenge":
			_show_scavenge_discard_popup()
		elif pile_type == "game":
			_show_game_discard_popup()


func _show_scavenge_discard_popup() -> void:
	var cards: Array = []
	if Game.scavenge_discard_pile != null and is_instance_valid(Game.scavenge_discard_pile):
		cards = Game.scavenge_discard_pile.get("cards")
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(315, 100)
	panel.size = Vector2(800, 560)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "拾荒弃牌堆（%d 张）" % cards.size()
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "弃牌堆为空"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for card in cards:
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			view.set_card(card)
			grid.add_child(view)
	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


func _show_game_discard_popup() -> void:
	var cards: Array = []
	var current: Variant = Game.get_current_player()
	if current != null and is_instance_valid(current):
		var pile: Variant = current.get("game_discard_pile")
		if pile != null and is_instance_valid(pile):
			cards = pile.get("cards")
	var pname: String = "当前玩家"
	if current != null and is_instance_valid(current):
		pname = current.get("player_name")
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(315, 100)
	panel.size = Vector2(800, 560)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "%s 的角色弃牌堆（%d 张）" % [pname, cards.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "弃牌堆为空"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for card in cards:
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			view.set_card(card)
			grid.add_child(view)
	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


func _show_monster_zone_popup(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var monsters: Array = player.get("monster_zone")
	var pname: String = player.get("player_name")
	var overlay := _create_modal_overlay()

	var card_w: int = 120
	var card_h: int = 180
	var cols: int = 4
	var flow_w: int = cols * card_w + (cols - 1) * 8
	var rows: int = ceili(float(maxi(monsters.size(), 1)) / float(cols))
	var panel_w: int = flow_w + 32
	var panel_h: int = 50 + rows * (card_h + 8) + 50

	var panel := Panel.new()
	panel.position = Vector2((1430 - panel_w) / 2, (780 - panel_h) / 2)
	panel.size = Vector2(panel_w, panel_h)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s 的怪物区（%d 只）" % [pname, monsters.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	if monsters.is_empty():
		var empty := Label.new()
		empty.text = "无怪物"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(flow_w, 0)
		flow.add_theme_constant_override("separation", 8)
		flow.add_theme_constant_override("line_separation", 8)
		vbox.add_child(flow)
		for m in monsters:
			if m == null or not is_instance_valid(m):
				continue
			flow.add_child(_build_monster_card(m, card_w, card_h))

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


## 构建单个怪物卡片（120×180）：图片 + 属性叠加 + 彩色边框。
func _build_monster_card(m: Variant, w: int, h: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(w, h)
	card.size = Vector2(w, h)

	# 彩色边框：boss=红/elite=橙/normal=灰
	var level: String = m.get("monster_level")
	var border_color: Color = Color(0.4, 0.4, 0.4, 1.0)
	var border_w: int = 2
	if level == "boss":
		border_color = Color(0.85, 0.15, 0.15, 1.0)
		border_w = 4
	elif level == "elite":
		border_color = Color(0.9, 0.6, 0.1, 1.0)
		border_w = 3
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	style.border_width_left = border_w
	style.border_width_top = border_w
	style.border_width_right = border_w
	style.border_width_bottom = border_w
	style.border_color = border_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)

	# 怪物图片
	var tex: Texture2D = ImageCache.get_monster_texture(m.get("monster_name"))
	if tex != null:
		var img := TextureRect.new()
		img.set_anchors_preset(PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.texture = tex
		if m.get("stunned"):
			img.modulate = Color(0.5, 0.5, 0.8, 0.7)
		card.add_child(img)

	# HP/MaxHP（右上角）
	var hp_lbl := Label.new()
	hp_lbl.text = "%d/%d" % [m.get("hp"), m.get("max_hp")]
	hp_lbl.position = Vector2(w - 58, 4)
	hp_lbl.size = Vector2(54, 16)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_lbl.add_theme_constant_override("outline_size", 3)
	card.add_child(hp_lbl)

	# 攻击力（HP 下方）
	var atk_lbl := Label.new()
	atk_lbl.text = "攻 %d" % [m.get("damage_value")]
	atk_lbl.position = Vector2(w - 58, 21)
	atk_lbl.size = Vector2(54, 16)
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	atk_lbl.add_theme_font_size_override("font_size", 11)
	atk_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	atk_lbl.add_theme_constant_override("outline_size", 3)
	card.add_child(atk_lbl)

	# 怪物名（中下）
	var name_lbl := Label.new()
	name_lbl.text = m.get("monster_name")
	name_lbl.position = Vector2(4, h - 52)
	name_lbl.size = Vector2(w - 8, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 3)
	card.add_child(name_lbl)

	# 射程（名字下方）
	var range_map := {"none": "纠缠", "short": "短程", "medium": "中程", "long": "远程", "infinity": "无限"}
	var range_lbl := Label.new()
	range_lbl.text = "射程 " + range_map.get(m.get("range"), m.get("range"))
	range_lbl.position = Vector2(4, h - 32)
	range_lbl.size = Vector2(w - 8, 18)
	range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_lbl.add_theme_font_size_override("font_size", 11)
	range_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	range_lbl.add_theme_constant_override("outline_size", 3)
	card.add_child(range_lbl)

	# 眩晕标识（左上角）
	if m.get("stunned"):
		var stun_lbl := Label.new()
		stun_lbl.text = "眩晕"
		stun_lbl.position = Vector2(4, 4)
		stun_lbl.size = Vector2(34, 16)
		stun_lbl.add_theme_font_size_override("font_size", 10)
		stun_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
		stun_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		stun_lbl.add_theme_constant_override("outline_size", 2)
		card.add_child(stun_lbl)

	return card


func _show_equipment_zone_popup(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var equips: Array = player.get("equipment_zone")
	var pname: String = player.get("player_name")
	var overlay := _create_modal_overlay()

	var card_w: int = 120
	var card_h: int = 180
	var cols: int = 4
	var flow_w: int = cols * card_w + (cols - 1) * 8
	var rows: int = ceili(float(maxi(equips.size(), 1)) / float(cols))
	var panel_w: int = flow_w + 32
	var panel_h: int = 50 + rows * (card_h + 8) + 50

	var panel := Panel.new()
	panel.position = Vector2((1430 - panel_w) / 2, (780 - panel_h) / 2)
	panel.size = Vector2(panel_w, panel_h)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s 的装备区（%d 件）" % [pname, equips.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	if equips.is_empty():
		var empty := Label.new()
		empty.text = "无装备"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(flow_w, 0)
		flow.add_theme_constant_override("separation", 8)
		flow.add_theme_constant_override("line_separation", 8)
		vbox.add_child(flow)
		for card in equips:
			if card == null or not is_instance_valid(card):
				continue
			flow.add_child(_build_equipment_card(card, card_w, card_h))

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


## 构建单个装备卡片（120×180）：图片 + 牌名(中下) + 射程(名字下) + 左上角格子数。
func _build_equipment_card(card: Variant, w: int, h: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(w, h)
	p.size = Vector2(w, h)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.55, 0.35, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	p.add_theme_stylebox_override("panel", style)

	# 装备图片
	var tex: Texture2D = ImageCache.get_card_texture(card.get("card_name"))
	if tex != null:
		var img := TextureRect.new()
		img.set_anchors_preset(PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.texture = tex
		p.add_child(img)

	# 左上角格子数
	var size_val: Variant = card.get("size")
	var sz: int = size_val if size_val is int else 0
	var badge := Label.new()
	badge.text = "%d格" % sz
	badge.position = Vector2(4, 4)
	badge.size = Vector2(40, 16)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 3)
	p.add_child(badge)

	# 牌名（中下）
	var name_lbl := Label.new()
	name_lbl.text = card.get("card_name")
	name_lbl.position = Vector2(4, h - 52)
	name_lbl.size = Vector2(w - 8, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 3)
	p.add_child(name_lbl)

	# 射程（名字下方，仅 range≠"none" 且非空）
	var range_val: Variant = card.get("range")
	var range_str: String = range_val if range_val is String else ""
	if not range_str.is_empty() and range_str != "none":
		var range_map := {"short": "短程", "medium": "中程", "long": "远程", "infinity": "无限"}
		var range_lbl := Label.new()
		range_lbl.text = "射程 " + range_map.get(range_str, range_str)
		range_lbl.position = Vector2(4, h - 32)
		range_lbl.size = Vector2(w - 8, 18)
		range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		range_lbl.add_theme_font_size_override("font_size", 11)
		range_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		range_lbl.add_theme_constant_override("outline_size", 3)
		p.add_child(range_lbl)

	# 填充物信息（如果有）
	var charge_max_val: Variant = card.get("charge_max")
	var charge_cur_val: Variant = card.get("charge_current")
	if charge_max_val is int and charge_max_val > 0:
		var cur: int = charge_cur_val if charge_cur_val is int else 0
		var charge_lbl := Label.new()
		charge_lbl.text = "%d/%d" % [cur, charge_max_val]
		charge_lbl.position = Vector2(w - 50, 4)
		charge_lbl.size = Vector2(46, 16)
		charge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		charge_lbl.add_theme_font_size_override("font_size", 11)
		charge_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1.0))
		charge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_lbl.add_theme_constant_override("outline_size", 3)
		p.add_child(charge_lbl)

	return p


func _show_hand_popup(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	var cards: Array = player.get("hand")
	var pname: String = player.get("player_name")
	var overlay := _create_modal_overlay()
	var panel := Panel.new()
	panel.position = Vector2(315, 100)
	panel.size = Vector2(800, 560)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s 的手牌（%d 张）" % [pname, cards.size()]
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	if cards.is_empty():
		var empty := Label.new()
		empty.text = "无手牌"
		empty.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty)
	else:
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(grid)
		for card in cards:
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			view.set_card(card)
			grid.add_child(view)

	var ok_btn := Button.new()
	ok_btn.text = "关闭"
	ok_btn.custom_minimum_size = Vector2(80, 30)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(_close_popup)
	vbox.add_child(ok_btn)


# === EventBus 信号处理 ===

func _on_turn_started(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	_current_player_label.text = "座位%d %s的回合" % [player.get("seat_number") + 1, player.player_name]
	_update_phase_indicator()
	_assign_player_panels()
	_refresh_map()
	_refresh_hand_area()
	_refresh_pile_counts()
	_refresh_confirm_cancel_buttons()


func _on_phase_changed(player: Variant, _old_phase: String, new_phase: String) -> void:
	_update_phase_indicator()
	_refresh_confirm_cancel_buttons()
	if new_phase != "action":
		_clear_active_skill_buttons()
		# 非行动阶段清空选中
		if _hand_area != null and is_instance_valid(_hand_area):
			_hand_area.clear_selection()


func _clear_active_skill_buttons() -> void:
	for btn in _active_skill_buttons:
		if btn != null and is_instance_valid(btn):
			btn.queue_free()
	_active_skill_buttons.clear()


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


func _on_player_moved(_player: Variant, _source_block: Variant, _target_block: Variant) -> void:
	_refresh_map()
	_refresh_all_panels()


func _on_block_revealed(_block: Variant, _player: Variant) -> void:
	_refresh_map()


func _on_block_destroyed(block: Variant, _source: Variant) -> void:
	# 已摧毁的地块从 Game.map_area 移除，但仍保留视图显示"已摧毁"状态
	if block == null or not is_instance_valid(block):
		return
	var view: Variant = _block_views.get(block.get_instance_id())
	if view != null and is_instance_valid(view):
		view.refresh(false)


func _on_monster_changed(_monster: Variant, _player: Variant) -> void:
	# 怪物生成/死亡影响地块上的怪物标记显示和玩家面板的怪物区
	_refresh_map()
	_refresh_all_panels()
	_refresh_pile_counts()


func _on_player_stat_changed(player: Variant, _arg1: Variant = null, _arg2: Variant = null) -> void:
	_refresh_panel_for_player(player)
	# 若是当前玩家，刷新手牌区、牌堆数与主动技能区（装备变化会增减主动技能）
	var current: Variant = Game.get_current_player()
	if player != null and is_instance_valid(player) and current != null and is_instance_valid(current) and player == current:
		_refresh_hand_area()
		_refresh_pile_counts()
		_refresh_active_skill_buttons()
		_refresh_confirm_cancel_buttons()
	_update_phase_indicator()


func _on_pile_drawn(_player: Variant, _card: Variant) -> void:
	_refresh_pile_counts()
	_refresh_panel_for_player(_player)


# === 玩家面板点击处理 ===

func _on_monster_zone_clicked(player: Variant) -> void:
	_show_monster_zone_popup(player)


func _on_equipment_zone_clicked(player: Variant) -> void:
	_show_equipment_zone_popup(player)


func _on_hand_clicked(player: Variant) -> void:
	_show_hand_popup(player)


func _on_log_message(message: String) -> void:
	_event_log.append(message)
	if _event_log.size() > 500:
		_event_log.pop_front()


func _on_game_over(result: int) -> void:
	_close_popup()
	var text: String = "胜利！" if result == GameStateMachine.GameResult.WIN else "失败..."
	var color: Color = Color(0.1, 0.5, 0.1, 0.9) if result == GameStateMachine.GameResult.WIN else Color(0.5, 0.1, 0.1, 0.9)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = color
	_popup_layer.add_child(overlay)
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(PRESET_CENTER)
	label.position = Vector2(640, 340)
	label.size = Vector2(150, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	overlay.add_child(label)
	var btn := Button.new()
	btn.text = "返回主菜单"
	btn.position = Vector2(560, 420)
	btn.size = Vector2(150, 36)
	btn.pressed.connect(_on_back_pressed)
	overlay.add_child(btn)
	var btn2 := Button.new()
	btn2.text = "重新开始"
	btn2.position = Vector2(720, 420)
	btn2.size = Vector2(150, 36)
	btn2.pressed.connect(_on_restart_pressed)
	overlay.add_child(btn2)


# === 导航 ===

func _on_back_pressed() -> void:
	Game.state_machine.current_state = GameStateMachine.GameState.WAITING
	Game.players.clear()
	Game.map_area.clear()
	RoomState.clear()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
