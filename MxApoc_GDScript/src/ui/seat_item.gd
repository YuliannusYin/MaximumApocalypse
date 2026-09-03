class_name SeatItem extends PanelContainer

## 座位序号，0 起。
@export var seat_index: int = 0

## 座位类型或求生者选择变更时发射。
signal changed(seat_index: int)
## 座位移动请求（delta = -1 上移 / +1 下移），由 GameRoom 处理交换。
signal move_requested(seat_index: int, delta: int)

const TYPE_HUMAN := 0
const TYPE_AI := 1
const TYPE_EMPTY := 2

@onready var _seat_index_label: Label = $MarginContainer/VBoxContainer/SeatHeader/SeatIndexLabel
@onready var _name_label: Label = $MarginContainer/VBoxContainer/SeatHeader/NameLabel
@onready var _type_option: OptionButton = $MarginContainer/VBoxContainer/SeatHeader/TypeOption
@onready var _survivor_option: OptionButton = $MarginContainer/VBoxContainer/SurvivorOption

## 归属下拉（真人座位指定控制者：主机 / 热座玩家 / 各客机）。
var _owner_option: OptionButton = null
## 上移/下移按钮。
var _up_btn: Button = null
var _down_btn: Button = null

## 可选归属的客机列表：[{pid, name}]，由 GameRoom 在 add_child 前注入。
var owner_clients: Array = []

## 座位归属的玩家名与网络 peer id（来自 RoomState.seats）。
var _player_name: String = ""
var _peer_id: int = 0
## 被客机占用时锁定为只读（归属下拉仍可改，供房主重新分配）。
var _locked: bool = false
## 首位/末位标记（禁用上移/下移）。
var _is_first := false
var _is_last := false


func _ready() -> void:
	_seat_index_label.text = "座位 %d" % (seat_index + 1)
	_build_owner_option()
	_build_move_buttons()
	_populate_survivors()
	_type_option.set_block_signals(true)
	_type_option.select(TYPE_AI)
	_type_option.set_block_signals(false)
	_update_widget_states()
	_type_option.item_selected.connect(_on_selection_changed)
	_survivor_option.item_selected.connect(_on_selection_changed)
	_owner_option.item_selected.connect(_on_owner_selected)


## 构建归属下拉（真人座位右侧）：主机 / 热座玩家 / 各已连接客机。
func _build_owner_option() -> void:
	_owner_option = OptionButton.new()
	_owner_option.custom_minimum_size = Vector2(120, 0)
	_owner_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header: HBoxContainer = _type_option.get_parent()
	header.add_child(_owner_option)
	_populate_owner_option()


func _populate_owner_option() -> void:
	_owner_option.set_block_signals(true)
	_owner_option.clear()
	_owner_option.add_item("主机", 0)
	_owner_option.set_item_metadata(0, {"peer_id": NetSession.HOST_PEER_ID, "name": ""})
	_owner_option.add_item("热座玩家", 1)
	_owner_option.set_item_metadata(1, {"peer_id": 0, "name": "热座玩家"})
	for i in range(owner_clients.size()):
		var client: Dictionary = owner_clients[i]
		var label := str(client.get("name", "玩家%d" % int(client.get("pid", 0))))
		_owner_option.add_item("◎ %s" % label, _owner_option.item_count)
		_owner_option.set_item_metadata(_owner_option.item_count - 1, {
			"peer_id": int(client.get("pid", 0)), "name": label,
		})
	_owner_option.select(0)
	_owner_option.set_block_signals(false)


## 构建上移/下移按钮（座位头部右侧）。
func _build_move_buttons() -> void:
	_up_btn = Button.new()
	_up_btn.text = "↑"
	_up_btn.custom_minimum_size = Vector2(30, 0)
	_down_btn = Button.new()
	_down_btn.text = "↓"
	_down_btn.custom_minimum_size = Vector2(30, 0)
	var header: HBoxContainer = _type_option.get_parent()
	header.add_child(_up_btn)
	header.add_child(_down_btn)
	_up_btn.pressed.connect(func() -> void: move_requested.emit(seat_index, -1))
	_down_btn.pressed.connect(func() -> void: move_requested.emit(seat_index, 1))


## 设置首位/末位标记（禁用对应移动按钮）。由 GameRoom 在构建列表时调用。
func set_move_bounds(is_first: bool, is_last: bool) -> void:
	_is_first = is_first
	_is_last = is_last
	_up_btn.disabled = is_first or _locked
	_down_btn.disabled = is_last or _locked


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
	_update_widget_states()
	changed.emit(seat_index)


func _on_owner_selected(_idx: int) -> void:
	var meta: Variant = _owner_option.get_item_metadata(_owner_option.selected)
	if meta is Dictionary:
		_peer_id = int(meta.get("peer_id", 0))
		_player_name = str(meta.get("name", ""))
		if _peer_id == NetSession.HOST_PEER_ID and _player_name == "":
			_player_name = NetSession.player_name
	# 归属变更后自校正锁定态：归属主机/热座时解锁（类型/角色恢复可编辑），归属客机时锁定
	_locked = (_peer_id != 0 and _peer_id != NetSession.HOST_PEER_ID)
	_type_option.disabled = _locked
	_refresh_name_label()
	changed.emit(seat_index)


## 按当前类型/锁定状态刷新各控件可用性与名称标签。
## 归属下拉不受 _locked 影响：客机占用座位锁定类型/角色，但房主仍可重新指定归属。
func _update_widget_states() -> void:
	_owner_option.visible = (_type_option.selected == TYPE_HUMAN)
	_owner_option.disabled = (_type_option.selected != TYPE_HUMAN)
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


## 按归属 peer_id 选中归属下拉对应项（找不到时保持默认）。
func _select_owner_by_peer(pid: int, player_name: String) -> void:
	_owner_option.set_block_signals(true)
	for i in range(_owner_option.item_count):
		var meta: Variant = _owner_option.get_item_metadata(i)
		if meta is Dictionary and int(meta.get("peer_id", -1)) == pid:
			_owner_option.select(i)
			_owner_option.set_block_signals(false)
			return
	_owner_option.set_block_signals(false)
	# 无匹配选项（如该客机已断开）：保留数据但显示原始名字
	_player_name = player_name


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
	_select_owner_by_peer(_peer_id, _player_name)
	_type_option.set_block_signals(false)
	_survivor_option.set_block_signals(false)
	_update_widget_states()


## 锁定座位（客机占用后：类型与角色只读；归属下拉保留可改，供房主重新分配）。
func set_locked(locked: bool) -> void:
	_locked = locked
	if _locked:
		_type_option.disabled = true
		_survivor_option.disabled = true
	else:
		_type_option.disabled = false
	_update_widget_states()
	if _up_btn != null and _down_btn != null:
		_up_btn.disabled = _is_first or _locked
		_down_btn.disabled = _is_last or _locked


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
	if _peer_id != 0:
		var name_text := _player_name if _player_name != "" else "玩家"
		if _peer_id != NetSession.HOST_PEER_ID:
			name_text = "◎ " + name_text
		_name_label.text = name_text
		_name_label.visible = true
	else:
		if _type_option.selected == TYPE_HUMAN and _player_name != "":
			_name_label.text = _player_name
			_name_label.visible = true
		else:
			_name_label.visible = false
