extends GutTest

## LogColors 工具类单元测试。


# === 1. 颜色常量 ===

func test_color_constants() -> void:
	assert_eq(LogColors.PLAYER, "#73d0ff")
	assert_eq(LogColors.MONSTER, "#ff7b7b")
	assert_eq(LogColors.CARD, "#d299ff")
	assert_eq(LogColors.SKILL, "#ffd370")
	assert_eq(LogColors.BLOCK, "#88dd88")
	assert_eq(LogColors.TEXT, "#cccccc")
	assert_eq(LogColors.BG, "#1E2228")


# === 2. player 方法 ===

func test_player() -> void:
	assert_eq(LogColors.player("消防员"), "[color=#73d0ff]\"消防员\"[/color]")


func test_player_empty() -> void:
	assert_eq(LogColors.player(""), "[color=#73d0ff]\"\"[/color]")


# === 3. monster 方法 ===

func test_monster() -> void:
	assert_eq(LogColors.monster("僵尸女王"), "[color=#ff7b7b]\"僵尸女王\"[/color]")


# === 4. card 方法 ===

func test_card() -> void:
	assert_eq(LogColors.card("急救包"), "[color=#d299ff]\"急救包\"[/color]")


# === 5. skill 方法 ===

func test_skill() -> void:
	assert_eq(LogColors.skill("潜行检定"), "[color=#ffd370]\"潜行检定\"[/color]")


# === 6. block 方法 ===

func test_block() -> void:
	assert_eq(LogColors.block("医院"), "[color=#88dd88]\"医院\"[/color]")


# === 7. skill_by_type 方法 ===

func test_skill_by_type_block() -> void:
	assert_eq(LogColors.skill_by_type("避难所技能", "block"), "[color=#88dd88]\"避难所技能\"[/color]")


func test_skill_by_type_monster() -> void:
	assert_eq(LogColors.skill_by_type("僵尸技能", "monster"), "[color=#ff7b7b]\"僵尸技能\"[/color]")


func test_skill_by_type_other() -> void:
	assert_eq(LogColors.skill_by_type("装备技能", "装备"), "[color=#d299ff]\"装备技能\"[/color]")


func test_skill_by_type_empty() -> void:
	assert_eq(LogColors.skill_by_type("默认技能", ""), "[color=#d299ff]\"默认技能\"[/color]")
