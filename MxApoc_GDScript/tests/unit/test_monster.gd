extends TestBase

## Monster 单元测试。


# === 测试用 mock player ===

class MockPlayer extends Player:
	var damage_received: Array = []  # 记录 [(num, source, type), ...]

	func _init() -> void:
		hp = 10
		max_hp = 10

	func damage(num: int, source: Entity, type: Variant = "", card: Card = null, runtime: Variant = null) -> void:
		damage_received.append([num, source, type])
		hp = maxi(hp - num, 0)


# === 测试用 mock block ===

class MockBlock extends MapBlock:
	var players_in_range: Array = []

	func get_players_in_range(_range_str: String, _for_monster: bool = false) -> Array:
		return players_in_range


# === 辅助方法 ===

func _make_combat_monster() -> Monster:
	var m: Monster = Monster.new()
	m.monster_name = "测试怪物"
	m.monster_type = "zombie"
	m.monster_level = "normal"
	m.max_hp = 5
	m.hp = 5
	m.damage_value = 2
	m.range = "none"
	return m


func _make_skill_with_trigger(trigger_name: String, called: Array) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(trigger_name)
	return s


func _make_combat_player(player_name: String = "测试玩家", hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = player_name
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	return p


## 多玩家场景下初始化 Game 单例。
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


# === 1. 默认字段 ===

func test_default_fields() -> void:
	var m: Monster = Monster.new()
	assert_eq(m.monster_name, "")
	assert_eq(m.monster_type, "")
	assert_eq(m.monster_level, "normal")
	assert_eq(m.hp, 0)
	assert_eq(m.max_hp, 0)
	assert_eq(m.damage_value, 0)
	assert_eq(m.range, "none")
	assert_null(m.attack_target)
	assert_null(m.monster_card)
	assert_false(m.stunned)


# === 2. 生命值接口 ===

func test_get_hp() -> void:
	var m: Monster = _make_combat_monster()
	assert_eq(m.get_hp(), 5)


func test_get_max_hp() -> void:
	var m: Monster = _make_combat_monster()
	assert_eq(m.get_max_hp(), 5)


func test_reduce_hp() -> void:
	var m: Monster = _make_combat_monster()
	m.reduce_hp(3)
	assert_eq(m.hp, 2)


func test_reduce_hp_floor_zero() -> void:
	var m: Monster = _make_combat_monster()
	m.reduce_hp(100)
	assert_eq(m.hp, 0, "生命值下限为 0")


func test_add_hp() -> void:
	var m: Monster = _make_combat_monster()
	m.reduce_hp(3)
	m.add_hp(2)
	assert_eq(m.hp, 4)


func test_add_hp_capped_at_max() -> void:
	var m: Monster = _make_combat_monster()
	m.add_hp(100)
	assert_eq(m.hp, 5, "生命值上限为 max_hp")


func test_restore_full_health() -> void:
	var m: Monster = _make_combat_monster()
	m.reduce_hp(3)
	assert_eq(m.hp, 2)
	await m.restore_full_health()
	assert_eq(m.hp, 5, "restore_full_health 应将生命值回复至上限")


func test_is_monster_returns_true() -> void:
	var m: Monster = Monster.new()
	assert_true(m.is_monster())


func test_is_player_returns_false() -> void:
	var m: Monster = Monster.new()
	assert_false(m.is_player())


# === 3. 行动流程 ===

func test_act_six_node_trigger_order() -> void:
	var m: Monster = _make_combat_monster()
	var p: MockPlayer = MockPlayer.new()
	m.attack_target = p
	var called: Array = []
	# 6 个 trigger 各挂一个技能
	for tname in ["before_monster_act", "on_monster_act", "before_monster_attack", "on_monster_attack", "after_monster_attack", "after_monster_act"]:
		m.add_skill(_make_skill_with_trigger(tname, called))
	await m.act()
	assert_eq(called, ["before_monster_act", "on_monster_act", "before_monster_attack", "on_monster_attack", "after_monster_attack", "after_monster_act"])


func test_act_stunned_skips_and_resets() -> void:
	var m: Monster = _make_combat_monster()
	m.stunned = true
	var called: Array = []
	m.add_skill(_make_skill_with_trigger("on_monster_act", called))
	await m.act()
	assert_eq(called.size(), 0, "击晕的怪物跳过行动")
	assert_false(m.stunned, "击晕状态重置为 false")


func test_act_not_stunned_does_not_reset() -> void:
	var m: Monster = _make_combat_monster()
	m.stunned = false
	await m.act()
	assert_false(m.stunned)


# === 4. 攻击流程 ===

func test_attack_none_range_only_targets_attack_target() -> void:
	var m: Monster = _make_combat_monster()
	m.range = "none"
	var p: MockPlayer = MockPlayer.new()
	m.attack_target = p
	m._attack()
	assert_eq(p.damage_received.size(), 1, "none 射程只攻击纠缠玩家一次")
	assert_eq(p.damage_received[0][0], 2, "伤害值为 damage_value")
	assert_eq(p.damage_received[0][1], m, "source 为怪物自身")


func test_attack_with_range_uses_block_players_in_range() -> void:
	var m: Monster = _make_combat_monster()
	m.range = "short"
	m.damage_value = 3
	var p1: MockPlayer = MockPlayer.new()
	var p2: MockPlayer = MockPlayer.new()
	var block: MockBlock = MockBlock.new()
	block.players_in_range = [p1, p2]
	p1.current_block = block
	p2.current_block = block
	m.attack_target = p1
	m._attack()
	assert_eq(p1.damage_received.size(), 1)
	assert_eq(p2.damage_received.size(), 1, "short 射程攻击地块上所有玩家")
	assert_eq(p1.damage_received[0][0], 3)


func test_attack_null_attack_target_safe_return() -> void:
	var m: Monster = _make_combat_monster()
	m.attack_target = null
	# 不应抛错
	m._attack()
	assert_true(true, "attack_target 为 null 时安全返回")


func test_attack_dead_attack_target_skipped() -> void:
	var m: Monster = _make_combat_monster()
	var p: MockPlayer = MockPlayer.new()
	p.hp = 0  # 死亡
	m.attack_target = p
	m._attack()
	assert_eq(p.damage_received.size(), 0, "纠缠玩家死亡时不再攻击")


func test_attack_invalid_block_safe_return() -> void:
	var m: Monster = _make_combat_monster()
	var p: MockPlayer = MockPlayer.new()
	p.current_block = null
	m.attack_target = p
	m._attack()
	assert_true(true, "block 为 null 时安全返回")


# === 5. 死亡流程 ===

func test_death_three_node_trigger_order() -> void:
	var m: Monster = _make_combat_monster()
	var called: Array = []
	for tname in ["before_monster_death", "on_monster_death", "after_monster_death"]:
		m.add_skill(_make_skill_with_trigger(tname, called))
	await m.death(null)
	assert_eq(called, ["before_monster_death", "on_monster_death", "after_monster_death"])


func test_death_removes_from_attack_target_monster_zone() -> void:
	var m: Monster = _make_combat_monster()
	var p: MockPlayer = MockPlayer.new()
	p.monster_zone = [m]
	m.attack_target = p
	await m.death(null)
	assert_eq(p.monster_zone.size(), 0, "应从纠缠玩家怪物区移除")


func test_death_enters_monster_discard_pile() -> void:
	var m: Monster = _make_combat_monster()
	# 暂用 Pile 作为 discard_pile
	var discard: Pile = Pile.new()
	Game.monster_discard_pile = discard
	await m.death(null)
	assert_eq(discard.size(), 1, "应进入怪物弃牌堆")
	# 清理
	Game.monster_discard_pile = null


func test_death_null_attack_target_safe() -> void:
	var m: Monster = _make_combat_monster()
	m.attack_target = null
	Game.monster_discard_pile = Pile.new()
	await m.death(null)
	assert_true(true, "attack_target 为 null 时安全执行")
	Game.monster_discard_pile = null


# === 6. 修改纠缠对象 ===

func test_change_engaged_target_sets_field() -> void:
	var m: Monster = _make_combat_monster()
	var p1: MockPlayer = MockPlayer.new()
	var p2: MockPlayer = MockPlayer.new()
	m.attack_target = p1
	m.change_engaged_target(p2)
	assert_eq(m.attack_target, p2, "应更新纠缠对象")


func test_change_engaged_target_emits_signal() -> void:
	var received: Array = []
	EventBus.monster_engaged_target_changed.connect(
		func(monster, old_t, new_t): received.append([monster, old_t, new_t])
	)
	var m: Monster = _make_combat_monster()
	var p1: MockPlayer = MockPlayer.new()
	var p2: MockPlayer = MockPlayer.new()
	m.attack_target = p1
	m.change_engaged_target(p2)
	assert_eq(received.size(), 1, "应发射 1 次信号")
	assert_eq(received[0][0], m, "信号 monster 参数应为怪物自身")
	assert_eq(received[0][1], p1, "信号 old_target 应为原纠缠对象")
	assert_eq(received[0][2], p2, "信号 new_target 应为新纠缠对象")
	EventBus.monster_engaged_target_changed.get_connections().map(
		func(c): EventBus.monster_engaged_target_changed.disconnect(c.callable)
	)


# === 6.1 change_engaged_target 输出"纠缠了"日志 ===

# 怪物 M 原 attack_target = B，调用 change_engaged_target(A) 后：
# - Game.log_list 应包含 "<M 名> 纠缠了 <A 名>" 日志（颜色标签内含怪物名/玩家名）
# - M.attack_target 应为 A
# - M 应在 A.monster_zone，不在 B.monster_zone
func test_change_engaged_target_logs_entangle_message() -> void:
	var pa: Player = _make_combat_player("玩家A")
	var pb: Player = _make_combat_player("玩家B")
	_setup_game_for_players([pa, pb])
	var m: Monster = _make_combat_monster()
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


# === 6.2 change_engaged_target 重复调用不重复输出日志 ===

# 紧接上场景：M 已纠缠 A，再次调用 change_engaged_target(A)（目标未变），
# 不应再次输出 "纠缠了" 日志（target == old_target 跳过日志）。
func test_change_engaged_target_no_duplicate_log() -> void:
	var pa: Player = _make_combat_player("玩家A")
	var pb: Player = _make_combat_player("玩家B")
	_setup_game_for_players([pa, pb])
	var m: Monster = _make_combat_monster()
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


# === 7. MonsterCard.instantiate ===

func test_monster_card_instantiate_creates_monster() -> void:
	var card: MonsterCard = MonsterCard.new()
	card.card_name = "测试僵尸"
	card.monster_type = "zombie"
	card.monster_level = "elite"
	card.max_hp = 7
	card.damage_value = 3
	card.range = "medium"
	var p: MockPlayer = MockPlayer.new()
	var m: Monster = card.instantiate(p)
	assert_eq(m.monster_name, "测试僵尸")
	assert_eq(m.monster_type, "zombie")
	assert_eq(m.monster_level, "elite")
	assert_eq(m.max_hp, 7)
	assert_eq(m.hp, 7, "实体化时当前生命值 = 最大生命值")
	assert_eq(m.damage_value, 3)
	assert_eq(m.range, "medium")
	assert_eq(m.attack_target, p)
	assert_eq(m.monster_card, card)


func test_monster_card_instantiate_copies_skills() -> void:
	var card: MonsterCard = MonsterCard.new()
	var s1: Skill = Skill.new()
	s1.skill_name = "技能1"
	s1.trigger = "on_monster_act"
	var s2: Skill = Skill.new()
	s2.skill_name = "技能2"
	s2.trigger = "before_monster_death"
	card.add_skill(s1)
	card.add_skill(s2)
	var p: MockPlayer = MockPlayer.new()
	var m: Monster = card.instantiate(p)
	assert_eq(m.get_all_skills().size(), 2, "应挂载 2 个技能到 Monster")


func test_monster_card_instantiate_returns_monster_instance() -> void:
	var card: MonsterCard = MonsterCard.new()
	var p: MockPlayer = MockPlayer.new()
	var m: Monster = card.instantiate(p)
	assert_true(m is Monster, "应返回 Monster 实例")
