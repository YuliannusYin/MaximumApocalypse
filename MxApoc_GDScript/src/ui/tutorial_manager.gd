extends Node

## 聚光灯教程。监听游戏事件，在首次触发时对着真实 UI 讲一句。
## 任务 0 默认启动；Settings.tutorial_mode 为 true 时任意任务也启动。

const ALL_TUTORIAL_POINTS: Array = [
	"mission_intro",
	"initial_monster_card",
	"first_monster_spawn",
	"first_draw_phase",
	"action_ap",
	"action_move",
	"action_rest",
	"action_skills",
	"first_sneak_judge",
	"first_hunger",
	"first_monster_attack",
]

## 步骤：text 旁白，anchor 对应 GameScene2D.get_tutorial_hole。
const TUTORIAL_STEPS: Dictionary = {
	"mission_intro": {
		"text": "看右边这块：这局要给面包车加满燃料，然后大家都回到车上，车上还不能有怪物。",
		"anchor": "mission",
	},
	"initial_monster_card": {
		"text": "开局太吵，招来了一只怪。它会跟着你，回合结束时打你。用攻击牌清掉它。",
		"anchor": "monster_zone",
	},
	"first_draw_phase": {
		"text": "每回合开始会摸一张牌。手牌就是你能做的事，别攒着不用。",
		"anchor": "hand",
	},
	"action_ap": {
		"text": "到你行动了。走动、再摸牌、拾荒各花 1 点行动。花完就结束回合。",
		"anchor": "ap",
	},
	"action_move": {
		"text": "想挪地方：点地图上自己的头像，再点旁边的地块。",
		"anchor": "avatar",
	},
	"action_rest": {
		"text": "点自己的牌堆再摸一张；地块上的红绿蓝对应三堆拾荒；点手牌就能用。左键拖地图，右键看地块，滚轮缩放。",
		"anchor": "action_rest",
	},
	"action_skills": {
		"text": "角色和地块的主动技能在这里。亮着就能点，灰掉是现在还用不了。有的要花行动点，点下去会再问你一次。",
		"anchor": "skills",
	},
	"first_monster_spawn": {
		"text": "格子上冒出怪物标记了。走进去可能要做潜行检定，失败就会再抓怪。",
		"anchor": "spawn_mark",
	},
	"first_sneak_judge": {
		"text": "潜行检定：骰子小于你的潜行值就躲开，不用抓怪。",
		"anchor": "sneak",
	},
	"first_hunger": {
		"text": "回合结束会饿一点。饥饿到 6 开始掉血，记得拾荒找食物。",
		"anchor": "hunger",
	},
	"first_monster_attack": {
		"text": "怪物打你了。生命到 0 就死。用攻击牌打怪，或拿防御装备减伤。",
		"anchor": "hp",
	},
	"tutorial_complete": {
		"text": "基本操作就是这些。去给面包车找燃料，活着回来。",
		"anchor": "",
	},
}

var _triggered: Dictionary = {}
var _dialog_queue: Array = []
var _dialog_active: bool = false
var _dialog: CanvasLayer = null
var _hole_provider: Callable = Callable()
var _tutorial_complete_shown: bool = false


func start(dialog: CanvasLayer, hole_provider: Callable = Callable()) -> void:
	_dialog = dialog
	_hole_provider = hole_provider
	_dialog.dialog_finished.connect(_on_dialog_finished)
	_dialog.skip_pressed.connect(_on_skip)
	EventBus.game_started.connect(_on_game_started)
	EventBus.monster_card_drawn.connect(_on_monster_card_drawn)
	EventBus.monster_spawned.connect(_on_monster_spawned)
	EventBus.card_drawn.connect(_on_card_drawn)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.sneak_judge_triggered.connect(_on_sneak_judge_triggered)
	EventBus.player_hunger_changed.connect(_on_hunger_changed)
	EventBus.damage_taken.connect(_on_damage_taken)


func _trigger(point_id: String) -> void:
	if _triggered.has(point_id):
		return
	_triggered[point_id] = true
	var step: Variant = TUTORIAL_STEPS.get(point_id, {})
	if step.is_empty():
		return
	_dialog_queue.append(step)
	if not _dialog_active:
		_show_next()


func _show_next() -> void:
	if _dialog_queue.is_empty():
		_dialog_active = false
		_check_all_triggered()
		return
	_dialog_active = true
	var step: Dictionary = _dialog_queue.pop_front()
	var hole := Rect2()
	var anchor: String = str(step.get("anchor", ""))
	if not anchor.is_empty() and _hole_provider.is_valid():
		hole = _hole_provider.call(anchor)
	_dialog.show_step(str(step.get("text", "")), hole)


func _check_all_triggered() -> void:
	if _tutorial_complete_shown:
		return
	for point in ALL_TUTORIAL_POINTS:
		if not _triggered.has(point):
			return
	_tutorial_complete_shown = true
	var step: Variant = TUTORIAL_STEPS.get("tutorial_complete", {})
	if not step.is_empty():
		_dialog_queue.append(step)
		_dialog_active = true
		_show_next()


func _on_dialog_finished() -> void:
	_dialog_active = false
	_show_next()


func _on_skip() -> void:
	_dialog_queue.clear()
	_dialog_active = false
	_tutorial_complete_shown = true
	for key in TUTORIAL_STEPS.keys():
		_triggered[key] = true


func _on_game_started() -> void:
	_trigger("mission_intro")


func _on_monster_card_drawn(_player: Variant, _card: Variant) -> void:
	_trigger("initial_monster_card")


func _on_monster_spawned(_monster: Variant, _player: Variant) -> void:
	_trigger("first_monster_spawn")


func _on_card_drawn(player: Variant, _card: Variant) -> void:
	var in_phase: String = player.get("in_phase") if player != null else ""
	if in_phase == "draw":
		_trigger("first_draw_phase")


func _on_phase_changed(_player: Variant, _old_phase: String, new_phase: String) -> void:
	if new_phase == "action":
		_trigger("action_ap")
		_trigger("action_move")
		_trigger("action_rest")
		_trigger("action_skills")


func _on_sneak_judge_triggered(_player: Variant, _block: Variant) -> void:
	_trigger("first_sneak_judge")


func _on_hunger_changed(_player: Variant, old_value: int, new_value: int) -> void:
	if new_value > old_value:
		_trigger("first_hunger")


func _on_damage_taken(_target: Variant, source: Variant, _amount: int) -> void:
	if source != null and is_instance_valid(source):
		if source.get("monster_type") != null:
			_trigger("first_monster_attack")
