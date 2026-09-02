class_name SeatItem extends PanelContainer

## 座位序号，0 起。
@export var seat_index: int = 0

## 座位类型或求生者选择变更时发射。
signal changed(seat_index: int)

const TYPE_HUMAN := 0
const TYPE_AI := 1
const TYPE_EMPTY := 2

@onready var _seat_index_label: Label = $MarginContainer/VBoxContainer/SeatHeader/SeatIndexLabel
@onready var _name_label: Label = $MarginContainer/VBoxContainer/SeatHeader/NameLabel
@onready var _type_option: OptionButton = $MarginContainer/VBoxContainer/SeatHeader/TypeOption
@onready var _survivor_option: OptionButton = $MarginContainer/VBoxContainer/SurvivorOption

## 座位归属的玩家名与网络 peer id（来自 RoomState.seats）。
var _player_name: String = ""
var _peer_id: int = 0
## 被客机占用时锁定为只读。
var _locked: bool = false

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
	var survivors := DataManager.get_available_survivors()
	for i in range(survivors.size()):
		var survivor = survivors[i]
		_survivor_option.add_item(survivor.character_name, i + 1)
		_survivor_option.set_item_metadata(i + 1, survivor)
	_survivor_option.select(0)

func _on_selection_changed(_idx: int) -> void:
	_update_survivor_enabled()
	changed.emit(seat_index)

func _update_survivor_enabled() -> void:
	_survivor_option.disabled = (_type_option.selected == TYPE_EMPTY) or _locked
	_refresh_name_label()

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

## 用 RoomState.seats 项的 {type, survivor, player_name, peer_id} 数据初始化座位 UI。
func setup(data: Dictionary) -> void:
	_player_name = str(data.get("player_name", ""))
	_peer_id = int(data.get("peer_id", 0))
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
	if seat_index == 0:
		_type_option.select(TYPE_HUMAN)
		_type_option.disabled = true
	else:
		# 非 0 座位允许主机设为"真人"（本地热座）；客机占用后由 set_locked 锁定
		_type_option.set_item_disabled(TYPE_HUMAN, false)
	_type_option.set_block_signals(false)
	_survivor_option.set_block_signals(false)
	_update_survivor_enabled()

## 锁定座位（客机占用后只读）。
func set_locked(locked: bool) -> void:
	_locked = locked
	if _locked:
		_type_option.disabled = true
		_survivor_option.disabled = true
	else:
		_type_option.disabled = (seat_index == 0)
		_update_survivor_enabled()

## 是否处于锁定只读状态。
func is_locked() -> bool:
	return _locked

## 收集当前座位选择，返回 {type, survivor, player_name, peer_id} 字典。
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
	return {"type": type_text, "survivor": survivor, "player_name": _player_name, "peer_id": _peer_id}

func _refresh_name_label() -> void:
	if _name_label == null:
		return
	if _locked or _peer_id != 0:
		var name_text := _player_name if _player_name != "" else "玩家"
		if _peer_id != 0:
			name_text = "◎ " + name_text
		_name_label.text = name_text
		_name_label.visible = true
	else:
		_name_label.visible = false
