# ScavengeCard.gd
class_name ScavengeCard
extends Card

# 拾荒牌颜色
enum ScavengeCardColor {
	RED,
	GREEN,
	BLUE
}

# 拾荒牌颜色
var card_color: String = ""

# 拾荒牌数值用于充能
var value: int = 0

# 拾荒牌牌堆数量
var count: int = 1

# 拾荒牌装备占用空间
var size: int = 0

# 拾荒牌充能类型
var charge_type: String = ""

# 拾荒牌充能最大值
var charge_max: int = 0

# 拾荒牌充能初始值
var charge_initial: int = 0

# 拾荒牌当前充能值
var current_charge: int = 0

# 拾荒牌抽牌堆颜色
var scavenge_draw_deck: ScavengeCardColor = ScavengeCardColor.RED


# 初始化拾荒牌
func _init() -> void:
	super()
	# 如果 Card 类中定义了 CardDeck 和 CardZone 枚举，通过 Card. 显式限定域可打破循环解析锁
	if "card_deck" in self:
		card_deck = Card.CardDeck.SCAVENGE_CARD
	if "card_zone" in self:
		card_zone = Card.CardZone.SCAVENGE_DRAW_DECK


# 从 JSON 字典初始化拾荒牌
func init_from_json_dict(data: Dictionary) -> void:
	# 调用父类 Card.gd 解析卡牌名称、描述及技能列表
	super.init_from_json_dict(data)
	
	card_color = data.get("card_color", "")
	value = data.get("value", 0)
	count = data.get("count", 1)
	size = data.get("size", 0)
	
	# 解析卡牌类型 (CardType) - 显式通过 Card. 访问父类枚举，避免歧义
	var raw_type: String = data.get("card_type", "")
	match raw_type:
		"action":
			card_type = Card.CardType.ACTION_CARD
		"equipment":
			card_type = Card.CardType.EQUIPMENT_CARD
		"monster":
			card_type = Card.CardType.MONSTER_CARD
		_:
			push_warning("未知的 card_type: %s，默认降级为 UNKNOWN_CARD_TYPE" % raw_type)
			card_type = Card.CardType.UNKNOWN_CARD_TYPE

	# 解析充能属性
	charge_type = data.get("charge_type", "")
	charge_max = data.get("charge_max", 0)
	charge_initial = data.get("charge_initial", 0)
	current_charge = charge_initial


## 增加/填装充能
func add_charge(amount: int) -> int:
	if charge_max <= 0:
		return 0
	
	var old_charge = current_charge
	current_charge = clamp(current_charge + amount, 0, charge_max)
	return current_charge - old_charge

## 填满充能
func fill_charge() -> void:
	if charge_max > 0:
		current_charge = charge_max

## 消耗/扣除充能
func consume_charge(amount: int) -> bool:
	if current_charge >= amount:
		current_charge -= amount
		return true
	return false

## 检查充能是否已满
func is_charge_full() -> bool:
	if charge_max <= 0:
		return true
	return current_charge >= charge_max

## 检查充能是否耗尽
func is_charge_empty() -> bool:
	return current_charge <= 0