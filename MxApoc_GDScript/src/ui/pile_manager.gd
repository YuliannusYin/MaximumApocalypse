class_name PileManager
extends Node

## 牌堆管理器。
## 管理右侧 7 个牌堆面板的配置、计数、高亮、点击。

signal pile_clicked(pile_key: String)
signal discard_pile_clicked(pile_type: String)

const PILE_CONFIGS: Array = [
	{"key": "red_scavenge", "node": "RedScavengePile", "color": Color(0.55, 0.25, 0.25, 1.0), "label": "红拾荒"},
	{"key": "green_scavenge", "node": "GreenScavengePile", "color": Color(0.25, 0.55, 0.30, 1.0), "label": "绿拾荒"},
	{"key": "blue_scavenge", "node": "BlueScavengePile", "color": Color(0.25, 0.40, 0.60, 1.0), "label": "蓝拾荒"},
	{"key": "game_deck", "node": "GameDeckPile", "color": Color(0.40, 0.25, 0.55, 1.0), "label": "游戏牌堆"},
	{"key": "monster_pile", "node": "MonsterPile", "color": Color(0.18, 0.18, 0.20, 1.0), "label": "怪物牌堆"},
	{"key": "scavenge_discard", "node": "ScavengeDiscardPile", "color": Color(0.35, 0.30, 0.25, 1.0), "label": "拾荒弃牌"},
	{"key": "game_discard", "node": "GameDiscardPile", "color": Color(0.30, 0.25, 0.35, 1.0), "label": "角色弃牌"},
]

var _pile_views: Dictionary = {}
var _ui_layer: CanvasLayer


func setup(ui_layer: CanvasLayer) -> void:
	_ui_layer = ui_layer


func wire_pile_nodes() -> void:
	for config in PILE_CONFIGS:
		var panel: Panel = _ui_layer.get_node(config["node"])
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
	# 可点击牌堆（摸牌/拾荒）连接点击
	for click_key in ["game_deck", "red_scavenge", "green_scavenge", "blue_scavenge"]:
		var click_entry: Variant = _pile_views.get(click_key)
		if click_entry != null:
			var click_panel: Panel = click_entry["panel"]
			click_panel.gui_input.connect(_on_pile_gui_input.bind(click_key))


func apply_pile_styles() -> void:
	for config in PILE_CONFIGS:
		var entry: Variant = _pile_views.get(config["key"])
		if entry == null:
			continue
		entry["panel"].add_theme_stylebox_override("panel", _make_pile_style(config["color"], false))
	refresh_pile_highlights()


## 教程挖洞：单个牌堆的全局矩形。
func get_pile_rect(key: String) -> Rect2:
	var entry: Variant = _pile_views.get(key)
	if entry == null:
		return Rect2()
	var panel: Panel = entry["panel"]
	if panel == null or not is_instance_valid(panel):
		return Rect2()
	return panel.get_global_rect()


## 教程挖洞：多个牌堆的包围盒。
func get_piles_union_rect(keys: Array) -> Rect2:
	var merged := Rect2()
	for key in keys:
		var r: Rect2 = get_pile_rect(str(key))
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if merged.size == Vector2.ZERO:
			merged = r
		else:
			merged = merged.merge(r)
	return merged


func refresh_pile_counts(local_player: Variant = null) -> void:
	_set_pile_count("red_scavenge", _get_pile_count(Game.red_scavenge_pile))
	_set_pile_count("green_scavenge", _get_pile_count(Game.green_scavenge_pile))
	_set_pile_count("blue_scavenge", _get_pile_count(Game.blue_scavenge_pile))
	_set_pile_count("game_deck", _get_current_player_deck_count(local_player))
	_set_pile_count("monster_pile", _get_pile_count(Game.monster_pile))
	_set_pile_count("scavenge_discard", _get_pile_count(Game.scavenge_discard_pile))
	_set_pile_count("game_discard", _get_current_player_discard_count(local_player))


## 弃牌堆计数。local_player 传入时（联机客机）用本地玩家，否则用当前回合玩家（热座/主机）。
func _get_current_player_discard_count(local_player: Variant = null) -> int:
	var current: Variant = local_player if local_player != null else Game.get_current_player()
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


## 游戏牌堆计数。local_player 传入时（联机客机）用本地玩家，否则用当前回合玩家（热座/主机）。
func _get_current_player_deck_count(local_player: Variant = null) -> int:
	var current: Variant = local_player if local_player != null else Game.get_current_player()
	if current == null or not is_instance_valid(current):
		return 0
	var deck: Variant = current.get("game_deck")
	if deck == null or not is_instance_valid(deck):
		return 0
	return deck.size() if deck.has_method("size") else deck.get("cards").size()


func _make_pile_style(color: Color, highlight: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.24)
	if highlight:
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color("#F3C45B")
		style.shadow_color = Color(1.0, 0.62, 0.18, 0.34)
		style.shadow_size = 6
		style.shadow_offset = Vector2.ZERO
	else:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.40, 0.34, 0.25, 1.0)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
		style.shadow_size = 4
		style.shadow_offset = Vector2(1, 2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


## 根据当前玩家行动状态刷新可操作牌堆的金黄色高亮。
## local_player 传入时（联机）：仅当本地玩家 == 当前回合玩家才高亮，别人回合不高亮。
func refresh_pile_highlights(local_player: Variant = null) -> void:
	var current: Variant = Game.get_current_player()
	# 非本方回合：全部不高亮（acted 为 null）
	var acted: Variant = current
	if local_player != null and current != null and is_instance_valid(current) and local_player != current:
		acted = null
	var can_act: bool = false
	var block_colors: PackedStringArray = []
	if acted != null and is_instance_valid(acted):
		can_act = acted.get("in_phase") == "action" and acted.get("action_count") > 0
		var block: Variant = acted.get("current_block")
		if block != null and is_instance_valid(block):
			block_colors = block.get("scavenge_colors")
	for config in PILE_CONFIGS:
		var highlight: bool = false
		if can_act:
			match config["key"]:
				"game_deck":
					highlight = _get_current_player_deck_count() > 0
				"red_scavenge":
					highlight = "red" in block_colors and _get_pile_count(Game.red_scavenge_pile) > 0
				"green_scavenge":
					highlight = "green" in block_colors and _get_pile_count(Game.green_scavenge_pile) > 0
				"blue_scavenge":
					highlight = "blue" in block_colors and _get_pile_count(Game.blue_scavenge_pile) > 0
		var entry: Variant = _pile_views.get(config["key"])
		if entry != null:
			entry["panel"].add_theme_stylebox_override("panel", _make_pile_style(config["color"], highlight))


## 判断牌堆当前是否可点击（可操作）。
## local_player 传入时（联机）：仅当本地玩家 == 当前回合玩家才可点击。
func is_pile_clickable(pile_key: String, local_player: Variant = null) -> bool:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		return false
	if local_player != null and local_player != current:
		return false
	if current.get("in_phase") != "action" or current.get("action_count") <= 0:
		return false
	match pile_key:
		"game_deck":
			return _get_current_player_deck_count() > 0
		"red_scavenge", "green_scavenge", "blue_scavenge":
			var block: Variant = current.get("current_block")
			if block == null or not is_instance_valid(block):
				return false
			var color_key: String = pile_key.replace("_scavenge", "")
			if not color_key in block.get("scavenge_colors"):
				return false
			var pile: Variant = null
			match pile_key:
				"red_scavenge":
					pile = Game.red_scavenge_pile
				"green_scavenge":
					pile = Game.green_scavenge_pile
				"blue_scavenge":
					pile = Game.blue_scavenge_pile
			return _get_pile_count(pile) > 0
		_:
			return false


## 牌堆中文名。
func pile_display_name(pile_key: String) -> String:
	match pile_key:
		"game_deck":
			return "游戏牌堆"
		"red_scavenge":
			return "红色拾荒牌堆"
		"green_scavenge":
			return "绿色拾荒牌堆"
		"blue_scavenge":
			return "蓝色拾荒牌堆"
		_:
			return "牌堆"


# === 弃牌堆面板点击 ===

func _on_discard_pile_gui_input(event: InputEvent, pile_type: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		discard_pile_clicked.emit(pile_type)


## 可操作牌堆（摸牌/拾荒）的鼠标点击处理。
func _on_pile_gui_input(event: InputEvent, pile_key: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pile_clicked.emit(pile_key)
