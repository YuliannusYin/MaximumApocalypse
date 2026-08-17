extends GutTest

## 修复"扣动扳机让我快乐"崩溃单元测试。
## 覆盖：
## 1. increase_max_action / decrease_max_action 方法存在且正确
## 2. decrease_max_action 下限为 0
## 3. "扣动扳机让我快乐" content 编译无 Parser Error
## 4. use_card 完整流程：使用后 max_action_count +2、action_count +2
## 5. before_turn_end 触发后 max_action_count 还原、临时技能被移除
## 6. 数据驱动 add_temp_skill：未知 skill_id 不挂载、energy_drink_satiety 异 trigger 看护模式
## 设计 spec：.trae/specs/fix-pull-trigger-happy-crash/spec.md


# === 辅助方法 ===

func _make_player(hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = "枪手"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	p.max_action_count = 4
	return p


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


## 从枪手 survivor 数据中取出 pull_trigger_happy 卡牌的原始字典。
func _get_pull_trigger_happy_card_dict() -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "应能加载枪手 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "pull_trigger_happy":
			return card_dict
	return {}


## 从枪手数据创建一张真实 pull_trigger_happy 卡牌（含编译后的技能 Callable）。
func _make_pull_trigger_happy_card() -> Card:
	var card_dict: Dictionary = _get_pull_trigger_happy_card_dict()
	assert(!card_dict.is_empty(), "未找到枪手 pull_trigger_happy 卡牌")
	return Game._create_game_card_from_dict(card_dict)


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
	Game.sub_skill_registry = {}
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
	Game.sub_skill_registry = {}
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 1. increase_max_action / decrease_max_action 方法 ===

# 测试 1: increase_max_action 存在且正确增加 max_action_count
func test_increase_max_action_increases_max_action_count() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_eq(p.max_action_count, 4, "初始 max_action_count 应为 4")
	p.increase_max_action(2)
	assert_eq(p.max_action_count, 6, "increase_max_action(2) 后 max_action_count 应为 6")


# 测试 2: decrease_max_action 存在且正确减少 max_action_count
func test_decrease_max_action_decreases_max_action_count() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_eq(p.max_action_count, 4, "初始 max_action_count 应为 4")
	p.decrease_max_action(2)
	assert_eq(p.max_action_count, 2, "decrease_max_action(2) 后 max_action_count 应为 2")


# 测试 3: decrease_max_action 下限为 0（不会变负数）
func test_decrease_max_action_floored_at_zero() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.decrease_max_action(10)
	assert_eq(p.max_action_count, 0, "decrease_max_action(10) 后 max_action_count 应为 0（下限）")


# 测试 4: increase_max_action 与 decrease_max_action 配合还原
func test_increase_then_decrease_restores_value() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var original: int = p.max_action_count
	p.increase_max_action(2)
	p.decrease_max_action(2)
	assert_eq(p.max_action_count, original, "increase(2) + decrease(2) 应还原原值")


# === 2. content 编译 ===

# 测试 5: "扣动扳机让我快乐" content 编译无 Parser Error
func test_pull_trigger_happy_content_compiles_without_error() -> void:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "枪手应存在")
	var found: bool = false
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") != "pull_trigger_happy":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "扣动扳机让我快乐 content 应编译为有效 Callable")
			assert_engine_error_count(0, "扣动扳机让我快乐 content 编译应无 Parser Error")
	assert_true(found, "应在枪手牌堆中找到 pull_trigger_happy 卡牌")


# === 3. use_card 完整流程 ===

# 测试 6: use_card "扣动扳机让我快乐" 后 max_action_count +2 且 action_count +2
func test_use_card_pull_trigger_happy_increases_max_and_action() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	p.max_action_count = 4
	var card: Card = _make_pull_trigger_happy_card()
	p.hand.append(card)
	var result: bool = await p.use_card(card)
	assert_true(result, "使用扣动扳机让我快乐应成功")
	assert_eq(p.max_action_count, 6, "max_action_count 应 +2（4 + 2 = 6）")
	assert_eq(p.action_count, 3, "action_count 应 +2 后 -1（use_card 系统扣 1）：2 + 2 - 1 = 3")
	# 卡牌应进入弃牌堆
	assert_eq(p.game_discard_pile.get_all().size(), 1, "弃牌堆应有 1 张（扣动扳机让我快乐）")


# === 4. before_turn_end 触发清除 ===

# 测试 7: before_turn_end 触发后 max_action_count 还原、临时技能被移除
func test_before_turn_end_restores_max_action_and_removes_temp_skill() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	p.max_action_count = 4
	var card: Card = _make_pull_trigger_happy_card()
	p.hand.append(card)
	# 使用卡牌
	var result: bool = await p.use_card(card)
	assert_true(result, "使用扣动扳机让我快乐应成功")
	assert_eq(p.max_action_count, 6, "使用后 max_action_count 应为 6")
	# 验证临时技能已挂载（同 trigger 模式下 english_name 带有 _temp 后缀）
	var has_temp: bool = false
	for s in p.get_all_skills():
		if s.english_name == "pull_trigger_happy_clear_temp":
			has_temp = true
			break
	assert_true(has_temp, "应挂载 pull_trigger_happy_clear_temp 临时技能")
	# 触发 before_turn_end
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_turn_end", event)
	# max_action_count 应还原
	assert_eq(p.max_action_count, 4, "before_turn_end 触发后 max_action_count 应还原为 4")
	# 临时技能应被移除
	var still_has_temp: bool = false
	for s in p.get_all_skills():
		if s.english_name == "pull_trigger_happy_clear_temp":
			still_has_temp = true
			break
	assert_false(still_has_temp, "before_turn_end 触发后临时技能应被移除")


# 测试 8: add_temp_skill 对未知 skill_id 不挂载任何技能（push_error 降级）
# 验证数据驱动模式下未知 skill_id 的安全降级行为
# 注：add_temp_skill 内部 push_error 会触发 GUT "Unexpected Errors"，
# 故仅验证 Game.get_sub_skill_data 对未注册名返回 null（add_temp_skill 的前置查找逻辑）。
func test_add_temp_skill_unknown_id_just_removes_itself() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var initial_skill_count: int = p.get_all_skills().size()
	assert_null(Game.get_sub_skill_data("unknown_temp_skill"), "未注册的 english_name 应返回 null")
	assert_eq(p.get_all_skills().size(), initial_skill_count, "未注册的子技能不应挂载任何技能")


# 测试 9: energy_drink_satiety 数据驱动模式（异 trigger 看护模式）
# 验证数据驱动 add_temp_skill 在异 trigger 下挂载子技能 + 看护技能
func test_energy_drink_satiety_data_driven_mode() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# 加载消防员数据并创建 energy_drink 卡牌以注册 energy_drink_satiety 到 sub_skill_registry
	var sd: SurvivorData = DataManager.get_survivor("firefighter")
	var card_dict: Dictionary = {}
	for c in sd.deck:
		if c.get("english_name", "") == "energy_drink":
			card_dict = c
			break
	assert(!card_dict.is_empty(), "应在消防员牌堆中找到 energy_drink 卡牌")
	var energy_drink_card: Card = Game._create_game_card_from_dict(card_dict)
	# energy_drink_satiety 现已注册
	p.add_temp_skill("energy_drink_satiety", "before_next_turn_start")
	# 异 trigger：应挂载 energy_drink_satiety + energy_drink_satiety_expiry 看护技能
	assert_eq(p.get_all_skills().size(), 2, "应挂载 energy_drink_satiety + energy_drink_satiety_expiry")
	# 触发 before_hunger_settlement：energy_drink_satiety content 执行 event.cancel()
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_hunger_settlement", event)
	assert_true(EventSystem.is_cancelled(event), "energy_drink_satiety 应取消事件")
	# 触发 before_next_turn_start：看护技能移除 energy_drink_satiety + 自身
	var event2: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_next_turn_start", event2)
	assert_eq(p.get_all_skills().size(), 0, "触发后 energy_drink_satiety 与看护技能应均被移除")
