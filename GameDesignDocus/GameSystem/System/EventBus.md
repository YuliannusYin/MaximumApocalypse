# EventBus 事件总线

> 以 `src/core/event_bus.gd` 为准。
> 职责：全局事件总线，作为核心逻辑层与 UI 表现层之间的解耦通道。
> 注册为 autoload，全局名 `EventBus`，无 `class_name`，继承 `Node`。
> 核心逻辑层通过 `EventBus.<signal>.emit(...)` 通知；UI 层通过 `EventBus.<signal>.connect(...)` 订阅。

---

## 公开方法

### publish_log(message: String) -> void

> 发布日志消息（供 UI 日志面板订阅）。
> 内部直接 `log_message.emit(message)`。

---

## 信号总览

> 共 35 个 signal，按业务域分组。signal 名作为代码引用保留原样。

### 玩家类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `player_died` | `(player, source)` | 玩家死亡 |
| `player_hp_changed` | `(player, old_value: int, new_value: int)` | 玩家生命值变化。**审计发现**：声明但代码中无 `emit` 点（UI 已订阅但无发射方） |
| `player_hunger_changed` | `(player, old_value: int, new_value: int)` | 玩家饥饿值变化 |

### 卡牌类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `card_drawn` | `(player, card)` | 玩家从牌堆抓牌（含游戏牌、拾荒牌等） |
| `card_discarded` | `(player, card)` | 玩家弃置卡牌 |
| `card_used` | `(player, card)` | 玩家使用卡牌 |

### 怪物类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `monster_spawned` | `(monster, player)` | 怪物出生。**审计发现**：声明但代码中无 `emit` 点（UI 已订阅但无发射方） |
| `monster_died` | `(monster, source)` | 怪物死亡 |
| `monster_engaged_target_changed` | `(monster, old_target, new_target)` | 怪物纠缠目标变化 |

### 地图类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `block_revealed` | `(block, player)` | 地块被展示 |
| `block_destroyed` | `(block, source)` | 地块被摧毁。**审计发现**：声明但代码中无 `emit` 点（UI 已订阅但无发射方） |
| `player_moved` | `(player, source_block, target_block)` | 玩家移动 |
| `objective_mark_triggered` | `(player, block, mark)` | 目标标记触发 |
| `monster_mark_changed` | `(block)` | 怪物标记变化 |
| `objective_mark_changed` | `(block)` | 目标标记变化 |

### 游戏流程类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `game_started` | `()` | 游戏开始 |
| `game_over` | `(result: int)` | 游戏结束，result 为 `GameStateMachine.GameResult` 枚举值 |
| `turn_started` | `(player)` | 玩家回合开始 |
| `turn_ended` | `(player)` | 玩家回合结束 |

### 装备与填充物类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `equipment_equipped` | `(player, card)` | 装备被装备 |
| `equipment_unequipped` | `(player, card)` | 装备被卸下 |
| `charge_consumed` | `(player, equipment, num: int)` | 装备填充物被消耗 |

### 抓牌类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `scavenge_drawn` | `(player, card)` | 玩家抓拾荒牌 |
| `monster_card_drawn` | `(player, card)` | 玩家抓怪物卡 |

### 回合阶段类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `phase_changed` | `(player, old_phase: String, new_phase: String)` | 玩家阶段变化 |
| `action_consumed` | `(player, num: int)` | 玩家消耗行动次数。**审计发现**：声明但代码中无 `emit` 点（UI 已订阅但无发射方） |
| `sneak_judge_triggered` | `(player, block)` | 玩家执行潜行检定时 |

### 日志类

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `log_message` | `(message: String)` | 日志消息。由 `publish_log` 发射 |

### 统计类

> 供 [StatsTracker](./StatsTracker.md) 订阅聚合本局统计。

| signal 名 | 参数 | 说明 |
|-----------|------|------|
| `damage_dealt` | `(source, target, amount: int)` | 实体造成伤害（source 为伤害来源） |
| `damage_taken` | `(target, source, amount: int)` | 实体受到伤害（target 为受伤者） |
| `hp_recovered` | `(player, amount: int)` | 玩家回复生命值 |
| `healing_done` | `(source, target, amount: int)` | 玩家治疗他人（source 为治疗者，target 为被治疗者） |
| `hunger_reduced` | `(player, amount: int)` | 玩家减少饥饿值 |
| `skill_used` | `(player, skill)` | 玩家使用主动技能 |
| `player_turn_started` | `(player)` | 玩家回合开始（统计用，区别于 `turn_started`） |

---

## 审计发现：声明但未发射的信号

> 以下 4 个 signal 在 `event_bus.gd` 中已声明、UI 已订阅，但代码库中找不到对应的 `emit` 点。重写 UI 或后续补 emit 时需关注：

| signal 名 | 期望发射时机 |
|-----------|------------|
| `monster_spawned` | 怪物出生检定产生新怪物时（`Player.draw_monster` 等节点） |
| `block_destroyed` | [Game.destroy_map_block](../Game/Game.md#destroy_map_block) 流程末尾 |
| `action_consumed` | 玩家消耗行动次数时（行动阶段主动技能 / 卡牌使用） |
| `player_hp_changed` | 玩家生命值变化时（`Player.damage` / `Player.heal` 等） |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](../Game/Game.md) | `Game.log_message` 通过 `EventBus.publish_log` 推送日志 |
| [StatsTracker](./StatsTracker.md) | `_init` 时订阅 12 个统计相关 signal 聚合本局统计 |
| [EventSystem](../Core/EventSystem.md) | 核心逻辑层封装事件并触发 emit；EventBus 提供信号通道 |
