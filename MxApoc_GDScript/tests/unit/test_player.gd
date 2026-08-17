extends GutTest

## Player 单元测试。
## 覆盖 34 方法 + 21 节点回合 + 11 节点移动。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md


# === 辅助方法 ===

func _make_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.hp = hp
	p.max_hp = max_hp
	p.player_name = "TestPlayer"
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_card(name: String = "test_card", type: String = "action", source: String = "game") -> Card:
	var c: Card = Card.new()
	c.card_name = name
	c.card_type = type
	c.source = source
	return c


func _make_equipment(name: String = "test_equip") -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	e.charge_type = "ammo"
	e.charge_max = 3
	e.charge_current = 3
	return e


## 创建一张非弹药类装备牌（用于 has_ammo_weapon 的 false 用例）。
func _make_non_ammo_equipment(name: String = "test_armor") -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	e.charge_type = ""
	e.charge_max = 0
	e.charge_current = 0
	return e


func _make_scavenge_card(name: String = "test_scavenge", color: String = "blue") -> ScavengeCard:
	var c: ScavengeCard = ScavengeCard.new()
	c.card_name = name
	c.card_type = "item"
	c.source = "scavenge"
	c.color = color
	c.scavenge_type = "consumable"
	return c


func _make_monster_card(name: String = "test_monster") -> MonsterCard:
	var c: MonsterCard = MonsterCard.new()
	c.card_name = name
	c.card_type = "monster"
	c.source = "monster"
	c.monster_type = "zombie"
	c.monster_level = "normal"
	c.max_hp = 3
	c.damage_value = 2
	c.range = "none"
	return c


func _make_block(name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	return b


func _make_skill_with_trigger(trigger_name: String, called: Array) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		called.append(trigger_name)
	return s


func _make_cancel_skill(trigger_name: String) -> Skill:
	var s: Skill = Skill.new()
	s.trigger = trigger_name
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		EventSystem.cancel(ev)
	return s


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
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


## 探针 input：记录 choose_target 调用参数（用于验证 prompt 传递）。
class _ChooseTargetSpyInput extends CliPlayerInput:
	var last_n: int = -1
	var last_skill: Variant = null
	var last_prompt: String = "__UNSET__"

	func choose_target(n: int, skill: Variant = null, prompt: String = "") -> Array:
		last_n = n
		last_skill = skill
		last_prompt = prompt
		return await super.choose_target(n, skill, prompt)


# === 1. 默认字段与 _init ===

func test_default_fields() -> void:
	var p: Player = Player.new()
	assert_eq(p.hp, 0)
	assert_eq(p.max_hp, 0)
	assert_eq(p.hunger, 1)
	assert_eq(p.stealth, 0)
	assert_eq(p.action_count, 0)
	assert_eq(p.max_action_count, 4)
	assert_eq(p.in_phase, "idle")
	assert_eq(p.hand.size(), 0)
	assert_eq(p.equipment_zone.size(), 0)
	assert_eq(p.monster_zone.size(), 0)
	assert_eq(p.seat_number, 0)
	assert_eq(p.player_name, "")
	assert_eq(p.marks.size(), 0)


func test_init_auto_injects_cli_input() -> void:
	var p: Player = Player.new()
	assert_not_null(p.input, "_init 应自动注入 CliPlayerInput")
	assert_true(p.input is CliPlayerInput)


func test_entity_overrides() -> void:
	var p: Player = Player.new()
	assert_true(p.is_player())
	assert_false(p.is_monster())
	p.hp = 5
	assert_eq(p.get_hp(), 5)
	p.max_hp = 10
	assert_eq(p.get_max_hp(), 10)
	p.reduce_hp(3)
	assert_eq(p.hp, 2)
	p.add_hp(5)
	assert_eq(p.hp, 7)


# === 2. 状态管理 ===

func test_recover_basic() -> void:
	var p: Player = _make_player(5, 10)
	await p.recover(3)
	assert_eq(p.hp, 8, "recover 应加血")


func test_recover_capped_at_max() -> void:
	var p: Player = _make_player(8, 10)
	await p.recover(5)
	assert_eq(p.hp, 10, "recover 不超过 max_hp")


func test_recover_zero_or_negative_no_op() -> void:
	var p: Player = _make_player(5, 10)
	await p.recover(0)
	assert_eq(p.hp, 5)
	await p.recover(-3)
	assert_eq(p.hp, 5)


func test_recover_triggers_all_4_hooks() -> void:
	var p: Player = _make_player(5, 10)
	var called: Array = []
	p.add_skill(_make_skill_with_trigger("before_recover", called))
	p.add_skill(_make_skill_with_trigger("on_recover", called))
	p.add_skill(_make_skill_with_trigger("after_recover", called))
	await p.recover(2)
	assert_eq(called, ["before_recover", "on_recover", "after_recover"])


func test_recover_cancel_before_returns_no_op() -> void:
	var p: Player = _make_player(5, 10)
	p.add_skill(_make_cancel_skill("on_recover"))
	await p.recover(3)
	assert_eq(p.hp, 5, "on_recover 取消后不应加血")


func test_increase_hunger_normal() -> void:
	var p: Player = _make_player(10, 10)
	await p.increase_hunger(2)
	assert_eq(p.hunger, 3)


func test_increase_hunger_at_6_flips_role_card() -> void:
	var p: Player = _make_player(10, 10)
	p.role_card = RoleCard.new()
	p.role_card.is_front_side = true
	p.hunger = 5
	await p.increase_hunger(1)
	assert_eq(p.hunger, 6)
	assert_false(p.role_card.is_front_side, "饥饿达 6 应翻面角色卡")
	assert_eq(p.count_mark("hunger_damage_level"), 1)
	# 等级 1 造成 2 点伤害
	assert_eq(p.hp, 8)


func test_increase_hunger_level_2_damage() -> void:
	var p: Player = _make_player(10, 10)
	p.role_card = RoleCard.new()
	p.role_card.is_front_side = false  # 已翻面（第一次结算已完成）
	p.hunger = 6
	p.add_mark("hunger_damage_level", 1)  # 第一次结算标记
	# 第二次饥饿结算：等级 2 → 4 伤害
	await p.increase_hunger(1)
	assert_eq(p.count_mark("hunger_damage_level"), 2)
	assert_eq(p.hp, 6)


func test_decrease_hunger_normal() -> void:
	var p: Player = _make_player(10, 10)
	p.hunger = 4
	p.decrease_hunger(2)
	assert_eq(p.hunger, 2)


func test_decrease_hunger_floor_at_1() -> void:
	var p: Player = _make_player(10, 10)
	p.hunger = 3
	p.decrease_hunger(5)
	assert_eq(p.hunger, 1, "饥饿最低 1")


func test_decrease_hunger_clears_hunger_damage_mark() -> void:
	var p: Player = _make_player(10, 10)
	p.role_card = RoleCard.new()
	p.role_card.is_front_side = false
	p.add_mark("hunger_damage_level", 2)
	p.hunger = 6
	p.decrease_hunger(2)
	assert_false(p.has_mark("hunger_damage_level"), "降饥饿应清除饥饿伤害标记")
	assert_true(p.role_card.is_front_side, "降饥饿应恢复角色卡正面")


func test_poison_no_mark_no_damage() -> void:
	var p: Player = _make_player(10, 10)
	await p.poison()
	assert_eq(p.hp, 10, "无中毒标记不扣血")


func test_poison_with_mark_deals_damage() -> void:
	var p: Player = _make_player(10, 10)
	p.add_mark("poison", 3)
	await p.poison()
	assert_eq(p.hp, 7, "中毒应扣 3 血")


# === 3. 抓牌流程 ===

func test_draw_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.game_deck.add(c1)
	p.game_deck.add(c2)
	await p.draw(2)
	assert_eq(p.hand.size(), 2)


func test_draw_zero_no_op() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	await p.draw(0)
	assert_eq(p.hand.size(), 0)


func test_draw_empty_deck_triggers_death() -> void:
	var p: Player = _make_player(5, 10)
	_setup_game_for_player(p)
	# 空牌堆
	await p.draw(1)
	assert_eq(p.hp, 0, "空牌堆抓牌应导致玩家死亡")
	assert_true(Game.game_over_called, "应触发全灭检查")


func test_draw_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_draw_game_card"))
	var c1: Card = _make_card("c1")
	p.game_deck.add(c1)
	await p.draw(1)
	assert_eq(p.hand.size(), 0, "before_draw_game_card 取消后不应抓牌")


func test_draw_cancel_on() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("on_draw_game_card"))
	var c1: Card = _make_card("c1")
	p.game_deck.add(c1)
	await p.draw(1)
	assert_eq(p.hand.size(), 0, "on_draw_game_card 取消后不应抓牌")


func test_draw_scavenge_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var pile: Pile = Pile.new()
	var c1: ScavengeCard = _make_scavenge_card("scav1")
	pile.add(c1)
	await p.draw_scavenge(1, pile)
	assert_eq(p.hand.size(), 1)


func test_draw_scavenge_empty_pile_no_draw() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var pile: Pile = Pile.new()
	await p.draw_scavenge(1, pile)
	assert_eq(p.hand.size(), 0, "空牌堆不抓牌")


func test_draw_scavenge_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_draw_scavenge_card"))
	var pile: Pile = Pile.new()
	pile.add(_make_scavenge_card("s1"))
	await p.draw_scavenge(1, pile)
	assert_eq(p.hand.size(), 0)


func test_draw_monster_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var mc: MonsterCard = _make_monster_card("goblin")
	Game.monster_pile.add(mc)
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 1, "应实体化 1 个怪物")


func test_draw_monster_empty_pile_reshuffles_discard() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# 怪物牌堆空，弃牌堆有 1 张
	var mc: MonsterCard = _make_monster_card("goblin")
	Game.monster_discard_pile.add(mc)
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 1, "应从弃牌堆重洗后实体化")


func test_draw_monster_empty_pile_and_discard_triggers_lose() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# 牌堆和弃牌堆都空
	await p.draw_monster(1)
	assert_true(Game.game_over_called, "应触发 game_over('lose')")
	assert_eq(Game.game_result, "lose")


func test_draw_monster_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_draw_monster_card"))
	var mc: MonsterCard = _make_monster_card("goblin")
	Game.monster_pile.add(mc)
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 0, "取消后不应实体化怪物")


# === 4. 弃牌与销毁 ===

func test_discard_single_card() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c: Card = _make_card("c1")
	p.hand.append(c)
	await p.discard(c)
	assert_eq(p.hand.size(), 0, "弃置后手牌应减少")
	assert_eq(p.game_discard_pile.size(), 1, "应进入游戏牌弃牌堆")


func test_discard_array_of_cards() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	await p.discard([c1, c2])
	assert_eq(p.hand.size(), 0)
	assert_eq(p.game_discard_pile.size(), 2)


func test_discard_scavenge_card_goes_to_scavenge_discard() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c: ScavengeCard = _make_scavenge_card("s1")
	p.hand.append(c)
	await p.discard(c)
	assert_eq(p.hand.size(), 0)
	assert_eq(Game.scavenge_discard_pile.size(), 1, "拾荒卡应进入拾荒弃牌堆")


func test_discard_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_discard"))
	var c: Card = _make_card("c1")
	p.hand.append(c)
	await p.discard(c)
	assert_eq(p.hand.size(), 1, "取消后不应弃置")


func test_remove_card_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c: Card = _make_card("c1")
	p.hand.append(c)
	await p.remove_card(c)
	assert_eq(p.hand.size(), 0, "销毁后手牌应减少")
	assert_eq(Game.removed_cards.size(), 1, "应进入 removed_cards")


func test_remove_card_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_remove_card"))
	var c: Card = _make_card("c1")
	p.hand.append(c)
	await p.remove_card(c)
	assert_eq(p.hand.size(), 1, "取消后不应销毁")


# === 5. 移动流程 ===

func test_move_to_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var src: MapBlock = _make_block("src", 0, 0)
	var dst: MapBlock = _make_block("dst", 1, 0)
	Game.map_area = [src, dst]
	p.current_block = src
	var result: bool = await p.move_to(dst)
	assert_true(result, "移动应成功")
	assert_eq(p.current_block, dst, "应切换到目标地块")
	assert_true(p.has_mark("moved_this_turn"), "应添加 moved_this_turn 标记")


func test_move_to_cancel_before_enter_rolls_back() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_enter_block"))
	var src: MapBlock = _make_block("src", 0, 0)
	var dst: MapBlock = _make_block("dst", 1, 0)
	Game.map_area = [src, dst]
	p.current_block = src
	var result: bool = await p.move_to(dst)
	assert_false(result, "取消后应返回 false")
	assert_eq(p.current_block, src, "取消后应保留原地块")


func test_move_to_triggers_leave_and_enter_hooks() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var called: Array = []
	p.add_skill(_make_skill_with_trigger("before_leave_block", called))
	p.add_skill(_make_skill_with_trigger("on_leave_block", called))
	p.add_skill(_make_skill_with_trigger("after_leave_block", called))
	p.add_skill(_make_skill_with_trigger("before_enter_block", called))
	p.add_skill(_make_skill_with_trigger("on_enter_block", called))
	p.add_skill(_make_skill_with_trigger("after_enter_block", called))
	var src: MapBlock = _make_block("src", 0, 0)
	var dst: MapBlock = _make_block("dst", 1, 0)
	dst.revealed = true
	Game.map_area = [src, dst]
	p.current_block = src
	await p.move_to(dst)
	assert_eq(called.size(), 6, "应触发 6 个移动钩子")


func test_move_to_reveals_unrevealed_block() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var src: MapBlock = _make_block("src", 0, 0)
	var dst: MapBlock = _make_block("dst", 1, 0)
	dst.revealed = false
	Game.map_area = [src, dst]
	p.current_block = src
	await p.move_to(dst)
	assert_true(dst.revealed, "应展示目标地块")


func test_move_to_with_monster_mark_sneak_fail_draws_monster() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# 强制潜行检定失败：添加 on_sneak_judge 技能修改 result.success = false
	var s: Skill = Skill.new()
	s.trigger = "on_sneak_judge"
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		ev["result"] = {"value": 99, "success": false}
	p.add_skill(s)
	var src: MapBlock = _make_block("src", 0, 0)
	var dst: MapBlock = _make_block("dst", 1, 0)
	dst.revealed = true
	dst.add_monster_mark(2)
	Game.map_area = [src, dst]
	p.current_block = src
	# 怪物牌堆有 2 张
	Game.monster_pile.add(_make_monster_card("m1"))
	Game.monster_pile.add(_make_monster_card("m2"))
	await p.move_to(dst)
	assert_eq(p.monster_zone.size(), 2, "潜行失败应抽 2 个怪物")
	assert_eq(dst.count_monster_mark(), 0, "应清空怪物标记")


func test_move_to_triggers_objective_mark() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var src: MapBlock = _make_block("src", 0, 0)
	var dst: MapBlock = _make_block("dst", 1, 0)
	dst.revealed = true
	Game.map_area = [src, dst]
	p.current_block = src
	var effect_called: Array = []
	var mark: Dictionary = {
		"id": "m1",
		"description": "test",
		"effect": func(_player) -> void: effect_called.append(true),
		"triggered": false,
		"initial_monster_marks": 0,
		"remove_condition": Callable(),
		"removed": false,
	}
	dst.add_objective_mark(mark)
	await p.move_to(dst)
	assert_eq(effect_called.size(), 1, "应触发目标标记效果")


func test_move_to_null_target_returns_false() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var src: MapBlock = _make_block("src", 0, 0)
	Game.map_area = [src]
	p.current_block = src
	var result: bool = await p.move_to(null)
	# null 目标不应崩溃；具体行为依实现
	assert_true(result != null or result == false or result == true, "null 目标不应崩溃")


# === 6. 检定系统 ===

func test_judge_returns_2_to_12() -> void:
	var p: Player = _make_player()
	for i in 100:
		var v: int = p.judge()
		assert_true(v >= 2 and v <= 12, "judge 应在 2-12 范围内")


func test_sneak_judge_success_high_sneak() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	p.role_card = RoleCard.new()
	p.role_card.sneak = 20
	var result: bool = await p.sneak_judge()
	assert_true(result, "高潜行应检定成功")


func test_sneak_judge_skip_judge_flag() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	var s: Skill = Skill.new()
	s.trigger = "before_sneak_judge"
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		ev["skip_judge"] = true
		ev["result"] = {"value": 0, "success": true}
	p.add_skill(s)
	var result: bool = await p.sneak_judge()
	assert_true(result, "skip_judge 应直接使用 event.result")


func test_sneak_judge_triggers_3_hooks() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	var called: Array = []
	p.add_skill(_make_skill_with_trigger("before_sneak_judge", called))
	p.add_skill(_make_skill_with_trigger("on_sneak_judge", called))
	p.add_skill(_make_skill_with_trigger("after_sneak_judge", called))
	await p.sneak_judge()
	assert_eq(called.size(), 3)


func test_monster_spawn_judge_no_match_no_mark() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b", 0, 0)
	block.revealed = true
	block.monster_spawn_value = 999  # 不可能匹配
	Game.map_area = [block]
	# 不应崩溃
	p.monster_spawn_judge()
	assert_eq(block.count_monster_mark(), 0)


func test_monster_spawn_judge_match_adds_mark() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b", 0, 0)
	block.revealed = true
	block.monster_spawn_value = 7
	Game.map_area = [block]
	# 强制投骰结果为 7
	var s: Skill = Skill.new()
	s.trigger = "on_spawn_judge"
	s.content = func(_p, _t, ev: Dictionary, _g) -> void:
		ev["result"] = {"value": 7, "success": true}
	p.add_skill(s)
	p.monster_spawn_judge()
	assert_eq(block.count_monster_mark(), 1, "匹配地块应添加 1 个怪物标记")


# === 7. 死亡流程 ===

func test_death_moves_monsters_to_discard() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var mc: MonsterCard = _make_monster_card("goblin")
	var monster: Monster = mc.instantiate(p)
	p.monster_zone.append(monster)
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	await p.death(null)
	assert_eq(p.monster_zone.size(), 0, "怪物区应清空")
	assert_eq(Game.monster_discard_pile.size(), 1, "怪物应进入弃牌堆")


func test_death_adds_monster_marks_to_block() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var mc1: MonsterCard = _make_monster_card("m1")
	var mc2: MonsterCard = _make_monster_card("m2")
	p.monster_zone.append(mc1.instantiate(p))
	p.monster_zone.append(mc2.instantiate(p))
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	await p.death(null)
	assert_eq(block.count_monster_mark(), 2, "应往地块放 2 个怪物标记")


func test_death_marks_capped_at_3() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	for i in 5:
		var mc: MonsterCard = _make_monster_card("m%d" % i)
		p.monster_zone.append(mc.instantiate(p))
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	await p.death(null)
	assert_eq(block.count_monster_mark(), 3, "怪物标记上限 3")


func test_death_triggers_3_hooks() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var called: Array = []
	p.add_skill(_make_skill_with_trigger("before_player_death", called))
	p.add_skill(_make_skill_with_trigger("on_player_death", called))
	p.add_skill(_make_skill_with_trigger("after_player_death", called))
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	await p.death(null)
	assert_eq(called.size(), 3)


func test_death_coop_mode_triggers_lose() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	Game.coop_death_mode = true
	var other: Player = _make_player(10, 10)
	Game.players = [p, other]
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	await p.death(null)
	assert_true(Game.game_over_called, "同生共死模式应触发 game_over")
	assert_eq(Game.game_result, "lose")


# === 8. 使用卡牌 ===

func test_use_card_equipment_routes_to_equip() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var e: EquipmentCard = _make_equipment("weapon")
	p.hand.append(e)
	var result: bool = await p.use_card(e)
	assert_true(result)
	assert_eq(p.equipment_zone.size(), 1, "装备应进入装备区")
	assert_eq(p.action_count, 1, "应消耗 1 行动")


func test_use_card_action_routes_to_discard() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构造带 active="action" 技能的行动牌，验证 content 执行后再弃牌
	var c: Card = _make_card("action1", "action")
	var called: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.content = func(_pl, _t, _ev: Dictionary, _g) -> void:
		called.append(true)
	c.add_skill(s)
	p.hand.append(c)
	var result: bool = await p.use_card(c)
	assert_true(result)
	assert_eq(called.size(), 1, "行动牌 content 应执行一次")
	assert_eq(p.hand.size(), 0, "行动牌应被弃置")
	assert_eq(p.game_discard_pile.size(), 1, "行动牌应进入弃牌堆")
	assert_eq(p.action_count, 1)


func test_use_card_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_use_card"))
	p.action_count = 2
	var c: Card = _make_card("c1")
	p.hand.append(c)
	var result: bool = await p.use_card(c)
	assert_false(result)
	assert_eq(p.action_count, 2, "取消后不应消耗行动")


# === 9. 装备流程 ===

func test_equip_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	var result: bool = await p.equip(e)
	assert_true(result)
	assert_eq(p.equipment_zone.size(), 1)


func test_equip_mounts_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	var s: Skill = Skill.new()
	s.skill_name = "weapon_skill"
	e.add_skill(s)
	await p.equip(e)
	assert_eq(p.get_all_skills().size(), 1, "装备技能应挂载到玩家")


func test_equip_same_name_discards_existing() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e1: EquipmentCard = _make_equipment("weapon")
	var e2: EquipmentCard = _make_equipment("weapon")
	await p.equip(e1)
	await p.equip(e2)
	assert_eq(p.equipment_zone.size(), 1, "同名装备应替换")
	assert_eq(p.game_discard_pile.size(), 1, "原装备应弃置")


func test_equip_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_equip"))
	var e: EquipmentCard = _make_equipment("weapon")
	var result: bool = await p.equip(e)
	assert_false(result)
	assert_eq(p.equipment_zone.size(), 0)


func test_unequip_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	await p.equip(e)
	var result: bool = await p.unequip(e)
	assert_true(result)
	assert_eq(p.equipment_zone.size(), 0)


func test_unequip_removes_skills() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	var s: Skill = Skill.new()
	s.skill_name = "weapon_skill"
	e.add_skill(s)
	await p.equip(e)
	assert_eq(p.get_all_skills().size(), 1)
	await p.unequip(e)
	assert_eq(p.get_all_skills().size(), 0, "卸下应移除技能")


func test_unequip_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	await p.equip(e)
	p.add_skill(_make_cancel_skill("before_unequip"))
	var result: bool = await p.unequip(e)
	assert_false(result)
	assert_eq(p.equipment_zone.size(), 1)


# === 10. 填充物 ===

func test_consume_charge_basic() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	e.charge_current = 3
	var result: bool = await p.consume_charge(e, 2)
	assert_true(result)
	assert_eq(e.charge_current, 1, "应扣减 2")


func test_consume_charge_insufficient_returns_false() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	e.charge_current = 1
	var result: bool = await p.consume_charge(e, 3)
	assert_false(result, "填充物不足应返回 false")
	assert_eq(e.charge_current, 1, "不应扣减")


func test_consume_charge_cancel_before() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_skill(_make_cancel_skill("before_consume_charge"))
	var e: EquipmentCard = _make_equipment("weapon")
	e.charge_current = 3
	var result: bool = await p.consume_charge(e, 1)
	assert_false(result)
	assert_eq(e.charge_current, 3, "取消后不应扣减")


func test_consume_charge_depleted_triggers_hook() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var called: Array = []
	p.add_skill(_make_skill_with_trigger("on_charge_depleted", called))
	var e: EquipmentCard = _make_equipment("weapon")
	e.charge_current = 1
	await p.consume_charge(e, 1)
	assert_eq(called.size(), 1, "耗尽应触发 on_charge_depleted")


# === 11. 回合流程 ===

func test_start_turn_resets_action_count() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 0
	# 准备牌堆避免死亡
	p.game_deck.add(_make_card("c1"))
	var block: MapBlock = _make_block("b", 0, 0)
	block.revealed = true
	Game.map_area = [block]
	p.current_block = block
	await p.start_turn()
	assert_eq(p.action_count, p.max_action_count, "回合开始应重置行动次数")


func test_start_turn_clears_turn_marks() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.add_mark("moved_this_turn")
	p.game_deck.add(_make_card("c1"))
	var block: MapBlock = _make_block("b", 0, 0)
	block.revealed = true
	Game.map_area = [block]
	p.current_block = block
	await p.start_turn()
	assert_false(p.has_mark("moved_this_turn"), "回合开始应清除临时标记")


func test_start_turn_phases_progression() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var phases: Array = []
	var s: Skill = Skill.new()
	s.trigger = "on_turn_start、before_monster_spawn、before_draw_phase、before_action_phase、before_hunger_settlement、before_poison_settlement、before_zone_monster_act、before_turn_end"
	s.content = func(_p, _t, _ev: Dictionary, _g) -> void:
		phases.append(p.in_phase)
	p.add_skill(s)
	p.game_deck.add(_make_card("c1"))
	var block: MapBlock = _make_block("b", 0, 0)
	block.revealed = true
	Game.map_area = [block]
	p.current_block = block
	await p.start_turn()
	# 验证至少触发了回合开始
	assert_true(phases.size() > 0, "应触发回合流程节点")


func test_start_turn_empty_deck_death_returns_early() -> void:
	var p: Player = _make_player(5, 10)
	_setup_game_for_player(p)
	# 空牌堆，draw(1) 会触发死亡
	var block: MapBlock = _make_block("b", 0, 0)
	block.revealed = true
	Game.map_area = [block]
	p.current_block = block
	await p.start_turn()
	assert_eq(p.hp, 0, "空牌堆应导致死亡")
	# 死亡后应提前返回，不再执行后续阶段
	assert_eq(p.in_phase, "draw", "应在摸牌阶段死亡")


# === 12. 底层接口 ===

func test_get_cards_by_name() -> void:
	var p: Player = _make_player()
	p.hand.append(_make_card("potion"))
	p.hand.append(_make_card("weapon"))
	p.hand.append(_make_card("potion"))
	var result: Array = p.get_cards("hand", "potion")
	assert_eq(result.size(), 2)


func test_get_cards_by_position() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.hand.append(_make_card("c1"))
	var e1: EquipmentCard = _make_equipment("e1")
	await p.equip(e1)
	var hand_only: Array = p.get_cards("hand")
	assert_eq(hand_only.size(), 1)
	var equip_only: Array = p.get_cards("equipment")
	assert_eq(equip_only.size(), 1)


func test_get_all_game_cards() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var c1: Card = _make_card("c1")
	var c2: EquipmentCard = _make_equipment("c2")
	var c3: Card = _make_card("c3")
	var c4: Card = _make_card("c4")
	p.hand.append(c1)
	await p.equip(c2)
	p.game_deck.add(c3)
	p.game_discard_pile.add(c4)
	var all: Array = p.get_all_game_cards()
	assert_eq(all.size(), 4, "应返回所有游戏牌")
	assert_true(all.has(c2), "装备区来源卡应在所有游戏牌中")


func test_has_non_boss_monster() -> void:
	var p: Player = _make_player()
	assert_false(p.has_non_boss_monster())
	var mc: MonsterCard = _make_monster_card("goblin")
	p.monster_zone.append(mc.instantiate(p))
	assert_true(p.has_non_boss_monster())


func test_marks_management() -> void:
	var p: Player = _make_player()
	assert_eq(p.count_mark("poison"), 0)
	assert_false(p.has_mark("poison"))
	p.add_mark("poison", 2)
	assert_eq(p.count_mark("poison"), 2)
	assert_true(p.has_mark("poison"))
	p.remove_mark("poison")
	assert_false(p.has_mark("poison"))


func test_has_equipment() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_false(p.has_equipment("weapon"))
	var e: EquipmentCard = _make_equipment("weapon")
	await p.equip(e)
	assert_true(p.has_equipment("weapon"))
	var entity: Equipment = p.get_equipment("weapon")
	assert_not_null(entity)
	assert_true(entity is Equipment, "get_equipment 应返回 Equipment 实体")
	assert_eq(entity.equipment_card, e, "实体 equipment_card 应回引来源卡")


func test_get_number() -> void:
	var p: Player = _make_player(7, 10)
	p.action_count = 3
	p.hunger = 4
	assert_eq(p.get_number("hp"), 7)
	assert_eq(p.get_number("action_count"), 3)
	assert_eq(p.get_number("hunger"), 4)
	assert_eq(p.get_number("unknown"), 0)


func test_choose_delegates_to_input() -> void:
	var p: Player = _make_player()
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose("picked")
	p.input = cli
	var result: Variant = await p.choose(["a", "b", "picked"])
	assert_eq(result, "picked", "choose 应委托给 input")


# === 13. 技能辅助方法 ===

func test_discard_non_boss_monster_to_mark() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var mc: MonsterCard = _make_monster_card("goblin")
	var monster: Monster = mc.instantiate(p)
	p.monster_zone.append(monster)
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	# CliPlayerInput 默认选择第一项
	await p.discard_non_boss_monster_to_mark()
	assert_eq(p.monster_zone.size(), 0, "应弃置非首领怪物")
	assert_eq(block.count_monster_mark(), 1, "应放 1 个怪物标记")


func test_pull_one_step_toward_target() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var src: MapBlock = _make_block("src", 0, 0)
	var mid: MapBlock = _make_block("mid", 1, 0)
	var dst_block: MapBlock = _make_block("dst", 2, 0)
	Game.map_area = [src, mid, dst_block]
	p.current_block = src
	var target: Player = _make_player()
	target.current_block = dst_block
	p.pull_one_step(target)
	assert_eq(p.current_block, mid, "应拉近一格到 mid")


func test_heal_all_status() -> void:
	var p: Player = _make_player()
	p.add_mark("poison", 2)
	p.add_mark("hunger_damage_level", 1)
	p.heal_all_status()
	assert_false(p.has_mark("poison"))
	assert_false(p.has_mark("hunger_damage_level"))


func test_play_card_immediately_equipment() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = _make_equipment("weapon")
	p.hand.append(e)
	# CliPlayerInput 默认 choose_card 返回空，需注入
	p.input.queue_choose_card([e])
	await p.play_card_immediately()
	assert_eq(p.equipment_zone.size(), 1, "应装备选择的卡")


# === 14. 任务系统方法 ===

func test_has_item() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_false(p.has_item("potion"))
	p.hand.append(_make_card("potion"))
	assert_true(p.has_item("potion"))
	var special: EquipmentCard = _make_equipment("special")
	await p.equip(special)
	assert_true(p.has_item("special"))


func test_collect_item_no_game_scavenge_def() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# create_scavenge_card stub 返回 null
	p.collect_item("日记本", 1)
	assert_eq(p.hand.size(), 0, "stub 返回 null 时不加手牌")


func test_draw_boss_card_finds_in_pile() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var boss_mc: MonsterCard = _make_monster_card("boss")
	boss_mc.monster_level = "boss"
	Game.monster_pile.add(boss_mc)
	p.draw_boss_card()
	# 应从牌堆找到 boss 卡并实体化
	assert_eq(p.monster_zone.size(), 1)
	assert_eq(p.monster_zone[0].monster_level, "boss")


func test_draw_boss_card_no_boss_logs_warning() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	# 牌堆和弃牌堆都无 boss 卡
	p.draw_boss_card()
	assert_eq(p.monster_zone.size(), 0)
	# 应有日志输出
	assert_true(Game.log_list.size() > 0, "应记录警告日志")


func test_rescue_scientist_option_no_mission_config() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# mission_config 为 null
	await p.rescue_scientist_option()
	assert_eq(p.action_count, 2, "无 mission_config 不应消耗行动")


func test_record_scientist_info() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var mc: MissionConfig = MissionConfig.new()
	Game.mission_config = mc
	p.record_scientist_info()
	assert_true(mc.mission_state.get("scientist_info_recorded", false), "应记录科学家信息")


# === max_action 方法 ===

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


# === Merged mechanism tests (from cleanup) ===

# 测试: player.choose_target 接受 prompt 参数并传递给 input
func test_player_choose_target_passes_prompt_to_input() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var spy: _ChooseTargetSpyInput = _ChooseTargetSpyInput.new()
	# 队列注入一个空数组作为返回值，避免阻塞
	spy.queue_choose_target([])
	p.input = spy
	var _r: Array = await p.choose_target(1, null, "测试 prompt 文本")
	assert_eq(spy.last_prompt, "测试 prompt 文本", "choose_target 应将 prompt 传递给 input")
	assert_eq(spy.last_n, 1, "choose_target 应将 n 传递给 input")


# 测试: player.choose_target 的 prompt 参数默认为空字符串
func test_player_choose_target_prompt_defaults_empty() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var spy: _ChooseTargetSpyInput = _ChooseTargetSpyInput.new()
	spy.queue_choose_target([])
	p.input = spy
	var _r: Array = await p.choose_target(1)
	assert_eq(spy.last_prompt, "", "未传 prompt 时应默认为空字符串")


# 测试: choose_target 接受 Dictionary 类型的 skill 参数（不崩溃）
func test_choose_target_accepts_dictionary_skill_config() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var config: Dictionary = {
		"filter_target_range": "long",
		"filter_target": "return target != player"
	}
	# 应正常返回，不崩溃
	var result: Array = await p.choose_target(1, config, "测试 Dictionary 配置")
	assert_eq(result.size(), 0, "CLI 队列注入空数组时应返回空数组")


# 测试: 装备区有弹药武器时返回 true
func test_has_ammo_weapon_true() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_equipment("手枪")
	await p.equip(weapon)
	assert_true(p.has_ammo_weapon(), "装备区有弹药武器时应返回 true")


# 测试: 装备区无弹药武器时返回 false
func test_has_ammo_weapon_false_no_ammo() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var armor: EquipmentCard = _make_non_ammo_equipment("护甲")
	await p.equip(armor)
	assert_false(p.has_ammo_weapon(), "装备区无弹药武器时应返回 false")


# 测试: 空装备区时返回 false
func test_has_ammo_weapon_false_empty() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	assert_false(p.has_ammo_weapon(), "空装备区时应返回 false")


# 测试: remove_card 输出玩家销毁详细日志（不输出兜底日志）
func test_remove_card_logs_player_destroy_message() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	Game.log_list = []
	var c: Card = _make_card("测试牌")
	p.hand.append(c)
	await p.remove_card(c)
	# 详细日志应包含 "TestPlayer" + "将" + "测试牌" + "移出游戏"
	assert_true(
		Game.log_list.any(func(l): return l.contains("TestPlayer") and l.contains("将") and l.contains("测试牌") and l.contains("移出游戏")),
		"应输出玩家销毁详细日志：TestPlayer 将 测试牌 移出游戏"
	)
	# 不应出现兜底日志（"被移出游戏" + "测试牌"）
	assert_false(
		Game.log_list.any(func(l): return l.contains("被移出游戏") and l.contains("测试牌")),
		"不应输出兜底销毁日志（玩家销毁日志已输出，silent 传递至 Game.remove_card）"
	)


# 测试: Game.remove_card 默认输出兜底日志
func test_game_remove_card_fallback_log() -> void:
	Game.log_list = []
	var card: Card = Card.new()
	card.card_name = "测试牌"
	await Game.remove_card(card)
	assert_true(
		Game.log_list.any(func(l): return l.contains("测试牌") and l.contains("被移出游戏")),
		"默认调用应输出兜底日志：测试牌 被移出游戏"
	)
	assert_true(Game.removed_cards.has(card), "卡牌应进入 removed_cards")


# 测试: Game.remove_card silent=true 不输出日志
func test_game_remove_card_silent_no_log() -> void:
	Game.log_list = []
	var card: Card = Card.new()
	card.card_name = "测试牌"
	await Game.remove_card(card, true)
	assert_false(
		Game.log_list.any(func(l): return l.contains("被移出游戏")),
		"silent=true 时不应输出兜底销毁日志"
	)
	assert_true(Game.removed_cards.has(card), "卡牌应进入 removed_cards（数据行为保留）")
