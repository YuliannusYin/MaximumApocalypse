class_name GameActions
extends RefCounted

## 供数据驱动技能登记游戏操作的门面。
## 方法只登记，不立即执行；Skill.execute_content() 返回前会自动排空队列。
## 旧 JSON 仍可继续使用 await player.*，两套路径可并存以支持渐进迁移。

var player: Variant
var game: Variant
var runtime: OperationRuntime


func _init(owner: Variant, game_instance: Variant, operation_runtime: OperationRuntime = null) -> void:
	player = owner
	game = game_instance
	runtime = operation_runtime if operation_runtime != null else OperationRuntime.new()


func damage(target: Entity, num: int, source: Entity = null, type: Variant = "", card: Card = null) -> Dictionary:
	return runtime.enqueue("damage", func() -> void:
		await target.damage(num, source, type, card), {
			"target": target, "source": source, "num": num, "type": type, "card": card,
		})


func recover(target: Variant, num: int, source: Variant = null) -> Dictionary:
	return runtime.enqueue("recover", func() -> void:
		await target.recover(num, source), {"target": target, "source": source, "num": num})


func draw(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("draw_game_card", func() -> void:
		await target.draw(num), {"target": target, "num": num})


func draw_scavenge(target: Variant, num: int, pile: Pile) -> Dictionary:
	return runtime.enqueue("draw_scavenge_card", func() -> void:
		await target.draw_scavenge(num, pile), {"target": target, "num": num, "pile": pile})


func draw_scavenge_card(target: Variant, card: Variant, pile: Pile, event: Dictionary) -> Dictionary:
	return runtime.enqueue("draw_scavenge_card_single", func() -> void:
		await target.draw_scavenge_card(card, pile, event), {"target": target, "card": card, "pile": pile})


func draw_monster(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("draw_monster_card", func() -> void:
		await target.draw_monster(num), {"target": target, "num": num})


func discard(target: Variant, card_or_cards: Variant, position: String = "", quantity: int = 1, type: String = "", silent: bool = false) -> Dictionary:
	return runtime.enqueue("discard", func() -> void:
		await target.discard(card_or_cards, position, quantity, type, silent), {
			"target": target, "cards": card_or_cards, "position": position, "quantity": quantity,
		})


func remove_card(target: Variant, card_or_cards: Variant, position: String = "", quantity: int = 1) -> Dictionary:
	return runtime.enqueue("remove_card", func() -> void:
		await target.remove_card(card_or_cards, position, quantity), {
			"target": target, "cards": card_or_cards, "position": position, "quantity": quantity,
		})


func move(target: Variant, block: MapBlock) -> Dictionary:
	return runtime.enqueue("move", func() -> bool:
		return await target.move_to(block), {"target": target, "block": block})


func move_to(target: Variant, block: MapBlock) -> Dictionary:
	return move(target, block)


func use_card(target: Variant, card: Card) -> Dictionary:
	return runtime.enqueue("use_card", func() -> bool:
		return await target.use_card(card), {"target": target, "card": card})


func consume_action(target: Variant, num: int = 1) -> Dictionary:
	return runtime.enqueue("consume_action", func() -> void:
		await target.consume_action_evented(num), {"target": target, "num": num})


func consume_charge(target: Variant, equipment: Variant, num: int = 1) -> Dictionary:
	return runtime.enqueue("consume_charge", func() -> bool:
		return await target.consume_charge(equipment, num), {"target": target, "equipment": equipment, "num": num})


func clear_charge(target: Variant, charge_type: String) -> Dictionary:
	return runtime.enqueue("clear_charge", func() -> void:
		await target.clear_charge(charge_type), {"target": target, "charge_type": charge_type})


func add_charge_to(target: Variant, equipment: Variant, amount: int, type: String) -> Dictionary:
	return runtime.enqueue("add_charge", func() -> void:
		target.add_charge_to(equipment, amount, type), {"target": target, "equipment": equipment, "amount": amount})


func fill_charge_to(target: Variant, equipment: Variant) -> Dictionary:
	return runtime.enqueue("fill_charge", func() -> void:
		target.fill_charge_to(equipment), {"target": target, "equipment": equipment})


func fill_charge(equipment: Variant) -> Dictionary:
	return runtime.enqueue("fill_charge", func() -> void:
		equipment.fill_charge(), {"equipment": equipment})


func change_charge_type(equipment: Variant, charge_type: String) -> Dictionary:
	return runtime.enqueue("change_charge_type", func() -> void:
		equipment.change_charge_type(charge_type), {"equipment": equipment, "charge_type": charge_type})


func add_action(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("add_action", func() -> void:
		target.add_action(num), {"target": target, "num": num})


func increase_max_action(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("increase_max_action", func() -> void:
		target.increase_max_action(num), {"target": target, "num": num})


func decrease_max_action(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("decrease_max_action", func() -> void:
		target.decrease_max_action(num), {"target": target, "num": num})


func add_poison(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("add_poison", func() -> void:
		target.add_poison(num), {"target": target, "num": num})


func add_mark(target: Variant, name: String, num: int = 1, mark_text: String = "", mark_content: String = "", visible: bool = true) -> Dictionary:
	return runtime.enqueue("add_mark", func() -> void:
		target.add_mark(name, num, mark_text, mark_content, visible), {"target": target, "name": name, "num": num})


func remove_mark(target: Variant, name: String) -> Dictionary:
	return runtime.enqueue("remove_mark", func() -> void:
		target.remove_mark(name), {"target": target, "name": name})


func add_monster_mark(target: Variant, num: int = 1) -> Dictionary:
	return runtime.enqueue("add_monster_mark", func() -> void:
		target.add_monster_mark(num), {"target": target, "num": num})


func remove_all_monster_marks(target: Variant) -> Dictionary:
	return runtime.enqueue("remove_all_monster_marks", func() -> void:
		target.remove_all_monster_marks(), {"target": target})


func reveal(target: Variant, with_effect: bool, player: Variant) -> Dictionary:
	return runtime.enqueue("reveal_block", func() -> void:
		await target.reveal(with_effect, player), {"target": target, "with_effect": with_effect, "player": player})


func equip(target: Variant, card: Variant) -> Dictionary:
	return runtime.enqueue("equip", func() -> bool:
		return await target.equip(card), {"target": target, "card": card})


func unequip(target: Variant, equipment: Variant) -> Dictionary:
	return runtime.enqueue("unequip", func() -> bool:
		return await target.unequip(equipment), {"target": target, "equipment": equipment})


func gain(target: Variant, card: Variant) -> Dictionary:
	return runtime.enqueue("gain", func() -> void:
		await target.gain(card), {"target": target, "card": card})


func heal_all_status(target: Variant) -> Dictionary:
	return runtime.enqueue("heal_all_status", func() -> void:
		target.heal_all_status(), {"target": target})


func restore_full_health(target: Variant) -> Dictionary:
	return runtime.enqueue("restore_full_health", func() -> void:
		target.hp = target.max_hp, {"target": target})


func execute_action_immediately(target: Variant, num: int) -> Dictionary:
	return runtime.enqueue("execute_action_immediately", func() -> void:
		await target.execute_action_immediately(num), {"target": target, "num": num})


func play_card_immediately(target: Variant) -> Dictionary:
	return runtime.enqueue("play_card_immediately", func() -> void:
		await target.play_card_immediately(), {"target": target})


func end_phase(target: Variant, phase: String) -> Dictionary:
	return runtime.enqueue("end_phase", func() -> void:
		target.end_phase(phase), {"target": target, "phase": phase})


func mount_sub_skill(target: Variant, skill_name: String) -> Dictionary:
	return runtime.enqueue("mount_sub_skill", func() -> void:
		target.mount_sub_skill(skill_name), {"target": target, "skill_name": skill_name})


func add_temp_skill(target: Variant, skill_name: String, expire_trigger: String) -> Dictionary:
	return runtime.enqueue("add_temp_skill", func() -> void:
		target.add_temp_skill(skill_name, expire_trigger), {"target": target, "skill_name": skill_name})


func add_mark_skill(target: Variant, name: String, num: int, expire_trigger: String, mark_text: String, mark_content: String, visible: bool = true) -> Dictionary:
	return runtime.enqueue("add_mark_skill", func() -> void:
		target.add_mark_skill(name, num, expire_trigger, mark_text, mark_content, visible), {"target": target, "name": name})


func increase_hunger(target: Variant, num: int = 1) -> Dictionary:
	return runtime.enqueue("increase_hunger", func() -> bool:
		return await target.increase_hunger_evented(num), {"target": target, "num": num})


func decrease_hunger(target: Variant, num: int = 1) -> Dictionary:
	return runtime.enqueue("decrease_hunger", func() -> bool:
		return await target.decrease_hunger_evented(num), {"target": target, "num": num})


func poison(target: Variant) -> Dictionary:
	return runtime.enqueue("poison", func() -> bool:
		return await target.poison_evented(), {"target": target})


func stun(target: Variant, source: Variant, expire_trigger: String) -> Dictionary:
	return runtime.enqueue("stun", func() -> bool:
		return await target.stun_evented(source, expire_trigger), {
			"target": target, "source": source, "expire_trigger": expire_trigger,
		})


func change_engaged_target(monster: Variant, target: Variant) -> Dictionary:
	return runtime.enqueue("change_engaged_target", func() -> bool:
		return await monster.change_engaged_target_evented(target), {
			"monster": monster, "target": target,
		})


func destroy_block(source: Variant, block: MapBlock) -> Dictionary:
	return runtime.enqueue("destroy_block", func() -> void:
		await game.destroy_map_block(source, block), {"source": source, "block": block})


func flush() -> void:
	await runtime.flush()
