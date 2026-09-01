extends Control

## 游戏 Wiki 覆盖层（文明百科式：左分类树 + 右条目）。
## 主菜单与对局共用；对局应加到 PopupLayer，不切场景、不停整棵树。

signal closed

const WikiIndex = preload("res://src/ui/wiki_index.gd")

const _COLOR_TEXT := Color(0.92, 0.92, 0.92)
const _COLOR_DIM := Color(0.62, 0.62, 0.66)
const _COLOR_ACCENT := Color(1.0, 0.85, 0.3)

const _RANGE_NAMES := {
	"none": "无",
	"short": "短距离",
	"medium": "中距离",
	"long": "长距离",
	"infinity": "无限",
}

const _CARD_TYPE_NAMES := {
	"action": "行动牌",
	"equipment": "装备牌",
}

const _MONSTER_LEVEL_NAMES := {
	"boss": "首领",
	"elite": "精英",
	"normal": "普通",
}

const _CHARGE_TYPE_NAMES := {
	"fuel": "燃料",
	"ammo": "弹药",
}

const _SCAVENGE_COLOR_NAMES := WikiIndex.SCAVENGE_COLOR_NAMES
const _MONSTER_PACK_NAMES := WikiIndex.MONSTER_PACK_NAMES

@onready var _tree: Tree = $Margin/Panel/VBox/Split/Tree
@onready var _article: VBoxContainer = $Margin/Panel/VBox/Split/ArticleScroll/Article
@onready var _close_button: Button = $Margin/Panel/VBox/CloseButton

var _index = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_close_button.pressed.connect(_on_close)
	_tree.item_selected.connect(_on_tree_item_selected)
	_index = WikiIndex.new()
	_index.populate_tree(_tree)
	_collapse_tree_branches(_tree.get_root())
	_article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = $Margin/Panel/VBox/Split/ArticleScroll
	scroll.resized.connect(_fit_article_width)
	_fit_article_width()
	var first := _tree.get_root().get_first_child() if _tree.get_root() else null
	if first != null:
		first.select(0)
		_render_entry(str(first.get_metadata(0)))
		_collapse_tree_branches(_tree.get_root())


func _fit_article_width() -> void:
	var scroll: ScrollContainer = $Margin/Panel/VBox/Split/ArticleScroll
	var w := int(scroll.size.x) - 12
	if w > 80:
		_article.custom_minimum_size.x = w


func _collapse_tree_branches(item: TreeItem) -> void:
	if item == null:
		return
	var child := item.get_first_child()
	while child != null:
		if child.get_first_child() != null:
			child.collapsed = true
		_collapse_tree_branches(child)
		child = child.get_next()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible and is_inside_tree()


func _on_close() -> void:
	closed.emit()
	queue_free()


func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	_render_entry(str(item.get_metadata(0)))


func _render_entry(id: String) -> void:
	for child in _article.get_children():
		child.queue_free()
	var entry: Dictionary = _index.get_entry(id)
	if entry.is_empty():
		_add_body("（无此条目）")
		return
	var kind: String = str(entry.get("kind", ""))
	var title: String = str(entry.get("title", ""))
	_add_title(title)
	match kind:
		WikiIndex.KIND_CATEGORY:
			_add_body(str(entry.get("body", "")))
		WikiIndex.KIND_RULE:
			_add_rich(str(entry.get("body", "")))
		WikiIndex.KIND_SURVIVOR:
			_render_survivor(entry.get("payload"))
		WikiIndex.KIND_SURVIVOR_CARD:
			_render_card_dict(entry.get("payload"))
		WikiIndex.KIND_COMMON_SKILL:
			_render_skill(entry.get("payload"))
		WikiIndex.KIND_SCAVENGE_CARD:
			_render_scavenge_card(entry.get("payload"))
		WikiIndex.KIND_MONSTER:
			_render_monster(entry.get("payload"))
		WikiIndex.KIND_MAP_BLOCK:
			_render_map_block(entry.get("payload"))
		WikiIndex.KIND_MISSION:
			_render_mission(entry.get("payload"))
		WikiIndex.KIND_VARIANT:
			_render_variant(entry.get("payload"))
		_:
			_add_body(str(entry.get("body", "")))


func _render_survivor(payload: Variant) -> void:
	var survivor := payload as SurvivorData
	if survivor == null:
		return
	_add_image(ImageCache.get_role_card_texture(survivor.english_name, true))
	_add_stat("生命值", "%d / %d" % [survivor.initial_hp, survivor.max_hp])
	_add_stat("潜行", str(survivor.stealth))
	_add_stat("饥饿潜行", str(survivor.hunger_stealth))
	_add_stat("装备栏", str(survivor.equipment_slot))
	_add_stat("手牌上限", str(survivor.hand_size_limit))
	if not survivor.intrinsic_skills.is_empty():
		_add_section("固有技能")
		for skill in survivor.intrinsic_skills:
			_add_skill_block(skill)
	if not survivor.deck.is_empty():
		_add_section("个人牌堆")
		for card_dict in survivor.deck:
			if card_dict is Dictionary:
				var count := int(card_dict.get("count", 1))
				var name: String = str(card_dict.get("card_name", ""))
				_add_body("• %s ×%d" % [name, count], _COLOR_DIM)


func _render_card_dict(payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var data: Dictionary = payload
	var card_name: String = str(data.get("card_name", ""))
	_add_image(ImageCache.get_card_texture(card_name))
	_add_stat("类型", _card_type_name(str(data.get("card_type", ""))))
	if data.has("count"):
		_add_stat("牌堆张数", str(int(data.get("count", 1))))
	if data.has("size"):
		_add_stat("占用装备格", str(int(data.get("size", 0))))
	var range_str: String = str(data.get("range", ""))
	if range_str != "" and range_str != "none":
		_add_stat("射程", _range_name(range_str))
	var charge_type: String = str(data.get("charge_type", ""))
	if charge_type != "":
		_add_stat("填充物", "%s（%d / %d）" % [
			_charge_type_name(charge_type),
			int(data.get("charge_initial", 0)),
			int(data.get("charge_max", 0)),
		])
	if int(data.get("value", 0)) != 0:
		_add_stat("数值", str(int(data.get("value", 0))))
	_add_skills_from_raw(data.get("skills", []))


func _render_scavenge_card(payload: Variant) -> void:
	var card := payload as ScavengeCardData
	if card == null:
		return
	_add_image(ImageCache.get_card_texture(card.card_name))
	_add_stat("类型", _card_type_name(card.card_type))
	if card.size > 0:
		_add_stat("占用装备格", str(card.size))
	if card.range != "" and card.range != "none":
		_add_stat("射程", _range_name(card.range))
	if card.charge_type != "":
		_add_stat("填充物", "%s（%d / %d）" % [
			_charge_type_name(card.charge_type),
			card.charge_initial,
			card.charge_max,
		])
	if card.value != 0:
		_add_stat("数值", str(card.value))
	_add_skill_list(card.skills)


func _render_skill(payload: Variant) -> void:
	_add_skill_block(payload as SkillData)


func _render_monster(payload: Variant) -> void:
	var monster := payload as MonsterCardData
	if monster == null:
		return
	_add_image(ImageCache.get_monster_texture(monster.monster_name))
	_add_stat("等级", _MONSTER_LEVEL_NAMES.get(monster.monster_level, monster.monster_level))
	_add_stat("生命值", "%d / %d" % [monster.initial_hp, monster.max_hp])
	_add_stat("攻击伤害", str(monster.attack_damage))
	_add_stat("射程", _range_name(monster.range))
	_add_stat("牌堆张数", str(monster.count))
	_add_skill_list(monster.skills)


func _render_map_block(payload: Variant) -> void:
	var block := payload as MapBlockData
	if block == null:
		return
	var colors := PackedStringArray()
	for c in block.scavenge_colors:
		colors.append(str(c))
	_add_image(ImageCache.get_block_texture(block.block_name, colors, block.monster_spawn_value))
	var color_labels: Array = []
	for c in block.scavenge_colors:
		color_labels.append(_SCAVENGE_COLOR_NAMES.get(str(c), str(c)))
	_add_stat("拾荒颜色", "、".join(color_labels) if not color_labels.is_empty() else "无")
	_add_stat("怪物生成点数", str(block.monster_spawn_value))
	if not block.variants.is_empty():
		_add_section("变体")
		for variant in block.variants:
			if not (variant is Dictionary):
				continue
			var vc: Array = variant.get("scavenge_colors", [])
			var labels: Array = []
			for c in vc:
				labels.append(_SCAVENGE_COLOR_NAMES.get(str(c), str(c)))
			_add_body("• 拾荒 %s，生成点数 %d" % [
				"、".join(labels) if not labels.is_empty() else "无",
				int(variant.get("monster_spawn_value", 0)),
			], _COLOR_DIM)
	_add_skill_list(block.skills)


func _render_mission(payload: Variant) -> void:
	var mission := payload as MissionData
	if mission == null:
		return
	_add_stat("难度", mission.difficulty_display)
	var pack: String = _MONSTER_PACK_NAMES.get(mission.monster_pack_type, mission.monster_pack_type)
	_add_stat("怪物包", pack)
	if mission.van_fuel_required != null:
		_add_stat("面包车燃料", str(mission.van_fuel_required))
	if mission.intro_text != "":
		_add_section("介绍")
		_add_body(mission.intro_text)
	if mission.objective_text != "":
		_add_section("目标")
		_add_body(mission.objective_text)
	if mission.special_setup != "":
		_add_section("特殊设置")
		_add_body(mission.special_setup)


func _render_variant(payload: Variant) -> void:
	var variant := payload as VariantData
	if variant == null:
		return
	_add_body(variant.desc if variant.desc != "" else "（无说明）")


func _add_skills_from_raw(raw: Variant) -> void:
	if not (raw is Array):
		return
	var has_any := false
	for item in raw:
		var skill: SkillData = null
		if item is SkillData:
			skill = item
		elif item is Dictionary:
			skill = SkillData.new(item)
		if skill == null:
			continue
		if not has_any:
			_add_section("效果")
			has_any = true
		_add_skill_block(skill)


func _add_skill_list(skills: Array) -> void:
	if skills.is_empty():
		return
	_add_section("效果")
	for skill in skills:
		_add_skill_block(skill as SkillData)


func _add_skill_block(skill: SkillData) -> void:
	if skill == null:
		return
	var name_text: String = skill.skill_name if skill.skill_name != "" else skill.english_name
	_add_body(name_text, _COLOR_ACCENT)
	var desc: String = skill.skill_description.strip_edges()
	_add_body(desc if desc != "" else "（无描述）")
	for sub_key in skill.sub_skills.keys():
		var sub: SkillData = skill.sub_skills[sub_key]
		if sub == null:
			continue
		var sub_name: String = sub.skill_name if sub.skill_name != "" else str(sub_key)
		var sub_desc: String = sub.skill_description.strip_edges()
		_add_body("• %s：%s" % [sub_name, sub_desc if sub_desc != "" else "（无描述）"], _COLOR_DIM)


func _add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _COLOR_ACCENT)
	_article.add_child(label)


func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", _COLOR_ACCENT)
	_article.add_child(label)


func _add_stat(label_text: String, value: String) -> void:
	var row := Label.new()
	row.text = "%s：%s" % [label_text, value]
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_font_size_override("font_size", 16)
	row.add_theme_color_override("font_color", _COLOR_TEXT)
	_article.add_child(row)


func _add_body(text: String, color: Color = _COLOR_TEXT, as_bbcode: bool = false) -> void:
	if text.strip_edges() == "":
		return
	if as_bbcode:
		_add_rich(text, color)
		return
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	_article.add_child(label)


func _add_rich(text: String, color: Color = _COLOR_TEXT) -> void:
	if text.strip_edges() == "":
		return
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.add_theme_font_size_override("normal_font_size", 15)
	rtl.add_theme_color_override("default_color", color)
	rtl.text = text
	_article.add_child(rtl)


func _add_image(tex: Texture2D) -> void:
	if tex == null:
		return
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 220)
	_article.add_child(rect)


func _range_name(range_str: String) -> String:
	return _RANGE_NAMES.get(range_str, range_str)


func _card_type_name(card_type: String) -> String:
	return _CARD_TYPE_NAMES.get(card_type, card_type if card_type != "" else "—")


func _charge_type_name(charge_type: String) -> String:
	return _CHARGE_TYPE_NAMES.get(charge_type, charge_type)
