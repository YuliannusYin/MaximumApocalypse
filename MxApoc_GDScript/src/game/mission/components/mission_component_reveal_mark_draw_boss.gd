class_name MissionComponentRevealMarkDrawBoss
extends MissionComponent

## 展示带目标标记地块抓首领触发器组件。
## 组件 id：reveal_mark_draw_boss；类别：trigger（触发器）。
## 说明：地块被展示（block_revealed 事件）时，若该地块带有未移除的目标标记
## （has_objective_mark()），展示者抓取一张首领卡；同一地块实例仅触发一次
## （组件内 Dictionary 按地块实例记录，标记被移除后再次展示也不重复触发）。
## 服务任务 7。

## 已触发过的地块实例集合（键为 MapBlock 实例，值恒 true）。
var _triggered_blocks: Dictionary = {}


func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if event_name != "block_revealed":
		return
	var block: Variant = event.get("block")
	if block == null or not is_instance_valid(block):
		return
	if not block.has_objective_mark():
		return
	if _triggered_blocks.has(block):
		return
	var player: Variant = event.get("player")
	if player == null or not is_instance_valid(player):
		return
	_triggered_blocks[block] = true
	if game != null and is_instance_valid(game):
		game.log_message(LogColors.player(player.player_name) + " 展示了带目标标记的 " + LogColors.block(block.block_name) + "，抓取一张首领牌！")
	player.draw_boss_card()
