extends Node

## 教程管理器。监听游戏事件，在首次触发时显示教程对话框。
## 仅在 Settings.tutorial_mode 为 true 时激活。

const TUTORIAL_DIALOG_SCENE := preload("res://scenes/TutorialDialog.tscn")

## 所有教程点（用于完成检查）
const ALL_TUTORIAL_POINTS: Array = [
	"mission_intro",
	"initial_monster_card",
	"first_monster_spawn",
	"first_draw_phase",
	"action_phase_intro",
	"player_panel_intro",
	"first_sneak_judge",
	"first_hunger",
	"first_monster_attack",
]

## 教程点内容定义
const TUTORIAL_CONTENT: Dictionary = {
	"mission_intro": [
		"欢迎来到《末日启示录》的世界！",
		"我们需要完成任务目标，才能生存下去。",
		"让我们来学习基本的生存技巧。"
	],
	"initial_monster_card": [
		"游戏开始，因为我们太吵了，吸引来了怪物，所以我们会抓取一张初始怪物牌",
		"怪物牌会纠缠你进入你的怪物区，每当你的回合结束时对你发动攻击。",
		"消灭怪物是生存的关键，别让它们积累太多！"
	],
	"first_monster_spawn": [
		"地图上出现了怪物标记！",
		"当你移动到有怪物标记的地块时，需要进行潜行检定。",
		"潜行成功可以避免战斗，失败则会被怪物发现。"
	],
	"first_draw_phase": [
		"每回合开始时，你会从牌堆摸一张牌。",
		"手牌是你最重要的资源，好好利用它们！"
	],
	"action_phase_intro": [
		"现在进入行动阶段了！让我告诉你都能做些什么。",
		"【移动】想要移动时，点击你的头像或按快捷键 (M)，然后选择目标地块。移动消耗 1 个行动点。",
		"【摸牌】想要摸牌时，点击牌堆并确认。每次摸牌消耗 1 个行动点。",
		"【拾荒】想要拾荒时，点击拾荒牌堆（红/绿/蓝）并确认，可以获得装备和物品。每次拾荒消耗 1 个行动点。",
		"【使用手牌】想要使用手牌时，点击手牌区的卡牌，查看效果后点击确定。",
		"【使用技能】想要使用技能时，点击底部的主动技能按钮，确认后即可释放。",
		"【地图交互】‘鼠标左键’选择地图块并拖拽地图，‘鼠标右键’查看地图块详情，按住‘Ctrl’并滚动‘滚轮’缩放地图大小。"
	],
	"player_panel_intro": [
		"接下来介绍你右边的面板信息，这些数据会帮助你掌握当前状态。",
		"【HP】显示你的当前生命值和最大生命值，归零就意味着死亡。",
		"【潜行】你的潜行检定值，影响潜行检定的成功率。",
		"【饥饿】当前饥饿值，达到 6 时会开始受到递增伤害。",
		"【行动】剩余行动点/最大行动点，行动点用完就只能结束回合了。",
		"【怪物】当前怪物区中的怪物数量，怪物每回合都会攻击你。",
		"【装备】当前装备区中的装备数量。",
		"【手牌】当前手牌数量，注意手牌上限。"
	],
	"first_sneak_judge": [
		"你正在进行潜行检定！",
		"只要投骰结果小于你的潜行值，就可以避免抓取怪物。",
		"潜行失败的话，你可能需要面对战斗。"
	],
	"first_hunger": [
		"饥饿值增加了！由于行动消耗了我们大量体力。",
		"所以每回合我们行动完后会增加 1 点饥饿值",
		"饥饿值达到6时，你会受到递增的伤害。",
		"通过拾荒获取食物可以降低饥饿值。"
	],
	"first_monster_attack": [
		"怪物攻击了你！",
		"你可以使用手牌中的攻击牌消灭怪物，或用防御型装备牌减少伤害。",
		"注意你的生命值，归零就意味着死亡！"
	],
	"tutorial_complete": [
		"恭喜你掌握了所有生存规则！",
		"现在你已经知道了如何移动、摸牌、拾荒、使用手牌和技能。",
		"祝你好运，活下去！"
	],
}

var _triggered: Dictionary = {}
var _dialog_queue: Array = []
var _dialog_active: bool = false
var _dialog: CanvasLayer = null
var _tutorial_complete_shown: bool = false

func start(dialog: CanvasLayer) -> void:
	_dialog = dialog
	_dialog.dialog_finished.connect(_on_dialog_finished)
	_dialog.skip_pressed.connect(_on_skip)
	# 连接 EventBus 信号
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
	var lines: Array = TUTORIAL_CONTENT.get(point_id, [])
	if lines.is_empty():
		return
	_dialog_queue.append(lines)
	if not _dialog_active:
		_show_next()

func _show_next() -> void:
	if _dialog_queue.is_empty():
		_dialog_active = false
		# 检查是否所有教程点都已触发
		_check_all_triggered()
		return
	_dialog_active = true
	var lines: Array = _dialog_queue.pop_front()
	_dialog.show_dialog(lines)

func _check_all_triggered() -> void:
	if _tutorial_complete_shown:
		return
	for point in ALL_TUTORIAL_POINTS:
		if not _triggered.has(point):
			return
	# 所有教程点都已触发，显示恭喜
	_tutorial_complete_shown = true
	var lines: Array = TUTORIAL_CONTENT.get("tutorial_complete", [])
	if not lines.is_empty():
		_dialog_queue.append(lines)
		_dialog_active = true
		_dialog.show_dialog(lines)

func _on_dialog_finished() -> void:
	_dialog_active = false
	_show_next()

func _on_skip() -> void:
	_dialog_queue.clear()
	_dialog_active = false
	_tutorial_complete_shown = true
	# 标记所有教程点为已触发
	for key in TUTORIAL_CONTENT.keys():
		_triggered[key] = true

# === 信号处理 ===

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
		_trigger("action_phase_intro")
		_trigger("player_panel_intro")

func _on_sneak_judge_triggered(_player: Variant, _block: Variant) -> void:
	_trigger("first_sneak_judge")

func _on_hunger_changed(_player: Variant, old_value: int, new_value: int) -> void:
	if new_value > old_value:
		_trigger("first_hunger")

func _on_damage_taken(_target: Variant, source: Variant, _amount: int) -> void:
	if source != null and is_instance_valid(source):
		if source.get("monster_type") != null:
			_trigger("first_monster_attack")
