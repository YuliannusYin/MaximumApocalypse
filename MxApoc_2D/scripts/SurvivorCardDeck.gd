#Deck.gd
extends Node2D

const CARD_SCENE_PATH = "res://scenes/SurvivorCard.tscn"
const CARD_DRAW_SPEED = 0.1
const MAX_PLAYER_HAND_CARD_COUNT = 10

# 🟢 接收内核指定的角色英文名 (例如: "surgeon", "mechanic", "firefighter", "veteran", "hunter", "gunslinger")
# 你可以在这里修改默认值，或者由 RoomState 分配
@export var character_id: String = "surgeon"

# 动态卡组池，存储当前角色所有卡牌的简要 UI 数据
var player_deck: Array[Dictionary] = []
# 当前角色的中文图包文件夹名称（从 JSON 中动态读取）
var character_folder_name: String = ""

func _ready() -> void:
	_load_character_deck_data()
	_update_deck_ui()

## 核心方法：动态读取指定角色的 JSON 数据并构建卡组
func _load_character_deck_data() -> void:
	player_deck.clear()
	
	# 1. 动态拼装 JSON 路径，例如 res://data/survivors/surgeon.json
	var json_path = "res://data/survivors/%s.json" % character_id
	
	if not FileAccess.file_exists(json_path):
		print("【错误】找不到角色的数据文件: ", json_path)
		return
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		print("【错误】JSON 解析失败: ", json.get_error_message())
		return
		
	var data: Dictionary = json.data
	
	# 2. 获取角色的中文名称，用于后面匹配“xx图包”文件夹
	# 比如 "外科医生" -> 对应的文件夹是 "外科医生图包"
	if data.has("character_name"):
		character_folder_name = data["character_name"] + "图包"
		# 特殊处理：如果你的 JSON 里写的是 "老兵"，而文件夹叫 "老兵与狗图包"，可以在这里做个小映射：
		if data["character_name"] == "老兵":
			character_folder_name = "老兵与狗图包"
	else:
		print("【警告】JSON 中缺少 character_name，无法匹配图包文件夹")
		return

	# 3. 遍历 deck 列表，根据 count 数量将卡牌 UI 数据压入牌库
	if data.has("deck") and data["deck"] is Array:
		for card_info in data["deck"]:
			var card_name = card_info.get("card_name", "未知卡牌")
			var count = card_info.get("count", 1)
			
			# 将这张牌需要用到的 UI 数据打包成一个小字典
			var ui_card_data = {
				"card_name": card_name,
				"card_type": card_info.get("card_type", "action")
			}
			
			# 根据 count 循环放入牌库
			for i in range(count):
				player_deck.append(ui_card_data.duplicate())
				
		# 4. 洗牌
		player_deck.shuffle()
		#print("【成功】加载角色 [%s] 成功，共生成了 %d 张卡牌。" % [data["character_name"], player_deck.size()])
		
		# ==================== 🟢 核心新增：同步改变牌堆（Deck）的外观 ====================
		var pure_character_name = character_folder_name.replace("图包", "")
		var deck_bg_path = "res://images/图包/求生者图包/%s/%s游戏牌背面.jpg" % [character_folder_name, pure_character_name]
		
		if $Sprite2D:
			if ResourceLoader.exists(deck_bg_path):
				$Sprite2D.texture = load(deck_bg_path)
				#print("【成功】牌堆皮肤已更换为: ", deck_bg_path)
			else:
				print("【警告】未找到牌堆皮肤图片: ", deck_bg_path)

func draw_card() -> void:
	if player_deck.is_empty():
		print("牌库已经空了！")
		return

	if $"../PlayerHand".current_hand_count >= MAX_PLAYER_HAND_CARD_COUNT:
		print("手牌满10")
		return

	# 弹出第一张牌的数据
	var card_ui_data = player_deck.pop_front()
	
	# 如果空了，关闭牌堆显示
	if player_deck.size() == 0:
		$Area2D/CollisionShape2D.set_deferred("disabled", true)
		$Sprite2D.visible = false
		$RichTextLabel.visible = false
	
	_update_deck_ui()
	
	# 实例化卡牌场景
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	

		
	# ==================== 1. 动态更换【卡牌背面】 ====================
	# 优先加载背面，因为我们要以背面的尺寸作为标准参照物
	var pure_character_name = character_folder_name.replace("图包", "")
	var card_back_path = "res://images/图包/求生者图包/%s/%s游戏牌背面.jpg" % [character_folder_name, pure_character_name]
	
	var back_node = new_card.get_node_or_null("VisualContainer/CardBackImage") as Sprite2D
	var back_texture: Texture2D = null
	
	if back_node:
		if ResourceLoader.exists(card_back_path):
			back_texture = load(card_back_path)
			back_node.texture = back_texture
		else:
			print("【警告】未找到卡牌背面图片: ", card_back_path)
	
# ==================== 2. 动态更换【卡牌正面】并精准校对 ====================
	var card_front_path = "res://images/图包/求生者图包/%s/%s.png" % [character_folder_name, card_ui_data["card_name"]]
	

	var front_node = new_card.get_node_or_null("VisualContainer/CardImage") as Sprite2D
	
	if front_node and ResourceLoader.exists(card_front_path):
		var front_texture: Texture2D = load(card_front_path)
		front_node.texture = front_texture
		
		# 🟢 方案 B 的绝对比例算法
		if back_node and back_texture and front_texture:
			var back_size: Vector2 = back_texture.get_size()
			var front_size: Vector2 = front_texture.get_size()
			
			if back_node.region_enabled:
				back_size = back_node.region_rect.size
			
			# 核心：因为正面是背面的子节点，背面的基础缩放已经是 1.0（相对子节点而言）
			# 我们只需要计算出正面图片“需要缩放多少才能和背面图片像素 1:1 一样大”
			var pixel_ratio_x = back_size.x / front_size.x
			var pixel_ratio_y = back_size.y / front_size.y
			
			# 直接把这个纯像素比例死死绑在正面的 scale 上
			front_node.scale = Vector2(pixel_ratio_x, pixel_ratio_y)
			
			# 100% 绝对对齐位置和属性
			front_node.position = Vector2.ZERO # 相对父级（背面）居中
			front_node.centered = back_node.centered
			front_node.offset = back_node.offset
				
	else:
		print("【警告】未找到卡牌正面图片或节点: ", card_front_path)
	# ====================================================================
	
	# 给新卡牌节点起个名字
	new_card.name = "Card_" + card_ui_data["card_name"]
	
	if "card_name" in new_card:
		new_card.card_name = card_ui_data["card_name"]
	
	new_card.global_position = self.global_position
	
	# 送入卡牌管理器和手牌布局
	$"../SurvivorCardManager".add_child(new_card)
	$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
	
	if new_card.has_node("AnimationPlayer"):
		new_card.get_node("AnimationPlayer").play("card_flip")

func _update_deck_ui() -> void:
	if $RichTextLabel:
		$RichTextLabel.text = str(player_deck.size())
