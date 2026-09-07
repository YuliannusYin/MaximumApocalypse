class_name EventSystem
extends RefCounted

## 事件触发系统工具类。
## 工厂返回 GameEvent；流程字段在 data 里，JSON 仍用 event.num / event.get / event["cancel"]。
## 临时 Dictionary（测试、任务 EventBus）仍可交给 cancel / trigger。
## schema 见 EventSystem.md；调度见 EventScheduler.md。

const GameEventScript = preload("res://src/core/game_event.gd")
const _META_KEYS: Array[String] = ["cancel", "game_event", "id", "root", "children", "parent"]


## 创建流程事件。无显式 parent 时挂到当前 scheduler 事件。
## cancel：event["cancel"].call() 或 EventSystem.cancel(event)。
static func create_event(initial: Dictionary = {}) -> GameEvent:
	var payload_type: Variant = initial.get("type", "")
	var node: GameEvent = GameEvent.new(
		payload_type if payload_type is String else str(payload_type),
		initial.get("owner", null),
		initial.get("source", null)
	)
	node.trigger_name = str(initial.get("trigger_name", ""))
	node.context = initial.get("context", null)
	node.data["trigger_name"] = node.trigger_name
	node.data["cancelled"] = false
	for key in initial:
		if key in _META_KEYS or key == "status":
			continue
		node.data[key] = initial[key]
	if initial.has("type"):
		node.data["type"] = initial["type"]
		node.type = initial["type"] if initial["type"] is String else str(initial["type"])
	var parent_event: Variant = initial.get("parent", null)
	var parent_node: Variant = null
	if parent_event is GameEventScript:
		parent_node = parent_event
	elif parent_event is Dictionary:
		parent_node = parent_event.get("game_event", null)
	if parent_node is GameEventScript:
		parent_node.add_child(node)
	else:
		var scheduler: Variant = Game.event_scheduler if Game != null and is_instance_valid(Game) else null
		var current: Variant = scheduler.get_current_event() if scheduler != null else null
		if current != null:
			current.add_child(node)
	return node


## 取消事件。接受 Dictionary 或 GameEvent。
static func cancel(event: Variant) -> void:
	if event is GameEventScript:
		event.mark_cancelled()
		event.data["cancelled"] = true
		return
	if event is Dictionary:
		event["cancelled"] = true
		var node: Variant = event.get("game_event", null)
		if node is GameEventScript:
			node.mark_cancelled()
			node.data["cancelled"] = true


## 是否已取消。
static func is_cancelled(event: Variant) -> bool:
	if event is GameEventScript:
		return event.status == GameEventScript.Status.CANCELLED or bool(event.data.get("cancelled", false))
	if event is Dictionary:
		if event.get("cancelled", false):
			return true
		var node: Variant = event.get("game_event", null)
		return node is GameEventScript and (
			node.status == GameEventScript.Status.CANCELLED or bool(node.data.get("cancelled", false))
		)
	return false


## 设置当前触发名。
static func set_trigger_name(event: Variant, trigger_name: String) -> void:
	if event is GameEventScript:
		event.trigger_name = trigger_name
		event.data["trigger_name"] = trigger_name
		return
	if event is Dictionary:
		event["trigger_name"] = trigger_name
		var node: Variant = event.get("game_event", null)
		if node is GameEventScript:
			node.trigger_name = trigger_name
			node.data["trigger_name"] = trigger_name


## 技能四参直接使用传入对象（工厂已是 GameEvent；测试里也可能是临时 Dictionary）。
static func skill_event(event: Variant) -> Variant:
	return event


static func restore_event(_event: Variant) -> void:
	pass


## 读流程字段。静态脚本不能对 GameEvent 使用 get(key, default)（Object.get 只接受 1 个参数）。
static func get_field(event: Variant, key: String, default: Variant = null) -> Variant:
	if event == null:
		return default
	if event is Dictionary:
		return event.get(key, default)
	if event is GameEventScript:
		return event.get_or(key, default)
	return default


# === 伤害流程 event ===
static func create_damage_event(target: Entity, source: Entity, num: int, type: Variant, card: Card = null) -> GameEvent:
	return create_event({
		"target": target,
		"source": source,
		"num": num,
		"type": type,
		"card": card,
	})


# === 回复生命 event ===
static func create_recover_event(player: Variant, num: int, source: Variant = null) -> GameEvent:
	return create_event({
		"player": player,
		"num": num,
		"source": source,
	})


# === 移动流程 event ===
static func create_move_event(player: Variant, source_block: MapBlock, target_block: MapBlock) -> GameEvent:
	return create_event({
		"player": player,
		"source_block": source_block,
		"target_block": target_block,
	})


# === 抓游戏牌 event ===
static func create_draw_game_card_event(player: Variant, num: int) -> GameEvent:
	return create_event({
		"player": player,
		"num": num,
		"cards": [],
	})


# === 抓拾荒牌 event ===
static func create_draw_scavenge_event(player: Variant, pile: Pile, num: int) -> GameEvent:
	return create_event({
		"player": player,
		"pile": pile,
		"num": num,
		"cards": [],
		"card": null,
	})


# === 抓怪物卡 event ===
static func create_draw_monster_event(player: Variant, num: int) -> GameEvent:
	return create_event({
		"player": player,
		"num": num,
		"cards": [],
		"card": null,
	})


# === 弃置/销毁牌 event ===
static func create_discard_event(player: Variant, cards: Array, num: int = 1) -> GameEvent:
	return create_event({
		"player": player,
		"card": null,
		"cards": cards,
		"num": num,
	})


# === 怪物死亡 event ===
static func create_monster_death_event(target: Entity, source: Entity) -> GameEvent:
	return create_event({
		"target": target,
		"source": source,
	})


# === 玩家死亡 event ===
static func create_player_death_event(target: Variant, source: Variant) -> GameEvent:
	return create_event({
		"target": target,
		"source": source,
	})


# === 装备进入/离开 event ===
static func create_equip_event(player: Variant, card: Card) -> GameEvent:
	return create_event({
		"player": player,
		"card": card,
	})


# === 消耗填充物 event ===
static func create_consume_charge_event(player: Variant, equipment: Variant, num: int) -> GameEvent:
	return create_event({
		"player": player,
		"card": equipment,
		"num": num,
	})


# === 潜行检定 event ===
static func create_sneak_judge_event(player: Variant, sneak_value: int, block: Variant = null) -> GameEvent:
	return create_event({
		"player": player,
		"block": block,
		"sneak_value": sneak_value,
		"result": {"value": 0, "success": false},
		"skip_judge": false,
	})


# === 怪物出生检定 event ===
static func create_spawn_judge_event(player: Variant) -> GameEvent:
	return create_event({
		"player": player,
		"result": {"value": 0, "success": true},
		"skip_judge": false,
	})


# === 摧毁地块 event ===
static func create_destroy_block_event(source: Variant, block: MapBlock) -> GameEvent:
	return create_event({
		"source": source,
		"block": block,
	})


# === 触发目标标记 event ===
static func create_objective_mark_event(player: Variant, block: MapBlock, mark: Dictionary) -> GameEvent:
	return create_event({
		"player": player,
		"block": block,
		"mark": mark,
	})


# === 主动技能 event ===
static func create_active_skill_event(player: Variant, targets: Array) -> GameEvent:
	return create_event({
		"player": player,
		"targets": targets,
	})


# === 行动次数与状态结算 event ===
static func create_consume_action_event(player: Variant, num: int) -> GameEvent:
	return create_event({"player": player, "num": num})


static func create_hunger_event(player: Variant, num: int, direction: String) -> GameEvent:
	return create_event({"player": player, "num": num, "direction": direction})


static func create_poison_event(player: Variant, num: int) -> GameEvent:
	return create_event({"player": player, "num": num})


static func create_engaged_target_event(monster: Variant, target: Variant) -> GameEvent:
	return create_event({"monster": monster, "target": target})


static func create_stun_event(monster: Variant, source: Variant, expire_trigger: String) -> GameEvent:
	return create_event({
		"monster": monster, "source": source, "expire_trigger": expire_trigger,
	})


# === 游戏开始/结束 event ===
static func create_game_start_event(player: Variant) -> GameEvent:
	return create_event({"player": player})


static func create_game_over_event(player: Variant, result: int) -> GameEvent:
	return create_event({"player": player, "result": result})


# === 怪物行动 event ===
static func create_monster_act_event(monster: Monster) -> GameEvent:
	return create_event({
		"monster": monster,
		"target_players": [],
	})


