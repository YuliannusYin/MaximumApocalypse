extends TestBase

## Mark 系统单元测试。
## 覆盖：
## 1. Mark 类字段与 get_display_text
## 2. Entity mark API（add/remove/count/has/get）
## 3. Collection（items）API
## 4. count 与 items 共存
## 5. add_mark_skill 及 expire_trigger 自动移除
## 6. Monster / EquipmentCard mark 支持
## 7. Player 便捷方法（add_poison / clear_turn_marks）


# === 辅助方法 ===

func _make_test_player(hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = "test"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_monster_with_hp(monster_name: String = "test_monster", hp: int = 20) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = hp
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


func _make_equipment_card(card_name: String = "test_equip") -> EquipmentCard:
	var c: EquipmentCard = EquipmentCard.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "equipment"
	return c


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


# === 1. Mark 类测试 ===

# 测试: 新建 Mark 的默认字段值
func test_mark_default_values() -> void:
	var m: Mark = Mark.new()
	assert_true(m.visible, "默认 visible 应为 true")
	assert_eq(m.count, 0, "默认 count 应为 0")
	assert_eq(m.items.size(), 0, "默认 items 应为空数组")
	assert_eq(m.mark_text, "", "默认 mark_text 应为空字符串")
	assert_eq(m.mark_content, "", "默认 mark_content 应为空字符串")


# 测试: mark_text 非空时 get_display_text 返回 mark_text
func test_mark_get_display_text_with_mark_text() -> void:
	var m: Mark = Mark.new()
	m.mark_text = "中毒"
	assert_eq(m.get_display_text(), "中毒", "mark_text 非空时应返回 mark_text")


# 测试: mark_text 为空时 get_display_text 回退到 name
func test_mark_get_display_text_empty_fallback() -> void:
	var m: Mark = Mark.new()
	m.name = "poison"
	assert_eq(m.get_display_text(), "poison", "mark_text 为空时应回退到 name")


# === 2. Entity mark API 测试 ===

# 测试: add_mark 创建标记并设置计数
func test_add_mark_creates_mark() -> void:
	var p: Player = _make_test_player()
	p.add_mark("poison", 2, "中毒", "desc")
	assert_true(p.has_mark("poison"), "应存在 poison 标记")
	assert_eq(p.count_mark("poison"), 2, "poison 计数应为 2")


# 测试: 多次 add_mark 累加计数
func test_add_mark_increments_count() -> void:
	var p: Player = _make_test_player()
	p.add_mark("poison", 1)
	p.add_mark("poison", 2)
	assert_eq(p.count_mark("poison"), 3, "两次 add_mark 后计数应累加为 3")


# 测试: 对已存在的 mark 调用 add_mark 更新元数据
func test_add_mark_updates_metadata_on_existing() -> void:
	var p: Player = _make_test_player()
	p.add_mark("x", 1, "A", "a")
	p.add_mark("x", 1, "B", "b")
	assert_eq(p.count_mark("x"), 2, "计数应累加为 2")
	assert_eq(p.get_mark("x").mark_text, "B", "mark_text 应更新为 B")


# 测试: add_mark 不传 mark_text 时默认用 name
func test_add_mark_empty_text_defaults_to_name() -> void:
	var p: Player = _make_test_player()
	p.add_mark("internal")
	assert_eq(p.get_mark("internal").mark_text, "internal", "mark_text 为空时应默认为 name")


# 测试: remove_mark 移除标记
func test_remove_mark() -> void:
	var p: Player = _make_test_player()
	p.add_mark("poison", 1)
	p.remove_mark("poison")
	assert_false(p.has_mark("poison"), "移除后应不存在 poison 标记")
	assert_eq(p.count_mark("poison"), 0, "移除后计数应为 0")


# 测试: 不存在的标记 count_mark 返回 0
func test_count_mark_nonexistent() -> void:
	var p: Player = _make_test_player()
	assert_eq(p.count_mark("nope"), 0, "不存在的标记计数应为 0")


# 测试: 不存在的标记 has_mark 返回 false
func test_has_mark_nonexistent() -> void:
	var p: Player = _make_test_player()
	assert_false(p.has_mark("nope"), "不存在的标记 has_mark 应为 false")


# 测试: 不存在的标记 get_mark 返回 null
func test_get_mark_nonexistent() -> void:
	var p: Player = _make_test_player()
	assert_null(p.get_mark("nope"), "不存在的标记 get_mark 应返回 null")


# 测试: get_mark 返回 Mark 对象及其字段
func test_get_mark_returns_mark_object() -> void:
	var p: Player = _make_test_player()
	p.add_mark("x", 3)
	var m: Mark = p.get_mark("x")
	assert_not_null(m, "get_mark 应返回 Mark 对象")
	assert_eq(m.count, 3, "Mark 对象的 count 应为 3")


# === 3. Collection（items）测试 ===

# 测试: add_mark_item 添加元素到 items 集合，不影响 count
func test_add_mark_item() -> void:
	var p: Player = _make_test_player()
	p.add_mark_item("tags", "fire")
	var items: Array = p.get_mark_items("tags")
	assert_true(items.has("fire"), "items 应包含 fire")
	assert_eq(p.count_mark("tags"), 0, "add_mark_item 不应增加 count")


# 测试: 多次 add_mark_item 添加多个元素
func test_add_mark_item_multiple() -> void:
	var p: Player = _make_test_player()
	p.add_mark_item("tags", "fire")
	p.add_mark_item("tags", "ice")
	var items: Array = p.get_mark_items("tags")
	assert_eq(items.size(), 2, "添加两个 item 后 items 大小应为 2")


# 测试: remove_mark_item 从 items 移除元素
func test_remove_mark_item() -> void:
	var p: Player = _make_test_player()
	p.add_mark_item("tags", "fire")
	p.remove_mark_item("tags", "fire")
	assert_eq(p.get_mark_items("tags").size(), 0, "移除 item 后 items 应为空")


# 测试: 不存在的标记 get_mark_items 返回空数组
func test_get_mark_items_nonexistent() -> void:
	var p: Player = _make_test_player()
	assert_eq(p.get_mark_items("nope").size(), 0, "不存在的标记 get_mark_items 应返回空数组")


# 测试: clear_mark_items 清空 items 但保留标记
func test_clear_mark_items() -> void:
	var p: Player = _make_test_player()
	p.add_mark_item("tags", "fire")
	p.add_mark_item("tags", "ice")
	p.clear_mark_items("tags")
	assert_eq(p.get_mark_items("tags").size(), 0, "清空后 items 应为空")
	assert_true(p.has_mark("tags"), "清空 items 后标记应仍存在")


# === 4. count 与 items 共存 ===

# 测试: count 和 items 可同时存在于同一标记
func test_count_and_items_coexist() -> void:
	var p: Player = _make_test_player()
	p.add_mark("x", 5, "X", "desc")
	p.add_mark_item("x", "item")
	assert_eq(p.count_mark("x"), 5, "count 应为 5")
	var items: Array = p.get_mark_items("x")
	assert_eq(items.size(), 1, "items 应有 1 个元素")
	assert_true(items.has("item"), "items 应包含 item")


# 测试: clear_mark_count 清零 count 但保留标记和 items
func test_clear_mark_count() -> void:
	var p: Player = _make_test_player()
	p.add_mark("x", 5)
	p.add_mark_item("x", "item1")
	p.clear_mark_count("x")
	assert_eq(p.count_mark("x"), 0, "清零后 count 应为 0")
	assert_true(p.has_mark("x"), "清零 count 后标记应仍存在")
	assert_eq(p.get_mark_items("x").size(), 1, "清零 count 不应影响 items")


# === 5. add_mark_skill 测试 ===

# 测试: add_mark_skill 不带 expire_trigger 时仅添加标记
func test_add_mark_skill_no_expire() -> void:
	var p: Player = _make_test_player()
	p.add_mark_skill("poison", 1, "", "中毒", "desc")
	assert_true(p.has_mark("poison"), "应存在 poison 标记")
	assert_eq(p.count_mark("poison"), 1, "poison 计数应为 1")


# 测试: has_mark_skill 等价于 has_mark
func test_has_mark_skill() -> void:
	var p: Player = _make_test_player()
	p.add_mark("poison", 1)
	assert_true(p.has_mark_skill("poison"), "has_mark_skill 应等价于 has_mark 返回 true")


# 测试: add_mark_skill 带 expire_trigger，触发后自动移除标记
func test_add_mark_skill_with_expire_trigger() -> void:
	var p: Player = _make_test_player()
	_setup_game_for_player(p)
	p.add_mark_skill("temp", 1, "turn_end", "T", "desc")
	assert_true(p.has_mark("temp"), "添加后应存在 temp 标记")
	await p.trigger("turn_end", EventSystem.create_event({}))
	assert_false(p.has_mark("temp"), "触发 turn_end 后 temp 标记应被移除")


# === 6. Monster 和 EquipmentCard mark 测试 ===

# 测试: Monster 可持有标记
func test_monster_can_have_mark() -> void:
	var m: Monster = _make_monster_with_hp()
	m.add_mark("stunned", 1, "眩晕", "skip")
	assert_true(m.has_mark("stunned"), "怪物应能持有标记")


# 测试: EquipmentCard 可持有标记
func test_equipment_card_can_have_mark() -> void:
	var c: EquipmentCard = _make_equipment_card()
	c.add_mark("upgrade", 1, "升级", "+1 dmg")
	assert_true(c.has_mark("upgrade"), "装备牌应能持有标记")


# === 7. Player 便捷方法 ===

# 测试: add_poison 添加中毒标记，mark_text 为"中毒"
func test_add_poison() -> void:
	var p: Player = _make_test_player()
	p.add_poison(2)
	assert_eq(p.count_mark("poison"), 2, "add_poison(2) 后计数应为 2")
	assert_eq(p.get_mark("poison").mark_text, "中毒", "mark_text 应为 中毒")


# 测试: 多次 add_poison 累加计数，mark_content 包含累加后总数
func test_add_poison_accumulates() -> void:
	var p: Player = _make_test_player()
	p.add_poison(2)
	p.add_poison(1)
	assert_eq(p.count_mark("poison"), 3, "两次 add_poison 后计数应为 3")
	var content: String = p.get_mark("poison").mark_content
	assert_true(content.contains("3"), "mark_content 应包含累加后的总数 3")


# 测试: clear_turn_marks 移除回合临时标记
func test_clear_turn_marks() -> void:
	var p: Player = _make_test_player()
	p.add_mark("moved_this_turn", 1, "", "", false)
	p.add_mark("shelter_disabled", 1, "避难所", "desc")
	p.clear_turn_marks()
	assert_false(p.has_mark("moved_this_turn"), "clear_turn_marks 应移除 moved_this_turn")
	assert_false(p.has_mark("shelter_disabled"), "clear_turn_marks 应移除 shelter_disabled")
