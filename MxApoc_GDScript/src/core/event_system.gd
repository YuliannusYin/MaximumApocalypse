class_name EventSystem
extends RefCounted

## 事件触发系统工具类。
## 提供 event Dictionary 的构建工厂与取消机制。
## event schema 见 GameDesignDocus/GameSystem/Core/EventSystem.md §2。
## 字段键名严格遵循 IdentifierMapping.md §六。
##
## 统一事件树：每个 event 额外携带 id/parent/root/children/game_event，
## 与领域操作、Player 的正式回合事件共享同一套
## GameEvent 生命周期字段（见 game_event.gd）。详见 .cursor/plan/plan.md “最终架构”。

const GameEventScript = preload("res://src/core/game_event.gd")

## 创建通用 event：注入 cancelled 标记与 cancel 可调用对象，
## 并挂接统一事件树节点元数据（id/parent/root/children/game_event）。
## 各流程工厂方法在此基础上追加流程专属字段。
## cancel 用法：event["cancel"].call() 或 EventSystem.cancel(event)。
static func create_event(initial: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {
		"trigger_name": "",
		"cancelled": false,
	}
	# 注入 cancel 闭包：捕获 event 引用，调用后置 cancelled = true
	# 注意 GDScript Dictionary 为引用类型，lambda 捕获的引用指向同一字典
	event["cancel"] = (func(ev: Dictionary) -> Callable:
		return func() -> void:
			ev["cancelled"] = true
	).call(event)
	# 合并调用方传入的初始字段
	for key in initial:
		event[key] = initial[key]
	var node: Variant = GameEventScript.new(
		str(event.get("type", "")), event.get("owner", null), event.get("source", null)
	)
	event["id"] = node.id
	node.context = event.get("context", null)
	var parent_event: Variant = event.get("parent", null)
	var parent_node: Variant = null
	if parent_event is Dictionary:
		parent_node = parent_event.get("game_event", null)
		event["root"] = parent_event.get("root", parent_event.get("id", event["id"]))
		var siblings: Array = parent_event.get("children", [])
		siblings.append(event["id"])
		parent_event["children"] = siblings
	else:
		if not event.has("root"):
			event["root"] = event["id"]
		if not event.has("children"):
			event["children"] = []
	if parent_node is GameEventScript:
		parent_node.add_child(node)
	else:
		var scheduler: Variant = Game.event_scheduler if Game != null and is_instance_valid(Game) else null
		var current: Variant = scheduler.get_current_event() if scheduler != null else null
		if current != null:
			current.add_child(node)
		event["root"] = node.root
	if not event.has("children"):
		event["children"] = []
	event["game_event"] = node
	return event


## 取消事件：设置 cancelled = true。
## 技能 content 内可调用 EventSystem.cancel(event) 或直接 event["cancel"].call()。
static func cancel(event: Dictionary) -> void:
	event["cancelled"] = true
	var node: Variant = event.get("game_event", null)
	if node is GameEventScript:
		node.cancel()


## 是否已取消。
static func is_cancelled(event: Dictionary) -> bool:
	if event.get("cancelled", false):
		return true
	var node: Variant = event.get("game_event", null)
	return node is GameEventScript and node.status == GameEventScript.Status.CANCELLED


## 设置当前触发名。
static func set_trigger_name(event: Dictionary, trigger_name: String) -> void:
	event["trigger_name"] = trigger_name


# === 伤害流程 event ===
static func create_damage_event(target: Entity, source: Entity, num: int, type: Variant, card: Card = null) -> Dictionary:
	return create_event({
		"target": target,
		"source": source,
		"num": num,
		"type": type,
		"card": card,
	})


# === 回复生命 event ===
static func create_recover_event(player: Variant, num: int) -> Dictionary:
	return create_event({
		"player": player,
		"num": num,
	})


# === 移动流程 event ===
static func create_move_event(player: Variant, source_block: MapBlock, target_block: MapBlock) -> Dictionary:
	return create_event({
		"player": player,
		"source_block": source_block,
		"target_block": target_block,
	})


# === 抓游戏牌 event ===
static func create_draw_game_card_event(player: Variant, num: int) -> Dictionary:
	return create_event({
		"player": player,
		"num": num,
		"cards": [],
	})


# === 抓拾荒牌 event ===
static func create_draw_scavenge_event(player: Variant, pile: Pile, num: int) -> Dictionary:
	return create_event({
		"player": player,
		"pile": pile,
		"num": num,
		"cards": [],
		"card": null,
	})


# === 抓怪物卡 event ===
static func create_draw_monster_event(player: Variant, num: int) -> Dictionary:
	return create_event({
		"player": player,
		"num": num,
		"cards": [],
		"card": null,
	})


# === 弃置/销毁牌 event ===
static func create_discard_event(player: Variant, cards: Array, num: int = 1) -> Dictionary:
	return create_event({
		"player": player,
		"card": null,
		"cards": cards,
		"num": num,
	})


# === 怪物死亡 event ===
static func create_monster_death_event(target: Entity, source: Entity) -> Dictionary:
	return create_event({
		"target": target,
		"source": source,
	})


# === 玩家死亡 event ===
static func create_player_death_event(target: Variant, source: Variant) -> Dictionary:
	return create_event({
		"target": target,
		"source": source,
	})


# === 装备进入/离开 event ===
static func create_equip_event(player: Variant, card: Card) -> Dictionary:
	return create_event({
		"player": player,
		"card": card,
	})


# === 消耗填充物 event ===
static func create_consume_charge_event(player: Variant, equipment: Variant, num: int) -> Dictionary:
	return create_event({
		"player": player,
		"card": equipment,
		"num": num,
	})


# === 潜行检定 event ===
static func create_sneak_judge_event(player: Variant, sneak_value: int, block: Variant = null) -> Dictionary:
	return create_event({
		"player": player,
		"block": block,
		"sneak_value": sneak_value,
		"result": {"value": 0, "success": false},
		"skip_judge": false,
	})


# === 怪物出生检定 event ===
static func create_spawn_judge_event(player: Variant) -> Dictionary:
	return create_event({
		"player": player,
		"result": {"value": 0, "success": true},
		"skip_judge": false,
	})


# === 摧毁地块 event ===
static func create_destroy_block_event(source: Variant, block: MapBlock) -> Dictionary:
	return create_event({
		"source": source,
		"block": block,
	})


# === 触发目标标记 event ===
static func create_objective_mark_event(player: Variant, block: MapBlock, mark: Dictionary) -> Dictionary:
	return create_event({
		"player": player,
		"block": block,
		"mark": mark,
	})


# === 主动技能 event ===
static func create_active_skill_event(player: Variant, targets: Array) -> Dictionary:
	return create_event({
		"player": player,
		"targets": targets,
	})


# === 行动次数与状态结算 event ===
static func create_consume_action_event(player: Variant, num: int) -> Dictionary:
	return create_event({"player": player, "num": num})


static func create_hunger_event(player: Variant, num: int, direction: String) -> Dictionary:
	return create_event({"player": player, "num": num, "direction": direction})


static func create_poison_event(player: Variant, num: int) -> Dictionary:
	return create_event({"player": player, "num": num})


static func create_engaged_target_event(monster: Variant, target: Variant) -> Dictionary:
	return create_event({"monster": monster, "target": target})


static func create_stun_event(monster: Variant, source: Variant, expire_trigger: String) -> Dictionary:
	return create_event({
		"monster": monster, "source": source, "expire_trigger": expire_trigger,
	})


# === 游戏开始/结束 event ===
static func create_game_start_event(player: Variant) -> Dictionary:
	return create_event({"player": player})


static func create_game_over_event(player: Variant, result: int) -> Dictionary:
	return create_event({"player": player, "result": result})


# === 怪物行动 event ===
static func create_monster_act_event(monster: Monster) -> Dictionary:
	return create_event({
		"monster": monster,
		"target_players": [],
	})


# === 内部：Dictionary 上无法挂方法，提供独立的取消闭包工厂 ===
# 由于 GDScript 的 Dictionary 不支持方法调用，event["cancel"] 实际是一个
# 引用 event 的 Callable。这里用静态函数返回闭包。
static func _make_cancel_callable(event: Dictionary) -> Callable:
	return func() -> void:
		event["cancelled"] = true
