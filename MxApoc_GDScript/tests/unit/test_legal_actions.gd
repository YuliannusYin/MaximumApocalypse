extends TestBase

## LegalActions 从规则层枚举行动阶段可选项。

const LegalActionsScript = preload("res://src/ai/legal_actions.gd")


func _punch_skill() -> Skill:
	var skill := Skill.new()
	skill.skill_name = "拳打"
	skill.english_name = "punch"
	skill.active = "action"
	skill.select_target = 1
	skill.filter_target_range = "short"
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage"], "effect": {"player": 0, "target": 2}}
	return skill


func _ready_combat_player() -> Player:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	p.is_ai = true
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p]
	p.current_block = block
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	monster.damage_value = 3
	monster.monster_level = "normal"
	p.monster_zone.append(monster)
	p.add_skill(_punch_skill())
	return p


func test_legal_actions_includes_attack_skill_when_monster_present() -> void:
	var p: Player = _ready_combat_player()
	var actions: Array = LegalActionsScript.enumerate(p)
	var has_punch := false
	for action in actions:
		if action.get("type") == "skill" and action.get("skill") != null and action["skill"].english_name == "punch":
			has_punch = true
	assert_true(has_punch, "有怪且行动阶段应枚举拳打")


func test_legal_actions_no_move_without_actions() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 0
	var a: MapBlock = _make_block("A", 0, 0, true)
	var b: MapBlock = _make_block("B", 1, 0, true)
	Game.map_area = [a, b]
	p.current_block = a
	var actions: Array = LegalActionsScript.enumerate(p)
	var types: Array = []
	for action in actions:
		types.append(action.get("type"))
	assert_false(types.has("move"), "无行动点不应枚举移动")
	assert_false(types.has("pile_draw"), "无行动点不应枚举抓牌")
