class_name SeatItem extends PanelContainer

@export var seat_index: int = 0

signal changed(seat_index: int)

const TYPE_HUMAN := 0
const TYPE_AI := 1
const TYPE_EMPTY := 2

@onready var _seat_index_label: Label = $MarginContainer/VBoxContainer/SeatHeader/SeatIndexLabel
@onready var _type_option: OptionButton = $MarginContainer/VBoxContainer/SeatHeader/TypeOption
@onready var _survivor_option: OptionButton = $MarginContainer/VBoxContainer/SurvivorOption

func _ready() -> void:
	_seat_index_label.text = "座位 %d" % (seat_index + 1)
	_populate_survivors()
	_type_option.set_block_signals(true)
	if seat_index == 0:
		_type_option.select(TYPE_HUMAN)
		_type_option.disabled = true
	else:
		_type_option.select(TYPE_AI)
	_type_option.set_block_signals(false)
	_update_survivor_enabled()
	_type_option.item_selected.connect(_on_selection_changed)
	_survivor_option.item_selected.connect(_on_selection_changed)

func _populate_survivors() -> void:
	_survivor_option.clear()
	_survivor_option.add_item("未选择", 0)
	_survivor_option.set_item_metadata(0, null)
	var survivors := Survivors.get_all()
	for i in range(survivors.size()):
		var s = survivors[i]
		_survivor_option.add_item(s.display_name, i + 1)
		_survivor_option.set_item_metadata(i + 1, s)
	_survivor_option.select(0)

func _on_selection_changed(_idx: int) -> void:
	_update_survivor_enabled()
	changed.emit(seat_index)

func _update_survivor_enabled() -> void:
	_survivor_option.disabled = (_type_option.selected == TYPE_EMPTY)

func refresh_survivor_disabled(taken_ids: Array) -> void:
	# 当前选择已被其他座位占用时（初始状态或类型切换导致），重置为"未选择"
	var my_id := _get_current_survivor_id()
	if my_id != "" and my_id in taken_ids:
		_survivor_option.select(0)
		my_id = ""
	for i in range(_survivor_option.item_count):
		if i == 0:
			_survivor_option.set_item_disabled(i, false)
			continue
		var meta = _survivor_option.get_item_metadata(i)
		if meta == null:
			_survivor_option.set_item_disabled(i, false)
			continue
		_survivor_option.set_item_disabled(i, meta.id in taken_ids)

func _get_current_survivor_id() -> String:
	var idx := _survivor_option.selected
	if idx <= 0:
		return ""
	var meta = _survivor_option.get_item_metadata(idx)
	if meta == null or not (meta is SurvivorData):
		return ""
	return meta.id

func setup(data: Dictionary) -> void:
	_type_option.set_block_signals(true)
	_survivor_option.set_block_signals(true)
	if data.has("type"):
		match String(data.type):
			"human": _type_option.select(TYPE_HUMAN)
			"ai": _type_option.select(TYPE_AI)
			"empty": _type_option.select(TYPE_EMPTY)
	if data.has("survivor") and data.survivor != null:
		var target: SurvivorData = data.survivor
		for i in range(_survivor_option.item_count):
			var meta = _survivor_option.get_item_metadata(i)
			if meta != null and meta is SurvivorData and meta.id == target.id:
				_survivor_option.select(i)
				break
	if seat_index == 0:
		_type_option.select(TYPE_HUMAN)
		_type_option.disabled = true
	_type_option.set_block_signals(false)
	_survivor_option.set_block_signals(false)
	_update_survivor_enabled()

func collect() -> Dictionary:
	var type_text := "human"
	match _type_option.selected:
		TYPE_HUMAN: type_text = "human"
		TYPE_AI: type_text = "ai"
		TYPE_EMPTY: type_text = "empty"
	var survivor = null
	if _type_option.selected != TYPE_EMPTY:
		var idx := _survivor_option.selected
		if idx > 0:
			survivor = _survivor_option.get_item_metadata(idx)
	return {"type": type_text, "survivor": survivor}
