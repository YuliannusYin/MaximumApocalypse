class_name PlayerStats
extends RefCounted

## 单玩家本局统计数据结构。
## 记录单个玩家在一局游戏中的各项累计数据，供结算与日志使用。

## 累计造成伤害
var damage_dealt: int = 0
## 累计受到的伤害
var damage_taken: int = 0
## 累计击杀
var kills: int = 0
## 累计移动格数
var moves: int = 0
## 累计摸牌次数
var draw_count: int = 0
## 累计拾荒次数
var scavenge_count: int = 0
## 累计减少饥饿值
var hunger_reduced: int = 0
## 累计回复生命值
var hp_recovered: int = 0
## 累计治疗量
var healing_done: int = 0
## 累计使用卡牌数
var cards_used: int = 0
## 累计主动技能次数
var skill_uses: int = 0
## 累计回合数
var turns_played: int = 0


func add_damage_dealt(n: int = 1) -> void:
	damage_dealt += n


func add_damage_taken(n: int = 1) -> void:
	damage_taken += n


func add_kills(n: int = 1) -> void:
	kills += n


func add_moves(n: int = 1) -> void:
	moves += n


func add_draw_count(n: int = 1) -> void:
	draw_count += n


func add_scavenge_count(n: int = 1) -> void:
	scavenge_count += n


func add_hunger_reduced(n: int = 1) -> void:
	hunger_reduced += n


func add_hp_recovered(n: int = 1) -> void:
	hp_recovered += n


func add_healing_done(n: int = 1) -> void:
	healing_done += n


func add_cards_used(n: int = 1) -> void:
	cards_used += n


func add_skill_uses(n: int = 1) -> void:
	skill_uses += n


func add_turns_played(n: int = 1) -> void:
	turns_played += n


## 返回包含全部 12 个字段的字典，键为字段名（字符串），值为对应 int。
func to_dict() -> Dictionary:
	return {
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"kills": kills,
		"moves": moves,
		"draw_count": draw_count,
		"scavenge_count": scavenge_count,
		"hunger_reduced": hunger_reduced,
		"hp_recovered": hp_recovered,
		"healing_done": healing_done,
		"cards_used": cards_used,
		"skill_uses": skill_uses,
		"turns_played": turns_played,
	}
