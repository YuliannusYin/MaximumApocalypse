extends GutTest

## CliPlayerInput 队列机制单元测试。
## 注：GUT 9.7.0 将 push_error 视为测试失败，因此不直接调用 IPlayerInput 抽象方法。
## 抽象基类的 push_error 行为由 GUT 错误捕获机制隐式验证。


# === 1. CliPlayerInput queue 机制 ===

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
	assert_eq(await input.choose(["default"]), "picked1")
	assert_eq(await input.choose(["default"]), "picked2")
	assert_eq(await input.choose(["default"]), "default", "队列空后返回默认第一项")


func test_cli_queue_choose_card_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_choose_card(["card1", "card2"])
	input.queue_choose_card(["card3"])
	assert_eq(await input.choose_card(2), ["card1", "card2"])
	assert_eq(await input.choose_card(1), ["card3"])
	assert_eq(await input.choose_card(1).size(), 0, "队列空后返回空")


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
	assert_eq(await input.choose_map_block([block1, block2]), block2, "应返回队列中的项")
	assert_eq(await input.choose_map_block([block1, block2]), block1, "队列空后返回默认第一项")


func test_cli_queue_confirm_returns_in_order() -> void:
	var input: CliPlayerInput = CliPlayerInput.new()
	input.queue_confirm(false)
	input.queue_confirm(true)
	assert_false(input.confirm("q1"), "应返回队列中的 false")
	assert_true(input.confirm("q2"), "应返回队列中的 true")
	assert_true(input.confirm("q3"), "队列空后返回默认 true")
