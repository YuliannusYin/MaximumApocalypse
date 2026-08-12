# MonsterCard.gd
class_name MonsterCard
extends Card

# 怪物等级
enum MonsterLevel {
	NORMAL,
	ELITE,
	BOSS,
	UNKNOWN_MONSTER_LEVEL_TYPE
}

# 怪物状态
enum MonsterStatus {
	ALIVE,
	DEAD,
	UNKNOWN_MONSTER_STATUS_TYPE
}

# 怪物攻击范围
enum MonsterRange {
	NONE,
	SHORT,
	LONG,
	UNKNOWN_MONSTER_RANGE_TYPE
}

enum MonsterType {
	ALIEN,
	MUTANT,
	ROBOT,
	ZOMBIE,
	UNKNOWN_MONSTER_TYPE_TYPE
}

# 怪物类型
var monster_type: MonsterType = MonsterType.ALIEN

# 怪物等级
var monster_level: MonsterLevel = MonsterLevel.NORMAL

# 怪物状态
var monster_status: MonsterStatus = MonsterStatus.ALIVE

# 怪物攻击范围
var monster_range: MonsterRange = MonsterRange.NONE

# 怪物最大生命值
var max_hp: int = 0

# 怪物攻击伤害
var attack_damage:int = 0

# 在怪物牌堆中数量
var deck_count: int = 0

# 怪物当前生命值
var current_hp: int = 0

# 怪物当前状态
var current_status: MonsterStatus = MonsterStatus.ALIVE



func _init() -> void:
	super()
	card_deck = Card.CardDeck.MONSTER_CARD
	card_type = Card.CardType.MONSTER_CARD


## 重写 JSON 解析，先解析 Card 通用属性，再解析 MonsterCard 专属数据
func init_from_json_dict(data: Dictionary) -> void:
	# 1. 解析 Card 通用字段 (card_name, english_name, description, skills)
	# 由于 JSON 中字段名为 "monster_name"，先进行适配兼容处理
	if not data.has("card_name") and data.has("monster_name"):
		data["card_name"] = data["monster_name"]
		
	super.init_from_json_dict(data)
	
	# 2. 解析 Monster 专属字段
	monster_type = data.get("monster_type", "")
	max_hp = data.get("max_hp", 1)
	current_hp = data.get("initial_hp", max_hp)
	attack_damage = data.get("attack_damage", 0)
	deck_count = data.get("count", 1)
	current_status = MonsterStatus.ALIVE
	
	# 解析 monster_level
	var level_str: String = data.get("monster_level", "normal").to_lower()
	match level_str:
		"boss": monster_level = MonsterLevel.BOSS
		"elite": monster_level = MonsterLevel.ELITE
		_: monster_level = MonsterLevel.NORMAL
		
	# 解析 range
	var range_str: String = data.get("range", "none").to_lower()
	match range_str:
		"short": monster_range = MonsterRange.SHORT
		"long": monster_range = MonsterRange.LONG
		_: monster_range = MonsterRange.NONE



# ==============================================================================
# 调试打印
# ==============================================================================

func print_debug_info() -> void:
	print("\n========== [MonsterCard Debug Info] ==========")
	print("  • 唯一 ID (unique_id): ", unique_id)
	print("  • 怪物名: %s (%s)" % [card_name, english_name])
	print("  • 种族 (Type): %s | 等级: %s" % [monster_type, monster_level])
	print("  • 状态: ", "存活 (ALIVE)" if current_status == MonsterStatus.ALIVE else "死亡 (DEAD)")
	print("  • 生命值 (HP): %d / %d" % [current_hp, max_hp])
	print("  • 攻击力: %d | 射程: %s" % [attack_damage, monster_range])
	print("  • 绑定技能数: ", skills.size())
	print("===============================================\n")
