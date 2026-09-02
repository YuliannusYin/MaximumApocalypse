extends GutTest


func test_flushes_operations_in_registration_order() -> void:
	var runtime := OperationRuntime.new()
	var order: Array[String] = []
	var first: Dictionary = runtime.enqueue("first", func() -> String:
		order.append("first")
		return "one")
	var second: Dictionary = runtime.enqueue("second", func() -> String:
		order.append("second")
		return "two")

	await runtime.flush()

	assert_eq(order, ["first", "second"])
	assert_eq(first["status"], "completed")
	assert_eq(first["result"], "one")
	assert_eq(second["result"], "two")


func test_cancelled_operation_is_not_executed() -> void:
	var runtime := OperationRuntime.new()
	var called := false
	var operation: Dictionary = runtime.enqueue("cancelled", func() -> void:
		called = true)
	EventSystem.cancel(operation)

	await runtime.flush()

	assert_false(called)
	assert_eq(operation["status"], "cancelled")


func test_nested_dispatch_uses_stack_order() -> void:
	var runtime: OperationRuntime = OperationRuntime.new()
	var order: Array[String] = []

	var c_executor: Callable = func() -> void:
		order.append("C")
	var b_executor: Callable = func() -> void:
		order.append("B")
		await runtime.dispatch("C", c_executor)
	var a_executor: Callable = func() -> void:
		order.append("A-start")
		await runtime.dispatch("B", b_executor)
		order.append("A-end")

	await runtime.dispatch("A", a_executor)

	assert_eq(order, ["A-start", "B", "C", "A-end"])
