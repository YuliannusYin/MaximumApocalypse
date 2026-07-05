class_name Skill
extends Resource

## 触发名。单个字符串或用"、"分隔的多个字符串(如 "游戏开始时、受到伤害时")。
@export var trigger: String

## 过滤函数。签名为 (event: Event) -> bool。默认恒真(无 callable 时返回 true)。
var filter: Callable = Callable()

## 内容函数。签名为 (event: Event) -> void。默认空操作。
var content: Callable = Callable()

## 静态构造:便于代码中创建技能实例。
static func make(p_trigger: String, p_filter: Callable = Callable(), p_content: Callable = Callable()) -> Skill:
	var s := Skill.new()
	s.trigger = p_trigger
	s.filter = p_filter
	s.content = p_content
	return s
