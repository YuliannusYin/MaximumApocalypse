class_name TestBase
extends GutTest

## 测试共享基类。
## 统一承载 Game 全局状态清理（before/after_each 自动调用）与常见测试对象构造器，
## 各测试文件 extends TestBase 复用，减少跨文件重复代码。
## 构造器默认值保持保守（不主动设置可选战斗字段），文件需要特殊初始化时在调用后追加。

# === 全局状态清理 ===

## 清理所有 Game 全局状态，避免用例间状态泄漏。
func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.map_width = 0
	Game.map_height = 0
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.current_mission = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 常见测试对象构造器 ===

func _make_card(card_name: String = "test_card", card_type: String = "action", source: String = "game") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = card_type
	c.source = source
	return c


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0, revealed: bool = false) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	b.revealed = revealed
	return b


func _make_player(player_name: String = "TestPlayer", hp: int = 10, max_hp: int = -1) -> Player:
	var p: Player = Player.new()
	p.player_name = player_name
	p.hp = hp
	p.max_hp = hp if max_hp < 0 else max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_monster_card(card_name: String = "test_monster", level: String = "normal") -> MonsterCard:
	var c: MonsterCard = MonsterCard.new()
	c.card_name = card_name
	c.card_type = "monster"
	c.source = "monster"
	c.monster_type = "zombie"
	c.monster_level = level
	c.max_hp = 3
	c.damage_value = 2
	c.range = "none"
	return c


func _make_monster(monster_name: String = "test_monster") -> Monster:
	return _make_monster_card(monster_name).instantiate(null)


func _make_equipment(card_name: String = "test_equip") -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = card_name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	e.charge_type = "ammo"
	e.charge_max = 3
	e.charge_current = 3
	return e


func _make_scavenge_card(card_name: String = "test_scavenge", color: String = "blue") -> ScavengeCard:
	var c: ScavengeCard = ScavengeCard.new()
	c.card_name = card_name
	c.card_type = "item"
	c.source = "scavenge"
	c.color = color
	c.scavenge_type = "consumable"
	return c
