class_name Mark
extends RefCounted

## Mark 类。实体上的标记，可同时支持计数和集合记录。
## 参考：无名杀（libnoname/noname）mark 系统。

## 标识名
var name: String = ""
## UI 渲染显示文本（空时用 name）
var mark_text: String = ""
## tooltip 内容
var mark_content: String = ""
## 是否在 UI 渲染
var visible: bool = true
## 计数值
var count: int = 0
## 集合项列表
var items: Array = []

## 返回 UI 显示文本：mark_text 非空时用 mark_text，否则用 name。
func get_display_text() -> String:
	return mark_text if mark_text != "" else name
