class_name WikiIndex
extends RefCounted

## 游戏 Wiki 目录：规则 JSON + DataManager 图鉴。
## 供 WikiOverlay 填充左栏 Tree 并按 id 取条目。

const RULES_DIR := "res://data/wiki/"

const KIND_CATEGORY := "category"
const KIND_RULE := "rule"
const KIND_SURVIVOR := "survivor"
const KIND_SURVIVOR_CARD := "survivor_card"
const KIND_COMMON_SKILL := "common_skill"
const KIND_SCAVENGE_CARD := "scavenge_card"
const KIND_MONSTER := "monster"
const KIND_MAP_BLOCK := "map_block"
const KIND_MISSION := "mission"
const KIND_VARIANT := "variant"

const SCAVENGE_COLOR_NAMES := {
	"blue": "蓝色",
	"green": "绿色",
	"red": "红色",
	"gray": "灰色",
}

const MONSTER_PACK_NAMES := {
	"zombie": "僵尸",
	"alien": "外星人",
	"mutant": "突变体",
	"robot": "机器人",
}

## id -> { id, title, kind, body, payload }
var _entries: Dictionary = {}
## 树节点描述：{ id, children: Array }
var _root_nodes: Array = []


func _init() -> void:
	_build()


func get_entry(id: String) -> Dictionary:
	return _entries.get(id, {})


func get_root_nodes() -> Array:
	return _root_nodes


func populate_tree(tree: Tree) -> void:
	tree.clear()
	tree.hide_root = true
	var root := tree.create_item()
	for node in _root_nodes:
		_add_tree_node(tree, root, node)


func _add_tree_node(tree: Tree, parent: TreeItem, node: Dictionary) -> void:
	var item := tree.create_item(parent)
	item.set_text(0, str(node.get("title", "")))
	item.set_metadata(0, str(node.get("id", "")))
	var children: Array = node.get("children", [])
	for child in children:
		if child is Dictionary:
			_add_tree_node(tree, item, child)
	if not children.is_empty():
		item.collapsed = true


func _build() -> void:
	_entries.clear()
	_root_nodes.clear()
	_root_nodes.append(_build_rules_branch())
	_root_nodes.append(_build_survivors_branch())
	_root_nodes.append(_build_common_skills_branch())
	_root_nodes.append(_build_scavenge_branch())
	_root_nodes.append(_build_monsters_branch())
	_root_nodes.append(_build_map_blocks_branch())
	_root_nodes.append(_build_missions_branch())
	_root_nodes.append(_build_variants_branch())


func _put(id: String, title: String, kind: String, body: String = "", payload: Variant = null) -> Dictionary:
	var entry := {
		"id": id,
		"title": title,
		"kind": kind,
		"body": body,
		"payload": payload,
	}
	_entries[id] = entry
	return {"id": id, "title": title, "children": []}


func _build_rules_branch() -> Dictionary:
	var cat_id := "cat.rules"
	_put(cat_id, "规则", KIND_CATEGORY, "合作求生的基本玩法：任务目标、回合流程、卡牌与检定。")
	var branch := {"id" : cat_id, "title": "规则", "children": []}
	var articles: Array = _load_rule_articles()
	articles.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	for article in articles:
		if not (article is Dictionary):
			continue
		var dict: Dictionary = article
		var id: String = str(dict.get("id", ""))
		if id.is_empty():
			continue
		var title: String = str(dict.get("title", id))
		var body: String = str(dict.get("body", ""))
		_put(id, title, KIND_RULE, body, dict)
		branch["children"].append({"id": id, "title": title, "children": []})
	return branch


func _load_rule_articles() -> Array:
	var result: Array = []
	var dir := DirAccess.open(RULES_DIR)
	if dir == null:
		push_error("WikiIndex: 无法打开规则目录: " + RULES_DIR)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var parsed: Variant = _load_json(RULES_DIR.path_join(file_name))
			if parsed is Dictionary:
				result.append(parsed)
			elif parsed is Array:
				for item in parsed:
					if item is Dictionary:
						result.append(item)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WikiIndex: 无法打开 " + path)
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("WikiIndex: 解析失败 " + path)
	return parsed


func _build_survivors_branch() -> Dictionary:
	var cat_id := "cat.survivors"
	_put(cat_id, "求生者", KIND_CATEGORY, "每位求生者有独立生命值、潜行、装备栏与个人牌堆。")
	var branch := {"id": cat_id, "title": "求生者", "children": []}
	var survivors: Array = DataManager.get_all_survivors()
	survivors.sort_custom(func(a, b): return a.character_name < b.character_name)
	for survivor in survivors:
		if survivor == null:
			continue
		branch["children"].append(_build_survivor_node(survivor, ""))
	return branch


func _build_survivor_node(survivor: SurvivorData, id_prefix: String) -> Dictionary:
	var sid: String = id_prefix + "survivor." + survivor.english_name
	_put(sid, survivor.character_name, KIND_SURVIVOR, "", survivor)
	var node := {"id": sid, "title": survivor.character_name, "children": []}
	var skill_i := 0
	for raw_skill in survivor.intrinsic_skills:
		var skill := raw_skill as SkillData
		if skill == null:
			continue
		var skill_title: String = skill.skill_name if skill.skill_name != "" else skill.english_name
		var skill_id: String = sid + ".skill." + str(skill_i) + "." + skill.english_name
		_put(skill_id, skill_title, KIND_COMMON_SKILL, "", skill)
		node["children"].append({"id": skill_id, "title": skill_title, "children": []})
		skill_i += 1
	var seen_cards: Dictionary = {}
	for card_dict in survivor.deck:
		if not (card_dict is Dictionary):
			continue
		var english: String = str(card_dict.get("english_name", ""))
		var card_name: String = str(card_dict.get("card_name", english))
		if english != "" and seen_cards.has(english):
			continue
		if english != "":
			seen_cards[english] = true
		var cid: String = sid + ".card." + (english if english != "" else card_name)
		_put(cid, card_name, KIND_SURVIVOR_CARD, "", card_dict)
		node["children"].append({"id": cid, "title": card_name, "children": []})
	for sub in survivor.sub_survivors:
		if not (sub is Dictionary):
			continue
		var sub_data := SurvivorData.new(sub)
		if sub_data.english_name == "":
			continue
		node["children"].append(_build_survivor_node(sub_data, sid + "."))
	return node


func _build_common_skills_branch() -> Dictionary:
	var cat_id := "cat.common_skills"
	_put(cat_id, "通用技能", KIND_CATEGORY, "所有求生者共用的主动技能。")
	var branch := {"id": cat_id, "title": "通用技能", "children": []}
	for raw_skill in DataManager.get_common_skills():
		var skill := raw_skill as SkillData
		if skill == null:
			continue
		var id: String = "common_skill." + skill.english_name
		_put(id, skill.skill_name, KIND_COMMON_SKILL, "", skill)
		branch["children"].append({"id": id, "title": skill.skill_name, "children": []})
	return branch


func _build_scavenge_branch() -> Dictionary:
	var cat_id := "cat.scavenge"
	_put(cat_id, "拾荒", KIND_CATEGORY, "按地块颜色从对应拾荒牌堆抓牌。使用后的拾荒卡进入拾荒弃牌堆。")
	var branch := {"id": cat_id, "title": "拾荒", "children": []}
	for color in DataManager.get_scavenge_pile_colors():
		var color_name: String = SCAVENGE_COLOR_NAMES.get(color, str(color))
		var color_id := "cat.scavenge." + str(color)
		_put(color_id, color_name, KIND_CATEGORY, color_name + "拾荒牌堆。")
		var color_node := {"id": color_id, "title": color_name, "children": []}
		for raw_card in DataManager.get_scavenge_pile(str(color)):
			var card := raw_card as ScavengeCardData
			if card == null:
				continue
			var id: String = "scavenge." + str(color) + "." + card.english_name
			_put(id, card.card_name, KIND_SCAVENGE_CARD, "", card)
			color_node["children"].append({"id": id, "title": card.card_name, "children": []})
		branch["children"].append(color_node)
	return branch


func _build_monsters_branch() -> Dictionary:
	var cat_id := "cat.monsters"
	_put(cat_id, "怪物", KIND_CATEGORY, "任务会指定一套怪物包。怪物卡进入玩家面前后与该玩家纠缠。")
	var branch := {"id": cat_id, "title": "怪物", "children": []}
	for pack_type in DataManager.get_monster_pack_types():
		var pack_name: String = MONSTER_PACK_NAMES.get(pack_type, str(pack_type))
		var pack_id := "cat.monsters." + str(pack_type)
		_put(pack_id, pack_name, KIND_CATEGORY, pack_name + "怪物包。")
		var pack_node := {"id": pack_id, "title": pack_name, "children": []}
		for raw_monster in DataManager.get_monster_pack(str(pack_type)):
			var monster := raw_monster as MonsterCardData
			if monster == null:
				continue
			var id: String = "monster." + str(pack_type) + "." + monster.english_name
			_put(id, monster.monster_name, KIND_MONSTER, "", monster)
			pack_node["children"].append({"id": id, "title": monster.monster_name, "children": []})
		branch["children"].append(pack_node)
	return branch


func _build_map_blocks_branch() -> Dictionary:
	var cat_id := "cat.map_blocks"
	_put(cat_id, "地图块", KIND_CATEGORY, "地图由地块组成。地块有拾荒颜色、怪物生成点数，部分地块带特殊效果。")
	var branch := {"id": cat_id, "title": "地图块", "children": []}
	for raw_block in DataManager.get_all_map_blocks():
		var block := raw_block as MapBlockData
		if block == null:
			continue
		var id: String = "map_block." + block.english_name
		_put(id, block.block_name, KIND_MAP_BLOCK, "", block)
		branch["children"].append({"id": id, "title": block.block_name, "children": []})
	return branch


func _build_missions_branch() -> Dictionary:
	var cat_id := "cat.missions"
	_put(cat_id, "任务", KIND_CATEGORY, "每局选择一个任务。任务决定地图、怪物包、拾荒构成与胜负条件。")
	var branch := {"id": cat_id, "title": "任务", "children": []}
	for raw_mission in DataManager.get_all_missions():
		var mission := raw_mission as MissionData
		if mission == null:
			continue
		var id: String = "mission." + str(mission.mission_id)
		_put(id, mission.mission_name, KIND_MISSION, "", mission)
		branch["children"].append({"id": id, "title": mission.mission_name, "children": []})
	return branch


func _build_variants_branch() -> Dictionary:
	var cat_id := "cat.variants"
	_put(cat_id, "变体", KIND_CATEGORY, "可选的额外规则，用于提高难度或改变合作方式。")
	var branch := {"id": cat_id, "title": "变体", "children": []}
	var variants: Array = DataManager.get_all_variants()
	variants.sort_custom(func(a, b): return a.display_name < b.display_name)
	for raw_variant in variants:
		var variant := raw_variant as VariantData
		if variant == null:
			continue
		var id: String = "variant." + variant.id
		_put(id, variant.display_name, KIND_VARIANT, "", variant)
		branch["children"].append({"id": id, "title": variant.display_name, "children": []})
	return branch
