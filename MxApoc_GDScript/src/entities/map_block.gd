class_name MapBlock
extends Entity

## 地图块类。
## 继承 Entity。职责：地图块属性、坐标定位、展示机制、怪物标记管理、地块技能挂载、目标标记管理与摧毁机制。
## 设计文档：GameDesignDocus/GameSystem/Entities/MapBlock.md
## 地块技能挂载到 Player 身上由 player.trigger() 触发（不在 MapBlock 上触发）

## 地图块名称（如"避难所"、"面包车"、"军事基地"）
var block_name: String = ""

## 坐标 {x: int, y: int}。x=列，y=行。对应 map[y][x]
var coordinate: Dictionary = {"x": 0, "y": 0}

## 怪物生成点数（monster_spawn_value）
var monster_spawn_value: int = 0

## 拾荒颜色集合（"red"/"green"/"blue"子集）。空集合表示不可拾荒
var scavenge_colors: PackedStringArray = []

## 是否展示（revealed）。玩家首次进入时翻开
var revealed: bool = false

## 怪物标记数（上限 3）
var monster_marks: int = 0

## 地块状态："alive"（存活）/ "destroyed"（已摧毁）
var block_state: String = "alive"

## 目标标记列表。null/空表示无标记
var objective_marks: Array = []


# === 展示 ===

## 翻开未展示的地块。
## trigger_effect=true 时触发 on_block_revealed（地块技能已挂载到 player 由 player.trigger 触发）。
func reveal(trigger_effect: bool, player: Variant) -> void:
	revealed = true
	if Game != null and is_instance_valid(Game):
		Game.log_message("地图块'%s'被揭示" % block_name)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.block_revealed.emit(self, player)
	if trigger_effect:
		var event: Dictionary = EventSystem.create_event({
			"player": player,
			"block": self,
		})
		await player.trigger("on_block_revealed", event)


## 是否已展示。
func is_revealed() -> bool:
	return revealed


## 返回怪物生成点数。
func get_spawn_value() -> int:
	return monster_spawn_value


# === 怪物标记管理 ===

## 增加 n 个怪物标记（上限 3）。不触发目标标记移除条件检查。
func add_monster_mark(n: int = 1) -> void:
	monster_marks = mini(monster_marks + n, 3)


## 移除 n 个怪物标记。移除后检查目标标记移除条件。
func remove_monster_mark(n: int = 1) -> void:
	monster_marks = maxi(monster_marks - n, 0)
	_check_objective_mark_remove_conditions()


## 移除所有怪物标记（设为 0）。不触发「怪物死亡时」事件。
func remove_all_monster_marks() -> void:
	monster_marks = 0
	_check_objective_mark_remove_conditions()


## 返回当前怪物标记数。
func count_monster_mark() -> int:
	return monster_marks


## 是否有怪物标记。
func has_monster_mark() -> bool:
	return monster_marks > 0


## 返回地块上当前纠缠玩家的怪物总数。
func count_monster() -> int:
	var count: int = 0
	if Game == null or not is_instance_valid(Game):
		return count
	for player in Game.players:
		if player != null and is_instance_valid(player) and player.is_alive():
			count += player.monster_zone.size() if "monster_zone" in player else 0
	return count


## 是否有玩家在此地块。
func has_player() -> bool:
	return get_players().size() > 0


## 是否可拾荒（拾荒颜色集合非空）。
func has_color() -> bool:
	return scavenge_colors.size() > 0


## 是否具备指定名字的地块技能。
func has_skill(skill_name: String) -> bool:
	for s in skills:
		if s.skill_name == skill_name:
			return true
	return false


## 是否存在相邻且未展示的存活地块。
func has_adjacent_unrevealed_block() -> bool:
	for b in get_adjacent_blocks():
		if not b.revealed:
			return true
	return false


# === 坐标与位置查询 ===

## 返回 {x, y} 坐标。
func get_coordinate() -> Dictionary:
	return coordinate


## 设置坐标（地图构建时使用）。
func set_coordinate(x: int, y: int) -> void:
	coordinate = {"x": x, "y": y}


## 地块状态是否为 "alive"。
func is_alive() -> bool:
	return block_state == "alive"


## 地块状态是否为 "destroyed"。
func is_destroyed() -> bool:
	return block_state == "destroyed"


## 返回四向相邻的存活地块（上下左右）。
func get_adjacent_blocks() -> Array:
	var adjacent: Array = []
	var directions: Array = [
		[0, -1],  # 上
		[0, 1],   # 下
		[-1, 0],  # 左
		[1, 0],   # 右
	]
	for dir in directions:
		var x: int = coordinate["x"] + dir[0]
		var y: int = coordinate["y"] + dir[1]
		var neighbor: MapBlock = Game.get_block_by_coord(x, y) if Game != null and is_instance_valid(Game) else null
		if neighbor != null and neighbor.is_alive():
			adjacent.append(neighbor)
	return adjacent


## 计算到目标地块的曼哈顿距离。
func distance_to(other: MapBlock) -> int:
	return absi(coordinate["x"] - other.coordinate["x"]) + absi(coordinate["y"] - other.coordinate["y"])


## 返回指定射程范围内的所有存活地块。
## range_str: "short" / "medium" / "long" / "infinity"
func get_blocks_in_range(range_str: String) -> Array:
	var result: Array = []
	if Game == null or not is_instance_valid(Game):
		return result
	for b in Game.map_area:
		if not b.is_alive():
			continue
		var d: int = distance_to(b)
		if range_str == "short" and d == 1:
			result.append(b)
		elif range_str == "medium" and d >= 1 and d <= 2:
			result.append(b)
		elif range_str == "long" and d >= 2 and d <= 3:
			result.append(b)
		elif range_str == "infinity":
			result.append(b)
	return result


## 返回指定射程范围内的所有玩家。
func get_players_in_range(range_str: String) -> Array:
	var players: Array = []
	var blocks: Array = get_blocks_in_range(range_str)
	for b in blocks:
		players.append_array(b.get_players())
	return players


## 返回该地块上的所有存活玩家。
func get_players() -> Array:
	var players: Array = []
	if Game == null or not is_instance_valid(Game):
		return players
	for player in Game.players:
		if player != null and is_instance_valid(player) and player.is_alive():
			if player.get_current_block() == self:
				players.append(player)
	return players


# === 目标标记管理 ===

## 是否有目标标记（且至少一个未移除）。
func has_objective_mark() -> bool:
	for mark in objective_marks:
		if not mark.get("removed", false):
			return true
	return false


## 返回目标标记列表。
func get_objective_marks() -> Array:
	return objective_marks


## 添加目标标记（地图构建时使用）。
func add_objective_mark(mark: Dictionary) -> void:
	objective_marks.append(mark)


## 移除指定目标标记（设 removed=true 并从列表移除）。
func remove_objective_mark(mark: Dictionary) -> void:
	mark["removed"] = true
	objective_marks.erase(mark)


## 移除所有未移除的目标标记。
func remove_all_objective_marks() -> void:
	var to_remove: Array = objective_marks.duplicate()
	for mark in to_remove:
		if not mark.get("removed", false):
			remove_objective_mark(mark)


## 触发所有未触发且未移除的目标标记效果。
func trigger_objective_marks(player: Variant) -> void:
	for mark in objective_marks:
		if mark.get("triggered", false) or mark.get("removed", false):
			continue
		# 1. 执行标记效果
		var effect: Callable = mark.get("effect", Callable())
		if effect.is_valid():
			effect.call(player)
		mark["triggered"] = true
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.objective_mark_triggered.emit(player, self, mark)
		# 2. 触发 on_objective_mark_triggered
		var event: Dictionary = EventSystem.create_objective_mark_event(player, self, mark)
		await player.trigger("on_objective_mark_triggered", event)


# === 内部方法 ===

## 检查所有目标标记的移除条件，满足时移除。
func _check_objective_mark_remove_conditions() -> void:
	var to_check: Array = objective_marks.duplicate()
	for mark in to_check:
		if mark.get("removed", false):
			continue
		var cond: Callable = mark.get("remove_condition", Callable())
		if cond.is_valid() and cond.call(self):
			remove_objective_mark(mark)
