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
	for s in skills:
		if not s.matches_trigger(trigger_name):
			continue
		if not s.execute_filter(event):
			continue
		s.execute_content(event)
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
		source.trigger("before_deal_damage", event)
		trigger("before_take_damage", event)
	else:
		trigger("before_take_damage", event)

	# 3. on_deal_damage（可修改 event.num）
	if source != null:
		source.trigger("on_deal_damage", event)

	# 4. on_take_damage（取消点：可修改 event.num 或 event.cancel()）
	trigger("on_take_damage", event)

	if EventSystem.is_cancelled(event):
		return

	# 5. 系统扣血（非钩子节点）
	reduce_hp(event["num"])

	# 6. after_deal_damage
	if source != null:
		source.trigger("after_deal_damage", event)

	# 7. after_take_damage
	trigger("after_take_damage", event)

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
