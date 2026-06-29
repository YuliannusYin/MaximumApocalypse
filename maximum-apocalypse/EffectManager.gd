# 效果管理器 - 处理所有卡牌效果脚本
# EffectManager.gd
class_name EffectManager
extends Node

# 引用其他管理器
var rule_engine: Node
var ui_manager: CanvasLayer
var map_board: Node2D

func initialize(_rule_engine: Node, _ui_manager: CanvasLayer, _map_board: Node2D) -> void:
	rule_engine = _rule_engine
	ui_manager = _ui_manager
	map_board = _map_board
	print("[EffectManager] 效果管理器已初始化")

# 执行卡牌效果
func execute_effect(card_data: Resource, player_id: String, card_instance: CardRuntime) -> bool:
	var effect_id: String = ""

	# 根据卡牌类型获取effect_script_id
	if card_data is ScavengeCardData:
		effect_id = card_data.effect_script_id
	elif card_data is CharacterCardData:
		effect_id = card_data.effect_script_id
	else:
		print("[EffectManager] 未知的卡牌类型")
		return false

	if effect_id == "" or effect_id == "none":
		print("[EffectManager] 卡牌无效果脚本")
		return true

	print("[EffectManager] 执行效果: " + effect_id + " (玩家: " + player_id + ")")

	# 调用对应的效果函数
	var method_name = "effect_" + effect_id
	if has_method(method_name):
		return call(method_name, player_id, card_data, card_instance)
	else:
		print("[EffectManager] 警告：效果函数未实现: " + method_name)
		return false

# === 生命/饥饿效果 ===

# 恢复HP效果
func effect_restore_hp_2(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _restore_hp(player_id, 2)

func effect_restore_hp_4(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _restore_hp(player_id, 4)

func effect_restore_hp_6(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _restore_hp(player_id, 6)

func effect_restore_hp_8(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _restore_hp(player_id, 8)

func _restore_hp(player_id: String, amount: int) -> bool:
	var player = GameState.players[player_id]
	player.current_hp = min(player.current_hp + amount, player.max_hp)
	print("[EffectManager] 玩家 " + player_id + " 恢复 " + str(amount) + " 点HP，当前HP=" + str(player.current_hp))
	ui_manager.update_player_info(player_id)
	return true

# 减少饥饿值效果
func effect_reduce_hunger_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_hunger(player_id, 1)

func effect_reduce_hunger_2(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_hunger(player_id, 2)

func effect_reduce_hunger_3(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_hunger(player_id, 3)

func effect_reduce_hunger_4(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_hunger(player_id, 4)

func effect_reduce_hunger_5(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_hunger(player_id, 5)

func effect_reduce_hunger_6(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_hunger(player_id, 6)

# 全体饥饿值减少效果（食物箱）
func effect_reduce_all_hunger_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_all_hunger(1)

func effect_reduce_all_hunger_2(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_all_hunger(2)

func _reduce_all_hunger(amount: int) -> bool:
	print("[EffectManager] 全体饥饿值减少 " + str(amount))
	for player_id in GameState.players.keys():
		var player = GameState.players[player_id]
		player.hunger_level = max(0, player.hunger_level - amount)
		print("[EffectManager]   玩家 " + player_id + " 饥饿值: " + str(player.hunger_level))
		ui_manager.update_player_info(player_id)
	return true

func _reduce_hunger(player_id: String, amount: int) -> bool:
	print("[EffectManager] _reduce_hunger 开始: player=" + player_id + ", amount=" + str(amount))
	
	if not GameState.players.has(player_id):
		print("[EffectManager] 错误：玩家不存在！")
		return false
		
	var player = GameState.players[player_id]
	print("[EffectManager] 当前饥饿值: " + str(player.hunger_level))
	
	player.hunger_level = max(0, player.hunger_level - amount)
	print("[EffectManager] 新饥饿值: " + str(player.hunger_level))
	
	if ui_manager:
		ui_manager.update_player_info(player_id)
		print("[EffectManager] UI已更新")
	else:
		print("[EffectManager] 错误：ui_manager为null！")
	
	return true

# 清除异常状态
func effect_clear_all_status_effects(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	player.poison_tokens = 0
	player.is_stunned = false
	print("[EffectManager] 玩家 " + player_id + " 清除所有异常状态")
	ui_manager.update_player_info(player_id)
	return true

# === 弹药/武器效果 ===

# 填装弹药
func effect_reload_weapon_2(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	return _reload_weapon(player_id, card_instance, 2)

func effect_reload_weapon_3(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	return _reload_weapon(player_id, card_instance, 3)

func effect_reload_weapon_4(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	return _reload_weapon(player_id, card_instance, 4)

func effect_reload_weapon_5(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	return _reload_weapon(player_id, card_instance, 5)

func effect_reload_weapon_6(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	return _reload_weapon(player_id, card_instance, 6)

func effect_reload_weapon_full(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	for equipment in player.equipment_zone:
		var max_ammo = _get_weapon_max_ammo(equipment)
		if max_ammo > 0:
			equipment.current_ammo = max_ammo
			print("[EffectManager] 为武器 " + equipment.card_name + " 填装满弹药至 " + str(max_ammo))
			ui_manager.add_log_message("装满 " + equipment.card_name + " 弹药至" + str(max_ammo))
			ui_manager.update_player_info(player_id)
			return true
	ui_manager.add_log_message("没有可装填的武器")
	return false

func _reload_weapon(player_id: String, _card_instance: CardRuntime, amount: int) -> bool:
	var player = GameState.players[player_id]
	for equipment in player.equipment_zone:
		var max_ammo = _get_weapon_max_ammo(equipment)
		if max_ammo > 0:
			var old_ammo = equipment.current_ammo
			equipment.current_ammo = min(equipment.current_ammo + amount, max_ammo)
			var actual = equipment.current_ammo - old_ammo
			if actual > 0:
				print("[EffectManager] 为武器 " + equipment.card_name + " 填装 " + str(actual) + " 发弹药 (上限" + str(max_ammo) + ")")
				ui_manager.add_log_message("装填 " + equipment.card_name + " +" + str(actual) + "弹药")
			else:
				ui_manager.add_log_message(equipment.card_name + " 弹药已满")
			ui_manager.update_player_info(player_id)
			return true
	ui_manager.add_log_message("没有可装填的武器")
	return false

# 获取武器最大弹药量（通过加载卡牌数据）
func _get_weapon_max_ammo(equipment: CardRuntime) -> int:
	if rule_engine == null:
		return 0
	var card_data = rule_engine._load_card_data(equipment.template_id)
	if card_data is CharacterCardData:
		return card_data.max_ammo if card_data.max_ammo > 0 else 0
	return 0

# 填装燃料（满）
func effect_reload_fuel_weapon_full(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# TODO: 实现燃料填装逻辑（用于面包车启动）
	print("[EffectManager] 燃料填装效果（暂未实现）")
	return true

# 造成伤害效果（武器攻击）
func effect_deal_damage_2_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 2)

func effect_deal_damage_3_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 3)

func effect_deal_damage_4_long_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 4)

# === 装备效果 ===

# 装备辅助函数：检查是否已有同种装备，有则顶掉（弹药装备重新装满）
func _equip_item(player_id: String, card_instance: CardRuntime, max_ammo: int = 0) -> void:
	var player = GameState.players[player_id]

	# 检查是否已有同种装备（template_id相同）
	for i in range(player.equipment_zone.size()):
		var existing = player.equipment_zone[i]
		if existing.template_id == card_instance.template_id:
			# 顶掉旧装备（移到弃牌堆）
			var old_card = player.equipment_zone[i]
			player.discard_pile.append(old_card)
			print("[EffectManager] 顶掉旧装备: " + old_card.card_name)
			ui_manager.add_log_message("替换装备: " + old_card.card_name)
			# 装备新卡（如果有弹药，重新装满）
			if max_ammo > 0:
				card_instance.current_ammo = max_ammo
			player.equipment_zone[i] = card_instance
			print("[EffectManager] 装备: " + card_instance.card_name)
			ui_manager.add_log_message("装备: " + card_instance.card_name)
			ui_manager.update_player_info(player_id)
			return

	# 没有同种装备，直接添加
	if max_ammo > 0:
		card_instance.current_ammo = max_ammo
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 装备: " + card_instance.card_name)
	ui_manager.add_log_message("装备: " + card_instance.card_name)
	ui_manager.update_player_info(player_id)

# 增加装备栏
func effect_increase_equipment_slots_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	# 背包不占用装备栏，作为特殊标记
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得背包，装备栏扩展")
	ui_manager.add_log_message("获得背包，装备栏扩展")
	ui_manager.update_player_info(player_id)
	return true

# 减伤效果（防弹背心）
func effect_damage_reduction_2_uses_3(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 装备时添加减伤标记，使用次数存储在CardRuntime中
	_equip_item(player_id, card_instance, 3)  # 使用次数=3
	print("[EffectManager] 玩家 " + player_id + " 获得防弹背心（减伤2，可用3次）")
	return true

# 拾荒时查看牌堆顶
func effect_scavenge_peek_top_2(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	_equip_item(player_id, card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得手电筒（拾荒时可查看牌堆顶2张）")
	return true

# 展示地图块不触发效果
func effect_reveal_tile_no_trigger(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	_equip_item(player_id, card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得双筒望远镜")
	return true

# 给其他玩家行动
func effect_grant_action_to_other_player(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# TODO: 选择一名玩家使其立即执行一个行动（需目标玩家选择UI）
	print("[EffectManager] 战术领导力/对讲机效果暂未实现")
	ui_manager.add_log_message("战术领导力效果暂未实现")
	return true

# === 特殊效果 ===

# 抽到时立即弃掉（一无所获）
func effect_discard_on_draw(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	# 从手牌移除并放入弃牌堆
	player.hand.erase(card_instance)
	GameState.scavenge_discard_pile.append(card_instance.template_id)
	print("[EffectManager] 一无所获！立即弃掉")
	return true

# 抽怪物卡后弃掉自己（伏击）
func effect_draw_monster_discard_self(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	# 抽取一张怪物卡
	if rule_engine:
		rule_engine.draw_monster_card_to_player(player_id)
	# 弃掉伏击卡
	player.hand.erase(card_instance)
	GameState.scavenge_discard_pile.append(card_instance.template_id)
	print("[EffectManager] 伏击！玩家抽取怪物卡并弃掉伏击卡")
	ui_manager.update_player_info(player_id)
	return true

# 移除所有怪物并造成伤害（炸药）
func effect_remove_all_monsters_deal_8_damage(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 对所有纠缠怪物造成8点伤害
	return _deal_damage_to_all_monsters(player_id, 8)

# 摧毁地图块（大炸药）
func effect_destroy_tile(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# TODO: 需要目标地块选择
	print("[EffectManager] 大炸药效果（需要选择目标地块）")
	return true

# 游戏结算物品
func effect_game_end_item(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 作为物品保留在手牌
	print("[EffectManager] 游戏结算物品已保留")
	return true

# 从弃牌堆回收手牌（备件）
func effect_return_card_from_discard_to_hand(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]

	# 检查弃牌堆是否有卡
	if player.discard_pile.size() == 0:
		print("[EffectManager] 弃牌堆为空，无法回收")
		ui_manager.status_label.text = "弃牌堆为空！"
		return false

	# 简化处理：回收最后一张弃掉的卡
	var recovered_card = player.discard_pile.pop_back()
	player.hand.append(recovered_card)

	print("[EffectManager] 从弃牌堆回收: " + recovered_card.card_name)
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "回收: " + recovered_card.card_name
	return true

# === 角色卡效果 ===

# 造成伤害系列
func effect_deal_2_damage_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 2)

func effect_deal_2_damage_short_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 2)

func effect_deal_3_damage_short_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 3)

func effect_deal_3_damage_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 3)

func effect_deal_4_damage_short_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 4)

func effect_deal_4_damage_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 4)

func effect_deal_4_damage_long_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 4)

func effect_deal_4_damage_trap(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 4)

func effect_deal_5_damage_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 5)

func effect_deal_5_damage_fire_arrow(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 5)

func effect_deal_6_damage_short_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 6)

func effect_deal_6_damage_long_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 6)

func effect_deal_8_damage_long_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 8)

func effect_deal_5_damage_area_3_damage(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 对第一个怪物造成5点，对第二个造成3点
	var success = _deal_damage_to_first_monster(player_id, 5)
	_deal_damage_to_monster_at_index(player_id, 1, 3)
	return success

func effect_deal_5_damage_3_targets_or_remove_monsters(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 对最多3个怪物造成5点伤害
	var success = false
	for i in range(3):
		if not _deal_damage_to_monster_at_index(player_id, i, 5):
			break
		success = true
	return success

func effect_deal_2_damage_all_monsters_in_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_all_monsters(player_id, 2)

func effect_deal_2_damage_all_enemies_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_all_monsters(player_id, 2)

func effect_consume_ammo_deal_5_damage(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# ACTION卡：从装备区找一把有弹药的武器消耗1发
	var weapon = _find_weapon_with_ammo(player_id)
	if weapon == null:
		ui_manager.status_label.text = "没有有弹药的武器!"
		ui_manager.add_log_message("集中射击失败：无可用弹药武器")
		return false
	weapon.current_ammo -= 1
	ui_manager.add_log_message("消耗 " + weapon.card_name + " 1发弹药")
	return _deal_damage_to_first_monster(player_id, 5)

func effect_consume_ammo_deal_4_damage(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	if card_instance.current_ammo <= 0:
		ui_manager.status_label.text = "弹药不足!"
		return false
	card_instance.current_ammo -= 1
	return _deal_damage_to_first_monster(player_id, 4)

func effect_deal_3_damage_chain_attack(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 连锁攻击：对最多3个怪物各造成3点伤害
	var success = false
	for i in range(3):
		if not _deal_damage_to_monster_at_index(player_id, i, 3):
			break
		success = true
	return success

func effect_deal_4_damage_front_targets_2_damage(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 对第一个怪物造成4点，对其他怪物造成2点
	var success = _deal_damage_to_first_monster(player_id, 4)
	_deal_damage_to_all_monsters(player_id, 2)
	return success

func effect_deal_1_damage_stun_until_next_turn(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _deal_damage_to_first_monster(player_id, 1)

# 恢复HP系列
func effect_heal_4_hp_to_player(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _restore_hp(player_id, 4)

func effect_heal_6_hp_to_player(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _restore_hp(player_id, 6)

func effect_heal_bonus_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 治疗时额外恢复1点HP")
	return true

func effect_deal_2_damage_heal_bonus_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 造成2点伤害并恢复1点HP")
	return true

func effect_heal_status_effects_or_reduce_hunger(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 清除异常状态或减少饥饿值")
	return true

func effect_heal_veteran_dog_2_reduce_veteran_damage_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 装备时：老兵和狗各恢复2HP，被动减伤1由apply_damage_to_player处理
	_equip_item(player_id, card_instance)
	var player = GameState.players[player_id]
	player.current_hp = min(player.current_hp + 2, player.max_hp)
	# 狗也恢复2HP（如果有狗）
	if player.has("dog_hp"):
		player.dog_hp = min(player.dog_hp + 2, player.get("dog_max_hp", 6))
	ui_manager.add_log_message("狗牌：老兵和狗各恢复2HP，受到伤害减1")
	ui_manager.update_player_info(player_id)
	return true

# 减伤系列
func effect_reduce_damage_by_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	card_instance.current_ammo = 99  # 持续效果标记
	_equip_item(player_id, card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得减伤1效果")
	return true

func effect_reduce_all_damage_by_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	_equip_item(player_id, card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得全体减伤1效果")
	return true

# 眩晕系列
func effect_stun_enemy_until_next_turn(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 眩晕敌人直到下一回合")
	return true

func effect_stun_all_monsters_until_next_turn(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 眩晕所有怪物直到下一回合")
	return true

func effect_stun_and_pull_monster(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 眩晕并拉近怪物")
	return true

# 移动系列
func effect_move_2_tiles_discard_reduce_hunger(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 移动2格，弃牌减少饥饿值")
	return true

func effect_move_3_tiles_draw_1_card(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 移动3格并抽1张牌")
	return true

func effect_consume_fuel_move_3_tiles(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 消耗燃料移动3格")
	return true

func effect_move_player_to_revealed_tile(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 移动玩家到已揭示的地块")
	return true

func effect_pull_player_1_tile_no_trigger(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 拉近玩家1格（不触发效果）")
	return true

# 抽牌系列
func effect_draw_2_cards_1_scavenge(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	# 从牌库抽2张
	if rule_engine and rule_engine.has_method("draw_character_card"):
		rule_engine.draw_character_card(player_id)
		rule_engine.draw_character_card(player_id)
	# 从拾荒牌堆抽1张
	if GameState.scavenge_decks[Enums.ScavengeCardColor.GREEN].size() > 0:
		var card = GameState.scavenge_decks[Enums.ScavengeCardColor.GREEN].pop_front()
		player.hand.append(card)
	print("[EffectManager] 抽2张角色牌 + 1张拾荒牌")
	ui_manager.update_player_info(player_id)
	return true

func effect_draw_3_scavenge_discard_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	for i in range(3):
		if GameState.scavenge_decks[Enums.ScavengeCardColor.GREEN].size() > 0:
			var card = GameState.scavenge_decks[Enums.ScavengeCardColor.GREEN].pop_front()
			player.hand.append(card)
	# 弃掉最后一张
	if player.hand.size() > 0:
		var discard_card = player.hand.pop_back()
		player.discard_pile.append(discard_card)
	print("[EffectManager] 抽3张拾荒牌，弃掉1张")
	ui_manager.update_player_info(player_id)
	return true

func effect_draw_equipment_from_discard_equip_to_player(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 从弃牌堆抽取装备牌并装备")
	return true

func effect_give_equipment_to_player_draw_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 给其他玩家装备并抽1张牌")
	return true

# 行动点系列
func effect_gain_2_extra_actions(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	player.action_points += 2
	print("[EffectManager] 玩家 " + player_id + " 获得2点额外行动点")
	ui_manager.update_player_info(player_id)
	return true

func effect_player_execute_2_actions(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 玩家可执行2次行动")
	return true

func effect_player_play_2_cards(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 玩家可打出2张牌")
	return true

# 饥饿系列
func effect_reduce_all_players_hunger_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return _reduce_all_hunger(1)

func effect_increase_hunger_restore_action(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 增加饥饿值并恢复行动点")
	return true

func effect_immune_hunger_draw_1_card(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 本回合免疫饥饿并抽1张牌")
	return true

func effect_dog_alive_reduce_veteran_dog_hunger_2(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] Veteran专属：狗存活时减少饥饿值2")
	return true

# 装备升级系列
func effect_attach_upgrade_increase_damage_1(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 装备升级卡，增加伤害1")
	return true

func effect_attach_hollow_point_ammo(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 附着空心弹弹药")
	return true

func effect_increase_all_damage_1_until_next_turn(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 本回合所有伤害+1")
	return true

func effect_heal_3_on_equip_increase_damage_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 装备时恢复3HP，增伤1由apply_damage_to_monster处理
	_equip_item(player_id, card_instance)
	var player = GameState.players[player_id]
	player.current_hp = min(player.current_hp + 3, player.max_hp)
	ui_manager.add_log_message("游侠帽：恢复3HP，造成伤害+1")
	ui_manager.update_player_info(player_id)
	return true

func effect_discard_all_ammo_damage_3_plus_2x(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 弃掉所有武器的弹药，造成3+2X伤害（X为弹药数）
	var total_ammo = 0
	var player = GameState.players[player_id]
	for equipment in player.equipment_zone:
		var max_ammo = _get_weapon_max_ammo(equipment)
		if max_ammo > 0 and equipment.current_ammo > 0:
			total_ammo += equipment.current_ammo
			equipment.current_ammo = 0
	if total_ammo == 0:
		ui_manager.status_label.text = "没有可弃掉的弹药!"
		ui_manager.add_log_message("齐射失败：无弹药")
		return false
	var damage = 3 + 2 * total_ammo
	ui_manager.add_log_message("弃掉" + str(total_ammo) + "弹药，造成" + str(damage) + "伤害")
	ui_manager.update_player_info(player_id)
	return _deal_damage_to_first_monster(player_id, damage)

# 武器填装系列
func effect_fully_reload_weapon(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	return effect_reload_weapon_full(player_id, _card_data, _card_instance)

# 特殊效果系列
func effect_auto_turret_counter_damage_4(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	card_instance.current_ammo = 99
	_equip_item(player_id, card_instance)
	print("[EffectManager] 自动炮台：怪物攻击时造成4点反击伤害")
	return true

func effect_discard_on_monster_draw_deal_7_damage(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 抽到怪物时弃掉此卡并造成7点伤害")
	return true

func effect_remove_all_monsters_from_tile(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 清除玩家所有纠缠怪物
	var player = GameState.players[player_id]
	if player.monster_zone.size() == 0:
		ui_manager.add_log_message("无纠缠怪物可清除")
		return true
	# 将所有怪物移到弃牌堆
	for monster in player.monster_zone.duplicate():
		GameState.monster_discard_pile.append(rule_engine._get_monster_data_by_id(monster.template_id))
	player.monster_zone.clear()
	ui_manager.add_log_message("清除所有纠缠怪物")
	ui_manager.update_monster_display(player_id)
	return true

func effect_remove_monsters_or_deal_6_damage_all(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 对所有纠缠怪物造成6点伤害
	return _deal_damage_to_all_monsters(player_id, 6)

func effect_auto_pass_river_skip_monster_draw(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	_equip_item(player_id, card_instance)
	print("[EffectManager] 自动通过河流并跳过怪物抽牌")
	return true

func effect_increase_stealth_2_discard_monster(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	_equip_item(player_id, card_instance)
	print("[EffectManager] 增加2点潜行值，可弃掉怪物卡")
	return true

func effect_attract_all_monsters_to_front(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 吸引所有怪物到前方")
	return true

func effect_consume_lighter_ammo_deal_3_damage_all(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 从装备区找打火机消耗1发弹药
	var player = GameState.players[player_id]
	var lighter = null
	for equipment in player.equipment_zone:
		if equipment.template_id == "lighter" and equipment.current_ammo > 0:
			lighter = equipment
			break
	if lighter == null:
		ui_manager.status_label.text = "打火机不存在或弹药不足!"
		ui_manager.add_log_message("氧气罐失败：无可用打火机")
		return false
	lighter.current_ammo -= 1
	ui_manager.add_log_message("消耗打火机1发弹药")
	return _deal_damage_to_all_monsters(player_id, 3)

func effect_scavenge_on_kill_until_turn_end(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# TODO: 本回合击杀怪物时抽1-2张拾荒牌（需回合标记和击杀触发）
	print("[EffectManager] 搜索尸体效果暂未实现")
	ui_manager.add_log_message("搜索尸体效果暂未实现")
	return true

func effect_equip_trusty_axe_draw_scavenge(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 装备斧头并抽拾荒牌")
	return true

# Veteran狗相关效果
func effect_dog_dead_increase_damage_3(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 狗死亡时伤害+3")
	return true

func effect_dog_dead_deal_6_damage_all_targets(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 对所有纠缠怪物造成6点伤害
	return _deal_damage_to_all_monsters(player_id, 6)

func effect_reduce_dog_damage_by_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	_equip_item(player_id, card_instance)
	print("[EffectManager] 减少狗的伤害1点")
	return true

func effect_dog_alive_stun_deal_2_damage(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 狗存活时眩晕并造成2点伤害")
	return true

func effect_dog_alive_remove_monster_dog_damage_2(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 狗存活时清除怪物并造成2点伤害")
	return true

func effect_dog_alive_draw_3_scavenge_discard_2(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 狗存活时抽3张拾荒牌弃掉2张")
	return true

func effect_dog_alive_deal_3_damage_3_targets(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# 狗存活时对最多3个目标造成3点伤害
	var success = false
	for i in range(3):
		if not _deal_damage_to_monster_at_index(player_id, i, 3):
			break
		success = true
	return success

func effect_dog_alive_reveal_2_tiles_no_trigger(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 狗存活时揭示2个地块（不触发效果）")
	return true

# === 伤害辅助函数 ===

# 对第一个纠缠怪物造成伤害
func _deal_damage_to_first_monster(player_id: String, damage: int) -> bool:
	var monster = rule_engine.get_first_monster(player_id)
	if monster == null:
		ui_manager.status_label.text = "没有纠缠的怪物!"
		ui_manager.add_log_message("攻击失败：无目标")
		return false
	return rule_engine.apply_damage_to_monster(player_id, monster.instance_id, damage)

# 从装备区找一把有弹药的武器（max_ammo > 0且current_ammo > 0）
func _find_weapon_with_ammo(player_id: String) -> CardRuntime:
	var player = GameState.players[player_id]
	for equipment in player.equipment_zone:
		var max_ammo = _get_weapon_max_ammo(equipment)
		if max_ammo > 0 and equipment.current_ammo > 0:
			return equipment
	return null

# 对指定索引的纠缠怪物造成伤害
func _deal_damage_to_monster_at_index(player_id: String, index: int, damage: int) -> bool:
	var player = GameState.players[player_id]
	if index >= player.monster_zone.size():
		return false
	var monster = player.monster_zone[index]
	return rule_engine.apply_damage_to_monster(player_id, monster.instance_id, damage)

# 对所有纠缠怪物造成伤害
func _deal_damage_to_all_monsters(player_id: String, damage: int) -> bool:
	var player = GameState.players[player_id]
	if player.monster_zone.size() == 0:
		ui_manager.status_label.text = "没有纠缠的怪物!"
		ui_manager.add_log_message("攻击失败：无目标")
		return false

	# 复制列表避免遍历时修改
	var monsters_copy = player.monster_zone.duplicate()
	for monster in monsters_copy:
		rule_engine.apply_damage_to_monster(player_id, monster.instance_id, damage)
	return true