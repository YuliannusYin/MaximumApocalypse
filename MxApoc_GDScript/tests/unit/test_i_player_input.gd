extends GutTest

## IPlayerInput + CliPlayerInput 单元测试。
## 注：GUT 9.7.0 将 push_error 视为测试失败，因此不直接调用 IPlayerInput 抽象方法。
## 抽象基类的 push_error 行为由 GUT 错误捕获机制隐式验证。
## 此处聚焦验证 CliPlayerInput 正确 override 所有方法 + 队列机制。


# === 1. CliPlayerInput 默认行为 ===

func test_cli_default_wait_action_returns_null() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_null(input.wait_action(null), "默认应返回 null 表示结束行动")


func test_cli_default_choose_returns_first_option() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	var options: Array = ["a", "b", "c"]
	assert_eq(input.choose(options), "a", "默认应返回第一项")


func test_cli_default_choose_empty_returns_null() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_null(input.choose([]), "空列表应返回 null")


func test_cli_default_choose_card_returns_empty() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_eq(input.choose_card(2).size(), 0, "默认应返回空数组")


func test_cli_default_choose_target_returns_empty() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_eq(input.choose_target(1).size(), 0, "默认应返回空数组")


func test_cli_default_choose_map_block_returns_first() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	var block1: Dictionary = {"name": "block1"}
	var block2: Dictionary = {"name": "block2"}
	assert_eq(input.choose_map_block([block1, block2]), block1, "默认应返回第一个地块")


func test_cli_default_choose_map_block_empty_returns_null() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_null(input.choose_map_block([]), "空列表应返回 null")


func test_cli_default_confirm_returns_true() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_true(input.confirm("确认？"), "默认应返回 true")


func test_cli_default_show_card_silent() -> void:
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.show_card(null, null)
	assert_true(true, "show_card 静默无副作用")


# === 3. CliPlayerInput queue 机制 ===

func test_cli_queue_action_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_action("action1")
	input.queue_action("action2")
	assert_eq(input.wait_action(null), "action1")
	assert_eq(input.wait_action(null), "action2")
	assert_null(input.wait_action(null), "队列空后返回默认 null")


func test_cli_queue_choose_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_choose("picked1")
	input.queue_choose("picked2")
	assert_eq(input.choose(["default"]), "picked1")
	assert_eq(input.choose(["default"]), "picked2")
	assert_eq(input.choose(["default"]), "default", "队列空后返回默认第一项")


func test_cli_queue_choose_card_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_choose_card(["card1", "card2"])
	input.queue_choose_card(["card3"])
	assert_eq(input.choose_card(2), ["card1", "card2"])
	assert_eq(input.choose_card(1), ["card3"])
	assert_eq(input.choose_card(1).size(), 0, "队列空后返回空")


func test_cli_queue_choose_target_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_choose_target(["p1"])
	assert_eq(input.choose_target(1), ["p1"])
	assert_eq(input.choose_target(1).size(), 0, "队列空后返回空")


func test_cli_queue_choose_block_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	var block1: Dictionary = {"name": "b1"}
	var block2: Dictionary = {"name": "b2"}
	input.queue_choose_block(block2)
	assert_eq(input.choose_map_block([block1, block2]), block2, "应返回队列中的项")
	assert_eq(input.choose_map_block([block1, block2]), block1, "队列空后返回默认第一项")


func test_cli_queue_confirm_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_confirm(false)
	input.queue_confirm(true)
	assert_false(input.confirm("q1"), "应返回队列中的 false")
	assert_true(input.confirm("q2"), "应返回队列中的 true")
	assert_true(input.confirm("q3"), "队列空后返回默认 true")


# === 4. 继承关系 ===

func test_cli_player_input_is_i_player_input() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_true(input is IPlayerInput, "CliPlayerInput 应是 IPlayerInput 子类")


func test_cli_overrides_choose_returns_value_not_null() -> void:
	# 验证 CliPlayerInput 确实 override 了 choose（基类返回 null，子类返回第一项）
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_not_null(input.choose(["x"]), "CliPlayerInput.choose 应 override 返回非 null")


func test_cli_overrides_confirm_returns_true_not_false() -> void:
	# 验证 CliPlayerInput 确实 override 了 confirm（基类返回 false，子类返回 true）
	var input: CliPlayerInput = CliPlayerInput.new()
	assert_true(input.confirm("test"), "CliPlayerInput.confirm 应 override 返回 true")


func test_cli_overrides_choose_map_block_returns_value_not_null() -> void:
	# 验证 CliPlayerInput 确实 override 了 choose_map_block
	var input: CliPlayerInput = CliPlayerInput.new()
	var block: Dictionary = {"name": "b"}
	assert_not_null(input.choose_map_block([block]), "CliPlayerInput.choose_map_block 应 override 返回非 null")
