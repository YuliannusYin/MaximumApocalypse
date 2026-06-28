# 游戏状态管理类，负责存储全局游戏状态数据
# 注意：GameState是autoload单例，不要添加class_name以避免冲突
extends Node

# === 游戏配置数据 ===
var selected_mission: MissionData  # 选中的关卡数据
var selected_character_ids: Array[String] = []  # 选中的角色ID列表

# 游戏基础状态
var current_turn: int = 1

var active_player_id: String = ""

var current_phase: Enums.GamePhase = Enums.GamePhase.SPAWN

var game_status: Enums.GameStatus = Enums.GameStatus.PLAYING

var available_monster_tokens: int = 30

var monster_deck: Array = []  # 怪物牌库，存放MonsterData资源实例

var monster_discard_pile: Array = []  # 怪物弃牌堆

var scavenge_decks = {
	Enums.ScavengeColor.RED: [],
	Enums.ScavengeColor.GREEN: [],
	Enums.ScavengeColor.BLUE: []
}

var scavenge_discard_pile: Array[String] = []

var map_grid: Dictionary = {}

var players: Dictionary = {}

var required_fuel: int = 4

var current_fuel_in_van: int = 0

signal phase_changed(new_phase: Enums.GamePhase)

signal player_hp_changed(player_id: String, new_hp: int)

signal tile_revealed(pos: Vector2i)

signal game_over(status: Enums.GameStatus)
