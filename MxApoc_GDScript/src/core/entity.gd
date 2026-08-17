class_name Entity
extends RefCounted

## 实体基类。
## 所有可挂载技能、可触发事件的实体的基类。
## 继承关系：Entity ← Player / Monster / Card / MapBlock。
## 设计文档：GameDesignDocus/GameSystem/Core/Entity.md

## 挂载在该实体上的所有技能（角色固有/装备/地块/临时）
var skills: Array[Skill] = []

## 实体上的标记集合。Dictionary[String, Mark]，键 = 标记名，值 = Mark 对象。
var marks: Dictionary = {}


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


## 仅在指定技能列表中触发匹配 trigger_name 的技能。
## 用于 on_draw_scavenge_card 等自身反应触发器，避免已装备卡牌的同名触发器重复触发。
func trigger_only(trigger_name: String, event: Dictionary, skill_list: Array) -> void:
	EventSystem.set_trigger_name(event, trigger_name)
	for s in skill_list:
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


## 判断实体身上是否已挂载指定 english_name 的技能。
## 用于卡牌 filter 或方法内按 english_name 去重（如"搜索尸体"已挂载 search_corpse_draw 时禁用第二张）。
func has_skill_by_english_name(english_name: String) -> bool:
	for s in skills:
		if s.english_name == english_name:
			return true
	return false


## 向实体挂载一个技能。
## 若该技能含 sub_skills，按 english_name 去重后递归 auto-mount 子技能（持久模式）。
## 同一 Skill 实例不重复挂载（防止 equip 流程中 auto-mount + 显式 add 重复）。
func add_skill(skill: Skill) -> void:
	if skills.has(skill):
		return
	skills.append(skill)
	# auto-mount 子技能（按 english_name 去重）
	for sub_skill in skill.sub_skills.values():
		if sub_skill.english_name != "" and has_skill_by_english_name(sub_skill.english_name):
			continue
		add_skill(sub_skill)


## 从实体移除一个技能。
## 若该技能含 sub_skills，递归 auto-unmount 仍挂载在实体上的子技能。
func remove_skill(skill: Skill) -> void:
	skills.erase(skill)
	# auto-unmount 子技能（仍挂载在实体上的）
	for sub_skill in skill.sub_skills.values():
		if sub_skill.english_name != "":
			for s in skills.duplicate():
				if s.english_name == sub_skill.english_name:
					remove_skill(s)
					break


## mount-on-use 模式：按 english_name 从全局子技能注册表查找 SkillData，编译为新鲜 Skill 挂载。
## 与 add_skill 不同：mount_sub_skill 挂载的是"无父"独立技能（如空尖弹/搜索尸体的持久效果）。
## 按 english_name 去重：已挂载则返回旧 Skill 实例。
## 注册表中不存在时 push_error 并返回 null。
func mount_sub_skill(english_name: String) -> Skill:
	if Game == null or not is_instance_valid(Game):
		push_error("mount_sub_skill: Game 单例不可用")
		return null
	var sub_data: SkillData = Game.get_sub_skill_data(english_name)
	if sub_data == null:
		push_error("mount_sub_skill: 注册表中未找到子技能 " + english_name)
		return null
	# 去重：已挂载则返回旧实例
	for s in skills:
		if s.english_name == english_name:
			return s
	# 编译并挂载（add_skill 会自动 auto-mount 其 sub_skills）
	var new_skill: Skill = Game._create_skill_from_data(sub_data)
	add_skill(new_skill)
	return new_skill


## 数据驱动临时模式：按 english_name 从全局子技能注册表查找 SkillData，
## 编译为新鲜 Skill 挂载，在 expire_trigger 触发后清理。
## - 若 expire_trigger == 子技能自身 trigger：包装 content 为"原 content + remove_skill(self)"
## - 若 expire_trigger != 子技能自身 trigger：挂载子技能（保留原 trigger+content）+ 另挂载看护 Skill
##   （english_name=english_name+"_expiry"、trigger=expire_trigger、forced=true、content=移除子技能+移除自身）
## 替代旧 player.gd 中的硬编码 add_temp_skill 分支。
func add_temp_skill(english_name: String, expire_trigger: String) -> void:
	if Game == null or not is_instance_valid(Game):
		push_error("add_temp_skill: Game 单例不可用")
		return
	var sub_data: SkillData = Game.get_sub_skill_data(english_name)
	if sub_data == null:
		push_error("add_temp_skill: 注册表中未找到子技能 " + english_name)
		return
	# 编译为新鲜 Skill，保留 JSON trigger / forced / filter / content
	var skill: Skill = Game._create_skill_from_data(sub_data)
	var skill_ref: Skill = skill
	if expire_trigger == sub_data.trigger:
		# 同 trigger：包装 content 为"原 content + remove_skill(self)"
		var original_content: Callable = skill.content
		skill.content = func(_player, _target, event: Dictionary, _game) -> void:
			if original_content.is_valid():
				await original_content.call(_player, _target, event, _game)
			_player.remove_skill(skill_ref)
		# 标记 expiry 名称（去重用）
		skill.english_name = english_name + "_temp"
		add_skill(skill)
	else:
		# 异 trigger：挂载子技能（保留原 trigger+content）+ 另挂载看护 Skill
		# 子技能 english_name 保持原样（来自 JSON）
		add_skill(skill)
		# 看护 Skill
		var watcher: Skill = Skill.new()
		watcher.english_name = english_name + "_expiry"
		watcher.skill_name = english_name + "_expiry"
		watcher.trigger = expire_trigger
		watcher.forced = true
		var watcher_ref: Skill = watcher
		watcher.content = func(_player, _target, _event: Dictionary, _game) -> void:
			# 移除子技能
			for s in _player.get_all_skills().duplicate():
				if s.english_name == english_name:
					_player.remove_skill(s)
					break
			# 移除自身
			_player.remove_skill(watcher_ref)
		add_skill(watcher)


# === Mark 管理 ===

## 添加或更新计数型 mark。mark_text 为空时默认用 name。
## 若 mark 已存在且 mark_text/mark_content 非空，更新对应字段。
func add_mark(name: String, quantity: int = 1, mark_text: String = "", mark_content: String = "", visible: bool = true) -> void:
	var existing_mark: Mark = marks.get(name, null)
	if existing_mark == null:
		var new_mark: Mark = Mark.new()
		new_mark.name = name
		new_mark.mark_text = mark_text if mark_text != "" else name
		new_mark.mark_content = mark_content
		new_mark.visible = visible
		new_mark.count = quantity
		marks[name] = new_mark
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.mark_added.emit(self, new_mark)
	else:
		existing_mark.count += quantity
		if mark_text != "":
			existing_mark.mark_text = mark_text
		if mark_content != "":
			existing_mark.mark_content = mark_content
		existing_mark.visible = visible
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.mark_changed.emit(self, existing_mark)

## 移除指定 mark。
func remove_mark(name: String) -> void:
	if marks.has(name):
		marks.erase(name)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.mark_removed.emit(self, name)

## 返回 mark 的 count 值（不存在返回 0）。
func count_mark(name: String) -> int:
	var m: Mark = marks.get(name, null)
	if m == null:
		return 0
	return m.count

## 判断 mark 是否存在。
func has_mark(name: String) -> bool:
	return marks.has(name)

## 返回 Mark 对象（不存在返回 null）。
func get_mark(name: String) -> Mark:
	return marks.get(name, null)

## 向 mark 的 items 集合添加元素。若 mark 不存在则创建。
func add_mark_item(name: String, item: Variant, mark_text: String = "", mark_content: String = "", visible: bool = true) -> void:
	var existing_mark: Mark = marks.get(name, null)
	if existing_mark == null:
		var new_mark: Mark = Mark.new()
		new_mark.name = name
		new_mark.mark_text = mark_text if mark_text != "" else name
		new_mark.mark_content = mark_content
		new_mark.visible = visible
		new_mark.items.append(item)
		marks[name] = new_mark
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.mark_added.emit(self, new_mark)
	else:
		if mark_text != "":
			existing_mark.mark_text = mark_text
		if mark_content != "":
			existing_mark.mark_content = mark_content
		existing_mark.visible = visible
		existing_mark.items.append(item)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.mark_changed.emit(self, existing_mark)

## 从 items 移除指定元素。
func remove_mark_item(name: String, item: Variant) -> void:
	var m: Mark = marks.get(name, null)
	if m == null:
		return
	m.items.erase(item)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.mark_changed.emit(self, m)

## 返回 items 列表（不存在返回空数组）。
func get_mark_items(name: String) -> Array:
	var m: Mark = marks.get(name, null)
	if m == null:
		return []
	return m.items

## 清零 count（不移除 mark 本身）。
func clear_mark_count(name: String) -> void:
	var m: Mark = marks.get(name, null)
	if m == null:
		return
	m.count = 0
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.mark_changed.emit(self, m)

## 清空 items。
func clear_mark_items(name: String) -> void:
	var m: Mark = marks.get(name, null)
	if m == null:
		return
	m.items.clear()
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.mark_changed.emit(self, m)

## 判断是否持有某标记技能（等价 has_mark）。
func has_mark_skill(name: String) -> bool:
	return has_mark(name)

## 添加标记技能，在 expire_trigger 触发后自动移除标记。
## 支持 mark_text/mark_content/visible 内联传参。
func add_mark_skill(name: String, n: int = 1, expire_trigger: String = "", mark_text: String = "", mark_content: String = "", visible: bool = true) -> void:
	add_mark(name, n, mark_text, mark_content, visible)
	if expire_trigger == "":
		return
	var skill := Skill.new()
	skill.english_name = name + "_mark_expire"
	skill.skill_name = name + "_mark_expire"
	skill.trigger = expire_trigger
	skill.forced = true
	var mark_name: String = name
	var skill_ref: Skill = skill
	skill.content = func(_player, _target, _event: Dictionary, _game) -> void:
		_player.remove_mark(mark_name)
		_player.remove_skill(skill_ref)
	skills.append(skill)


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
	var hp_before: int = get_hp()
	reduce_hp(event["num"])
	var actual_damage: int = hp_before - get_hp()
	# 5.5 统计信号：仅统计实际扣血量（trigger 可能修改/取消伤害）
	if actual_damage > 0 and EventBus != null and is_instance_valid(EventBus):
		EventBus.damage_taken.emit(self, source, actual_damage)
		if source != null:
			EventBus.damage_dealt.emit(source, self, actual_damage)
	# 5.6 日志记录（玩家/怪物受伤时区分来源）
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
