extends TestBase

## 老兵与狗：座位 + 双子生命体。


const WikiIndex = preload("res://src/ui/wiki_index.gd")


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


func _make_veteran_seat() -> Player:
	var survivor: SurvivorData = DataManager.get_survivor("veteran")
	assert_not_null(survivor, "应加载 veteran 求生者数据")
	var p: Player = _make_player("老兵与狗", 0, 0)
	p.role_card = Game._create_role_card_from_survivor(survivor)
	Game._create_companion_bodies(p, survivor)
	for sub_dict in survivor.sub_survivors:
		if not (sub_dict is Dictionary):
			continue
		var sub_data: SurvivorData = SurvivorData.new(sub_dict)
		for skill_data in sub_data.intrinsic_skills:
			p.add_skill(Game._create_skill_from_data(skill_data))
	return p


func _deck_card_dict(english_name: String) -> Dictionary:
	var survivor: SurvivorData = DataManager.get_survivor("veteran")
	for card_dict in survivor.deck:
		if str(card_dict.get("english_name", "")) == english_name:
			return card_dict
	return {}


func test_veteran_is_player_mode_available() -> void:
	var old: bool = Settings.dev_mode
	Settings.dev_mode = false
	var ids: Array = []
	for survivor in DataManager.get_available_survivors():
		ids.append(survivor.english_name)
	Settings.dev_mode = old
	assert_true(ids.has("veteran"), "玩家模式白名单应包含老兵")


func test_factory_builds_two_bodies() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	assert_true(p.has_companion_bodies())
	assert_eq(p.bodies.size(), 2)
	assert_not_null(p.get_body("veteran_human"))
	assert_not_null(p.get_body("dog"))
	assert_eq(p.get_body("veteran_human").hp, 22)
	assert_eq(p.get_body("dog").hp, 12)
	assert_eq(p.hp, 0, "座位本身不持有战斗生命值")
	assert_true(p.is_alive())
	assert_true(p.get_controller_body() == p.get_body("veteran_human"))


func test_dual_alive_capacity_and_sneak_min() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	assert_eq(p.get_hand_size_limit(), 14, "双活手牌上限 8+6")
	assert_eq(p.get_equipment_capacity(), 4, "双活装备栏 4+0")
	assert_eq(p.get_sneak(), 7, "双活潜行取较低值（老兵 7）")


func test_untargeted_damage_hits_controller() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var veteran: Variant = p.get_body("veteran_human")
	var dog: Variant = p.get_body("dog")
	assert_eq(veteran.get_hp(), 22)
	await p.damage(3, null)
	assert_eq(veteran.get_hp(), 19, "座位无目标伤害应打操控者")
	assert_eq(dog.get_hp(), 12)


func test_dog_collar_reduces_only_dog_damage() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var raw: Dictionary = _deck_card_dict("dog_collar")
	assert_false(raw.is_empty(), "应有狗项圈数据")
	var collar: Card = Game._create_game_card_from_dict(raw)
	assert_not_null(collar)
	assert_true(await p.equip(collar))
	var veteran: Variant = p.get_body("veteran_human")
	var dog: Variant = p.get_body("dog")
	await veteran.damage(3, null)
	assert_eq(veteran.get_hp(), 19, "项圈不应减免老兵伤害")
	await dog.damage(3, null)
	assert_eq(dog.get_hp(), 10, "项圈应对狗减 1 点伤害")


func test_filter_target_excludes_own_bodies_when_not_self() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var other: Player = _make_player("Ally", 10, 10)
	Game.players = [p, other]
	var skill: Skill = Skill.new()
	skill.filter_target = CodeExecutor.compile_filter_target("return target != player")
	assert_false(p.candidate_passes_filter_target(skill, p.get_body("dog"), {}), "target != player 应排除自己的狗")
	assert_false(p.candidate_passes_filter_target(skill, p.get_body("veteran_human"), {}), "target != player 应排除自己的老兵")
	assert_true(p.candidate_passes_filter_target(skill, other, {}), "应允许选其他座位")


func test_shares_seat_and_expand_targets() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var veteran: Variant = p.get_body("veteran_human")
	var dog: Variant = p.get_body("dog")
	assert_true(p.shares_seat(veteran))
	assert_true(p.shares_seat(dog))
	assert_true(veteran.shares_seat(dog))
	var expanded: Array = Player.expand_targetable_entities([p])
	assert_eq(expanded.size(), 2)
	assert_true(expanded.has(veteran))
	assert_true(expanded.has(dog))


func test_one_body_death_is_not_seat_death_and_overflows() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	for i in 8:
		p.hand.append(_make_card("c%d" % i))
	var sized: EquipmentCard = EquipmentCard.new()
	sized.card_name = "M1加兰德步枪"
	sized.english_name = "m1_garand"
	sized.card_type = "equipment"
	sized.source = "game"
	sized.size = 2
	var collar: EquipmentCard = EquipmentCard.new()
	collar.card_name = "狗项圈"
	collar.english_name = "dog_collar"
	collar.card_type = "equipment"
	collar.source = "game"
	collar.size = 0
	assert_true(await p.equip(sized))
	assert_true(await p.equip(collar))
	assert_eq(p.get_equipped_size(), 2)
	var veteran: Variant = p.get_body("veteran_human")
	await veteran.death(null)
	assert_false(veteran.is_alive())
	assert_true(p.is_alive(), "仅老兵死亡不是座位死亡")
	assert_true(p.get_body("dog").is_alive())
	assert_eq(p.get_controller_body(), p.get_body("dog"))
	assert_eq(p.get_hand_size_limit(), 6)
	assert_eq(p.hand.size(), 6, "容量下降后应把手牌弃到上限")
	assert_eq(p.get_equipment_capacity(), 0)
	assert_eq(p.get_equipped_size(), 0, "占格装备应被溢出弃掉")
	var still_has_collar: bool = false
	for e in p.equipment_zone:
		if e != null and str(e.get("english_name")) == "dog_collar":
			still_has_collar = true
	assert_true(still_has_collar, "占 0 格的狗项圈在容量 0 时应保留")


func test_only_dog_alive_keeps_zero_size_gear() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var collar: EquipmentCard = EquipmentCard.new()
	collar.card_name = "狗项圈"
	collar.english_name = "dog_collar"
	collar.card_type = "equipment"
	collar.source = "game"
	collar.size = 0
	assert_true(await p.equip(collar))
	await p.get_body("veteran_human").death(null)
	assert_eq(p.get_equipment_capacity(), 0)
	assert_eq(p.equipment_zone.size(), 1, "仅狗存活时项圈应留下")


func test_both_bodies_dead_kills_seat() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	await p.get_body("veteran_human").death(null)
	assert_true(p.is_alive())
	await p.get_body("dog").death(null)
	assert_false(p.is_alive())


func test_none_range_hits_controller_only() -> void:
	var p: Player = _make_veteran_seat()
	var block: MapBlock = _make_block("营地", 0, 0, true)
	p.current_block = block
	_setup_game_for_player(p)
	Game.map_area = [block]
	var m: Monster = _make_monster("none_range")
	m.range = "none"
	m.attack_target = p
	var targets: Array = m._get_attack_targets()
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], p.get_body("veteran_human"))


func test_non_none_range_hits_both_bodies() -> void:
	var p: Player = _make_veteran_seat()
	var block: MapBlock = _make_block("营地", 0, 0, true)
	p.current_block = block
	_setup_game_for_player(p)
	Game.map_area = [block]
	var m: Monster = _make_monster("short_range")
	m.range = "short"
	m.attack_target = p
	var targets: Array = m._get_attack_targets()
	assert_eq(targets.size(), 2, "非 none 射程应同时打老兵和狗")
	assert_true(targets.has(p.get_body("veteran_human")))
	assert_true(targets.has(p.get_body("dog")))


func test_dog_guard_replaces_veteran() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var veteran: Variant = p.get_body("veteran_human")
	var dog: Variant = p.get_body("dog")
	var m: Monster = _make_monster("none_range")
	var result: Array = await p.try_apply_dog_guard(m, [veteran])
	assert_true(result.has(dog), "狗的守护应把老兵换成狗")
	assert_false(result.has(veteran))


func test_dog_guard_skips_if_dog_already_targeted() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var veteran: Variant = p.get_body("veteran_human")
	var dog: Variant = p.get_body("dog")
	var m: Monster = _make_monster("aoe")
	var original: Array = [veteran, dog]
	var result: Array = await p.try_apply_dog_guard(m, original)
	assert_eq(result.size(), 2)
	assert_true(result.has(veteran))
	assert_true(result.has(dog))


func test_get_target_expands_bodies() -> void:
	var p: Player = _make_veteran_seat()
	var block: MapBlock = _make_block("营地", 0, 0, true)
	p.current_block = block
	_setup_game_for_player(p)
	Game.map_area = [block]
	var targets: Array = Game.get_target(block)
	assert_true(targets.has(p.get_body("veteran_human")))
	assert_true(targets.has(p.get_body("dog")))
	assert_false(targets.has(p), "溅射列表应是身体而不是座位")


func test_fetch_draws_then_discards_scavenge() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	p.in_phase = "action"
	p.action_count = 4
	for i in 3:
		Game.red_scavenge_pile.add(_make_scavenge_card("scrap_%d" % i, "red"))
	var raw: Dictionary = _deck_card_dict("fetch")
	assert_false(raw.is_empty(), "应有取回卡数据")
	var skill_raw: Dictionary = raw.get("skills", [{}])[0]
	var skill: Skill = Game._create_skill_from_data(SkillData.new(skill_raw))
	var event: GameEvent = EventSystem.create_event({"player": p})
	await skill.execute_content(p, event)
	var scav: Array = p.get_cards("", "", 0, "scavenge")
	assert_eq(scav.size(), 1, "抓 3 弃 2 后应剩 1 张拾荒")
	assert_eq(Game.red_scavenge_pile.size(), 0)
	assert_eq(p.action_count, 3)


func test_image_cache_maps_veteran_bodies() -> void:
	assert_not_null(ImageCache.get_role_card_texture("veteran_human", true), "老兵角色牌应映射到 veteran_human")
	assert_not_null(ImageCache.get_role_card_texture("dog", true), "狗角色牌应映射到 dog")
	assert_not_null(ImageCache.get_role_card_texture("veteran", true), "包键 veteran 应指向老兵正面")
	assert_not_null(ImageCache.get_player_avatar("veteran"), "老兵与狗头像应按包 id 缓存")
	assert_not_null(ImageCache.get_card_texture("把它们撕成碎片"), "撕碎片卡名应命中卡图")


func test_ai_treats_own_bodies_as_self() -> void:
	var p: Player = _make_veteran_seat()
	_setup_game_for_player(p)
	var scorer := AiScorer.new()
	assert_eq(scorer.attitude(p, p.get_body("dog")), AiScorer.ATT_SELF)
	assert_eq(scorer.attitude(p, p.get_body("veteran_human")), AiScorer.ATT_SELF)


func test_wiki_has_veteran_and_sub_survivors() -> void:
	var index = WikiIndex.new()
	assert_false(index.get_entry("survivor.veteran").is_empty(), "Wiki 应有老兵与狗包页")
	assert_false(index.get_entry("survivor.veteran.survivor.veteran_human").is_empty(), "Wiki 应有老兵子页")
	assert_false(index.get_entry("survivor.veteran.survivor.dog").is_empty(), "Wiki 应有狗子页")
	assert_false(index.get_entry("survivor.veteran.card.tear_them_apart").is_empty(), "Wiki 应有把它们撕成碎片")
