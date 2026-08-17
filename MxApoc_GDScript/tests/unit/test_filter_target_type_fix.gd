extends GutTest

## "filter_target 类型判断"修复单元测试。
## 覆盖 spec: .trae/specs/fix-filter-target-type-crash/spec.md
##   5.1 survivors/ 全目录无残留 target.type == "human" / "monster"
##   5.2 tactical_leadership filter_target 编译执行：Player→true / Monster→false / 自己→false
##   5.3 steroid_injection filter_target 数据验证：target.is_player()
##   5.4 is_monster filter_target 数据验证（molotov_cocktail）
##   5.5 use_card 战术领导力不再崩溃
##   5.6 use_card 注射类固醇不再崩溃
##   5.7 use_card 注射肾上腺素不再崩溃


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


func _make_monster(monster_name: String = "test_monster", hp: int = 20) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = hp
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


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


## 多玩家场景下初始化 Game 单例（与 test_extra_turn_cards.gd 保持一致）。
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


# === SubTask 5.1: survivors/ 全目录无残留 target.type == ===

# 遍历 res://data/survivors/ 下所有 .json 文件，逐文件读取内容并断言：
# 不再包含 `target.type == "human"` 或 `target.type == "monster"` 子串。
# 共应遍历 6 个文件（firefighter / gunslinger / hunter / mechanic / surgeon / veteran）。
func test_no_residual_target_type_in_survivors_dir() -> void:
	var dir: DirAccess = DirAccess.open("res://data/survivors/")
	assert_not_null(dir, "应能打开 res://data/survivors/ 目录")
	dir.list_dir_begin()
	var expected_files: Array = [
		"firefighter.json",
		"gunslinger.json",
		"hunter.json",
		"mechanic.json",
		"surgeon.json",
		"veteran.json",
	]
	var found_files: Dictionary = {}
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			assert_true(expected_files.has(fname), "survivors 目录仅应含预期文件，意外文件: " + fname)
			found_files[fname] = true
			var path: String = "res://data/survivors/" + fname
			var content: String = FileAccess.get_file_as_string(path)
			assert_false(content.is_empty(), "应能读取文件: " + path)
			assert_false(
				content.contains("target.type == \"human\""),
				fname + " 不应含 target.type == \"human\""
			)
			assert_false(
				content.contains("target.type == \"monster\""),
				fname + " 不应含 target.type == \"monster\""
			)
		fname = dir.get_next()
	dir.list_dir_end()
	# 断言 6 个预期文件全部遍历到
	for expected in expected_files:
		assert_true(found_files.has(expected), "应遍历到 survivor 文件: " + expected)
	assert_eq(found_files.size(), 6, "应共遍历到 6 个 survivor 文件")


# === SubTask 5.2: tactical_leadership filter_target 编译执行 ===

# 加载 gunslinger.json tactical_leadership 卡牌的首个 skill 的 filter_target 字符串，
# 通过 CodeExecutor.compile_filter_target 编译为 Callable 并直接调用：
# - 候选为 Player B（非 player）→ true
# - 候选为 Monster → false
# - 候选为 player 自己 → false（因 `&& target != player`）
func test_tactical_leadership_filter_target_compiles_and_works() -> void:
	var card_dict: Dictionary = _get_card_dict_by_english_name("gunslinger", "tactical_leadership")
	assert_false(card_dict.is_empty(), "应找到 tactical_leadership 卡牌")
	var raw_skills: Array = card_dict.get("skills", [])
	assert_true(raw_skills.size() > 0, "tactical_leadership 应至少有 1 个技能")
	var raw: Dictionary = raw_skills[0]
	var filter_target_str: String = raw.get("filter_target", "")
	assert_eq(
		filter_target_str,
		"return target.is_player() && target != player",
		"tactical_leadership filter_target 应为修复后的字符串"
	)
	var cb: Callable = CodeExecutor.compile_filter_target(filter_target_str)
	assert_true(cb.is_valid(), "filter_target 应编译为有效 Callable")
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	var m: Monster = _make_monster("测试怪物")
	# Player B（非 player）→ true
	assert_true(
		cb.call(pa, pb, {}, Game),
		"tactical_leadership filter_target 对 Player B（非 player）应返回 true"
	)
	# Monster → false
	assert_false(
		cb.call(pa, m, {}, Game),
		"tactical_leadership filter_target 对 Monster 应返回 false"
	)
	# player 自己 → false
	assert_false(
		cb.call(pa, pa, {}, Game),
		"tactical_leadership filter_target 对 player 自己应返回 false（&& target != player）"
	)


# === SubTask 5.3: steroid_injection filter_target 数据验证 ===

# 加载 surgeon.json steroid_injection 卡牌的首个 skill 的 filter_target 字符串，
# 断言其等于 `return target.is_player()`（不再含 target.type）。
func test_steroid_injection_filter_target_is_player() -> void:
	var card_dict: Dictionary = _get_card_dict_by_english_name("surgeon", "steroid_injection")
	assert_false(card_dict.is_empty(), "应找到 steroid_injection 卡牌")
	var raw_skills: Array = card_dict.get("skills", [])
	assert_true(raw_skills.size() > 0, "steroid_injection 应至少有 1 个技能")
	var raw: Dictionary = raw_skills[0]
	var filter_target_str: String = raw.get("filter_target", "")
	assert_eq(
		filter_target_str,
		"return target.is_player()",
		"steroid_injection filter_target 应为 return target.is_player()"
	)
	assert_false(
		filter_target_str.contains("target.type"),
		"steroid_injection filter_target 不应含 target.type"
	)


# === SubTask 5.4: is_monster filter_target 数据验证 ===

# 加载 surgeon.json molotov_cocktail 卡牌（第 80 行 filter_target 为 target.is_monster()），
# 断言 filter_target 字符串包含 `is_monster()` 且不含 `target.type`。
func test_is_monster_filter_target_data_verification() -> void:
	var card_dict: Dictionary = _get_card_dict_by_english_name("surgeon", "molotov_cocktail")
	assert_false(card_dict.is_empty(), "应找到 molotov_cocktail 卡牌")
	var raw_skills: Array = card_dict.get("skills", [])
	assert_true(raw_skills.size() > 0, "molotov_cocktail 应至少有 1 个技能")
	var raw: Dictionary = raw_skills[0]
	var filter_target_str: String = raw.get("filter_target", "")
	assert_true(
		filter_target_str.contains("is_monster()"),
		"molotov_cocktail filter_target 应含 is_monster()，实际: " + filter_target_str
	)
	assert_false(
		filter_target_str.contains("target.type"),
		"molotov_cocktail filter_target 不应含 target.type"
	)


# === SubTask 5.5: use_card 战术领导力不再崩溃 ===

# 玩家 A（action_count=2, in_phase="action"）使用战术领导力选 B（action_count=0, in_phase="idle"）：
# filter_target 修复后不再触发 `target.type` 崩溃；A 消耗 1 行动；
# B 临时 action_count=1、in_phase="action"，wait_player_action 立即返回后恢复。
func test_use_card_tactical_leadership_no_crash() -> void:
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
	assert_true(result, "使用战术领导力应成功（不再崩溃）")
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")


# === SubTask 5.6: use_card 注射类固醇不再崩溃 ===

# 玩家 A（action_count=2）使用注射类固醇选 B（手牌 2 张）：
# filter_target 修复后不再触发 `target.type` 崩溃；A 消耗 1 行动；
# B 被 asked 调用 2 次 play_card_immediately，每次打出 1 张牌。
func test_use_card_steroid_injection_no_crash() -> void:
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
	assert_true(result, "使用注射类固醇应成功（不再崩溃）")
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")


# === SubTask 5.7: use_card 注射肾上腺素不再崩溃 ===

# 玩家 A（action_count=2）使用注射肾上腺素选 B（action_count=0, in_phase="idle"）：
# filter_target 修复后不再触发 `target.type` 崩溃；A 消耗 1 行动；
# B 临时 action_count=2、in_phase="action"，wait_player_action 立即返回后恢复为 0/idle。
func test_use_card_adrenaline_injection_no_crash() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	pa.action_count = 2
	pa.in_phase = "action"
	pb.action_count = 0
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
	assert_true(result, "使用注射肾上腺素应成功（不再崩溃）")
	assert_eq(pa.action_count, 1, "A 应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(pb.action_count, 0, "B action_count 应恢复为 0（原值 0，临时 2，恢复 0）")
