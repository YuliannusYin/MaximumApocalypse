# PlayerStats 单玩家统计

> 以 `src/core/player_stats.gd` 为准。
> 职责：单玩家本局统计数据结构，记录各项累计数据供结算与日志使用。
> 类名 `PlayerStats`，继承 `RefCounted`。由 [StatsTracker](./StatsTracker.md) 为每位玩家创建。

---

## 字段

> 12 个累计字段，均 int 类型默认 0。

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `damage_dealt` | int | 0 | 累计造成伤害 |
| `damage_taken` | int | 0 | 累计受到的伤害 |
| `kills` | int | 0 | 累计击杀 |
| `moves` | int | 0 | 累计移动格数 |
| `draw_count` | int | 0 | 累计摸牌次数 |
| `scavenge_count` | int | 0 | 累计拾荒次数 |
| `hunger_reduced` | int | 0 | 累计减少饥饿值 |
| `hp_recovered` | int | 0 | 累计回复生命值 |
| `healing_done` | int | 0 | 累计治疗量 |
| `cards_used` | int | 0 | 累计使用卡牌数 |
| `skill_uses` | int | 0 | 累计主动技能次数 |
| `turns_played` | int | 0 | 累计回合数 |

---

## 方法

> 12 个累加器方法，参数 `n: int = 1` 默认为 1，对相应字段做 `+= n`。

| 方法名 | 对应字段 |
|--------|---------|
| `add_damage_dealt(n = 1)` | `damage_dealt` |
| `add_damage_taken(n = 1)` | `damage_taken` |
| `add_kills(n = 1)` | `kills` |
| `add_moves(n = 1)` | `moves` |
| `add_draw_count(n = 1)` | `draw_count` |
| `add_scavenge_count(n = 1)` | `scavenge_count` |
| `add_hunger_reduced(n = 1)` | `hunger_reduced` |
| `add_hp_recovered(n = 1)` | `hp_recovered` |
| `add_healing_done(n = 1)` | `healing_done` |
| `add_cards_used(n = 1)` | `cards_used` |
| `add_skill_uses(n = 1)` | `skill_uses` |
| `add_turns_played(n = 1)` | `turns_played` |

### to_dict() -> Dictionary

> 返回包含全部 12 个字段的字典，键为字段名（字符串），值为对应 int。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [StatsTracker](./StatsTracker.md) | 由 StatsTracker 为每位玩家创建并维护 |
