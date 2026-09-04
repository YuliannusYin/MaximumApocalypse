class_name GameActions
extends RefCounted

## 供数据驱动技能执行嵌套游戏操作的门面。
## 每个方法立即进入 OperationRuntime 栈；调用方由 CodeExecutor 自动等待其完成。
## 旧 JSON 仍可继续使用 await player.*，两套路径可并存以支持渐进迁移。

var player: Variant
var game: Variant
var runtime: OperationRuntime


func _init(owner: Variant, game_instance: Variant, operation_runtime: OperationRuntime = null) -> void:
	player = owner
	game = game_instance
	runtime = operation_runtime if operation_runtime != null else OperationRuntime.new()


func damage(target: Entity, num: int, source: Entity = null, type: Variant = "", card: Card = null) -> Variant:
	## damage() 内部已自行创建 OperationEvent（复用同一 runtime 以保持嵌套），
	## 这里直接转发调用，避免重复包裹出两层同名 "damage" 节点。
	return await target.damage(num, source, type, card, runtime)


func recover(target: Variant, num: int, source: Variant = null) -> Variant:
	return await target.recover(num, source, runtime)


func draw(target: Variant, num: int) -> Variant:
	return await target.draw(num, runtime)


func draw_scavenge(target: Variant, num: int, pile: Pile) -> Variant:
	return await target.draw_scavenge(num, pile, runtime)


func draw_scavenge_card(target: Variant, card: Variant, pile: Pile, event: Dictionary) -> Variant:
	return await target.draw_scavenge_card(card, pile, event, runtime)


func draw_monster(target: Variant, num: int) -> Variant:
	return await target.draw_monster(num, runtime)


func discard(target: Variant, card_or_cards: Variant, position: String = "", quantity: int = 1, type: String = "", silent: bool = false) -> Variant:
	return await target.discard(card_or_cards, position, quantity, type, silent, runtime)


func choose_to_discard(target: Variant, n: int, type: String = "") -> Variant:
	return await target.choose_to_discard(n, type, runtime)


func remove_card(target: Variant, card_or_cards: Variant, position: String = "", quantity: int = 1) -> Variant:
	return await target.remove_card(card_or_cards, position, quantity, runtime)


func move(target: Variant, block: MapBlock) -> Variant:
	return await target.move_to(block, runtime)


func move_to(target: Variant, block: MapBlock) -> Variant:
	return await move(target, block)


func use_card(target: Variant, card: Card) -> Variant:
	return await target.use_card(card, false, runtime, player)


func consume_action(target: Variant, num: int = 1) -> Variant:
	## consume_action_evented 内部已自行创建 OperationEvent（复用同一 runtime 以保持嵌套），
	## 这里直接转发调用，避免重复包裹出两层同名 "consume_action" 节点。
	return await target.consume_action_evented(num, runtime)


func consume_charge(target: Variant, equipment: Variant, num: int = 1) -> Variant:
	return await target.consume_charge(equipment, num, runtime)


func clear_charge(target: Variant, charge_type: String) -> Variant:
	return await target.clear_charge(charge_type, runtime)


func add_charge_to(target: Variant, equipment: Variant, amount: int, type: String) -> Variant:
	return await target.add_charge_to(equipment, amount, type, runtime)


func fill_charge_to(target: Variant, equipment: Variant) -> Variant:
	return await target.fill_charge_to(equipment, runtime)


func fill_charge(equipment: Variant) -> Variant:
	return await runtime.dispatch("fill_charge", func() -> void:
		equipment.fill_charge(), {"equipment": equipment})


func change_charge_type(equipment: Variant, charge_type: String) -> Variant:
	return await runtime.dispatch("change_charge_type", func() -> void:
		equipment.change_charge_type(charge_type), {"equipment": equipment, "charge_type": charge_type})


func add_action(target: Variant, num: int) -> Variant:
	return await target.add_action(num, runtime)


func increase_max_action(target: Variant, num: int) -> Variant:
	return await target.increase_max_action(num, runtime)


func decrease_max_action(target: Variant, num: int) -> Variant:
	return await target.decrease_max_action(num, runtime)


func add_poison(target: Variant, num: int) -> Variant:
	return await target.add_poison(num, runtime)


func add_mark(target: Variant, name: String, num: int = 1, mark_text: String = "", mark_content: String = "", visible: bool = true) -> Variant:
	return await runtime.dispatch("add_mark", func() -> void:
		target.add_mark(name, num, mark_text, mark_content, visible), {"target": target, "name": name, "num": num})


func remove_mark(target: Variant, name: String) -> Variant:
	return await runtime.dispatch("remove_mark", func() -> void:
		target.remove_mark(name), {"target": target, "name": name})


func add_monster_mark(target: Variant, num: int = 1) -> Variant:
	return await runtime.dispatch("add_monster_mark", func() -> void:
		target.add_monster_mark(num), {"target": target, "num": num})


func remove_all_monster_marks(target: Variant) -> Variant:
	return await runtime.dispatch("remove_all_monster_marks", func() -> void:
		target.remove_all_monster_marks(), {"target": target})


func reveal(target: Variant, with_effect: bool, player: Variant) -> Variant:
	return await runtime.dispatch("reveal_block", func() -> void:
		await target.reveal(with_effect, player), {"target": target, "with_effect": with_effect, "player": player})


func equip(target: Variant, card: Variant) -> Variant:
	return await target.equip(card, runtime)


func unequip(target: Variant, equipment: Variant) -> Variant:
	return await target.unequip(equipment, runtime)


func gain(target: Variant, card: Variant) -> Variant:
	return await target.gain(card, runtime)


func heal_all_status(target: Variant) -> Variant:
	return await target.heal_all_status(runtime)


func restore_full_health(target: Variant) -> Variant:
	return await target.restore_full_health(runtime)


func execute_action_immediately(target: Variant, num: int) -> Variant:
	var context: Dictionary = runtime.create_limited_action_context(target, player, num)
	return await runtime.dispatch(
		"execute_action_immediately",
		func() -> Variant:
			return await target.execute_action_immediately(num, runtime),
		{"target": target, "num": num},
		target,
		player,
		"limited_action",
		{"free_action": true, "action_count": num},
		context
	)


func play_card_immediately(target: Variant, max_cards: int = 1) -> Variant:
	return await runtime.dispatch(
		"play_card_immediately",
		func() -> Variant:
			return await target.play_card_immediately(max_cards, runtime),
		{"target": target, "max_cards": max_cards},
		target,
		player,
		"limited_card_use",
		{"free_action": true, "max_cards": max_cards}
	)


func end_phase(target: Variant, phase: String) -> Variant:
	return await runtime.dispatch("end_phase", func() -> void:
		target.end_phase(phase), {"target": target, "phase": phase})


func mount_sub_skill(target: Variant, skill_name: String) -> Variant:
	return await runtime.dispatch("mount_sub_skill", func() -> void:
		target.mount_sub_skill(skill_name), {"target": target, "skill_name": skill_name})


func add_temp_skill(target: Variant, skill_name: String, expire_trigger: String) -> Variant:
	return await runtime.dispatch("add_temp_skill", func() -> void:
		target.add_temp_skill(skill_name, expire_trigger), {"target": target, "skill_name": skill_name})


func add_mark_skill(target: Variant, name: String, num: int, expire_trigger: String, mark_text: String, mark_content: String, visible: bool = true) -> Variant:
	return await runtime.dispatch("add_mark_skill", func() -> void:
		target.add_mark_skill(name, num, expire_trigger, mark_text, mark_content, visible), {"target": target, "name": name})


func increase_hunger(target: Variant, num: int = 1) -> Variant:
	return await target.increase_hunger_evented(num, runtime)


func decrease_hunger(target: Variant, num: int = 1) -> Variant:
	return await target.decrease_hunger_evented(num, runtime)


func poison(target: Variant) -> Variant:
	return await target.poison_evented(runtime)


func stun(target: Variant, source: Variant, expire_trigger: String) -> Variant:
	return await target.stun_evented(source, expire_trigger, runtime)


func change_engaged_target(monster: Variant, target: Variant) -> Variant:
	return await runtime.dispatch("change_engaged_target", func() -> bool:
		return await monster.change_engaged_target_evented(target), {
			"monster": monster, "target": target,
		})


func destroy_block(source: Variant, block: MapBlock) -> Variant:
	## 注意：沿用既有调用顺序 (source, block) 传入 destroy_map_block(block, source)，
	## 与迁移前行为保持一致，不在本次迁移中调整参数顺序。
	return await game.destroy_map_block(source, block, runtime)


func flush() -> void:
	await runtime.flush()
