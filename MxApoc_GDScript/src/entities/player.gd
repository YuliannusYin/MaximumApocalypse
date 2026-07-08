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

# === 标记系统 ===
# Dictionary[String, int]：键 = 标记名，值 = 计数
var marks: Dictionary = {}

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
func recover(num: int) -> void:
	if num <= 0:
		return
	var event: Dictionary = EventSystem.create_recover_event(self, num)
	trigger("before_recover", event)
	trigger("on_recover", event)
	if EventSystem.is_cancelled(event):
		return
	var max_recover: int = get_max_hp() - get_hp()
	if event["num"] > max_recover:
		event["num"] = max_recover
	add_hp(event["num"])
	trigger("after_recover", event)


## 增加饥饿值。达 6 后翻面角色卡并叠加饥饿伤害标记。
func increase_hunger(num: int) -> void:
	if num <= 0:
		return
	while num > 0:
		if hunger < 6:
			hunger += 1
			if hunger == 6:
				# 刚达到 6：翻面 + 添加饥饿伤害标记
				if role_card != null and role_card.is_front():
					role_card.flip()
				add_mark("hunger_damage_level", 1)
		elif hunger == 6:
			# 已在 6：叠加标记
			if role_card != null and role_card.is_front():
				role_card.flip()
			add_mark("hunger_damage_level", 1)
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
				Game.log_message(player_name + "被饿死了")
				damage(get_max_hp(), null, "hunger")
		num -= 1


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
	if count_mark("hunger_damage_level") > 0:
		remove_mark("hunger_damage_level")
	if role_card != null and not role_card.is_front():
		role_card.flip()


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
	trigger("before_draw_game_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 抓取游戏牌时（取消点）
	trigger("on_draw_game_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 3. 逐张抓取
	var num_to_draw: int = event["num"]
	for i in num_to_draw:
		if game_deck == null or game_deck.is_empty():
			death(null)
			return
		var card: Card = game_deck.draw()
		hand.append(card)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.card_drawn.emit(self, card)
		event["cards"].append(card)
	# 4. 抓取游戏牌后
	trigger("after_draw_game_card", event)


## 从指定拾荒牌堆抓 n 张牌（4 节点）。
func draw_scavenge(n: int, pile: Pile) -> void:
	if n <= 0:
		return
	var event: Dictionary = EventSystem.create_draw_scavenge_event(self, pile, n)
	# 1. 抓取拾荒牌前（取消点）
	trigger("before_draw_scavenge_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张抓取
	var num_to_draw: int = event["num"]
	for i in num_to_draw:
		if pile == null or pile.is_empty():
			break
		var card: Card = pile.draw()
		hand.append(card)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.scavenge_drawn.emit(self, card)
		event["cards"].append(card)
		event["card"] = card
		# 3. 抓取拾荒牌时（每张触发）
		trigger("on_draw_scavenge_card", event)
	# 4. 抓取拾荒牌后
	trigger("after_draw_scavenge_card", event)


## 从怪物牌堆抓 n 张怪物卡（7 节点）。
func draw_monster(n: int) -> void:
	if n <= 0:
		return
	var event: Dictionary = EventSystem.create_draw_monster_event(self, n)
	# 1. 抓取怪物卡前（取消点）
	trigger("before_draw_monster_card", event)
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
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.monster_card_drawn.emit(self, card)
		# b. 抓取怪物卡时（每张触发）
		trigger("on_draw_monster_card", event)
		# c. 怪物卡进入求生者怪物区前（每张触发）
		trigger("before_monster_enter_zone", event)
		# d. 实体化（设置纠缠对象、初始化生命值）
		var monster: Monster = card.instantiate(self)
		# e. 怪物卡进入求生者怪物区时（每张触发）
		monster_zone.append(monster)
		trigger("on_monster_enter_zone", event)
		# f. 怪物卡进入求生者怪物区后（每张触发）
		trigger("after_monster_enter_zone", event)
	# 3. 抓取怪物卡后（整体触发一次）
	trigger("after_draw_monster_card", event)


# === 三、弃牌与销毁流程 ===

## 弃置卡牌到对应弃牌堆（3 节点）。
## target 可为 Card/Array[Card]/String（卡牌名）；position 为区域名；quantity 为数量。
func discard(target: Variant, position: String = "", quantity: int = 1, type: String = "") -> void:
	var cards_to_discard: Array = []
	if type != "":
		# 按类型弃置
		var all_cards: Array = get_cards(position)
		for card in all_cards:
			if card.card_type == target:
				cards_to_discard.append(card)
	elif target is Array:
		cards_to_discard = target.duplicate()
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
	trigger("before_discard", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张弃置
	for card in cards_to_discard:
		event["card"] = card
		# 装备区的牌先走卸下流程
		if equipment_zone.has(card):
			_unequip(card)
		else:
			_remove_card_from_zone(card)
		# 进入对应弃牌堆（按 source 分派）
		if card.source == "scavenge":
			if Game != null and Game.scavenge_discard_pile != null:
				Game.scavenge_discard_pile.add(card)
		else:
			if game_discard_pile != null:
				game_discard_pile.add(card)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.card_discarded.emit(self, card)
		# 触发弃置牌时
		trigger("on_discard", event)
	# 3. 弃置牌后
	trigger("after_discard", event)


## 销毁卡牌（移出游戏，3 节点）。
func remove_card(target: Variant, position: String = "", quantity: int = 1) -> void:
	var cards_to_remove: Array = []
	if target is Array:
		cards_to_remove = target.duplicate()
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
	trigger("before_remove_card", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. 逐张销毁
	for card in cards_to_remove:
		event["card"] = card
		event["cards"].append(card)
		_remove_card_from_zone(card)
		if Game != null:
			Game.remove_card(card)
		trigger("on_remove_card", event)
	# 3. 销毁牌后
	trigger("after_remove_card", event)


# === 四、移动流程 ===

## 底层移动函数（11 节点，不扣行动次数）。
func move_to(target: MapBlock) -> bool:
	var source: MapBlock = current_block
	var event: Dictionary = EventSystem.create_move_event(self, source, target)
	# 1. 离开地块前
	trigger("before_leave_block", event)
	# 2. 离开地块时
	trigger("on_leave_block", event)
	# 3. 离开地块后
	trigger("after_leave_block", event)
	# 4. 获取目标地块技能（先获取，再准入检定）
	if target != null and target.has_method("_acquire_skills_for_player"):
		target._acquire_skills_for_player(self)
	# 5. 进入地块前（取消点）
	trigger("before_enter_block", event)
	if EventSystem.is_cancelled(event):
		# 移动取消，回滚：移除刚获取的目标地块技能
		if target != null and target.has_method("_clear_skills_for_player"):
			target._clear_skills_for_player(self)
		return false
	# 6. 移动时（坐标变更）
	current_block = target
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_moved.emit(self, source, target)
	add_mark("moved_this_turn")
	# 7. 清理旧地块技能（移动成功后才清理）
	if source != null and source.has_method("_clear_skills_for_player"):
		source._clear_skills_for_player(self)
	# 8. 进入地块时（一次性效果）
	trigger("on_enter_block", event)
	# 9. 进入地块后（展示未展示的地块）
	if target != null and target.has_method("is_revealed"):
		if not target.is_revealed():
			target.reveal(true, self)
	trigger("after_enter_block", event)
	# 10. 潜行检定（地块有怪物标记时）
	if target != null and target.has_method("has_monster_mark") and target.has_monster_mark():
		if not sneak_judge():
			var num: int = target.count_monster_mark()
			target.remove_monster_mark(num)
			draw_monster(num)
	# 11. 触发目标标记
	if target != null and target.has_method("trigger_objective_marks"):
		target.trigger_objective_marks(self)
	return true


# === 五、检定系统 ===

## 基础检定：投两颗骰子，返回点数之和。
func judge() -> int:
	var d1: int = randi_range(1, 6)
	var d2: int = randi_range(1, 6)
	return d1 + d2


## 潜行检定（4 节点）。
func sneak_judge() -> bool:
	var block: MapBlock = current_block
	var monster_count: int = 0
	var mark_count: int = 0
	if block != null:
		if block.has_method("count_monster"):
			monster_count = block.count_monster()
		if block.has_method("count_monster_mark"):
			mark_count = block.count_monster_mark()
	var sneak_value: int = get_sneak() - (monster_count + mark_count)
	var event: Dictionary = EventSystem.create_sneak_judge_event(self, sneak_value)
	# 1. 潜行检定前
	trigger("before_sneak_judge", event)
	# 2. 系统投骰（若未跳过）
	if not event["skip_judge"]:
		var dice_value: int = judge()
		var success: bool = dice_value <= event["sneak_value"]
		event["result"] = {"value": dice_value, "success": success}
	# 3. 潜行检定时
	trigger("on_sneak_judge", event)
	# 4. 潜行检定后
	trigger("after_sneak_judge", event)
	return event["result"]["success"]


## 怪物出生检定（5 节点）。
func monster_spawn_judge() -> void:
	var event: Dictionary = EventSystem.create_spawn_judge_event(self)
	# 1. 怪物出生检定前
	trigger("before_spawn_judge", event)
	# 2. 系统投骰
	if not event["skip_judge"]:
		var dice_value: int = judge()
		event["result"] = {"value": dice_value, "success": true}
	# 3. 怪物出生检定时
	trigger("on_spawn_judge", event)
	# 4. 怪物出生检定后
	trigger("after_spawn_judge", event)
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
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_died.emit(self, source)
	var event: Dictionary = EventSystem.create_player_death_event(self, source)
	# 1. 玩家死亡前
	trigger("before_player_death", event)
	# 2. 玩家死亡时
	trigger("on_player_death", event)
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
	var scavenge_cards: Array = get_cards("", "", 0, "scavenge")
	for c in scavenge_cards:
		_remove_card_from_zone(c)
		if Game != null and c.has_method("get_color"):
			var pile: Pile = Game.get_scavenge_pile(c.get_color())
			if pile != null:
				pile.add(c)
	if Game != null:
		for color in ["red", "green", "blue"]:
			var pile: Pile = Game.get_scavenge_pile(color)
			if pile != null:
				pile.shuffle()
	trigger("after_player_death", event)
	# 检查游戏结束条件
	if Game != null and Game.coop_death_mode:
		Game.game_over("lose")
		return
	if Game != null and Game.all_players_dead():
		Game.game_over("lose")


# === 七、使用卡牌流程 ===

## 从手牌中使用一张卡牌（4 节点）。
func use_card(card: Card) -> bool:
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"card": card,
	})
	# 1. 使用卡牌前（取消点）
	trigger("before_use_card", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 使用卡牌时（取消点）
	trigger("on_use_card", event)
	if EventSystem.is_cancelled(event):
		return false
	# 3. 系统结算：统一消耗 1 点行动次数
	action_count -= 1
	# 按卡牌类型分流
	if card.card_type == "equipment":
		equip(card)
	else:
		# 行动牌：技能 content 由技能系统独立执行（此处简化为直接调用 card 上的技能）
		# 弃掉这张牌（按 source 分派）
		discard(card)
	# 4. 使用卡牌后
	trigger("after_use_card", event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.card_used.emit(self, card)
	return true


# === 八、装备流程 ===

## 装备进入装备区（3 节点 + 预校验）。
func equip(card: Card) -> bool:
	var event: Dictionary = EventSystem.create_equip_event(self, card)
	# 1. 卡牌进入装备区前（取消点）
	trigger("before_equip", event)
	if EventSystem.is_cancelled(event):
		return false
	# 系统预校验
	# a. 同名装备校验：弃置装备区中的同名装备
	var same_name: Array = []
	for e in equipment_zone:
		if e.card_name == card.card_name:
			same_name.append(e)
	for e in same_name:
		discard(e)
	# b. 装备栏容量校验（简化：不强制，阶段 1 容量由 RoleCard.equipment_capacity 约束）
	# 2. 卡牌进入装备区时
	equipment_zone.append(card)
	# 装备技能挂载到玩家
	if card.has_method("get_all_skills"):
		for s in card.get_all_skills():
			add_skill(s)
	trigger("on_equip", event)
	# 3. 卡牌进入装备区后
	trigger("after_equip", event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.equipment_equipped.emit(self, card)
	return true


## 装备离开装备区（3 节点）。
func unequip(card: Card) -> bool:
	var event: Dictionary = EventSystem.create_equip_event(self, card)
	# 1. 卡牌离开装备区前（取消点）
	trigger("before_unequip", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 卡牌离开装备区时
	equipment_zone.erase(card)
	# 移除装备技能
	if card.has_method("get_all_skills"):
		for s in card.get_all_skills():
			remove_skill(s)
	trigger("on_unequip", event)
	# 3. 卡牌离开装备区后
	trigger("after_unequip", event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.equipment_unequipped.emit(self, card)
	return true


# === 九、填充物流程 ===

## 装备填充物消耗（4 节点 + 耗尽衍生）。
func consume_charge(equipment: EquipmentCard, num: int) -> bool:
	# 前置校验：填充物不足时取消
	if equipment == null or not equipment.has_method("get_charge"):
		return false
	if equipment.get_charge() < num:
		return false
	var event: Dictionary = EventSystem.create_consume_charge_event(self, equipment, num)
	# 1. 消耗填充物前（取消点）
	trigger("before_consume_charge", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 消耗填充物时（取消点）
	trigger("on_consume_charge", event)
	if EventSystem.is_cancelled(event):
		return false
	# 3. 系统扣减
	if equipment.has_method("consume_charge"):
		equipment.consume_charge(event["num"])
	# 4. 消耗填充物后
	trigger("after_consume_charge", event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.charge_consumed.emit(self, equipment, num)
	# 5. 衍生：填充物耗尽时
	if equipment.get_charge() <= 0:
		trigger("on_charge_depleted", event)
	return true


# === 十、回合流程 ===

## 玩家回合完整流程（21 节点，节点 21 由状态机执行）。
func start_turn() -> void:
	var event: Dictionary = EventSystem.create_event({"player": self})
	# 节点 1：进入玩家回合（非钩子节点）
	in_phase = "turn_start"
	action_count = max_action_count
	clear_turn_marks()
	# 节点 2：回合开始前
	trigger("before_turn_start", event)
	# 节点 3：回合开始时
	trigger("on_turn_start", event)
	# 节点 4：怪物出生前
	in_phase = "monster_spawn"
	trigger("before_monster_spawn", event)
	# 节点 5：怪物出生时
	trigger("on_monster_spawn", event)
	monster_spawn_judge()
	# 节点 6：摸牌阶段前
	in_phase = "draw"
	trigger("before_draw_phase", event)
	# 节点 7：摸牌阶段（牌堆空 → 死亡）
	draw(1)
	if not is_alive():
		return
	# 节点 8：行动阶段前（含潜行检定）
	in_phase = "action"
	if current_block != null and current_block.has_method("has_monster_mark"):
		if current_block.has_monster_mark():
			if not sneak_judge():
				var num: int = current_block.count_monster_mark()
				current_block.remove_monster_mark(num)
				draw_monster(num)
	trigger("before_action_phase", event)
	# 节点 9：行动阶段
	wait_player_action()
	# 节点 10：行动阶段结束前
	trigger("before_action_phase_end", event)
	# 节点 11：行动阶段结束时
	trigger("on_action_phase_end", event)
	# 节点 12：求生者饥饿状态结算前
	in_phase = "hunger"
	trigger("before_hunger_settlement", event)
	# 节点 13：求生者饥饿状态结算时
	trigger("on_hunger_settlement", event)
	increase_hunger(1)
	if not is_alive():
		return
	# 节点 14：求生者中毒状态结算前
	in_phase = "poison"
	trigger("before_poison_settlement", event)
	# 节点 15：求生者中毒状态结算时
	trigger("on_poison_settlement", event)
	poison()
	if not is_alive():
		return
	# 节点 16：面前怪物行动前
	in_phase = "monster_action"
	trigger("before_zone_monster_act", event)
	# 节点 17：面前怪物行动时
	trigger("on_zone_monster_act", event)
	var monsters_copy: Array = monster_zone.duplicate()
	for monster in monsters_copy:
		if monster != null and is_instance_valid(monster):
			monster.act()
	if not is_alive():
		return
	# 节点 18：回合结束前
	in_phase = "turn_end"
	trigger("before_turn_end", event)
	# 节点 19：回合结束时
	trigger("on_turn_end", event)
	# 节点 20：退出玩家回合
	in_phase = "idle"


# === 十一、迷你回合流程 ===

## 立即执行一个行动（仅含行动阶段）。
func execute_action_immediately(num: int = 1) -> void:
	var saved_phase: String = in_phase
	in_phase = "action"
	action_count = num
	wait_player_action()
	in_phase = saved_phase


# === 十二、底层接口与工具方法 ===

## 饥饿值读写
func get_hunger() -> int:
	return hunger


func add_hunger(n: int) -> void:
	hunger += n


func reduce_hunger(n: int) -> void:
	hunger = maxi(hunger - n, 1)


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


func _card_matches(card: Card, name: String, source: String) -> bool:
	if name != "" and card.card_name != name:
		return false
	if source != "" and card.source != source:
		return false
	return true


## 返回所有求生者游戏牌（手牌+装备+牌堆+弃牌堆）。
func get_all_game_cards() -> Array:
	var result: Array = []
	result.append_array(hand)
	result.append_array(equipment_zone)
	if game_deck != null:
		result.append_array(game_deck.get_all())
	if game_discard_pile != null:
		result.append_array(game_discard_pile.get_all())
	return result


## 从所在区域移除一张牌（内部方法）。
func _remove_card_from_zone(card: Card) -> void:
	hand.erase(card)
	equipment_zone.erase(card)


## 内部卸下装备（不触发钩子，供 discard 流程复用）。
func _unequip(card: Card) -> void:
	equipment_zone.erase(card)
	if card != null and typeof(card) == TYPE_OBJECT and card.has_method("get_all_skills"):
		for s in card.get_all_skills():
			remove_skill(s)


## 玩家面前是否有非首领怪物。
func has_non_boss_monster() -> bool:
	for m in monster_zone:
		if m != null and is_instance_valid(m) and m.monster_level != "boss":
			return true
	return false


## 标记管理
func count_mark(name: String) -> int:
	return marks.get(name, 0)


func add_mark(name: String, quantity: int = 1) -> void:
	marks[name] = count_mark(name) + quantity


func remove_mark(name: String) -> void:
	marks.erase(name)


func has_mark(name: String) -> bool:
	return count_mark(name) > 0


func clear_turn_marks() -> void:
	# 清除持续到回合结束的临时标记
	marks.erase("moved_this_turn")
	marks.erase("shelter_disabled")


## 装备管理
func has_equipment(name: String) -> bool:
	for e in equipment_zone:
		if e.card_name == name:
			return true
	return false


func get_equipment(name: String) -> EquipmentCard:
	for e in equipment_zone:
		if e.card_name == name:
			return e
	return null


## 选择器（委托 input）
func choose(options: Array, prompt: String = "") -> Variant:
	return input.choose(options, prompt)


func choose_card(n: int, position: String = "hand", filter: Variant = null) -> Array:
	return input.choose_card(n, position, filter)


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	return input.choose_map_block(blocks, prompt)


func show_card(card: Card, target: Variant) -> void:
	input.show_card(card, target)


## 占位方法：等待玩家通过 UI 选择行动。
func wait_player_action() -> void:
	input.wait_action(self)


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
	var monster: Monster = input.choose(candidates)
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
	var cards: Array = input.choose_card(1, "hand")
	if cards.is_empty():
		in_phase = saved_phase
		return
	var card: Card = cards[0]
	if card.card_type == "equipment":
		equip(card)
	else:
		if card.has_method("trigger"):
			card.trigger("on_use_card", EventSystem.create_event({}))
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
		Game.log_message(player_name + " 获得了 " + str(quantity) + " 张 " + card_name)


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
	var choice: String = input.choose(["花费 1 行动解救科学家", "不解救"])
	if choice == "不解救":
		Game.log_message(player_name + " 选择不解救科学家。")
		return
	if action_count < 1:
		Game.log_message(player_name + " 行动次数不足，无法解救科学家。")
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
	Game.log_message(player_name + " 解救了科学家，装备到面前！")


## 记录科学家信息。
func record_scientist_info() -> void:
	if Game == null or Game.mission_config == null:
		return
	Game.mission_config.mission_state["scientist_info_recorded"] = true
	Game.log_message(player_name + " 记录了科学家信息。")
