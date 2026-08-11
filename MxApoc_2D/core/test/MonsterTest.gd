# TestMonsterManager.gd
extends Node

func _ready() -> void:
	print("\n==================================================")
	print("       开始测试 MonsterManagerNew 卡组加载       ")
	print("==================================================\n")
	
	test_load_all_decks()
	test_invalid_type_input()

	print("\n==================================================")
	print("               所有测试项执行完毕               ")
	print("==================================================\n")


## 测试 1：依次加载 4 种怪物卡组并校验详细数据
func test_load_all_decks() -> void:
	var monster_types = [
		MonsterManagerNew.MonsterType.ALIEN,
		MonsterManagerNew.MonsterType.MUTANT,
		MonsterManagerNew.MonsterType.ROBOT,
		MonsterManagerNew.MonsterType.ZOMBIE
	]
	
	for type_id in monster_types:
		print("--------------------------------------------------")
		print("正在测试加载卡组 ID: %d ..." % type_id)
		
		var deck: Array[MonsterCard] = MonsterManagerNew.load_monster_deck_by_id(type_id)
		
		if deck.is_empty():
			push_error("❌ [失败] 卡组 ID %d 加载失败或结果为空！" % type_id)
			continue
			
		print("✅ [成功] 卡组 ID %d 加载成功，实例化总张数: %d" % [type_id, deck.size()])
		
		# 统计不重复的卡牌种数
		var unique_names: Dictionary = {}
		var skill_count_total: int = 0
		
		for card in deck:
			# 校验注入的 monster_type 是否与请求的型一致
			assert(str(card.monster_type) == str(type_id), "卡牌 monster_type 注入异常！")
			
			unique_names[card.card_name] = unique_names.get(card.card_name, 0) + 1
			skill_count_total += card.skills.size()
			
		print("  • 包含了 %d 种不同的怪物卡牌:" % unique_names.size())
		for card_name in unique_names:
			print("    - %s: %d 张" % [card_name, unique_names[card_name]])
			
		print("  • 关联技能指令集总数: %d" % skill_count_total)
		
		# 抽查打印第一张牌的详细调试信息
		if not deck.is_empty():
			print("  • 样例卡牌数据抽查:")
			deck[0].print_debug_info()


## 测试 2：测试非法输入/不存在的类型 ID 容错
func test_invalid_type_input() -> void:
	print("--------------------------------------------------")
	print("正在测试非法 ID 输入 (如 99)...")
	
	# 强转一个超出枚举范围的整型
	var invalid_id = 99 as MonsterManagerNew.MonsterType
	var result = MonsterManagerNew.load_monster_deck_by_id(invalid_id)
	
	if result.is_empty():
		print("✅ [成功] 非法 ID 触发了预期保护，正确返回空列表！")
	else:
		push_error("❌ [失败] 非法 ID 居然返回了数据！")
