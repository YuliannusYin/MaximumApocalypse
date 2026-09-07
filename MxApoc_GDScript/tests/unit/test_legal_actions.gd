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


func test_legal_actions_no_move_when_monster_zone_not_empty() -> void:
	var p: Player = _ready_combat_player()
	var here: MapBlock = p.current_block
	var there: MapBlock = _make_block("邻格", 1, 0, true)
	Game.map_area = [here, there]
	var actions: Array = LegalActionsScript.enumerate(p)
	var types: Array = []
	for action in actions:
		types.append(action.get("type"))
	assert_false(types.has("move"), "怪物区有怪不应枚举主动移动")


func test_legal_actions_scavenge_only_current_block_colors() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var mall: MapBlock = _make_block("购物中心", 0, 0, true)
	mall.scavenge_colors = PackedStringArray(["blue"])
	Game.map_area = [mall]
	p.current_block = mall
	Game.red_scavenge_pile = Pile.new()
	Game.red_scavenge_pile.add(_make_scavenge_card("燃料", "red"))
	Game.blue_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile.add(_make_scavenge_card("食物", "blue"))
	var actions: Array = LegalActionsScript.enumerate(p)
	var keys: Array = []
	for action in actions:
		if action.get("type") == "pile_draw":
			keys.append(action.get("pile_key"))
	assert_true(keys.has("blue_scavenge"), "当前格蓝色应枚举蓝拾荒")
	assert_false(keys.has("red_scavenge"), "非红格不应枚举红拾荒")


func test_legal_actions_skips_focused_shot_without_monsters() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var block: MapBlock = _make_block("购物中心", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p]
	p.current_block = block
	var card: Card = _make_card("集中射击")
	card.english_name = "focused_shot"
	var skill := Skill.new()
	skill.skill_name = "集中射击"
	skill.english_name = "focused_shot"
	skill.active = "action"
	skill.target_type = "equipment"
	skill.range = "long"
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage", "ammo"], "effect": {"player": 1, "target": 2}}
	card.add_skill(skill)
	p.hand.append(card)
	var actions: Array = LegalActionsScript.enumerate(p)
	var has_shot := false
	for action in actions:
		if action.get("type") == "card" and action.get("card") == card:
			has_shot = true
	assert_false(has_shot, "没有怪物时不应枚举集中射击")
	var monster: Monster = Monster.new()
	monster.hp = 5
	p.monster_zone.append(monster)
	actions = LegalActionsScript.enumerate(p)
	has_shot = false
	for action in actions:
		if action.get("type") == "card" and action.get("card") == card:
			has_shot = true
	assert_true(has_shot, "自己怪物区有怪时应枚举集中射击")


func test_legal_actions_skips_damage_when_only_survivors() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var ally: Player = _make_player("Ally")
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p, ally]
	p.current_block = block
	ally.current_block = block
	p.add_skill(_punch_skill())
	var actions: Array = LegalActionsScript.enumerate(p)
	var has_punch := false
	for action in actions:
		if action.get("type") == "skill" and action.get("skill") != null and action["skill"].english_name == "punch":
			has_punch = true
	assert_false(has_punch, "只有求生者可打时不应枚举拳打")


func test_legal_actions_skips_binoculars_when_all_revealed() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var here: MapBlock = _make_block("购物中心", 0, 0, true)
	var there: MapBlock = _make_block("加油站", 1, 0, true)
	Game.map_area = [here, there]
	Game.players = [p]
	p.current_block = here
	var skill := Skill.new()
	skill.skill_name = "双筒望远镜"
	skill.english_name = "binoculars"
	skill.active = "action"
	skill.range = "long"
	skill.ai = {"order": 5, "useful": 0, "tags": ["reveal"]}
	p.add_skill(skill)
	var actions: Array = LegalActionsScript.enumerate(p)
	var has_binoculars := false
	for action in actions:
		if action.get("type") == "skill" and action.get("skill") != null and action["skill"].english_name == "binoculars":
			has_binoculars = true
	assert_false(has_binoculars, "全图已展示不应枚举望远镜")
	there.revealed = false
	actions = LegalActionsScript.enumerate(p)
	has_binoculars = false
	for action in actions:
		if action.get("type") == "skill" and action.get("skill") != null and action["skill"].english_name == "binoculars":
			has_binoculars = true
	assert_true(has_binoculars, "射程内有未展示格时应枚举望远镜")


func _push_card_only_context(player: Player) -> void:
	player._operation_context_stack.append({
		"kind": "limited_action",
		"remaining_actions": 2,
		"allowed_action_types": ["card"],
		"completed": false,
	})


func test_legal_actions_card_whitelist_excludes_skill_move_draw() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var here: MapBlock = _make_block("A", 0, 0, true)
	var there: MapBlock = _make_block("B", 1, 0, true)
	Game.map_area = [here, there]
	Game.players = [p]
	p.current_block = here
	p.game_deck.add(_make_card("deck"))
	p.add_skill(_punch_skill())
	var weapon: EquipmentCard = _make_equipment("猎枪")
	weapon.weapon = true
	weapon.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.hand.append(weapon)
	_push_card_only_context(p)
	var actions: Array = LegalActionsScript.enumerate(p)
	var types: Array = []
	for action in actions:
		types.append(action.get("type"))
	assert_true(types.has("card"), "类固醇迷你回合应枚举手牌")
	assert_false(types.has("skill"), "仅手牌白名单不应枚举技能")
	assert_false(types.has("move"), "仅手牌白名单不应枚举移动")
	assert_false(types.has("pile_draw"), "仅手牌白名单不应枚举抓牌")


func test_legal_actions_allowed_types_override_filters_without_context() -> void:
	var p: Player = _ready_combat_player()
	var weapon: EquipmentCard = _make_equipment("猎枪")
	weapon.weapon = true
	weapon.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.hand.append(weapon)
	var actions: Array = LegalActionsScript.enumerate(p, ["card"])
	var types: Array = []
	for action in actions:
		types.append(action.get("type"))
	assert_true(types.has("card"), "grant_types 预览应枚举手牌")
	assert_false(types.has("skill"), "grant_types 预览不应枚举拳打")

