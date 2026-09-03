class_name CheatMenu
extends Control

## 作弊菜单（仅开发者模式可用）。
## 由 game_scene_2d.gd 在 Settings.dev_mode == true 时创建，反引号键（`）呼出/关闭。
## 所有操作均直接调用 Game / Player / Monster / MapBlock 既有 API，尽量走完整流程（含 EventBus 信号），
## 保证操作后 UI（面板/任务进度等）能正常刷新。

const PANEL_SIZE: Vector2 = Vector2(360, 620)
const BG_COLOR: Color = Color("#211f1a")

var _panel: Panel = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _player_option: OptionButton = null
var _players_cache: Array = []

# 常用输入框缓存，供各按钮回调读取
var _hp_edit: LineEdit = null
var _hunger_edit: LineEdit = null
var _action_edit: LineEdit = null
var _card_name_edit: LineEdit = null
var _game_card_name_edit: LineEdit = null
var _monster_name_edit: LineEdit = null
var _van_fuel_edit: LineEdit = null
var _mission_key_edit: LineEdit = null
var _mission_value_edit: LineEdit = null

# UI 刷新回调：由 game_scene_2d.gd 注入，签名 (player: Variant = null) -> void。
# player 非空时刷新其面板（及为当前回合玩家时的手牌区）；player 为 null 时刷新全局（所有面板/地图/牌堆数）。
# 仅用于绕过完整实体方法（如 Player.gain()）不发 EventBus 信号导致 UI 不刷新的场景；
# 走完整实体方法（recover/damage/draw/draw_monster/death 等）的操作已通过其自身信号驱动刷新，无需调用本回调。
var _refresh_ui_callback: Callable = Callable()


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(20, 20)
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	HudTheme.apply_section_panel(_panel, BG_COLOR, HudTheme.GOLD_BORDER)
	add_child(_panel)

	var title_bar := HBoxContainer.new()
	title_bar.position = Vector2(10, 8)
	title_bar.size = Vector2(PANEL_SIZE.x - 20, 24)
	_panel.add_child(title_bar)

	var title := Label.new()
	title.text = "作弊菜单（开发者模式）"
	title.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func() -> void: visible = false)
	title_bar.add_child(close_btn)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(6, 38)
	_scroll.size = Vector2(PANEL_SIZE.x - 12, PANEL_SIZE.y - 44)
	_panel.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(PANEL_SIZE.x - 30, 0)
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)

	_build_player_selector()
	_add_separator("生命 / 饥饿 / 行动点")
	_build_stats_section()
	_add_separator("胜负")
	_build_win_lose_section()
	_add_separator("卡牌")
	_build_card_section()
	_add_separator("怪物")
	_build_monster_section()
	_add_separator("地图")
	_build_map_section()
	_add_separator("任务")
	_build_mission_section()
	_add_separator("回合")
	_build_turn_section()
	_add_separator("调试")
	_build_debug_section()


func _add_separator(text: String) -> void:
	var label := Label.new()
	label.text = "── " + text + " ──"
	label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	label.add_theme_font_size_override("font_size", 12)
	_content.add_child(label)


func _add_row(children: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for child in children:
		row.add_child(child)
	_content.add_child(row)
	return row


func _make_label(text: String, min_width: int = 60) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 0)
	label.add_theme_color_override("font_color", HudTheme.TEXT_MAIN)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn


func _make_line_edit(placeholder: String, width: int = 60) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(width, 0)
	return edit


# === 玩家选择 ===

func _build_player_selector() -> void:
	_player_option = OptionButton.new()
	_player_option.custom_minimum_size = Vector2(0, 28)
	_content.add_child(_player_option)
	refresh_player_list()


## 刷新玩家下拉列表（打开菜单时调用，保证座位/名字/存活状态最新）。
func refresh_player_list() -> void:
	if _player_option == null:
		return
	var previous_player: Variant = _get_selected_player()
	_players_cache = Game.get_all_players() if Game != null and is_instance_valid(Game) else []
	_player_option.clear()
	var reselect_idx: int = 0
	for i in range(_players_cache.size()):
		var p: Variant = _players_cache[i]
		if p == null or not is_instance_valid(p):
			continue
		var alive_tag: String = "" if p.is_alive() else "（死亡）"
		_player_option.add_item("座位%d %s%s" % [p.seat_number + 1, p.player_name, alive_tag], i)
		if p == previous_player:
			reselect_idx = _player_option.get_item_count() - 1
	if _player_option.get_item_count() > 0:
		_player_option.select(reselect_idx)


func _get_selected_player() -> Variant:
	if _player_option == null or _player_option.get_item_count() == 0:
		return null
	var id: int = _player_option.get_selected_id()
	if id < 0 or id >= _players_cache.size():
		return null
	return _players_cache[id]


func _log(text: String) -> void:
	if Game != null and is_instance_valid(Game):
		Game.log_message("[作弊] " + text)


## 由 game_scene_2d.gd 调用，注入 UI 刷新回调。
func setup(refresh_ui_callback: Callable) -> void:
	_refresh_ui_callback = refresh_ui_callback


func _refresh_ui(player: Variant = null) -> void:
	if _refresh_ui_callback.is_valid():
		_refresh_ui_callback.call(player)


# === 生命 / 饥饿 / 行动点 ===

func _build_stats_section() -> void:
	_hp_edit = _make_line_edit("生命值")
	_add_row([_make_label("生命值"), _hp_edit,
		_make_button("设置", _on_set_hp_pressed),
		_make_button("回满", _on_full_hp_pressed)])

	_hunger_edit = _make_line_edit("饥饿值(1-6)")
	_add_row([_make_label("饥饿值"), _hunger_edit,
		_make_button("设置", _on_set_hunger_pressed),
		_make_button("清空", _on_clear_hunger_pressed)])

	_action_edit = _make_line_edit("行动点")
	_add_row([_make_label("行动点"), _action_edit,
		_make_button("设置", _on_set_action_pressed),
		_make_button("回满", _on_full_action_pressed)])


func _on_set_hp_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var value: int = _hp_edit.text.to_int()
	value = clampi(value, 0, player.max_hp)
	var old_hp: int = player.hp
	player.hp = value
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_hp_changed.emit(player, old_hp, player.hp)
	_log("将 " + player.player_name + " 的生命值设为 " + str(value))
	if value <= 0 and old_hp > 0:
		await player.death(null)


func _on_full_hp_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var missing: int = player.max_hp - player.hp
	if missing > 0:
		await player.recover(missing, null)
	_log("将 " + player.player_name + " 的生命值回满")


func _on_set_hunger_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var value: int = clampi(_hunger_edit.text.to_int(), 1, 6)
	var diff: int = value - player.hunger
	if diff > 0:
		player.increase_hunger(diff)
	elif diff < 0:
		player.decrease_hunger(-diff)
	_log("将 " + player.player_name + " 的饥饿值设为 " + str(value))


func _on_clear_hunger_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	if player.hunger > 1:
		player.decrease_hunger(player.hunger - 1)
	_log("清空了 " + player.player_name + " 的饥饿值")


func _on_set_action_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var value: int = maxi(_action_edit.text.to_int(), 0)
	player.set_action_count(value)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.action_consumed.emit(player, 0)
	_log("将 " + player.player_name + " 的行动点设为 " + str(value))


func _on_full_action_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	player.set_action_count(player.max_action_count)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.action_consumed.emit(player, 0)
	_log("将 " + player.player_name + " 的行动点回满")


# === 胜负 ===

func _build_win_lose_section() -> void:
	_add_row([
		_make_button("一键胜利", _on_win_pressed),
		_make_button("一键失败", _on_lose_pressed),
	])


func _on_win_pressed() -> void:
	_log("触发一键胜利")
	if Game != null and is_instance_valid(Game):
		Game.game_over("win")


func _on_lose_pressed() -> void:
	_log("触发一键失败")
	if Game != null and is_instance_valid(Game):
		Game.game_over("lose")


# === 卡牌 ===

func _build_card_section() -> void:
	_card_name_edit = _make_line_edit("拾荒卡名称", 140)
	_add_row([_card_name_edit, _make_button("获得拾荒卡", _on_gain_card_pressed)])

	_game_card_name_edit = _make_line_edit("角色游戏牌名称", 140)
	_add_row([_game_card_name_edit, _make_button("定向抓取游戏牌", _on_draw_named_game_card_pressed)])


## 直接生成一张拾荒卡加入目标玩家手牌。Player.gain() 不发 EventBus 信号，
## 手动调用 _refresh_ui 刷新手牌区/面板（不伪造 scavenge_drawn 信号，避免污染 StatsTracker 拾荒统计）。
func _on_gain_card_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var card_name: String = _card_name_edit.text.strip_edges()
	if card_name.is_empty():
		return
	if Game == null or not is_instance_valid(Game):
		return
	var card: Card = Game.create_scavenge_card(card_name)
	if card == null:
		_log("未找到拾荒卡：" + card_name)
		return
	await player.gain(card)
	_refresh_ui(player)
	_log("给 " + player.player_name + " 发放了拾荒卡 " + card_name)


## 定向抓取目标玩家自己牌堆（或弃牌堆）中的指定游戏牌：取出后插到牌堆顶，
## 复用 Player.draw(1) 完整流程（含触发器/手牌超限判定），已发 card_drawn 信号，UI 自动刷新。
func _on_draw_named_game_card_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var card_name: String = _game_card_name_edit.text.strip_edges()
	if card_name.is_empty():
		return
	var card: Variant = _take_card_by_name_from_pile(player.get("game_deck"), card_name)
	if card == null:
		card = _take_card_by_name_from_pile(player.get("game_discard_pile"), card_name)
	if card == null:
		_log("未在 " + player.player_name + " 的游戏牌堆/弃牌堆中找到：" + card_name)
		return
	var deck: Pile = player.get("game_deck")
	if deck == null:
		return
	deck.cards.push_front(card)
	await player.draw(1)
	_log("给 " + player.player_name + " 定向抓取了游戏牌 " + card_name)


## 按名称（card_name 或 english_name）从牌堆中查找并取出一张牌（按实例移除），未找到返回 null。
func _take_card_by_name_from_pile(pile: Variant, card_name: String) -> Variant:
	if pile == null or not (pile is Pile):
		return null
	for card in (pile as Pile).cards:
		if card != null and is_instance_valid(card) and (card.card_name == card_name or card.english_name == card_name):
			(pile as Pile).cards.erase(card)
			return card
	return null


# === 怪物 ===

func _build_monster_section() -> void:
	_monster_name_edit = _make_line_edit("怪物名称", 140)
	_add_row([_monster_name_edit, _make_button("定向抓取怪物", _on_draw_named_monster_pressed)])
	_add_row([_make_button("杀死场上所有怪物", _on_kill_all_monsters_pressed)])


## 定向抓取怪物牌堆（或怪物弃牌堆）中的指定怪物：取出后插到怪物牌堆顶，
## 复用 Player.draw_monster(1) 完整流程（含触发器/纠缠/动画），已发 monster_spawned 等信号，UI 自动刷新。
func _on_draw_named_monster_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	var monster_name: String = _monster_name_edit.text.strip_edges()
	if monster_name.is_empty():
		return
	if Game == null or not is_instance_valid(Game):
		return
	var card: Variant = _take_card_by_name_from_pile(Game.monster_pile, monster_name)
	if card == null:
		card = _take_card_by_name_from_pile(Game.monster_discard_pile, monster_name)
	if card == null:
		_log("未在怪物牌堆/弃牌堆中找到：" + monster_name)
		return
	if Game.monster_pile == null:
		return
	Game.monster_pile.cards.push_front(card)
	await player.draw_monster(1)
	_log("给 " + player.player_name + " 定向抓取了怪物 " + monster_name)


func _on_kill_all_monsters_pressed() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var killer: Variant = _get_selected_player()
	var total: int = 0
	for player in Game.get_all_players():
		if player == null or not is_instance_valid(player):
			continue
		var monsters: Array = player.monster_zone.duplicate()
		for monster in monsters:
			if monster != null and is_instance_valid(monster):
				await monster.death(killer)
				total += 1
	_log("杀死了场上全部 " + str(total) + " 只怪物")


# === 地图 ===

func _build_map_section() -> void:
	_add_row([_make_button("揭示全部地图块", _on_reveal_map_pressed)])


func _on_reveal_map_pressed() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var player: Variant = _get_selected_player()
	var count: int = 0
	for block in Game.map_area.duplicate():
		if block != null and is_instance_valid(block) and not block.is_revealed():
			await block.reveal(false, player)
			count += 1
	_log("揭示了 " + str(count) + " 个未展示的地图块")


# === 任务 ===

func _build_mission_section() -> void:
	_van_fuel_edit = _make_line_edit("燃料值")
	_add_row([_make_label("面包车燃料"), _van_fuel_edit, _make_button("设置", _on_set_van_fuel_pressed)])

	_mission_key_edit = _make_line_edit("标记键", 100)
	_mission_value_edit = _make_line_edit("值(true/false/数字/文本)", 140)
	_add_row([_mission_key_edit])
	_add_row([_mission_value_edit, _make_button("设置任务标记", _on_set_mission_state_pressed)])


func _on_set_van_fuel_pressed() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var van_blocks: Array = Game.get_blocks_by_name("面包车")
	if van_blocks.is_empty():
		_log("当前地图上没有面包车地块")
		return
	var van: MapBlock = van_blocks[0]
	var max_fuel: int = van.get_van_fuel_max()
	var value: int = clampi(_van_fuel_edit.text.to_int(), 0, maxi(max_fuel, 0))
	van.van_fuel = value
	# 无需手动刷新：MissionProgressPanel._process 每帧自读 van_fuel 刷新显示。
	_log("将面包车燃料设为 " + str(value) + "/" + str(max_fuel))


func _on_set_mission_state_pressed() -> void:
	if Game == null or not is_instance_valid(Game) or Game.mission_config == null:
		_log("当前没有任务配置")
		return
	var key: String = _mission_key_edit.text.strip_edges()
	if key.is_empty():
		return
	var raw_value: String = _mission_value_edit.text.strip_edges()
	var value: Variant = _parse_mission_value(raw_value)
	Game.mission_config.mission_state[key] = value
	_log("设置任务标记 " + key + " = " + str(value))


func _parse_mission_value(raw: String) -> Variant:
	if raw.to_lower() == "true":
		return true
	if raw.to_lower() == "false":
		return false
	if raw.is_valid_int():
		return raw.to_int()
	if raw.is_valid_float():
		return raw.to_float()
	return raw


# === 回合 ===

func _build_turn_section() -> void:
	_add_row([
		_make_button("跳过目标玩家下回合", _on_skip_turn_pressed),
		_make_button("给目标玩家额外回合", _on_extra_turn_pressed),
	])


func _on_skip_turn_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	if Game != null and is_instance_valid(Game) and Game.state_machine != null:
		Game.state_machine.skip_next_turn(player)


func _on_extra_turn_pressed() -> void:
	var player: Variant = _get_selected_player()
	if player == null or not is_instance_valid(player):
		return
	if Game != null and is_instance_valid(Game) and Game.state_machine != null:
		Game.state_machine.queue_extra_turn(player)


# === 调试 ===

func _build_debug_section() -> void:
	_add_row([_make_button("打印当前游戏状态到日志", _on_dump_state_pressed)])


func _on_dump_state_pressed() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var lines: Array = []
	lines.append("==== 作弊菜单：游戏状态快照 ====")
	if Game.state_machine != null:
		lines.append("轮数：%d，当前状态：%d" % [Game.state_machine.get_turn_number(), Game.state_machine.get_game_state()])
		var current: Variant = Game.state_machine.get_current_player()
		if current != null and is_instance_valid(current):
			lines.append("当前回合玩家：" + current.player_name)
	for player in Game.get_all_players():
		if player == null or not is_instance_valid(player):
			continue
		lines.append("玩家 %s：HP=%d/%d 饥饿=%d 行动点=%d/%d 手牌=%d 装备=%d 怪物=%d 存活=%s" % [
			player.player_name, player.hp, player.max_hp, player.hunger,
			player.action_count, player.max_action_count,
			player.hand.size(), player.equipment_zone.size(), player.monster_zone.size(),
			str(player.is_alive()),
		])
	if Game.mission_config != null:
		lines.append("任务标记：" + str(Game.mission_config.mission_state))
	var van_blocks: Array = Game.get_blocks_by_name("面包车")
	if not van_blocks.is_empty():
		var van: MapBlock = van_blocks[0]
		lines.append("面包车燃料：%d/%d" % [van.get_van_fuel(), van.get_van_fuel_max()])
	print("\n".join(lines))
	for line in lines:
		_log(line)


# === 外部接口 ===

func toggle() -> void:
	visible = not visible
	if visible:
		refresh_player_list()
