class_name MissionComponentDefuseBomb
extends MissionComponent

## 消耗行动解除炸弹的行动选项组件。
## 组件 id：defuse_bomb；类别：action（行动选项）。
## params：
## - block_name: String（默认 "电厂"）——炸弹所在地块名
## - cost: int（默认 2）——解除消耗的行动数
## - card_name: String（默认 "满是灰尘的日记本"）——解除所需的情报卡名（持有即可，不消耗）
## - countdown: int（默认 3）——声明用参数：倒计时轮数实际由 turn_countdown 组件的 rounds 配置
## mission_state 键：
## - bomb_defused: bool——炸弹是否已解除（setup 时缺省 false）
## - countdown_activate: true——写入后由 turn_countdown 组件在下一个转发事件中
##   激活倒计时并清除该标记键（见 MissionComponentTurnCountdown）
## 行动选项仅在玩家位于炸弹地块、持有情报卡（手牌或装备区）、行动数充足
## 且未解除时出现；执行后扣减行动并置 bomb_defused / countdown_activate。
## 服务任务 5。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config
	if not params.has("block_name"):
		params["block_name"] = "电厂"
	if not params.has("cost"):
		params["cost"] = 2
	if not params.has("card_name"):
		params["card_name"] = "满是灰尘的日记本"
	if not params.has("countdown"):
		params["countdown"] = 3
	if _mission_config == null:
		return
	if not _mission_config.mission_state.has("bomb_defused"):
		_mission_config.mission_state["bomb_defused"] = false


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if _mission_config == null:
		return []
	if _mission_config.mission_state.get("bomb_defused", false) == true:
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if player.current_block.block_name != params.get("block_name", "电厂"):
		return []
	if not player.has_item(params.get("card_name", "满是灰尘的日记本")):
		return []
	var cost: int = int(params.get("cost", 2))
	if player.action_count < cost:
		return []
	return [{
		"id": "defuse_bomb",
		"label": "消耗 %d 行动解除炸弹" % cost,
		"execute": _do_defuse.bind(game, player),
	}]


## 解除执行：扣减行动并置 bomb_defused 与倒计时激活标记。
func _do_defuse(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if _mission_config == null:
		return
	var cost: int = int(params.get("cost", 2))
	player.reduce_action_count(cost)
	_mission_config.mission_state["bomb_defused"] = true
	_mission_config.mission_state["countdown_activate"] = true
	game.log_message(LogColors.player(player.player_name) + " 炸弹已解除！倒计时开始！")
