class_name SeatItem extends PanelContainer

## 座位序号，0 起。
@export var seat_index: int = 0
var _online_mode: bool = false
var _controller_editable: bool = true
var _survivor_editable: bool = true
var _initialized: bool = false

## 座位类型或求生者选择变更时发射。
signal changed(seat_index: int)

const TYPE_HUMAN := 0
const TYPE_AI := 1
const TYPE_EMPTY := 2

@onready var _seat_index_label: Label = $MarginContainer/VBoxContainer/SeatHeader/SeatIndexLabel
@onready var _type_option: OptionButton = $MarginContainer/VBoxContainer/SeatHeader/TypeOption
@onready var _survivor_option: OptionButton = $MarginContainer/VBoxContainer/SurvivorOption

func _ready() -> void:
	_ensure_initialized()

func _ensure_initialized() -> void:
	if _initialized:
		return
	_seat_index_label = get_node("MarginContainer/VBoxContainer/SeatHeader/SeatIndexLabel")
	_type_option = get_node("MarginContainer/VBoxContainer/SeatHeader/TypeOption")
	_survivor_option = get_node("MarginContainer/VBoxContainer/SurvivorOption")
	_seat_index_label.text = "座位 %d" % (seat_index + 1)
	_populate_survivors()
	_type_option.set_block_signals(true)
	_type_option.select(TYPE_AI)
	_type_option.set_block_signals(false)
	_update_survivor_enabled()
	_type_option.item_selected.connect(_on_selection_changed)
	_survivor_option.item_selected.connect(_on_selection_changed)
	_initialized = true

func _populate_survivors() -> void:
	_survivor_option.clear()
	_survivor_option.add_item("未选择", 0)
	_survivor_option.set_item_metadata(0, null)
	var survivors := DataManager.get_available_survivors()
	for i in range(survivors.size()):
		var survivor = survivors[i]
		_survivor_option.add_item(survivor.character_name, i + 1)
		_survivor_option.set_item_metadata(i + 1, survivor)
	_survivor_option.select(0)

## 联机房间由房主提供当前玩家列表；客户端只读控制者下拉框。
func configure_controller_options(players: Array, controller_id: String,
		controller_editable: bool, survivor_editable: bool) -> void:
	_ensure_initialized()
	_online_mode = true
	_controller_editable = controller_editable
	_survivor_editable = survivor_editable
	_type_option.clear()
	for player in players:
		if not player is Dictionary:
			continue
		var pid := String(player.get("player_id", ""))
		if pid.is_empty():
			continue
		_type_option.add_item(String(player.get("display_name", pid)))
		_type_option.set_item_metadata(_type_option.item_count - 1, pid)
	_type_option.add_item("AI托管")
	_type_option.set_item_metadata(_type_option.item_count - 1, "__ai__")
	_select_controller(controller_id)
	_type_option.disabled = not _controller_editable
	_update_survivor_enabled()

func _select_controller(controller_id: String) -> void:
	for i in range(_type_option.item_count):
		if String(_type_option.get_item_metadata(i)) == controller_id:
			_type_option.select(i)
			return
	if _type_option.item_count > 0:
		_type_option.select(_type_option.item_count - 1)

func _on_selection_changed(_idx: int) -> void:
	if _online_mode and _controller_editable:
		_survivor_editable = true
	_update_survivor_enabled()
	changed.emit(seat_index)

func _update_survivor_enabled() -> void:
	if _online_mode:
		_survivor_option.disabled = not _survivor_editable
	else:
		_survivor_option.disabled = (_type_option.selected == TYPE_EMPTY)

## 根据已占用 id 禁用 OptionButton 中对应的求生者项。
## 当前选择已被其他座位占用时（初始状态或类型切换导致），重置为"未选择"。
func refresh_survivor_disabled(taken_ids: Array) -> void:
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
		_survivor_option.set_item_disabled(i, meta.english_name in taken_ids)

func _get_current_survivor_id() -> String:
	var idx := _survivor_option.selected
	if idx <= 0:
		return ""
	var meta = _survivor_option.get_item_metadata(idx)
	if meta == null or not (meta is SurvivorData):
		return ""
	return meta.english_name

## 用 RoomState.seats 项的 {type, survivor} 数据初始化座位 UI。
func setup(data: Dictionary) -> void:
	_ensure_initialized()
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
			if meta != null and meta is SurvivorData and meta.english_name == target.english_name:
				_survivor_option.select(i)
				break
	elif _online_mode:
		var survivor_id := String(data.get("survivor_id", ""))
		for i in range(_survivor_option.item_count):
			var meta = _survivor_option.get_item_metadata(i)
			if meta != null and meta is SurvivorData and meta.english_name == survivor_id:
				_survivor_option.select(i)
				break
		if data.has("controller_id"):
			_select_controller(String(data.get("controller_id", "")))
	_type_option.set_block_signals(false)
	_survivor_option.set_block_signals(false)
	_update_survivor_enabled()

## 收集当前座位选择，返回 {type: String, survivor: SurvivorData} 字典。
func collect() -> Dictionary:
	_ensure_initialized()
	if _online_mode:
		var controller_id := String(_type_option.get_item_metadata(_type_option.selected))
		var survivor = null
		if _survivor_option.selected > 0:
			survivor = _survivor_option.get_item_metadata(_survivor_option.selected)
		return {
			"type": "ai" if controller_id == "__ai__" else "human",
			"controller_id": "" if controller_id == "__ai__" else controller_id,
			"survivor": survivor,
		}
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
