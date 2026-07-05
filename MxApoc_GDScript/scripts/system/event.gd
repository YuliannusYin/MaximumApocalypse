class_name Event
extends RefCounted

## 触发名,由 entity.trigger 在循环外赋值。
var trigger_name: String

## 事件来源。null 表示无来源(如饥饿伤害、中毒)。
var source: Variant = null

## 事件目标。
var target: Variant = null

## 数值参数(伤害点数、抓牌数、回复量等)。可被钩子修改。
var num: int = 0

## 类型标签(如 "饥饿伤害"、"poison")。
var type: String = ""

## 是否已取消。cancel() 后为 true,后续技能不再执行。
var cancelled: bool = false

## 取消事件。trigger 循环检测到 cancelled 后中断后续技能。
func cancel() -> void:
	cancelled = true
