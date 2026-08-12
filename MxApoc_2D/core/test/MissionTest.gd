extends Node

func _ready() -> void:
	var mission_mgr = MissionManager.new()
	
	# 1. 预加载拾荒卡 JSON
	mission_mgr.preload_scavenge_cards([
		"res://data/scavenge/blue.json",
		"res://data/scavenge/gray.json",
		"res://data/scavenge/green.json",
		"res://data/scavenge/red.json"
	])
	
	# 2. 加载任务 JSON
	mission_mgr.load_mission_from_file("res://data/missions/mission_1.json")
	
	# 3. 实例化生成拾荒牌堆
	var scavenge_decks = mission_mgr.build_scavenge_decks()
	
	# 4. 打印调试：输出各个牌堆生成情况
	print("\n========== 拾荒牌堆生成测试 ==========")
	
	# 修正为 ScavengeCardColor 及对应的 RED / GREEN / BLUE
	var deck_names = {
		ScavengeCard.ScavengeCardColor.RED: "红色牌堆",
		ScavengeCard.ScavengeCardColor.GREEN: "绿色牌堆",
		ScavengeCard.ScavengeCardColor.BLUE: "蓝色牌堆"
	}
	
	for deck_type in scavenge_decks:
		var deck_array: Array = scavenge_decks[deck_type]
		var deck_name_str = deck_names.get(deck_type, "未知牌堆")
		
		print("\n[%s] (共 %d 张卡牌):" % [deck_name_str, deck_array.size()])
		
		# 统计当前牌堆中每种卡牌的数量
		var card_counts: Dictionary = {}
		for card in deck_array:
			# Card 父类中的卡牌名称属性（如果是 card_name 或 display_name）
			var c_name = card.card_name if "card_name" in card and card.card_name != "" else card.display_name
			card_counts[c_name] = card_counts.get(c_name, 0) + 1
			
		# 格式化输出牌堆里的具体卡牌及数量
		for c_name in card_counts:
			print("  - %s x %d" % [c_name, card_counts[c_name]])
			
	print("\n======================================")