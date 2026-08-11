# MonsterManagerNew.gd
class_name MonsterManagerNew
extends RefCounted

# 4种怪物卡组枚举（对应传入的整型 0, 1, 2, 3）
enum MonsterType {
	ALIEN,
	MUTANT,
	ROBOT,
	ZOMBIE
}

# 配置文件路径映射 (请根据你的项目实际路径调整)
const DECK_PATHS: Dictionary = {
	MonsterType.ALIEN: "res://data/monsters/alien.json",
	MonsterType.MUTANT: "res://data/monsters/mutant.json",
	MonsterType.ROBOT: "res://data/monsters/robot.json",
	MonsterType.ZOMBIE: "res://data/monsters/zombie.json"
}

## 核心接口：接收一个整型 (0, 1, 2, 3)，读取对应 JSON 并返回实例化后的 MonsterCard 数组
static func load_monster_deck_by_id(type_int: MonsterType) -> Array[MonsterCard]:
	if not DECK_PATHS.has(type_int):
		push_error("[MonsterManager] 未知的怪物卡组类型整型值: %d" % type_int)
		return []
		
	var file_path: String = DECK_PATHS[type_int]
	if not FileAccess.file_exists(file_path):
		push_error("[MonsterManager] 找不到配置文件: %s" % file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[MonsterManager] JSON 解析失败: %s" % json.get_error_message())
		return []
		
	var raw_data = json.data
	if not raw_data is Array:
		push_error("[MonsterManager] JSON 顶层结构必须是 Array！")
		return []
		
	var card_instances: Array[MonsterCard] = []
	
	for raw_card in raw_data:
		if not raw_card is Dictionary:
			continue
			
		var card_dict: Dictionary = raw_card.duplicate(true)
		
		# 自动注入/覆盖整型 monster_type，保证卡牌知晓自己的种族 ID
		card_dict["monster_type"] = type_int
		
		# 提取 count，并展开生成对应数量的 MonsterCard 对象
		var count: int = card_dict.get("count", 1)
		for i in range(count):
			var card = MonsterCard.new()
			card.init_from_json_dict(card_dict)
			card_instances.append(card)
			
	print("[MonsterManager] 成功实例化卡组类型 [%d]，共生成 %d 张怪物牌！" % [type_int, card_instances.size()])
	return card_instances