extends GutTest

## DataManager 单元测试。
## 验证 has_survivor / has_mission / stub 方法返回 null + 不崩溃。
## 设计文档：GameDesignDocus/GameSystem/Data/DataManager.md


# === 1. has_survivor ===

func test_has_survivor_true() -> void:
	# Survivors 静态数据中应有 ID（如 "university_student" 等）
	var all_survivors: Array = DataManager.get_all_survivors()
	if all_survivors.size() > 0:
		var id: Variant = all_survivors[0].id
		assert_true(DataManager.has_survivor(id))


func test_has_survivor_false() -> void:
	assert_false(DataManager.has_survivor("non_existent_survivor_id"))


# === 2. has_mission ===

func test_has_mission_true() -> void:
	var all_missions: Array = DataManager.get_all_missions()
	if all_missions.size() > 0:
		var id: Variant = all_missions[0].id
		assert_true(DataManager.has_mission(id))


func test_has_mission_false() -> void:
	assert_false(DataManager.has_mission(99999))


# === 3. stub 方法返回 null ===

func test_get_monster_card_stub_returns_null() -> void:
	var result: Resource = DataManager.get_monster_card("zombie")
	assert_null(result)


func test_get_scavenge_card_stub_returns_null() -> void:
	var result: Resource = DataManager.get_scavenge_card("bandage")
	assert_null(result)


func test_get_map_block_def_stub_returns_null() -> void:
	var result: Resource = DataManager.get_map_block_def("gas_station")
	assert_null(result)


func test_get_mission_pack_stub_returns_null() -> void:
	var result: Resource = DataManager.get_mission_pack(1)
	assert_null(result)


# === 4. 已有方法仍正常 ===

func test_get_all_survivors_not_empty() -> void:
	var result: Array = DataManager.get_all_survivors()
	assert_true(result.size() > 0, "应有求生者数据")
