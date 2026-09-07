extends TestBase

## 目标指向动画的无场景布局与安全回退测试。
const TargetLinkAnimationViewScript = preload("res://src/ui/target_link_animation_view.gd")


func test_single_monster_card_is_centered() -> void:
	var layout: Dictionary = TargetLinkAnimationViewScript.calculate_monster_row_layout(1, 1430.0)
	assert_eq(layout["total_width"], 120.0)
	assert_eq(layout["step"], 128.0)
	assert_eq(layout["origin_x"], 655.0, "单怪物卡应以画面水平中心摆放")


func test_short_monster_row_uses_normal_card_gap() -> void:
	var layout: Dictionary = TargetLinkAnimationViewScript.calculate_monster_row_layout(3, 1430.0)
	assert_eq(layout["total_width"], 376.0)
	assert_eq(layout["step"], 128.0, "未超宽的怪物牌应保留正常间距")
	assert_eq(layout["origin_x"], 527.0)


func test_wide_monster_row_overlaps_inside_max_width() -> void:
	var layout: Dictionary = TargetLinkAnimationViewScript.calculate_monster_row_layout(8, 1430.0)
	assert_eq(layout["total_width"], 780.0, "超宽怪物牌组应压缩到最大演出宽度")
	assert_lt(layout["step"], 120.0, "超宽时相邻卡牌应发生重叠")
	assert_eq(layout["origin_x"], 325.0, "压缩后牌组仍应水平居中")


func test_role_card_center_returns_zero_before_panel_is_built() -> void:
	var panel := PlayerPanel.new()
	assert_eq(panel.get_role_card_global_position(), Vector2.ZERO, "角色牌未创建时应安全返回零坐标")
	panel.free()
