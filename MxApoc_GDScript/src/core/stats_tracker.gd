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
	_stats.clear()
	_survivor_ids.clear()
	_monster_kills.clear()
	_boss_kills.clear()
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
	if _stats.has(source):
		get_stats(source).add_damage_dealt(amount)


func _on_damage_taken(target: Variant, source: Variant, amount: int) -> void:
	if _stats.has(target):
		get_stats(target).add_damage_taken(amount)


func _on_hp_recovered(player: Variant, amount: int) -> void:
	if _stats.has(player):
		get_stats(player).add_hp_recovered(amount)


func _on_healing_done(source: Variant, target: Variant, amount: int) -> void:
	if _stats.has(source):
		get_stats(source).add_healing_done(amount)


func _on_hunger_reduced(player: Variant, amount: int) -> void:
	if _stats.has(player):
		get_stats(player).add_hunger_reduced(amount)


func _on_card_used(player: Variant, card: Variant) -> void:
	if _stats.has(player):
		get_stats(player).add_cards_used(1)


func _on_skill_used(player: Variant, skill: Variant) -> void:
	if _stats.has(player):
		get_stats(player).add_skill_uses(1)


func _on_player_turn_started(player: Variant) -> void:
	if _stats.has(player):
		get_stats(player).add_turns_played(1)


func _on_player_moved(player: Variant, _src: Variant, _dst: Variant) -> void:
	if _stats.has(player):
		get_stats(player).add_moves(1)


func _on_card_drawn(player: Variant, _card: Variant) -> void:
	if _stats.has(player):
		get_stats(player).add_draw_count(1)


func _on_scavenge_drawn(player: Variant, _card: Variant) -> void:
	if _stats.has(player):
		get_stats(player).add_scavenge_count(1)


func _on_monster_died(monster: Variant, source: Variant) -> void:
	# 按单个怪物统计击杀数（键 = Monster.english_name；缺失/为空时以 "unknown" 兜底，
	# 保证击杀数据不丢失，正常对局怪物卡均携带 english_name）
	if monster != null and typeof(monster) == TYPE_OBJECT and is_instance_valid(monster):
		var mname: Variant = monster.get("english_name")
		var key: String = str(mname) if mname != null and str(mname) != "" else "unknown"
		_monster_kills[key] = int(_monster_kills.get(key, 0)) + 1
	if source != null and _stats.has(source):
		get_stats(source).add_kills(1)
		# 首领击杀归属：monster_died 负载携带击杀来源 source，可按玩家可靠归属。
		# 首领判定 = Monster.monster_level == "boss"（实体化时由 MonsterCard 复制）。
		if monster != null and typeof(monster) == TYPE_OBJECT and is_instance_valid(monster):
			if str(monster.get("monster_level")) == "boss":
				_boss_kills[source] = int(_boss_kills.get(source, 0)) + 1


# === 归档汇总 ===

## 返回本局结算归档汇总（供 ArchiveManager 归档）。
## 结构：
## - "result": "win"/"lose"；优先取 result_override（调用方注入，默认 ""），
##   否则从 Game 状态机读取；均不可得时为 ""（由调用方决定兜底）。
## - "duration_msec": game_duration_msec（stop_timer 后有效）
## - "player_count": 本局玩家数
## - "mission_id": 任务 id（从 Game.current_mission 读取，不可得时为 -1）
## - "survivors": { survivor_id: {damage, kills, healing, turns, boss_kills} }
##   damage/kills/healing/turns 取自 PlayerStats（damage_dealt/kills/healing_done/turns_played）；
##   无 survivor id 的玩家（正常对局不出现）不进入该字典。
## - "monsters": { english_name: 击杀数 }（english_name = Monster.english_name，缺失时 "unknown"）
func get_archive_summary(result_override: String = "") -> Dictionary:
	var survivors: Dictionary = {}
	for player in _stats:
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
	return {
		"result": result_override if result_override != "" else _read_game_result(),
		"duration_msec": game_duration_msec,
		"player_count": _stats.size(),
		"mission_id": _read_mission_id(),
		"survivors": survivors,
		"monsters": _monster_kills.duplicate(),
	}


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
