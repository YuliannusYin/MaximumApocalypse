extends GutTest

## DataManager 单元测试。
## 验证 has_survivor / has_mission / 数据加载与查询接口。
## 设计文档：GameDesignDocus/GameSystem/Data/DataManager.md


# === 1. has_survivor ===

func test_has_survivor_true() -> void:
	var all_survivors: Array = DataManager.get_all_survivors()
	if all_survivors.size() > 0:
		var id: Variant = all_survivors[0].english_name
		assert_true(DataManager.has_survivor(id))


func test_has_survivor_false() -> void:
	assert_false(DataManager.has_survivor("non_existent_survivor_id"))


# === 2. has_mission ===

func test_has_mission_true() -> void:
	var all_missions: Array = DataManager.get_all_missions()
	if all_missions.size() > 0:
		var id: Variant = all_missions[0].mission_id
		assert_true(DataManager.has_mission(id))


func test_has_mission_false() -> void:
	assert_false(DataManager.has_mission(99999))


# === 3. 数据加载与查询 ===

func test_get_monster_pack_returns_non_empty() -> void:
	var result: Array = DataManager.get_monster_pack("zombie")
	assert_true(result.size() > 0, "zombie 怪物包应有数据")


func test_get_scavenge_pile_returns_non_empty() -> void:
	var result: Array = DataManager.get_scavenge_pile("red")
	assert_true(result.size() > 0, "red 拾荒牌堆应有数据")


func test_get_map_block_def_returns_data() -> void:
	var result = DataManager.get_map_block_def("gas_station")
	assert_not_null(result, "应找到 gas_station 地图块定义")


func test_get_map_block_def_returns_null_for_unknown() -> void:
	var result = DataManager.get_map_block_def("non_existent_block")
	assert_null(result)


# === 4. 已有方法仍正常 ===

func test_get_all_survivors_not_empty() -> void:
	var result: Array = DataManager.get_all_survivors()
	assert_true(result.size() > 0, "应有求生者数据")


func test_get_all_missions_not_empty() -> void:
	var result: Array = DataManager.get_all_missions()
	assert_true(result.size() > 0, "应有任务数据")


func test_get_all_variants_not_empty() -> void:
	var result: Array = DataManager.get_all_variants()
	assert_true(result.size() > 0, "应有变体数据")


func test_get_all_missions_sorted_by_id() -> void:
	var result: Array = DataManager.get_all_missions()
	for i in range(1, result.size()):
		assert_true(result[i - 1].mission_id < result[i].mission_id, "任务应按 mission_id 排序")


func test_get_all_map_blocks_not_empty() -> void:
	var result: Array = DataManager.get_all_map_blocks()
	assert_true(result.size() > 0, "应有地图块数据")
	assert_not_null(DataManager.get_map_block_def(result[0].english_name))


func test_get_scavenge_pile_colors_ordered() -> void:
	var colors: Array = DataManager.get_scavenge_pile_colors()
	assert_true(colors.has("red"), "应包含红色拾荒堆")
	assert_true(colors.has("green"), "应包含绿色拾荒堆")
	assert_eq(colors[0], "blue", "拾荒颜色应按蓝绿红灰顺序")


func test_get_monster_pack_types_ordered() -> void:
	var types: Array = DataManager.get_monster_pack_types()
	assert_true(types.has("zombie"), "应包含僵尸包")
	assert_eq(types[0], "zombie", "怪物包应按僵尸/外星/突变/机器人顺序")
