extends GutTest

## CodeExecutor 单元测试。
## 验证代码字符串编译为 Callable、上下文注入、失败降级。


# === 1. compile_filter ===

func test_compile_filter_simple_true() -> void:
	var cb: Callable = CodeExecutor.compile_filter("return true")
	assert_true(cb.is_valid(), "应返回有效 Callable")
	var result: bool = cb.call(null, null, {}, null)
	assert_true(result)


func test_compile_filter_simple_false() -> void:
	var cb: Callable = CodeExecutor.compile_filter("return false")
	assert_true(cb.is_valid())
	var result: bool = cb.call(null, null, {}, null)
	assert_false(result)


func test_compile_filter_with_player_dict() -> void:
	# player 作为 Dictionary，GDScript 4 支持点号访问 Dictionary 键
	var cb: Callable = CodeExecutor.compile_filter("return player.action_count > 0")
	var player_with_actions: Dictionary = {"action_count": 5}
	var result_true: bool = cb.call(player_with_actions, null, {}, null)
	assert_true(result_true)
	var player_no_actions: Dictionary = {"action_count": 0}
	var result_false: bool = cb.call(player_no_actions, null, {}, null)
	assert_false(result_false)


func test_compile_filter_with_event() -> void:
	var cb: Callable = CodeExecutor.compile_filter("return event.num >= 3")
	var event: Dictionary = {"num": 5}
	assert_true(cb.call(null, null, event, null))
	var event2: Dictionary = {"num": 2}
	assert_false(cb.call(null, null, event2, null))


func test_compile_filter_invalid_code_returns_noop() -> void:
	# 无效代码应降级为 no-op filter（恒返回 true）
	var cb: Callable = CodeExecutor.compile_filter("this is !!! not valid gdscript @@@")
	assert_engine_error_count(1, "无效代码应产生 1 个编译错误")
	assert_true(cb.is_valid(), "降级后应返回有效 Callable")
	var result: bool = cb.call(null, null, {}, null)
	assert_true(result, "no-op filter 应返回 true")


func test_compile_filter_empty_string() -> void:
	var cb: Callable = CodeExecutor.compile_filter("")
	assert_false(cb.is_valid(), "空字符串应返回空 Callable")


# === 2. compile_content ===

func test_compile_content_simple_multiline() -> void:
	var cb: Callable = CodeExecutor.compile_content("var x = 1 + 2\nvar y = x * 3")
	assert_true(cb.is_valid())
	cb.call(null, null, {}, null)  # 不报错即可


func test_compile_content_modify_event() -> void:
	var cb: Callable = CodeExecutor.compile_content("event.num = event.num - 1")
	var event: Dictionary = {"num": 5}
	cb.call(null, null, event, null)
	assert_eq(event["num"], 4, "content 应能修改 event 字典")


func test_compile_content_with_for_loop() -> void:
	# 测试多语句 for 循环（Expression 无法处理，CodeExecutor 可以）
	var cb: Callable = CodeExecutor.compile_content("var sum = 0\nfor i in range(5):\n\tsum += i\nevent.sum = sum")
	var event: Dictionary = {"sum": 0}
	cb.call(null, null, event, null)
	assert_eq(event["sum"], 10, "for 循环应正确执行：0+1+2+3+4=10")


func test_compile_content_with_if_else() -> void:
	var cb: Callable = CodeExecutor.compile_content("if event.num > 3:\n\tevent.result = \"high\"\nelse:\n\tevent.result = \"low\"")
	var event_high: Dictionary = {"num": 5, "result": ""}
	cb.call(null, null, event_high, null)
	assert_eq(event_high["result"], "high")
	var event_low: Dictionary = {"num": 2, "result": ""}
	cb.call(null, null, event_low, null)
	assert_eq(event_low["result"], "low")


func test_compile_content_invalid_code_returns_noop() -> void:
	var cb: Callable = CodeExecutor.compile_content("this is !!! not valid gdscript @@@")
	assert_engine_error_count(1, "无效代码应产生 1 个编译错误")
	assert_true(cb.is_valid(), "降级后应返回有效 Callable")
	# no-op content 不应报错
	cb.call(null, null, {}, null)


func test_compile_content_empty_string() -> void:
	var cb: Callable = CodeExecutor.compile_content("")
	assert_false(cb.is_valid(), "空字符串应返回空 Callable")


# === 3. compile_filter_target ===

func test_compile_filter_target_true_returns_empty() -> void:
	# "true" 应返回空 Callable（无过滤）
	var cb: Callable = CodeExecutor.compile_filter_target("true")
	assert_false(cb.is_valid())


func test_compile_filter_target_empty_returns_empty() -> void:
	var cb: Callable = CodeExecutor.compile_filter_target("")
	assert_false(cb.is_valid())


func test_compile_filter_target_with_target() -> void:
	var cb: Callable = CodeExecutor.compile_filter_target("return target.hp > 0")
	var target_alive: Dictionary = {"hp": 5}
	assert_true(cb.call(null, target_alive, {}, null))
	var target_dead: Dictionary = {"hp": 0}
	assert_false(cb.call(null, target_dead, {}, null))


# === 4. 综合：模拟技能 filter + content ===

func test_skill_filter_and_content_combined() -> void:
	# 模拟"拳打"技能：filter 检查行动阶段 + 行动次数，content 扣行动次数 + 造成伤害
	var filter_code := "return player.in_phase == \"action\" && player.action_count > 0"
	var content_code := "player.action_count -= 1\ntarget.hp -= 2"
	var filter_cb: Callable = CodeExecutor.compile_filter(filter_code)
	var content_cb: Callable = CodeExecutor.compile_content(content_code)
	# player 用 Dictionary 模拟
	var player: Dictionary = {"in_phase": "action", "action_count": 3}
	var target: Dictionary = {"hp": 10}
	var event: Dictionary = {}
	# filter 应通过
	assert_true(filter_cb.call(player, target, event, null))
	# 执行 content
	content_cb.call(player, target, event, null)
	assert_eq(player["action_count"], 2, "行动次数应减 1")
	assert_eq(target["hp"], 8, "目标 hp 应减 2")
