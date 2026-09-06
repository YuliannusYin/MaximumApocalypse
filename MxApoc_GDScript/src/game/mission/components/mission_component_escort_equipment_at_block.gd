class_name MissionComponentEscortEquipmentAtBlock
extends MissionComponent

## 护送装备（如科学家）抵达地块胜利条件组件。
## 组件 id：escort_equipment_at_block；类别：win_condition（胜利条件）。
## params：
## - card_name: String——护送的装备卡名（如 "科学家"）
## - block_name: String——护送目标地块名（如 "面包车" / "医院"）
## - no_monster: bool（默认 false）——true 时持有者所在目标地块须无怪物标记，
##   且该地块上所有存活玩家的怪物卡总数为 0
## 判定（直接查找持有者）：存在存活玩家装备着指定卡（player.has_equipment，
## 仅查装备区）且其 current_block 非空、地块名匹配目标地块即胜利；无存活持有者失败。
## 不依赖 mission_state 键：装备来源不限——无论 spend_action_rescue 解救获得
## 还是 setup_equip_card 开局装备，只要实际在玩家装备区即可判定。

func check_win(game: Game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var card_name: String = params.get("card_name", "")
	var block_name: String = params.get("block_name", "")
	var no_monster: bool = params.get("no_monster", false) == true
	for player in game.get_alive_players():
		if not player.has_equipment(card_name):
			continue
		if player.current_block == null or not is_instance_valid(player.current_block):
			continue
		if player.current_block.block_name != block_name:
			continue
		if no_monster and not _is_block_clear(player.current_block, game):
			continue
		return true
	return false


func _is_block_clear(block: MapBlock, game: Game) -> bool:
	if block.count_monster_mark() > 0:
		return false
	for other in game.get_alive_players():
		if other.current_block == block and other.monster_zone.size() > 0:
			return false
	return true
