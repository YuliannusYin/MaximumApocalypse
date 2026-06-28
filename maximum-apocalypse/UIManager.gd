class_name UIManager
extends CanvasLayer

# UI面板
var info_panel: PanelContainer
var status_label: Label
var turn_label: Label
var phase_label: Label
var player_info_panel: PanelContainer
var hand_panel: PanelContainer
var hand_cards_container: HBoxContainer
var control_panel: PanelContainer
var control_container: VBoxContainer

# 控制按钮
var dice_button: Button
var draw_button: Button
var end_turn_button: Button
var turn_end_button: Button  # 回合结束按钮（合并饥饿和怪物攻击）
var scavenge_button: Button  # 拾荒按钮

# 当前玩家ID
var current_player_id: String = ""

func _ready() -> void:
	create_ui_panels()

func create_ui_panels() -> void:
	# 信息面板（右上）
	info_panel = PanelContainer.new()
	info_panel.position = Vector2(900, 50)
	info_panel.size = Vector2(300, 300)
	add_child(info_panel)

	var vbox = VBoxContainer.new()
	info_panel.add_child(vbox)

	turn_label = Label.new()
	turn_label.text = "回合: 1"
	turn_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(turn_label)

	phase_label = Label.new()
	phase_label.text = "阶段: 怪物出生"
	phase_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(phase_label)

	status_label = Label.new()
	status_label.text = "游戏进行中"
	vbox.add_child(status_label)

	# 控制面板（右下）
	control_panel = PanelContainer.new()
	control_panel.position = Vector2(900, 400)
	control_panel.size = Vector2(300, 250)
	add_child(control_panel)

	control_container = VBoxContainer.new()
	control_panel.add_child(control_container)

	var control_title = Label.new()
	control_title.text = "操作控制"
	control_title.add_theme_font_size_override("font_size", 16)
	control_container.add_child(control_title)

	# 丢筛子按钮（怪物出生阶段）
	dice_button = Button.new()
	dice_button.text = "丢筛子 (怪物出生)"
	dice_button.size = Vector2(280, 40)
	dice_button.visible = false
	dice_button.pressed.connect(_on_dice_button_pressed)
	control_container.add_child(dice_button)

	# 抽牌按钮（抽牌阶段）
	draw_button = Button.new()
	draw_button.text = "抽牌"
	draw_button.size = Vector2(280, 40)
	draw_button.visible = false
	draw_button.pressed.connect(_on_draw_button_pressed)
	control_container.add_child(draw_button)

	# 结束回合按钮（行动阶段）
	end_turn_button = Button.new()
	end_turn_button.text = "结束行动"
	end_turn_button.size = Vector2(280, 40)
	end_turn_button.visible = false
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	control_container.add_child(end_turn_button)

	# 回合结束按钮（合并饥饿和怪物攻击）
	turn_end_button = Button.new()
	turn_end_button.text = "回合结束 (饥饿+怪物攻击)"
	turn_end_button.size = Vector2(280, 40)
	turn_end_button.visible = false
	turn_end_button.pressed.connect(_on_turn_end_button_pressed)
	control_container.add_child(turn_end_button)

	# 拾荒按钮（行动阶段）
	scavenge_button = Button.new()
	scavenge_button.text = "拾荒 (消耗1行动点)"
	scavenge_button.size = Vector2(280, 40)
	scavenge_button.visible = false
	scavenge_button.pressed.connect(_on_scavenge_button_pressed)
	control_container.add_child(scavenge_button)

	# 玩家信息面板（左上）
	player_info_panel = PanelContainer.new()
	player_info_panel.position = Vector2(50, 50)
	player_info_panel.size = Vector2(250, 220)
	add_child(player_info_panel)

	var player_vbox = VBoxContainer.new()
	player_info_panel.add_child(player_vbox)

	var player_name_label = Label.new()
	player_name_label.text = "玩家: 消防员"
	player_name_label.add_theme_font_size_override("font_size", 16)
	player_vbox.add_child(player_name_label)

	var hp_label = Label.new()
	hp_label.text = "生命值: 6/6"
	hp_label.name = "HPLabel"
	player_vbox.add_child(hp_label)

	var hunger_label = Label.new()
	hunger_label.text = "饥饿度: 0"
	hunger_label.name = "HungerLabel"
	player_vbox.add_child(hunger_label)

	var action_label = Label.new()
	action_label.text = "行动点: 4"
	action_label.name = "ActionLabel"
	player_vbox.add_child(action_label)

	var deck_label = Label.new()
	deck_label.text = "牌库: 10张"
	deck_label.name = "DeckLabel"
	player_vbox.add_child(deck_label)

	var position_label = Label.new()
	position_label.text = "位置: (0, 0)"
	position_label.name = "PositionLabel"
	player_vbox.add_child(position_label)

	# 手牌面板（底部）
	hand_panel = PanelContainer.new()
	hand_panel.position = Vector2(50, 550)
	hand_panel.size = Vector2(900, 100)
	add_child(hand_panel)

	var hand_vbox = VBoxContainer.new()
	hand_panel.add_child(hand_vbox)

	var hand_title = Label.new()
	hand_title.text = "手牌区域（点击卡牌出牌）"
	hand_vbox.add_child(hand_title)

	hand_cards_container = HBoxContainer.new()
	hand_cards_container.add_theme_constant_override("separation", 10)
	hand_vbox.add_child(hand_cards_container)

# 信号定义
signal dice_rolled(d1: int, d2: int)
signal card_drawn(player_id: String)
signal turn_ended(player_id: String)
signal turn_end_processed(player_id: String)  # 回合结束信号
signal card_played(player_id: String, card_index: int)
signal scavenge_performed(player_id: String)  # 拾荒信号

# 按钮事件处理
func _on_dice_button_pressed() -> void:
	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	status_label.text = "骰子结果: " + str(d1) + " + " + str(d2) + " = " + str(d1 + d2)
	dice_button.visible = false
	dice_rolled.emit(d1, d2)

func _on_draw_button_pressed() -> void:
	draw_button.visible = false
	status_label.text = "抽牌中..."
	card_drawn.emit(current_player_id)

func _on_end_turn_pressed() -> void:
	end_turn_button.visible = false
	status_label.text = "行动阶段结束"
	turn_ended.emit(current_player_id)

func _on_turn_end_button_pressed() -> void:
	turn_end_button.visible = false
	status_label.text = "回合结束处理..."
	turn_end_processed.emit(current_player_id)

func _on_card_button_pressed(card_index: int) -> void:
	status_label.text = "出牌: 手牌索引 " + str(card_index)
	card_played.emit(current_player_id, card_index)

func _on_scavenge_button_pressed() -> void:
	status_label.text = "拾荒中..."
	scavenge_performed.emit(current_player_id)

# 显示当前阶段的按钮
func show_phase_buttons(phase: Enums.GamePhase, player_id: String) -> void:
	current_player_id = player_id

	# 隐藏所有按钮
	dice_button.visible = false
	draw_button.visible = false
	end_turn_button.visible = false
	turn_end_button.visible = false
	scavenge_button.visible = false

	# 根据阶段显示对应按钮
	match phase:
		Enums.GamePhase.SPAWN:
			dice_button.visible = true
			status_label.text = "点击丢筛子进行怪物出生"
		Enums.GamePhase.DRAW:
			draw_button.visible = true
			status_label.text = "点击抽牌按钮"
		Enums.GamePhase.ACTION:
			end_turn_button.visible = true
			# 检查玩家是否在有拾荒标记的地块上
			if _can_player_scavenge(player_id):
				scavenge_button.visible = true
				scavenge_button.text = "拾荒 (消耗1行动点)"
			status_label.text = "行动阶段 - 点击地图移动或点击手牌出牌"
		Enums.GamePhase.MONSTER_ATTACK:  # 回合结束阶段
			turn_end_button.visible = true
			status_label.text = "回合结束 - 点击结算饥饿和怪物攻击"

# 检查玩家是否可以在当前位置拾荒
func _can_player_scavenge(player_id: String) -> bool:
	if not GameState.players.has(player_id):
		return false

	var player = GameState.players[player_id]
	var player_pos = player.position

	if not GameState.map_grid.has(player_pos):
		return false

	var tile = GameState.map_grid[player_pos]
	var tile_data: MapBlockData = tile["data"]

	# 检查地块是否有拾荒颜色标记
	return tile_data.scavenge_colors.size() > 0

# 更新玩家信息面板
func update_player_info(player_id: String) -> void:
	if not GameState.players.has(player_id):
		return

	var player = GameState.players[player_id]

	var hp_label = player_info_panel.find_child("HPLabel", true, false)
	if hp_label:
		hp_label.text = "生命值: " + str(player.current_hp) + "/" + str(player.max_hp)

	var hunger_label = player_info_panel.find_child("HungerLabel", true, false)
	if hunger_label:
		hunger_label.text = "饥饿度: " + str(player.hunger_level)

	var action_label = player_info_panel.find_child("ActionLabel", true, false)
	if action_label:
		action_label.text = "行动点: " + str(player.action_points)

	var deck_label = player_info_panel.find_child("DeckLabel", true, false)
	if deck_label:
		deck_label.text = "牌库: " + str(player.deck.size()) + "张"

	var position_label = player_info_panel.find_child("PositionLabel", true, false)
	if position_label:
		position_label.text = "位置: (" + str(player.position.x) + ", " + str(player.position.y) + ")"

	# 更新手牌显示
	update_hand_display(player_id)

# 更新手牌显示（改为按钮卡片）
func update_hand_display(player_id: String) -> void:
	# 清空当前手牌
	for child in hand_cards_container.get_children():
		child.queue_free()

	if not GameState.players.has(player_id):
		return

	var player = GameState.players[player_id]
	var hand = player.hand

	# 为每张手牌创建按钮
	for i in range(hand.size()):
		var card = hand[i]
		var card_button = Button.new()
		card_button.text = card.card_name
		card_button.size = Vector2(80, 50)

		# 怪物卡用红色标注
		if card.template_id.contains("monster"):
			card_button.modulate = Color(0.8, 0.2, 0.2)

		card_button.pressed.connect(_on_card_button_pressed.bind(i))
		hand_cards_container.add_child(card_button)

# 显示胜利画面
func show_victory_screen() -> void:
	var victory_panel = PanelContainer.new()
	victory_panel.position = Vector2(400, 200)
	victory_panel.size = Vector2(400, 200)
	victory_panel.modulate = Color(0.2, 0.8, 0.2, 0.9)
	add_child(victory_panel)

	var vbox = VBoxContainer.new()
	victory_panel.add_child(vbox)

	var title = Label.new()
	title.text = "胜利!"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "你们成功逃离了!"
	vbox.add_child(desc)

	var restart_btn = Button.new()
	restart_btn.text = "返回主菜单"
	restart_btn.pressed.connect(_restart_game)
	vbox.add_child(restart_btn)

# 显示失败画面
func show_defeat_screen() -> void:
	var defeat_panel = PanelContainer.new()
	defeat_panel.position = Vector2(400, 200)
	defeat_panel.size = Vector2(400, 200)
	defeat_panel.modulate = Color(0.8, 0.2, 0.2, 0.9)
	add_child(defeat_panel)

	var vbox = VBoxContainer.new()
	defeat_panel.add_child(vbox)

	var title = Label.new()
	title.text = "失败!"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "你们全军覆没..."
	vbox.add_child(desc)

	var restart_btn = Button.new()
	restart_btn.text = "返回主菜单"
	restart_btn.pressed.connect(_restart_game)
	vbox.add_child(restart_btn)

func _restart_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func update_phase_display(phase: Enums.GamePhase) -> void:
	var phase_names = {
		Enums.GamePhase.SPAWN: "怪物出生",
		Enums.GamePhase.DRAW: "抽牌",
		Enums.GamePhase.ACTION: "行动",
		Enums.GamePhase.HUNGER: "饥饿结算",
		Enums.GamePhase.MONSTER_ATTACK: "怪物攻击"
	}
	phase_label.text = "阶段: " + phase_names.get(phase, "未知")

func update_turn_display(turn: int) -> void:
	turn_label.text = "回合: " + str(turn)