class_name MapBlock
extends Entity

## 怪物生成点数(匹配 judge 结果,2-12)。
var monster_spawn_value: int = 0

var _revealed: bool = false
var _monster_marks: int = 0
var _monsters: Array = []
var _players: Array = []


## 是否已展示(翻开)。
func is_revealed() -> bool:
	return _revealed


## 怪物标记数(0-3)。
## 规则引用: GameSystem/Judge.md(monsterSpawnJudge)
func countMonsterMark() -> int:
	return _monster_marks


## 添加 n 个怪物标记。
func addMonsterMark(n: int) -> void:
	if n <= 0:
		return
	_monster_marks += n


## 移除所有怪物标记。
func removeAllMonsterMarks() -> void:
	_monster_marks = 0


## 地块上是否有玩家。
func hasPlayer() -> bool:
	return not _players.is_empty()


## 地块上的怪物数(stub,返回 _monsters 大小)。
func countMonster() -> int:
	return _monsters.size()


## 添加玩家到地块。
## p 类型为 Variant 以避免与 Player 的循环依赖。
func addPlayer(p: Variant) -> void:
	_players.append(p)


## 移除玩家。
func removePlayer(p: Variant) -> void:
	_players.erase(p)


## 设置已展示(测试与后续展示机制用)。
func set_revealed(v: bool) -> void:
	_revealed = v


## 地块上的所有玩家(stub,返回 _players 副本)。
func get_players() -> Array:
	return _players.duplicate()
