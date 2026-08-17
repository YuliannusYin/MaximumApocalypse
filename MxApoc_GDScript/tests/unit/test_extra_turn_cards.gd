extends GutTest

## "立即行动卡牌机制"单元测试。
## 覆盖 spec: .trae/specs/implement-extra-turn-cards/spec.md
##   5.1  execute_action_immediately 保存-恢复 action_count / in_phase
##   5.2  战术领导力 content 编译无 Parser Error（修正方法名后）
##   5.3  战术领导力 use_card 完整流程
##   5.4  战术领导力取消保护
##   5.5  注射类固醇 use_card 完整流程
##   5.6  注射类固醇取消保护
##   5.7  注射肾上腺素 use_card 完整流程
##   5.8  注射肾上腺素取消保护
##   5.9  注射肾上腺素对自己使用
##   5.10 对讲机 use_active_skill 完整流程（装备牌）
##   5.11 对讲机取消保护
##   5.12 4 张卡牌 JSON 数据验证（defer_action_cost / filter / content 前缀）


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


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


## 按 english_name 取出指定 survivor 牌堆中卡牌的原始字典。
func _get_card_dict_by_english_name(survivor_id: String, english_name: String) -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor(survivor_id)
	assert_not_null(sd, "应能加载 survivor 数据: " + survivor_id)
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == english_name:
			return card_dict
	return {}


## 按 english_name 创建一张真实 survivor 卡牌（含编译后的技能 Callable）。
func _make_card_by_english_name(survivor_id: String, english_name: String) -> Card:
	var card_dict: Dictionary = _get_card_dict_by_english_name(survivor_id, english_name)
	assert(!card_dict.is_empty(), "未找到卡牌: " + survivor_id + "/" + english_name)
	return Game._create_game_card_from_dict(card_dict)


## 通过 Game.create_scavenge_card 创建一张真实拾荒卡（含编译后的技能 Callable）。
func _make_scavenge_card_by_name(card_name: String) -> Card:
	var card: Card = Game.create_scavenge_card(card_name)
	assert_not_null(card, "应能创建拾荒卡: " + card_name)
	return card


## 多玩家场景下初始化 Game 单例（与 test_cancel_target_and_entangle_log.gd 保持一致）。
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


## 在玩家已挂载技能中按 english_name 查找 Skill（用于装备 active 技能触发）。
func _find_skill_by_english_name(p: Player, en_name: String) -> Skill:
	for s in p.get_all_skills():
		if s.english_name == en_name:
			return s
	return null


# === SubTask 5.1: execute_action_immediately 保存-恢复 action_count / in_phase ===

# 玩家 action_count=3、in_phase="idle"，调用 execute_action_immediately(1)：
# 期间 action_count=1、in_phase="action"；执行完毕后 action_count=3、in_phase="idle"（恢复原值）。
# CliPlayerInput 默认 wait_action 返回 null（空队列）→ wait_player_action 立即退出，不阻塞测试。
func test_execute_action_immediately_restores_action_count_and_phase() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_players([p])
	p.action_count = 3
	p.in_phase = "idle"
	# 默认 CliPlayerInput：wait_action 返回 null → wait_player_action 立即退出
	p.input = CliPlayerInput.new()
	await p.execute_action_immediately(1)
	assert_eq(p.action_count, 3, "execute_action_immediately 后 action_count 应恢复为 3")
	assert_eq(p.in_phase, "idle", "execute_action_immediately 后 in_phase 应恢复为 idle")


# === SubTask 5.2: 战术领导力 content 编译无 Parser Error ===

# 验证 gunslinger.json tactical_leadership skill 的 content 编译为有效 Callable 且无 Parser Error。
# 旧 bug：content 调用不存在的 execute_immediate_action；修正后应为 execute_action_immediately。
func test_tactical_leadership_content_compiles_without_error() -> void:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "枪手应存在")
	var found: bool = false
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") != "tactical_leadership":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "战术领导力 content 应编译为有效 Callable")
			assert_engine_error_count(0, "战术领导力 content 编译应无 Parser Error")
	assert_true(found, "应在枪手牌堆中找到 tactical_leadership 卡牌")


# === SubTask 5.3: 战术领导力 use_card 完整流程 ===

# 玩家 A（action_count=2, in_phase="action"）使用战术领导力选 B（action_count=0, in_phase="idle"）：
# A 消耗 1 行动（content 中 consume_action(1)）；B 临时 action_count=1、in_phase="action"，
# wait_player_action 立即返回后 action_count 恢复为 0、in_phase 恢复为 idle。
func test_use_card_tactical_leadership_full_flow() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	pa.action_count = 2
	pa.in_phase = "action"
	pb.action_count = 0
	pb.in_phase = "idle"
	var card: Card = _make_card_by_english_name("gunslinger", "tactical_leadership")
	pa.hand.append(card)
	# A 的 input：选择 B 为目标
	var cli_a: CliPlayerInput = CliPlayerInput.new()
	cli_a.queue_choose_target([pb])
	pa.input = cli_a
	# B 的 input：wait_action 返回 null → wait_player_action 立即退出
	pb.input = CliPlayerInput.new()
	var result: bool = await pa.use_card(card)
	assert_true(result, "使用战术领导力应成功")
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(pb.action_count, 0, "B action_count 应恢复为 0（原值 0，临时 1，恢复 0）")
	assert_eq(pb.in_phase, "idle", "B in_phase 应恢复为 idle")


# === SubTask 5.4: 战术领导力取消保护 ===

# 玩家 A（action_count=2）使用战术领导力，目标选取阶段取消（queue_choose_target([])）：
# use_card 返回 false、牌退回手牌、action_count 不变。
func test_use_card_tactical_leadership_cancel_returns_false() -> void:
	var pa: Player = _make_player("玩家A")
	_setup_game_for_players([pa])
	pa.action_count = 2
	pa.in_phase = "action"
	var card: Card = _make_card_by_english_name("gunslinger", "tactical_leadership")
	pa.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	pa.input = cli
	var result: bool = await pa.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(pa.action_count, 2, "不应消耗行动次数")
	assert_eq(pa.hand.size(), 1, "牌应退回手牌")
	assert_eq(pa.hand[0].card_name, "战术领导力", "手牌中应为战术领导力")


# === SubTask 5.5: 注射类固醇 use_card 完整流程 ===

# 玩家 A（action_count=2）使用注射类固醇选 B（手牌 2 张）：
# A 消耗 1 行动；B 被 asked 调用 2 次 play_card_immediately，每次打出 1 张牌。
# 验证：A.action_count==1，B 手牌为空（2 张被打出），B 弃牌堆有 2 张。
func test_use_card_steroid_injection_full_flow() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	pa.action_count = 2
	pa.in_phase = "action"
	pb.action_count = 0
	pb.in_phase = "idle"
	# B 手牌 2 张普通行动牌
	var b_card1: Card = _make_card("B牌1", "action")
	var b_card2: Card = _make_card("B牌2", "action")
	pb.hand.append(b_card1)
	pb.hand.append(b_card2)
	var card: Card = _make_card_by_english_name("surgeon", "steroid_injection")
	pa.hand.append(card)
	# A 的 input：选择 B 为目标
	var cli_a: CliPlayerInput = CliPlayerInput.new()
	cli_a.queue_choose_target([pb])
	pa.input = cli_a
	# B 的 input：两次 choose_card 各选 1 张
	var cli_b: CliPlayerInput = CliPlayerInput.new()
	cli_b.queue_choose_card([b_card1])
	cli_b.queue_choose_card([b_card2])
	pb.input = cli_b
	var result: bool = await pa.use_card(card)
	assert_true(result, "使用注射类固醇应成功")
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(pb.hand.size(), 0, "B 应被打出 2 张牌（手牌为空）")
	assert_eq(pb.game_discard_pile.get_all().size(), 2, "B 弃牌堆应有 2 张（B牌1 + B牌2）")


# === SubTask 5.6: 注射类固醇取消保护 ===

# 玩家 A（action_count=2）使用注射类固醇，目标选取阶段取消：
# use_card 返回 false、牌退回手牌、action_count 不变。
func test_use_card_steroid_injection_cancel_returns_false() -> void:
	var pa: Player = _make_player("玩家A")
	_setup_game_for_players([pa])
	pa.action_count = 2
	pa.in_phase = "action"
	var card: Card = _make_card_by_english_name("surgeon", "steroid_injection")
	pa.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	pa.input = cli
	var result: bool = await pa.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(pa.action_count, 2, "不应消耗行动次数")
	assert_eq(pa.hand.size(), 1, "牌应退回手牌")
	assert_eq(pa.hand[0].card_name, "注射类固醇", "手牌中应为注射类固醇")


# === SubTask 5.7: 注射肾上腺素 use_card 完整流程 ===

# 玩家 A（action_count=2）使用注射肾上腺素选 B（action_count=5, in_phase="idle"）：
# A 消耗 1 行动；B 临时 action_count=2、in_phase="action"，wait_player_action 立即返回后
# action_count 恢复为 5、in_phase 恢复为 idle。
func test_use_card_adrenaline_injection_full_flow() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	pa.action_count = 2
	pa.in_phase = "action"
	pb.action_count = 5
	pb.in_phase = "idle"
	var card: Card = _make_card_by_english_name("surgeon", "adrenaline_injection")
	pa.hand.append(card)
	# A 的 input：选择 B 为目标
	var cli_a: CliPlayerInput = CliPlayerInput.new()
	cli_a.queue_choose_target([pb])
	pa.input = cli_a
	# B 的 input：wait_action 返回 null → wait_player_action 立即退出
	pb.input = CliPlayerInput.new()
	var result: bool = await pa.use_card(card)
	assert_true(result, "使用注射肾上腺素应成功")
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(pb.action_count, 5, "B action_count 应恢复为 5（原值 5，临时 2，恢复 5）")
	assert_eq(pb.in_phase, "idle", "B in_phase 应恢复为 idle")


# === SubTask 5.8: 注射肾上腺素取消保护 ===

# 玩家 A（action_count=2）使用注射肾上腺素，目标选取阶段取消：
# use_card 返回 false、牌退回手牌、action_count 不变。
func test_use_card_adrenaline_injection_cancel_returns_false() -> void:
	var pa: Player = _make_player("玩家A")
	_setup_game_for_players([pa])
	pa.action_count = 2
	pa.in_phase = "action"
	var card: Card = _make_card_by_english_name("surgeon", "adrenaline_injection")
	pa.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	pa.input = cli
	var result: bool = await pa.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(pa.action_count, 2, "不应消耗行动次数")
	assert_eq(pa.hand.size(), 1, "牌应退回手牌")
	assert_eq(pa.hand[0].card_name, "注射肾上腺素", "手牌中应为注射肾上腺素")


# === SubTask 5.9: 注射肾上腺素对自己使用 ===

# 玩家 A（action_count=2, in_phase="action"）使用注射肾上腺素选自己：
# content 中 player.consume_action(1) → A.action_count=1；
# 然后 target.execute_action_immediately(2)（target 也是 A）：
#   saved_action_count=1, action_count=2, wait_player_action 立即返回, action_count 恢复为 1。
# 最终 A.action_count == 1。
func test_use_card_adrenaline_injection_self_use() -> void:
	var pa: Player = _make_player("玩家A")
	_setup_game_for_players([pa])
	pa.action_count = 2
	pa.in_phase = "action"
	var card: Card = _make_card_by_english_name("surgeon", "adrenaline_injection")
	pa.hand.append(card)
	# A 的 input：选择自己为目标（filter_target 允许 target == player）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([pa])
	pa.input = cli
	var result: bool = await pa.use_card(card)
	assert_true(result, "使用注射肾上腺素（自己）应成功")
	assert_eq(pa.action_count, 1, "A action_count 应为 1（consume_action(1) 后恢复 saved=1）")
	assert_eq(pa.in_phase, "action", "A in_phase 应保持 action")


# === SubTask 5.10: 对讲机 use_active_skill 完整流程（装备牌）===

# 玩家 A 装备对讲机（active="action" 技能），action_count=2, in_phase="action"；
# B（action_count=0, in_phase="idle"）。
# A 触发对讲机 active 技能选 B：A 消耗 1 行动（content 中 consume_action(1)）；
# B 临时 action_count=1、in_phase="action"，wait_player_action 立即返回后恢复。
func test_use_active_skill_walkie_talkie_full_flow() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	pa.action_count = 2
	pa.in_phase = "action"
	pb.action_count = 0
	pb.in_phase = "idle"
	# A 装备对讲机
	var wt_card: Card = _make_scavenge_card_by_name("对讲机")
	pa.hand.append(wt_card)
	await pa.equip(wt_card)
	# 查找已挂载的对讲机 active 技能
	var skill: Skill = _find_skill_by_english_name(pa, "walkie_talkie")
	assert_not_null(skill, "装备对讲机后应挂载 walkie_talkie 技能")
	# A 的 input：选择 B 为目标
	var cli_a: CliPlayerInput = CliPlayerInput.new()
	cli_a.queue_choose_target([pb])
	pa.input = cli_a
	# B 的 input：wait_action 返回 null → wait_player_action 立即退出
	pb.input = CliPlayerInput.new()
	await pa.use_active_skill(skill)
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(pb.action_count, 0, "B action_count 应恢复为 0（原值 0，临时 1，恢复 0）")
	assert_eq(pb.in_phase, "idle", "B in_phase 应恢复为 idle")


# === SubTask 5.11: 对讲机取消保护 ===

# 玩家 A 装备对讲机，action_count=2；触发 active 技能，目标选取阶段取消：
# use_active_skill 早退，action_count 不变，无目标受影响。
func test_use_active_skill_walkie_talkie_cancel_no_effect() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	pa.action_count = 2
	pa.in_phase = "action"
	pb.action_count = 0
	pb.in_phase = "idle"
	# A 装备对讲机
	var wt_card: Card = _make_scavenge_card_by_name("对讲机")
	pa.hand.append(wt_card)
	await pa.equip(wt_card)
	var skill: Skill = _find_skill_by_english_name(pa, "walkie_talkie")
	assert_not_null(skill, "装备对讲机后应挂载 walkie_talkie 技能")
	# A 的 input：取消选取（空数组）
	var cli_a: CliPlayerInput = CliPlayerInput.new()
	cli_a.queue_choose_target([])
	pa.input = cli_a
	await pa.use_active_skill(skill)
	assert_eq(pa.action_count, 2, "取消时不应消耗行动次数")
	assert_eq(pb.action_count, 0, "取消时 B action_count 不应变")
	assert_eq(pb.in_phase, "idle", "取消时 B in_phase 不应变")


# === SubTask 5.12: 4 张卡牌 JSON 数据验证 ===

# 验证 gunslinger.json (tactical_leadership)、surgeon.json (steroid_injection, adrenaline_injection)、
# scavenge/blue.json (walkie_talkie) 共 4 张卡牌的首个 skill：
# - defer_action_cost == true
# - filter 包含 "action_count" 子串
# - content 以 "player.consume_action(1)" 开头
func test_four_cards_have_defer_action_cost_and_consume_prefix() -> void:
	# 3 张 survivor 卡牌：通过 DataManager 获取原始字典
	var survivor_cases: Array = [
		["gunslinger", "tactical_leadership"],
		["surgeon", "steroid_injection"],
		["surgeon", "adrenaline_injection"],
	]
	for entry in survivor_cases:
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
		# filter 包含 action_count
		var filter_str: String = raw.get("filter", "")
		assert_false(filter_str.is_empty(), survivor_id + "/" + english_name + " filter 不应为空")
		assert_true(
			filter_str.contains("action_count"),
			survivor_id + "/" + english_name + " filter 应包含 action_count"
		)
		# content 以 player.consume_action(1) 开头
		var content: String = raw.get("content", "")
		assert_false(content.is_empty(), survivor_id + "/" + english_name + " content 不应为空")
		assert_true(
			content.begins_with("player.consume_action(1)"),
			survivor_id + "/" + english_name + " content 应以 player.consume_action(1) 开头，实际前 25 字符: " + content.substr(0, 25)
		)
	# walkie_talkie：通过 DataManager.get_scavenge_pile("blue") 获取 ScavengeCardData
	var found_wt: bool = false
	for card_data in DataManager.get_scavenge_pile("blue"):
		if card_data.english_name != "walkie_talkie":
			continue
		found_wt = true
		assert_true(card_data.skills.size() > 0, "walkie_talkie 应至少有 1 个技能")
		var sd: SkillData = card_data.skills[0]
		# defer_action_cost == true
		assert_eq(sd.defer_action_cost, true, "walkie_talkie defer_action_cost 应为 true")
		# filter 包含 action_count
		assert_false(sd.filter.is_empty(), "walkie_talkie filter 不应为空")
		assert_true(
			sd.filter.contains("action_count"),
			"walkie_talkie filter 应包含 action_count"
		)
		# content 以 player.consume_action(1) 开头
		assert_false(sd.content.is_empty(), "walkie_talkie content 不应为空")
		assert_true(
			sd.content.begins_with("player.consume_action(1)"),
			"walkie_talkie content 应以 player.consume_action(1) 开头，实际前 25 字符: " + sd.content.substr(0, 25)
		)
	assert_true(found_wt, "应在 blue 拾荒牌堆中找到 walkie_talkie")
