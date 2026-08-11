# Card.gd
class_name Card
extends BaseEntity

# 卡牌类型
enum CardDeck {
    SURVIVOR_CARD,
    MONSTER_CARD,
    SCAVENGE_CARD
}

# 卡牌类型
enum CardType {
    ACTION_CARD,
    EQUIPMENT_CARD,
    MONSTER_CARD
}

# 卡牌区域
enum CardZone {
    SURVIVOR_DRAW_DECK,
    HAND_ZONE,
    SURVIVOR_DISCARD_ZONE,
    MONSTER_DRAW_DECK,
    MONSTER_ZONE,
    MONSTER_DISCARD_ZONE,
    SCAVENGE_DRAW_DECK,
    SCAVENGE_DISCARD_ZONE,
    EQUIPMENT_ZONE
}

# 卡牌中文名
var card_name: String = ""

# 卡牌英文名
var english_name: String = ""

# 卡牌描述
var description: String = ""

# 卡牌类型
var card_type: CardType = CardType.MONSTER_CARD

## 归属牌堆与类型
var card_deck: CardDeck = CardDeck.SURVIVOR_CARD
var card_zone: CardZone = CardZone.SURVIVOR_DRAW_DECK

# 卡牌技能列表
var skills: Array[Skill] = []

# 卡牌所有者
var owner: BaseEntity = null

# 卡牌是否已被消耗/使用
var is_consumed: bool = false

# 初始化卡牌
func _init() -> void:
    super(BaseEntity.Type.CARD)

## 从 JSON 字典解析基础属性
func init_from_json_dict(data: Dictionary) -> void:
    card_name = data.get("card_name", "")
    english_name = data.get("english_name", "")
    description = data.get("description", "")
	
	# 解析技能列表
    skills.clear()
    var raw_skills: Array = data.get("skills", [])
    for skill_dict in raw_skills:
        if skill_dict is Dictionary:
            var skill_obj: Skill = SkillFactory.create_skill_from_dict(skill_dict)
            if skill_obj:
                skills.append(skill_obj)

func has_skill(skill_eng_name: String) -> bool:
    for sk in skills:
        if sk.english_name == skill_eng_name:
                return true
    return false


func trigger_event(trigger_name: String, context: EffectContext) -> void:
    context.source = self
    context.trigger_name = trigger_name
	
    for sk in skills:
        if not sk.matches_trigger(trigger_name):
            continue
        if not sk.is_usable():
            continue
        if not sk.check_filter(context):
            continue
			
        for effect in sk.effects:
            effect.execute(context)
			
        sk.record_use()