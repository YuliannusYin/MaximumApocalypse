extends Node2D

# 怪物卡使用的场景路径（复用了之前的 Card.tscn 或 CardMonster.tscn）
const CARD_SCENE_PATH = "res://scenes/MonsterCard.tscn"
const CARD_DRAW_SPEED = 0.1

# 🟢 当前局选择的怪物类型，可选: "alien", "mutant", "robot", "zombie"
@export var current_monster_type: String = "alien"

# 展开并洗好的怪物卡牌堆（存放卡牌数据字典）
var monster_deck: Array[Dictionary] = []

func _ready() -> void:
	_load_monster_deck_data()
	_update_deck_ui()

## 核心逻辑 1：读取 JSON 并按 count 展开洗牌
func _load_monster_deck_data() -> void:
	monster_deck.clear()
	
	var json_path = "res://data/monsters/%s.json" % current_monster_type
	
	if not FileAccess.file_exists(json_path):
		print("【错误】找不到怪物数据文件: ", json_path)
		return
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		print("【错误】怪物 JSON 解析失败: ", json.get_error_message())
		return
		
	var data: Dictionary = json.data
	
	if data.has("cards") and data["cards"] is Array:
		for card_info in data["cards"]:
			var monster_name = card_info.get("monster_name", "未知怪物")
			var count = card_info.get("count", 1)
			
			# 将该怪物的基本数据打包
			var card_data = {
				"monster_name": monster_name,
				"english_name": card_info.get("english_name", ""),
				"monster_level": card_info.get("monster_level", "normal"),
				"max_hp": card_info.get("max_hp", 10),
				"initial_hp": card_info.get("initial_hp", 10),
				"attack_damage": card_info.get("attack_damage", 1),
				"range": card_info.get("range", "none"),
				"skills": card_info.get("skills", [])
			}
			
			# 🟢 关键：根据 count 展开加入牌池
			for i in range(count):
				monster_deck.append(card_data.duplicate(true))
				
		# 🟢 彻底洗牌
		monster_deck.shuffle()
		print("【成功】怪物牌堆 [%s] 加载完成！展开后共包含 %d 张怪物牌。" % [current_monster_type, monster_deck.size()])
		

## 核心逻辑 2：抽取怪物卡并处理 UI 生成与显示
func draw_monster_card() -> void:
	if monster_deck.is_empty():
		print("怪物牌库已经空了！")
		return

	# 弹出第一张怪物卡数据
	var card_data = monster_deck.pop_front()
	
	# 如果牌抽光了，关闭桌面牌堆显示
	if monster_deck.size() == 0:
		if has_node("Area2D/CollisionShape2D"):
			$Area2D/CollisionShape2D.set_deferred("disabled", true)
		if has_node("Sprite2D"):
			$Sprite2D.visible = false
		if has_node("RichTextLabel"):
			$RichTextLabel.visible = false
	
	_update_deck_ui()
	
	# 实例化卡牌场景
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	
	# ==================== 1. 设置【通用怪物卡背面】 ====================
	var back_node = new_card.get_node_or_null("VisualContainer/CardBackImage") as Sprite2D
	var back_texture: Texture2D = back_node.texture
			
	# ==================== 2. 设置【怪物正面图片】（中文名匹配） ====================
	# 路径示例: res://images/图包/怪物卡牌图包/alien/外星收割者.png
	var monster_front_path = "res://images/图包/怪物卡牌图包/%s/%s.png" % [current_monster_type, card_data["monster_name"]]
	
	# 方案 B 结构的正面节点路径
	var front_node = new_card.get_node_or_null("VisualContainer/CardImage") as Sprite2D
	
	if front_node and ResourceLoader.exists(monster_front_path):
		var front_texture: Texture2D = load(monster_front_path)
		front_node.texture = front_texture
		
		# 🟢 方案 B 纯像素等比例覆盖算法（彻底防止高亮抖动和比例缩放不一）
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
		print("【警告】未找到怪物卡正面图片: ", monster_front_path)
	# ====================================================================
	
	# 给节点命名并挂载怪物数据
	new_card.name = "MonsterCard_" + card_data["monster_name"]
	
	# 将怪物的属性直接附加到 Card 节点实例上（方便日后战斗逻辑读取）
	new_card.set_meta("monster_data", card_data)
	if "card_name" in new_card:
		new_card.card_name = card_data["monster_name"]
		
	# 设置出牌初始位置为当前怪物牌堆位置
	new_card.global_position = self.global_position
	
	# 送入卡牌管理器和场上/手牌布局（根据你项目中的节点命名调整，如 MonsterZone 或 PlayerHand）
	if has_node("../MonsterCardManager"):
		$"../MonsterCardManager".add_child(new_card)
	
	# 如果你有一个怪物区域手牌组件，这里可以调用它：
	if has_node("../MonsterZone"):
		$"../MonsterZone".add_card_to_zone(new_card, CARD_DRAW_SPEED)
	
	# 播放翻牌动画
	if new_card.has_node("AnimationPlayer"):
		new_card.get_node("AnimationPlayer").play("card_flip")

func _update_deck_ui() -> void:
	if has_node("RichTextLabel"):
		$RichTextLabel.text = str(monster_deck.size())
