extends TestBase

## WikiIndex：规则 JSON 与 DataManager 图鉴能否组成目录。

const WikiIndex = preload("res://src/ui/wiki_index.gd")


func test_wiki_index_loads_rule_articles() -> void:
	var index = WikiIndex.new()
	var overview: Dictionary = index.get_entry("rules.overview")
	assert_eq(str(overview.get("kind", "")), WikiIndex.KIND_RULE)
	assert_eq(str(overview.get("title", "")), "游戏概述")
	assert_true(str(overview.get("body", "")).length() > 20, "概述正文不应为空")


func test_wiki_index_includes_catalog_entries() -> void:
	var index = WikiIndex.new()
	assert_eq(str(index.get_entry("cat.survivors").get("kind", "")), WikiIndex.KIND_CATEGORY)
	var firefighter: Dictionary = index.get_entry("survivor.firefighter")
	assert_false(firefighter.is_empty(), "应有消防员条目")
	assert_not_null(firefighter.get("payload"))
	var mission0: Dictionary = index.get_entry("mission.0")
	assert_false(mission0.is_empty(), "应有任务 0 条目")
	assert_true(index.get_root_nodes().size() >= 8, "应有规则与图鉴各大类")


func test_wiki_overlay_scene_instantiates() -> void:
	var packed: PackedScene = load("res://scenes/WikiOverlay.tscn")
	assert_not_null(packed)
	var overlay: Node = packed.instantiate()
	add_child_autofree(overlay)
	assert_true(overlay is Control)
	assert_not_null(overlay.get_node("Margin/Panel/VBox/Split/Tree"))
