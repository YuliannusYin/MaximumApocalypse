class_name Entity
extends RefCounted

## 实体基类。
## 所有可挂载技能、可触发事件的实体的基类。
## 继承关系：Entity ← Player / Monster / Card / MapBlock。
## 设计文档：GameDesignDocus/GameSystem/Core/Entity.md

## 挂载在该实体上的所有技能（角色固有/装备/地块/临时）
var skills: Array[Skill] = []


# === 1. 事件触发 ===

## 遍历实体上所有匹配 trigger_name 的技能，依次执行。
## 技能 content 执行时可通过 event 访问流程参数；
## 若 trigger 为取消点，技能可调用 event["cancel"].call() 或 EventSystem.cancel(event) 终止流程。
func trigger(trigger_name: String, event: Dictionary) -> void:
	EventSystem.set_trigger_name(event, trigger_name)
	# 迭代副本：技能 content 可能挂载/移除技能（如燃料 on_draw 调用 equip），
	# 避免新挂载的同触发器技能在当前迭代中重复触发导致死循环。
	for s in skills.duplicate():
		if not s.matches_trigger(trigger_name):
			continue
		if not s.execute_filter(self, event):
			continue
		# 输出触发日志
		if Game != null and is_instance_valid(Game):
			var _trigger_actor: Variant = self
			if has_method("is_monster") and is_monster() and event.has("player"):
				_trigger_actor = event["player"]
			var _actor_name: String = ""
			if _trigger_actor.has_method("is_player") and _trigger_actor.is_player():
				_actor_name = _trigger_actor.get("player_name")
			elif _trigger_actor.has_method("is_monster") and _trigger_actor.is_monster():
				_actor_name = _trigger_actor.get("monster_name")
			elif "block_name" in _trigger_actor:
				_actor_name = str(_trigger_actor.block_name)
			var _skill_name: String = s.skill_name if s.skill_name != "" else s.english_name
			if _actor_name != "":
				Game.log_message(LogColors.player(_actor_name) + " 触发了 " + LogColors.skill_by_type(_skill_name, s.skill_type))
		await s.execute_content(self, event)
		if EventSystem.is_cancelled(event):
			break


# === 2. 技能挂载 ===

## 返回该实体身上的所有技能列表。
func get_all_skills() -> Array[Skill]:
	return skills


## 向实体挂载一个技能。
func add_skill(skill: Skill) -> void:
	skills.append(skill)


## 从实体移除一个技能。
func remove_skill(skill: Skill) -> void:
	skills.erase(skill)


# === 3. 伤害流程（8 节点） ===

## target 受到来自于 source 的 num 点类型为 type 的伤害。
## source = null 时表示无来源伤害（饥饿/中毒），跳过所有 source 侧钩子。
## card = null 时表示非武器伤害；card 为武器牌时供「造成伤害时」filter 判断。
## type 为伤害类型标识，可为 String（"monster_attack"/"poison"/"hunger"）或 int。
## 流程节点 8 触发死亡判定，调用 target.death(source)（多态）。
func damage(num: int, source: Entity, type: Variant = "", card: Card = null) -> void:
	if num <= 0:
		return
	if get_hp() <= 0:
		return

	var event: Dictionary = EventSystem.create_damage_event(self, source, num, type, card)

	# 1-2. before_deal_damage / before_take_damage
	if source != null:
		await source.trigger("before_deal_damage", event)
		await trigger("before_take_damage", event)
	else:
		await trigger("before_take_damage", event)

	# 3. on_deal_damage（可修改 event.num）
	if source != null:
		await source.trigger("on_deal_damage", event)

	# 4. on_take_damage（取消点：可修改 event.num 或 event.cancel()）
	await trigger("on_take_damage", event)

	if EventSystem.is_cancelled(event):
		return

	# 5. 系统扣血（非钩子节点）
	reduce_hp(event["num"])
	# 5.5 日志记录（玩家/怪物受伤时区分来源）
	if is_player() and event["num"] > 0 and Game != null and is_instance_valid(Game):
		var p_name: String = self.get("player_name")
		var dmg_num: int = event["num"]
		var dmg_type: String = str(type) if type != null else ""
		if dmg_type == "monster_attack" and source != null and is_instance_valid(source) and source.is_monster():
			Game.log_message(LogColors.player(p_name) + " 受到 " + LogColors.monster(source.get("monster_name")) + " 造成的 " + str(dmg_num) + " 点伤害")
		elif dmg_type == "hunger":
			Game.log_message(LogColors.player(p_name) + " 因饥饿受到 " + str(dmg_num) + " 点伤害")
		elif dmg_type == "poison":
			Game.log_message(LogColors.player(p_name) + " 因中毒受到 " + str(dmg_num) + " 点伤害")
		elif dmg_type == "block_destroy":
			Game.log_message(LogColors.player(p_name) + " 因地块摧毁受到 " + str(dmg_num) + " 点伤害")
		else:
			Game.log_message(LogColors.player(p_name) + " 受到 " + str(dmg_num) + " 点伤害")
	elif is_monster() and event["num"] > 0 and Game != null and is_instance_valid(Game):
		var m_name: String = self.get("monster_name")
		var dmg_num_m: int = event["num"]
		if source != null and is_instance_valid(source) and source.is_player():
			Game.log_message(LogColors.monster(m_name) + " 受到 " + LogColors.player(source.get("player_name")) + " 造成的 " + str(dmg_num_m) + " 点伤害")
		else:
			Game.log_message(LogColors.monster(m_name) + " 受到 " + str(dmg_num_m) + " 点伤害")

	# 6. after_deal_damage
	if source != null:
		await source.trigger("after_deal_damage", event)

	# 7. after_take_damage
	await trigger("after_take_damage", event)

	# 8. 死亡判定（多态调用）
	if get_hp() <= 0:
		death(source)


# === 4. 生命值接口（子类必须 override） ===

## 返回当前生命值。
func get_hp() -> int:
	return 0


## 返回最大生命值上限。
func get_max_hp() -> int:
	return 0


## 直接扣血（底层原子方法，不触发钩子）。
func reduce_hp(n: int) -> void:
	pass


## 直接加血（底层原子方法，不触发钩子，不受最大值约束）。
func add_hp(n: int) -> void:
	pass


# === 5. 类型判断 ===

## 是否为 Player 实例。
func is_player() -> bool:
	return false


## 是否为 Monster 实例。
func is_monster() -> bool:
	return false


# === 6. 抽象方法（子类实现） ===

## 死亡流程的抽象方法，由子类实现。
## Player.death → player_death；Monster.death → monster_death。
func death(source: Entity) -> void:
	pass
