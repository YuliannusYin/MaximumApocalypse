class_name MissionComponentFirstEnterDrawBoss
extends MissionComponent

## 首次抵达指定地块抓首领触发器组件。
## 组件 id：first_enter_draw_boss；类别：trigger（触发器）。
## params：
## - block_name: String——目标地块名（如 "警察局"）
## mission_state 键：
## - first_enter_done_<block_name>: bool——该地块是否已有玩家首次抵达过（全队共享一次）
## 说明：任意玩家移动到指定地块（player_moved 事件 target_block 命中）且
## mission_state 中尚未记录时，该玩家抓取一张首领卡并记录标记键；
## 同一地块全队仅触发一次。服务任务 1（警察局）。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config


func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if event_name != "player_moved":
		return
	if _mission_config == null:
		return
	var block_name: String = params.get("block_name", "")
	if block_name == "":
		return
	var target_block: Variant = event.get("target_block")
	if target_block == null or not is_instance_valid(target_block):
		return
	if target_block.block_name != block_name:
		return
	var state_key: String = "first_enter_done_" + block_name
	if _mission_config.mission_state.get(state_key, false) == true:
		return
	var player: Variant = event.get("player")
	if player == null or not is_instance_valid(player):
		return
	_mission_config.mission_state[state_key] = true
	if game != null and is_instance_valid(game):
		game.log_message(LogColors.player(player.player_name) + " 首次抵达 " + LogColors.block(block_name) + "，抓取一张首领牌！")
	player.draw_boss_card()
