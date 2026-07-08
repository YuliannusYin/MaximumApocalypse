extends GutTest

## Pile 单元测试。


func _make_card(n: String = "") -> Card:
	var c: Card = Card.new()
	c.card_name = n
	return c


func test_new_pile_is_empty() -> void:
	var p: Pile = Pile.new()
	assert_true(p.is_empty(), "新建牌堆应为空")
	assert_eq(p.size(), 0)


func test_add_and_size() -> void:
	var p: Pile = Pile.new()
	p.add(_make_card("card1"))
	p.add(_make_card("card2"))
	assert_eq(p.size(), 2, "添加 2 张后 size 应为 2")
	assert_false(p.is_empty(), "不应为空")


func test_draw_from_top() -> void:
	var p: Pile = Pile.new()
	var c1: Card = _make_card("card1")
	var c2: Card = _make_card("card2")
	p.add(c1)  # 顶部
	p.add(c2)  # 底部
	var drawn: Card = p.draw()
	assert_eq(drawn, c1, "应从顶部抓取（先加入的先抓）")
	assert_eq(p.size(), 1, "抓取后 size 应为 1")


func test_draw_empty_returns_null() -> void:
	var p: Pile = Pile.new()
	var drawn: Card = p.draw()
	assert_null(drawn, "空牌堆抓取应返回 null")
	assert_eq(p.size(), 0)


func test_get_all_does_not_remove() -> void:
	var p: Pile = Pile.new()
	p.add(_make_card("card1"))
	p.add(_make_card("card2"))
	var all: Array = p.get_all()
	assert_eq(all.size(), 2, "get_all 应返回所有牌")
	assert_eq(p.size(), 2, "get_all 不应移除牌")
	# 修改返回的列表不应影响原牌堆
	all.clear()
	assert_eq(p.size(), 2, "修改返回列表不应影响原牌堆")


func test_shuffle_keeps_size() -> void:
	var p: Pile = Pile.new()
	for i in range(10):
		p.add(_make_card(str(i)))
	p.shuffle()
	assert_eq(p.size(), 10, "洗牌后 size 应不变")
	# 验证元素不变（顺序可能变）
	var all: Array = p.get_all()
	var names: Array = []
	for c in all:
		names.append(c.card_name)
	names.sort()
	assert_eq(names, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], "洗牌后元素集合应不变")


func test_shuffle_into_clears_source() -> void:
	var source: Pile = Pile.new()
	var target: Pile = Pile.new()
	source.add(_make_card("a"))
	source.add(_make_card("b"))
	target.add(_make_card("c"))
	source.shuffle_into(target)
	assert_eq(source.size(), 0, "shuffle_into 后源牌堆应清空")
	assert_eq(target.size(), 3, "目标牌堆应有 3 张牌")


func test_shuffle_into_target_reshuffled() -> void:
	var source: Pile = Pile.new()
	var target: Pile = Pile.new()
	source.add(_make_card("a"))
	source.add(_make_card("b"))
	target.add(_make_card("c"))
	target.add(_make_card("d"))
	source.shuffle_into(target)
	# 验证目标牌堆包含所有元素
	var all: Array = target.get_all()
	var names: Array = []
	for c in all:
		names.append(c.card_name)
	names.sort()
	assert_eq(names, ["a", "b", "c", "d"], "目标牌堆应包含源+目标的全部牌")


func test_draw_sequence() -> void:
	var p: Pile = Pile.new()
	var c1: Card = _make_card("first")
	var c2: Card = _make_card("second")
	var c3: Card = _make_card("third")
	p.add(c1)
	p.add(c2)
	p.add(c3)
	assert_eq(p.draw(), c1)
	assert_eq(p.draw(), c2)
	assert_eq(p.draw(), c3)
	assert_null(p.draw(), "全部抓完后应返回 null")
