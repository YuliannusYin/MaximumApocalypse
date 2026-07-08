class_name VariantData
extends RefCounted

## 变体静态数据。
## 从 data/variants/*.json 构造。

var id: String = ""  # "crisis" / "famine" / "shared_fate"
var english_name: String = ""
var display_name: String = ""
var desc: String = ""


func _init(data: Dictionary = {}) -> void:
	id = data.get("id", "")
	english_name = data.get("english_name", id)
	display_name = data.get("display_name", "")
	desc = data.get("desc", "")
