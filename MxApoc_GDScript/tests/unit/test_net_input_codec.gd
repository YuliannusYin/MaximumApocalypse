extends TestBase

## 网络输入编解码：怪物中文名、弃牌堆卡牌解析、装备卡重建。


func test_encode_monster_keeps_monster_name() -> void:
	var monster: Monster = _make_monster("丧尸")
	monster.english_name = "zombie"
	monster.hp = 2
	monster.max_hp = 4
	monster.damage_value = 3
	monster.range = "short"
	monster.stunned = true
	var encoded: Variant = NetInputCodec.encode(monster)
	assert_eq(encoded["__kind"], "monster")
	assert_eq(encoded["monster_name"], "丧尸")
	assert_eq(encoded["hp"], 2)
	assert_eq(encoded["damage_value"], 3)
	assert_eq(encoded["range"], "short")
	assert_true(encoded["stunned"])


func test_decode_monster_returns_live_zone_reference_without_writing() -> void:
	var holder: Player = _make_player("P")
	holder.seat_number = 0
	var monster: Monster = Monster.new()
	monster.english_name = "zombie"
	monster.monster_name = "丧尸"
	monster.hp = 5
	monster.max_hp = 5
	monster.attack_target = holder
	holder.monster_zone = [monster]
	Game.players = [holder]
	var decoded: Variant = NetInputCodec.decode({
		"__kind": "monster",
		"id": "zombie",
		"monster_name": "别的名字",
		"hp": 0,
		"max_hp": 5,
		"holder_seat": 0,
		"zone_index": 0,
	}, Game)
	assert_eq(decoded, monster)
	assert_eq(monster.monster_name, "丧尸", "decode 不得改写活怪字段")
	assert_eq(monster.hp, 5, "decode 不得把活怪血量写成 payload 里的 0")


func test_decode_zero_hp_payload_does_not_clobber_live_hp() -> void:
	var holder: Player = _make_player("P")
	holder.seat_number = 0
	var monster: Monster = Monster.new()
	monster.net_id = 41
	monster.english_name = "zombie"
	monster.hp = 4
	monster.max_hp = 5
	holder.monster_zone = [monster]
	Game.players = [holder]
	var decoded: Variant = NetInputCodec.decode({
		"__kind": "monster",
		"net_id": 41,
		"hp": 0,
		"max_hp": 5,
	}, Game)
	assert_eq(decoded, monster)
	assert_eq(monster.hp, 4)


func test_apply_display_combat_fields_updates_live_hp() -> void:
	var holder: Player = _make_player("P")
	holder.seat_number = 0
	var monster: Monster = Monster.new()
	monster.net_id = 41
	monster.english_name = "zombie"
	monster.monster_name = "丧尸"
	monster.hp = 5
	monster.max_hp = 5
	monster.stunned = false
	holder.monster_zone = [monster]
	Game.players = [holder]
	NetInputCodec.apply_display_combat_fields({
		"targets": [{
			"__kind": "monster",
			"net_id": 41,
			"hp": 2,
			"max_hp": 5,
			"stunned": true,
		}],
	}, Game)
	assert_eq(monster.hp, 2, "选目标 payload 应把显示层活怪血量写成新值")
	assert_true(monster.stunned)
	var decoded: Variant = NetInputCodec.decode({
		"__kind": "monster",
		"net_id": 41,
		"hp": 0,
		"max_hp": 5,
	}, Game)
	assert_eq(decoded, monster)
	assert_eq(monster.hp, 2, "通用 decode 仍不得改写活怪血量")


func test_resolve_card_finds_discard_pile_equipment() -> void:
	var player: Player = _make_player("Hunter")
	var equipment: EquipmentCard = _make_equipment("迷彩服")
	equipment.english_name = "camouflage"
	player.game_discard_pile.add(equipment)
	Game.players = [player]
	var resolved: Variant = NetInputCodec.resolve_card({
		"id": "camouflage",
		"card_name": "迷彩服",
		"card_type": "equipment",
		"source": "game",
	}, Game)
	assert_eq(resolved, equipment)


func test_create_card_from_payload_equipment_fallback() -> void:
	var card: Variant = NetInputCodec.create_card_from_payload({
		"id": "unknown_equip",
		"english_name": "unknown_equip",
		"card_name": "测试装备",
		"card_type": "equipment",
		"source": "game",
	}, Game)
	assert_true(card is EquipmentCard, "装备 payload 在无静态数据时应重建为 EquipmentCard")
	assert_eq(card.card_name, "测试装备")


func test_encode_player_includes_role_english_name() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 2
	var role := RoleCard.new()
	role.english_name = "hunter"
	player.role_card = role
	var encoded: Variant = NetInputCodec.encode(player)
	assert_eq(encoded["seat_id"], 2)
	assert_eq(encoded["role_english_name"], "hunter")


func test_decode_separates_same_english_name_by_net_id() -> void:
	var player: Player = _make_player("Hunter")
	player.seat_number = 0
	var first: Card = _make_card("手枪")
	first.english_name = "pistol"
	first.net_id = 21
	var second: Card = _make_card("手枪")
	second.english_name = "pistol"
	second.net_id = 22
	player.hand = [first, second]
	Game.players = [player]
	var decoded: Variant = NetInputCodec.decode({
		"__kind": "card",
		"net_id": 22,
		"id": "pistol",
	}, Game)
	assert_eq(decoded, second, "同名牌应按 net_id 命中第二张")
	var encoded: Variant = NetInputCodec.encode(first)
	assert_eq(encoded["net_id"], 21)
