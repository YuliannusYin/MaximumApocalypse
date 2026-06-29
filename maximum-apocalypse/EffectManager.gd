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
	# 填装满弹药（查找武器的最大弹药量）
	var player = GameState.players[player_id]
	for equipment in player.equipment_zone:
		if equipment.template_id.contains("weapon") or equipment.template_id.contains("pistol") or equipment.template_id.contains("rifle"):
			# 填装到最大值（假设最大为6）
			equipment.current_ammo = 6
			print("[EffectManager] 为武器 " + equipment.card_name + " 填装满弹药")
			ui_manager.update_player_info(player_id)
			return true
	print("[EffectManager] 玩家没有可填装的武器")
	return false

func _reload_weapon(player_id: String, _card_instance: CardRuntime, amount: int) -> bool:
	var player = GameState.players[player_id]
	# 查找装备栏中的武器
	var weapon_found = false
	for equipment in player.equipment_zone:
		if equipment.template_id.contains("weapon") or equipment.template_id.contains("pistol") or equipment.template_id.contains("rifle"):
			equipment.current_ammo += amount
			print("[EffectManager] 为武器 " + equipment.card_name + " 填装 " + str(amount) + " 发弹药")
			weapon_found = true
			break

	if not weapon_found:
		print("[EffectManager] 玩家没有可填装的武器")
		return false

	ui_manager.update_player_info(player_id)
	return true

# 填装燃料（满）
func effect_reload_fuel_weapon_full(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# TODO: 实现燃料填装逻辑（用于面包车启动）
	print("[EffectManager] 燃料填装效果（暂未实现）")
	return true

# 造成伤害效果（武器攻击）
func effect_deal_damage_2_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	# TODO: 需要目标选择UI
	print("[EffectManager] 造成2点伤害效果（需要目标选择）")
	return true

func effect_deal_damage_3_medium_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 造成3点伤害效果（需要目标选择）")
	return true

func effect_deal_damage_4_long_range(player_id: String, _card_data: Resource, _card_instance: CardRuntime) -> bool:
	print("[EffectManager] 造成4点伤害效果（需要目标选择）")
	return true

# === 装备效果 ===

# 增加装备栏
func effect_increase_equipment_slots_1(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	# 背包不占用装备栏，作为特殊标记
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得背包，装备栏扩展")
	ui_manager.update_player_info(player_id)
	return true

# 减伤效果（防弹背心）
func effect_damage_reduction_2_uses_3(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 装备时添加减伤标记，使用次数存储在CardRuntime中
	card_instance.current_ammo = 3  # 使用次数
	var player = GameState.players[player_id]
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得防弹背心（减伤2，可用3次）")
	ui_manager.update_player_info(player_id)
	return true

# 拾荒时查看牌堆顶
func effect_scavenge_peek_top_2(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	# 作为装备放入装备栏
	var player = GameState.players[player_id]
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得手电筒（拾荒时可查看牌堆顶2张）")
	ui_manager.update_player_info(player_id)
	return true

# 展示地图块不触发效果
func effect_reveal_tile_no_trigger(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得双筒望远镜")
	ui_manager.update_player_info(player_id)
	return true

# 给其他玩家行动
func effect_grant_action_to_other_player(player_id: String, _card_data: Resource, card_instance: CardRuntime) -> bool:
	var player = GameState.players[player_id]
	player.equipment_zone.append(card_instance)
	print("[EffectManager] 玩家 " + player_id + " 获得对讲机")
	ui_manager.update_player_info(player_id)
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
	# TODO: 需要目标地块选择
	print("[EffectManager] 炸药效果（需要选择目标地块）")
	return true

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