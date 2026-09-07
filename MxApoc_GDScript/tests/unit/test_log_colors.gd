extends TestBase

## LogColors 单元测试。
## 覆盖：BBCode 着色包裹、导出纯文本时去掉颜色标签。


func test_player_wraps_quoted_name_with_color() -> void:
	assert_eq(LogColors.player("消防员"), "[color=#73d0ff]\"消防员\"[/color]")


func test_strip_bbcode_keeps_quotes_and_body() -> void:
	var colored: String = LogColors.player("消防员") + " 抓取了游戏牌 " + LogColors.card("急救包")
	assert_eq(LogColors.strip_bbcode(colored), "\"消防员\" 抓取了游戏牌 \"急救包\"")


func test_strip_bbcode_leaves_plain_text() -> void:
	assert_eq(LogColors.strip_bbcode("==== 第1轮 ===="), "==== 第1轮 ====")


func test_to_plain_log_joins_lines() -> void:
	var messages: Array = [
		LogColors.player("A") + " 移动",
		"==== 第2轮 ====",
		LogColors.monster("丧尸") + " 被击杀",
	]
	var expected: String = "\"A\" 移动\n==== 第2轮 ====\n\"丧尸\" 被击杀"
	assert_eq(LogColors.to_plain_log(messages), expected)


func test_to_plain_log_empty() -> void:
	assert_eq(LogColors.to_plain_log([]), "")
