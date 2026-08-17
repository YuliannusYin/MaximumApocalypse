extends GutTest

## "精炼固有技能与装备技能"修复单元测试。
## 覆盖 spec: .trae/specs/refine-intrinsic-and-equipment-skills/spec.md
##   7.1  start_game 流程顺序：on_game_start 在 draw(4) 之前（行序断言）
##   7.2  horse_move content 编译无 Parser Error
##   7.3  horse_move 第一步取消：不消耗行动
##   7.4  horse_move 第一步成功：消耗 1 行动并移动
##   7.5  motorcycle 第一步取消：不消耗行动与燃料
##   7.6  motorcycle 第一步成功：消耗 1 行动与 1 燃料
##   7.7  ranger_hat 装备触发 recover(3)
##   7.8  backpack 装备触发 equipment_capacity +1
##   7.9  camouflage 装备触发 sneak +2
##   7.10 survivors/ 全目录无残留 on_card_enter/leave_equipment


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
	b.revealed = true
	return b


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


## 单玩家场景下初始化 Game 单例（与 test_pull_trigger_happy_fix.gd 保持一致）。
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


## 在玩家已挂载技能中按 english_name 查找 Skill（用于装备 active 技能触发）。
func _find_skill_by_english_name(p: Player, en_name: String) -> Skill:
	for s in p.get_all_skills():
		if s.english_name == en_name:
			return s
	return null


# === SubTask 7.1: start_game 流程顺序 — on_game_start 在 draw(4) 之前 ===

# 读取 game_state_machine.gd 源码，断言 `trigger("on_game_start"` 所在行号
# 小于 `draw(4)` 所在行号（行序断言 Approach B）。
# 这证明 on_game_start 触发器在抓初始手牌之前执行（quick_draw 先于 draw(4)）。
func test_start_game_on_game_start_before_draw_4() -> void:
	var path: String = "res://src/core/game_state_machine.gd"
	var content: String = FileAccess.get_file_as_string(path)
	assert_false(content.is_empty(), "应能读取 game_state_machine.gd")
	var lines: PackedStringArray = content.split("\n")
	var on_game_start_line: int = -1
	var draw_4_line: int = -1
	for i in range(lines.size()):
		var line: String = lines[i]
		if on_game_start_line < 0 and line.contains("trigger(\"on_game_start\""):
			on_game_start_line = i
		if draw_4_line < 0 and line.contains("draw(4)"):
			draw_4_line = i
	assert_true(on_game_start_line >= 0, "应找到 trigger(\"on_game_start\") 行")
	assert_true(draw_4_line >= 0, "应找到 draw(4) 行")
	assert_true(
		on_game_start_line < draw_4_line,
		"on_game_start 触发应在 draw(4) 之前（行 %d < 行 %d）" % [on_game_start_line, draw_4_line]
	)


# === SubTask 7.2: horse_move content 编译无 Parser Error ===

# 加载 gunslinger.json horse 卡牌的 horse_move 技能 content，
# 通过 CodeExecutor.compile_content 编译为 Callable 并断言无 Parser Error。
func test_horse_move_content_compiles_without_error() -> void:
	var card_dict: Dictionary = _get_card_dict_by_english_name("gunslinger", "horse")
	assert_false(card_dict.is_empty(), "应找到 horse 卡牌")
	var found_horse_move: bool = false
	for raw in card_dict.get("skills", []):
		if not (raw is Dictionary):
			continue
		if raw.get("english_name", "") != "horse_move":
			continue
		found_horse_move = true
		var content_str: String = raw.get("content", "")
		assert_false(content_str.is_empty(), "horse_move content 不应为空")
		var cb: Callable = CodeExecutor.compile_content(content_str)
		assert_true(cb.is_valid(), "horse_move content 应编译为有效 Callable")
		assert_engine_error_count(0, "horse_move content 编译应无 Parser Error")
	assert_true(found_horse_move, "应在 horse 卡牌中找到 horse_move 技能")


# === SubTask 7.3: horse_move 第一步取消 ===

# 玩家 A（action_count=2, in_phase="action"）装备马，位于中心块（有相邻块）；
# 触发 horse_move 主动技能，第一步 choose_block_inline 返回空（取消）：
# content 中 steps==0 → EventSystem.cancel(event); return，
# use_active_skill 检测到取消不记录使用，action_count 不变。
func test_horse_move_first_step_cancel_no_consume() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_player(p)
	p.action_count = 2
	p.in_phase = "action"
	# 构建地图：中心块 + 北侧相邻块（medium 射程含 distance 0/1）
	# 构建地图：中心块 + 北/南/东侧相邻块。
	# 注意：player.choose_block_inline 在 count >= valid_blocks.size() 时会短路
	# 自动返回全部候选（不查询 input 队列）。因此需保证每步 valid_blocks.size() >= 2，
	# 使 mock 的 queue_choose_block([]) 能被消费，从而正确模拟"取消"。
	var center: MapBlock = _make_block("center", 1, 1)
	var north: MapBlock = _make_block("north", 1, 0)
	var south: MapBlock = _make_block("south", 1, 2)
	var east: MapBlock = _make_block("east", 2, 0)
	Game.map_area = [center, north, south, east]
	p.current_block = center
	# 装备马（horse 卡牌含 horse_move + horse_discard 两个 active 技能）
	var horse_card: Card = _make_card_by_english_name("gunslinger", "horse")
	p.hand.append(horse_card)
	await p.equip(horse_card)
	var skill: Skill = _find_skill_by_english_name(p, "horse_move")
	assert_not_null(skill, "装备马后应挂载 horse_move 技能")
	# mock input：第一步取消（空数组）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([])
	p.input = cli
	await p.use_active_skill(skill)
	assert_eq(p.action_count, 2, "第一步取消不应消耗行动次数")


# === SubTask 7.4: horse_move 第一步成功 ===

# 玩家 A（action_count=2）装备马，位于中心块；
# 第一步 choose_block_inline 返回北侧相邻块（成功），第二步返回空（取消）：
# 第一步 steps==0 → consume_action(1)，随后 move_to(north)；
# 第二步 target==null 且 steps!=0 → break。
# 断言：action_count==1（消耗 1），玩家已移动至 north。
func test_horse_move_first_step_success_consumes_action() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_player(p)
	p.action_count = 2
	p.in_phase = "action"
	# 构建地图：中心块 + 北侧相邻块
	# 构建地图：中心块 + 北/南/东侧相邻块。
	# 注意：player.choose_block_inline 在 count >= valid_blocks.size() 时会短路
	# 自动返回全部候选（不查询 input 队列）。因此需保证每步 valid_blocks.size() >= 2，
	# 使 mock 的 queue_choose_block([]) 能被消费，从而正确模拟"取消"。
	var center: MapBlock = _make_block("center", 1, 1)
	var north: MapBlock = _make_block("north", 1, 0)
	var south: MapBlock = _make_block("south", 1, 2)
	var east: MapBlock = _make_block("east", 2, 0)
	Game.map_area = [center, north, south, east]
	p.current_block = center
	# 装备马
	var horse_card: Card = _make_card_by_english_name("gunslinger", "horse")
	p.hand.append(horse_card)
	await p.equip(horse_card)
	var skill: Skill = _find_skill_by_english_name(p, "horse_move")
	assert_not_null(skill, "装备马后应挂载 horse_move 技能")
	# mock input：第一步选 north，第二步取消
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([north])
	cli.queue_choose_block([])
	p.input = cli
	await p.use_active_skill(skill)
	assert_eq(p.action_count, 1, "第一步成功应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(p.current_block, north, "应已移动至 north")


# === SubTask 7.5: motorcycle 第一步取消 ===

# 玩家 A（action_count=2, motorcycle charge=2）触发 motorcycle 主动技能，
# 第一步 choose_block_inline 返回空（取消）：
# content 中 steps==0 → EventSystem.cancel(event); return，
# action_count 与 charge 均不变。
func test_motorcycle_first_step_cancel_no_consume() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_player(p)
	p.action_count = 2
	p.in_phase = "action"
	# 构建地图：中心块 + 北侧相邻块
	# 构建地图：中心块 + 北/南/东侧相邻块。
	# 注意：player.choose_block_inline 在 count >= valid_blocks.size() 时会短路
	# 自动返回全部候选（不查询 input 队列）。因此需保证每步 valid_blocks.size() >= 2，
	# 使 mock 的 queue_choose_block([]) 能被消费，从而正确模拟"取消"。
	var center: MapBlock = _make_block("center", 1, 1)
	var north: MapBlock = _make_block("north", 1, 0)
	var south: MapBlock = _make_block("south", 1, 2)
	var east: MapBlock = _make_block("east", 2, 0)
	Game.map_area = [center, north, south, east]
	p.current_block = center
	# 装备摩托车（charge_type="fuel", charge_max=2, charge_initial=2）
	var motorcycle_card: Card = _make_card_by_english_name("hunter", "motorcycle")
	p.hand.append(motorcycle_card)
	await p.equip(motorcycle_card)
	assert_eq(p.get_charge_count("motorcycle"), 2, "摩托车初始燃料应为 2")
	var skill: Skill = _find_skill_by_english_name(p, "motorcycle")
	assert_not_null(skill, "装备摩托车后应挂载 motorcycle 技能")
	# mock input：第一步取消
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([])
	p.input = cli
	await p.use_active_skill(skill)
	assert_eq(p.action_count, 2, "第一步取消不应消耗行动次数")
	assert_eq(p.get_charge_count("motorcycle"), 2, "第一步取消不应消耗燃料")


# === SubTask 7.6: motorcycle 第一步成功 ===

# 玩家 A（action_count=2, motorcycle charge=2）触发 motorcycle 主动技能，
# 第一步选北侧相邻块（成功），第二步取消：
# 第一步 steps==0 → consume_action(1) + consume_charge(motorcycle, 1)；
# 第二步 target==null 且 steps!=0 → break。
# 断言：action_count==1, charge==1。
func test_motorcycle_first_step_success_consumes_action_and_charge() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_player(p)
	p.action_count = 2
	p.in_phase = "action"
	# 构建地图：中心块 + 北侧相邻块
	# 构建地图：中心块 + 北/南/东侧相邻块。
	# 注意：player.choose_block_inline 在 count >= valid_blocks.size() 时会短路
	# 自动返回全部候选（不查询 input 队列）。因此需保证每步 valid_blocks.size() >= 2，
	# 使 mock 的 queue_choose_block([]) 能被消费，从而正确模拟"取消"。
	var center: MapBlock = _make_block("center", 1, 1)
	var north: MapBlock = _make_block("north", 1, 0)
	var south: MapBlock = _make_block("south", 1, 2)
	var east: MapBlock = _make_block("east", 2, 0)
	Game.map_area = [center, north, south, east]
	p.current_block = center
	# 装备摩托车
	var motorcycle_card: Card = _make_card_by_english_name("hunter", "motorcycle")
	p.hand.append(motorcycle_card)
	await p.equip(motorcycle_card)
	var skill: Skill = _find_skill_by_english_name(p, "motorcycle")
	assert_not_null(skill, "装备摩托车后应挂载 motorcycle 技能")
	# mock input：第一步选 north，第二步取消
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([north])
	cli.queue_choose_block([])
	p.input = cli
	await p.use_active_skill(skill)
	assert_eq(p.action_count, 1, "第一步成功应消耗 1 点行动（2 - 1 = 1）")
	assert_eq(p.get_charge_count("motorcycle"), 1, "第一步成功应消耗 1 点燃料（2 - 1 = 1）")


# === SubTask 7.7: ranger_hat 装备触发 recover(3) ===

# 玩家 A（hp=10, max_hp=20）装备游侠帽：
# ranger_hat 技能 trigger=on_equip、on_unequip，content 中 on_equip 分支调用 player.recover(3)。
# 修复前 trigger 名不匹配导致不触发；修复后应正确触发 recover(3)。
# 断言：A.hp == 13（10 + 3 = 13）。
func test_ranger_hat_equip_triggers_recover() -> void:
	var p: Player = _make_player("玩家A", 10, 20)
	_setup_game_for_player(p)
	var ranger_hat_card: Card = _make_card_by_english_name("gunslinger", "ranger_hat")
	p.hand.append(ranger_hat_card)
	await p.equip(ranger_hat_card)
	assert_eq(p.hp, 13, "装备游侠帽应回复 3 点生命值（10 + 3 = 13）")


# === SubTask 7.8: backpack 装备触发 equipment_capacity +1 ===

# 玩家 A（role_card.equipment_capacity=4）装备背包：
# backpack 技能 trigger=on_equip、on_unequip，content 中 on_equip 分支调用
# player.increase_equipment_slot(1)（修改 role_card.equipment_capacity）。
# 断言：role_card.equipment_capacity == 5（4 + 1 = 5）。
func test_backpack_equip_increases_equipment_capacity() -> void:
	var p: Player = _make_player("玩家A")
	p.role_card = RoleCard.new()
	p.role_card.equipment_capacity = 4
	_setup_game_for_player(p)
	var backpack_card: Card = _make_card_by_english_name("hunter", "backpack")
	p.hand.append(backpack_card)
	var before: int = p.role_card.equipment_capacity
	await p.equip(backpack_card)
	assert_eq(p.role_card.equipment_capacity, before + 1, "装备背包后装备栏容量应 +1（4 + 1 = 5）")


# === SubTask 7.9: camouflage 装备触发 sneak +2 ===

# 玩家 A（初始潜行值 sneak_before）装备迷彩服：
# camouflage_stealth 技能 trigger=on_equip、on_unequip，content 中 on_equip 分支调用
# player.add_sneak(2)（修改 stealth 字段）。
# 断言：get_sneak() == sneak_before + 2。
func test_camouflage_equip_triggers_sneak_plus_2() -> void:
	var p: Player = _make_player("玩家A")
	_setup_game_for_player(p)
	var sneak_before: int = p.get_sneak()
	var camouflage_card: Card = _make_card_by_english_name("hunter", "camouflage")
	p.hand.append(camouflage_card)
	await p.equip(camouflage_card)
	assert_eq(p.get_sneak(), sneak_before + 2, "装备迷彩服后潜行值应 +2")


# === SubTask 7.10: survivors/ 全目录无残留 on_card_enter/leave_equipment ===

# 遍历 res://data/survivors/ 下所有 .json 文件，逐文件读取内容并断言：
# 不包含 `on_card_enter_equipment` 或 `on_card_leave_equipment` 子串。
# 共应遍历 6 个文件（firefighter / gunslinger / hunter / mechanic / surgeon / veteran）。
func test_no_residual_on_card_enter_leave_equipment_in_survivors() -> void:
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
				content.contains("on_card_enter_equipment"),
				fname + " 不应含 on_card_enter_equipment"
			)
			assert_false(
				content.contains("on_card_leave_equipment"),
				fname + " 不应含 on_card_leave_equipment"
			)
		fname = dir.get_next()
	dir.list_dir_end()
	for expected in expected_files:
		assert_true(found_files.has(expected), "应遍历到 survivor 文件: " + expected)
	assert_eq(found_files.size(), 6, "应共遍历到 6 个 survivor 文件")
