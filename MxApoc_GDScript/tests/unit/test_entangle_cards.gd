extends GutTest

## 纠缠目标卡牌（套索/闪光棒）修复单元测试。
## 覆盖 SubTask 6.1-6.7：
##   6.1 套索卡数据 filter_target 为 target.is_monster()
##   6.2 change_engaged_target 实际移动怪物区
##   6.3 change_engaged_target null 安全
##   6.4 change_engaged_target 发射信号
##   6.5 套索 use_card 全流程
##   6.6 闪光棒 use_card 全流程
##   6.7 get_skill_valid_targets 包含射程内其他玩家怪物
## 设计 spec：.trae/specs/fix-entangle-cards/spec.md


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


## 多玩家场景下初始化 Game 单例（与现有测试的 _setup_game_for_player 保持一致，
## 但 Game.players 接收任意玩家数组）。
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


## 从枪手 survivor 数据中取出套索卡牌的原始字典。
func _get_lasso_card_dict() -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "应能加载枪手 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "lasso":
			return card_dict
	return {}


## 从枪手数据创建一张真实套索卡牌（含编译后的技能 Callable）。
func _make_lasso_card() -> Card:
	var card_dict: Dictionary = _get_lasso_card_dict()
	assert(!card_dict.is_empty(), "未找到枪手套索卡牌")
	return Game._create_game_card_from_dict(card_dict)


## 从消防员数据创建一张真实闪光棒卡牌（含编译后的技能 Callable）。
func _make_flare_rod_card() -> Card:
	var sd: SurvivorData = DataManager.get_survivor("firefighter")
	assert_not_null(sd, "应能加载消防员 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("english_name", "") == "flare_rod":
			return Game._create_game_card_from_dict(card_dict)
	assert(false, "未找到消防员闪光棒卡牌")
	return null


# === SubTask 6.1: 套索卡数据 filter_target ===

func test_lasso_card_filter_target_is_monster_method() -> void:
	var card_dict: Dictionary = _get_lasso_card_dict()
	assert(!card_dict.is_empty(), "应找到套索卡牌数据")
	var raw_skills: Array = card_dict.get("skills", [])
	assert_eq(raw_skills.size(), 1, "套索卡应只有 1 个技能")
	var raw: Dictionary = raw_skills[0]
	var filter_target: String = raw.get("filter_target", "")
	assert_eq(filter_target, "return target.is_monster()", "套索卡 filter_target 应为 return target.is_monster()")
	# 确保不含旧的 target.type == "monster" 模式
	assert_false(filter_target.contains("target.type"), "filter_target 不应使用 target.type 模式")
	# 其余字段保持不变
	assert_eq(raw.get("range", ""), "medium", "range 应保持为 medium")
	assert_eq(raw.get("select_target", 0), 1, "select_target 应保持为 1")
	assert_eq(raw.get("filter_target_range", ""), "medium", "filter_target_range 应保持为 medium")


# === SubTask 6.2: change_engaged_target 实际移动怪物区 ===

func test_change_engaged_target_moves_monster_zone() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	var m: Monster = _make_monster("测试怪物")
	# 怪物 M 初始在 B 的怪物区，纠缠 B
	m.attack_target = pb
	pb.monster_zone.append(m)
	# 调用 change_engaged_target(A)
	m.change_engaged_target(pa)
	# 断言：M 从 B 移动到 A
	assert_true(pa.monster_zone.has(m), "M 应被追加到 A.monster_zone")
	assert_false(pb.monster_zone.has(m), "M 应从 B.monster_zone 移除")
	assert_eq(m.attack_target, pa, "M.attack_target 应为 A")


# === SubTask 6.3: change_engaged_target null 安全 ===

func test_change_engaged_target_null_safety() -> void:
	var pa: Player = _make_player("玩家A")
	_setup_game_for_players([pa])

	# 场景 1：old_target == null，调用 change_engaged_target(A) 不崩溃
	var m1: Monster = _make_monster("怪物1")
	m1.attack_target = null  # old_target == null
	m1.change_engaged_target(pa)
	assert_eq(m1.attack_target, pa, "场景1：attack_target 应更新为 A")
	assert_true(pa.monster_zone.has(m1), "场景1：M1 应被追加到 A.monster_zone")

	# 场景 2：target == null，调用 change_engaged_target(null) 不崩溃
	var m2: Monster = _make_monster("怪物2")
	m2.attack_target = pa  # old_target == A
	pa.monster_zone.append(m2)
	m2.change_engaged_target(null)
	assert_eq(m2.attack_target, null, "场景2：attack_target 应为 null")
	assert_false(pa.monster_zone.has(m2), "场景2：M2 应从 A.monster_zone 移除")


# === SubTask 6.4: change_engaged_target 发射信号 ===

func test_change_engaged_target_emits_signal() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	var m: Monster = _make_monster("测试怪物")
	m.attack_target = pb
	pb.monster_zone.append(m)

	var received: Array = []
	var cb: Callable = func(monster, old_t, new_t) -> void:
		received.append([monster, old_t, new_t])
	EventBus.monster_engaged_target_changed.connect(cb)

	m.change_engaged_target(pa)

	assert_eq(received.size(), 1, "应发射 1 次信号")
	assert_eq(received[0][0], m, "信号 monster 参数应为怪物自身")
	assert_eq(received[0][1], pb, "信号 old_target 应为原纠缠对象 B")
	assert_eq(received[0][2], pa, "信号 new_target 应为新纠缠对象 A")

	EventBus.monster_engaged_target_changed.disconnect(cb)


# === SubTask 6.5: 套索 use_card 全流程 ===

func test_lasso_use_card_full_flow() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	# A 与 B 在同一地块（同地块即在 medium 射程内）
	var block: MapBlock = _make_block("center", 0, 0)
	Game.map_area = [block]
	pa.current_block = block
	pb.current_block = block
	# 怪物 M 在 B 的怪物区，纠缠 B
	var m: Monster = _make_monster("测试怪物")
	m.attack_target = pb
	pb.monster_zone.append(m)
	# A 持有套索牌
	var card: Card = _make_lasso_card()
	pa.hand.append(card)
	# mock input：选取怪物 M
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([m])
	pa.input = cli
	# 执行 use_card
	var result: bool = await pa.use_card(card)
	assert_true(result, "使用套索应成功")
	# 断言：M 被击晕、纠缠目标改为 A、怪物区移动
	assert_true(m.stunned, "M 应被击晕")
	assert_eq(m.attack_target, pa, "M.attack_target 应为 A")
	assert_true(pa.monster_zone.has(m), "M 应在 A.monster_zone")
	assert_false(pb.monster_zone.has(m), "M 应不在 B.monster_zone")


# === SubTask 6.6: 闪光棒 use_card 全流程 ===

func test_flare_rod_use_card_full_flow() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	var pc: Player = _make_player("玩家C")
	_setup_game_for_players([pa, pb, pc])
	# A、B、C 在同一地块（同地块即在 long 射程内）
	var block: MapBlock = _make_block("center", 0, 0)
	Game.map_area = [block]
	pa.current_block = block
	pb.current_block = block
	pc.current_block = block
	# 怪物 M1 在 B 的怪物区，M2 在 C 的怪物区
	var m1: Monster = _make_monster("怪物1")
	m1.attack_target = pb
	pb.monster_zone.append(m1)
	var m2: Monster = _make_monster("怪物2")
	m2.attack_target = pc
	pc.monster_zone.append(m2)
	# A 持有闪光棒牌
	var card: Card = _make_flare_rod_card()
	pa.hand.append(card)
	# mock input：select_target=-1，自动选取全部合法目标
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([m1, m2])
	pa.input = cli
	# 执行 use_card
	var result: bool = await pa.use_card(card)
	assert_true(result, "使用闪光棒应成功")
	# 断言：M1、M2 都转移到 A 的怪物区，纠缠目标改为 A
	assert_eq(m1.attack_target, pa, "M1.attack_target 应为 A")
	assert_eq(m2.attack_target, pa, "M2.attack_target 应为 A")
	assert_true(pa.monster_zone.has(m1), "M1 应在 A.monster_zone")
	assert_true(pa.monster_zone.has(m2), "M2 应在 A.monster_zone")
	assert_false(pb.monster_zone.has(m1), "M1 应不在 B.monster_zone")
	assert_false(pc.monster_zone.has(m2), "M2 应不在 C.monster_zone")


# === SubTask 6.7: get_skill_valid_targets 包含其他玩家怪物 ===

func test_get_skill_valid_targets_includes_other_players_monsters() -> void:
	var pa: Player = _make_player("玩家A")
	var pb: Player = _make_player("玩家B")
	_setup_game_for_players([pa, pb])
	# A 在 (0,0)，B 在 (1,0) → d=1 → 在 A 的 long 射程内
	# （get_blocks_in_range "long" for_monster=false 包含 d=1 和 d=2）
	var block_a: MapBlock = _make_block("block_a", 0, 0)
	var block_b: MapBlock = _make_block("block_b", 1, 0)
	Game.map_area = [block_a, block_b]
	pa.current_block = block_a
	pb.current_block = block_b
	# A 怪物区为空（默认）
	# B 怪物区有怪物 M
	var m: Monster = _make_monster("测试怪物")
	pb.monster_zone.append(m)
	# 取得真实闪光棒技能（filter_target_range="long", filter_target="return target.is_monster()"）
	var card: Card = _make_flare_rod_card()
	var skills: Array = card.get_all_skills()
	assert_true(skills.size() > 0, "闪光棒卡应含技能")
	var skill: Skill = skills[0]
	# 调用 A.get_skill_valid_targets(skill)
	var valid: Array = pa.get_skill_valid_targets(skill)
	assert_true(valid.has(m), "合法目标应包含 B 怪物区的 M")
