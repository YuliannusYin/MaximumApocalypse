class_name Pile
extends RefCounted

## 通用牌堆结构。
## 提供抓牌、弃牌、洗牌等操作。Pile 不继承 Entity（无技能、无 trigger），是数据容器。
## 设计文档：GameDesignDocus/GameSystem/Common/Pile.md
## 重洗规则由调用方处理（怪物牌堆空时重洗弃牌堆；拾荒牌堆空时不重洗；玩家游戏牌堆空时玩家死亡）。

## 牌堆中的卡牌列表（有序）。顶部在索引 0，底部在末尾。
var cards: Array = []


## 从牌堆顶抓取一张牌并返回。空时返回 null。
func draw() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_front()


## 判断牌堆是否为空。
func is_empty() -> bool:
	return cards.is_empty()


## 将一张牌加入牌堆底部。
func add(card: Card) -> void:
	cards.append(card)


## 查看牌堆顶 n 张牌（不移除）。不足时返回全部。
func peek_top(n: int) -> Array:
	if n <= 0:
		return []
	return cards.slice(0, n)


## 将一张牌置于牌堆底（语义化别名，等价于 add）。
func put_bottom(card: Card) -> void:
	cards.append(card)


## 洗牌（随机打乱牌堆顺序）。
func shuffle() -> void:
	cards.shuffle()


## 将本牌堆的所有牌洗入目标牌堆（本牌堆清空，目标牌堆重洗）。
## 触发场景：怪物牌堆空时重洗怪物弃牌堆。
func shuffle_into(target_pile: Pile) -> void:
	for card in cards:
		target_pile.cards.append(card)
	cards.clear()
	target_pile.shuffle()


## 返回牌堆中所有牌的列表（不移除）。
func get_all() -> Array:
	return cards.duplicate()


## 返回牌堆中卡牌数量。
func size() -> int:
	return cards.size()
