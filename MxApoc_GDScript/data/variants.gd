class_name Variants

static var _ALL: Array[VariantData] = []

static func _ensure_all() -> void:
	if not _ALL.is_empty():
		return
	_ALL.append(_make("crisis", "危机四伏", "往初始拾荒牌堆中添加更多的“伏击”。"))
	_ALL.append(_make("famine", "大饥荒", "玩家随机投掷骰子来决定初始饥饿等级。"))
	_ALL.append(_make("shared_fate", "同生共死", "当任何玩家被消灭时，所有求生者输掉游戏。"))

## 获取所有变体，首次调用时懒加载。
static func get_all() -> Array[VariantData]:
	_ensure_all()
	return _ALL

## 按 id 查询变体；未找到返回 null。
static func get_by_id(id: String) -> VariantData:
	_ensure_all()
	for v in _ALL:
		if v.id == id:
			return v
	return null

static func _make(id: String, display_name: String, desc: String) -> VariantData:
	var v := VariantData.new()
	v.id = id
	v.display_name = display_name
	v.desc = desc
	return v
