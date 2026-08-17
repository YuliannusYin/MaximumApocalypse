class_name Player
extends Entity

## 玩家类。
## 继承 Entity。职责：玩家实体的状态、区域、行动与玩家专属流程方法。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md
## trigger 名映射见 IdentifierMapping.md §五。

# === 状态字段 ===
var hp: int = 0
var max_hp: int = 0
var hunger: int = 1
var stealth: int = 0
var action_count: int = 0
var max_action_count: int = 4
var in_phase: String = "idle"  # idle/turn_start/monster_spawn/draw/action/hunger/poison/monster_action/turn_end
var _phase_end_requested: String = ""  # 内部信号：end_phase 设置后 wait_player_action 循环跳出

# === 区域字段 ===
var hand: Array = []  # List<Card>，上限 10
var equipment_zone: Array = []  # List<EquipmentCard>
var monster_zone: Array = []  # List<Monster>
var game_deck: Pile = null  # 求生者游戏牌堆
var game_discard_pile: Pile = null

# === 关联对象 ===
var role_card: RoleCard = null
var current_block = null  # MapBlock
var seat_number: int = 0
var player_name: String = ""

# === 输入接口 ===
var input: IPlayerInput = null


func _init() -> void:
	if input == null:
		input = CliPlayerInput.new()


# === Entity 抽象方法实现 ===

func get_hp() -> int:
	return hp


func get_max_hp() -> int:
	return max_hp


func reduce_hp(n: int) -> void:
	hp = maxi(hp - n, 0)


func add_hp(n: int) -> void:
	hp = mini(hp + n, max_hp)


func is_player() -> bool:
	return true


func is_alive() -> bool:
	return hp > 0


# === 一、状态管理 ===

## 回复生命值（4 节点：前/时/系统加血/后）。
## source 为治疗来源（默认 null 表示自行回复）；source != self 时额外发射 healing_done。
func recover(num: int, source: Variant = null) -> void:
	if num <= 0:
		return
	var event: Dictionary = EventSystem.create_recover_event(self, num)
	await trigger("before_recover", event)
	await trigger("on_recover", event)
	if EventSystem.is_cancelled(event):
		return
	var max_recover: int = get_max_hp() - get_hp()
	if event["num"] > max_recover:
		event["num"] = max_recover
	var hp_before: int = get_hp()
	add_hp(event["num"])
	var actual_heal: int = get_hp() - hp_before
	if actual_heal > 0 and Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 回复了 " + str(actual_heal) + " 点生命值")
	if actual_heal > 0 and EventBus != null and is_instance_valid(EventBus):
		EventBus.hp_recovered.emit(self, actual_heal)
		if source != null and source != self:
			EventBus.healing_done.emit(source, self, actual_heal)
		else:
			EventBus.healing_done.emit(self, self, actual_heal)
	await trigger("after_recover", event)


## 增加饥饿值。达 6 后翻面角色卡并叠加饥饿伤害标记。
func increase_hunger(num: int) -> void:
	if num <= 0:
		return
	var old_hunger: int = hunger
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 增加了 " + str(num) + " 点饥饿值")
	while num > 0:
		if hunger < 6:
			hunger += 1
			if hunger == 6:
				# 刚达到 6：翻面 + 添加饥饿伤害标记
				if role_card != null and role_card.is_front():
					role_card.flip()
				var _new_hunger_level: int = count_mark("hunger_damage_level") + 1
				add_mark("hunger_damage_level", 1, "饥饿", "饥饿伤害等级" + str(_new_hunger_level) + ", 饥饿结算时受到 " + str(_new_hunger_level * 2) + "点饥饿伤害")
		elif hunger == 6:
			# 已在 6：叠加标记
			if role_card != null and role_card.is_front():
				role_card.flip()
			var _new_hunger_level: int = count_mark("hunger_damage_level") + 1
			add_mark("hunger_damage_level", 1, "饥饿", "饥饿伤害等级" + str(_new_hunger_level) + ", 饥饿结算时受到 " + str(_new_hunger_level * 2) + "点饥饿伤害")
		if count_mark("hunger_damage_level") > 0:
			var level: int = count_mark("hunger_damage_level")
			if level == 1:
				damage(2, null, "hunger")
			elif level == 2:
				damage(4, null, "hunger")
			elif level == 3:
				damage(6, null, "hunger")
			elif level == 4:
				damage(8, null, "hunger")
			elif level >= 5:
				Game.log_message(LogColors.player(player_name) + " 被饿死了")
				damage(get_max_hp(), null, "hunger")
		num -= 1
	EventBus.player_hunger_changed.emit(self, old_hunger, hunger)

## 减少饥饿值。最低降至 1，减少后清除饥饿伤害标记并恢复角色卡正面。
func decrease_hunger(num: int) -> void:
	if num <= 0:
		return
	var max_reduce: int = hunger - 1
	if num > max_reduce:
		num = max_reduce
	if num <= 0:
		return
	hunger -= num
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 减少了 " + str(num) + " 点饥饿值")
	if count_mark("hunger_damage_level") > 0:
		remove_mark("hunger_damage_level")
	if role_card != null and not role_card.is_front():
		role_card.flip()
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.hunger_reduced.emit(self, num)


## 中毒结算。中毒标记数 = 受到无来源伤害值。
func poison() -> void:
	if count_mark("poison") > 0:
		var num: int = count_mark("poison")
		damage(num, null, "poison")


# === 二、抓牌流程 ===

## 从求生者游戏牌堆抓 n 张牌（4 节点）。
func draw(n: int) -> void:
	if n <= 0:
		return
	var event: Dictionary = EventSystem.create_draw_game_card_event(self, n)
	# 1. 抓取游戏牌前（取消点）
	await trigger("before_draw_game_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 抓取游戏牌时（取消点）
	await trigger("on_draw_game_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 3. 逐张抓取
	var num_to_draw: int = event["num"]
	var _drawn_names: Array = []
	for i in num_to_draw:
		if game_deck == null or game_deck.is_empty():
			death(null)
			return
		var card: Card = game_deck.draw()
		hand.append(card)
		_drawn_names.append(LogColors.card(card.card_name))
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.card_drawn.emit(self, card)
		event["cards"].append(card)
	# 批量输出抓牌日志
	if _drawn_names.size() > 0 and Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 抓取了游戏牌 " + ", ".join(_drawn_names))
	# 4. 抓取游戏牌后
	await trigger("after_draw_game_card", event)


## 将卡牌加入手牌区（content 代码调用入口）。
func gain(card: Card) -> void:
	hand.append(card)


## 从指定拾荒牌堆抓 n 张牌（4 节点）。
func draw_scavenge(n: int, pile: Pile) -> void:
	if n <= 0:
		return
	var event: Dictionary = EventSystem.create_draw_scavenge_event(self, pile, n)
	# 1. 抓取拾荒牌前（取消点）
	await trigger("before_draw_scavenge_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张抓取
	var num_to_draw: int = event["num"]
	for i in num_to_draw:
		if pile == null or pile.is_empty():
			break
		var card: Card = pile.draw()
		await draw_scavenge_card(card, pile, event)
	# 4. 抓取拾荒牌后
	await trigger("after_draw_scavenge_card", event)


## 处理单张拾荒牌的抓取流程（加入手牌、日志、信号、触发抓取效果）。
## card 为已从 pile 取出的牌；pile 用于判断牌堆名称；event 为 draw_scavenge 事件。
func draw_scavenge_card(card: Card, pile: Pile, event: Dictionary) -> void:
	hand.append(card)
	if Game != null and is_instance_valid(Game):
		var _pile_name: String = "拾荒牌堆"
		if pile == Game.red_scavenge_pile:
			_pile_name = "红色拾荒牌堆"
		elif pile == Game.green_scavenge_pile:
			_pile_name = "绿色拾荒牌堆"
		elif pile == Game.blue_scavenge_pile:
			_pile_name = "蓝色拾荒牌堆"
		Game.log_message(LogColors.player(player_name) + " 从 \"" + _pile_name + "\" 中抓取了拾荒牌 " + LogColors.card(card.card_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.scavenge_drawn.emit(self, card)
	event["cards"].append(card)
	event["card"] = card
	# 触发被抓取卡自身的 forced on_draw_scavenge_card 技能（避免已装备同名卡重复触发）
	var mounted_skills: Array = []
	if card.has_method("get_all_skills"):
		for s in card.get_all_skills():
			if s.forced and s.matches_trigger("on_draw_scavenge_card"):
				mounted_skills.append(s)
	await trigger_only("on_draw_scavenge_card", event, mounted_skills)


## 从怪物牌堆抓 n 张怪物卡（7 节点）。
func draw_monster(n: int) -> void:
	if n <= 0:
		return
	var event: Dictionary = EventSystem.create_draw_monster_event(self, n)
	# 1. 抓取怪物卡前（取消点）
	await trigger("before_draw_monster_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张抓取
	var num_to_draw: int = event["num"]
	for i in num_to_draw:
		# a. 牌堆空时重洗怪物弃牌堆
		if Game.monster_pile == null or Game.monster_pile.is_empty():
			if Game.monster_discard_pile != null:
				Game.monster_discard_pile.shuffle_into(Game.monster_pile)
			# 重洗后仍空 → 游戏失败
			if Game.monster_pile == null or Game.monster_pile.is_empty():
				Game.game_over("lose")
				return
		# 抓取怪物卡
		var card: MonsterCard = Game.monster_pile.draw()
		event["card"] = card
		event["cards"].append(card)
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 抓取了怪物牌 " + LogColors.card(card.card_name))
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.monster_card_drawn.emit(self, card)
		# b. 抓取怪物卡时（每张触发）
		await trigger("on_draw_monster_card", event)
		# c. 怪物卡进入求生者怪物区前（每张触发）
		await trigger("before_monster_enter_zone", event)
		# d. 实体化（设置纠缠对象、初始化生命值）
		var monster: Monster = card.instantiate(self)
		# e. 怪物卡进入求生者怪物区时（每张触发）
		monster_zone.append(monster)
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.monster(monster.monster_name) + " 纠缠了 " + LogColors.player(player_name))
		await trigger("on_monster_enter_zone", event)
		await monster.trigger("on_monster_enter_zone", event)
		# f. 怪物卡进入求生者怪物区后（每张触发）
		await trigger("after_monster_enter_zone", event)
		await monster.trigger("after_monster_enter_zone", event)
	# 3. 抓取怪物卡后（整体触发一次）
	await trigger("after_draw_monster_card", event)


# === 三、弃牌与销毁流程 ===

## 弃置卡牌到对应弃牌堆（3 节点）。
## target 可为 Card/Equipment/Array/String（卡牌名）；position 为区域名；quantity 为数量。
## 装备区命中时走卸下分支，并把来源 EquipmentCard 送入弃牌堆（弃牌堆永远收来源卡）。
func discard(target: Variant, position: String = "", quantity: int = 1, type: String = "", silent: bool = false) -> void:
	var cards_to_discard: Array = []
	if type != "":
		# 按类型弃置
		var all_cards: Array = get_cards(position)
		for card in all_cards:
			if card.card_type == type:
				cards_to_discard.append(card)
	elif target is Array:
		cards_to_discard = target.duplicate()
	elif target is Equipment:
		# 装备实体
		cards_to_discard.append(target)
	elif target is Card:
		# 单张卡牌
		cards_to_discard.append(target)
	else:
		# 按名字+位置+数量弃置
		cards_to_discard = get_cards(position, target, quantity)
	if cards_to_discard.is_empty():
		return
	var event: Dictionary = EventSystem.create_discard_event(self, cards_to_discard, cards_to_discard.size())
	# 1. 弃置牌前（取消点）
	await trigger("before_discard", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张弃置
	for card in cards_to_discard:
		var entity: Equipment = _resolve_equipment_entity(card)
		if entity != null:
			# 装备区实体：卸下 + 来源卡入弃牌堆
			_unequip(entity)
			var src_card: EquipmentCard = entity.equipment_card
			event["card"] = src_card
			if src_card.source == "scavenge":
				if Game != null and Game.scavenge_discard_pile != null:
					Game.scavenge_discard_pile.add(src_card)
			else:
				if game_discard_pile != null:
					game_discard_pile.add(src_card)
			if not silent and Game != null and is_instance_valid(Game):
				Game.log_message(LogColors.player(player_name) + " 弃置了 " + LogColors.card(src_card.card_name))
			if EventBus != null and is_instance_valid(EventBus):
				EventBus.card_discarded.emit(self, src_card)
		else:
			# 手牌卡
			event["card"] = card
			_remove_card_from_zone(card)
			if card.source == "scavenge":
				if Game != null and Game.scavenge_discard_pile != null:
					Game.scavenge_discard_pile.add(card)
			else:
				if game_discard_pile != null:
					game_discard_pile.add(card)
			if not silent and Game != null and is_instance_valid(Game):
				Game.log_message(LogColors.player(player_name) + " 弃置了 " + LogColors.card(card.card_name))
			if EventBus != null and is_instance_valid(EventBus):
				EventBus.card_discarded.emit(self, card)
		# 触发弃置牌时
		await trigger("on_discard", event)
	# 3. 弃置牌后
	await trigger("after_discard", event)


## 销毁卡牌（移出游戏，3 节点）。
func remove_card(target: Variant, position: String = "", quantity: int = 1) -> void:
	var cards_to_remove: Array = []
	if target is Array:
		cards_to_remove = target.duplicate()
	elif target is Equipment:
		cards_to_remove.append(target)
	elif target is Card:
		cards_to_remove.append(target)
	else:
		cards_to_remove = get_cards(position, target, quantity)
	if cards_to_remove.is_empty():
		return
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"card": null,
		"cards": [],
		"num": cards_to_remove.size(),
	})
	# 1. 销毁牌前（取消点）
	await trigger("before_remove_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张销毁（销毁不入弃牌堆，与现状一致）
	for card in cards_to_remove:
		var entity: Equipment = _resolve_equipment_entity(card)
		var src_card: Variant = entity.equipment_card if entity != null else card
		event["card"] = src_card
		event["cards"].append(src_card)
		_remove_card_from_zone(card)
		if Game != null:
			Game.remove_card(src_card, true)
			Game.log_message(LogColors.player(player_name) + " 将 " + LogColors.card(src_card.card_name) + " 移出游戏")
		await trigger("on_remove_card", event)
	# 3. 销毁牌后
	await trigger("after_remove_card", event)


# === 四、移动流程 ===

## 底层移动函数（11 节点，不扣行动次数）。
func move_to(target: MapBlock) -> bool:
	var source: MapBlock = current_block
	var event: Dictionary = EventSystem.create_move_event(self, source, target)
	# 1. 离开地块前
	await trigger("before_leave_block", event)
	# 2. 离开地块时
	await trigger("on_leave_block", event)
	# 3. 离开地块后
	await trigger("after_leave_block", event)
	# 4. 获取目标地块技能（先获取，再准入检定）
	if target != null and target.has_method("_acquire_skills_for_player"):
		target._acquire_skills_for_player(self)
	# 5. 进入地块前（取消点）
	await trigger("before_enter_block", event)
	if EventSystem.is_cancelled(event):
		# 移动取消，回滚：移除刚获取的目标地块技能
		if target != null and target.has_method("_clear_skills_for_player"):
			target._clear_skills_for_player(self)
		return false
	# 6. 移动时（坐标变更）
	current_block = target
	if Game != null and is_instance_valid(Game) and target != null and is_instance_valid(target):
		var src_name: String = source.block_name if source != null and is_instance_valid(source) else "出生点"
		Game.log_message(LogColors.player(player_name) + " 从 " + LogColors.block(src_name) + " 移动至 " + LogColors.block(target.block_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_moved.emit(self, source, target)
	add_mark("moved_this_turn", 1, "", "", false)
	# 7. 清理旧地块技能（移动成功后才清理）
	if source != null and source.has_method("_clear_skills_for_player"):
		source._clear_skills_for_player(self)
	# 8. 进入地块时（一次性效果）
	await trigger("on_enter_block", event)
	# 8.5 若 on_enter_block 期间玩家被移动到其他地块，跳过后续步骤
	if current_block != target:
		return false
	# 9. 进入地块后（展示未展示的地块）
	if target != null and target.has_method("is_revealed"):
		if not target.is_revealed():
			await target.reveal(true, self)
	await trigger("after_enter_block", event)
	# 10. 潜行检定（地块有怪物标记时）
	if target != null and target.has_method("has_monster_mark") and target.has_monster_mark():
		if not await sneak_judge():
			var num: int = target.count_monster_mark()
			target.remove_monster_mark(num)
			draw_monster(num)
	# 11. 触发目标标记
	if target != null and target.has_method("trigger_objective_marks"):
		await target.trigger_objective_marks(self)
	return true


# === 五、检定系统 ===

## 基础检定：投两颗骰子，返回点数之和。
func judge() -> int:
	var d1: int = randi_range(1, 6)
	var d2: int = randi_range(1, 6)
	return d1 + d2


## 潜行检定（4 节点）。
func sneak_judge(block_param: MapBlock = null) -> bool:
	var block: MapBlock = block_param if block_param != null else current_block
	EventBus.sneak_judge_triggered.emit(self, block)
	var monster_count: int = 0
	var mark_count: int = 0
	if block != null:
		if block.has_method("count_monster"):
			monster_count = block.count_monster()
		if block.has_method("count_monster_mark"):
			mark_count = block.count_monster_mark()
	var sneak_value: int = get_sneak() - (monster_count + mark_count)
	var event: Dictionary = EventSystem.create_sneak_judge_event(self, sneak_value, block)
	# 1. 潜行检定前
	await trigger("before_sneak_judge", event)
	# 2. 系统投骰（若未跳过）
	if not event["skip_judge"]:
		var dice_value: int = judge()
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 执行了 " + LogColors.skill("潜行检定") + ", 点数为 " + str(dice_value))
		var success: bool = dice_value <= event["sneak_value"]
		event["result"] = {"value": dice_value, "success": success}
	# 3. 潜行检定时
	await trigger("on_sneak_judge", event)
	# 4. 潜行检定后
	await trigger("after_sneak_judge", event)
	if Game != null and is_instance_valid(Game):
		if event["result"]["success"]:
			Game.log_message(LogColors.player(player_name) + " 潜行成功")
		else:
			Game.log_message(LogColors.player(player_name) + " 潜行失败")
	return event["result"]["success"]


## 怪物出生检定（5 节点）。
func monster_spawn_judge() -> void:
	var event: Dictionary = EventSystem.create_spawn_judge_event(self)
	# 1. 怪物出生检定前
	await trigger("before_spawn_judge", event)
	# 2. 系统投骰
	if not event["skip_judge"]:
		var dice_value: int = judge()
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 执行了 " + LogColors.skill("怪物生成") + ", 点数为 " + str(dice_value))
		event["result"] = {"value": dice_value, "success": true}
	# 3. 怪物出生检定时
	await trigger("on_spawn_judge", event)
	# 4. 怪物出生检定后
	await trigger("after_spawn_judge", event)
	# 5. 结果处理：匹配地块
	var dice: int = event["result"]["value"]
	if Game != null and Game.map_area != null:
		for block in Game.map_area:
			if block == null or not is_instance_valid(block):
				continue
			if not block.has_method("is_revealed") or not block.is_revealed():
				continue
			if block.has_method("get_spawn_value") and block.get_spawn_value() == dice:
				if block.count_monster_mark() < 3:
					block.add_monster_mark(1)
				elif block.count_monster_mark() == 3 and block.has_player():
					for p in block.get_players():
						if p != null and is_instance_valid(p) and p.is_alive():
							p.draw_monster(1)


# === 六、死亡流程 ===

## 玩家死亡流程（3 节点）。
func death(source: Entity) -> void:
	hp = 0
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 死亡了")
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_died.emit(self, source)
	var event: Dictionary = EventSystem.create_player_death_event(self, source)
	# 1. 玩家死亡前
	await trigger("before_player_death", event)
	# 2. 玩家死亡时
	await trigger("on_player_death", event)
	# 3. 玩家死亡后
	# 3a. 怪物区怪物 → 弃牌堆，等量怪物标记（最多3个）放回地块
	var monsters: Array = monster_zone.duplicate()
	var mark_count: int = mini(monsters.size(), 3)
	for m in monsters:
		monster_zone.erase(m)
		if Game != null and Game.monster_discard_pile != null:
			Game.monster_discard_pile.add(m.monster_card)
	if mark_count > 0 and current_block != null and current_block.has_method("add_monster_mark"):
		current_block.add_monster_mark(mark_count)
	# 3b. 所有求生者游戏牌移出游戏
	var game_cards: Array = get_all_game_cards()
	for c in game_cards:
		if Game != null:
			Game.remove_card(c)
	# 3c. 拾荒卡按颜色洗回对应拾荒牌堆
	# 装备区返回的是 Equipment 实体，需用来源 ScavengeCard 入拾荒牌堆。
	var scavenge_cards: Array = get_cards("", "", 0, "scavenge")
	for c in scavenge_cards:
		_remove_card_from_zone(c)
		var src_card: Variant = c.equipment_card if c is Equipment else c
		if Game != null and src_card != null and src_card.has_method("get_color"):
			var pile: Pile = Game.get_scavenge_pile(src_card.get_color())
			if pile != null:
				pile.add(src_card)
	if Game != null:
		for color in ["red", "green", "blue"]:
			var pile: Pile = Game.get_scavenge_pile(color)
			if pile != null:
				pile.shuffle()
	await trigger("after_player_death", event)
	# 检查游戏结束条件
	if Game != null and Game.coop_death_mode:
		Game.game_over("lose")
		return
	if Game != null and Game.all_players_dead():
		Game.game_over("lose")


# === 七、使用卡牌流程 ===

## 从手牌中使用一张卡牌（4 节点）。
func use_card(card: Card) -> bool:
	if action_count < 1:
		return false
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"card": card,
		"target": null,
		"targets": [],
		"cards": [],
	})
	# 1. 使用卡牌前（取消点）
	await trigger("before_use_card", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 使用卡牌时（取消点）
	await trigger("on_use_card", event)
	if EventSystem.is_cancelled(event):
		return false
	# 3. 系统结算：消耗 1 点行动次数（defer_action_cost 的技能延迟到 content 中消耗）
	var deferred: bool = false
	if card.card_type != "equipment":
		for _skill in card.get_all_skills():
			if _skill.active == "action" and _skill.defer_action_cost:
				deferred = true
				break
	if not deferred:
		consume_action(1)
	# 按卡牌类型分流
	if card.card_type == "equipment":
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.card(card.card_name))
		equip(card)
	else:
		# 行动牌：执行 card 上声明 active="action" 的 skill 的完整流程
		var skill_executed: bool = false
		var use_logged: bool = false
		for skill in card.get_all_skills():
			if skill.active != "action":
				continue
			# filter 校验
			if not skill.execute_filter(self, event):
				continue
			# select_target 目标选择
			var select_n: int = skill.select_target
			var targets: Array = []
			if select_n > 0:
				targets = await choose_target(select_n, skill, skill.window_prompt)
				if targets.is_empty():
					if deferred:
						return false  # 延迟消耗的技能：玩家取消选取，牌退回手牌
					continue  # 玩家取消
				event["target"] = targets[0]
				event["targets"] = targets
			elif select_n == -1:
				# 自动选取全部合法目标（由 UI 层 _on_choose_target_requested 处理）
				targets = await choose_target(-1, skill, skill.window_prompt)
				if targets.is_empty():
					if deferred:
						return false
					else:
						continue
				event["target"] = targets[0] if not targets.is_empty() else null
				event["targets"] = targets
			# select_card 选牌（若有）
			var select_card_n: int = skill.select_card
			if select_card_n > 0:
				var cards: Array = await choose_card(select_card_n, "hand", skill.filter_card)
				event["cards"] = cards
			# 输出使用日志（有非自身目标时输出"对目标使用了"，否则输出"使用了"）
			if not use_logged and Game != null and is_instance_valid(Game):
				var _target: Variant = event.get("target", null)
				if _target != null and _target != self:
					Game.log_message(LogColors.player(player_name) + " 对 " + _format_target_name(_target) + " 使用了 " + LogColors.card(card.card_name))
				else:
					Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.card(card.card_name))
				use_logged = true
			# 执行 content（content 可通过 EventSystem.cancel(event) 取消，如第一步未确认目标）
			await skill.execute_content(self, event)
			if deferred and EventSystem.is_cancelled(event):
				# 延迟消耗的技能在 content 中取消：牌退回手牌，不弃牌，不触发 after_use_card
				return false
			skill_executed = true
		# 若所有 skill 的 filter 均不通过，仍输出"使用了"日志
		if not use_logged and Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.card(card.card_name))
		# 弃牌（在 content 执行后，静默弃置不输出"弃置了"日志）
		# 若 content 已销毁牌（移出游戏），跳过弃置
		if Game != null and is_instance_valid(Game) and Game.removed_cards.has(card):
			pass  # 牌已被 content 销毁，跳过弃置
		else:
			await discard(card, "", 1, "", true)
	# 4. 使用卡牌后
	await trigger("after_use_card", event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.card_used.emit(self, card)
	return true


## 判断手牌当前是否可被玩家使用（供 UI 确认按钮置灰）。
## 装备牌直接可装备（无 filter 门槛）；行动牌需至少一个 active="action" 技能 filter 通过。
## filter 以 target = null 求值，与 use_card 的校验时机保持一致。
func is_card_usable(card: Card) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	if card.card_type == "equipment":
		return true
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"card": card,
		"target": null,
		"targets": [],
		"cards": [],
	})
	for skill in card.get_all_skills():
		if skill.active != "action":
			continue
		if not skill.execute_filter(self, event):
			continue
		if skill.select_target > 0:
			var valid_targets: Array = get_skill_valid_targets(skill)
			if valid_targets.is_empty():
				continue
		return true
	return false


# === 八、装备流程 ===

## 装备进入装备区（3 节点 + 预校验）。
func equip(card: Card) -> bool:
	var event: Dictionary = EventSystem.create_equip_event(self, card)
	# 1. 卡牌进入装备区前（取消点）
	await trigger("before_equip", event)
	if EventSystem.is_cancelled(event):
		return false
	# 系统预校验
	# a. 同名装备校验：弃置装备区中的同名装备（装备区持有 Equipment 实体）
	# "燃料"例外：允许多张同时存在于装备区
	var same_name: Array = []
	if card.get("english_name") != "fuel":
		for e in equipment_zone:
			if e.card_name == card.card_name:
				same_name.append(e)
		for e in same_name:
			discard(e)
	# b. 装备栏容量校验
	if role_card != null:
		var new_size: int = 0
		if card.get("size") != null:
			new_size = int(card.get("size"))
		var total_size: int = 0
		for e in equipment_zone:
			if e != null and is_instance_valid(e):
				total_size += int(e.get("size"))
		while total_size + new_size > role_card.equipment_capacity and not equipment_zone.is_empty():
			var selected: Array = await choose_card(1, equipment_zone)
			if selected.is_empty():
				EventSystem.cancel(event)
				return false
			await discard(selected[0])
			total_size = 0
			for e in equipment_zone:
				if e != null and is_instance_valid(e):
					total_size += int(e.get("size"))
	# 2. 卡牌进入装备区时
	hand.erase(card)
	# 实体化：装备区持有 Equipment 实体；非 EquipmentCard 时保底直接入区
	var entity: Equipment = null
	if card is EquipmentCard and card.has_method("instantiate"):
		entity = card.instantiate(self)
		equipment_zone.append(entity)
	else:
		equipment_zone.append(card)
	# 装备技能挂载到玩家（从实体挂载，技能实例与来源卡同源）
	if entity != null:
		for s in entity.get_all_skills():
			add_skill(s)
	elif card.has_method("get_all_skills"):
		for s in card.get_all_skills():
			add_skill(s)
	await trigger("on_equip", event)
	# 3. 卡牌进入装备区后
	await trigger("after_equip", event)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 装备了 " + LogColors.card(card.card_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.equipment_equipped.emit(self, entity if entity != null else card)
	return true


## 装备离开装备区（3 节点）。
func unequip(card: Variant) -> bool:
	# 解析装备实体（target 可为实体或来源卡）
	var entity: Equipment = _resolve_equipment_entity(card)
	if entity == null:
		return false
	var src_card: EquipmentCard = entity.equipment_card
	var event: Dictionary = EventSystem.create_equip_event(self, src_card)
	# 1. 卡牌离开装备区前（取消点）
	await trigger("before_unequip", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 卡牌离开装备区时
	equipment_zone.erase(entity)
	entity.in_equipment_area = false
	await trigger("on_unequip", event)
	# 移除装备技能（在 on_unequip 之后，确保 on_unequip 触发器仍可见装备技能）
	for s in entity.get_all_skills():
		remove_skill(s)
	# 3. 卡牌离开装备区后
	await trigger("after_unequip", event)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 卸下了 " + LogColors.card(src_card.card_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.equipment_unequipped.emit(self, src_card)
	return true


## 增加装备栏容量上限 n 格。
## 容量由 RoleCard.equipment_capacity 约束（见 equip() 预校验注释）。
func increase_equipment_slot(n: int) -> void:
	if n <= 0:
		return
	if role_card == null:
		return
	role_card.equipment_capacity += n


## 减少装备栏容量上限 n 格，不低于 0。
func decrease_equipment_slot(n: int) -> void:
	if n <= 0:
		return
	if role_card == null:
		return
	role_card.equipment_capacity = maxi(role_card.equipment_capacity - n, 0)


# === 九、填充物流程 ===

## 装备填充物消耗（4 节点 + 耗尽衍生）。
## equipment 可为 Equipment 实体或 EquipmentCard（实体方法委托到来源卡）。
## 钩子/事件载荷收到的永远是来源 EquipmentCard（entity.equipment_card）。
func consume_charge(equipment: Variant, num: int) -> bool:
	# 前置校验：填充物不足时取消
	if equipment == null or not equipment.has_method("get_charge"):
		return false
	if equipment.get_charge() < num:
		return false
	# 解析来源卡：钩子/事件载荷用来源卡（保留 charge_type 等 live 字段访问）
	var src_card: Variant = equipment
	if equipment is Equipment and equipment.equipment_card != null:
		src_card = equipment.equipment_card
	var event: Dictionary = EventSystem.create_consume_charge_event(self, src_card, num)
	# 1. 消耗填充物前（取消点）
	await trigger("before_consume_charge", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 消耗填充物时（取消点）
	await trigger("on_consume_charge", event)
	if EventSystem.is_cancelled(event):
		return false
	# 3. 系统扣减（实体方法委托到来源卡）
	if equipment.has_method("consume_charge"):
		equipment.consume_charge(event["num"])
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 对 " + LogColors.card(equipment.card_name) + " 消耗了 " + str(num) + " 发填充物")
	# 4. 消耗填充物后
	await trigger("after_consume_charge", event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.charge_consumed.emit(self, src_card, num)
	# 5. 衍生：填充物耗尽时
	if equipment.get_charge() <= 0:
		await trigger("on_charge_depleted", event)
	return true


## 为装备填装填充物并输出日志。
func add_charge_to(equipment: Variant, amount: int, type: String) -> void:
	if equipment == null or not equipment.has_method("add_charge"):
		return
	var before: int = equipment.get_charge()
	equipment.add_charge(amount, type)
	var added: int = equipment.get_charge() - before
	if added > 0 and Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 对 " + LogColors.card(equipment.card_name) + " 填装了 " + str(added) + " 发填充物")


## 遍历装备区，累加所有 charge_type 匹配装备的当前填充物数量。
## 用于"齐射"等卡牌：统计某类填充物（如 ammo）总数。
func get_total_charge_count(charge_type: String) -> int:
	var total: int = 0
	for e in equipment_zone:
		if e == null or not is_instance_valid(e):
			continue
		if e.charge_type == charge_type:
			total += e.get_charge()
	return total


## 清空装备区内所有 charge_type 匹配装备的填充物。
## 对每个耗尽的装备触发 on_charge_depleted 事件（与 consume_charge 一致）。
## 用于"齐射"卡牌：弃掉所有弹药以造成 X×2 伤害。
## 注意：先收集匹配装备到临时数组，避免迭代中 on_charge_depleted 的技能
## 弃置装备导致 equipment_zone 变动。
func clear_charge(charge_type: String) -> void:
	var matched: Array = []
	var total: int = 0
	for e in equipment_zone:
		if e == null or not is_instance_valid(e):
			continue
		if e.charge_type == charge_type:
			matched.append(e)
			total += e.get_charge()
	# 先收集到临时数组，避免迭代中 equipment_zone 变动
	for e in matched:
		var num: int = e.get_charge()
		if num <= 0:
			continue
		# 解析来源卡（与 consume_charge 一致）
		var src_card: Variant = e
		if e is Equipment and e.equipment_card != null:
			src_card = e.equipment_card
		var event: Dictionary = EventSystem.create_consume_charge_event(self, src_card, num)
		# 清零填充物（直接设置，不经过 consume_charge 的 before/on_consume 取消点）
		e.charge_current = 0
		# 触发耗尽事件（可能触发 hollow_point_remove 等弃置武器技能）
		await trigger("on_charge_depleted", event)
	if total > 0 and Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 弃掉了 " + str(total) + " 发 " + charge_type + " 弹药")


## 将装备填充物填满并输出日志。
func fill_charge_to(equipment: Variant) -> void:
	if equipment == null or not equipment.has_method("fill_charge"):
		return
	var before: int = equipment.get_charge()
	equipment.fill_charge()
	var added: int = equipment.get_charge() - before
	if added > 0 and Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 对 " + LogColors.card(equipment.card_name) + " 填装了 " + str(added) + " 发填充物")


## 格式化目标名称为带颜色的字符串（用于日志输出）。
func _format_target_name(target: Variant) -> String:
	if typeof(target) == TYPE_OBJECT and is_instance_valid(target):
		if target.has_method("is_monster") and target.is_monster():
			return LogColors.monster(target.get("monster_name"))
		elif target.has_method("is_player") and target.is_player():
			return LogColors.player(target.get("player_name"))
		elif "block_name" in target:
			return LogColors.block(target.block_name)
		elif "card_name" in target:
			return LogColors.card(target.card_name)
	return "\"" + str(target) + "\""


# === 十、回合流程 ===

## 玩家回合完整流程（21 节点，节点 21 由状态机执行）。
func start_turn() -> void:
	var event: Dictionary = EventSystem.create_event({"player": self})
	# 节点 1：进入玩家回合（非钩子节点）
	in_phase = "turn_start"
	action_count = max_action_count
	clear_turn_marks()
	# 重置主动技能使用次数
	for skill in skills:
		if skill is Skill and skill.active != "":
			skill.reset_use_count()
	# 节点 2：回合开始前
	await trigger("before_turn_start", event)
	# 节点 3：回合开始时
	await trigger("on_turn_start", event)
	# 节点 4：怪物出生前
	in_phase = "monster_spawn"
	await trigger("before_monster_spawn", event)
	# 节点 5：怪物出生时
	await trigger("on_monster_spawn", event)
	await monster_spawn_judge()
	# 节点 6：摸牌阶段前
	in_phase = "draw"
	await trigger("before_draw_phase", event)
	# 节点 7：摸牌阶段（牌堆空 → 死亡）
	draw(1)
	if not is_alive():
		return
	# 节点 8：行动阶段前（含潜行检定）
	in_phase = "action"
	EventBus.phase_changed.emit(self, "", "action")
	if current_block != null and current_block.has_method("has_monster_mark"):
		if current_block.has_monster_mark():
			if not await sneak_judge():
				var num: int = current_block.count_monster_mark()
				current_block.remove_monster_mark(num)
				draw_monster(num)
	await trigger("before_action_phase", event)
	# 节点 9：行动阶段
	await wait_player_action()
	# 节点 10：行动阶段结束前
	await trigger("before_action_phase_end", event)
	# 节点 11：行动阶段结束时
	await trigger("on_action_phase_end", event)
	# 节点 12：求生者饥饿状态结算前
	in_phase = "hunger"
	await trigger("before_hunger_settlement", event)
	# 节点 13：求生者饥饿状态结算时
	await trigger("on_hunger_settlement", event)
	increase_hunger(1)
	if not is_alive():
		return
	# 节点 14：求生者中毒状态结算前
	in_phase = "poison"
	await trigger("before_poison_settlement", event)
	# 节点 15：求生者中毒状态结算时
	await trigger("on_poison_settlement", event)
	poison()
	if not is_alive():
		return
	# 节点 16：面前怪物行动前
	in_phase = "monster_action"
	await trigger("before_zone_monster_act", event)
	# 节点 17：面前怪物行动时
	await trigger("on_zone_monster_act", event)
	var monsters_copy: Array = monster_zone.duplicate()
	for monster in monsters_copy:
		if monster != null and is_instance_valid(monster):
			await monster.act()
	if not is_alive():
		return
	# 节点 18：回合结束前
	in_phase = "turn_end"
	await trigger("before_turn_end", event)
	# 节点 19：回合结束时
	await trigger("on_turn_end", event)
	# 节点 20：退出玩家回合
	in_phase = "idle"


# === 十一、迷你回合流程 ===

## 立即执行一个行动（仅含行动阶段）。
func execute_action_immediately(num: int = 1) -> void:
	var saved_phase: String = in_phase
	var saved_action_count: int = action_count
	in_phase = "action"
	action_count = num
	await wait_player_action()
	in_phase = saved_phase
	action_count = saved_action_count


# === 十二、底层接口与工具方法 ===

## 饥饿值读写
func get_hunger() -> int:
	return hunger


func add_hunger(n: int) -> void:
	hunger += n


func reduce_hunger(n: int) -> void:
	var hunger_before: int = hunger
	hunger = maxi(hunger - n, 1)
	var actual_reduce: int = hunger_before - hunger
	if actual_reduce > 0 and EventBus != null and is_instance_valid(EventBus):
		EventBus.hunger_reduced.emit(self, actual_reduce)


## 潜行值（含饥饿状态修正）
func get_sneak() -> int:
	if role_card != null:
		return stealth + role_card.get_sneak()
	return stealth


func add_sneak(n: int) -> void:
	stealth += n


func reduce_sneak(n: int) -> void:
	stealth = maxi(stealth - n, 0)


## 行动次数管理
func get_action_count() -> int:
	return action_count


func set_action_count(n: int) -> void:
	action_count = n


func reduce_action_count(n: int) -> void:
	action_count = maxi(action_count - n, 0)


## 扣除 n 点行动次数（content 代码字符串统一调用名，等价 reduce_action_count）。
func consume_action(n: int) -> void:
	reduce_action_count(n)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 消耗了 " + str(n) + " 点行动点数")


## 增加 n 点行动次数（野地夹克使用）。
func add_action(n: int) -> void:
	action_count += n
	if action_count < 0:
		action_count = 0
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 增加了 " + str(n) + " 点行动点数")


## 增加 n 点行动次数上限（扣动扳机让我快乐使用）。
func increase_max_action(n: int) -> void:
	max_action_count += n
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 增加了 " + str(n) + " 点行动次数上限")


## 减少 n 点行动次数上限（下限 0）。
func decrease_max_action(n: int) -> void:
	max_action_count = maxi(max_action_count - n, 0)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 减少了 " + str(n) + " 点行动次数上限")


## 区域管理
func get_current_block() -> MapBlock:
	return current_block


func get_role_card() -> RoleCard:
	return role_card


## 按条件查询玩家区域中的牌。
func get_cards(position: String = "", name: String = "", quantity: int = 0, source: String = "") -> Array:
	var result: Array = []
	var search_hand: bool = (position == "" or position == "hand")
	var search_equip: bool = (position == "" or position == "equipment")
	if search_hand:
		for card in hand:
			if _card_matches(card, name, source):
				result.append(card)
				if quantity > 0 and result.size() >= quantity:
					return result
	if search_equip:
		for card in equipment_zone:
			if _card_matches(card, name, source):
				result.append(card)
				if quantity > 0 and result.size() >= quantity:
					return result
	return result


func _card_matches(card: Variant, name: String, source: String) -> bool:
	if name != "" and card.card_name != name and card.english_name != name:
		return false
	if source != "" and card.source != source:
		return false
	return true


## 返回所有求生者游戏牌（手牌+装备+牌堆+弃牌堆）。
## 装备区追加来源 EquipmentCard（实体不入"所有游戏卡"）。
func get_all_game_cards() -> Array:
	var result: Array = []
	result.append_array(hand)
	for e in equipment_zone:
		if e != null and e.equipment_card != null:
			result.append(e.equipment_card)
	if game_deck != null:
		result.append_array(game_deck.get_all())
	if game_discard_pile != null:
		result.append_array(game_discard_pile.get_all())
	return result


## 从所在区域移除一张牌（内部方法）。
## 装备区持有 Equipment 实体，需解析实体后 erase。
func _remove_card_from_zone(card: Variant) -> void:
	hand.erase(card)
	var entity: Equipment = _resolve_equipment_entity(card)
	if entity != null:
		equipment_zone.erase(entity)
	else:
		equipment_zone.erase(card)


## 内部卸下装备（不触发钩子，供 discard 流程复用）。
## target 可为 Equipment 实体或 EquipmentCard 来源卡。
func _unequip(target: Variant) -> void:
	var entity: Equipment = _resolve_equipment_entity(target)
	if entity == null:
		return
	equipment_zone.erase(entity)
	entity.in_equipment_area = false
	for s in entity.get_all_skills():
		remove_skill(s)


## 解析装备实体：target 为 Equipment 实体时返回自身；
## 为 EquipmentCard 时在装备区查找对应实体；为其他对象/字符串时按 card_name 匹配；
## 找不到返回 null。
func _resolve_equipment_entity(target: Variant) -> Equipment:
	if target is Equipment:
		return target
	if target is EquipmentCard:
		for e in equipment_zone:
			if e != null and e.equipment_card == target:
				return e
		return null
	# 按卡牌名匹配（对象或字符串）
	var tname: String = ""
	if target != null and typeof(target) == TYPE_OBJECT and target.has_method("get"):
		var got: Variant = target.get("card_name")
		if got is String:
			tname = got
	elif target is String:
		tname = target
	if tname != "":
		for e in equipment_zone:
			if e != null and (e.card_name == tname or e.english_name == tname):
				return e
	return null


## 玩家面前是否有非首领怪物。
func has_non_boss_monster() -> bool:
	for m in monster_zone:
		if m != null and is_instance_valid(m) and m.monster_level != "boss":
			return true
	return false


## 增加 n 层中毒标记。
func add_poison(n: int) -> void:
	var new_count: int = count_mark("poison") + n
	add_mark("poison", n, "中毒", "中毒结算时受到 " + str(new_count) + " 点伤害")


func clear_turn_marks() -> void:
	# 清除持续到回合结束的临时标记
	remove_mark("moved_this_turn")
	remove_mark("shelter_disabled")


## 装备管理
func has_equipment(name: String) -> bool:
	for e in equipment_zone:
		if e.card_name == name or e.english_name == name:
			return true
	return false


## 装备区是否存在 charge_type == "ammo" 的装备（空尖弹 filter 用）。
func has_ammo_weapon() -> bool:
	for e in equipment_zone:
		if e != null and e.charge_type == "ammo":
			return true
	return false


## 判断玩家是否持有指定类型的牌（无参时判断是否有任意牌）。
func has_card(type: String = "") -> bool:
	if type == "":
		return not hand.is_empty() or not equipment_zone.is_empty()
	for c in hand:
		if c.card_type == type:
			return true
	for c in equipment_zone:
		if c.card_type == type:
			return true
	return false


func get_equipment(name: String) -> Equipment:
	for e in equipment_zone:
		if e.card_name == name or e.english_name == name:
			return e
	return null


## 查询指定装备的当前 charge 数量；装备不存在返回 0。
func get_charge_count(equipment_name: String) -> int:
	var equip: Equipment = get_equipment(equipment_name)
	if equip == null or not is_instance_valid(equip):
		return 0
	return equip.get_charge()


## 按名称获取玩家的牌堆。
## name: "deck" = 角色游戏牌堆, "hand" = 手牌, "equipment" = 装备区, "discard" = 弃牌堆。
## 注意：deck/discard 返回 Pile；hand/equipment 返回 Array（玩家手牌与装备区以 Array 存储）。
func get_pile(name: String) -> Variant:
	match name:
		"deck":
			return game_deck
		"hand":
			return hand
		"equipment":
			return equipment_zone
		"discard":
			return game_discard_pile
		_:
			return null


## 返回游戏牌弃牌堆（content 代码调用入口）。
func get_discard_pile() -> Pile:
	return game_discard_pile


## 选择器（委托 input）
func choose(options: Array, prompt: String = "") -> Variant:
	return await input.choose(options, prompt)


## 确认对话框（委托 input）。
func confirm(message: String) -> bool:
	return await input.confirm(message)


## 选择卡牌。
## param 为 String 时：按 position（如 "hand"/"equipment"/"discard"）查询玩家区域卡牌（原有行为）。
## param 为 Array 时：直接作为候选卡牌列表，绕过 position 查询。
func choose_card(n: int, param: Variant = "hand", filter: Variant = null) -> Array:
	if typeof(param) == TYPE_ARRAY:
		# Array 模式：直接作为候选卡牌列表，绕过 position 查询
		return await input.choose_card(n, param, filter)
	# String 模式（原有行为）：按 position 查询玩家区域卡牌
	return await input.choose_card(n, param, filter)


## 选择目标。n 为选择数量（-1 表示全部），skill 为当前技能（含 target_type/filter_target 等）。
func choose_target(n: int, skill: Variant = null, prompt: String = "") -> Array:
	return await input.choose_target(n, skill, prompt)


## 选择目标地块。
## param 为 Array 时：直接作为候选地块列表（原有行为）。
## param 为 Dictionary 时：内部构建候选地块并过滤。
##   - "filter_target_range": 距离限制（"short"/"medium"/"long"），默认 "short"
##   - "filter_target": 过滤代码字符串，target 指代候选地块，返回 bool
func choose_map_block(param: Variant, prompt: String = "") -> Variant:
	if typeof(param) == TYPE_DICTIONARY:
		var filter_config: Dictionary = param
		var range_str: String = filter_config.get("filter_target_range", "short")
		var filter_code: String = filter_config.get("filter_target", "")
		var current_block: MapBlock = get_current_block()
		if current_block == null:
			return null
		var candidates: Array = current_block.get_blocks_in_range(range_str)
		# 过滤候选（filter_code 中 target 指代候选地块）
		var filtered: Array = []
		var filter_callable: Callable = CodeExecutor.compile_filter_target(filter_code)
		for block in candidates:
			var event: Dictionary = {"player": self, "target": block}
			if filter_callable.is_valid():
				if filter_callable.call(self, block, event, Game):
					filtered.append(block)
			else:
				filtered.append(block)
		if filtered.is_empty():
			return null
		return await input.choose_map_block(filtered, prompt)
	else:
		# array 模式（原有行为）
		return await input.choose_map_block(param, prompt)


## 内联选取地块（使用地图内联高亮，非弹窗）。
## valid_blocks 为候选地块列表，委托 input 层用内联高亮方式选取。
## 返回选中的地块数组（取消/无可选地块返回空数组）。
func choose_block_inline(valid_blocks: Array, prompt: String = "", count: int = 1) -> Array:
	if valid_blocks.is_empty():
		return []
	if count >= valid_blocks.size():
		return valid_blocks.duplicate()
	if input == null or not is_instance_valid(input):
		return []
	return await input.choose_block_inline(valid_blocks, prompt, count)


func show_card(card: Card, target: Variant) -> void:
	input.show_card(card, target)


## 设置 prompt 区文本（content 代码调用入口）。
func set_prompt(text: String) -> void:
	if input != null and is_instance_valid(input):
		input.set_prompt(text)


## 等待玩家重调决策（第零轮专用）。返回 true 表示确定重调，false 表示取消。
func wait_redraw_decision() -> bool:
	if input == null or not is_instance_valid(input):
		return false
	return await input.wait_redraw_decision(self)


## 行动阶段循环：等待玩家操作（使用卡牌/使用主动技能/结束回合）。
func wait_player_action() -> void:
	while is_alive():
		if _phase_end_requested != "":
			_phase_end_requested = ""
			break
		var choice: Variant = await input.wait_action(self)
		if choice == null:
			break  # 结束回合
		if typeof(choice) == TYPE_DICTIONARY:
			var action_type: String = choice.get("type", "")
			if action_type == "skill":
				var skill: Skill = choice.get("skill", null)
				if skill != null and is_instance_valid(skill):
					await use_active_skill(skill)
			elif action_type == "card":
				var card: Card = choice.get("card", null)
				if card != null and is_instance_valid(card):
					await use_card(card)
			elif action_type == "pile_draw":
				var pile_key: String = choice.get("pile_key", "")
				await _execute_pile_draw(pile_key)
			elif action_type == "move":
				var target_block: Variant = choice.get("target", null)
				if target_block != null and is_instance_valid(target_block):
					consume_action(1)
					await move_to(target_block)


## 执行牌堆抓牌动作（UI 牌堆点击触发）。
## pile_key 为 "game_deck" / "red_scavenge" / "green_scavenge" / "blue_scavenge"。
func _execute_pile_draw(pile_key: String) -> void:
	if pile_key == "game_deck":
		consume_action(1)
		await draw(1)
		return
	var pile: Pile = null
	match pile_key:
		"red_scavenge":
			pile = Game.red_scavenge_pile
		"green_scavenge":
			pile = Game.green_scavenge_pile
		"blue_scavenge":
			pile = Game.blue_scavenge_pile
		_:
			return
	if pile == null:
		return
	consume_action(1)
	await draw_scavenge(1, pile)


## 设置标记让 wait_player_action 循环跳出。phase 为请求结束的阶段名。
func end_phase(phase: String) -> void:
	_phase_end_requested = phase


## 选择并弃置 n 张牌（可选类型过滤）。
func choose_to_discard(n: int, type: String = "") -> void:
	var candidates: Array = []
	if type == "":
		candidates = hand.duplicate()
	else:
		for c in hand:
			if c.card_type == type:
				candidates.append(c)
	if candidates.is_empty():
		return
	var chosen: Variant = await choose_card(n, candidates)
	if chosen == null:
		return
	var cards_to_discard: Array = chosen if chosen is Array else [chosen]
	discard(cards_to_discard)


## 使用主动技能。处理目标选择和卡牌选择，然后执行技能 content。
func use_active_skill(skill: Skill) -> void:
	if skill == null or not is_instance_valid(skill):
		return
	if skill.active.is_empty():
		return
	if not skill.is_usable():
		return
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"target": null,
		"targets": [],
		"cards": [],
	})
	# 1. filter 检查
	if not skill.execute_filter(self, event):
		return
	# 2. 目标选择
	var target_type: String = skill.target_type
	if target_type == "block":
		var range_str: String = skill.filter_target_range
		var candidates: Array = []
		if current_block != null:
			if range_str != "":
				candidates = current_block.get_blocks_in_range(range_str)
			else:
				candidates = current_block.get_adjacent_blocks()
		candidates = _filter_targets(skill, candidates, event)
		if candidates.is_empty():
			return
		var chosen: Variant = await choose_map_block(candidates, "选择目标地块")
		if chosen == null:
			return
		event["target"] = chosen
	elif target_type == "entity":
		var range_str: String = skill.filter_target_range
		var candidates: Array = []
		if current_block != null:
			candidates = current_block.get_players_in_range(range_str)
		candidates = _filter_targets(skill, candidates, event)
		if candidates.is_empty():
			return
		var chosen: Variant = await choose(candidates, "选择目标")
		if chosen == null:
			return
		event["target"] = chosen
	elif target_type == "pile":
		var colors: Array = []
		if current_block != null and current_block.has_color():
			colors = Array(current_block.scavenge_colors)
		if colors.is_empty():
			return
		var chosen: Variant = await choose(colors, "选择拾荒牌堆颜色")
		if chosen == null:
			return
		event["target"] = chosen
	elif target_type == "equipment":
		var candidates: Array = equipment_zone.duplicate()
		candidates = _filter_targets(skill, candidates, event)
		if candidates.is_empty():
			return
		var chosen: Variant = await choose(candidates, "选择装备")
		if chosen == null:
			return
		event["target"] = chosen
	else:
		# target_type 为空：依据 select_target 选择目标
		var select_n: int = skill.select_target
		var targets: Array = []
		if select_n > 0:
			targets = await choose_target(select_n, skill, skill.window_prompt)
			if targets.is_empty():
				return  # 玩家取消
			event["target"] = targets[0]
			event["targets"] = targets
		elif select_n == -1:
			# 自动选取全部合法目标
			targets = await choose_target(-1, skill, skill.window_prompt)
			if targets.is_empty():
				return
			event["target"] = targets[0] if not targets.is_empty() else null
			event["targets"] = targets
	# 3. 卡牌选择
	if skill.select_card > 0:
		var cards: Array = await choose_card(skill.select_card, skill.position, skill.filter_card)
		if cards.size() < skill.select_card:
			return
		event["cards"] = cards
	# 4. 输出使用日志（有 target 时输出"对目标使用了"，无 target 时输出"使用了"）
	if Game != null and is_instance_valid(Game):
		var _skill_name: String = skill.skill_name if skill.skill_name != "" else skill.english_name
		var _target: Variant = event.get("target", null)
		if _target != null:
			var _target_name: String = ""
			if typeof(_target) == TYPE_OBJECT and is_instance_valid(_target):
				if _target.has_method("is_monster") and _target.is_monster():
					_target_name = LogColors.monster(_target.get("monster_name"))
				elif _target.has_method("is_player") and _target.is_player():
					_target_name = LogColors.player(_target.get("player_name"))
				elif "block_name" in _target:
					_target_name = LogColors.block(_target.block_name)
			if _target_name == "":
				_target_name = "\"" + str(_target) + "\""
			Game.log_message(LogColors.player(player_name) + " 对 " + _target_name + " 使用了 " + LogColors.skill(_skill_name))
		else:
			Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.skill(_skill_name))
	# 5. 执行 content
	await skill.execute_content(self, event)
	# 5.5 取消检查：content 中通过 EventSystem.cancel(event) 取消时不记录使用
	if EventSystem.is_cancelled(event):
		return
	# 6. 记录使用
	skill.record_use()
	# 7. 统计信号：技能成功使用
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.skill_used.emit(self, skill)


## 内部方法：用 skill.filter_target 过滤候选目标列表。
func _filter_targets(skill: Skill, candidates: Array, event: Dictionary) -> Array:
	var filtered: Array = []
	for candidate in candidates:
		if skill.filter_target.is_valid():
			if skill.filter_target.call(self, candidate, event, Game):
				filtered.append(candidate)
		else:
			filtered.append(candidate)
	return filtered


## 构建技能的合法目标候选列表（按 target_type 与 filter_target_range 构建并经 filter_target 过滤）。
## 逻辑与 game_scene_2d.gd._on_choose_target_requested 保持一致，供可用性判断复用。
func get_skill_valid_targets(skill: Variant) -> Array:
	if skill == null or not is_instance_valid(skill):
		return []
	var target_type: String = skill.target_type
	var filter_target_range: String = skill.filter_target_range
	if filter_target_range == "":
		filter_target_range = "short"
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"target": null,
		"card": null,
		"targets": [],
		"cards": [],
	})
	var candidates: Array = []
	match target_type:
		"block":
			if current_block != null and is_instance_valid(current_block):
				candidates = current_block.get_blocks_in_range(filter_target_range)
		"equipment":
			candidates = equipment_zone.duplicate()
		_:
			# entity 默认分支：当前地块射程内玩家 + 当前地块所有玩家 + 当前玩家怪物区怪物
			if current_block != null and is_instance_valid(current_block):
				candidates = current_block.get_players_in_range(filter_target_range)
				candidates.append_array(current_block.get_players())
			if monster_zone != null:
				for m in monster_zone:
					if m != null and is_instance_valid(m):
						candidates.append(m)
			# 新增：射程内其他玩家怪物区的怪物（与 game_scene_2d.gd 候选构建逻辑保持一致）
			if current_block != null and is_instance_valid(current_block):
				var players_in_range: Array = current_block.get_players_in_range(filter_target_range)
				for other_player in players_in_range:
					if other_player == null or not is_instance_valid(other_player):
						continue
					if other_player == self:
						continue  # 自己的怪物区已在上面处理
					if "monster_zone" in other_player:
						for m in other_player.monster_zone:
							if m != null and is_instance_valid(m) and not candidates.has(m):
								candidates.append(m)
			# 去重（按实例 id）
			var seen: Dictionary = {}
			var deduped: Array = []
			for c in candidates:
				if c == null or not is_instance_valid(c):
					continue
				var key: int = c.get_instance_id()
				if seen.has(key):
					continue
				seen[key] = true
				deduped.append(c)
			candidates = deduped
	return _filter_targets(skill, candidates, event)


## 判断主动技能当前是否可使用（供 UI 确认按钮置灰判断）。
## 依次检查：active 非空、usable 次数、filter 通过；若技能需要选目标则要求存在合法候选。
func can_use_active_skill(skill: Variant) -> bool:
	if skill == null or not is_instance_valid(skill):
		return false
	if skill.active.is_empty():
		return false
	if not skill.is_usable():
		return false
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"target": null,
		"targets": [],
		"cards": [],
	})
	if not skill.execute_filter(self, event):
		return false
	# 需要选目标的技能（target_type 非空 或 select_target 非 0）：要求候选非空
	var target_type: String = skill.target_type
	var select_n: int = skill.select_target
	if target_type != "" or select_n != 0:
		var valid_targets: Array = get_skill_valid_targets(skill)
		if valid_targets.is_empty():
			return false
	return true


## 获取数值型状态。
func get_number(key: String) -> int:
	match key:
		"action_count":
			return action_count
		"hp":
			return hp
		"hunger":
			return hunger
		_:
			return 0


# === 十三、技能辅助方法 ===

## 弃置面前的一张非首领怪物并替换为怪物标记。
func discard_non_boss_monster_to_mark() -> void:
	var candidates: Array = []
	for m in monster_zone:
		if m != null and is_instance_valid(m) and m.monster_level != "boss":
			candidates.append(m)
	if candidates.is_empty():
		return
	var monster: Monster = await input.choose(candidates)
	if monster == null:
		return
	monster_zone.erase(monster)
	if Game != null and Game.monster_discard_pile != null:
		Game.monster_discard_pile.add(monster.monster_card)
	if current_block != null and current_block.has_method("add_monster_mark"):
		current_block.add_monster_mark(1)


## 向玩家拉近一格不触发效果。
func pull_one_step(target: Player) -> void:
	if target == null:
		return
	var source_block: MapBlock = current_block
	var target_block: MapBlock = target.get_current_block()
	if source_block == null or target_block == null:
		return
	if Game == null or not Game.has_method("get_step_toward"):
		return
	var next_block: MapBlock = Game.get_step_toward(source_block, target_block)
	if next_block == null:
		return
	current_block = next_block


## 治疗所有状态效果。
func heal_all_status() -> void:
	remove_mark("poison")
	remove_mark("hunger_damage_level")


## 立即打出一张牌（不消耗行动次数）。
func play_card_immediately() -> void:
	if hand.is_empty():
		return
	var saved_phase: String = in_phase
	in_phase = "action"
	var cards: Array = await input.choose_card(1, "hand")
	if cards.is_empty():
		in_phase = saved_phase
		return
	var card: Card = cards[0]
	if card.card_type == "equipment":
		equip(card)
	else:
		if card.has_method("trigger"):
			await card.trigger("on_use_card", EventSystem.create_event({}))
		discard(card)
	in_phase = saved_phase


# === 十四、任务系统方法 ===

## 收集物品（直接生成拾荒卡加入手牌区）。
func collect_item(card_name: String, quantity: int) -> void:
	for i in quantity:
		if Game != null and Game.has_method("create_scavenge_card"):
			var card: Card = Game.create_scavenge_card(card_name)
			if card == null:
				return
			hand.append(card)
	if Game != null:
		Game.log_message(LogColors.player(player_name) + " 获得了 " + str(quantity) + " 张 " + LogColors.card(card_name))


## 判断是否持有指定名字的物品（手牌+装备区）。
func has_item(card_name: String) -> bool:
	for card in hand:
		if card.card_name == card_name:
			return true
	for card in equipment_zone:
		if card.card_name == card_name:
			return true
	return false


## 从怪物牌堆中筛选首领卡抽取。
func draw_boss_card() -> void:
	if Game == null or Game.monster_pile == null:
		return
	var boss_card: MonsterCard = null
	# 1. 从怪物牌堆中筛选首领卡
	for i in Game.monster_pile.cards.size():
		if Game.monster_pile.cards[i].monster_level == "boss":
			boss_card = Game.monster_pile.cards.pop_at(i)
			break
	# 2. 牌堆中没有，从怪物弃牌堆中查找
	if boss_card == null and Game.monster_discard_pile != null:
		for i in Game.monster_discard_pile.cards.size():
			if Game.monster_discard_pile.cards[i].monster_level == "boss":
				boss_card = Game.monster_discard_pile.cards.pop_at(i)
				break
	# 3. 都没有
	if boss_card == null:
		Game.log_message("牌堆与弃牌堆中均无首领卡！")
		return
	# 4. 放到怪物牌堆顶部，复用 draw_monster(1)
	Game.monster_pile.cards.push_front(boss_card)
	draw_monster(1)


## 获得解救科学家的选项。
func rescue_scientist_option() -> void:
	var choice: String = await input.choose(["花费 1 行动解救科学家", "不解救"])
	if choice == "不解救":
		Game.log_message(LogColors.player(player_name) + " 选择不解救科学家。")
		return
	if action_count < 1:
		Game.log_message(LogColors.player(player_name) + " 行动次数不足，无法解救科学家。")
		return
	if Game == null or Game.mission_config == null:
		return
	var scientist: Variant = Game.mission_config.mission_state.get("scientist_equipment", null)
	if scientist == null:
		Game.log_message("科学家已被解救！")
		return
	reduce_action_count(1)
	equip(scientist)
	Game.mission_config.mission_state["scientist_equipment"] = null
	Game.mission_config.mission_state["scientist_rescued"] = true
	Game.log_message(LogColors.player(player_name) + " 解救了科学家，装备到面前！")


## 记录科学家信息。
func record_scientist_info() -> void:
	if Game == null or Game.mission_config == null:
		return
	Game.mission_config.mission_state["scientist_info_recorded"] = true
	Game.log_message(LogColors.player(player_name) + " 记录了科学家信息。")
