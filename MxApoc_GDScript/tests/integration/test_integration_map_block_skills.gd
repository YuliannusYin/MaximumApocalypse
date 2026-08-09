extends GutTest

## 集成测试：地图块技能端到端。
## 覆盖电厂/百货商店/森林/河流/避难所地块技能的真实 JSON 加载与触发全链路。
## 设计文档：GameDesignDocus/GameSystem/Entities/MapBlock.md


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.role_card = RoleCard.new()
	return p


func _make_block(name: String = "B", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	b.revealed = true
	return b


func _make_scavenge_card(name: String = "test_scavenge", color: String = "green") -> ScavengeCard:
	var c: ScavengeCard = ScavengeCard.new()
	c.card_name = name
	c.card_type = "item"
	c.source = "scavenge"
	c.color = color
	c.scavenge_type = "consumable"
	return c


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
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 测试用例 ===

## 测试 1: 电厂 on_enter_block 触发中毒
func test_enter_power_plant_triggers_poison() -> void:
	var p: Player = _make_player("A")
	var start: MapBlock = _make_block("城市街道", 0, 0)
	var power_plant: MapBlock = Game._create_map_block("电厂")
	power_plant.set_coordinate(1, 0)
	start.revealed = true
	power_plant.revealed = true
	p.current_block = start
	Game.players = [p]
	Game.map_area = [start, power_plant]
	var result: bool = await p.move_to(power_plant)
	assert_true(result, "移动应成功")
	assert_true(p.has_mark("poison"), "电厂 on_enter_block 应添加中毒标记")


## 测试 2: 百货商店 on_reveal_block 触发免费拾荒
func test_reveal_department_store_triggers_free_scavenge() -> void:
	var p: Player = _make_player("A")
	var store: MapBlock = Game._create_map_block("百货商店")
	store.set_coordinate(0, 0)
	store.revealed = false
	# 准备绿色拾荒牌堆
	Game.green_scavenge_pile = Pile.new()
	var sc: ScavengeCard = _make_scavenge_card("bandage", "green")
	Game.green_scavenge_pile.add(sc)
	p.current_block = store
	store._acquire_skills_for_player(p)
	Game.players = [p]
	Game.map_area = [store]
	var hand_before: int = p.hand.size()
	await store.reveal(true, p)
	assert_eq(p.hand.size(), hand_before + 1, "百货商店 on_reveal_block 应抓 1 张拾荒牌")


## 测试 3: 离开地块时清除地块技能
func test_leave_block_clears_skills() -> void:
	var p: Player = _make_player("A")
	var start: MapBlock = _make_block("起点", 0, 0)
	var forest: MapBlock = Game._create_map_block("森林")
	forest.set_coordinate(1, 0)
	var other: MapBlock = _make_block("空地", 2, 0)
	start.revealed = true
	forest.revealed = true
	other.revealed = true
	p.current_block = start
	Game.players = [p]
	Game.map_area = [start, forest, other]
	# 移动到森林 → 森林技能挂载
	await p.move_to(forest)
	var has_forest_skill: bool = false
	for s in p.skills:
		if s.english_name == "forest":
			has_forest_skill = true
			break
	assert_true(has_forest_skill, "进入森林后应挂载森林技能")
	# 移动到另一个地块 → 森林技能移除
	await p.move_to(other)
	var still_has_forest: bool = false
	for s in p.skills:
		if s.english_name == "forest":
			still_has_forest = true
			break
	assert_false(still_has_forest, "离开森林后应移除森林技能")


## 测试 4: 河流 before_enter_block 潜行失败取消移动
func test_river_cancel_before_enter() -> void:
	var p: Player = _make_player("A")
	p.stealth = -100
	var start: MapBlock = _make_block("城市街道", 0, 0)
	var river: MapBlock = Game._create_map_block("河流")
	river.set_coordinate(1, 0)
	start.revealed = true
	river.revealed = true
	p.current_block = start
	Game.players = [p]
	Game.map_area = [start, river]
	var result: bool = await p.move_to(river)
	assert_false(result, "潜行失败时移动应被取消")
	assert_eq(p.current_block, start, "玩家应仍在起始地块")


## 测试 5: 避难所 on_turn_start 添加 shelter_disabled 标记
func test_shelter_turn_start_adds_disabled_mark() -> void:
	var p: Player = _make_player("A")
	var start: MapBlock = _make_block("城市街道", 0, 0)
	var shelter: MapBlock = Game._create_map_block("避难所")
	shelter.set_coordinate(1, 0)
	start.revealed = true
	shelter.revealed = true
	p.current_block = start
	Game.players = [p]
	Game.map_area = [start, shelter]
	await p.move_to(shelter)
	# 手动触发 on_turn_start
	var event: Dictionary = EventSystem.create_event({"player": p})
	await p.trigger("on_turn_start", event)
	assert_true(p.has_mark_skill("shelter_disabled"), "避难所 on_turn_start 应添加 shelter_disabled 标记")


## 测试 6: 避难所免疫伤害（未在此开始回合时）
func test_shelter_immune_damage_when_not_started_here() -> void:
	var p: Player = _make_player("A", 10)
	var shelter: MapBlock = Game._create_map_block("避难所")
	shelter.set_coordinate(0, 0)
	shelter.revealed = true
	p.current_block = shelter
	# 手动挂载避难所技能（不走 move_to，确保没有 on_turn_start 触发的 disabled 标记）
	shelter._acquire_skills_for_player(p)
	Game.players = [p]
	Game.map_area = [shelter]
	p.hp = 10
	await p.damage(5, null)
	assert_eq(p.hp, 10, "避难所应免疫伤害（on_take_damage 被 cancel）")
