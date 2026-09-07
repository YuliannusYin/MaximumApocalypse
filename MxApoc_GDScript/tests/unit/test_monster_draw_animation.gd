extends TestBase

## 抓取怪物牌动画单元测试。
## 覆盖 Player.draw_monster 中 _play_monster_draw_animation 的调用约定：
## 逐张播放、n=0 不播放、牌堆与弃牌堆均空（game_over 分支）不播放、input 为 null 不崩溃。


# === 辅助方法 ===

func _make_combat_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.hp = hp
	p.max_hp = max_hp
	p.player_name = "TestPlayer"
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _setup_game_for_player(p: Player) -> void:
	Game.players = [p]
	Game.map_area = []
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.coop_death_mode = false
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


## 探针 input：记录 play_monster_draw_animation 的调用（次数/玩家/卡牌）。
class _MonsterDrawSpyInput extends CliPlayerInput:
	var calls: Array = []  # 每项 {"player": Player, "card": MonsterCard}

	func play_monster_draw_animation(player: Variant, card: Variant) -> void:
		calls.append({"player": player, "card": card})


# === 用例 ===

func test_draw_monster_two_plays_animation_per_card() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	var spy: _MonsterDrawSpyInput = _MonsterDrawSpyInput.new()
	p.input = spy
	var m1: MonsterCard = _make_monster_card("m1")
	var m2: MonsterCard = _make_monster_card("m2")
	Game.monster_pile.add(m1)
	Game.monster_pile.add(m2)
	await p.draw_monster(2)
	assert_eq(spy.calls.size(), 2, "draw_monster(2) 应逐张播放 2 次动画")
	assert_eq(spy.calls[0]["card"], m1, "第 1 次动画应传入当次抓到的 m1")
	assert_eq(spy.calls[1]["card"], m2, "第 2 次动画应传入当次抓到的 m2")
	assert_eq(spy.calls[0]["player"], p, "动画应以玩家自身为 player 参数")
	assert_eq(spy.calls[1]["player"], p, "动画应以玩家自身为 player 参数")
	assert_eq(p.monster_zone.size(), 2, "动画播放不应阻断实体化流程")


func test_draw_monster_zero_no_animation() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	var spy: _MonsterDrawSpyInput = _MonsterDrawSpyInput.new()
	p.input = spy
	Game.monster_pile.add(_make_monster_card("m1"))
	await p.draw_monster(0)
	assert_eq(spy.calls.size(), 0, "draw_monster(0) 不应播放动画")
	assert_eq(p.monster_zone.size(), 0, "draw_monster(0) 不应实体化怪物")


func test_draw_monster_empty_piles_game_over_no_animation() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	var spy: _MonsterDrawSpyInput = _MonsterDrawSpyInput.new()
	p.input = spy
	# 牌堆与弃牌堆均空 → game_over('lose') 分支，未抓到卡
	await p.draw_monster(1)
	assert_true(Game.game_over_called, "应触发 game_over('lose')")
	assert_eq(Game.game_result, "lose")
	assert_eq(spy.calls.size(), 0, "game_over 分支未抓到卡，不应播放动画")
	assert_eq(p.monster_zone.size(), 0, "不应实体化怪物")


func test_draw_monster_null_input_no_crash() -> void:
	var p: Player = _make_combat_player()
	_setup_game_for_player(p)
	p.input = null
	Game.monster_pile.add(_make_monster_card("m1"))
	await p.draw_monster(1)
	assert_eq(p.monster_zone.size(), 1, "input 为 null 时流程应正常完成并实体化怪物")


## 动画视图图片资源：怪物立绘按名称可查、牌背纹理已收录（images/monster 根目录）。
func test_monster_animation_image_resources() -> void:
	assert_not_null(ImageCache.get_monster_texture("僵尸步行者"), "常见怪物应有立绘图片")
	assert_not_null(ImageCache.get_monster_texture("僵尸步行者（精英）"), "精英怪应有独立立绘图片")
	assert_not_null(ImageCache.get_monster_card_back_texture(), "怪物牌背面图片应已收录")
