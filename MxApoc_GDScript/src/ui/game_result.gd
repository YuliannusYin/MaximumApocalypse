extends Control

## 游戏结算场景。
## 场景结构由 GameResult.tscn 提供（固定 1430×780 绝对坐标布局），
## 脚本仅在 _ready 中填充动态数据：胜负标题、时长、角色牌、统计表格。
## 归档接入：结算页就绪时（玩家模式 + 取得有效胜负结果）执行一次归档
## （ArchiveManager.record_game_result），并展示本局新达成成就。

const _STAT_HEADERS: PackedStringArray = [
	"造成伤害", "受到伤害", "击杀", "移动", "摸牌", "拾荒",
	"减饥饿", "回复HP", "治疗量", "用牌", "技能", "回合",
]

const _NAME_COL_WIDTH: float = 100.0
const _STAT_COL_WIDTH: float = 62.0
const _ROW_HEIGHT: float = 30.0

@onready var _title_label: Label = $TitleLabel
@onready var _duration_label: Label = $DurationLabel
@onready var _role_cards: Array[TextureRect] = [
	$Seat1/RoleCard,
	$Seat2/RoleCard,
	$Seat3/RoleCard,
	$Seat4/RoleCard,
]
@onready var _stats_grid: GridContainer = $StatsScroll/StatsGrid
@onready var _back_button: Button = $BottomBar/BackButton
@onready var _log_button: Button = $BottomBar/LogButton
@onready var _restart_button: Button = $BottomBar/RestartButton

var _log_panel: Node = null

## 归档防重入标记：同一结算页实例只归档一次（_ready 重复触发或二次调用直接返回）。
## 重新开局后的结算页是新实例，标记随之重置，不受影响。
var _archive_recorded: bool = false
## 本局新达成的成就定义列表（record_game_result 返回，元素含 id/name/description）。
var _new_achievements: Array = []


func _ready() -> void:
	# 读取本局数据
	var result: int = -1
	var duration_msec: int = 0
	var all_stats: Dictionary = {}
	var current_player: Variant = null
	var players: Array = []
	if Game != null and is_instance_valid(Game):
		if Game.state_machine != null:
			result = Game.state_machine.game_result
			current_player = Game.state_machine.last_player
		if Game.stats_tracker != null:
			all_stats = Game.stats_tracker.get_all_stats()
			duration_msec = Game.stats_tracker.game_duration_msec
		players = Game.players
		_fill_title(result, players)
		_fill_duration(duration_msec)
		_fill_role_cards(players)
		_fill_stats(all_stats, current_player, players)
		_back_button.pressed.connect(_on_back_pressed)
		_log_button.pressed.connect(_on_view_log_pressed)
		_restart_button.pressed.connect(_on_restart_pressed)
	# 结算归档（玩家模式 + 正常结算时执行一次）与本局新成就展示
	_record_archive(result)
	_fill_new_achievements()


# === 数据填充 ===

func _fill_title(result: int, players: Array) -> void:
	var alive_count := 0
	for player in players:
		if player != null and is_instance_valid(player) and player.is_alive():
			alive_count += 1
	var total := players.size()
	if result == GameStateMachine.GameResult.WIN and total > 0:
		if alive_count == total:
			_title_label.text = "薪火同存"
			_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			_title_label.text = "余烬残存"
			_title_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		_title_label.text = "无人生还"
		_title_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))


func _fill_duration(duration_msec: int) -> void:
	var total_sec: int = int(duration_msec / 1000)
	_duration_label.text = "%02d:%02d" % [total_sec / 60, total_sec % 60]


func _fill_role_cards(players: Array) -> void:
	# 先清空所有角色牌
	for card in _role_cards:
		card.texture = null
	# 按 seat_number 映射到座位槽（seat_number 是 0-based）
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var seat: int = player.seat_number
		if seat < 0 or seat >= _role_cards.size():
			continue
		var eng: String = player.role_card.english_name
		var tex: Texture2D = ImageCache.get_role_card_texture(eng, player.is_alive())
		_role_cards[seat].texture = tex


func _fill_stats(all_stats: Dictionary, current_player: Variant, players: Array) -> void:
	# 清空旧内容
	for child in _stats_grid.get_children():
		child.queue_free()
	_stats_grid.columns = _STAT_HEADERS.size() + 1
	var header_sb := _make_stylebox(Color(0.22, 0.22, 0.28))
	var normal_sb := _make_stylebox(Color(0.12, 0.12, 0.15))
	var highlight_sb := _make_stylebox(Color(0.35, 0.3, 0.18))
	var normal_color := Color(0.92, 0.92, 0.92)
	var highlight_color := Color(1.0, 0.95, 0.6)
	# 表头行
	_stats_grid.add_child(_make_cell("玩家", _NAME_COL_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, header_sb, 14, Color(0.9, 0.9, 0.9)))
	for h in _STAT_HEADERS:
		_stats_grid.add_child(_make_cell(h, _STAT_COL_WIDTH, HORIZONTAL_ALIGNMENT_CENTER, header_sb, 14, Color(0.9, 0.9, 0.9)))
	# 玩家行
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var is_current: bool = current_player != null and player == current_player
		var row_sb: StyleBoxFlat = highlight_sb if is_current else normal_sb
		var text_color: Color = highlight_color if is_current else normal_color
		var pname: String = player.player_name
		var name_text: String = ("▶ " + pname) if is_current else pname
		_stats_grid.add_child(_make_cell(name_text, _NAME_COL_WIDTH, HORIZONTAL_ALIGNMENT_LEFT, row_sb, 13, text_color))
		for value in _stats_to_array(all_stats.get(player, null)):
			_stats_grid.add_child(_make_cell(str(value), _STAT_COL_WIDTH, HORIZONTAL_ALIGNMENT_CENTER, row_sb, 13, text_color))


# === 结算归档 ===

## 结算归档：仅玩家模式（Settings.dev_mode == false）且取得有效胜负结果时执行。
## 将本局统计（Game.stats_tracker 汇总）写入 ArchiveManager 并立即落盘，
## 取回本局新达成成就列表供 _fill_new_achievements 展示。
## result 非 WIN/LOSE（未结算/异常直入结算页）时不归档。
## _archive_recorded 防重入：同一结算页实例只归档一次；重新开局后的结算页
## 是新实例，标记重置，正常再次归档。
func _record_archive(result: int) -> void:
	if _archive_recorded:
		return
	_archive_recorded = true
	if Settings == null or not is_instance_valid(Settings) or Settings.dev_mode:
		return
	if ArchiveManager == null or not is_instance_valid(ArchiveManager):
		return
	if Game == null or not is_instance_valid(Game) or Game.stats_tracker == null:
		return
	var result_str: String = ""
	if result == GameStateMachine.GameResult.WIN:
		result_str = "win"
	elif result == GameStateMachine.GameResult.LOSE:
		result_str = "lose"
	else:
		return
	var summary: Dictionary = Game.stats_tracker.get_archive_summary(result_str)
	_new_achievements = ArchiveManager.record_game_result(summary)


## 新达成成就区块：在结算页右侧（座位区/统计表右旁的空区）动态构建，
## 结构为 标题「新达成成就」+ 滚动列表（每条成就：名称 + 描述）。
## 本局无新成就（开发者模式 / 未归档 / 无新解锁）时不创建该区块（天然隐藏）。
func _fill_new_achievements() -> void:
	if _new_achievements.is_empty():
		return
	var frame := PanelContainer.new()
	frame.name = "NewAchievements"
	frame.position = Vector2(1150.0, 130.0)
	frame.size = Vector2(270.0, 570.0)
	frame.add_theme_stylebox_override("panel", _make_stylebox(Color(0.16, 0.13, 0.08)))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	frame.add_child(outer)
	var title := Label.new()
	title.text = "新达成成就"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for def in _new_achievements:
		var ach_name := Label.new()
		ach_name.text = str(def.get("name", def.get("id", "")))
		ach_name.add_theme_font_size_override("font_size", 14)
		ach_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		list.add_child(ach_name)
		var desc := Label.new()
		desc.text = str(def.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		list.add_child(desc)
	add_child(frame)


# === 辅助函数 ===

func _make_stylebox(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


func _make_cell(text: String, min_w: float, align: int, sb: StyleBoxFlat, font_size: int, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_w, _ROW_HEIGHT)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	return panel


func _stats_to_array(stats: Variant) -> Array:
	if not (stats is PlayerStats):
		return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var ps: PlayerStats = stats
	return [
		ps.damage_dealt, ps.damage_taken, ps.kills, ps.moves, ps.draw_count,
		ps.scavenge_count, ps.hunger_reduced, ps.hp_recovered, ps.healing_done,
		ps.cards_used, ps.skill_uses, ps.turns_played,
	]


# === 按钮回调 ===

func _on_back_pressed() -> void:
	Game.state_machine.current_state = GameStateMachine.GameState.WAITING
	Game.players.clear()
	Game.map_area.clear()
	RoomState.clear()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameScene2D.tscn")


func _on_view_log_pressed() -> void:
	if _log_panel != null and is_instance_valid(_log_panel):
		return
	_log_panel = _create_log_panel()
	add_child(_log_panel)


func _create_log_panel() -> Control:
	# 全屏容器
	var panel := Control.new()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# 半透明背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(bg)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	panel.add_child(center)

	# 面板容器（固定大小）
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1000, 600)
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	frame.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "游戏日志"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# 滚动日志区
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	# 逐行添加日志
	var logs: Array = []
	if Game != null and is_instance_valid(Game):
		logs = Game.log_list
	if logs.is_empty():
		var empty := Label.new()
		empty.text = "（暂无日志）"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		content.add_child(empty)
	else:
		for msg in logs:
			var line := Label.new()
			line.text = str(msg)
			line.add_theme_font_size_override("font_size", 13)
			line.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
			content.add_child(line)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = "关闭 (Esc)"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close_log_pressed)
	vbox.add_child(close_btn)

	return panel


func _on_close_log_pressed() -> void:
	if _log_panel != null and is_instance_valid(_log_panel):
		_log_panel.queue_free()
		_log_panel = null


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_B:
			_on_back_pressed()
		KEY_R:
			_on_restart_pressed()
		KEY_L:
			_on_view_log_pressed()
		KEY_ESCAPE:
			if _log_panel != null and is_instance_valid(_log_panel):
				_on_close_log_pressed()
