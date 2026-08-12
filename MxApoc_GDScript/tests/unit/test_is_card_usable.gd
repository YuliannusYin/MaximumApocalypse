extends GutTest

## Player.is_card_usable 单元测试。
## 覆盖：装备牌恒返回 true；行动牌需至少一个 active=="action" 技能且其 filter 通过
## （以 target = null 的 event 求值）才返回 true；null/无效卡返回 false；
## 无 active=="action" 技能的行动牌返回 false。
## 参考：tests/unit/test_use_card_scavenging.gd 的 fixture 模式。
## 数据来源：data/scavenge/green.json（食物（小额），filter: hunger > 1）


# === 辅助方法 ===

func _make_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = "TestPlayer"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	p.hunger = 1
	return p


## 通过 Game.create_scavenge_card 创建一张真实拾荒卡（含编译后的技能 Callable）。
func _make_scavenge_card(card_name: String) -> Card:
	var card: Card = Game.create_scavenge_card(card_name)
	assert_not_null(card, "应能创建拾荒卡: " + card_name)
	return card


func _setup_game_for_player(p: Player) -> void:
	Game.players = [p]
	Game.map_area = []
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.coop_death_mode = false
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 测试用例 ===

# 行动牌「食物（小额）」filter 为 hunger > 1：hunger=1 时 filter 不通过，卡不可用
func test_food_small_not_usable_when_hunger_low() -> void:
	var p: Player = _make_player()
	p.hunger = 1
	_setup_game_for_player(p)
	var card: Card = _make_scavenge_card("食物（小额）")
	assert_false(p.is_card_usable(card), "hunger=1 时食物（小额）filter 不通过，应返回 false")


# 同一玩家 hunger=3 时 filter 通过，卡可用
func test_food_small_usable_when_hunger_high() -> void:
	var p: Player = _make_player()
	p.hunger = 3
	_setup_game_for_player(p)
	var card: Card = _make_scavenge_card("食物（小额）")
	assert_true(p.is_card_usable(card), "hunger=3 时食物（小额）filter 通过，应返回 true")


# 装备牌恒可用（card_type == "equipment" 直接返回 true，无 filter 门槛）
func test_equipment_card_always_usable() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var eq: Card = Card.new()
	eq.card_type = "equipment"
	assert_true(p.is_card_usable(eq), "装备牌应恒返回 true")


# 传入 null 应返回 false
func test_null_card_not_usable() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_false(p.is_card_usable(null), "null 卡应返回 false")


# 行动牌但无任何技能：无 active=="action" 技能，返回 false
func test_action_card_without_skills_not_usable() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c: Card = Card.new()
	c.card_type = "action"
	assert_false(p.is_card_usable(c), "无任何技能的行动牌应返回 false")


# 行动牌但仅挂 active != "action" 技能：同样无 active=="action" 技能，返回 false
func test_action_card_with_non_action_skill_not_usable() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c: Card = Card.new()
	c.card_type = "action"
	var s: Skill = Skill.new()
	s.active = "passive"
	c.add_skill(s)
	assert_false(p.is_card_usable(c), "仅挂 active!=action 技能的行动牌应返回 false")
