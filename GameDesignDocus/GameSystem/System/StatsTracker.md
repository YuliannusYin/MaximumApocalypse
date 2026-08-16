# StatsTracker 统计聚合器

> 以 `src/core/stats_tracker.gd` 为准。
> 职责：本局统计聚合器。订阅 EventBus 信号，为每个玩家维护 [PlayerStats](./PlayerStats.md)。
> 类名 `StatsTracker`，继承 `RefCounted`。由 [Game](../Game/Game.md) 持有，`_ready` 中创建。

---

## 设计意图

> 在 `Game._ready` 中通过 `StatsTracker.new()` 创建实例。构造时 `_init` 会自动连接 EventBus 上 12 个统计相关 signal。
> 在 `Game.start_game` 时调用 `reset(players)` 清空统计并为每位玩家创建 `PlayerStats`。
> 在 `Game.game_over` 时调用 `stop_timer()` 锁定本局总时长。

> 12 个订阅的 EventBus signal：
> - `damage_dealt` / `damage_taken` / `hp_recovered` / `healing_done` / `hunger_reduced`
> - `card_used` / `skill_used` / `player_turn_started` / `player_moved`
> - `card_drawn` / `scavenge_drawn` / `monster_died`

---

## 字段

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `_stats` | Dictionary | {} | 内部 `player -> PlayerStats` 映射 |
| `game_duration_msec` | int | 0 | 本局游戏总时长（毫秒） |
| `_start_time_msec` | int | 0 | 计时开始时间（毫秒）；0 表示未开始计时 |
| `_subscribed` | bool | false | 是否已订阅 EventBus 信号；`_init` 后置 true，避免重复 connect |

---

## 方法

### _init()

> 构造时若 EventBus 有效，连接 12 个统计相关 signal 并置 `_subscribed = true`。

### reset(players: Array) -> void

> 重置统计：清空 `_stats`；对 `players` 中每个玩家创建 `PlayerStats`；将 `game_duration_msec` 与 `_start_time_msec` 清零。
> 内部调用 `_ensure_subscribed()` 保证已连接 EventBus。

### get_stats(player: Variant) -> PlayerStats

> 返回指定玩家的 PlayerStats。若 `_stats` 无此玩家返回新创建的临时 `PlayerStats.new()`（不入库，调用方需自行决定是否持久化）。

### get_all_stats() -> Dictionary

> 返回内部 `_stats` 字典（`player -> PlayerStats` 映射）。

### start_timer() -> void

> 启动计时：`_start_time_msec = Time.get_ticks_msec()`。

### stop_timer() -> void

> 停止计时：若 `_start_time_msec > 0`，`game_duration_msec = Time.get_ticks_msec() - _start_time_msec`；将 `_start_time_msec` 重置为 0。

### _ensure_subscribed() -> void

> 内部方法：若未订阅且 EventBus 有效，连接 12 个统计相关 signal 并置 `_subscribed = true`。

### _on_damage_dealt(source, target, amount) -> void

> `_stats` 含 source 时调用 `get_stats(source).add_damage_dealt(amount)`。

### _on_damage_taken(target, source, amount) -> void

> `_stats` 含 target 时调用 `get_stats(target).add_damage_taken(amount)`。

### _on_hp_recovered(player, amount) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_hp_recovered(amount)`。

### _on_healing_done(source, target, amount) -> void

> `_stats` 含 source 时调用 `get_stats(source).add_healing_done(amount)`。

### _on_hunger_reduced(player, amount) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_hunger_reduced(amount)`。

### _on_card_used(player, card) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_cards_used(1)`。

### _on_skill_used(player, skill) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_skill_uses(1)`。

### _on_player_turn_started(player) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_turns_played(1)`。

### _on_player_moved(player, _src, _dst) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_moves(1)`。

### _on_card_drawn(player, _card) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_draw_count(1)`。

### _on_scavenge_drawn(player, _card) -> void

> `_stats` 含 player 时调用 `get_stats(player).add_scavenge_count(1)`。

### _on_monster_died(_monster, source) -> void

> source 非 null 且 `_stats` 含 source 时调用 `get_stats(source).add_kills(1)`。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](../Game/Game.md) | Game 持有 `stats_tracker` 实例，`_ready` 中创建 |
| [EventBus](./EventBus.md) | `_init` 时订阅 12 个统计相关 signal |
| [PlayerStats](./PlayerStats.md) | 为每位玩家维护一个 PlayerStats 实例 |
