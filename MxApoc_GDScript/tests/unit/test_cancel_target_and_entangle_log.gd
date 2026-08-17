extends GutTest

## "取消目标选取保护"与"纠缠日志"修复单元测试。
## 覆盖 spec: .trae/specs/fix-cancel-target-and-entangle-log/spec.md
##   6.1 use_card select_target == -1 路径空目标检查（闪光棒）
##   6.2 use_card 取消保护（闪光棒）
##   6.3 use_card 套索取消保护
##   6.4 7 张卡牌 defer_action_cost + content 前缀数据验证
##   6.5 Monster.change_engaged_target 输出"纠缠了"日志
##   6.6 change_engaged_target 重复调用不重复输出日志
##   6.7 change_engaged_target null 安全


# === 辅助方法 ===

func _make_player(player_name: String = "测试玩家", hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = player_name
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	return p


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


func _make_monster(monster_name: String = "test_monster", hp: int = 20) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = hp
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


## 多玩家场景下初始化 Game 单例（与 test_entangle_cards.gd 保持一致）。
func _setup_game_for_players(players: Array) -> void:
	Game.players = players
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


## 按 english_name 取出指定 survivor 牌堆中卡牌的原始字典。
func _get_card_dict_by_english_name(survivor_id: String, english_name: String) -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor(survivor_id)
	assert_not_null(sd, "应能加载 survivor 数据: " + survivor_id)
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == english_name:
			return card_dict
	return {}


## 按 english_name 创建一张真实卡牌（含编译后的技能 Callable）。
func _make_card_by_english_name(survivor_id: String, english_name: String) -> Card:
	var card_dict: Dictionary = _get_card_dict_by_english_name(survivor_id, english_name)
	assert(!card_dict.is_empty(), "未找到卡牌: " + survivor_id + "/" + english_name)
	return Game._create_game_card_from_dict(card_dict)


## 判断 Game.log_list 中是否存在同时包含全部给定子串的日志条目。
func _log_contains_all(substrings: Array) -> bool:
	for l in Game.log_list:
		var all_match: bool = true
		for s in substrings:
			if not l.contains(s):
				all_match = false
				break
		if all_match:
			return true
	return false


## 统计 Game.log_list 中包含 "纠缠了" 的条目数。
func _count_entangle_logs() -> int:
	var count: int = 0
	for l in Game.log_list:
		if l.contains("纠缠了"):
			count += 1
	return count


# === SubTask 6.1: use_card select_target == -1 路径空目标检查（闪光棒）===

# 玩家使用闪光棒（select_target == -1, defer_action_cost == true），
# 当 choose_target 返回空数组（无候选目标）时，use_card 应返回 false，
# 牌退回手牌、行动次数不消耗。
func test_use_card_flare_rod_empty_target_returns_false() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_players([p])
	var block: MapBlock = _make_block("center", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	p.action_count = 2
	# 闪光棒卡牌（firefighter, select_target == -1, defer_action_cost == true）
	var card: Card = _make_card_by_english_name("firefighter", "flare_rod")
	p.hand.append(card)
	# mock input：choose_target 返回空数组（无候选目标）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "空候选目标时 use_card 应返回 false")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0], card, "手牌中应为闪光棒")
	assert_eq(p.action_count, 2, "行动次数不应被消耗")


# === SubTask 6.2: use_card 取消保护（闪光棒）===

# 玩家使用闪光棒，选择目标阶段点击取消（CliPlayerInput 用空数组模拟取消），
# use_card 应返回 false、牌退回手牌、行动次数不消耗。
# 注：本代码库中取消选取与无候选目标在引擎层等价（choose_target 均返回空数组），
# 与 test_hollow_point_redesign.gd / test_grenade_and_volley.gd 的取消模拟方式一致。
func test_use_card_flare_rod_cancel_returns_false() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_players([p])
	var block: MapBlock = _make_block("center", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	p.action_count = 2
	var card: Card = _make_card_by_english_name("firefighter", "flare_rod")
	p.hand.append(card)
	# mock input：取消选取（空数组表示取消）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "闪光棒", "手牌中应为闪光棒")


# === SubTask 6.3: use_card 套索取消保护 ===

# 玩家使用套索（select_target == 1, defer_action_cost == true），
# 选择目标阶段取消（空数组），use_card 应返回 false、牌退回手牌、行动次数不消耗。
func test_use_card_lasso_cancel_returns_false() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_players([p])
	var block: MapBlock = _make_block("center", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	p.action_count = 2
	# 套索卡牌（gunslinger, select_target == 1, defer_action_cost == true）
	var card: Card = _make_card_by_english_name("gunslinger", "lasso")
	p.hand.append(card)
	# mock input：取消选取（空数组）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "套索", "手牌中应为套索")


# === SubTask 6.4: 7 张卡牌 defer_action_cost + content 前缀数据验证 ===

# 验证 gunslinger.json 的 lasso、tactical_leadership 与 firefighter.json 的
# first_aid_kit、lighter、fire_extinguisher、flare_rod、oxygen_tank 共 7 张卡牌：
# - 首个 skill 的 defer_action_cost == true
# - 首个 skill 的 content 以 "player.consume_action(1)" 开头
func test_seven_cards_have_defer_action_cost_and_consume_prefix() -> void:
	var cases: Array = [
		["gunslinger", "lasso"],
		["gunslinger", "tactical_leadership"],
		["firefighter", "first_aid_kit"],
		["firefighter", "lighter"],
		["firefighter", "fire_extinguisher"],
		["firefighter", "flare_rod"],
		["firefighter", "oxygen_tank"],
	]
	for entry in cases:
		var survivor_id: String = entry[0]
		var english_name: String = entry[1]
		var card_dict: Dictionary = _get_card_dict_by_english_name(survivor_id, english_name)
		assert_false(card_dict.is_empty(), "应找到卡牌: " + survivor_id + "/" + english_name)
		var raw_skills: Array = card_dict.get("skills", [])
		assert_true(raw_skills.size() > 0, survivor_id + "/" + english_name + " 应至少有 1 个技能")
		var raw: Dictionary = raw_skills[0]
		# defer_action_cost == true
		assert_true(raw.has("defer_action_cost"), survivor_id + "/" + english_name + " 应含 defer_action_cost 字段")
		assert_eq(raw.get("defer_action_cost", false), true, survivor_id + "/" + english_name + " defer_action_cost 应为 true")
		# content 以 "player.consume_action(1)" 开头
		var content: String = raw.get("content", "")
		assert_false(content.is_empty(), survivor_id + "/" + english_name + " content 不应为空")
		assert_true(
			content.begins_with("player.consume_action(1)"),
			survivor_id + "/" + english_name + " content 应以 player.consume_action(1) 开头，实际前 25 字符: " + content.substr(0, 25)
		)


# === SubTask 6.5: Monster.change_engaged_target 输出"纠缠了"日志 ===

# 怪物 M 原 attack_target = B，调用 change_engaged_target(A) 后：
# - Game.log_list 应包含 "<M 名> 纠缠了 <A 名>" 日志（颜色标签内含怪物名/玩家名）
# - M.attack_target 应为 A
# - M 应在 A.monster_zone，不在 B.monster_zone
func test_change_engaged_target_logs_entangle_message() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	var m: Monster = _make_monster("测试怪物")
	m.attack_target = pb
	pb.monster_zone.append(m)
	# 清空日志
	Game.log_list = []
	# 调用 change_engaged_target(A)
	m.change_engaged_target(pa)
	# 日志应包含 "测试怪物 纠缠了 玩家A"（颜色标签内含怪物名/玩家名）
	assert_true(
		_log_contains_all(["测试怪物", "纠缠了", "玩家A"]),
		"应输出 '测试怪物 纠缠了 玩家A' 日志，实际日志: " + str(Game.log_list)
	)
	# 攻击目标与怪物区应正确更新
	assert_eq(m.attack_target, pa, "M.attack_target 应为 A")
	assert_true(pa.monster_zone.has(m), "M 应在 A.monster_zone")
	assert_false(pb.monster_zone.has(m), "M 应不在 B.monster_zone")


# === SubTask 6.6: change_engaged_target 重复调用不重复输出日志 ===

# 紧接 6.5 场景：M 已纠缠 A，再次调用 change_engaged_target(A)（目标未变），
# 不应再次输出 "纠缠了" 日志（target == old_target 跳过日志）。
func test_change_engaged_target_no_duplicate_log() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	var m: Monster = _make_monster("测试怪物")
	m.attack_target = pb
	pb.monster_zone.append(m)
	# 第一次调用：应输出 1 条日志
	m.change_engaged_target(pa)
	var first_count: int = _count_entangle_logs()
	assert_eq(first_count, 1, "第一次调用应输出 1 条 '纠缠了' 日志")
	# 清空日志，再次调用同一目标：不应再输出
	Game.log_list = []
	m.change_engaged_target(pa)
	assert_eq(_count_entangle_logs(), 0, "目标未变时不应再输出 '纠缠了' 日志")
	# M 仍应纠缠 A
	assert_eq(m.attack_target, pa, "M.attack_target 应仍为 A")
	assert_true(pa.monster_zone.has(m), "M 应仍在 A.monster_zone")


# === SubTask 6.7: change_engaged_target null 安全 ===

# 怪物 M.attack_target == null，调用 change_engaged_target(null)：
# 不崩溃、不输出 "纠缠了" 日志。
func test_change_engaged_target_null_safety_no_log() -> void:
	var pa: Player = _make_player("玩家A")
	_setup_game_for_players([pa])
	var m: Monster = _make_monster("游离怪物")
	m.attack_target = null
	Game.log_list = []
	# 调用 change_engaged_target(null)：不应崩溃
	m.change_engaged_target(null)
	assert_eq(m.attack_target, null, "attack_target 应保持 null")
	assert_eq(_count_entangle_logs(), 0, "target == null 时不应输出 '纠缠了' 日志")
