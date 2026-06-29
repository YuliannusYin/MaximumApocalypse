class_name UIManager
extends CanvasLayer

# UI面板
var info_panel: PanelContainer  # 右侧综合信息面板
var status_label: Label
var turn_label: Label
var phase_label: Label
var log_label: Label  # 输出日志
var hand_panel: PanelContainer
var hand_cards_container: HBoxContainer
var equipment_container: HBoxContainer
var monster_container: HBoxContainer
var control_panel: PanelContainer
var control_container: VBoxContainer

# 控制按钮
var dice_button: Button
var draw_button: Button
var end_turn_button: Button
var turn_end_button: Button
var scavenge_button: Button

# 当前玩家ID
var current_player_id: String = ""
var rule_engine_ref: Node = null  # RuleEngine引用，用于查询装备栏槽位

func _ready() -> void:
	create_ui_panels()

func create_ui_panels() -> void:
	# === 右侧：综合信息面板（合并所有信息）===
	info_panel = PanelContainer.new()
	info_panel.position = Vector2(750, 0)
	info_panel.size = Vector2(500, 610)
	info_panel.modulate = Color(0.95, 0.96, 0.98, 0.95)
	add_child(info_panel)

	var main_vbox = VBoxContainer.new()
	info_panel.add_child(main_vbox)

	# 回合信息
	turn_label = Label.new()
	turn_label.text = "回合: 1"
	turn_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(turn_label)

	phase_label = Label.new()
	phase_label.text = "阶段: 怪物出生"
	phase_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(phase_label)

	status_label = Label.new()
	status_label.text = "游戏进行中"
	status_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(status_label)

	main_vbox.add_child(HSeparator.new())

	# 玩家状态区
	var player_title = Label.new()
	player_title.text = "【玩家状态】"
	player_title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(player_title)

	var player_name_label = Label.new()
	player_name_label.text = "玩家: 消防员"
	player_name_label.name = "PlayerNameLabel"
	main_vbox.add_child(player_name_label)

	var hp_label = Label.new()
	hp_label.text = "生命值: 6/6"
	hp_label.name = "HPLabel"
	main_vbox.add_child(hp_label)

	var hunger_label = Label.new()
	hunger_label.text = "饥饿度: 0"
	hunger_label.name = "HungerLabel"
	main_vbox.add_child(hunger_label)

	var action_label = Label.new()
	action_label.text = "行动点: 4"
	action_label.name = "ActionLabel"
	main_vbox.add_child(action_label)

	var deck_label = Label.new()
	deck_label.text = "牌库: 10张 | 弃牌: 0张"
	deck_label.name = "DeckLabel"
	main_vbox.add_child(deck_label)

	var position_label = Label.new()
	position_label.text = "位置: (0, 0)"
	position_label.name = "PositionLabel"
	main_vbox.add_child(position_label)

	main_vbox.add_child(HSeparator.new())

	# 装备区
	var equip_title = Label.new()
	equip_title.text = "【装备区】"
	equip_title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(equip_title)

	equipment_container = HBoxContainer.new()
	equipment_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(equipment_container)

	main_vbox.add_child(HSeparator.new())

	# 纠缠怪物区
	var monster_title = Label.new()
	monster_title.text = "【纠缠怪物】"
	monster_title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(monster_title)

	monster_container = HBoxContainer.new()
	monster_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(monster_container)

	main_vbox.add_child(HSeparator.new())

	# 游戏日志
	var log_title = Label.new()
	log_title.text = "【游戏日志】"
	log_title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(log_title)

	log_label = Label.new()
	log_label.text = ""
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(log_label)

	# === 右下角：控制面板 ===
	control_panel = PanelContainer.new()
	control_panel.position = Vector2(900, 80)
	control_panel.size = Vector2(500, 200)
	control_panel.modulate = Color(1.0, 0.96, 0.92, 0.95)
	add_child(control_panel)

	control_container = VBoxContainer.new()
	control_panel.add_child(control_container)

	var control_title = Label.new()
	control_title.text = "【操作控制】"
	control_title.add_theme_font_size_override("font_size", 14)
	control_container.add_child(control_title)

	dice_button = Button.new()
	dice_button.text = "丢筛子 (怪物出生)"
	dice_button.size = Vector2(480, 32)
	dice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	dice_button.visible = false
	dice_button.pressed.connect(_on_dice_button_pressed)
	control_container.add_child(dice_button)

	draw_button = Button.new()
	draw_button.text = "抽牌"
	draw_button.size = Vector2(480, 32)
	draw_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	draw_button.visible = false
	draw_button.pressed.connect(_on_draw_button_pressed)
	control_container.add_child(draw_button)

	end_turn_button = Button.new()
	end_turn_button.text = "结束行动"
	end_turn_button.size = Vector2(480, 32)
	end_turn_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	end_turn_button.visible = false
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	control_container.add_child(end_turn_button)

	turn_end_button = Button.new()
	turn_end_button.text = "回合结束 (饥饿+怪物攻击)"
	turn_end_button.size = Vector2(480, 32)
	turn_end_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_end_button.visible = false
	turn_end_button.pressed.connect(_on_turn_end_button_pressed)
	control_container.add_child(turn_end_button)

	scavenge_button = Button.new()
	scavenge_button.text = "拾荒 (消耗1行动点)"
	scavenge_button.size = Vector2(480, 32)
	scavenge_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	scavenge_button.visible = false
	scavenge_button.pressed.connect(_on_scavenge_button_pressed)
	control_container.add_child(scavenge_button)

	# === 底部：手牌区 ===
	hand_panel = PanelContainer.new()
	hand_panel.position = Vector2(50, 600)
	hand_panel.size = Vector2(700, 180)
	hand_panel.modulate = Color(0.95, 1.0, 0.95, 0.95)
	add_child(hand_panel)

	var hand_vbox = VBoxContainer.new()
	hand_panel.add_child(hand_vbox)

	var hand_title = Label.new()
	hand_title.text = "【手牌区】点击卡牌出牌（消耗1行动点）"
	hand_title.add_theme_font_size_override("font_size", 14)
	hand_vbox.add_child(hand_title)

	hand_cards_container = HBoxContainer.new()
	hand_cards_container.add_theme_constant_override("separation", 6)
	hand_vbox.add_child(hand_cards_container)

# 信号定义
signal dice_rolled(d1: int, d2: int)
signal card_drawn(player_id: String)
signal turn_ended(player_id: String)
signal turn_end_processed(player_id: String)
signal card_played(player_id: String, card_index: int)
signal scavenge_performed(player_id: String)
signal weapon_attack_triggered(player_id: String, equipment_index: int)
signal equipment_discarded(player_id: String, equipment_index: int)

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

	dice_button.visible = false
	draw_button.visible = false
	end_turn_button.visible = false
	turn_end_button.visible = false
	scavenge_button.visible = false

	match phase:
		Enums.GamePhase.SPAWN:
			dice_button.visible = true
			status_label.text = "点击丢筛子进行怪物出生"
		Enums.GamePhase.DRAW:
			draw_button.visible = true
			status_label.text = "点击抽牌按钮"
		Enums.GamePhase.ACTION:
			end_turn_button.visible = true
			if _can_player_scavenge(player_id):
				scavenge_button.visible = true
			status_label.text = "行动阶段 - 点击地图移动或点击手牌出牌"
		Enums.GamePhase.MONSTER_ATTACK:
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

	return tile_data.scavenge_colors.size() > 0

# 更新玩家信息面板
func update_player_info(player_id: String) -> void:
	if not GameState.players.has(player_id):
		return

	var player = GameState.players[player_id]

	var player_name_label = info_panel.find_child("PlayerNameLabel", true, false)
	if player_name_label:
		player_name_label.text = "玩家: " + player.character_name

	var hp_label = info_panel.find_child("HPLabel", true, false)
	if hp_label:
		hp_label.text = "生命值: " + str(player.current_hp) + "/" + str(player.max_hp)

	var hunger_label = info_panel.find_child("HungerLabel", true, false)
	if hunger_label:
		hunger_label.text = "饥饿度: " + str(player.hunger_level)

	var action_label = info_panel.find_child("ActionLabel", true, false)
	if action_label:
		action_label.text = "行动点: " + str(player.action_points)

	var deck_label = info_panel.find_child("DeckLabel", true, false)
	if deck_label:
		deck_label.text = "牌库: " + str(player.deck.size()) + "张 | 弃牌: " + str(player.discard_pile.size()) + "张"

	var position_label = info_panel.find_child("PositionLabel", true, false)
	if position_label:
		position_label.text = "位置: (" + str(player.position.x) + ", " + str(player.position.y) + ")"

	update_hand_display(player_id)
	update_equipment_display(player_id)
	update_monster_display(player_id)

# 更新装备区显示
func update_equipment_display(player_id: String) -> void:
	for child in equipment_container.get_children():
		child.queue_free()

	if not GameState.players.has(player_id):
		return

	var player = GameState.players[player_id]
	var equipment_zone = player.equipment_zone

	# 显示槽位使用情况
	var slots_used = 0
	for equipment in equipment_zone:
		var ed = rule_engine_ref._load_card_data(equipment.template_id) if rule_engine_ref else null
		if ed is CharacterCardData:
			slots_used += ed.equipment_cost
		elif ed is ScavengeCardData:
			slots_used += ed.equipment_slot
	var slots_max = rule_engine_ref.get_player_equipment_slots(player_id) if rule_engine_ref else 4
	var slots_label = Label.new()
	slots_label.text = "装备栏: " + str(slots_used) + "/" + str(slots_max)
	equipment_container.add_child(slots_label)

	for i in range(equipment_zone.size()):
		var equipment = equipment_zone[i]
		var row = HBoxContainer.new()

		# 加载卡牌描述（用于tooltip拼接）
		var card_desc = _get_card_tooltip(equipment.template_id)

		var equip_button = Button.new()
		# 武器显示弹药数，-1表示无限弹药
		if equipment.current_ammo > 0:
			equip_button.text = equipment.card_name + "(弹" + str(equipment.current_ammo) + ")"
		elif equipment.current_ammo == -1:
			equip_button.text = equipment.card_name + "(∞)"
		else:
			equip_button.text = equipment.card_name
		equip_button.size = Vector2(120, 40)
		# 武器（有弹药或无限弹药）可点击攻击
		if equipment.current_ammo != 0:
			var usage_tip = "点击使用武器攻击（消耗1行动点）"
			equip_button.tooltip_text = usage_tip + "\n\n" + card_desc if card_desc != "" else usage_tip
			var idx = i
			equip_button.pressed.connect(func(): _on_weapon_attack_pressed(idx))
		else:
			equip_button.disabled = true
			if card_desc != "":
				equip_button.tooltip_text = card_desc
		row.add_child(equip_button)

		# 弃装备按钮
		var discard_btn = Button.new()
		discard_btn.text = "弃"
		discard_btn.size = Vector2(40, 40)
		var discard_tip = "弃掉此装备（触发弃牌效果）"
		discard_btn.tooltip_text = discard_tip + "\n\n" + card_desc if card_desc != "" else discard_tip
		var didx = i
		discard_btn.pressed.connect(func(): _on_discard_equipment_pressed(didx))
		row.add_child(discard_btn)

		equipment_container.add_child(row)

# 武器攻击按钮回调
func _on_weapon_attack_pressed(equipment_index: int) -> void:
	weapon_attack_triggered.emit(current_player_id, equipment_index)

# 弃装备按钮回调
func _on_discard_equipment_pressed(equipment_index: int) -> void:
	equipment_discarded.emit(current_player_id, equipment_index)

# 更新怪物区显示
func update_monster_display(player_id: String) -> void:
	for child in monster_container.get_children():
		child.queue_free()

	if not GameState.players.has(player_id):
		return

	var player = GameState.players[player_id]
	var monster_zone = player.monster_zone

	if monster_zone.size() == 0:
		var no_monster_label = Label.new()
		no_monster_label.text = "无纠缠怪物"
		no_monster_label.add_theme_font_size_override("font_size", 12)
		monster_container.add_child(no_monster_label)
		return

	for monster in monster_zone:
		var monster_button = Button.new()
		monster_button.text = monster.card_name + " (" + str(monster.current_hp) + "HP)"
		monster_button.size = Vector2(80, 40)
		monster_button.modulate = Color(0.8, 0.3, 0.3)
		monster_button.disabled = true
		# 鼠标悬停显示怪物描述（与手牌一致）
		var desc = _get_card_tooltip(monster.template_id)
		if desc != "":
			monster_button.tooltip_text = desc
		monster_container.add_child(monster_button)

# 更新手牌显示
func update_hand_display(player_id: String) -> void:
	for child in hand_cards_container.get_children():
		child.queue_free()

	if not GameState.players.has(player_id):
		return

	var player = GameState.players[player_id]
	var hand = player.hand

	for i in range(hand.size()):
		var card = hand[i]
		var card_button = Button.new()
		card_button.text = card.card_name
		card_button.size = Vector2(70, 40)

		if card.template_id.contains("monster"):
			card_button.modulate = Color(0.8, 0.2, 0.2)

		# 鼠标悬停显示卡牌描述
		var desc = _get_card_tooltip(card.template_id)
		if desc != "":
			card_button.tooltip_text = desc

		card_button.pressed.connect(_on_card_button_pressed.bind(i))
		hand_cards_container.add_child(card_button)

# 静默加载卡牌描述（不输出日志）
func _get_card_tooltip(template_id: String) -> String:
	# 拾荒卡
	var scavenge_folders = ["red", "green", "blue", "gray"]
	for folder in scavenge_folders:
		var path = "res://data/cards/scavengeCards/" + folder + "/" + template_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is ScavengeCardData:
				var tip = "【" + res.card_name + "】"
				var type_str = "行动牌"
				if res.card_type == Enums.ScavengeCardType.EQUIPMENT:
					type_str = "装备牌"
				elif res.card_type == Enums.ScavengeCardType.ITEM:
					type_str = "物品牌"
				tip += "\n类型: " + type_str
				if res.equipment_slot > 0:
					tip += "（占" + str(res.equipment_slot) + "格）"
				if res.effect != "":
					tip += "\n效果: " + res.effect
				return tip
			break

	# 角色卡
	var char_folders = ["cowboy", "firefighter", "hunter", "mechanic", "surgeon", "veteran"]
	for folder in char_folders:
		var path = "res://data/cards/characterCards/" + folder + "/" + template_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is CharacterCardData:
				var tip = "【" + res.card_name + "】"
				var type_str = "行动牌" if res.card_type == Enums.CharacterCard.ACTION else "装备牌"
				tip += "\n类型: " + type_str
				if res.card_type == Enums.CharacterCard.EQUIPMENT and res.equipment_cost > 0:
					tip += "（占" + str(res.equipment_cost) + "格）"
				if res.max_ammo > 0:
					tip += "\n弹药: " + str(res.max_ammo)
				elif res.max_ammo == -1:
					tip += "\n弹药: ∞"
				if res.action_condition != "":
					tip += "\n条件: " + res.action_condition
				if res.description != "":
					tip += "\n效果: " + res.description
				return tip
			break

	# 怪物卡
	var monster_folders = ["alien", "mutant", "robot", "zombie"]
	for folder in monster_folders:
		var path = "res://data/monsters/" + folder + "/" + template_id + ".tres"
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is MonsterData:
				var tip = "【" + res.monster_name + "】"
				tip += "\n卡包: " + _monster_pack_name(res.pack)
				tip += "\n等级: " + _monster_rank_name(res.rank)
				tip += "\n生命: " + str(res.max_hp)
				tip += "\n伤害: " + str(res.damage)
				tip += "\n射程: " + _range_type_name(res.range_type)
				if res.description != "":
					tip += "\n描述: " + res.description
				return tip
			break

	return ""

# 怪物卡包名称
func _monster_pack_name(pack: Enums.MonsterPack) -> String:
	match pack:
		Enums.MonsterPack.ALIEN:
			return "异形"
		Enums.MonsterPack.MUTANT:
			return "变种人"
		Enums.MonsterPack.ROBOT:
			return "机器人"
		Enums.MonsterPack.ZOMBIE:
			return "僵尸"
		_:
			return "未知"

# 怪物等级名称
func _monster_rank_name(rank: Enums.MonsterLevel) -> String:
	match rank:
		Enums.MonsterLevel.NORMAL:
			return "普通怪"
		Enums.MonsterLevel.ELITE:
			return "精英怪"
		Enums.MonsterLevel.BOSS:
			return "首领怪"
		_:
			return "未知"

# 射程类型名称
func _range_type_name(range_type: Enums.RangeType) -> String:
	match range_type:
		Enums.RangeType.NONE:
			return "无"
		Enums.RangeType.SHORT:
			return "短距离"
		Enums.RangeType.MEDIUM:
			return "中距离"
		Enums.RangeType.LONG:
			return "长距离"
		_:
			return "未知"

# 添加日志输出（新日志在最上方）
func add_log_message(message: String) -> void:
	if log_label:
		var current_text = log_label.text
		var lines = current_text.split("\n")
		# 新消息插入到开头
		lines.insert(0, message)
		# 保留最近15行日志（移除最旧的末尾）
		if lines.size() > 15:
			lines.remove_at(lines.size() - 1)
		log_label.text = "\n".join(lines)
		print("[UI日志] " + message)

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
