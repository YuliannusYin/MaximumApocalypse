class_name Player
extends Entity

const TurnContextScript = preload("res://src/core/turn_context.gd")
const PhaseEventScript = preload("res://src/core/phase_event.gd")
const TurnEventScript = preload("res://src/core/turn_event.gd")

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
var _card_effect_in_progress: bool = false  # 行动牌已统一预扣行动点，兼容旧 content 扣点
var _pending_card_settlement: Card = null  # defer_action_cost 卡牌等待 content 首次选择完成
var _pending_card_cost_free: bool = false  # 当前待结算卡牌是否由有限操作免费使用
var _card_cost_paid_by_content: bool = false
var _operation_context_stack: Array[Dictionary] = []
var _operation_runtime_stack: Array = []
var _turn_context: RefCounted = null
var _turn_event: Variant = null  # TurnEvent，统一事件树的正式回合节点
var _phase_sequence: int = 0

# === 区域字段 ===
var hand: Array = []  # List<Card>，上限 10
var card_settlement_zone: Array = []  # List<Card>，正在结算的行动牌
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
	var old_value: int = hp
	hp = maxi(hp - n, 0)
	if hp != old_value and EventBus != null and is_instance_valid(EventBus):
		EventBus.player_hp_changed.emit(self, old_value, hp)


func add_hp(n: int) -> void:
	var old_value: int = hp
	hp = mini(hp + n, max_hp)
	if hp != old_value and EventBus != null and is_instance_valid(EventBus):
		EventBus.player_hp_changed.emit(self, old_value, hp)


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
				await damage(2, null, "hunger")
			elif level == 2:
				await damage(4, null, "hunger")
			elif level == 3:
				await damage(6, null, "hunger")
			elif level == 4:
				await damage(8, null, "hunger")
			elif level >= 5:
				Game.log_message(LogColors.player(player_name) + " 被饿死了")
				await damage(get_max_hp(), null, "hunger")
		num -= 1
	EventBus.player_hunger_changed.emit(self, old_hunger, hunger)


## 事件化的饥饿增加；保留 increase_hunger 兼容既有 JSON。
func increase_hunger_evented(num: int) -> bool:
	var event: Dictionary = EventSystem.create_hunger_event(self, num, "increase")
	await trigger("before_increase_hunger", event)
	if EventSystem.is_cancelled(event):
		return false
	await trigger("on_increase_hunger", event)
	if EventSystem.is_cancelled(event):
		return false
	await increase_hunger(event["num"])
	await trigger("after_increase_hunger", event)
	return true

## 减少饥饿值。最低降至 1，减少后清除饥饿伤害标记并恢复角色卡正面。
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


## 事件化的饥饿减少；保留 decrease_hunger 兼容既有 JSON。
func decrease_hunger_evented(num: int) -> bool:
	var event: Dictionary = EventSystem.create_hunger_event(self, num, "decrease")
	await trigger("before_decrease_hunger", event)
	if EventSystem.is_cancelled(event):
		return false
	await trigger("on_decrease_hunger", event)
	if EventSystem.is_cancelled(event):
		return false
	decrease_hunger(event["num"])
	await trigger("after_decrease_hunger", event)
	return true


## 中毒结算。中毒标记数 = 受到无来源伤害值。
func poison() -> void:
	if count_mark("poison") > 0:
		var num: int = count_mark("poison")
		await damage(num, null, "poison")


func poison_evented() -> bool:
	var event: Dictionary = EventSystem.create_poison_event(self, count_mark("poison"))
	await trigger("before_poison", event)
	if EventSystem.is_cancelled(event):
		return false
	await trigger("on_poison", event)
	if EventSystem.is_cancelled(event):
		return false
	if event["num"] > 0:
		await damage(event["num"], null, "poison")
	await trigger("after_poison", event)
	return true


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
	var drawn_cards: Array = []
	for i in num_to_draw:
		if game_deck == null or game_deck.is_empty():
			death(null)
			return
		var card: Card = game_deck.draw()
		hand.append(card)
		drawn_cards.append(card)
		_drawn_names.append(LogColors.card(card.card_name))
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.card_drawn.emit(self, card)
		event["cards"].append(card)
	# 批量输出抓牌日志
	if _drawn_names.size() > 0 and Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 抓取了游戏牌 " + ", ".join(_drawn_names))
	# 手牌超限结算（先入手后判定：整批合并为单次弹窗；死亡 return 路径不结算）
	await resolve_hand_overflow(drawn_cards)
	# 4. 抓取游戏牌后
	await trigger("after_draw_game_card", event)


## 将卡牌加入手牌区（content 代码调用入口）。
## 手牌满时先入手，超限由 try_add_card_to_hand 内的 resolve_hand_overflow 弹窗结算（含 await，为协程入口）。
func gain(card: Card) -> void:
	await try_add_card_to_hand(card)


## 将卡牌加入手牌区（先入手，超限随后结算）。
## 返回 true = card 已加入手牌（若超限已触发弹窗结算）。
func try_add_card_to_hand(card: Card) -> bool:
	hand.append(card)
	await resolve_hand_overflow([card])
	return true


## 手牌入手后超限结算：手牌数超上限时弹窗弃置恰好 K 张（K = 超出数）。
## new_cards 为本批新入手的牌（取消时自动弃置新牌直到不超限，后入手的先弃）。
func resolve_hand_overflow(new_cards: Array) -> void:
	if role_card == null:
		return
	var k: int = hand.size() - role_card.hand_size_limit
	if k <= 0:
		return
	# 单次弹窗：精确模式弃置恰好 K 张手牌
	var discard_filter := Callable(self, "_discardable_card_filter")
	var selected: Array = await choose_card(k, "hand", discard_filter, "\"手牌超限\": 请弃置 %d 张手牌" % k)
	# 输入层之外仍做一次校验，防止 CLI/脚本注入受保护卡牌。
	selected = _filter_discardable_cards(selected)
	if selected.is_empty():
		# 玩家取消：自动弃置 new_cards 中后入手的 K 张（从数组末尾往前取仍在手牌中的牌）
		var auto_names: Array = []
		for i in range(new_cards.size() - 1, -1, -1):
			if auto_names.size() >= k:
				break
			var nc: Card = new_cards[i]
			if nc != null and is_instance_valid(nc) and hand.has(nc) and not is_card_protected_from_discard(nc):
				await discard(nc, "", 1, "", true)
				auto_names.append(LogColors.card(nc.card_name))
		if auto_names.size() > 0 and Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 手牌超限，自动弃置了 " + ", ".join(auto_names))
		return
	# 选中：逐张弃置所选牌（带默认弃牌日志）
	for c in selected:
		await discard(c)


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
	# 播放"抓取时"技能触发动画（居中翻卡展示后原地放大淡出），动画播完前阻塞流程
	if not mounted_skills.is_empty():
		await _play_scavenge_draw_animation(card)
	await trigger_only("on_draw_scavenge_card", event, mounted_skills)
	# 手牌超限结算（先入手、抓取技能结算完再弹窗；技能可能改变手牌，K 动态计算天然正确）
	await resolve_hand_overflow([card])


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
		# 播放抓取怪物牌动画（居中翻卡展示后飞向持有者面板怪物区），动画播完前阻塞流程
		await _play_monster_draw_animation(card)
		# b. 抓取怪物卡时（每张触发）
		await trigger("on_draw_monster_card", event)
		# c. 怪物卡进入求生者怪物区前（每张触发）
		await trigger("before_monster_enter_zone", event)
		# d. 实体化（设置纠缠对象、初始化生命值）
		var monster: Monster = card.instantiate(self)
		# e. 怪物卡进入求生者怪物区时（每张触发）
		monster_zone.append(monster)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.monster_spawned.emit(monster, self)
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
## 装备区命中时走 `_unequip`（触发 on_unequip，不经过 before_unequip 取消点），
## 并把来源 EquipmentCard 送入弃牌堆（弃牌堆永远收来源卡）。
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
	# 特殊卡牌不可作为弃置目标（例如“科学家”，包括手牌中的科学家）。
	cards_to_discard = _filter_discardable_cards(cards_to_discard)
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
			# 装备区实体：离开装备区（on_unequip）+ 来源卡入弃牌堆
			await _unequip(entity)
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
			var was_in_settlement: bool = card_settlement_zone.has(card)
			await _remove_card_from_zone(card)
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
				if was_in_settlement:
					EventBus.card_settlement_finished.emit(self, card)
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
	# 特殊卡牌不可作为移出游戏目标（例如“科学家”，包括手牌中的科学家）。
	cards_to_remove = _filter_discardable_cards(cards_to_remove)
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
		# 销毁演出在实际移出区域前完成，确保展示的卡面仍与当前状态一致。
		if input != null and src_card is Card:
			_prepare_input_request()
			await input.play_card_destroy_animation(src_card)
		await _remove_card_from_zone(card)
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
	# 4. 获取目标地块技能（先获取，再准入检定）；并列挂载任务行动技能
	if target != null and target.has_method("_acquire_skills_for_player"):
		target._acquire_skills_for_player(self)
	if target != null and Game != null and is_instance_valid(Game) and Game.mission_config != null:
		Game.mission_config.mount_action_skills(self, target)
	# 5. 进入地块前（取消点）
	await trigger("before_enter_block", event)
	if EventSystem.is_cancelled(event):
		# 移动取消，回滚：移除刚获取的目标地块技能（旧地块技能本就未移除，无需恢复）；
		# 任务行动技能在挂载时已被卸载，需卸载目标地块的并按旧地块重挂，
		# 使回滚后玩家持有的技能与留在旧地块的状态一致
		if target != null and target.has_method("_clear_skills_for_player"):
			target._clear_skills_for_player(self)
		if Game != null and is_instance_valid(Game) and Game.mission_config != null:
			Game.mission_config.unmount_action_skills(self)
			if source != null and is_instance_valid(source):
				Game.mission_config.mount_action_skills(self, source)
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
			await draw_monster(num)
	# 11. 触发目标标记
	if target != null and target.has_method("trigger_objective_marks"):
		await target.trigger_objective_marks(self)
	return true


## 把本玩家向 source 拉近 1 格（轮床等效果用，不触发地图块效果：
## 无进出地块事件、无潜行检定、无目标标记；仅维护地块技能挂载与基础移动状态）。
func pull_toward_one_block_no_effect(source: Variant) -> void:
	if source == null or not is_instance_valid(source) or not source.has_method("is_player"):
		return
	var source_block: MapBlock = source.current_block
	var from_block: MapBlock = current_block
	if source_block == null or from_block == null or from_block == source_block:
		return
	# 在当前地块的相邻地块中选距离 source 最近的一格
	var best: MapBlock = null
	var best_dist: int = -1
	for block in from_block.get_adjacent_blocks():
		if block == null or not is_instance_valid(block) or not block.is_alive():
			continue
		var d: int = block.distance_to(source_block)
		if best == null or d < best_dist:
			best = block
			best_dist = d
	if best == null or best == from_block:
		return
	# 维护地块技能挂载（移除旧地块技能、获取新地块技能，不触发任何事件）；
	# 并列维护任务行动技能挂载（卸载旧地块的、挂载新地块的）
	from_block._clear_skills_for_player(self)
	best._acquire_skills_for_player(self)
	if Game != null and is_instance_valid(Game) and Game.mission_config != null:
		Game.mission_config.unmount_action_skills(self)
		Game.mission_config.mount_action_skills(self, best)
	# 坐标变更（与 move_to 的第 6 步保持一致的状态记录）
	current_block = best
	add_mark("moved_this_turn", 1, "", "", false)
	if not best.is_revealed():
		best.reveal(false, self)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(source.player_name) + " 将 " + LogColors.player(player_name) + " 拉近至 " + LogColors.block(best.block_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.player_moved.emit(self, from_block, best)


# === 五、检定系统 ===

## 投两颗骰子，返回两颗各自点数 [d1, d2]。
func roll_dice() -> Array:
	return [randi_range(1, 6), randi_range(1, 6)]


## 基础检定：投两颗骰子，返回点数之和。
func judge() -> int:
	var dice: Array = roll_dice()
	return dice[0] + dice[1]


## 检定确认门包装：等待玩家确认是否执行检定（input 为空时默认确定）。
func _wait_judge_confirm(prompt: String, allow_cancel: bool) -> bool:
	if input == null or not is_instance_valid(input):
		return true
	_prepare_input_request()
	return await input.wait_judge_confirm(self, prompt, allow_cancel)


## 骰子动画包装：播放两颗骰子投掷动画并等待结束（input 为空时跳过）。
func _play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	if input == null or not is_instance_valid(input):
		return
	_prepare_input_request()
	await input.play_dice_animation(d1, d2, label, outcome)


## 播放抓取怪物牌动画（居中翻卡展示后飞向持有者面板怪物区），动画播完前阻塞流程。
func _play_monster_draw_animation(card: MonsterCard) -> void:
	if input == null or not is_instance_valid(input):
		return
	_prepare_input_request()
	await input.play_monster_draw_animation(self, card)


## 播放"抓取时"技能触发动画（居中翻卡展示后原地放大淡出），动画播完前阻塞流程。
func _play_scavenge_draw_animation(card: Card) -> void:
	if input == null or not is_instance_valid(input):
		return
	_prepare_input_request()
	await input.play_scavenge_draw_animation(self, card)


## 潜行检定（4 节点，投骰前含确认门，确认后播放骰子动画）。
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
	var abandoned: bool = false
	# 2. 系统投骰（若未跳过）
	if not event["skip_judge"]:
		if not await _wait_judge_confirm("是否执行 \"潜行检定\"", true):
			# 玩家放弃：不投骰，结果保持初始失败
			abandoned = true
		else:
			var dice: Array = roll_dice()
			var dice_value: int = dice[0] + dice[1]
			var success: bool = dice_value <= event["sneak_value"]
			await _play_dice_animation(dice[0], dice[1], "潜行检定", "成功" if success else "失败")
			if Game != null and is_instance_valid(Game):
				Game.log_message(LogColors.player(player_name) + " 执行了 " + LogColors.skill("潜行检定") + ", 点数为 " + str(dice_value))
			event["result"] = {"value": dice_value, "success": success}
	# 3. 潜行检定时
	await trigger("on_sneak_judge", event)
	# 4. 潜行检定后
	await trigger("after_sneak_judge", event)
	if Game != null and is_instance_valid(Game):
		if event["result"]["success"]:
			Game.log_message(LogColors.player(player_name) + " 潜行成功")
		elif abandoned:
			Game.log_message(LogColors.player(player_name) + " 放弃了潜行检定，潜行失败")
		else:
			Game.log_message(LogColors.player(player_name) + " 潜行失败")
	return event["result"]["success"]


## 怪物出生检定（5 节点，投骰前含确认门（仅确定），确认后播放骰子动画）。
func monster_spawn_judge() -> void:
	var event: Dictionary = EventSystem.create_spawn_judge_event(self)
	# 1. 怪物出生检定前
	await trigger("before_spawn_judge", event)
	# 2. 系统投骰
	if not event["skip_judge"]:
		await _wait_judge_confirm("执行 \"怪物生成\"", false)
		var dice: Array = roll_dice()
		var dice_value: int = dice[0] + dice[1]
		await _play_dice_animation(dice[0], dice[1], "怪物生成", "")
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 执行了 " + LogColors.skill("怪物生成") + ", 点数为 " + str(dice_value))
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.monster_spawn_judged.emit(self, dice_value)
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
							await p.draw_monster(1)


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
	# 3-equip. 装备区全部离开（触发 on_unequip），再按来源分流：游戏牌移出游戏，拾荒牌洗回颜色牌堆
	var equipped: Array = equipment_zone.duplicate()
	for e in equipped:
		if e == null or not is_instance_valid(e):
			continue
		var eq_src: Variant = e.equipment_card if e is Equipment else e
		await _unequip(e)
		if eq_src == null:
			continue
		if eq_src.get("source") == "scavenge":
			if Game != null and eq_src.has_method("get_color"):
				var eq_pile: Pile = Game.get_scavenge_pile(eq_src.get_color())
				if eq_pile != null:
					eq_pile.add(eq_src)
		elif Game != null:
			Game.remove_card(eq_src)
	# 3b. 其余求生者游戏牌移出游戏（装备区已在 3-equip 处理）
	var game_cards: Array = get_all_game_cards()
	for c in game_cards:
		if Game != null:
			Game.remove_card(c)
	# 3c. 其余拾荒卡按颜色洗回对应拾荒牌堆
	var scavenge_cards: Array = get_cards("", "", 0, "scavenge")
	for c in scavenge_cards:
		await _remove_card_from_zone(c)
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
## free_action=true 时仍走完整卡牌生命周期，但不消耗目标玩家正式行动点。
## operation_runtime 用于让卡牌 content 的嵌套 actions 继续挂在同一操作事件栈。
func use_card(card: Card, free_action: bool = false, operation_runtime: Variant = null) -> bool:
	if card == null or not is_instance_valid(card) or not hand.has(card):
		return false
	if not free_action and get_effective_action_count() < 1:
		return false
	var event: Dictionary = EventSystem.create_event({
		"player": self,
		"card": card,
		"target": null,
		"targets": [],
		"cards": [],
		"free_action": free_action,
	})
	if operation_runtime != null:
		event["actions"] = GameActions.new(self, Game, operation_runtime)
	# 1. 使用卡牌前（取消点）
	await trigger("before_use_card", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 使用卡牌时（取消点）
	await trigger("on_use_card", event)
	if EventSystem.is_cancelled(event):
		return false
	# 3. 按卡牌类型分流
	if card.card_type == "equipment":
		if not free_action and not await consume_action_evented(1):
			return false
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.card(card.card_name))
		await equip(card)
	else:
		# 行动牌：执行 card 上声明 active="action" 的 skill 的完整流程
		var skill_executed: bool = false
		var use_logged: bool = false
		var settlement_started: bool = false
		var deferred_card: bool = false
		_card_cost_paid_by_content = false
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
				# select_target_min：范围模式下允许选 [min_n, select_n] 个目标（-1 = 精确模式）
				var min_n: int = skill.select_target_min
				targets = await choose_target(select_n, skill, skill.window_prompt, min_n)
				if targets.is_empty():
					if skill.defer_action_cost:
						return false  # 首次目标选择取消：卡牌保留在手牌
					continue  # 玩家取消
				event["target"] = targets[0]
				event["targets"] = targets
			elif select_n == -1:
				# 自动选取全部合法目标（由 UI 层 _on_choose_target_requested 处理）
				targets = await choose_target(-1, skill, skill.window_prompt)
				if targets.is_empty():
					if skill.defer_action_cost:
						return false  # 首次目标选择取消：卡牌保留在手牌
					continue
				event["target"] = targets[0] if not targets.is_empty() else null
				event["targets"] = targets
			# select_card 选牌（若有）
			var select_card_n: int = skill.select_card
			if select_card_n > 0:
				var cards: Array = await choose_card(select_card_n, "hand", skill.filter_card)
				event["cards"] = cards
				if cards.size() < select_card_n and skill.defer_action_cost:
					return false  # 首次选牌取消：卡牌保留在手牌
			# 输出使用日志（有非自身目标时输出"对目标使用了"，否则输出"使用了"）
			if not use_logged and Game != null and is_instance_valid(Game):
				var _target: Variant = event.get("target", null)
				if _target != null and _target != self:
					Game.log_message(LogColors.player(player_name) + " 对 " + _format_target_name(_target) + " 使用了 " + LogColors.card(card.card_name))
				else:
					Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.card(card.card_name))
				use_logged = true
			# 效果开始前统一消耗 1 点行动次数，并把牌移入结算区。
			# 目标/选牌取消发生在此之前，不消耗行动点，牌也保留在手牌。
			if not settlement_started:
				if skill.defer_action_cost:
					# content 内通常会先完成一次选择，再调用 consume_action。
					# 在该调用点完成“进入结算区 → 扣行动点”。
					_pending_card_settlement = card
					_pending_card_cost_free = free_action
					_card_cost_paid_by_content = false
					deferred_card = true
				else:
					if not begin_card_settlement(card):
						return false
					if not free_action and not await consume_action_evented(1):
						cancel_card_settlement(card)
						return false
					settlement_started = true
			# 执行 content（content 可通过 EventSystem.cancel(event) 取消）
			_card_effect_in_progress = true
			await skill.execute_content(self, event)
			_card_effect_in_progress = false
			if deferred_card:
				_pending_card_settlement = null
				_pending_card_cost_free = false
				if not _card_cost_paid_by_content:
					_card_cost_paid_by_content = false
					return false
				settlement_started = true
			skill_executed = true
		# 若所有 skill 的 filter 均不通过，仍输出"使用了"日志
		if not use_logged and Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.card(card.card_name))
		# 弃牌（在 content 执行后，静默弃置不输出"弃置了"日志）
		# 若 content 已销毁牌（移出游戏），跳过弃置
		if Game != null and is_instance_valid(Game) and Game.removed_cards.has(card):
			pass  # 牌已被 content 销毁，跳过弃置
		elif not settlement_started:
			# 没有可执行技能时保持原行为：从手牌直接弃置。
			await discard(card, "", 1, "", true)
		else:
			await finish_card_settlement(card)
		_card_cost_paid_by_content = false
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
			var overflow_candidates: Array = []
			for e in get_discardable_equipment_cards():
				if int(e.get("size")) > 0:
					overflow_candidates.append(e)
			var selected: Array = await choose_card(1, overflow_candidates, null, "\"装备栏超限\": 请弃置装备区中的装备以容纳新装备")
			if selected.is_empty():
				# 玩家取消：中止装备流程，这张打算装备的牌（仍在手牌）因装备栏超限被弃置
				EventSystem.cancel(event)
				await discard(card, "", 1, "", true)
				if Game != null and is_instance_valid(Game):
					Game.log_message(LogColors.player(player_name) + " 装备栏超限，弃置了 " + LogColors.card(card.card_name))
				return false
			await discard(selected[0])
			total_size = 0
			for e in equipment_zone:
				if e != null and is_instance_valid(e):
					total_size += int(e.get("size"))
	# 2. 卡牌进入装备区时
	# 从来源区域取出（手牌 / 牌堆 / 弃牌堆等），避免同一张来源卡仍留在牌堆被抽到手牌，
	# 与装备实体共享 charge_current（枪手开局从牌堆装备柯尔特即此路径）。
	_take_card_for_equip(card)
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


## 装备离开装备区（3 节点）。仅对外接口经过 before_unequip 取消点。
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
	await _unequip(entity, true, event)
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
	var turn_number: int = 0
	if Game != null and is_instance_valid(Game) and Game.state_machine != null:
		turn_number = Game.state_machine.turn_number
	var phase_event: Variant = begin_turn_context("turn_start", turn_number, max_action_count)
	event["turn_context"] = _turn_context
	event["phase_event"] = phase_event
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
	phase_event = _enter_turn_phase("monster_spawn")
	event["phase_event"] = phase_event
	await trigger("before_monster_spawn", event)
	# 节点 5：怪物出生时
	await trigger("on_monster_spawn", event)
	await monster_spawn_judge()
	# 节点 6：摸牌阶段前
	phase_event = _enter_turn_phase("draw")
	event["phase_event"] = phase_event
	await trigger("before_draw_phase", event)
	# 节点 7：摸牌阶段（牌堆空 → 死亡；手牌超限时由 draw 内的 resolve_hand_overflow 弹窗弃牌）
	await draw(1)
	if not is_alive():
		return
	# 节点 8：行动阶段前（含潜行检定）
	phase_event = _enter_turn_phase("action")
	event["phase_event"] = phase_event
	if current_block != null and current_block.has_method("has_monster_mark"):
		if current_block.has_monster_mark():
			if not await sneak_judge():
				var num: int = current_block.count_monster_mark()
				current_block.remove_monster_mark(num)
				await draw_monster(num)
	await trigger("before_action_phase", event)
	# 节点 9：行动阶段
	await wait_player_action()
	# 节点 10：行动阶段结束前
	await trigger("before_action_phase_end", event)
	# 节点 11：行动阶段结束时
	await trigger("on_action_phase_end", event)
	# 节点 12：求生者饥饿状态结算前
	phase_event = _enter_turn_phase("hunger")
	event["phase_event"] = phase_event
	await trigger("before_hunger_settlement", event)
	var hunger_cancelled: bool = EventSystem.is_cancelled(event)
	if not hunger_cancelled:
		# 节点 13：求生者饥饿状态结算时
		await trigger("on_hunger_settlement", event)
		await increase_hunger_evented(1)
		if not is_alive():
			return
	# 节点 14：求生者中毒状态结算前
	phase_event = _enter_turn_phase("poison")
	event["phase_event"] = phase_event
	await trigger("before_poison_settlement", event)
	# 节点 15：求生者中毒状态结算时
	await trigger("on_poison_settlement", event)
	await poison_evented()
	if not is_alive():
		return
	# 节点 16：面前怪物行动前
	phase_event = _enter_turn_phase("monster_action")
	event["phase_event"] = phase_event
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
	phase_event = _enter_turn_phase("turn_end")
	event["phase_event"] = phase_event
	await trigger("before_turn_end", event)
	# 节点 19：回合结束时
	await trigger("on_turn_end", event)
	# 节点 20：退出玩家回合
	phase_event = _enter_turn_phase("idle")
	event["phase_event"] = phase_event
	finish_turn_context()


# === 十一、迷你回合流程 ===

## 立即执行一个行动（仅含行动阶段）。
func execute_action_immediately(num: int = 1, operation_runtime: Variant = null) -> Dictionary:
	var runtime: OperationRuntime = operation_runtime if operation_runtime is OperationRuntime else OperationRuntime.new()
	var context: Dictionary = runtime.get_current_context()
	if context.is_empty():
		context = runtime.create_limited_action_context(self, null, num)
		context["kind"] = "limited_action"
		context["owner"] = self
		context["requested_actions"] = maxi(num, 0)
		context["remaining_actions"] = maxi(num, 0)
	if not context.has("requested_actions"):
		context["requested_actions"] = maxi(num, 0)
	if not context.has("remaining_actions"):
		context["remaining_actions"] = maxi(num, 0)
	_operation_context_stack.append(context)
	_operation_runtime_stack.append(runtime)
	var result: Dictionary = await wait_player_action(context)
	_operation_runtime_stack.pop_back()
	_operation_context_stack.pop_back()
	context["completed"] = true
	context["reason"] = result.get("reason", "")
	return result


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
		EventBus.player_hunger_changed.emit(self, hunger_before, hunger)


## 潜行值（含饥饿状态修正）
func get_sneak() -> int:
	if role_card != null:
		return stealth + role_card.get_sneak()
	return stealth


func add_sneak(n: int) -> void:
	stealth += n


func reduce_sneak(n: int) -> void:
	stealth = maxi(stealth - n, 0)


## 当前玩家的最内层有限操作上下文。正式回合没有该上下文。
func get_operation_context() -> Dictionary:
	if _operation_context_stack.is_empty():
		return {}
	var context: Variant = _operation_context_stack.back()
	if context is Dictionary and not context.get("completed", false):
		return context
	return {}


func get_operation_runtime() -> Variant:
	if _operation_runtime_stack.is_empty():
		return null
	return _operation_runtime_stack.back()


func get_turn_context() -> Variant:
	return _turn_context


## 统一事件树的正式回合节点。仅正式回合/第零轮拥有，有限行动不创建。
func get_turn_event() -> Variant:
	return _turn_event


## 创建正式回合上下文并进入初始阶段。第零轮也通过此入口建立独立上下文。
func begin_turn_context(initial_phase: String, turn_number: int = 0, action_limit: int = -1) -> Variant:
	var limit: int = max_action_count if action_limit < 0 else action_limit
	_turn_context = TurnContextScript.new(self, turn_number, limit)
	_turn_event = TurnEventScript.new(self, turn_number)
	_turn_event.mark_running()
	_phase_sequence = 0
	return _enter_turn_phase(initial_phase, "context_started")


func _enter_turn_phase(new_phase: String, reason: String = "") -> Variant:
	if _turn_context == null:
		_turn_context = TurnContextScript.new(self, 0, action_count)
	if _turn_event == null:
		_turn_event = TurnEventScript.new(self, _turn_context.turn_number)
		_turn_event.mark_running()
	var old_phase: String = _turn_context.enter_phase(new_phase)
	_phase_sequence += 1
	in_phase = new_phase
	action_count = _turn_context.remaining_actions
	var event: Variant = PhaseEventScript.new(
		self,
		_turn_context,
		old_phase,
		new_phase,
		_phase_sequence,
		reason,
		_turn_event
	)
	_turn_event.children.append(event)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.phase_event.emit(event)
		# 兼容旧 UI/教程：保持旧信号原有的 action 进入时机和参数。
		if new_phase == "action":
			EventBus.phase_changed.emit(self, "", "action")
	return event


func finish_turn_context() -> void:
	if _turn_context != null:
		_turn_context.finish()
	if _turn_event != null:
		_turn_event.complete()


## 有限行动期间返回虚拟 action 阶段，否则返回正式阶段。
func get_effective_phase() -> String:
	var context: Dictionary = get_operation_context()
	if context.get("kind", "") == "limited_action":
		return "action"
	if _turn_context != null:
		return _turn_context.phase
	return in_phase


## 有限行动期间返回上下文预算，否则返回正式行动点。
func get_effective_action_count() -> int:
	var context: Dictionary = get_operation_context()
	if context.get("kind", "") == "limited_action":
		return maxi(int(context.get("remaining_actions", 0)), 0)
	if _turn_context != null and _turn_context.active:
		return maxi(_turn_context.remaining_actions, 0)
	return action_count


func is_action_available(cost: int = 1) -> bool:
	return get_effective_phase() == "action" and get_effective_action_count() >= cost


func get_action_count() -> int:
	return get_effective_action_count()


func set_action_count(n: int) -> void:
	var context: Dictionary = get_operation_context()
	if context.get("kind", "") == "limited_action":
		context["remaining_actions"] = maxi(n, 0)
	elif _turn_context != null and _turn_context.active:
		_turn_context.set_action_count(n)
		action_count = _turn_context.remaining_actions
	else:
		action_count = n


func reduce_action_count(n: int) -> void:
	var context: Dictionary = get_operation_context()
	if context.get("kind", "") == "limited_action":
		var actual: int = mini(maxi(n, 0), get_effective_action_count())
		context["remaining_actions"] = get_effective_action_count() - actual
		context["consumed_actions"] = int(context.get("consumed_actions", 0)) + actual
		if actual > 0 and EventBus != null and is_instance_valid(EventBus):
			EventBus.action_consumed.emit(self, actual)
		return
	if _turn_context != null and _turn_context.active:
		var formal_actual: int = _turn_context.consume_action(n)
		action_count = _turn_context.remaining_actions
		if formal_actual > 0 and EventBus != null and is_instance_valid(EventBus):
			EventBus.action_consumed.emit(self, formal_actual)
		return
	action_count = maxi(action_count - n, 0)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.action_consumed.emit(self, n)


## 扣除 n 点行动次数（content 代码字符串统一调用名，等价 reduce_action_count）。
func consume_action(n: int) -> void:
	if _pending_card_settlement != null:
		var card: Card = _pending_card_settlement
		_pending_card_settlement = null
		if begin_card_settlement(card):
			_card_cost_paid_by_content = true
			reduce_action_count(n)
		return
	if _card_cost_paid_by_content:
		return
	if _card_effect_in_progress:
		return
	reduce_action_count(n)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 消耗了 " + str(n) + " 点行动点数")


## 事件化的行动次数消耗。新操作入口应使用本方法；保留 consume_action 兼容既有 JSON。
func consume_action_evented(n: int) -> bool:
	if _pending_card_settlement != null:
		var card: Card = _pending_card_settlement
		if not begin_card_settlement(card):
			return false
		_pending_card_settlement = null
		if _pending_card_cost_free:
			_pending_card_cost_free = false
			_card_cost_paid_by_content = true
			return true
		var consumed: bool = await _consume_action_evented_internal(n)
		if consumed:
			_card_cost_paid_by_content = true
		else:
			cancel_card_settlement(card)
		return consumed
	if _card_cost_paid_by_content or _card_effect_in_progress:
		return true
	return await _consume_action_evented_internal(n)


func _consume_action_evented_internal(n: int) -> bool:
	if n <= 0 or get_effective_action_count() < n:
		return false
	var event: Dictionary = EventSystem.create_consume_action_event(self, n)
	event["operation_context"] = get_operation_context()
	await trigger("before_consume_action", event)
	if EventSystem.is_cancelled(event):
		return false
	await trigger("on_consume_action", event)
	if EventSystem.is_cancelled(event):
		return false
	var actual_num: int = maxi(int(event.get("num", n)), 0)
	if get_effective_action_count() < actual_num:
		return false
	reduce_action_count(actual_num)
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 消耗了 " + str(actual_num) + " 点行动点数")
	await trigger("after_consume_action", event)
	return true


## 增加 n 点行动次数（野地夹克使用）。
func add_action(n: int) -> void:
	var context: Dictionary = get_operation_context()
	if context.get("kind", "") == "limited_action":
		context["remaining_actions"] = maxi(get_effective_action_count() + n, 0)
		return
	if _turn_context != null and _turn_context.active:
		_turn_context.add_action(n)
		action_count = _turn_context.remaining_actions
		return
	action_count += n
	if action_count < 0:
		action_count = 0
	if Game != null and is_instance_valid(Game):
		Game.log_message(LogColors.player(player_name) + " 增加了 " + str(n) + " 点行动点数")
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.action_consumed.emit(self, n)


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


## 将行动牌从手牌移入卡牌结算区。
func begin_card_settlement(card: Card) -> bool:
	if card == null or not is_instance_valid(card) or not hand.has(card):
		return false
	hand.erase(card)
	if not card_settlement_zone.has(card):
		card_settlement_zone.append(card)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.card_settlement_started.emit(self, card)
	return true


## 将结算区中的行动牌移入对应弃牌堆。
func finish_card_settlement(card: Card) -> void:
	if card == null or not is_instance_valid(card) or not card_settlement_zone.has(card):
		return
	await discard(card, "", 1, "", true)


## 取消卡牌结算并将卡牌退回手牌（例如行动点扣除被取消）。
func cancel_card_settlement(card: Card) -> void:
	if card == null or not is_instance_valid(card) or not card_settlement_zone.has(card):
		return
	card_settlement_zone.erase(card)
	if not hand.has(card):
		hand.append(card)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.card_settlement_finished.emit(self, card)


## 按条件查询玩家区域中的牌。
func get_cards(position: String = "", name: String = "", quantity: int = 0, source: String = "") -> Array:
	var result: Array = []
	var search_hand: bool = (position == "" or position == "hand")
	var search_settlement: bool = (position == "settlement")
	var search_equip: bool = (position == "" or position == "equipment")
	if search_hand:
		for card in hand:
			if _card_matches(card, name, source):
				result.append(card)
				if quantity > 0 and result.size() >= quantity:
					return result
	if search_settlement:
		for card in card_settlement_zone:
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
	result.append_array(card_settlement_zone)
	for e in equipment_zone:
		if e != null and e.equipment_card != null:
			result.append(e.equipment_card)
	if game_deck != null:
		result.append_array(game_deck.get_all())
	if game_discard_pile != null:
		result.append_array(game_discard_pile.get_all())
	return result


## 装备前从来源区域取出卡牌。不只擦手牌：牌堆/弃牌堆/拾荒堆中的同一实例也必须离开，
## 否则装备实体的 equipment_card 仍在别处，消耗填充物会同时改那张“另一份”牌。
func _take_card_for_equip(card: Variant) -> void:
	if card == null:
		return
	hand.erase(card)
	card_settlement_zone.erase(card)
	if game_deck != null:
		game_deck.remove(card)
	if game_discard_pile != null:
		game_discard_pile.remove(card)
	if Game == null or not is_instance_valid(Game):
		return
	if Game.scavenge_discard_pile != null:
		Game.scavenge_discard_pile.remove(card)
	for pile in [Game.red_scavenge_pile, Game.green_scavenge_pile, Game.blue_scavenge_pile]:
		if pile != null:
			pile.remove(card)


## 从所在区域移除一张牌（内部方法）。
## 装备区命中时走 `_unequip`（触发 on_unequip / after_unequip，不经过 before_unequip 取消点）。
func _remove_card_from_zone(card: Variant) -> void:
	hand.erase(card)
	card_settlement_zone.erase(card)
	var entity: Equipment = _resolve_equipment_entity(card)
	if entity != null:
		await _unequip(entity)
	else:
		equipment_zone.erase(card)


## 装备离开装备区的实际效果（弃置 / 销毁 / 死亡等强制离开走这里）。
## 不经过 before_unequip 取消点，避免拦下已确定的离开。
## target 可为 Equipment 实体或 EquipmentCard 来源卡。
## event 为 null 时新建 equip event；公开 unequip 传入同一 event 以衔接三节点。
func _unequip(target: Variant, log_unequip: bool = false, event: Variant = null) -> void:
	var entity: Equipment = _resolve_equipment_entity(target)
	if entity == null:
		return
	var src_card: EquipmentCard = entity.equipment_card
	var unequip_event: Dictionary = event if event is Dictionary else EventSystem.create_equip_event(self, src_card)
	# 2. 卡牌离开装备区时
	equipment_zone.erase(entity)
	entity.in_equipment_area = false
	await trigger("on_unequip", unequip_event)
	# 移除装备技能（在 on_unequip 之后，确保 on_unequip 触发器仍可见装备技能）
	for s in entity.get_all_skills():
		remove_skill(s)
	# 3. 卡牌离开装备区后
	await trigger("after_unequip", unequip_event)
	if log_unequip and Game != null and is_instance_valid(Game) and src_card != null:
		Game.log_message(LogColors.player(player_name) + " 卸下了 " + LogColors.card(src_card.card_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.equipment_unequipped.emit(self, src_card)


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


## 判断卡牌是否为不能被普通弃置/移除的特殊卡牌。
## 按卡牌名称判断，因此手牌与装备区内的“科学家”均受保护。
func is_card_protected_from_discard(target: Variant) -> bool:
	if target == null or typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return false
	var card_name: Variant = target.get("card_name")
	var english_name: Variant = target.get("english_name")
	return card_name == "科学家" or english_name == "scientist"


## 返回当前装备区内可被普通弃置/移除的装备实体。
func get_discardable_equipment_cards() -> Array:
	var result: Array = []
	for e in equipment_zone:
		if e != null and is_instance_valid(e) and not is_card_protected_from_discard(e):
			result.append(e)
	return result


## 从弃置/移除候选中排除特殊卡牌。
func _filter_discardable_cards(cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		if not is_card_protected_from_discard(card):
			result.append(card)
	return result


## 供 choose_card 过滤器使用：返回卡牌是否可被弃置。
func _discardable_card_filter(_player: Variant, card: Variant, _event: Variant, _game: Variant) -> bool:
	return not is_card_protected_from_discard(card)


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
## name: "deck" = 角色游戏牌堆, "hand" = 手牌, "settlement" = 卡牌结算区,
## "equipment" = 装备区, "discard" = 弃牌堆。
## 注意：deck/discard 返回 Pile；hand/equipment/settlement 返回 Array。
func get_pile(name: String) -> Variant:
	match name:
		"deck":
			return game_deck
		"hand":
			return hand
		"settlement":
			return card_settlement_zone
		"equipment":
			return equipment_zone
		"discard":
			return game_discard_pile
		_:
			return null


## 返回游戏牌弃牌堆（content 代码调用入口）。
func get_discard_pile() -> Pile:
	return game_discard_pile


## 在共享输入实例上标记下一次请求的所属玩家。
func _prepare_input_request() -> void:
	if input != null and is_instance_valid(input) and input.has_method("set_request_owner"):
		input.set_request_owner(self)


## 选择器（委托 input）
func choose(options: Array, prompt: String = "") -> Variant:
	_prepare_input_request()
	return await input.choose(options, prompt)


## 确认对话框（委托 input）。
func confirm(message: String) -> bool:
	_prepare_input_request()
	return await input.confirm(message)


## 选择卡牌。
## param 为 String 时：按 position（如 "hand"/"equipment"/"discard"）查询玩家区域卡牌（原有行为）。
## param 为 Array 时：直接作为候选卡牌列表，绕过 position 查询。
func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	_prepare_input_request()
	if typeof(param) == TYPE_ARRAY:
		# Array 模式：直接作为候选卡牌列表，绕过 position 查询
		return await input.choose_card(n, param, filter, prompt, min_n)
	# String 模式（原有行为）：按 position 查询玩家区域卡牌
	return await input.choose_card(n, param, filter, prompt, min_n)


## 选择目标。n 为选择数量（-1 表示全部），skill 为当前技能（含 target_type/filter_target 等）。
## min_n 为最小选择数（-1 表示精确模式，必须选 n 个）；范围模式 min_n>=0 时允许 [min_n, n] 个。
func choose_target(n: int, skill: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	_prepare_input_request()
	return await input.choose_target(n, skill, prompt, min_n)


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
		_prepare_input_request()
		return await input.choose_map_block(filtered, prompt)
	else:
		# array 模式（原有行为）
		_prepare_input_request()
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
	_prepare_input_request()
	return await input.choose_block_inline(valid_blocks, prompt, count)


func show_card(card: Card, target: Variant) -> void:
	_prepare_input_request()
	input.show_card(card, target)


## 设置 prompt 区文本（content 代码调用入口）。
func set_prompt(text: String) -> void:
	if input != null and is_instance_valid(input):
		_prepare_input_request()
		input.set_prompt(text)


## 等待玩家重调决策（第零轮专用）。返回 true 表示确定重调，false 表示取消。
func wait_redraw_decision() -> bool:
	if input == null or not is_instance_valid(input):
		return false
	_prepare_input_request()
	return await input.wait_redraw_decision(self)


## 行动阶段循环：等待玩家操作（使用卡牌/使用主动技能/结束回合）。
func wait_player_action(_operation_context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"reason": "",
		"requested_actions": int(_operation_context.get("requested_actions", 0)),
		"consumed_actions": int(_operation_context.get("consumed_actions", 0)),
		"remaining_actions": int(_operation_context.get("remaining_actions", 0)),
	}
	while is_alive():
		if _phase_end_requested != "":
			_phase_end_requested = ""
			result["reason"] = "ended"
			break
		if not get_operation_context().is_empty() and get_effective_action_count() <= 0:
			result["reason"] = "budget_exhausted"
			break
		var choice: Variant = await input.wait_action(self)
		if choice == null:
			result["reason"] = "cancelled"
			break  # 结束回合
		if typeof(choice) == TYPE_DICTIONARY:
			await dispatch_player_action(choice)
	if result["reason"] == "":
		result["reason"] = "player_unavailable" if not is_alive() else "completed"
	result["consumed_actions"] = int(get_operation_context().get("consumed_actions", result["consumed_actions"]))
	result["remaining_actions"] = get_effective_action_count() if not get_operation_context().is_empty() else result["remaining_actions"]
	return result


## 所有 UI/CLI 玩家意图的统一领域分发入口。
func dispatch_player_action(choice: Dictionary) -> void:
	var action_type: String = choice.get("type", "")
	var operation_runtime: Variant = get_operation_runtime()
	if action_type == "skill":
		var skill: Skill = choice.get("skill", null)
		if skill != null and is_instance_valid(skill):
			await use_active_skill(skill, operation_runtime)
	elif action_type == "card":
		var card: Card = choice.get("card", null)
		if card != null and is_instance_valid(card):
			await use_card(card, false, operation_runtime)
	elif action_type == "pile_draw":
		await _execute_pile_draw(choice.get("pile_key", ""))
	elif action_type == "mission_action":
		await _execute_mission_action(choice.get("option_id", ""))
	elif action_type == "move":
		var target_block: Variant = choice.get("target", null)
		if target_block != null and is_instance_valid(target_block):
			if await consume_action_evented(1):
				await move_to(target_block)


## 执行任务行动选项（actions 组件/任务脚本提供的专属行动）。
func _execute_mission_action(option_id: String) -> void:
	if Game == null or not is_instance_valid(Game) or Game.mission_config == null:
		return
	var options: Array = Game.mission_config.get_action_options(Game, self)
	for opt in options:
		if opt is Dictionary and opt.get("id", "") == option_id:
			var fn: Callable = opt.get("execute", Callable())
			if fn.is_valid():
				await fn.call()
			return


## 执行牌堆抓牌动作（UI 牌堆点击触发）。
## pile_key 为 "game_deck" / "red_scavenge" / "green_scavenge" / "blue_scavenge"。
func _execute_pile_draw(pile_key: String) -> void:
	if pile_key == "game_deck":
		if await consume_action_evented(1):
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
	if await consume_action_evented(1):
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
	candidates = _filter_discardable_cards(candidates)
	if candidates.is_empty():
		return
	var chosen: Variant = await choose_card(n, candidates)
	if chosen == null:
		return
	var cards_to_discard: Array = chosen if chosen is Array else [chosen]
	await discard(cards_to_discard)


## 使用主动技能。处理目标选择和卡牌选择，然后执行技能 content。
func use_active_skill(skill: Skill, operation_runtime: Variant = null) -> void:
	if skill == null or not is_instance_valid(skill):
		return
	if skill.active.is_empty():
		return
	if not skill.is_usable():
		return
	var event: Dictionary = EventSystem.create_active_skill_event(self, [])
	event["target"] = null
	event["cards"] = []
	event["skill"] = skill
	if operation_runtime != null:
		event["actions"] = GameActions.new(self, Game, operation_runtime)
	# 1. 主动技能使用前（取消点）
	await trigger("before_use_active_skill", event)
	if EventSystem.is_cancelled(event):
		return
	# 2. filter 检查
	if not skill.execute_filter(self, event):
		return
	# 3. 目标选择
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
		# 新版声明式目标选择窗口：GUI 按 target_type 构建装备区候选并经 filter_target 过滤，显示 window_prompt
		var select_n: int = skill.select_target if skill.select_target > 0 else 1
		var targets: Array = await choose_target(select_n, skill, skill.window_prompt, skill.select_target_min)
		if targets.is_empty():
			return  # 玩家取消或无合法目标
		event["target"] = targets[0]
		event["targets"] = targets
	else:
		# target_type 为空：依据 select_target 选择目标
		var select_n: int = skill.select_target
		var targets: Array = []
		if select_n > 0:
			# select_target_min：范围模式下允许选 [min_n, select_n] 个目标（-1 = 精确模式）
			var min_n: int = skill.select_target_min
			targets = await choose_target(select_n, skill, skill.window_prompt, min_n)
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
	# 4. 卡牌选择
	if skill.select_card > 0:
		var cards: Array = await choose_card(skill.select_card, skill.position, skill.filter_card)
		if cards.size() < skill.select_card:
			return
		event["cards"] = cards
	# 5. 主动技能使用时（取消点）
	await trigger("on_use_active_skill", event)
	if EventSystem.is_cancelled(event):
		return
	# 6. 输出使用日志（有 target 时输出"对目标使用了"，无 target 时输出"使用了"）
	if Game != null and is_instance_valid(Game):
		var _skill_name: String = skill.skill_name if skill.skill_name != "" else skill.english_name
		var _target: Variant = event.get("target", null)
		if _target != null:
			Game.log_message(LogColors.player(player_name) + " 对 " + _format_target_name(_target) + " 使用了 " + LogColors.skill(_skill_name))
		else:
			Game.log_message(LogColors.player(player_name) + " 使用了 " + LogColors.skill(_skill_name))
	# 7. 执行 content
	await skill.execute_content(self, event)
	# 7.5 取消检查：content 中通过 EventSystem.cancel(event) 取消时不记录使用
	if EventSystem.is_cancelled(event):
		return
	# 8. 记录使用
	skill.record_use()
	# 9. 主动技能使用后
	await trigger("after_use_active_skill", event)
	# 10. 统计信号：技能成功使用
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
			return get_effective_action_count()
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
	_prepare_input_request()
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


## 在有限操作事件中让玩家免费使用最多 max_cards 张手牌。
## 每张牌都复用 use_card 的完整生命周期，不修改正式回合阶段或行动点。
func play_card_immediately(max_cards: int = 1, operation_runtime: Variant = null) -> Dictionary:
	var result: Dictionary = {
		"used_count": 0,
		"cancelled": false,
	}
	if max_cards <= 0 or hand.is_empty():
		result["cancelled"] = true
		return result

	for _i in range(max_cards):
		if hand.is_empty():
			break
		_prepare_input_request()
		var cards: Array = await input.choose_card(
			1,
			"hand",
			null,
			"选择一张手牌使用（可取消）",
			0
		)
		if cards.is_empty():
			result["cancelled"] = true
			break
		var card: Variant = cards[0]
		if not card is Card or not hand.has(card):
			break
		if not await use_card(card, true, operation_runtime):
			break
		result["used_count"] = int(result["used_count"]) + 1

	return result


# === 十四、任务系统方法 ===

## 收集物品（直接生成拾荒卡加入手牌区）。
func collect_item(card_name: String, quantity: int) -> void:
	for i in quantity:
		if Game != null and Game.has_method("create_scavenge_card"):
			var card: Card = Game.create_scavenge_card(card_name)
			if card == null:
				return
			await try_add_card_to_hand(card)
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
	await draw_monster(1)
