class_name StatsTracker
extends RefCounted

## 本局统计聚合器。
## 订阅 EventBus 信号，为每个玩家维护 PlayerStats。
## 由 Game autoload 持有，在 start_game 时 reset，在 game_over 时 stop_timer。

var _stats: Dictionary = {} # player -> PlayerStats 映射
var game_duration_msec: int = 0
var _start_time_msec: int = 0
var _subscribed: bool = false


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
	for player in players:
		_stats[player] = PlayerStats.new()
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


func _on_monster_died(_monster: Variant, source: Variant) -> void:
	if source != null and _stats.has(source):
		get_stats(source).add_kills(1)
