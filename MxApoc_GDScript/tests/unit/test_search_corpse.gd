extends GutTest

## "搜索尸体"重设计单元测试。
## 覆盖：mount_sub_skill 挂载/去重、击杀怪物触发抓牌、随机抓牌逻辑、
## 空牌堆日志、非本人击杀不触发、before_turn_end 清除、僵尸女王回归、use_card 端到端
## 设计 spec：.trae/specs/redesign-search-corpse/spec.md

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

## 创建一张拾荒牌（用于填入拾荒牌堆，draw_scavenge 会抓到手牌）
func _make_scavenge_card(card_name: String = "scavenge_card") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "action"
	c.source = "scavenge"
	return c

## 从枪手数据创建一张真实"搜索尸体"卡牌
func _make_search_corpse_card() -> Card:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "应能加载枪手 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("card_name", "") == "搜索尸体":
			return Game._create_game_card_from_dict(card_dict)
	assert(false, "未找到枪手卡牌: 搜索尸体")
	return null

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

func _has_skill_by_english_name(p: Player, en_name: String) -> bool:
	for s in p.get_all_skills():
		if s.english_name == en_name:
			return true
	return false

func _count_skill_by_english_name(p: Player, en_name: String) -> int:
	var count: int = 0
	for s in p.get_all_skills():
		if s.english_name == en_name:
			count += 1
	return count


# === 测试 1: mount_sub_skill 挂载技能 + 去重 ===

func test_mount_sub_skill_search_corpse_mounts_and_dedup() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# First create search_corpse card to register sub_skills
	var card: Card = _make_search_corpse_card()
	p.hand.append(card)
	# mount search_corpse_draw via mount_sub_skill
	p.mount_sub_skill("search_corpse_draw")
	# mount search_corpse_clear via add_temp_skill (same trigger mode — before_turn_end == before_turn_end)
	p.add_temp_skill("search_corpse_clear", "before_turn_end")
	assert_true(_has_skill_by_english_name(p, "search_corpse_draw"), "应挂载 search_corpse_draw")
	assert_true(_has_skill_by_english_name(p, "search_corpse_clear_temp"), "应挂载 search_corpse_clear_temp")
	# 再次调用 mount_sub_skill：去重，不重复挂载
	p.mount_sub_skill("search_corpse_draw")
	assert_eq(_count_skill_by_english_name(p, "search_corpse_draw"), 1, "去重：不重复挂载")


# === 测试 2: 玩家击杀怪物 → 触发抓牌（on_monster_death 在玩家触发）===

func test_player_kill_monster_triggers_draw() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("test_block", 0, 0)
	p.current_block = block
	Game.map_area = [block]
	# 红色拾荒牌堆非空，使抓牌可执行
	Game.red_scavenge_pile.add(_make_scavenge_card("card1"))
	# First create search_corpse card to register sub_skills
	var card: Card = _make_search_corpse_card()
	p.hand.append(card)
	# mount search_corpse_draw via mount_sub_skill
	p.mount_sub_skill("search_corpse_draw")
	# mount search_corpse_clear via add_temp_skill (same trigger mode — before_turn_end == before_turn_end)
	p.add_temp_skill("search_corpse_clear", "before_turn_end")
	# discard the search_corpse card so it doesn't affect hand.size assertions
	await p.discard(card)
	# 创建怪物并放入玩家怪物区
	var m: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [m]
	m.attack_target = p
	# 玩家 P 是击杀者
	await m.death(p)
	assert_eq(p.hand.size(), 1, "应抓 1 张拾荒牌到手牌")
	assert_true(_has_skill_by_english_name(p, "search_corpse_draw"), "技能应仍挂载（回合未结束）")


# === 测试 3: 所有拾荒牌堆为空 → 输出日志，不抓牌 ===

func test_all_scavenge_piles_empty_logs_and_no_draw() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# red/green/blue 均为空 Pile（_setup_game_for_player 已创建空 Pile）
	# First create search_corpse card to register sub_skills
	var card: Card = _make_search_corpse_card()
	p.hand.append(card)
	# mount search_corpse_draw via mount_sub_skill
	p.mount_sub_skill("search_corpse_draw")
	# mount search_corpse_clear via add_temp_skill (same trigger mode — before_turn_end == before_turn_end)
	p.add_temp_skill("search_corpse_clear", "before_turn_end")
	# discard the search_corpse card so it doesn't affect hand.size assertions
	await p.discard(card)
	var m: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [m]
	m.attack_target = p
	await m.death(p)
	assert_eq(p.hand.size(), 0, "空牌堆不应抓牌")
	assert_true(
		Game.log_list.any(func(l): return l.contains("所有拾荒牌堆均为空")),
		"应输出空牌堆日志"
	)


# === 测试 4: 非本人击杀不触发（filter event.source == self）===

func test_non_player_kill_does_not_trigger() -> void:
	var p1: Player = _make_player()
	var p2: Player = _make_player()
	p2.player_name = "玩家2"
	Game.players = [p1, p2]
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
	# 红色拾荒牌堆非空
	Game.red_scavenge_pile.add(_make_scavenge_card("card1"))
	# 仅 P1 挂载搜索尸体技能
	# First create search_corpse card to register sub_skills
	var card: Card = _make_search_corpse_card()
	p1.hand.append(card)
	# mount search_corpse_draw via mount_sub_skill
	p1.mount_sub_skill("search_corpse_draw")
	# mount search_corpse_clear via add_temp_skill (same trigger mode — before_turn_end == before_turn_end)
	p1.add_temp_skill("search_corpse_clear", "before_turn_end")
	# discard the search_corpse card so it doesn't affect hand.size assertions
	await p1.discard(card)
	# 怪物由 P2 击杀
	var m: Monster = _make_monster("僵尸", 20)
	p2.monster_zone = [m]
	m.attack_target = p2
	await m.death(p2)
	assert_eq(p1.hand.size(), 0, "P1 未击杀，不应抓牌")


# === 测试 5: before_turn_end 清除抓牌技能 ===

func test_before_turn_end_clears_skill() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# First create search_corpse card to register sub_skills
	var card: Card = _make_search_corpse_card()
	p.hand.append(card)
	# mount search_corpse_draw via mount_sub_skill
	p.mount_sub_skill("search_corpse_draw")
	# mount search_corpse_clear via add_temp_skill (same trigger mode — before_turn_end == before_turn_end)
	p.add_temp_skill("search_corpse_clear", "before_turn_end")
	assert_true(_has_skill_by_english_name(p, "search_corpse_draw"), "应已挂载 search_corpse_draw")
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_turn_end", event)
	assert_false(_has_skill_by_english_name(p, "search_corpse_draw"), "before_turn_end 后抓牌技能应被移除")
	assert_false(_has_skill_by_english_name(p, "search_corpse_clear_temp"), "clear 技能也应被移除")


# === 测试 6: 回归 — 怪物自身 on_monster_death 技能仍正常触发 ===

func test_monster_own_on_monster_death_skill_still_triggers() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var m: Monster = _make_monster("僵尸", 20)
	# 手动为怪物挂载一个 on_monster_death 技能，触发时写日志
	var death_skill: Skill = Skill.new()
	death_skill.english_name = "test_monster_death_skill"
	death_skill.skill_name = "测试_怪物死亡技能"
	death_skill.trigger = "on_monster_death"
	death_skill.forced = true
	death_skill.content = func(_p, _t, _event: Dictionary, _g) -> void:
		_g.log("monster_death_skill_triggered")
	m.add_skill(death_skill)
	p.monster_zone = [m]
	m.attack_target = p
	await m.death(p)
	assert_true(
		Game.log_list.any(func(l): return l.contains("monster_death_skill_triggered")),
		"怪物自身 on_monster_death 技能应正常触发"
	)


# === 测试 7: use_card 端到端 — 使用"搜索尸体"挂载技能、弃牌、消耗行动 ===

func test_use_card_search_corpse_full_flow() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var block: MapBlock = _make_block("test_block", 0, 0)
	p.current_block = block
	Game.map_area = [block]
	var card: Card = _make_search_corpse_card()
	p.hand.append(card)
	var result: bool = await p.use_card(card)
	assert_true(result, "使用搜索尸体应成功")
	assert_eq(p.action_count, 1, "应消耗 1 行动")
	assert_eq(p.hand.size(), 0, "牌应进入弃牌堆")
	assert_eq(p.game_discard_pile.size(), 1, "牌应在弃牌堆")
	assert_true(_has_skill_by_english_name(p, "search_corpse_draw"), "应挂载 search_corpse_draw")
	assert_true(_has_skill_by_english_name(p, "search_corpse_clear_temp"), "应挂载 search_corpse_clear_temp")
	# 验证技能实际生效：加入拾荒牌、创建怪物、击杀后应抓 1 张
	Game.red_scavenge_pile.add(_make_scavenge_card("card1"))
	var m: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [m]
	m.attack_target = p
	await m.death(p)
	assert_eq(p.hand.size(), 1, "击杀怪物后应抓 1 张拾荒牌")


# === 测试 8: 第一张使用后，第二张"搜索尸体"应被 filter 屏蔽（UI 置灰）===

func test_second_search_corpse_blocked_by_filter() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var block: MapBlock = _make_block("test_block", 0, 0)
	p.current_block = block
	Game.map_area = [block]
	# 第一张"搜索尸体"
	var card1: Card = _make_search_corpse_card()
	p.hand.append(card1)
	var result: bool = await p.use_card(card1)
	assert_true(result, "第一张应可使用")
	assert_true(_has_skill_by_english_name(p, "search_corpse_draw"), "应挂载 search_corpse_draw")
	# 第二张"搜索尸体"：filter 应返回 false，UI 应置灰
	var card2: Card = _make_search_corpse_card()
	p.hand.append(card2)
	assert_false(p.is_card_usable(card2), "第二张应被 filter 屏蔽（已挂载 search_corpse_draw）")
	# 验证 Entity.has_skill_by_english_name 辅助方法
	assert_true(p.has_skill_by_english_name("search_corpse_draw"), "辅助方法应返回 true（已挂载）")
	assert_false(p.has_skill_by_english_name("nonexistent_skill"), "辅助方法应返回 false（未挂载）")


# === 测试 9: before_turn_end 清除后，第二张"搜索尸体"可重新使用 ===

func test_second_search_corpse_usable_after_clear() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var block: MapBlock = _make_block("test_block", 0, 0)
	p.current_block = block
	Game.map_area = [block]
	# 第一张"搜索尸体"使用后挂载技能
	var card1: Card = _make_search_corpse_card()
	p.hand.append(card1)
	await p.use_card(card1)
	assert_false(p.is_card_usable(_make_search_corpse_card()), "技能挂载中：第二张应被屏蔽")
	# before_turn_end 清除技能
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("before_turn_end", event)
	assert_false(_has_skill_by_english_name(p, "search_corpse_draw"), "技能应已清除")
	# 清除后第二张应重新可用
	var card2: Card = _make_search_corpse_card()
	p.hand.append(card2)
	assert_true(p.is_card_usable(card2), "技能清除后：第二张应重新可用")
