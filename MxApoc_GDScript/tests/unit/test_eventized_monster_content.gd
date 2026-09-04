extends TestBase

## 首批迁移包的防逃逸检查。旧数据允许继续使用 await player.*，
## 但已迁移的怪物包不得回退到会脱离当前操作上下文的旧调用形式。

const _MIGRATED_FILES := [
	"res://data/monsters/alien.json",
	"res://data/monsters/zombie.json",
]


func test_migrated_monster_operations_use_actions_facade() -> void:
	for path in _MIGRATED_FILES:
		var text := FileAccess.get_file_as_string(path)
		assert_false(text.contains("await target_player.remove_card"), "%s 应通过 actions 移除卡牌" % path)
		assert_false(text.contains("await drawer.remove_card"), "%s 应通过 actions 移除卡牌" % path)
		assert_false(text.contains("await event.player.draw_monster"), "%s 应通过 actions 抓怪物牌" % path)
		assert_false(text.contains("await event.source.draw_monster"), "%s 应通过 actions 抓怪物牌" % path)
		assert_false(text.contains("event.monster.change_engaged_target"), "%s 应通过 actions 修改纠缠对象" % path)
