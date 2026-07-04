class_name Survivors

static var _ALL: Array[SurvivorData] = []

static func _ensure_all() -> void:
	if not _ALL.is_empty():
		return
	_ALL.append(_make("firefighter", "消防员", 32, 6, 5, "拳打", "行动：对一个目标造成2点伤害。", false, ""))
	_ALL.append(_make("gunslinger", "枪手", 28, 7, 6, "快速拔枪", "游戏开始时，将牌堆中的装备牌【柯尔特手枪】装备你的装备区。当你受到饥饿伤害时，将装备区或弃牌区中的【柯尔特手枪】重新洗回你的牌堆。", false, ""))
	_ALL.append(_make("hunter", "猎人", 24, 9, 8, "侦察", "行动：最多展示两个相邻的地图块，且不触发任何地块触发效果。", false, ""))
	_ALL.append(_make("mechanic", "机械师", 26, 8, 7, "维修", "行动：从任一弃牌堆中选择一张装备牌，并把它放置在场上任一玩家的装备区中。", false, ""))
	_ALL.append(_make("surgeon", "外科医生", 23, 8, 7, "缝合", "行动：使一名玩家回复1点生命。", false, ""))
	_ALL.append(_make("veteran", "老兵与狗", 22, 7, 6, "把你的爪子拿开", "行动：对老兵造成2点伤害，然后狗直到你的下回合开始免疫伤害。", true,
		"“老兵与狗”为二位一体特殊角色：作为一个整体同时移动、共用行动次数与回合，但生命值与饥饿值“老兵”与“狗”各自独立计算（老兵HP22/潜行7，狗HP12/潜行9，两角色均存活时潜行取最低值）。公用一个手牌区、游戏牌堆、游戏牌弃牌区，“老兵”与“狗”各自独立有一个装备区。其中一方生命值≤0即永久死亡，另一方仍可继续存活并单独行动。"))

static func get_all() -> Array[SurvivorData]:
	_ensure_all()
	return _ALL

static func get_by_id(id: String) -> SurvivorData:
	_ensure_all()
	for s in _ALL:
		if s.id == id:
			return s
	return null

static func _make(id: String, display_name: String, hp: int, stealth: int, hunger_stealth: int, skill_name: String, skill_desc: String, is_special: bool, special_note: String) -> SurvivorData:
	var s := SurvivorData.new()
	s.id = id
	s.display_name = display_name
	s.hp = hp
	s.stealth = stealth
	s.hunger_stealth = hunger_stealth
	s.skill_name = skill_name
	s.skill_desc = skill_desc
	s.is_special = is_special
	s.special_note = special_note
	s.icon_path = "res://images/survivors/%s.png" % id
	return s
