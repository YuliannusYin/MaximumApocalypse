extends GutTest

## 验证修复 complex_target 卡牌崩溃。
## 3 张曾用 complex_target + target1/target2 的卡牌 content 现应可被
## CodeExecutor.compile_content 编译，无 "Identifier 'target1' not declared" 等 Parser Error。
## 修复 spec：.trae/specs/fix-complex-target-crash/spec.md


# 从指定求生者的牌堆中收集所有非空 content 字符串并编译，返回 [{card, callable}, ...]。
func _compile_deck_contents(survivor_english_name: String) -> Array:
	var survivor: SurvivorData = DataManager.get_survivor(survivor_english_name)
	assert_not_null(survivor, "%s 求生者应存在" % survivor_english_name)
	var results: Array = []
	for card_dict in survivor.deck:
		var card_name: String = card_dict.get("english_name", "")
		var raw_skills: Array = card_dict.get("skills", [])
		for raw in raw_skills:
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			if content.strip_edges().is_empty():
				continue
			var cb: Callable = CodeExecutor.compile_content(content)
			results.append({"card": card_name, "callable": cb})
	return results


# === 1. 枪手「集中射击」content 编译 ===

func test_gunslinger_focused_shot_compiles_without_error() -> void:
	var survivor: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(survivor, "枪手应存在")
	var found: bool = false
	for card_dict in survivor.deck:
		if card_dict.get("english_name", "") != "focused_shot":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "集中射击 content 应编译为有效 Callable")
			# 关键断言：曾用 target1/target2 触发 Parser Error，修复后应为 0
			assert_engine_error_count(0, "集中射击 content 编译应无 Parser Error（target1/target2 已 var 声明）")
			# 失效字段应已删除
			assert_false(raw.has("complex_target"), "集中射击应删除 complex_target 字段")
			assert_false(raw.has("filter_target_1"), "集中射击应删除 filter_target_1 字段")
			assert_false(raw.has("filter_target_2"), "集中射击应删除 filter_target_2 字段")
			assert_false(raw.has("filter_target_2_range"), "集中射击应删除 filter_target_2_range 字段")
	assert_true(found, "应在枪手牌堆中找到 focused_shot 卡牌")


# === 2. 机械师「启动汽车」content 编译 ===

func test_mechanic_start_car_compiles_without_error() -> void:
	var survivor: SurvivorData = DataManager.get_survivor("mechanic")
	assert_not_null(survivor, "机械师应存在")
	var found: bool = false
	for card_dict in survivor.deck:
		if card_dict.get("english_name", "") != "start_car":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "启动汽车 content 应编译为有效 Callable")
			assert_engine_error_count(0, "启动汽车 content 编译应无 Parser Error")
			assert_false(raw.has("complex_target"), "启动汽车应删除 complex_target 字段")
			assert_false(raw.has("filter_target_1"), "启动汽车应删除 filter_target_1 字段")
			assert_false(raw.has("filter_target_1_range"), "启动汽车应删除 filter_target_1_range 字段")
			assert_false(raw.has("filter_target_2"), "启动汽车应删除 filter_target_2 字段")
			assert_false(raw.has("filter_target_2_range"), "启动汽车应删除 filter_target_2_range 字段")
	assert_true(found, "应在机械师牌堆中找到 start_car 卡牌")


# === 3. 机械师「阅读使用说明」content 编译 ===

func test_mechanic_read_manual_compiles_without_error() -> void:
	var survivor: SurvivorData = DataManager.get_survivor("mechanic")
	assert_not_null(survivor, "机械师应存在")
	var found: bool = false
	for card_dict in survivor.deck:
		if card_dict.get("english_name", "") != "read_manual":
			continue
		found = true
		for raw in card_dict.get("skills", []):
			if not (raw is Dictionary):
				continue
			var content: String = raw.get("content", "")
			var cb: Callable = CodeExecutor.compile_content(content)
			assert_true(cb.is_valid(), "阅读使用说明 content 应编译为有效 Callable")
			assert_engine_error_count(0, "阅读使用说明 content 编译应无 Parser Error")
			assert_false(raw.has("complex_target"), "阅读使用说明应删除 complex_target 字段")
			assert_false(raw.has("filter_target_1"), "阅读使用说明应删除 filter_target_1 字段")
			assert_false(raw.has("filter_target_2"), "阅读使用说明应删除 filter_target_2 字段")
			assert_false(raw.has("filter_target_2_range"), "阅读使用说明应删除 filter_target_2_range 字段")
	assert_true(found, "应在机械师牌堆中找到 read_manual 卡牌")


# === 4. 全牌堆编译（模拟进入游戏编译牌堆的场景）===

func test_gunslinger_full_deck_compiles_without_error() -> void:
	var results: Array = _compile_deck_contents("gunslinger")
	assert_gt(results.size(), 0, "枪手牌堆应有可编译的 content")
	# 整副牌堆编译后累计应无任何 Parser Error
	assert_engine_error_count(0, "枪手整副牌堆 content 编译应无 Parser Error")
	for r in results:
		assert_true(r["callable"].is_valid(), "%s 的 content 应编译为有效 Callable" % r["card"])


func test_mechanic_full_deck_compiles_without_error() -> void:
	var results: Array = _compile_deck_contents("mechanic")
	assert_gt(results.size(), 0, "机械师牌堆应有可编译的 content")
	assert_engine_error_count(0, "机械师整副牌堆 content 编译应无 Parser Error")
	for r in results:
		assert_true(r["callable"].is_valid(), "%s 的 content 应编译为有效 Callable" % r["card"])
