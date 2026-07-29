#ScavengeCardDeck.gd
extends Node2D

const CARD_SCENE_PATH = "res://scenes/ScavengeCard.tscn"
const CARD_DRAW_SPEED = 0.1
const MAX_PLAYER_HAND_CARD_COUNT = 10

# 任务 ID（由 Inspector 配置，对应 data/missions/mission_{id}.json）
@export var mission_id: String = "1"

# 三色牌堆数据（按 mission 的 scavenge_config 构建后的卡牌数据字典列表）
var scavenge_decks: Dictionary = {
	"red": [],
	"green": [],
	"blue": []
}

# 所有拾荒卡牌模板（card_name → card_data），从 blue/green/red/gray.json 加载
var _card_templates: Dictionary = {}

# 三色牌堆对应的 RichTextLabel 节点路径（按场景中的节点顺序）
const DECK_UI_NODES = {
	"red": "RichTextLabel",
	"green": "RichTextLabel2",
	"blue": "RichTextLabel3"
}

# 三色碰撞体节点路径（如果 CollisionShape2D 节点在 Area2D 下面请按真实相对路径填写）
const DECK_SHAPE_NODES = {
	"red": "Area2D/CollisionShape2D",
	"green": "Area2D/CollisionShape2D2",
	"blue": "Area2D/CollisionShape2D3"
}

# 拾荒卡牌图片所在目录
const SCAVENGE_IMAGE_DIR = "res://images/图包/拾荒卡牌图包"
const CARD_BACK_PATH = "res://images/图包/拾荒卡牌图包/拾荒卡牌背面.jpg"


func _ready() -> void:
	_load_all_card_templates()
	_build_scavenge_decks_from_mission()
	_update_all_deck_ui()
	#_print_debug_decks()

## 加载所有拾荒卡牌模板（blue/green/red/gray.json）到 _card_templates
func _load_all_card_templates() -> void:
	_card_templates.clear()
	var colors = ["blue", "green", "red", "gray"]
	for color in colors:
		var json_path = "res://data/scavenge/%s.json" % color
		_load_card_templates_from_file(json_path, color)


## 从单个 JSON 文件加载卡牌模板
func _load_card_templates_from_file(json_path: String, color: String) -> void:
	if not FileAccess.file_exists(json_path):
		print("【错误】找不到拾荒牌数据文件: ", json_path)
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		print("【错误】拾荒牌 JSON 解析失败[%s]: " % color, json.get_error_message())
		return

	var data: Dictionary = json.data
	if data.has("cards") and data["cards"] is Array:
		for card_info in data["cards"]:
			var card_name = card_info.get("card_name", "未知卡牌")
			# 打包卡牌模板数据
			var card_data = {
				"card_name": card_name,
				"english_name": card_info.get("english_name", ""),
				"card_type": card_info.get("card_type", "action"),
				"source_color": color,
				"size": card_info.get("size", 0),
				"value": card_info.get("value", null),
				"charge_type": card_info.get("charge_type", null),
				"charge_max": card_info.get("charge_max", 0),
				"charge_initial": card_info.get("charge_initial", 0),
				"skills": card_info.get("skills", []),
				"is_special": _check_is_special(card_info.get("skills", []))
			}
			_card_templates[card_name] = card_data


## 检查卡牌是否为特殊抓取牌（技能中含 on_draw_scavenge_card 或 before_draw_scavenge_card 触发器）
func _check_is_special(skills: Array) -> bool:
	for skill in skills:
		var trigger = skill.get("trigger", "")
		if trigger == "on_draw_scavenge_card" or trigger == "before_draw_scavenge_card":
			return true
	return false


## 从任务 JSON 读取 scavenge_config 并构建三色牌堆
func _build_scavenge_decks_from_mission() -> void:
	for color in scavenge_decks.keys():
		scavenge_decks[color].clear()

	var mission_path = "res://data/missions/mission_%s.json" % mission_id
	if not FileAccess.file_exists(mission_path):
		print("【错误】找不到任务数据文件: ", mission_path)
		return

	var file = FileAccess.open(mission_path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		print("【错误】任务 JSON 解析失败: ", json.get_error_message())
		return

	var data: Dictionary = json.data
	if not data.has("scavenge_config"):
		print("【警告】任务 %s 没有 scavenge_config" % mission_id)
		return

	var scavenge_config: Dictionary = data["scavenge_config"]

	# 为每个颜色构建牌堆
	for color in scavenge_decks.keys():
		if not scavenge_config.has(color):
			continue

		var pile_config = scavenge_config[color]
		if not pile_config is Array:
			continue

		for entry in pile_config:
			var card_name = entry.get("card_name", "")
			var count = entry.get("count", 1)

			# 查找匹配的卡牌模板（前缀匹配）
			var matching_cards = _find_matching_cards(card_name)
			if matching_cards.is_empty():
				print("【警告】未找到匹配的拾荒卡牌: ", card_name)
				continue

			# 按 count 添加卡牌到牌堆（每次随机选一个变体）
			for i in range(count):
				var chosen = matching_cards[randi() % matching_cards.size()]
				var card_copy = chosen.duplicate(true)
				card_copy["pile_color"] = color
				scavenge_decks[color].append(card_copy)

		# 洗牌
		scavenge_decks[color].shuffle()


## 前缀匹配：先精确匹配，再前缀匹配
## "食物" 匹配 "食物（微量）"、"食物（小额）" 等所有以"食物"开头的卡
func _find_matching_cards(card_name: String) -> Array:
	# 1. 精确匹配
	if _card_templates.has(card_name):
		return [_card_templates[card_name]]

	# 2. 前缀匹配：找所有 card_name 以指定名称开头的卡
	var matches: Array = []
	for key in _card_templates.keys():
		if key.begins_with(card_name):
			matches.append(_card_templates[key])

	return matches


## 根据颜色获取对应的 CollisionShape2D 全局坐标
func _get_deck_global_position(color: String) -> Vector2:
	var shape_path = DECK_SHAPE_NODES.get(color, "")
	if shape_path and has_node(shape_path):
		return get_node(shape_path).global_position
	return global_position


## 抓取指定颜色的拾荒牌（由 InputManager 调用）
func draw_scavenge_card(color: String) -> void:
	if not scavenge_decks.has(color):
		print("【错误】未知的拾荒牌颜色: ", color)
		return

	if scavenge_decks[color].is_empty():
		print("【提示】%s 色拾荒牌堆已空！" % color)
		return

	if $"../PlayerHand".current_hand_count >= MAX_PLAYER_HAND_CARD_COUNT:
		print("手牌满 %d" % MAX_PLAYER_HAND_CARD_COUNT)
		return

	# 弹出牌堆顶第一张牌的数据
	var card_data = scavenge_decks[color].pop_front()

	# 牌堆空了则关闭对应显示
	if scavenge_decks[color].size() == 0:
		print("【提示】%s 色拾荒牌堆已抓完！" % color)

	_update_deck_ui(color)

	# 特殊牌提示
	if card_data.get("is_special", false):
		print("【特殊牌】抓取到特殊牌 [%s]，需触发抓取效果（待接入技能系统）" % card_data["card_name"])

	# 实例化卡牌场景
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()

	# ==================== 1. 设置【卡牌背面】 ====================
	# 拾荒牌统一使用同一张背面图
	var back_node = new_card.get_node_or_null("VisualContainer/CardBackImage") as Sprite2D
	var back_texture: Texture2D = null

	if back_node:
		if ResourceLoader.exists(CARD_BACK_PATH):
			back_texture = load(CARD_BACK_PATH)
			back_node.texture = back_texture
		else:
			print("【警告】未找到拾荒卡牌背面图片: ", CARD_BACK_PATH)

	# ==================== 2. 设置【卡牌正面】并精准校对 ====================
	var front_texture = _load_card_front_texture(card_data["card_name"])
	var front_node = new_card.get_node_or_null("VisualContainer/CardImage") as Sprite2D

	if front_node and front_texture:
		front_node.texture = front_texture

		# 纯像素等比例覆盖算法（与 SurvivorCard/MonsterCard 一致）
		if back_node and back_texture and front_texture:
			var back_size: Vector2 = back_texture.get_size()
			var front_size: Vector2 = front_texture.get_size()

			if back_node.region_enabled:
				back_size = back_node.region_rect.size

			var pixel_ratio_x = back_size.x / front_size.x
			var pixel_ratio_y = back_size.y / front_size.y

			front_node.scale = Vector2(pixel_ratio_x, pixel_ratio_y)
			front_node.position = Vector2.ZERO
			front_node.centered = back_node.centered
			front_node.offset = back_node.offset
	else:
		print("【警告】未找到拾荒卡牌正面图片: ", card_data["card_name"])
	# ====================================================================

	# 给节点命名并挂载卡牌数据
	new_card.name = "ScavengeCard_" + card_data["card_name"]
	new_card.card_data = card_data
	new_card.card_name = card_data["card_name"]

	# 设置初始位置为对应颜色碰撞体的全局位置（改动点）
	new_card.global_position = _get_deck_global_position(color)

	# 送入卡牌管理器和手牌布局
	$"../ScavengeCardManager".add_child(new_card)
	$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)

	# 播放翻牌动画
	if new_card.has_node("AnimationPlayer"):
		new_card.get_node("AnimationPlayer").play("card_flip")


## 加载卡牌正面图片（兼容 .png 和 .jpg）
func _load_card_front_texture(card_name: String) -> Texture2D:
	var extensions = [".png", ".jpg"]
	for ext in extensions:
		var path = "%s/%s%s" % [SCAVENGE_IMAGE_DIR, card_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## 更新指定颜色牌堆的数量显示
func _update_deck_ui(color: String) -> void:
	var node_path = DECK_UI_NODES.get(color, "")
	if node_path and has_node(node_path):
		get_node(node_path).text = str(scavenge_decks[color].size())


## 更新所有牌堆的数量显示
func _update_all_deck_ui() -> void:
	for color in scavenge_decks.keys():
		_update_deck_ui(color)


## 打印当前各色牌堆打乱后的详细列表（调试用）
func _print_debug_decks() -> void:
	print("========== 拾荒牌堆明细列表（从堆顶到堆底） ==========")
	for color in ["red", "green", "blue"]:
		var names: Array = []
		for card in scavenge_decks[color]:
			names.append(card.get("card_name", "未知卡牌"))
		print("【%s包】(%d张): %s" % [color.to_upper(), names.size(), " -> ".join(names)])
	print("==================================================")
