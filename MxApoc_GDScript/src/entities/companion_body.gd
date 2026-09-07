class_name CompanionBody
extends Entity

## 同一座位上的子生命体（老兵 / 狗）。
## 独立生命、饥饿、角色卡翻面与潜行；手牌 / 装备 / 回合仍在所属 Player 上。

var hp: int = 0
var max_hp: int = 0
var hunger: int = 1
var stealth: int = 0
var role_card: RoleCard = null
var owner_player = null
var english_name: String = ""
var player_name: String = ""


func setup_from_survivor(data: SurvivorData, owner) -> void:
	owner_player = owner
	english_name = data.english_name
	player_name = data.character_name
	max_hp = data.max_hp
	hp = data.initial_hp
	hunger = 1
	role_card = RoleCard.new()
	role_card.role_name = data.character_name
	role_card.english_name = data.english_name
	role_card.max_hp = data.max_hp
	role_card.initial_hp = data.initial_hp
	role_card.sneak = data.stealth
	role_card.hunger_sneak = data.hunger_stealth
	role_card.equipment_capacity = data.equipment_slot
	role_card.hand_size_limit = data.hand_size_limit


func is_player() -> bool:
	return true


func is_companion_body() -> bool:
	return true


func is_alive() -> bool:
	return hp > 0


func get_seat_player() -> Variant:
	return owner_player


func get_owner_player():
	return owner_player


func get_current_block() -> MapBlock:
	if owner_player == null:
		return null
	return owner_player.get_current_block()


func get_hp() -> int:
	return hp


func get_max_hp() -> int:
	return max_hp


func reduce_hp(n: int) -> void:
	var old_value: int = hp
	hp = maxi(hp - n, 0)
	if hp != old_value and EventBus != null and is_instance_valid(EventBus):
		EventBus.player_hp_changed.emit(self, old_value, hp)
		if owner_player != null:
			EventBus.player_hp_changed.emit(owner_player, old_value, hp)


func add_hp(n: int) -> void:
	var old_value: int = hp
	hp = mini(hp + n, max_hp)
	if hp != old_value and EventBus != null and is_instance_valid(EventBus):
		EventBus.player_hp_changed.emit(self, old_value, hp)
		if owner_player != null:
			EventBus.player_hp_changed.emit(owner_player, old_value, hp)


func get_sneak() -> int:
	if role_card != null:
		return stealth + role_card.get_sneak()
	return stealth


func get_hand_size_limit() -> int:
	if role_card != null:
		return role_card.hand_size_limit
	return 0


func get_equipment_capacity() -> int:
	if role_card != null:
		return role_card.equipment_capacity
	return 0


func increase_hunger(num: int, runtime: Variant = null) -> void:
	if num <= 0:
		return
	var old_hunger: int = hunger
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 增加了 " + str(num) + " 点饥饿值")
	while num > 0:
		if hunger < 6:
			hunger += 1
			if hunger == 6:
				if role_card != null and role_card.is_front():
					role_card.flip()
				var _new_hunger_level: int = count_mark("hunger_damage_level") + 1
				add_mark("hunger_damage_level", 1, "饥饿", "饥饿伤害等级" + str(_new_hunger_level) + ", 饥饿结算时受到 " + str(_new_hunger_level * 2) + "点饥饿伤害")
		elif hunger == 6:
			if role_card != null and role_card.is_front():
				role_card.flip()
			var _new_hunger_level: int = count_mark("hunger_damage_level") + 1
			add_mark("hunger_damage_level", 1, "饥饿", "饥饿伤害等级" + str(_new_hunger_level) + ", 饥饿结算时受到 " + str(_new_hunger_level * 2) + "点饥饿伤害")
		if count_mark("hunger_damage_level") > 0:
			var level: int = count_mark("hunger_damage_level")
			if level == 1:
				await damage(2, null, "hunger", null, runtime)
			elif level == 2:
				await damage(4, null, "hunger", null, runtime)
			elif level == 3:
				await damage(6, null, "hunger", null, runtime)
			elif level == 4:
				await damage(8, null, "hunger", null, runtime)
			elif level >= 5:
				if Game != null and is_instance_valid(Game):
					Game.log_message(LogColors.player(player_name) + " 被饿死了")
				await damage(get_max_hp(), null, "hunger", null, runtime)
		num -= 1
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_hunger_changed.emit(self, old_hunger, hunger)
		if owner_player != null:
			EventBus.player_hunger_changed.emit(owner_player, old_hunger, hunger)


func increase_hunger_evented(num: int, runtime: Variant = null) -> bool:
	var rt: Variant = runtime if runtime != null else Game.event_scheduler
	return await rt.dispatch("increase_hunger", func() -> bool:
		var event: GameEvent = EventSystem.create_hunger_event(self, num, "increase")
		await trigger("before_increase_hunger", event)
		if EventSystem.is_cancelled(event):
			return false
		await trigger("on_increase_hunger", event)
		if EventSystem.is_cancelled(event):
			return false
		await increase_hunger(event["num"], rt)
		await trigger("after_increase_hunger", event)
		return true,
		{"target": self, "num": num})


func decrease_hunger(num: int) -> void:
	if num <= 0:
		return
	var max_reduce: int = hunger - 1
	if num > max_reduce:
		num = max_reduce
	if num <= 0:
		return
	var old_hunger: int = hunger
	hunger -= num
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 减少了 " + str(num) + " 点饥饿值")
	if count_mark("hunger_damage_level") > 0:
		remove_mark("hunger_damage_level")
	if role_card != null and not role_card.is_front():
		role_card.flip()
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.hunger_reduced.emit(self, num)
		EventBus.player_hunger_changed.emit(self, old_hunger, hunger)
		if owner_player != null:
			EventBus.player_hunger_changed.emit(owner_player, old_hunger, hunger)


func decrease_hunger_evented(num: int, runtime: Variant = null) -> bool:
	var rt: Variant = runtime if runtime != null else Game.event_scheduler
	return await rt.dispatch("decrease_hunger", func() -> bool:
		var event: GameEvent = EventSystem.create_hunger_event(self, num, "decrease")
		await trigger("before_decrease_hunger", event)
		if EventSystem.is_cancelled(event):
			return false
		await trigger("on_decrease_hunger", event)
		if EventSystem.is_cancelled(event):
			return false
		decrease_hunger(event["num"])
		await trigger("after_decrease_hunger", event)
		return true,
		{"target": self, "num": num})


## 中毒等座位级标记落到所属玩家；饥饿伤害等级留在本身体上。
func add_mark(name: String, quantity: int = 1, mark_text: String = "", mark_content: String = "", visible: bool = true) -> void:
	if name != "hunger_damage_level" and owner_player != null:
		owner_player.add_mark(name, quantity, mark_text, mark_content, visible)
		return
	super.add_mark(name, quantity, mark_text, mark_content, visible)


func add_mark_skill(name: String, n: int = 1, expire_trigger: String = "", mark_text: String = "", mark_content: String = "", visible: bool = true) -> void:
	if name != "hunger_damage_level" and owner_player != null:
		owner_player.add_mark_skill(name, n, expire_trigger, mark_text, mark_content, visible)
		return
	super.add_mark_skill(name, n, expire_trigger, mark_text, mark_content, visible)


func death(source: Entity, runtime: Variant = null) -> void:
	var rt: Variant = runtime if runtime != null else Game.event_scheduler
	await rt.dispatch("companion_death", func() -> void:
		hp = 0
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 死亡了")
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.player_hp_changed.emit(self, 1, 0)
			if owner_player != null:
				EventBus.player_hp_changed.emit(owner_player, 1, 0)
		if owner_player != null and is_instance_valid(owner_player):
			await owner_player.on_companion_body_died(self, source, rt)
	, {"target": self, "source": source})
