class_name Player
extends Entity

## 玩家名字(玩家可见文本)。
var name: String = ""

var _max_hp: int = 6
var _hp: int = 6
var _hunger: int = 1
var _sneak_value: int = 0
var _role_card: RoleCard = RoleCard.new()
# 规则引用: 待定义方法.md §9.6 / §9.7 —— add_hp / add_hunger 为底层原子方法
var _marks: Dictionary = {}
var _current_block: Variant = null
var _dice_roller: Callable = Callable()


func set_max_hp(max_hp: int) -> void:
	_max_hp = max_hp


func set_hp(hp: int) -> void:
	_hp = hp


func set_hunger(hunger: int) -> void:
	_hunger = hunger


func set_sneak(sneak_value: int) -> void:
	_sneak_value = sneak_value


## 当前生命值。
func get_hp() -> int:
	return _hp


## 最大生命值上限。
func get_max_hp() -> int:
	return _max_hp


## 当前饥饿值(1~6,6 后翻面)。
func get_hunger() -> int:
	return _hunger


## 当前潜行值(基础值,不含地块怪物减成;sneakJudge 自行减成)。
func get_sneak() -> int:
	return _sneak_value


## 当前所在地图块。null 表示未在地图上。05 轮接 MapBlock。
func get_current_block() -> Variant:
	return _current_block


## 设置当前所在地图块(测试与后续移动流程用)。
func set_current_block(block: MapBlock) -> void:
	_current_block = block


## 注入骰子 roller(测试用)。roller 为无参 Callable,返回 int。
func set_dice_roller(roller: Callable) -> void:
	_dice_roller = roller


## 角色卡牌对象。
func get_role_card() -> RoleCard:
	return _role_card


# 规则引用: 待定义方法.md §9.6 —— 直接加血不触发钩子、不受上限约束
## 直接增加 num 点生命值,不触发"回复生命时"钩子,不受最大值约束。
## 与 recover 的区别见 待定义方法.md §9.6。
func add_hp(num: int) -> void:
	if num <= 0:
		return
	_hp += num


# 规则引用: 待定义方法.md §9.7 —— 直接加饥饿值不走 increaseHunger 流程
## 直接增加 num 点饥饿值,不走 increaseHunger 流程(不翻面、不加饥饿伤害标记)。
## 与 increaseHunger 的区别见 待定义方法.md §9.7。
func add_hunger(num: int) -> void:
	if num <= 0:
		return
	_hunger += num


## 直接减少 num 点饥饿值,不走 decreaseHunger 流程(不清饥饿伤害标记、不翻回)。
## 最低降至 1。与 decreaseHunger 的区别见 待定义方法.md §9.7。
func reduce_hunger(num: int) -> void:
	if num <= 0:
		return
	_hunger = max(1, _hunger - num)


## 增加潜行值。
func add_sneak(num: int) -> void:
	if num <= 0:
		return
	_sneak_value += num


## 减少潜行值(可为负)。
func reduce_sneak(num: int) -> void:
	if num <= 0:
		return
	_sneak_value -= num


## 添加 quantity 层标记。quantity 默认 1。
## 本轮不支持 Until 参数(永久标记),后续轮次扩展。
func addMarkSkill(mark_name: String, quantity: int = 1) -> void:
	if quantity <= 0:
		return
	_marks[mark_name] = int(_marks.get(mark_name, 0)) + quantity


## 移除标记(清零)。
func removeMarkSkill(mark_name: String) -> void:
	_marks.erase(mark_name)


## 获取标记层数。无此标记返回 0。
func countMark(mark_name: String) -> int:
	return int(_marks.get(mark_name, 0))


## 是否有指定标记(层数 > 0)。
func hasMarkSkill(mark_name: String) -> bool:
	return countMark(mark_name) > 0


## 直接扣血 num 点。可降至 0 以下(死亡判定由 damage 处理)。
func reduce_hp(num: int) -> void:
	if num <= 0:
		return
	_hp -= num


## 是否为玩家。
func is_player() -> bool:
	return true


## 恢复 num 点生命值,受最大值约束。
## 4 节点钩子链:回复生命前/时/系统加血/后。规则见 GameSystem/PlayerState.md。
## 规则引用: GameInstructions/J_gameEventFlow.md §16
func recover(num: int) -> void:
	if num <= 0:
		return
	var event := Event.new()
	event.target = self
	event.num = num
	trigger("回复生命前", event)
	trigger("回复生命时", event)
	if event.cancelled:
		return
	var max_recover := get_max_hp() - get_hp()
	if event.num > max_recover:
		event.num = max_recover
	add_hp(event.num)
	trigger("回复生命后", event)


## 增加 num 点饥饿值,逐点结算:到 6 翻面+加饥饿伤害标记,按等级造成无来源伤害。
## 规则见 GameSystem/PlayerState.md。
func increaseHunger(num: int) -> void:
	if num <= 0:
		return
	while num > 0:
		if get_hunger() < 6:
			add_hunger(1)
		elif get_hunger() == 6:
			if get_role_card().is_front():
				get_role_card().flip()
			addMarkSkill("饥饿伤害等级", 1)
		if countMark("饥饿伤害等级") > 0:
			var level := countMark("饥饿伤害等级")
			if level == 1:
				damage(2, null, "饥饿伤害")
			elif level == 2:
				damage(4, null, "饥饿伤害")
			elif level == 3:
				damage(6, null, "饥饿伤害")
			elif level == 4:
				damage(8, null, "饥饿伤害")
			elif level >= 5:
				_game_log_stub(name + "被饿死了")
				damage(get_max_hp(), null, "饥饿伤害")
		num -= 1


## 减少 num 点饥饿值,最低降至 1。清除饥饿伤害标记并翻回正面。
## 返回 bool:是否成功减少(已在 1 时返回 false)。规则见 GameSystem/PlayerState.md。
func decreaseHunger(num: int) -> bool:
	if num <= 0:
		return false
	var max_reduce := get_hunger() - 1
	if num > max_reduce:
		num = max_reduce
	if num <= 0:
		_game_log_stub("饥饿值已减少到1，无法继续减少")
		return false
	reduce_hunger(num)
	if countMark("饥饿伤害等级") > 0:
		removeMarkSkill("饥饿伤害等级")
	if not get_role_card().is_front():
		get_role_card().flip()
	return true


## 中毒结算:按 poison 标记层数造成无来源伤害。
## 规则见 GameSystem/PlayerState.md。
func poison() -> void:
	var level := countMark("poison")
	if level <= 0:
		return
	damage(level, null, "poison")


## 投两颗大骰子,返回点数和(2-12)。
## 测试可通过 set_dice_roller 注入固定返回。规则引用: GameSystem/Judge.md
func roll_two_dice() -> int:
	if _dice_roller.is_valid():
		return int(_dice_roller.call())
	return Dice.roll_two()


## 检定:投两颗大骰子,返回点数和(2-12)。
## 规则引用: GameSystem/Judge.md
func judge() -> int:
	return roll_two_dice()


## 潜行检定:结果 <= 潜行值(减地块怪物数+标记数)则成功。
## 失败分支(移除标记+抓怪物)由调用方处理,见 E_gameJudge.md。规则引用: GameSystem/Judge.md
func sneakJudge() -> bool:
	var block: Variant = get_current_block()
	var num := 0
	if block is MapBlock:
		num = block.countMonster() + block.countMonsterMark()
	var sneak_value := get_sneak() - num
	var result := judge()
	return result <= sneak_value


## 怪物出生检定:投骰子得 result,匹配的已展示地图块执行出生逻辑。
## revealed_blocks 由调用方注入(本轮无 game 对象);后续轮次改由 game.getRevealedMapBlocks()。
## 规则引用: GameSystem/Judge.md
func monsterSpawnJudge(revealed_blocks: Array[MapBlock] = []) -> void:
	var result := judge()
	for block in revealed_blocks:
		if not block.is_revealed():
			continue
		if block.monster_spawn_value != result:
			continue
		if block.countMonsterMark() < 3:
			block.addMonsterMark(1)
		elif block.countMonsterMark() == 3 and block.hasPlayer():
			for player in block.get_players():
				player.drawMonster(1)


## 抓 num 张怪物卡。本轮 stub;真实逻辑见 GameSystem/DrawFlow.md(后续轮次)。
## 规则引用: GameSystem/DrawFlow.md
func drawMonster(num: int) -> void:
	push_warning("drawMonster stub called on %s, num=%d" % [name, num])


## 玩家死亡流程。本轮 stub;真实逻辑见 GameSystem/DeathFlow.md(后续轮次)。
## 规则引用: GameSystem/DeathFlow.md
func playerDeath(source: Variant) -> void:
	push_warning("playerDeath stub called on %s. source=%s" % [name, str(source)])


func _on_death(source: Variant) -> void:
	playerDeath(source)


static func _game_log_stub(msg: String) -> void:
	push_warning("[game.log stub] " + msg)
