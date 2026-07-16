extends Node

## EventBus 全局事件总线（autoload）。
## 供 UI 层订阅游戏事件，解耦核心逻辑与表现层。
## 核心逻辑层通过 EventBus.emit_signal 通知 UI；UI 通过 EventBus.connect 订阅。

# === 玩家相关信号 ===
signal player_died(player: Variant, source: Variant)
signal player_hp_changed(player: Variant, old_value: int, new_value: int)
signal player_hunger_changed(player: Variant, old_value: int, new_value: int)

# === 卡牌相关信号 ===
signal card_drawn(player: Variant, card: Variant)
signal card_discarded(player: Variant, card: Variant)
signal card_used(player: Variant, card: Variant)

# === 怪物相关信号 ===
signal monster_spawned(monster: Variant, player: Variant)
signal monster_died(monster: Variant, source: Variant)
signal monster_engaged_target_changed(monster: Variant, old_target: Variant, new_target: Variant)

# === 地图相关信号 ===
signal block_revealed(block: Variant, player: Variant)
signal block_destroyed(block: Variant, source: Variant)
signal player_moved(player: Variant, source_block: Variant, target_block: Variant)
signal objective_mark_triggered(player: Variant, block: Variant, mark: Variant)

# === 游戏流程信号 ===
signal game_started()
signal game_over(result: int)
signal turn_started(player: Variant)
signal turn_ended(player: Variant)

# === 装备与填充物信号 ===
signal equipment_equipped(player: Variant, card: Variant)
signal equipment_unequipped(player: Variant, card: Variant)
signal charge_consumed(player: Variant, equipment: Variant, num: int)

# === 卡牌抽取信号 ===
signal scavenge_drawn(player: Variant, card: Variant)
signal monster_card_drawn(player: Variant, card: Variant)

# === 回合阶段信号 ===
signal phase_changed(player: Variant, old_phase: String, new_phase: String)
signal action_consumed(player: Variant, num: int)

# === 日志信号 ===
signal log_message(message: String)


## 发布日志消息（供 UI 日志面板订阅）。
func publish_log(message: String) -> void:
	log_message.emit(message)
