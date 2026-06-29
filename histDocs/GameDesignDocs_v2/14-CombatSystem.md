# 14 - CombatSystem（战斗系统）

> MA 的战斗系统统一文档：射程系统 / 玩家攻击结算 / 怪物攻击结算 / 伤害计算与减免 / 中毒机制 / 击晕机制 / 潜行检定。
> 战斗系统不是一个单独的类，而是由 `CombatUtils` 静态工具类 + `Entity.take_damage` 统一入口 + `SkillExecutor` 调度减伤技能 + `TurnManager` 阶段 4c/4b.5 触发共同组成。
> 本文承接 [05-MonsterCard.md](05-MonsterCard.md) 第 10 节怪物攻击框架与 [06-Entity.md](06-Entity.md) 第 3 节 take_damage 流程，详述战斗结算细节。
> 应用决策：D23（怪物射程 NONE 定义）/ R1（饥饿伤害不可减免）/ R2（回合结束顺序）/ R3（怪物纠缠机制）。

---

## 1. 设计原则

- **战斗系统非单类**：战斗逻辑分散在 `CombatUtils`（射程判定 / 目标查询）+ `Entity.take_damage`（伤害结算统一入口）+ `SkillExecutor`（减伤调度）+ `TurnManager`（阶段触发）。不设 `CombatSystem` 类，避免空壳（ponytail YAGNI）。
- **CombatUtils 静态工具类**：射程判定、攻击范围查询、目标列表收集等无状态函数放 `CombatUtils`，与 `DiceRoller` / `DeckUtils` 风格一致（D64 同源决策）。
- **take_damage 统一入口**：所有伤害（玩家攻击 / 怪物攻击 / 中毒 / 饥饿）走 `Entity.take_damage(amount, source, unavoidable)` 入口。`unavoidable=true` 跳过 ON_DAMAGE_TAKEN 调度（解决 06-Entity Q3）。
- **减伤走 SkillExecutor 调度**：玩家与怪物受伤都触发 ON_DAMAGE_TAKEN，减伤技能（焊接头盔 / 防弹背心 / 方阵机器人）走 forced 串行修改 `event.amount`（详见 13-SkillExecutor.md 第 5 节）。
- **固定伤害不投骰**：玩家攻击与怪物攻击均固定伤害必中，不投骰。骰子仅用于怪物出生阶段与潜行检定（沿用 v1 第 1 节决策）。
- **范围攻击所有受击者独立结算**：怪物 MEDIUM/LONG 射程的范围攻击对每个受击者分别触发 take_damage，各自走 ON_DAMAGE_TAKEN 减伤（v1 Q3 决策）。

---

## 2. 射程系统（Range 枚举）

### 2.1 Range 枚举

```text
enum Range {
    NONE,    # 无射程（怪物：仅攻击纠缠玩家；玩家：不能攻击）
    SHORT,   # 短距离（1 格：当前格）
    MEDIUM,  # 中距离（5 格：当前格 + 4 邻格）
    LONG,    # 长距离（玩家 12 格 / 怪物 13 格）
}
```

### 2.2 怪物射程（以纠缠玩家所在格为中心）

| 射程 | 攻击格子 | 坐标列表（纠缠玩家所在格 = (0,0)） | 受击玩家 |
|---|---|---|---|
| `NONE` | 仅纠缠玩家所在格 | (0,0) 上的纠缠玩家 | 仅纠缠玩家 |
| `SHORT` | 当前格 | (0,0) | 该格所有玩家 |
| `MEDIUM` | 当前格 + 4 邻格 | (0,0)、(1,0)、(-1,0)、(0,1)、(0,-1) | 范围内所有玩家 |
| `LONG` | 5×5 减四角（13 格） | (0,0)、(±2,0)、(0,±2)、(±1,±1)、(±1,0)、(0,±1) | 范围内所有玩家 |

> 怪物 LONG 射程含纠缠玩家所在格（中心），共 13 格。

### 2.3 玩家射程（以玩家当前格为中心）

| 射程 | 可指定格子 | 坐标列表（玩家所在格 = (0,0)） | 说明 |
|---|---|---|---|
| `NONE` | 无 | - | 玩家无攻击能力（无武器/无攻击技能） |
| `SHORT` | 当前格 | (0,0) | 仅当前地块 |
| `MEDIUM` | 当前格 + 4 邻格 | (0,0)、(1,0)、(-1,0)、(0,1)、(0,-1) | 含当前格 |
| `LONG` | 十字 2 格 + 对角 1 格 | (±2,0)、(0,±2)、(±1,±1) | **不含当前格**（共 12 格） |

> 玩家 LONG 射程**不含当前格**，这是与怪物 LONG 射程的关键区别（怪物 LONG 含纠缠玩家所在格）。

### 2.4 目标所在格的判定

- **怪物目标**：怪物所在格 = 纠缠该怪物的玩家所在格（怪物卡不占地块，跟随纠缠玩家）
- **玩家目标**：玩家所在格 = `survivor.current_block.grid_pos`
- **跨格攻击**：玩家可攻击其他玩家面前的怪物（需在射程内）

---

## 3. CombatUtils 静态工具类

```text
class_name CombatUtils

# === 射程判定 ===

# 判断 from_pos 到 to_pos 是否在 range 射程内
# is_player: true 用玩家射程表（LONG 不含当前格），false 用怪物射程表（LONG 含中心）
static func is_in_range(from_pos: Vector2i, to_pos: Vector2i, range: Range, is_player: bool) -> bool:
    var diff = to_pos - from_pos
    match range:
        Range.NONE:
            return false if is_player else (diff == Vector2i.ZERO)
        Range.SHORT:
            return diff == Vector2i.ZERO
        Range.MEDIUM:
            return absi(diff.x) + absi(diff.y) <= 1   # 曼哈顿距离 ≤ 1
        Range.LONG:
            if is_player:
                if diff == Vector2i.ZERO:
                    return false   # 玩家 LONG 不含当前格
                # 十字 2 格 + 对角 1 格
                return (absi(diff.x) <= 2 and diff.y == 0) \
                    or (absi(diff.y) <= 2 and diff.x == 0) \
                    or (absi(diff.x) == 1 and absi(diff.y) == 1)
            else:
                # 怪物 LONG：5×5 减四角（13 格）
                return (absi(diff.x) <= 2 and absi(diff.y) <= 2) \
                    and not (absi(diff.x) == 2 and absi(diff.y) == 2)
    return false

# === 攻击范围查询 ===

# 获取怪物攻击的目标玩家列表（基于怪物射程 + 纠缠玩家位置）
# 返回范围内所有存活玩家（含纠缠玩家本人）
static func get_monster_attack_targets(monster: Monster, game_session: GameSession) -> Array[Survivor]:
    if monster.engaged_player == null:
        return []
    var center = monster.engaged_player.current_block.grid_pos
    var targets: Array[Survivor] = []
    for survivor in game_session.survivors:
        if not survivor.is_alive:
            continue
        var pos = survivor.current_block.grid_pos
        if is_in_range(center, pos, monster.data.range, false):
            targets.append(survivor)
    return targets

# 获取玩家攻击的目标怪物列表（基于武器射程 + 玩家位置）
# 返回所有在射程内的"玩家面前纠缠怪物"（含自己面前的 + 其他玩家面前的）
static func get_player_attack_targets(attacker: Survivor, weapon_range: Range, game_session: GameSession) -> Array[Monster]:
    if weapon_range == Range.NONE:
        return []
    var attacker_pos = attacker.current_block.grid_pos
    var targets: Array[Monster] = []
    for monster in game_session.get_all_monsters():
        if not monster.is_alive or monster.engaged_player == null:
            continue
        var monster_pos = monster.engaged_player.current_block.grid_pos
        if is_in_range(attacker_pos, monster_pos, weapon_range, true):
            targets.append(monster)
    return targets

# === 内部工具 ===

# 获取指定中心 + 射程的所有地块坐标（用于 UI 射程可视化）
static func _get_attack_positions(center: Vector2i, range: Range, is_player: bool) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    match range:
        Range.NONE:
            if not is_player:
                result.append(center)
        Range.SHORT:
            result.append(center)
        Range.MEDIUM:
            result.append(center)
            result.append(center + Vector2i(1, 0))
            result.append(center + Vector2i(-1, 0))
            result.append(center + Vector2i(0, 1))
            result.append(center + Vector2i(0, -1))
        Range.LONG:
            if is_player:
                # 十字 2 格 + 对角 1 格（不含当前格，共 12 格）
                for dx in [-2, -1, 0, 1, 2]:
                    for dy in [-2, -1, 0, 1, 2]:
                        if dx == 0 and dy == 0:
                            continue
                        if (absi(dx) <= 2 and dy == 0) \
                            or (absi(dy) <= 2 and dx == 0) \
                            or (absi(dx) == 1 and absi(dy) == 1):
                            result.append(center + Vector2i(dx, dy))
            else:
                # 怪物 LONG：5×5 减四角（13 格，含中心）
                for dx in [-2, -1, 0, 1, 2]:
                    for dy in [-2, -1, 0, 1, 2]:
                        if absi(dx) == 2 and absi(dy) == 2:
                            continue
                        result.append(center + Vector2i(dx, dy))
    return result
```

> CombatUtils 是无状态静态工具类，与 `DiceRoller` / `DeckUtils` 风格一致。射程判定用曼哈顿距离 + 形状匹配，避免每次扫描全图。

---

## 4. 玩家攻击结算

### 4.1 攻击流程

```text
玩家攻击流程（玩家通过 UI 选择攻击行动）：
  1. 玩家选择武器/攻击卡（消耗 1 行动点，由 try_use_active 处理）
  2. UI 高亮射程范围内可攻击的怪物（CombatUtils.get_player_attack_targets）
  3. 玩家选择目标怪物（可多选，受武器 multi_target 限制）
  4. 消耗弹药（武器 ammo_type != null 时，current_ammo -= 1）
     - 弹药不足 → try_use_active 失败，UI 提示
     - 多目标攻击只消耗 1 发弹药（v1 Q2 决策）
  5. 计算伤害 = 武器基础伤害 + 伤害修正（如游侠帽 +1、升级 +1）
  6. 对每个目标怪物分别调用 monster.take_damage(damage, attacker, unavoidable=false)
     - 走 ON_DAMAGE_TAKEN 调度，怪物的减伤天赋生效（如方阵机器人）
  7. 死亡判定由 take_damage 内部处理（current_hp <= 0 → die(attacker)）
```

### 4.2 攻击特点

| 特点 | 说明 |
|---|---|
| 必中 | 玩家攻击不投骰命中，直接造成伤害 |
| 固定伤害 | 伤害值由武器卡决定，不投骰 |
| 弹药消耗 | 有弹药类型的武器每次攻击行动消耗 1 发（多目标不增量） |
| 多目标攻击 | 部分武器/行动卡可攻击多个目标（如猎枪"面前所有目标 2 点伤害"） |
| 跨格攻击 | 玩家可攻击其他玩家面前的怪物（需在射程内） |
| 减伤生效 | 怪物的减伤天赋（方阵机器人"范围内机器人受伤 -1"）走 ON_DAMAGE_TAKEN 调度 |

### 4.3 玩家攻击的实现入口

玩家攻击通过 `SkillExecutor.try_use_active(skill_id, owner, target)` 触发（武器技能 = ACTIVE 类型）：

```text
try_use_active(weapon_attack_skill_id, attacker, target_monster) 流程：
  1. SkillRegistry.get_skill(weapon_attack_skill_id) → WeaponAttackSkill
  2. can_trigger 检查：武器装备中 + 弹药充足 + 目标在射程内
  3. spend_action(1) 扣行动点
  4. 武器 current_ammo -= 1（若有弹药）
  5. execute(event, owner=weapon_card):
     - damage = weapon.data.damage + 伤害修正
     - target_monster.take_damage(damage, attacker, unavoidable=false)
```

> 武器攻击技能的 owner 是装备卡 CardInstance（与 13-SkillExecutor.md §3.1 装备区扫描一致），execute 内通过 `event.player` 操作攻击者。

---

## 5. 怪物攻击结算

### 5.1 攻击时机

回合结束阶段（阶段 4c），按 R2 顺序结算：

```text
阶段 4 回合结束结算（R2 顺序）：
  4a. 地块结束效果（ON_TURN_END_ON_BLOCK）
  4b. 饥饿 +1（详见 15-HungerSystem.md）
  4b.5 中毒结算（详见 §8 中毒机制）
  4c. 怪物攻击（本文档）
```

> 中毒结算（4b.5）插入在饥饿后、怪物攻击前，与饥饿伤害同属"不可减免伤害"先结算，再让怪物攻击。详见第 8 节。

### 5.2 攻击流程

```text
TurnManager._step_monster_attack() 流程：
  for monster in current_player.engaged_monsters:
    if not monster.is_alive:
      continue
    if monster.is_stunned_now(current_player):
      continue   # 击晕期间不攻击
    # 1. 触发 ON_MONSTER_ATTACK 时机（用于"攻击时"天赋，如外星科学家"伤害+1"）
    var event = GameEvent.new()
    event.timing = TriggerTiming.ON_MONSTER_ATTACK
    event.source = monster
    event.player = current_player   # 被攻击的当前回合玩家
    SkillExecutor.dispatch(ON_MONSTER_ATTACK, event)
    # event.damage 可能被 forced 天赋修改（如外星科学家 +1）
    var damage = event.damage if event.damage > 0 else monster.data.damage
    # 2. 获取攻击目标（基于怪物射程）
    var targets = CombatUtils.get_monster_attack_targets(monster, game_session)
    # 3. 对每个目标分别结算
    for target in targets:
      target.take_damage(damage, monster, unavoidable=false)
    # 4. 触发 ON_DAMAGE_DEALT 时机（如僵尸潜行者"造成伤害后移动"）
    SkillExecutor.dispatch(ON_DAMAGE_DEALT, event)
```

### 5.3 攻击特点

| 特点 | 说明 |
|---|---|
| 必中 | 怪物攻击不投骰命中，直接造成伤害 |
| 固定伤害 | 伤害值由 `monster.data.damage` 字段决定，不投骰 |
| 范围攻击 | MEDIUM/LONG 射程的怪物会波及同格/邻格的其他玩家（即使不是他们的回合） |
| 攻击顺序 | 按怪物卡抓取顺序（先抓的先攻击，engaged_monsters 数组顺序） |
| 击晕跳过 | `is_stunned_now(current_player)` 返回 true 时跳过本次攻击 |
| 减伤生效 | 所有受击玩家分别触发 ON_DAMAGE_TAKEN，各自减伤装备/天赋生效 |

### 5.4 范围攻击示例

```text
僵尸喷吐者（射程 MEDIUM，伤害 2）纠缠玩家 A，玩家 A 与玩家 B 在相邻格。
回合结束（玩家 A 的回合）：
  - 喷吐者攻击，CombatUtils.get_monster_attack_targets 返回 [A, B]
  - A.take_damage(2, 喷吐者, unavoidable=false) → A 的焊接头盔减伤 -1 → 实际 1 点
  - B.take_damage(2, 喷吐者, unavoidable=false) → B 无减伤 → 实际 2 点
  - A/B 各自触发 ON_DAMAGE_TAKEN，独立结算
```

---

## 6. 伤害计算与 take_damage 统一入口

### 6.1 take_damage 签名（06-Entity.md §3.1 更新）

```text
# Entity 基类方法（06-Entity.md §2 / §3.1）
# amount: 原始伤害值
# source: 伤害来源（Entity，可为 null 如饥饿/中毒）
# unavoidable: true 时跳过 ON_DAMAGE_TAKEN 调度（饥饿/中毒等不可减免伤害）
func take_damage(amount: int, source: Entity, unavoidable: bool = false) -> void:
    if not is_alive:
        return
    var actual_amount = amount
    if not unavoidable:
        var event = GameEvent.new()
        event.timing = TriggerTiming.ON_DAMAGE_TAKEN
        event.target = self
        event.source = source
        event.amount = amount
        event.unavoidable = false
        SkillExecutor.dispatch(ON_DAMAGE_TAKEN, event)
        actual_amount = max(0, event.amount)   # 减伤不为负
    current_hp -= actual_amount
    damage_taken.emit(actual_amount, source, unavoidable)   # UI 信号
    if current_hp <= 0:
        current_hp = 0
        is_alive = false
        die(source)
```

### 6.2 unavoidable 参数的应用场景

| 伤害来源 | unavoidable | 说明 |
|---|---|---|
| 玩家攻击怪物 | `false` | 怪物的减伤天赋生效（方阵机器人） |
| 怪物攻击玩家 | `false` | 玩家的减伤装备生效（焊接头盔 / 防弹背心） |
| 饥饿伤害 | `true` | R1 不可减免，跳过调度（详见 15-HungerSystem.md） |
| 中毒伤害 | `true` | 不可减免，跳过调度（见第 8 节） |
| 任务特殊伤害 | `true` | 如任务 6 核辐射，不可减免 |

### 6.3 统一入口的优势

- **UI 演出一致**：所有伤害走 `damage_taken` 信号，UI 层统一显示伤害飘字 / 受击高亮
- **死亡判定集中**：`current_hp <= 0` 在 take_damage 内统一处理，避免遗漏
- **减伤调度可选**：`unavoidable` 参数控制是否走 ON_DAMAGE_TAKEN，语义清晰

---

## 7. 伤害减免机制

### 7.1 减伤技能的 ECA 表达

减伤技能统一用 `TRIGGER + forced=true` 表达（01-Skill.md §6.1）：

| 装备/天赋 | 减伤值 | skill_id | 时机 | 耐久 |
|---|---|---|---|---|
| 焊接头盔 | -1 | `welding_helmet_damage_reduce` | ON_DAMAGE_TAKEN | 无限 |
| 防弹背心 | -2 | `bulletproof_vest_damage_reduce` | ON_DAMAGE_TAKEN | 3 次 |
| 防火头盔 | -1 | `fireproof_helmet_damage_reduce` | ON_DAMAGE_TAKEN | 无限 |
| 方阵机器人（怪物天赋） | -1 | `phalanx_robot_aura` | ON_DAMAGE_TAKEN | - |

### 7.2 防弹背心耐久机制（02-Card.md Q2 实现）

```text
class_name BulletproofVestSkill extends TriggerSkill

func _init():
    skill_id = &"bulletproof_vest_damage_reduce"
    forced = true

func get_trigger_timings() -> Array[TriggerTiming]:
    return [TriggerTiming.ON_DAMAGE_TAKEN]

func can_trigger(event: GameEvent, owner: CardInstance) -> bool:
    # owner = 防弹背心装备卡
    # 仅持有者受伤时触发
    if event.target != owner.get_owner_player():
        return false
    # 不可减免伤害不触发（饥饿/中毒）
    if event.unavoidable:
        return false
    # 耐久 > 0 才生效
    return owner.current_durability > 0

func execute(event: GameEvent, owner: CardInstance) -> void:
    event.amount -= 2
    owner.current_durability -= 1
    if owner.current_durability <= 0:
        owner.remove()   # 耐久归零，移出游戏（隐含触发 ON_UNEQUIP）
```

### 7.3 多减伤技能串行结算

多个 forced=true 减伤技能同时触发时，按 13-SkillExecutor.md §5.2 串行修改 `event.amount`：

```text
玩家 P 装备焊接头盔（-1）+ 防弹背心（-2，耐久 1）
怪物攻击造成 5 点伤害 → take_damage(5, monster, unavoidable=false)
  → 调度 ON_DAMAGE_TAKEN
  → _collect_candidates 收集到 2 个 forced 候选（按扫描顺序）：
    1. 焊接头盔（P 装备区）
    2. 防弹背心（P 装备区）
  → 第一批串行执行：
    焊接头盔.execute → event.amount = 5 - 1 = 4
    防弹背心.execute → event.amount = 4 - 2 = 2; current_durability -= 1（归零 remove）
  → 回到 take_damage：actual_amount = max(0, 2) = 2
  → current_hp -= 2
```

### 7.4 不可减免伤害跳过调度

```text
饥饿伤害（R1 不可减免）→ take_damage(2, null, unavoidable=true)
  → 跳过 ON_DAMAGE_TAKEN 调度（焊接头盔/防弹背心均不触发）
  → actual_amount = 2
  → current_hp -= 2
  → damage_taken.emit(2, null, true)   # UI 仍显示伤害飘字
```

---

## 8. 中毒机制

### 8.1 中毒字段（07-CharacterCard.md §3 已定义）

```text
# Survivor 字段
var poison_stacks: int = 0   # 中毒层数
```

### 8.2 中毒施加

```text
# Survivor 方法
func apply_poison(stacks: int) -> void:
    if stacks <= 0:
        return
    poison_stacks += stacks
    # 触发 ON_POISON_APPLIED 时机（如装备"中毒层数减半"天赋）
    var event = GameEvent.new()
    event.timing = TriggerTiming.ON_POISON_APPLIED
    event.target = self
    event.amount = stacks
    SkillExecutor.dispatch(ON_POISON_APPLIED, event)
    poison_stacks = event.amount   # 天赋可能修改
```

### 8.3 中毒结算（回合结束 4b.5 阶段）

```text
TurnManager._step_poison_check() 流程（阶段 4b.5，饥饿后、怪物攻击前）：
  for survivor in game_session.survivors:
    if not survivor.is_alive:
      continue
    if survivor.poison_stacks <= 0:
      continue
    var damage = survivor.poison_stacks
    # 触发 ON_POISON_DAMAGE 时机（用于"中毒伤害修改"天赋，预留扩展）
    var event = GameEvent.new()
    event.timing = TriggerTiming.ON_POISON_DAMAGE
    event.target = survivor
    event.amount = damage
    event.source = null   # 中毒无来源
    SkillExecutor.dispatch(ON_POISON_DAMAGE, event)
    damage = max(0, event.amount)
    # 中毒伤害不可减免
    survivor.take_damage(damage, null, unavoidable=true)
    # 结算后清除中毒层数
    survivor.poison_stacks = 0
```

### 8.4 解毒剂使用

解毒剂（antidote.tres，红色拾荒卡）作为 ACTIVE 技能实现：

```text
class_name AntidoteSkill extends ActiveSkill

func _init():
    skill_id = &"antidote_cure_poison"
    action_cost = 1

func can_trigger(event: GameEvent, owner: CardInstance) -> bool:
    # owner = 解毒剂卡（在玩家手牌或装备区）
    var player = owner.get_owner_player()
    return player != null and player.poison_stacks > 0

func execute(event: GameEvent, owner: CardInstance) -> void:
    var player = owner.get_owner_player()
    player.poison_stacks = 0
    # 解毒剂卡使用后 discard
    owner.discard()
```

### 8.5 中毒时机汇总

| 时机 | 触发点 | 用途 |
|---|---|---|
| `ON_POISON_APPLIED` | apply_poison 调用时 | "中毒层数减半"等天赋 |
| `ON_POISON_DAMAGE` | 回合结束 4b.5 结算时 | "中毒伤害修改"等天赋（预留） |

> 两个时机需加入 01-Skill.md TriggerTiming 枚举（与 ON_HUNGER 等一起同步）。

---

## 9. 击晕机制

### 9.1 击晕字段（05-MonsterCard.md §3 已定义）

```text
# Monster 字段
var is_stunned: bool = false                    # 击晕状态
var stunned_until_turn_owner: Survivor = null   # 击晕到哪个玩家的下回合开始
```

### 9.2 击晕施加

```text
# Monster 方法
func stun(until_turn_owner: Survivor) -> void:
    is_stunned = true
    stunned_until_turn_owner = until_turn_owner
    # 触发 ON_STUN_APPLIED 时机（预留扩展）
    var event = GameEvent.new()
    event.timing = TriggerTiming.ON_STUN_APPLIED
    event.target = self
    event.source = until_turn_owner
    SkillExecutor.dispatch(ON_STUN_APPLIED, event)
```

### 9.3 击晕到期检查

```text
# Monster 方法
# current_turn_owner: 当前回合玩家
# 返回 true 表示仍在击晕中，false 表示已到期（解除击晕）
func is_stunned_now(current_turn_owner: Survivor) -> bool:
    if not is_stunned:
        return false
    # 击晕者的下回合开始时解除
    if current_turn_owner == stunned_until_turn_owner:
        is_stunned = false
        stunned_until_turn_owner = null
        # 触发 ON_STUN_EXPIRED 时机
        var event = GameEvent.new()
        event.timing = TriggerTiming.ON_STUN_EXPIRED
        event.target = self
        SkillExecutor.dispatch(ON_STUN_EXPIRED, event)
        return false   # 本回合已到期，不再算击晕
    return true
```

### 9.4 击晕机制说明

| 维度 | 说明 |
|---|---|
| 击晕者 | 施加击晕的玩家（如套索/泰瑟枪/灭火器使用者） |
| 解除时机 | 击晕者的**下回合开始**（即 `stunned_until_turn_owner` 的回合开始时） |
| 攻击跳过 | `is_stunned_now(current_player)` 返回 true 时，回合结束 4c 阶段跳过该怪物攻击 |
| 检查时机 | 回合结束 4c 阶段（_step_monster_attack 内）调用 is_stunned_now |

### 9.5 击晕典型场景

```text
玩家 A（回合 1）用套索击晕怪物 M → M.stun(until_turn_owner=A)
玩家 B（回合 2）回合结束：M.is_stunned_now(B) → B != A，仍击晕，跳过攻击
玩家 A（回合 3）回合结束：M.is_stunned_now(A) → A == A，解除击晕，M 攻击 A
```

### 9.6 击晕时机汇总

| 时机 | 触发点 | 用途 |
|---|---|---|
| `ON_STUN_APPLIED` | stun() 调用时 | "击晕时"天赋（预留） |
| `ON_STUN_EXPIRED` | is_stunned_now 解除时 | "击晕到期"天赋（预留） |

> 两个时机需加入 01-Skill.md TriggerTiming 枚举。

---

## 10. 潜行检定

### 10.1 触发条件

玩家移动进入一个地块时，若满足以下**全部**条件，必须进行潜行检定：

1. 该地块有怪物标记（`monster_tokens > 0`）
2. 玩家面前**没有任何纠缠怪物卡**（`engaged_monsters.is_empty()`）

> 若玩家面前已有怪物卡纠缠，进入有怪物标记的地块时**不需要**潜行检定（已有怪物纠缠，无法"悄悄溜走"）。

### 10.2 玩家选项

进入有怪物标记的地块且面前无怪物时，PC 版弹窗提供 2 个选项：

| 选项 | 效果 |
|---|---|
| 进行潜行检定 | 投 2 颗 D6，判定是否成功（见 10.3） |
| 跳过检定 | 直接移除该地块所有怪物标记，每移除 1 个抓 1 张怪物卡（纠缠该玩家） |

> 跳过检定是玩家的主动选择，适用于潜行成功率低或玩家想主动抓怪物卡的情况。

### 10.3 检定方式

```text
StealthCheck.perform_check(player, block) 流程：
  1. 触发 ON_STEALTH_CHECK 时机（用于"跳过检定直接抓怪物卡"天赋，如激光无人机）
     - 若天赋修改 event.skip_check = true → 跳过检定，直接抓怪物卡（与失败结果相同）
  2. 确定潜行数值
     - 正常状态（饥饿值 < 6）→ stealth_normal
     - 饥饿状态（饥饿值 ≥ 6）→ stealth_hungry
  3. 调整潜行数值
     - 调整后潜行值 = 潜行数值 - 该地块怪物标记数
  4. 投 2 颗 D6 大骰子（DiceRoller.roll_2d6()），记和为 Y
  5. 判定
     - Y ≤ 调整后潜行值 → 检定成功
     - Y > 调整后潜行值 → 检定失败
```

### 10.4 检定结果

| 结果 | 效果 |
|---|---|
| 成功 | 玩家正常进入地块，怪物标记保留 |
| 失败 | 移除该地块所有怪物标记，每移除 1 个抓 1 张怪物卡（纠缠该玩家） |

> 失败结果与"主动跳过检定"的效果相同——都是移除标记 + 抓卡。区别在于：检定失败是被动触发（玩家想潜行但失败了），跳过是主动选择。

### 10.5 检定实现

```text
class_name StealthCheck

# 执行潜行检定，返回 true=成功 false=失败
static func perform_check(player: Survivor, block: MapBlockInstance, game_session: GameSession) -> bool:
    # 1. ON_STEALTH_CHECK 时机（激光无人机等天赋）
    var event = GameEvent.new()
    event.timing = TriggerTiming.ON_STEALTH_CHECK
    event.target = player
    event.player = player
    event.card = block   # 进入的地块
    event.skip_check = false
    SkillExecutor.dispatch(ON_STEALTH_CHECK, event)
    if event.skip_check:
        _apply_failure(player, block, game_session)
        return false   # 视为检定失败（实际上是天赋跳过）
    # 2. 确定潜行数值
    var stealth_value = player.data.stealth_hungry if player.is_hungry else player.data.stealth_normal
    # 3. 调整潜行数值
    var adjusted_stealth = stealth_value - block.monster_tokens
    # 4. 投 2D6
    var roll = DiceRoller.roll_2d6()
    # 5. 判定
    var success = roll <= adjusted_stealth
    if not success:
        _apply_failure(player, block, game_session)
    return success

# 失败结果：移除所有怪物标记，每移除 1 个抓 1 张怪物卡
static func _apply_failure(player: Survivor, block: MapBlockInstance, game_session: GameSession) -> void:
    var tokens = block.monster_tokens
    block.monster_tokens = 0
    game_session.notify_monster_token_changed()
    for i in tokens:
        var card = game_session.monster_deck.draw()
        if card == null:
            DeckUtils.reshuffle_monster_discard(game_session.monster_deck, game_session.monster_discard_pile)
            card = game_session.monster_deck.draw()
        if card != null:
            # 创建 Monster Node, engage(player)（见 05-MonsterCard.md）
            pass
```

### 10.6 检定示例

```text
玩家（外科医生，stealth_normal=8）进入有 3 个怪物标记的地块：
  - 调整后潜行值 = 8 - 3 = 5
  - 投 2D6，投出 7
  - 7 > 5 → 检定失败
  - 移除该地块所有 3 个怪物标记，玩家抓 3 张怪物卡
```

---

## 11. 与其他子系统的交互

### 11.1 与 SkillExecutor 的交互

| 调用方 | 时机 | 说明 |
|---|---|---|
| `Entity.take_damage` | `ON_DAMAGE_TAKEN` | 减伤技能调度（unavoidable=true 跳过） |
| `TurnManager._step_monster_attack` | `ON_MONSTER_ATTACK` / `ON_DAMAGE_DEALT` | 怪物攻击时 / 造成伤害后 |
| `TurnManager._step_poison_check` | `ON_POISON_APPLIED` / `ON_POISON_DAMAGE` | 中毒施加 / 中毒结算 |
| `Monster.stun` / `is_stunned_now` | `ON_STUN_APPLIED` / `ON_STUN_EXPIRED` | 击晕施加 / 到期 |
| `StealthCheck.perform_check` | `ON_STEALTH_CHECK` | 潜行检定前（激光无人机跳过） |

### 11.2 与 TurnManager 的交互

```text
TurnManager 阶段 4 回合结束结算（R2 + 中毒插入）：
  4a. _step_block_end_effects()       # 地块结束效果
  4b. _step_hunger_check()            # 饥饿 +1（15-HungerSystem.md）
  4b.5. _step_poison_check()          # 中毒结算（本文档 §8）
  4c. _step_monster_attack()          # 怪物攻击（本文档 §5）
```

> 4b.5 中毒结算插入在饥饿后、怪物攻击前。这与饥饿伤害同属"不可减免伤害"先结算，让玩家血量在怪物攻击前已反映饥饿+中毒的双重损耗。

### 11.3 与 Entity / Monster / Survivor 的交互

| 调用方 | 方法 | 说明 |
|---|---|---|
| CombatUtils | `monster.data.range` | 获取怪物射程 |
| CombatUtils | `monster.engaged_player.current_block.grid_pos` | 获取怪物所在格 |
| CombatUtils | `survivor.current_block.grid_pos` | 获取玩家所在格 |
| CombatUtils | `game_session.survivors` / `get_all_monsters()` | 遍历目标 |
| StealthCheck | `player.data.stealth_normal` / `stealth_hungry` | 获取潜行值 |
| StealthCheck | `player.is_hungry` | 判断饥饿状态 |
| Monster | `stun(until_turn_owner)` | 击晕施加 |
| Survivor | `apply_poison(stacks)` | 中毒施加 |

---

## 12. 信号（UI 通知）

战斗系统的 UI 信号主要由 `Entity.damage_taken` 与各 Skill 信号驱动：

| 信号 | 来源 | 参数 | UI 用途 |
|---|---|---|---|
| `damage_taken` | Entity | actual_amount, source, unavoidable | 伤害飘字 / 受击高亮 |
| `monster_killed` | Monster.die | monster, killer | 怪物死亡动画 |
| `player_killed` | GameSession | survivor | 玩家死亡 UI |
| `monster_stunned` | Monster.stun | monster, until_turn_owner | 击晕状态显示 |
| `monster_attack_started` | TurnManager | monster, targets | 攻击高亮（红色边框） |
| `stealth_check_triggered` | StealthCheck | player, block, success_rate | 检定弹窗 |
| `stealth_check_result` | StealthCheck | player, success, roll, adjusted_stealth | 检定结果动画 |

---

## 13. 待定问题

### Q1. 玩家攻击的"伤害修正"字段

武器基础伤害 + 伤害修正（游侠帽 +1、升级 +1）的具体实现：
- 候选 A：武器 execute 内部计算 `damage = weapon.data.damage + _get_damage_modifiers(player)`
- 候选 B：用 ON_ATTACK_DECLARED 时机让修正技能修改 event.damage
- 倾向 B（ECA 一致，便于扩展）

### Q2. 多目标攻击的目标选择 UI

玩家用多目标武器（如霰弹枪"面前所有目标 2 点伤害"）攻击时：
- 候选 A：自动命中射程内所有目标（玩家无选择权）
- 候选 B：玩家从射程内选择 N 个目标
- 倾向 A（与原版"面前所有目标"语义一致）

### Q3. ON_ATTACK_DECLARED 时机

玩家攻击前是否需要独立 `ON_ATTACK_DECLARED` 时机（用于"攻击前 +1 伤害"等天赋）？
- 候选 A：加入（与 ON_MONSTER_ATTACK 对称）
- 候选 B：用 ACTIVE_USE 时机替代（武器技能 execute 内部处理）
- 倾向 A（语义清晰，便于"攻击前"天赋扩展）

### Q4. 怪物攻击同格多玩家的目标顺序

怪物 MEDIUM/LONG 射程范围内有多个玩家时，take_damage 的调用顺序：
- 候选 A：按 survivors 数组顺序（座次顺序）
- 候选 B：纠缠玩家优先，其他按座次
- 倾向 B（纠缠玩家是首要目标）

### Q5. 击晕到期与怪物攻击的时序

击晕到期检查（is_stunned_now）在 _step_monster_attack 内调用。若到期，本回合该怪物是否攻击？
- 候选 A：到期则本回合不攻击（下回合再攻击）
- 候选 B：到期则本回合立即攻击
- 倾向 A（05-MonsterCard.md Q11 决策："击晕者的下回合开始时解除"，已到期则不再算击晕，但本回合攻击阶段已在解除后，逻辑上应跳过）

> 实际上 is_stunned_now 返回 false 时（已到期），_step_monster_attack 不会跳过该怪物，会执行攻击。需确认语义。

### Q6. 解毒剂的目标选择

解毒剂使用时，若多人中毒，是否可选目标？
- 候选 A：仅自己使用（ACTION_COST=1，owner=自己）
- 候选 B：可选同地块其他玩家为目标
- 倾向 A（与原版"医疗用品治疗自己"一致，跨玩家治疗需另一类卡）

### Q7. 中毒层数上限

poison_stacks 是否有上限？某些怪物一次施加多层中毒（如突变老鼠 3 层）。
- 候选 A：无上限（实际场景罕见超 10 层）
- 候选 B：上限 6（与小骰子数量一致，UI 显示）
- 倾向 A（YAGNI）

### Q8. 范围攻击的"范围内但已死亡"玩家

怪物 MEDIUM 射程范围内有 A（纠缠）和 B（同格）。A 在本次攻击中死亡后，B 是否仍受击？
- 候选 A：是（targets 在攻击开始时收集，A 死亡不影响 B）
- 候选 B：否（A 死亡后攻击中断）
- 倾向 A（targets 已固定，独立结算）

### Q9. ON_MONSTER_ATTACK 修改 damage 的传递

外星科学家"所有外星人类怪物攻击时伤害 +1"光环，如何修改 event.damage？
- 候选 A：ON_MONSTER_ATTACK 时 forced=true 天赋修改 event.damage（需先在 event 中填 damage=monster.data.damage）
- 候选 B：怪物自身 attack 方法内检查场上有无外星科学家（耦合）
- 倾向 A（数据驱动，与 05-MonsterCard.md Q5 决策一致）

### Q10. 潜行检定的 ON_STEALTH_CHECK 与 event.skip_check

激光无人机"跳过检定直接抓怪物卡"天赋如何实现？
- 候选 A：ON_STEALTH_CHECK 时 forced=true 天赋设 event.skip_check=true（13-SkillExecutor §5 forced 串行）
- 候选 B：玩家进入地块前 UI 弹窗主动选择
- 倾向 A（自动触发，与"天赋"语义一致）

### Q11. 玩家死亡后面前怪物的处理

玩家死亡时，纠缠该玩家的怪物如何处理（D11 决策已定"进怪物弃牌堆"）？range 攻击范围内已死亡玩家是否仍算目标？
- 候选 A：玩家死亡 → is_alive=false → CombatUtils.get_monster_attack_targets 跳过（已实现）
- 候选 B：怪物攻击继续命中死亡玩家（无意义）
- 倾向 A（已隐含在 is_alive 检查中）

### Q12. 燃料/任务物品作为伤害来源

任务 6 核辐射伤害、任务 5 炸弹爆炸等"非 Entity 伤害来源"如何传 source？
- 候选 A：source = null（与饥饿/中毒一致，unavoidable=true）
- 候选 B：source = 触发地块/任务卡（需扩展 Entity 概念）
- 倾向 A（YAGNI，source=null 足够）

---

## 附：决策应用索引

本文档应用的决策：

- D23 怪物射程 NONE 定义（仅攻击纠缠玩家，§2.2）
- R1 饥饿伤害不可减免（unavoidable=true，§6.2 / §7.4）
- R2 回合结束顺序（地块→饥饿→中毒→怪物，§5.1 / §11.2）
- R3 怪物纠缠机制（攻击范围以纠缠玩家所在格为中心，§2.2 / §3）
- 用户决策：CombatUtils 静态工具类（§3）
- 用户决策：玩家攻击走 ON_DAMAGE_TAKEN 调度（§4.2 / §6.1）
- 用户决策：1 行动 1 发弹药（多目标不增量，§4.2）
- 用户决策：范围攻击附带受击触发减伤（§5.4 / §7）
- 用户决策：unavoidable 参数跳过调度（解决 06-Entity Q3，§6）
- 用户决策：中毒回合结束 4b.5 结算（解决 07-Character Q3 / 05-Monster Q9，§8.3 / §11.2）
