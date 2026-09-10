extends TestBase

## RPC/JSON 数字常为 float；卡面取值必须把 float 收成 int，否则会显示成 0。


func test_to_int_accepts_float_and_int() -> void:
	var view := MonsterCardView.new()
	assert_eq(view._to_int(2, 0), 2)
	assert_eq(view._to_int(3.0, 0), 3, "float 应显示为整数攻击力/血量")
	assert_eq(view._to_int(null, 7), 7, "缺字段应回退")
	view.free()
