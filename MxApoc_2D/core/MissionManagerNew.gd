# MissionManager.gd
class_name MissionManager
extends Node

## 当前激活的任务实体
var current_mission: Mission = null

## 预加载的拾荒卡模板字典：card_name -> 卡牌 JSON 原始 Dictionary
var scavenge_card_templates: Dictionary = {}

# ==============================================================================
# 1. 模板预加载 API
# ==============================================================================

## 预加载拾荒卡模板数据
## templates_list: 拾荒卡 JSON 文件路径数组，例如 ["res://data/scavenge/red.json", ...]
func preload_scavenge_cards(templates_list: Array) -> void:
	scavenge_card_templates.clear()
	for file_path in templates_list:
		_load_scavenge_json_file(str(file_path))
	print("[MissionManager] 成功预加载 %d 张拾荒卡模板" % scavenge_card_templates.size())


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
## 支持精确匹配（如 "食物（标准）"）与前缀模糊匹配（如 "食物" 随机抽取一个变体）
func create_scavenge_card_by_name(card_name_or_category: String) -> ScavengeCard:
	var target_tpl: Dictionary = {}

	# 1. 尝试精确匹配（例如传入了 "食物（标准）"）
	if scavenge_card_templates.has(card_name_or_category):
		target_tpl = scavenge_card_templates[card_name_or_category]
	else:
		# 2. 精确匹配失败，尝试前缀模糊匹配（例如传入了 "食物"，匹配 "食物（微量）"、"食物（标准）" 等）
		var matched_templates: Array[Dictionary] = []
		for name_key in scavenge_card_templates.keys():
			if name_key.begins_with(card_name_or_category):
				matched_templates.append(scavenge_card_templates[name_key])

		# 3. 从匹配到的所有变体中随机抽取一张
		if matched_templates.size() > 0:
			target_tpl = matched_templates.pick_random()
		else:
			push_error("[MissionManager] 未找到匹配名称或类别为 '%s' 的拾荒卡模板！" % card_name_or_category)
			return null

	# 实例化拾荒卡
	var card = ScavengeCard.new()
	card.init_from_json_dict(target_tpl)
	return card


## 根据当前任务的 scavenge_config 构建三种颜色的拾荒牌堆
## scavenge_config 结构: {"red": [{"card_name": "食物", "count": 2}, ...], "green": [...], "blue": [...]}
## 返回: {ScavengeCardColor.RED: [ScavengeCard, ...], ScavengeCardColor.GREEN: [...], ScavengeCardColor.BLUE: [...]}
func build_scavenge_decks() -> Dictionary:
	var result_decks = {
		ScavengeCard.ScavengeCardColor.RED: [],
		ScavengeCard.ScavengeCardColor.GREEN: [],
		ScavengeCard.ScavengeCardColor.BLUE: []
	}

	if current_mission == null:
		push_error("[MissionManager] 当前没有加载任务，无法构建拾荒牌堆！")
		return result_decks

	var config_decks: Dictionary = current_mission.scavenge_config
	for color_key in config_decks.keys():
		var color_enum: ScavengeCard.ScavengeCardColor = _parse_deck_color_from_string(str(color_key))
		var entries: Array = config_decks.get(color_key, [])
		var deck_list: Array = result_decks.get(color_enum, [])

		for entry in entries:
			if entry is Dictionary and entry.has("card_name"):
				var card_name: String = str(entry.get("card_name", ""))
				var count: int = int(entry.get("count", 1))
				for i in range(count):
					var card_obj = create_scavenge_card_by_name(card_name)
					if card_obj:
						deck_list.append(card_obj)
			else:
				push_warning("[MissionManager] 拾荒牌堆配置项格式不正确，应为带 card_name/count 的字典: %s" % str(entry))

		# 组装完成后自动洗牌
		deck_list.shuffle()
		result_decks[color_enum] = deck_list
		print("[MissionManager] %s 牌堆构建完成，共 %d 张卡牌" % [str(color_key), deck_list.size()])

	return result_decks


## 字符串转 ScavengeCardColor 枚举
func _parse_deck_color_from_string(color_str: String) -> ScavengeCard.ScavengeCardColor:
	match color_str.to_lower():
		"red":
			return ScavengeCard.ScavengeCardColor.RED
		"green":
			return ScavengeCard.ScavengeCardColor.GREEN
		"blue":
			return ScavengeCard.ScavengeCardColor.BLUE
		"gray":
			push_warning("[MissionManager] gray 牌堆暂不支持构建，降级为 RED: %s" % color_str)
			return ScavengeCard.ScavengeCardColor.RED
		_:
			push_warning("[MissionManager] 未知或未映射的拾荒牌堆颜色: %s" % color_str)
			return ScavengeCard.ScavengeCardColor.RED
