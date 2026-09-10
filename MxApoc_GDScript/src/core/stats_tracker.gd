class_name StatsTracker
extends RefCounted

## 本局统计聚合器。
## 订阅 EventBus 信号，为每个玩家维护 PlayerStats。
## 由 Game autoload 持有，在 start_game 时 reset，在 game_over 时 stop_timer。
## 归档扩展：维护玩家→survivor_id 映射、按单个怪物（english_name）击杀数、按玩家首领击杀数，
## 并提供 get_archive_summary() 供结算归档（ArchiveManager）汇总。

var _stats: Dictionary = {} # player -> PlayerStats 映射
var game_duration_msec: int = 0
var _start_time_msec: int = 0
var _subscribed: bool = false
## player -> survivor_id 映射（survivor_id = RoleCard.english_name，与 data/survivors/*.json 的 id 一致）
var _survivor_ids: Dictionary = {}
## 单个怪物 english_name（Monster.english_name，与 data/monsters/*.json 卡片 english_name
## 一致）-> 击杀数；english_name 缺失/为空时以 "unknown" 兜底计数
var _monster_kills: Dictionary = {}
## player -> 首领击杀数（击杀来源可从 monster_died 信号负载可靠归属到玩家）
var _boss_kills: Dictionary = {}
## player -> { english_name: 击杀数 }；仅统计能归属到该玩家的击杀
var _player_monster_kills: Dictionary = {}
## 显示世界从网络快照灌入统计后不再听 EventBus，避免和权威计数叠一份。
var _ignore_events: bool = false


func _init() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	EventBus.damage_dealt.connect(Callable(self, "_on_damage_dealt"))
	EventBus.damage_taken.connect(Callable(self, "_on_damage_taken"))
	EventBus.hp_recovered.connect(Callable(self, "_on_hp_recovered"))
	EventBus.healing_done.connect(Callable(self, "_on_healing_done"))
	EventBus.hunger_reduced.connect(Callable(self, "_on_hunger_reduced"))
	EventBus.card_used.connect(Callable(self, "_on_card_used"))
	EventBus.skill_used.connect(Callable(self, "_on_skill_used"))
	EventBus.player_turn_started.connect(Callable(self, "_on_player_turn_started"))
	EventBus.player_moved.connect(Callable(self, "_on_player_moved"))
	EventBus.card_drawn.connect(Callable(self, "_on_card_drawn"))
	EventBus.scavenge_drawn.connect(Callable(self, "_on_scavenge_drawn"))
	EventBus.monster_died.connect(Callable(self, "_on_monster_died"))
	_subscribed = true


func reset(players: Array) -> void:
	_ensure_subscribed()
	_ignore_events = false
	_stats.clear()
	_survivor_ids.clear()
	_monster_kills.clear()
	_boss_kills.clear()
	_player_monster_kills.clear()
	for player in players:
		_stats[player] = PlayerStats.new()
		var sid: String = _read_survivor_id(player)
		if sid != "":
			_survivor_ids[player] = sid
	game_duration_msec = 0
	_start_time_msec = 0


func _ensure_subscribed() -> void:
	if _subscribed:
		return
	if EventBus == null or not is_instance_valid(EventBus):
		return
	EventBus.damage_dealt.connect(Callable(self, "_on_damage_dealt"))
	EventBus.damage_taken.connect(Callable(self, "_on_damage_taken"))
	EventBus.hp_recovered.connect(Callable(self, "_on_hp_recovered"))
	EventBus.healing_done.connect(Callable(self, "_on_healing_done"))
	EventBus.hunger_reduced.connect(Callable(self, "_on_hunger_reduced"))
	EventBus.card_used.connect(Callable(self, "_on_card_used"))
	EventBus.skill_used.connect(Callable(self, "_on_skill_used"))
	EventBus.player_turn_started.connect(Callable(self, "_on_player_turn_started"))
	EventBus.player_moved.connect(Callable(self, "_on_player_moved"))
	EventBus.card_drawn.connect(Callable(self, "_on_card_drawn"))
	EventBus.scavenge_drawn.connect(Callable(self, "_on_scavenge_drawn"))
	EventBus.monster_died.connect(Callable(self, "_on_monster_died"))
	_subscribed = true


func get_stats(player: Variant) -> PlayerStats:
	return _stats.get(player, PlayerStats.new())


func get_all_stats() -> Dictionary:
	return _stats


## 查询玩家对应的 survivor id（reset 时记录；未记录时返回 ""）。
func get_survivor_id(player: Variant) -> String:
	return str(_survivor_ids.get(player, ""))


## 从玩家对象读取 survivor id。
## survivor id = 玩家角色卡 RoleCard.english_name（由 Game._create_role_card_from_survivor
## 从 SurvivorData.english_name 复制而来，与 data/survivors/*.json 的文件 id 一致）。
## 角色卡缺失或无英文标识时返回 ""（正常对局不会发生，仅测试/异常场景）。
func _read_survivor_id(player: Variant) -> String:
	if player == null or typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
		return ""
	var role_card: Variant = player.get("role_card")
	if role_card != null and typeof(role_card) == TYPE_OBJECT:
		var sid: Variant = role_card.get("english_name")
		if sid != null and str(sid) != "":
			return str(sid)
	return ""


func start_timer() -> void:
	_start_time_msec = Time.get_ticks_msec()


func stop_timer() -> void:
	if _start_time_msec > 0:
		game_duration_msec = Time.get_ticks_msec() - _start_time_msec
	_start_time_msec = 0


func _on_damage_dealt(source: Variant, target: Variant, amount: int) -> void:
	if _ignore_events:
		return
	if _stats.has(source):
		get_stats(source).add_damage_dealt(amount)


func _on_damage_taken(target: Variant, source: Variant, amount: int) -> void:
	if _ignore_events:
		return
	if _stats.has(target):
		get_stats(target).add_damage_taken(amount)


func _on_hp_recovered(player: Variant, amount: int) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_hp_recovered(amount)


func _on_healing_done(source: Variant, target: Variant, amount: int) -> void:
	if _ignore_events:
		return
	if _stats.has(source):
		get_stats(source).add_healing_done(amount)


func _on_hunger_reduced(player: Variant, amount: int) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_hunger_reduced(amount)


func _on_card_used(player: Variant, card: Variant) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_cards_used(1)


func _on_skill_used(player: Variant, skill: Variant) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_skill_uses(1)


func _on_player_turn_started(player: Variant) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_turns_played(1)


func _on_player_moved(player: Variant, _src: Variant, _dst: Variant) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_moves(1)


func _on_card_drawn(player: Variant, _card: Variant) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_draw_count(1)


func _on_scavenge_drawn(player: Variant, _card: Variant) -> void:
	if _ignore_events:
		return
	if _stats.has(player):
		get_stats(player).add_scavenge_count(1)


func _on_monster_died(monster: Variant, source: Variant) -> void:
	if _ignore_events:
		return
	# 按单个怪物统计击杀数（键 = Monster.english_name；缺失/为空时以 "unknown" 兜底，
	# 保证击杀数据不丢失，正常对局怪物卡均携带 english_name）
	var key := _monster_kill_key(monster)
	if key != "":
		_monster_kills[key] = int(_monster_kills.get(key, 0)) + 1
	if source != null and _stats.has(source):
		get_stats(source).add_kills(1)
		if key != "":
			var per: Dictionary = _player_monster_kills.get(source, {})
			per[key] = int(per.get(key, 0)) + 1
			_player_monster_kills[source] = per
		# 首领击杀归属：monster_died 负载携带击杀来源 source，可按玩家可靠归属。
		# 首领判定 = Monster.monster_level == "boss"（实体化时由 MonsterCard 复制）。
		if monster != null and typeof(monster) == TYPE_OBJECT and is_instance_valid(monster):
			if str(monster.get("monster_level")) == "boss":
				_boss_kills[source] = int(_boss_kills.get(source, 0)) + 1


func _monster_kill_key(monster: Variant) -> String:
	if monster == null or typeof(monster) != TYPE_OBJECT or not is_instance_valid(monster):
		return ""
	var mname: Variant = monster.get("english_name")
	if mname != null and str(mname) != "":
		return str(mname)
	return "unknown"


# === 网络快照（显示世界灌入权威统计） ===

## 按座位序列化本局统计，供 STATE_SNAPSHOT / game_over 事件携带。
func to_network_dict(players: Array = []) -> Dictionary:
	var source: Array = players if not players.is_empty() else _stats.keys()
	var rows: Dictionary = {}
	for player in source:
		if player == null or typeof(player) != TYPE_OBJECT:
			continue
		if not _stats.has(player):
			continue
		var stats: PlayerStats = _stats[player]
		var per: Dictionary = _player_monster_kills.get(player, {})
		var row: Dictionary = stats.to_dict()
		row["boss_kills"] = int(_boss_kills.get(player, 0))
		row["monster_kills"] = per.duplicate() if per is Dictionary else {}
		row["survivor_id"] = get_survivor_id(player)
		rows[str(int(player.get("seat_number")))] = row
	return {
		"duration_msec": game_duration_msec,
		"players": rows,
	}


## 用权威统计覆盖显示世界。之后忽略 EventBus，避免和快照叠一份。
func apply_network_snapshot(players: Array, data: Dictionary) -> void:
	_ignore_events = true
	_stats.clear()
	_survivor_ids.clear()
	_monster_kills.clear()
	_boss_kills.clear()
	_player_monster_kills.clear()
	game_duration_msec = int(data.get("duration_msec", 0))
	_start_time_msec = 0
	var rows: Variant = data.get("players", {})
	if not (rows is Dictionary):
		rows = {}
	for player in players:
		if player == null or typeof(player) != TYPE_OBJECT:
			continue
		var seat_num := int(player.get("seat_number"))
		var row: Variant = rows.get(str(seat_num), rows.get(seat_num, {}))
		if not (row is Dictionary):
			row = {}
		var stats := PlayerStats.new()
		stats.from_dict(row)
		_stats[player] = stats
		var sid := str(row.get("survivor_id", ""))
		if sid == "":
			sid = _read_survivor_id(player)
		if sid != "":
			_survivor_ids[player] = sid
		_boss_kills[player] = int(row.get("boss_kills", 0))
		var mk: Variant = row.get("monster_kills", {})
		if mk is Dictionary:
			var copied: Dictionary = mk.duplicate()
			_player_monster_kills[player] = copied
			for mkey in copied:
				_monster_kills[str(mkey)] = int(_monster_kills.get(str(mkey), 0)) + int(copied[mkey])


# === 归档汇总 ===

## 返回本局结算归档汇总（供 ArchiveManager 归档）。
## 结构：
## - "result": "win"/"lose"；优先取 result_override（调用方注入，默认 ""），
##   否则从 Game 状态机读取；均不可得时为 ""（由调用方决定兜底）。
## - "duration_msec": game_duration_msec（stop_timer 后有效）
## - "player_count": 本局玩家数（联机过滤座位时仍为全队人数，供任务分档）
## - "mission_id": 任务 id（从 Game.current_mission 读取，不可得时为 -1）
## - "survivors": { survivor_id: {damage, kills, healing, turns, boss_kills} }
##   damage/kills/healing/turns 取自 PlayerStats（damage_dealt/kills/healing_done/turns_played）；
##   无 survivor id 的玩家（正常对局不出现）不进入该字典。
## - "monsters": { english_name: 击杀数 }（english_name = Monster.english_name，缺失时 "unknown"）
func get_archive_summary(result_override: String = "") -> Dictionary:
	return _build_archive_summary(result_override, null)


## 只把 only_players 写入 survivors / 怪物击杀；player_count / 任务 / 时长仍按全队。
## 联机归档：各端只录入自己操作的座位。单机请用 get_archive_summary()。
func get_archive_summary_for_players(only_players: Array, result_override: String = "") -> Dictionary:
	return _build_archive_summary(result_override, only_players)


func _build_archive_summary(result_override: String, only_players: Variant) -> Dictionary:
	var iterate: Array = _stats.keys() if only_players == null else only_players
	var survivors: Dictionary = {}
	for player in iterate:
		if not _stats.has(player):
			continue
		var sid: String = get_survivor_id(player)
		if sid == "":
			continue
		var stats: PlayerStats = _stats[player]
		survivors[sid] = {
			"damage": stats.damage_dealt,
			"kills": stats.kills,
			"healing": stats.healing_done,
			"turns": stats.turns_played,
			"boss_kills": int(_boss_kills.get(player, 0)),
		}
	var monsters: Dictionary = _monster_kills.duplicate()
	if only_players != null:
		monsters = _aggregate_player_monster_kills(only_players)
	return {
		"result": result_override if result_override != "" else _read_game_result(),
		"duration_msec": game_duration_msec,
		"player_count": _stats.size(),
		"mission_id": _read_mission_id(),
		"survivors": survivors,
		"monsters": monsters,
	}


func _aggregate_player_monster_kills(players: Array) -> Dictionary:
	var out: Dictionary = {}
	for player in players:
		var row: Variant = _player_monster_kills.get(player, {})
		if not (row is Dictionary):
			continue
		for mkey in row:
			var name := str(mkey)
			out[name] = int(out.get(name, 0)) + int(row[mkey])
	return out


## 从 Game 状态机读取胜负结果："win"/"lose"；未结束或不可得时返回 ""。
func _read_game_result() -> String:
	if Game == null or not is_instance_valid(Game):
		return ""
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		var result: int = Game.state_machine.get_game_result()
		if result == GameStateMachine.GameResult.WIN:
			return "win"
		if result == GameStateMachine.GameResult.LOSE:
			return "lose"
	var str_result: String = str(Game.game_result)
	if str_result == "win" or str_result == "lose":
		return str_result
	return ""


## 从 Game.current_mission 读取任务 id（MissionData.mission_id）；不可得时返回 -1。
func _read_mission_id() -> int:
	if Game == null or not is_instance_valid(Game):
		return -1
	var mission: Variant = Game.current_mission
	if mission is Dictionary:
		return int(mission.get("mission_id", -1))
	if mission == null or typeof(mission) != TYPE_OBJECT or not is_instance_valid(mission):
		return -1
	var mid: Variant = mission.get("mission_id")
	if mid == null:
		return -1
	return int(mid)
