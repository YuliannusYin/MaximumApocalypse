# GameState.gd
extends Node

# 游戏基础状态
var current_turn: int = 1
var active_player_id: String = ""
var current_phase: Enums.GamePhase = Enums.GamePhase.SPAWN
var game_status: Enums.GameStatus = Enums.GameStatus.PLAYING

# 配件流失检查
var available_monster_tokens: int = 30

# 共有牌堆 (存放实例ID或实例)
var monster_deck: Array[String] = []
var monster_discard_pile: Array[String] = []

var scavenge_decks = {
	Enums.ScavengeColor.RED: [],
	Enums.ScavengeColor.GREEN: [],
	Enums.ScavengeColor.BLUE: []
}
var scavenge_discard_pile: Array[String] = []

# 地图网格：Key 是 Vector2i，Value 是自定义的地图运行时字典或对象
var map_grid: Dictionary = {} # Dictionary[Vector2i, Dictionary]

# 所有玩家状态
var players: Dictionary = {} # Dictionary[String, PlayerState]

# 任务目标进度
var required_fuel: int = 4
var current_fuel_in_van: int = 0

# 信号（用于解耦数据与 UI 表现层）
signal phase_changed(new_phase: Enums.GamePhase)
signal player_hp_changed(player_id: String, new_hp: int)
signal tile_revealed(pos: Vector2i)
signal game_over(status: Enums.GameStatus)
