# Monster 怪物类

> 继承：[Entity](../Core/Entity.md)
> 职责：怪物实体的属性、纠缠对象、行动/攻击流程与死亡流程。
> 代码：`src/entities/monster.gd`，`class_name Monster extends Entity`。
> 实体化由 [MonsterCard.instantiate](Card.md#monstercard-怪物卡) 完成（复制卡面数据到 Monster 实例）。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 实体化

怪物卡从怪物牌堆抓取后，在进入玩家怪物区时**实体化**为 Monster 实例（见 [Player.draw_monster](Player.md#draw_monstern) 节点 2d）。实体化时由 `MonsterCard.instantiate(player)` 完成以下赋值：

- `monster_name = card_name`（怪物名回引卡牌名）
- `monster_type` / `monster_level` / `max_hp` / `damage_value` / `range` 从卡面复制
- `hp = max_hp`（初始化当前生命值为上限）
- `attack_target = player`（设置纠缠对象为抓取玩家）
- `monster_card = self`（回引来源怪物卡，死亡后入怪物弃牌堆用）
- 复制卡牌 `skills` 到 Monster 实例

> MonsterCard（卡面数据）与 Monster（实体）的关系见 [Card.md](Card.md#monstercard-怪物卡)。

---

## 字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `monster_name` | String | `""` | 怪物名（来自 MonsterCard.card_name）。用于日志输出 |
| `monster_type` | String | `""` | 怪物类型：`"alien"`（外星人）/ `"mutant"`（突变体）/ `"zombie"`（僵尸）/ `"robot"`（机器人）。对应不同怪物包 |
| `monster_level` | String | `"normal"` | 怪物级别：`"boss"`（首领）/ `"elite"`（精英）/ `"normal"`（普通）。影响怪物属性与技能 |
| `hp` | int | `0` | 当前生命值。≤ 0 时进入死亡流程 |
| `max_hp` | int | `0` | 最大生命值上限 |
| `damage_value` | int | `0` | 怪物攻击造成的伤害 |
| `range` | String | `"none"` | 射程：`"none"`（只攻击纠缠玩家）/ `"short"` / `"medium"` / `"long"` / `"infinity"`。决定怪物攻击范围 |
| `attack_target` | Player | `null` | 纠缠的玩家。怪物只攻击其纠缠对象所在地块的玩家（按射程） |
| `monster_card` | MonsterCard | `null` | 来源怪物卡（死亡后进入怪物弃牌堆用） |
| `stunned` | bool | `false` | 击晕状态。击晕的怪物跳过下次行动，击晕仅持续到下次行动 |
| `skills` | List\<Skill\> | — | 怪物自带技能（继承自 Entity 的 skills） |

---

## 信号量（triggers）

> 完整 trigger 列表见 [EventSystem.md](../Core/EventSystem.md)。

| trigger 名 | 触发时机 |
|-----------|---------|
| `before_monster_act` 怪物行动前 | 单个怪物行动前 |
| `on_monster_act` 怪物行动时 | 单个怪物开始行动 |
| `before_monster_attack` 怪物攻击前 | 攻击前 |
| `on_monster_attack` 怪物攻击时 | 根据射程对目标发动攻击 |
| `after_monster_attack` 怪物攻击后 | 攻击后 |
| `after_monster_act` 怪物行动后 | 单个怪物行动结束 |
| `before_monster_death` 怪物死亡前 | 怪物死亡前 |
| `on_monster_death` 怪物死亡时 | 怪物死亡时（如僵尸女王、爆破机器人、方阵机器人） |
| `after_monster_death` 怪物死亡后 | 怪物死亡后 |

> EventBus 信号：`monster_died` / `monster_engaged_target_changed`，详见 [System/EventBus.md](../System/EventBus.md)。

---

## 方法

### Entity 抽象方法实现

| 方法 | 说明 |
|------|------|
| `get_hp() -> int` | 返回当前生命值 |
| `get_max_hp() -> int` | 返回最大生命值上限 |
| `reduce_hp(n)` | 减少生命值（不低于 0） |
| `add_hp(n)` | 增加生命值（不超过 `max_hp`） |
| `is_monster() -> bool` | 是否为怪物实体（恒返回 true） |

### 修改纠缠对象

`change_engaged_target(target)`：修改怪物的纠缠对象为目标玩家。

流程：

1. 记录 `old_target = attack_target`
2. 设置 `attack_target = target`
3. 发射 EventBus `monster_engaged_target_changed` 信号，参数为 `(self, old_target, target)`

> **触发场景**：僵尸潜行者（攻击后改纠缠血量最低玩家）、枪手 / 消防员（嘲讽使怪物纠缠自己）。
>
> **`old_target` 记录**：信号发射时携带旧纠缠对象，供下游监听者对比新旧目标。
>
> **注**：技能 content 内对自身调用时用 `event.monster.change_engaged_target(target)`（`self` 在 CodeExecutor 沙箱中指 RefCounted 基类，非怪物实体）。

### 击晕

`stun(source, expire_trigger)`：设置 `stunned = true`。怪物下回合行动时清除并跳过行动。

> `expire_trigger` 由调用方语义约定（如 `"before_next_turn_start"`），实际清除由 `act()` 开头已有的 `stunned` 检查负责，故此处仅置标志。

### 行动流程

`act()`：单个怪物行动流程。触发场景：玩家回合节点 17「面前怪物行动时」（见 [02_开局与流程.md](../../GameInstructions/02_开局与流程.md)）。

**事件钩子顺序（6 节点）**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 0 | — | 击晕的怪物跳过行动：`stunned = true` 时清除并 return（击晕仅持续到下次行动） |
| 1 | `before_monster_act` | 单个怪物行动前 |
| 2 | `on_monster_act` | 怪物开始行动 |
| 3 | `before_monster_attack` | 攻击前 |
| 4 | `on_monster_attack` + `_attack()` | 根据射程对目标发动攻击（见 [§攻击流程](#攻击流程)） |
| 5 | `after_monster_attack` | 攻击后；如僵尸潜行者 |
| 6 | `after_monster_act` | 单个怪物行动结束 |

事件由 `EventSystem.create_monster_act_event(self)` 构建，所有节点 await `trigger` 串行执行。

> **注**：「怪物行动前 / 时 / 后」与玩家回合流程中的「面前怪物行动前 / 时」是不同层级的 trigger。前者是单个怪物级别，后者是玩家回合阶段级别。

### 攻击流程

`_attack()`：怪物根据射程对目标发动攻击。射程规则见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md)。

**怪物射程**（以纠缠玩家所在地块为中心）：

| 射程 | 攻击范围 |
|------|---------|
| `"none"` | 只攻击纠缠玩家，无需地块查询 |
| `"short"` | 纠缠玩家所在地块上的所有玩家（距离 0） |
| `"medium"` | 纠缠玩家所在地块 0-1 格内的所有玩家 |
| `"long"` | 纠缠玩家所在地块 0-2 格内的所有玩家（含同地块） |
| `"infinity"` | 场上所有存活玩家 |

流程：

1. `attack_target` 无效时直接返回
2. `range` 为 `"none"`：目标列表为 `[attack_target]`
3. 其他射程：取 `block = attack_target.get_current_block()`，`targets = block.get_players_in_range(range, true)`（**注意传 `for_monster=true`**，怪物长距离含同地块）
4. 对每个存活目标输出"X 攻击了 Y"日志，并对目标调用 `target.damage(damage_value, self, "monster_attack")`（伤害来源为怪物自身，伤害类型 `"monster_attack"`）

> **长距离射程修正**：怪物长距离 0-2 格含同地块，与玩家长距离 1-2 格不含同地块不同。以代码为准统一，详见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md) 与 [MapBlock.get_blocks_in_range](MapBlock.md#射程范围查询)。

### 死亡流程

`death(source)`：实现 [Entity.death](../Core/Entity.md)。流程：怪物死亡前 → 怪物死亡时（含跨怪物广播） → 怪物死亡后（移除怪物卡）。取消点：无（死亡流程不可取消）。触发场景：`entity.damage` 流程中怪物生命值 ≤ 0。

**3 节点流程**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 0 | — | 输出死亡日志（source 为玩家时输出"X 被 Y 击杀"，否则输出"X 被击杀"）；发射 EventBus `monster_died` 信号 `(self, source)` |
| 1 | `before_monster_death` | 怪物死亡前 |
| 2 | `on_monster_death` | 怪物死亡时。**含跨怪物广播**：向所有玩家怪物区中的其他存活怪物广播 `on_monster_death` 事件 |
| 3 | `after_monster_death` | 从纠缠玩家怪物区移除 + 来源怪物卡进入怪物弃牌堆 |

#### 跨怪物广播 `on_monster_death`

`on_monster_death` 节点执行后，遍历 `Game.players` 中每个玩家 `_p` 的 `monster_zone`，对每只非自身且存活的怪物 `_m` 调用 `await _m.trigger("on_monster_death", event)`。

> **设计原因**：使跨怪物监听技能（如僵尸女王）能感知到其他怪物的死亡。事件载荷与死亡怪物自身触发的 `on_monster_death` 相同，包含 `target` / `source` 等字段。

#### 节点 3 移除流程

1. 若 `attack_target` 有效且 `monster_zone` 中包含自身：`attack_target.monster_zone.erase(self)`
2. 若 `Game.monster_discard_pile` 有效：`monster_discard_pile.add(self.monster_card)`（来源怪物卡入弃牌堆）

> **注意**：地图块 / 技能效果「弃置怪物」（如 hunter 迷彩服、`Player.discard_non_boss_monster_to_mark`）为纯移除，**不**触发怪物死亡流程。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。复用 trigger / damage / death 抽象方法 |
| [Player](Player.md) | 纠缠玩家；玩家怪物区持有怪物；玩家可攻击怪物 |
| [Card](Card.md) | MonsterCard 实体化后成为 Monster 实例；`monster_card` 回引来源卡 |
| [Game](../Game/Game.md) | 怪物牌堆 / 弃牌堆由 Game 管理 |
| [EventBus](../System/EventBus.md) | 发射 `monster_died` / `monster_engaged_target_changed` 信号 |
