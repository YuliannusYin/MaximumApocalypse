class_name Dice
extends RefCounted

## 投两颗标准骰子(1-6),返回点数和(2-12)。
## "大骰子"指物理尺寸,点数仍为 1-6。规则引用: GameSystem/Judge.md
static func roll_two() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 6) + rng.randi_range(1, 6)
