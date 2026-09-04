class_name PileManager
extends Node

## 牌堆管理器。
## 管理右侧 7 个牌堆面板的配置、计数、高亮、点击。
## 高亮：可操作=绿色，玩家单击选中=金黄色，确认/取消后若仍可操作则回绿色。

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
var _selected_pile_key: String = ""
var _acting_player: Variant = null


func setup(ui_layer: CanvasLayer) -> void:
	_ui_layer = ui_layer


## 设置当前实际操作玩家；为空时回退到真实回合玩家。
func set_acting_player(player: Variant) -> void:
	_acting_player = player


func _get_acting_player() -> Variant:
	if _acting_player != null and is_instance_valid(_acting_player):
		return _acting_player
	return Game.get_current_player()


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
		entry["panel"].add_theme_stylebox_override("panel", _make_pile_style(config["color"], "none"))
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


func refresh_pile_counts() -> void:
	_set_pile_count("red_scavenge", _get_pile_count(Game.red_scavenge_pile))
	_set_pile_count("green_scavenge", _get_pile_count(Game.green_scavenge_pile))
	_set_pile_count("blue_scavenge", _get_pile_count(Game.blue_scavenge_pile))
	_set_pile_count("game_deck", _get_current_player_deck_count())
	_set_pile_count("monster_pile", _get_pile_count(Game.monster_pile))
	_set_pile_count("scavenge_discard", _get_pile_count(Game.scavenge_discard_pile))
	_set_pile_count("game_discard", _get_current_player_discard_count())


func _get_current_player_discard_count() -> int:
	var current: Variant = _get_acting_player()
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
	var current: Variant = _get_acting_player()
	if current == null or not is_instance_valid(current):
		return 0
	var deck: Variant = current.get("game_deck")
	if deck == null or not is_instance_valid(deck):
		return 0
	return deck.size() if deck.has_method("size") else deck.get("cards").size()


## 同步当前选中牌堆并刷新高亮（可操作=绿，已选中=黄）。
func set_selected_pile_key(pile_key: String) -> void:
	_selected_pile_key = pile_key
	refresh_pile_highlights()


func _make_pile_style(color: Color, highlight: String = "none") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.24)
	match highlight:
		"green":
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.2, 0.8, 0.2, 1.0)
			style.shadow_color = Color(0.25, 0.90, 0.35, 0.35)
			style.shadow_size = 6
			style.shadow_offset = Vector2.ZERO
		"golden":
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color("#F3C45B")
			style.shadow_color = Color(1.0, 0.62, 0.18, 0.34)
			style.shadow_size = 6
			style.shadow_offset = Vector2.ZERO
		_:
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


## 根据当前玩家行动状态刷新牌堆高亮：可操作=绿色，已选中=金黄色。
func refresh_pile_highlights() -> void:
	for config in PILE_CONFIGS:
		var highlight: String = "none"
		if is_pile_clickable(config["key"]):
			if config["key"] == _selected_pile_key:
				highlight = "golden"
			else:
				highlight = "green"
		var entry: Variant = _pile_views.get(config["key"])
		if entry != null:
			entry["panel"].add_theme_stylebox_override("panel", _make_pile_style(config["color"], highlight))


## 判断牌堆当前是否可点击（可操作）。
func is_pile_clickable(pile_key: String) -> bool:
	var current: Variant = _get_acting_player()
	if current == null or not is_instance_valid(current):
		return false
	var in_action: bool = current.get_effective_phase() == "action" if current.has_method("get_effective_phase") else current.get("in_phase") == "action"
	var action_count: int = current.get_effective_action_count() if current.has_method("get_effective_action_count") else current.get("action_count")
	if not in_action or action_count <= 0:
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
