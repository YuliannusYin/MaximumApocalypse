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
signal monster_mark_changed(block: Variant)
signal objective_mark_changed(block: Variant)

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
signal sneak_judge_triggered(player: Variant, block: Variant) ## 玩家执行潜行检定时
signal monster_spawn_judged(player: Variant, value: int) ## 怪物出生检定投骰结果出来时

# === 日志信号 ===
signal log_message(message: String)

# === 统计信号 ===
signal damage_dealt(source: Variant, target: Variant, amount: int) ## 实体造成伤害时（source 为伤害来源）
signal damage_taken(target: Variant, source: Variant, amount: int) ## 实体受到伤害时（target 为受伤者）
signal hp_recovered(player: Variant, amount: int) ## 玩家回复生命值时
signal healing_done(source: Variant, target: Variant, amount: int) ## 玩家治疗他人时（source 为治疗者，target 为被治疗者）
signal hunger_reduced(player: Variant, amount: int) ## 玩家减少饥饿值时
signal skill_used(player: Variant, skill: Variant) ## 玩家使用主动技能时
signal player_turn_started(player: Variant) ## 玩家回合开始时

# === Mark 信号 ===
signal mark_added(entity: Variant, mark: Variant)
signal mark_removed(entity: Variant, mark_name: String)
signal mark_changed(entity: Variant, mark: Variant)


## 发布日志消息（供 UI 日志面板订阅）。
func publish_log(message: String) -> void:
	log_message.emit(message)
