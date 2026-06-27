# MonsterData.gd
class_name MonsterData
extends Resource

@export var id: String = ""
@export var monster_name: String = ""
@export_enum("ALIEN", "MUTANT", "ROBOT", "ZOMBIE") var pack: String = "ZOMBIE"
@export_enum("NORMAL", "ELITE", "BOSS") var rank: String = "NORMAL"
@export var max_hp: int = 10
@export var damage: int = 2
@export var range_type: Enums.RangeType = Enums.RangeType.NONE
@export var ability_id: String = ""
@export_multiline var description: String = ""