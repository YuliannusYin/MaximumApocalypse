# MonsterManagerNew.gd
class_name MonsterManagerNew
extends Node

## 当前激活的任务实体
var current_mission: Mission = null

## 内存缓存字典: "卡牌中文名" -> 卡牌 JSON 原始 Dictionary
var scavenge_card_templates: Dictionary = {}


# ==============================================================================
# 1. 模板预加载 API
# ==============================================================================

## 预加载所有拾荒卡 JSON 数据到内存字典中
## 示例: mission_manager.preload_scavenge_cards(["res://data/scavenge_blue.json", "res://data/scavenge_red.json"])
func preload_scavenge_cards(file_paths: Array[String]) -> void:
	scavenge_card_templates.clear()
	
	for path in file_paths:
		_load_scavenge_json_file(path)
		
	print("[MissionManager] 拾荒卡模板预加载完成，共加载 %d 种卡牌模板。" % scavenge_card_templates.size())


## 读取单个拾荒卡 JSON 文件并塞入模板字典
func _load_scavenge_json_file(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		push_error("[MissionManager] 拾荒卡 JSON 文件不存在: %s" % file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("[MissionManager] 拾荒卡 JSON 解析失败: %s, 错误: %s" % [file_path, json.get_error_message()])
		return
		
	var data_list = json.get_data()
	if not data_list is Array:
		push_error("[MissionManager] 拾荒卡 JSON 根节点必须是 Array: %s" % file_path)
		return
		
	for card_data in data_list:
		if card_data is Dictionary:
			var c_name: String = card_data.get("card_name", "")
			if c_name != "":
				scavenge_card_templates[c_name] = card_data
			else:
				push_warning("[MissionManager] 发现没有 card_name 的卡牌配置: %s" % file_path)


# ==============================================================================
# 2. 任务加载 API
# ==============================================================================

## 从指定的 JSON 文件路径加载任务
func load_mission_from_file(file_path: String) -> Mission:
	if not FileAccess.file_exists(file_path):
		push_error("[MissionManager] 任务 JSON 文件不存在: %s" % file_path)
		return null
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[MissionManager] 任务 JSON 解析失败: %s, 错误: %s" % [file_path, json.get_error_message()])
		return null
		
	var data = json.get_data()
	if not data is Dictionary:
		push_error("[MissionManager] 任务 JSON 格式错误，根节点必须为 Dictionary: %s" % file_path)
		return null
		
	var mission = Mission.new()
	mission.init_from_json_dict(data)
	current_mission = mission
	return mission


# ==============================================================================
# 3. 拾荒卡实例化 & 牌堆构建 API
# ==============================================================================

## 根据卡牌中文名，从预加载模板中实例化一张独立的 ScavengeCard
func create_scavenge_card_by_name(card_name: String) -> ScavengeCard:
	if not scavenge_card_templates.has(card_name):
		push_error("[MissionManager] 未找到名为 '%s' 的拾荒卡模板！" % card_name)
		return null
		
	var template_dict: Dictionary = scavenge_card_templates[card_name]
	
	# 实例化新的 ScavengeCard 实体
	var new_card: ScavengeCard = ScavengeCard.new()
	new_card.init_from_json_dict(template_dict)
	
	return new_card


## 构建任务所需的三个拾荒抽牌堆
## 返回格式: { ScavengeCard.ScavengeDeckType.RED_DECK: Array[ScavengeCard], ... }
func build_scavenge_decks() -> Dictionary:
	var result_decks: Dictionary = {
		ScavengeCard.ScavengeDeckType.RED_DECK: [] as Array[ScavengeCard],
		ScavengeCard.ScavengeDeckType.GREEN_DECK: [] as Array[ScavengeCard],
		ScavengeCard.ScavengeDeckType.BLUE_DECK: [] as Array[ScavengeCard]
	}
	
	if current_mission == null:
		push_error("[MissionManager] 构建拾荒牌堆失败：当前未加载任何 Mission！")
		return result_decks
		
	var config: Dictionary = current_mission.scavenge_config
	
	for color_key in config:
		var deck_type: ScavengeCard.ScavengeDeckType = _parse_deck_type_from_string(color_key)
		if deck_type == ScavengeCard.ScavengeDeckType.NONE:
			continue
			
		var card_configs: Array = config.get(color_key, [])
		var target_deck_array: Array[ScavengeCard] = result_decks[deck_type]
		
		for item in card_configs:
			if not item is Dictionary:
				continue
				
			var card_name: String = item.get("card_name", "")
			var count: int = item.get("count", 1)
			
			# 直接在 MissionManager 内部实例化卡牌对象
			for i in range(count):
				var card_instance: ScavengeCard = create_scavenge_card_by_name(card_name)
				if card_instance:
					# 标记当前分配给哪个地图抽牌堆
					card_instance.current_scavenge_deck = deck_type
					target_deck_array.append(card_instance)
					
	return result_decks


## 字符串转拾荒牌堆类型枚举 Helper
func _parse_deck_type_from_string(color_str: String) -> ScavengeCard.ScavengeDeckType:
	match color_str.to_lower():
		"red":
			return ScavengeCard.ScavengeDeckType.RED_DECK
		"green":
			return ScavengeCard.ScavengeDeckType.GREEN_DECK
		"blue":
			return ScavengeCard.ScavengeDeckType.BLUE_DECK
		_:
			push_warning("[MissionManager] 未知的拾荒牌堆颜色配置: %s" % color_str)
			return ScavengeCard.ScavengeDeckType.NONE