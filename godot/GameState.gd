# [新增] 2026-06-24: 游戏状态管理类，负责存储全局游戏状态数据
# GameState.gd
extends Node

# [新增] 2026-06-24: 游戏基础状态
# 当前回合数
var current_turn: int = 1

# [新增] 2026-06-24: 当前激活玩家ID
var active_player_id: String = ""

# [新增] 2026-06-24: 当前游戏阶段
var current_phase: Enums.GamePhase = Enums.GamePhase.SPAWN

# [新增] 2026-06-24: 游戏状态（进行中、胜利、失败）
var game_status: Enums.GameStatus = Enums.GameStatus.PLAYING

# [新增] 2026-06-24: 配件流失检查 - 可用怪物标记数量
var available_monster_tokens: int = 30

# [新增] 2026-06-24: 共有牌堆（存放实例ID或实例）
# 怪物牌库
var monster_deck: Array[String] = []

# [新增] 2026-06-24: 怪物弃牌堆
var monster_discard_pile: Array[String] = []

# [新增] 2026-06-24: 拾荒牌库（按颜色分类）
var scavenge_decks = {
	Enums.ScavengeColor.RED: [],
	Enums.ScavengeColor.GREEN: [],
	Enums.ScavengeColor.BLUE: []
}

# [新增] 2026-06-24: 拾荒弃牌堆
var scavenge_discard_pile: Array[String] = []

# [新增] 2026-06-24: 地图网格：Key是Vector2i，Value是自定义的地图运行时字典或对象
var map_grid: Dictionary = {} # Dictionary[Vector2i, Dictionary]

# [新增] 2026-06-24: 所有玩家状态
var players: Dictionary = {} # Dictionary[String, PlayerState]

# [新增] 2026-06-24: 任务目标进度
# 需求的燃料数量
var required_fuel: int = 4

# [新增] 2026-06-24: 面包车中当前的燃料数量
var current_fuel_in_van: int = 0

# [新增] 2026-06-24: 信号（用于解耦数据与UI表现层）
# 阶段改变信号
signal phase_changed(new_phase: Enums.GamePhase)

# [新增] 2026-06-24: 玩家生命值改变信号
signal player_hp_changed(player_id: String, new_hp: int)

# [新增] 2026-06-24: 地块展示信号
signal tile_revealed(pos: Vector2i)

# [新增] 2026-06-24: 游戏结束信号
signal game_over(status: Enums.GameStatus)