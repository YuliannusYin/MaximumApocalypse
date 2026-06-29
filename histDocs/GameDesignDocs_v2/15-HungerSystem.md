# 15 - HungerSystem（饥饿系统）

> MA 的饥饿系统统一文档：饥饿值机制 / 状态切换（R1）/ 伤害序列 / 恢复途径 / 能量饮料免疫 / 野地夹克换行动 / ON_HUNGER 系列时机调度。
> 饥饿系统不是一个单独的类，而是由 `Survivor` 饥饿字段 + `Survivor.increase_hunger` / `decrease_hunger` / `check_hunger_state` 方法 + `SkillExecutor` 调度 ON_HUNGER 系列时机 + `TurnManager` 阶段 4b 触发共同组成。
> 本文承接 [07-CharacterCard.md](07-CharacterCard.md) 第 5 节饥饿字段定义与 [14-CombatSystem.md](14-CombatSystem.md) take_damage(unavoidable) 入口，详述饥饿结算细节。
> 应用决策：D13（MVP 核心饥饿功能）/ R1（饥饿状态切换 + 伤害不可减免）/ R2（回合结束顺序：地块→饥饿→怪物）。

---

## 1. 设计原则

- **饥饿系统非单类**：饥饿逻辑分散在 `Survivor`（字段 + 方法）+ `SkillExecutor`（ON_HUNGER 系列调度）+ `TurnManager`（阶段 4b 触发）+ 食物卡 Skill（恢复）+ 能量饮料 Skill（免疫拦截）。不设 `HungerSystem` 类，避免空壳（ponytail YAGNI）。
- **v1 机制为准**：v1 文档（`GameDesignDocs_v1/07-饥饿系统设计.md`）已废弃但机制沿用——每回合饥饿 +1，饥饿状态下每次 +1 扣血，序列 2/4/6/8/死亡，不可减免，退出饥饿重置序列。**07-CharacterCard.md 第 5 节注释与 v1 冲突处以本文档为准**（见第 5 节注）。
- **饥饿伤害走 unavoidable 入口**：饥饿伤害调用 `Survivor.take_damage(amount, source=HUNGER, unavoidable=true)`，跳过 ON_DAMAGE_TAKEN 减伤调度，直接扣 current_hp（与 14-CombatSystem 第 5 节 unavoidable 机制一致）。
- **食物卡 = Skill**：每张食物卡对应一个独立 Skill（ACTIVE 类型，forced=false，玩家主动打出）。复用 SkillExecutor 调度，不引入 effect_id 字段（01-Skill.md 统一原则）。
- **能量饮料 = Skill + 字段拦截**：能量饮料打出后获得 `hunger_damage_immune` 临时状态，SkillExecutor 在 ON_HUNGER_DAMAGE 调度前检查此字段，true 时跳过 take_damage 并消耗。
- **野地夹克 +1 走 increase_hunger**：野地夹克主动 +1 饥饿走标准 `increase_hunger(1)` 入口，触发完整 ON_HUNGER 系列时机（与回合 +1 一致），能量饮料也可免疫其引起的饥饿伤害。

---

## 2. 饥饿值字段与初始值

### 2.1 Survivor 字段（07-CharacterCard.md 第 3 节已定义）

```text
# === 生命与饥饿 ===
var hunger_level: int = 1                       # 当前饥饿等级（初始 1，下限 1）
var is_hungry: bool = false                       # hunger ≥ 6 时 true（R1）
var hunger_damage_sequence: int = 2               # 下次饥饿伤害值（2/4/6/8/10，10=死亡；每次扣血后 +=2，退出饥饿重置回 2）
var hunger_damage_this_turn: bool = false         # 本回合是否已进入过饥饿状态（用于"进入饥饿本回合不扣血"）
```

### 2.2 新增字段（本文档扩展）

```text
# === 饥饿免疫临时状态 ===
var hunger_damage_immune: bool = false            # 能量饮料免疫标记（true 时下次 ON_HUNGER_DAMAGE 跳过扣血并消耗）
```

> `hunger_damage_immune` 由能量饮料 Skill 设置为 true，由 SkillExecutor 在 ON_HUNGER_DAMAGE 调度前检查并消耗，由 `Survivor.on_turn_start()` 在使用者下回合开始时清除（若未消耗）。详见第 8 节。

### 2.3 字段语义补充

| 字段 | 取值范围 | 变化规则 |
|---|---|---|
| `hunger_level` | ≥ 1（下限 1） | +1（回合/野地夹克）/ -N（食物卡/绿洲/特殊效果）；低于 1 按 1 处理 |
| `is_hungry` | bool | `check_hunger_state()` 内：hunger ≥ 6 → true，hunger ≤ 5 → false |
| `hunger_damage_sequence` | 2 / 4 / 6 / 8 / 10 | 初始 2；扣血后 +=2；达 10 时下次触发死亡；退出饥饿重置回 2 |
| `hunger_damage_this_turn` | bool | 进入饥饿时置 true；`on_turn_start()` 重置为 false |
| `hunger_damage_immune` | bool | 能量饮料打出时 true；ON_HUNGER_DAMAGE 消耗时 false；下回合开始时未消耗则清除 |

---

## 3. 饥饿值变化时机

| 时机 | 变化 | 触发来源 | 走 increase/decrease？ |
|---|---|---|---|
| 回合结束阶段 4b | +1 | TurnManager 自动 | `increase_hunger(1)` |
| 野地夹克主动换行动 | +1 | 玩家主动（消防员装备） | `increase_hunger(1)` |
| 打出食物卡 | -1 ~ -5 | 玩家主动（消耗 1 行动） | `decrease_hunger(N)` |
| 食物箱卡 | 全队各 -1 或 -2 | 玩家主动（消耗 1 行动） | 每个存活玩家 `decrease_hunger(N)` |
| 绿洲地块 | -1 | ON_TURN_END_ON_BLOCK 触发 | `decrease_hunger(1)` |
| 卡牌效果（生存本能、马） | -1（全队） | 玩家主动 / ON_DISCARD 触发 | 每个存活玩家 `decrease_hunger(1)` |

### 3.1 饥饿值下限（Q1 决策）

- 饥饿值下限为 **1**（不能降到 0 以下）
- `decrease_hunger(amount)` 内部：`hunger_level = max(1, hunger_level - amount)`
- 多余恢复效果浪费（如饥饿值 2 时打出食物卡 -5，实际只降到 1）

### 3.2 食物箱"全队"范围（Q2 决策）

- 食物箱卡（小箱/大箱）的"全队饥饿 -N"仅包括**存活玩家**
- 死亡玩家不参与全队恢复（与死亡玩家不参与任何结算一致）

---

## 4. 饥饿状态切换（R1）

### 4.1 状态定义

| 状态 | 饥饿值范围 | 特征 |
|---|---|---|
| 正常状态 | 1-5 | 天赋可用，使用 `stealth_normal`，角色卡正面 |
| 饥饿状态 | ≥ 6 | 天赋禁用，使用 `stealth_hungry`，角色卡翻面（边框变红） |

### 4.2 check_hunger_state() 内部流程

```text
check_hunger_state():
    if hunger_level ≥ 6 and not is_hungry:
        # 进入饥饿状态
        is_hungry = true
        stealth = data.stealth_hungry
        hunger_damage_this_turn = true        # 本回合不扣血
        # 触发 ON_HUNGER_STATE_ENTER（用于"进入饥饿时"触发的天赋）
        SkillExecutor.dispatch(ON_HUNGER_STATE_ENTER, {owner: self})
    elif hunger_level ≤ 5 and is_hungry:
        # 退出饥饿状态
        is_hungry = false
        stealth = data.stealth_normal
        hunger_damage_sequence = 2            # 重置回 2（R1）
        # 触发 ON_HUNGER_STATE_EXIT
        SkillExecutor.dispatch(ON_HUNGER_STATE_EXIT, {owner: self})
```

> `hunger_damage_this_turn` 在 `on_turn_start()` 中重置为 false。这保证"进入饥饿的当回合不扣血，下回合开始才扣血"。

### 4.3 进入饥饿状态

当饥饿值达到 6 时（`check_hunger_state` 检测到 `hunger_level ≥ 6 and not is_hungry`）：
1. `is_hungry = true`
2. 潜行值降为 `data.stealth_hungry`（通常 -1）
3. 天赋禁用（通过 ActiveSkill/TriggerSkill 子类的 `can_trigger` 内检查 `owner.is_hungry` 实现，见 07-CharacterCard Q7）
4. `hunger_damage_this_turn = true`（本回合不扣血，R1）
5. `hunger_damage_sequence` 保持为 2（初始值或上次退出后重置的值）
6. UI 表现：角色卡翻面（边框变红 / 图标变色）
7. 触发 ON_HUNGER_STATE_ENTER 时机

### 4.4 退出饥饿状态

当饥饿值降到 5 及以下时（食物卡/绿洲/特殊效果）：
1. `is_hungry = false`
2. 潜行值恢复 `data.stealth_normal`
3. 天赋恢复
4. **`hunger_damage_sequence` 重置回 2**（R1 关键：下次重新进入饥饿从 2 重新开始）
5. UI 表现：角色卡翻回正面
6. 触发 ON_HUNGER_STATE_EXIT 时机

### 4.5 重新进入饥饿状态

退出饥饿后再次达到 6 时：按 4.3 流程处理，`hunger_damage_sequence` 从 2 重新开始（因 4.4 已重置）。

---

## 5. 饥饿伤害序列（R1）

### 5.1 序列表

饥饿状态下每次 `increase_hunger(1)` 触发扣血（除"进入饥饿本回合"外）：

| 第 N 次 +1（饥饿状态下） | 扣血量 | hunger_damage_sequence 变化 |
|---|---|---|
| 第 1 次 | 2 | 2 → 4 |
| 第 2 次 | 4 | 4 → 6 |
| 第 3 次 | 6 | 6 → 8 |
| 第 4 次 | 8 | 8 → 10 |
| 第 5 次 | 死亡 | （玩家死亡） |

### 5.2 伤害规则

- **不可减免**：饥饿伤害调用 `take_damage(amount, source=HUNGER, unavoidable=true)`，跳过 ON_DAMAGE_TAKEN 减伤调度（焊接头盔 / 防弹背心 / 方阵机器人等对饥饿伤害无效，R1）。
- **直接扣 current_hp**：unavoidable=true 路径在 Entity.take_damage 内直接 `current_hp -= amount`，不调度减伤技能。
- **死亡判定**：扣血后 `current_hp <= 0` → 玩家死亡（走 Survivor.die() 流程）。
- **第 5 次直接死亡**：`hunger_damage_sequence == 10` 时不扣血直接调用 `die()`（R1）。

### 5.3 07-CharacterCard.md 注释修正

> 07-CharacterCard.md 第 5 节"饥饿伤害序列"注释写的"第 1 次进入饥饿：受 2 点伤害，hunger_damage_sequence = 3 / 第 2 次进入：受 3 点伤害..."是**错误描述**。
>
> 正确机制（v1 + 本文档）：**饥饿状态下每次饥饿 +1 扣血**（不是"每次进入饥饿扣血"），序列 2/4/6/8/死亡（不是 2/3/4/5/...）。
>
> `hunger_damage_sequence` 字段注释"每次进入饥饿 +1"也是错误，应为"每次扣血后 +2，退出重置回 2"。
>
> 待 07-CharacterCard.md 修订时同步修正（见本文档第 15 节 Q1）。

---

## 6. increase_hunger 内部流程

### 6.1 触发顺序（Q5 决策）

```text
increase_hunger(amount):
    hunger_level += amount
    
    # 阶段 1：触发 ON_HUNGER（饥饿值变化后、状态切换前）
    # 用于野地夹克"饥饿换行动"等需要在 +1 时介入的技能
    SkillExecutor.dispatch(ON_HUNGER, {owner: self, amount: amount})
    
    # 阶段 2：状态切换检查
    old_hungry = is_hungry
    check_hunger_state()        # 内部触发 ON_HUNGER_STATE_ENTER / ON_HUNGER_STATE_EXIT
    
    # 阶段 3：饥饿伤害结算（仅在仍处于饥饿状态时）
    if is_hungry and not hunger_damage_this_turn:
        # 触发 ON_HUNGER_DAMAGE（用于能量饮料免疫拦截）
        SkillExecutor.dispatch(ON_HUNGER_DAMAGE, {owner: self, amount: hunger_damage_sequence})
        # SkillExecutor 内部检查 owner.hunger_damage_immune：
        #   - true → 跳过 take_damage，hunger_damage_immune = false（消耗）
        #   - false → 调用 take_damage(hunger_damage_sequence, HUNGER, unavoidable=true)
        #             然后 hunger_damage_sequence += 2（达 10 时下次直接 die）
```

### 6.2 ON_HUNGER_DAMAGE 调度细节

```text
SkillExecutor.dispatch(ON_HUNGER_DAMAGE, event):
    owner = event.owner
    amount = event.amount
    
    # 阶段 3a：检查能量饮料免疫（在 forced 技能调度前）
    if owner.hunger_damage_immune:
        owner.hunger_damage_immune = false    # 消耗免疫
        return                                 # 跳过扣血，但 hunger_damage_sequence 不变
    
    # 阶段 3b：forced 技能调度（如有"饥饿伤害 +1"等 forced 技能）
    # 走标准 forced 串行流程（13-SkillExecutor.md 第 5 节）
    forced_skills = get_forced_skills(ON_HUNGER_DAMAGE, owner)
    for skill in forced_skills:
        if skill.can_trigger(event, owner):
            skill.execute(event, owner)        # 可修改 event.amount
    
    # 阶段 3c：扣血结算
    if event.amount ≥ 10:
        owner.die()                            # 第 5 次直接死亡
    else:
        owner.take_damage(event.amount, HUNGER, unavoidable=true)
        owner.hunger_damage_sequence = event.amount + 2
```

### 6.3 "进入饥饿本回合不扣血"实现

- `check_hunger_state()` 进入饥饿时设置 `hunger_damage_this_turn = true`
- `increase_hunger` 阶段 3 检查 `hunger_damage_this_turn`，true 时跳过 ON_HUNGER_DAMAGE 调度
- `Survivor.on_turn_start()` 中 `hunger_damage_this_turn = false`（下回合开始可扣血）

### 6.4 流程示例

```text
玩家初始 hunger=1：
- 回合 1（结束 4b）：hunger 1→2，未饥饿，无扣血
- 回合 2：hunger 2→3，无扣血
- 回合 3：hunger 3→4，无扣血
- 回合 4：hunger 4→5，无扣血
- 回合 5：hunger 5→6
    ├─ ON_HUNGER 触发
    ├─ check_hunger_state：is_hungry=true，hunger_damage_this_turn=true
    ├─ ON_HUNGER_STATE_ENTER 触发
    └─ 阶段 3：hunger_damage_this_turn=true → 跳过 ON_HUNGER_DAMAGE
  回合 5 on_turn_end 完成。下回合开始 on_turn_start 重置 hunger_damage_this_turn=false。

- 回合 6（结束 4b）：hunger 6→7
    ├─ ON_HUNGER 触发
    ├─ check_hunger_state：仍是饥饿状态，无切换
    └─ 阶段 3：hunger_damage_this_turn=false → ON_HUNGER_DAMAGE 调度
        ├─ hunger_damage_immune=false（无能量饮料）
        ├─ take_damage(2, HUNGER, unavoidable=true) → current_hp -= 2
        └─ hunger_damage_sequence = 4

- 回合 7：hunger 7→8，扣 4 血，sequence = 6
- 回合 8：玩家打出食物卡（标准）hunger 8→5
    ├─ check_hunger_state：is_hungry=false，hunger_damage_sequence 重置回 2
    └─ ON_HUNGER_STATE_EXIT 触发

- 回合 9：hunger 5→6
    ├─ check_hunger_state：is_hungry=true，hunger_damage_this_turn=true
    └─ 跳过扣血（本回合进入饥饿）

- 回合 10：hunger 6→7，扣 2 血（sequence 从 2 重新开始）
```

---

## 7. 饥饿恢复途径

### 7.1 食物卡（绿色大类行动卡）

每张食物卡对应一个独立 Skill（ACTIVE 类型，forced=false）。打出消耗 1 行动，立即降低饥饿值。

| 卡牌 | skill_id | 效果 | 目标 |
|---|---|---|---|
| 食物（微量） | `reduce_hunger_self_1` | 自身饥饿值 -1 | owner |
| 食物（小额） | `reduce_hunger_self_2` | 自身饥饿值 -2 | owner |
| 食物（标准） | `reduce_hunger_self_3` | 自身饥饿值 -3 | owner |
| 食物（足量） | `reduce_hunger_self_4` | 自身饥饿值 -4 | owner |
| 食物（大量） | `reduce_hunger_self_5` | 自身饥饿值 -5 | owner |
| 食物（小箱） | `reduce_hunger_all_1` | 所有存活玩家饥饿值各 -1 | 所有存活玩家 |
| 食物（大箱） | `reduce_hunger_all_2` | 所有存活玩家饥饿值各 -2 | 所有存活玩家 |

#### 7.1.1 食物卡 Skill 签名

```text
# === 自身恢复型 ===
class_name ReduceHungerSelfSkill extends ActiveSkill
# skill_id: reduce_hunger_self_1 / 2 / 3 / 4 / 5
# skill_type = ACTIVE
# forced = false
@export var amount: int                          # 恢复量（1/2/3/4/5）

func can_trigger(event, owner) -> bool:
    return owner is Survivor and owner.hunger_level > 1   # 已达下限不再恢复

func execute(event, owner) -> void:
    owner.decrease_hunger(amount)                # 内部 max(1, ...) 限下限
    # 调用 check_hunger_state 由 decrease_hunger 内部触发

# === 全队恢复型 ===
class_name ReduceHungerAllSkill extends ActiveSkill
# skill_id: reduce_hunger_all_1 / 2
# skill_type = ACTIVE
# forced = false
@export var amount: int                          # 每人恢复量（1/2）

func can_trigger(event, owner) -> bool:
    return owner is Survivor

func execute(event, owner) -> void:
    var survivors = GameSession.get_alive_survivors()    # 仅存活玩家（Q2）
    for s in survivors:
        s.decrease_hunger(amount)
```

> `decrease_hunger(amount)` 内部会调用 `check_hunger_state()`，自动触发 ON_HUNGER_STATE_EXIT 时机（如退出饥饿）。

#### 7.1.2 食物卡特点

- 食物卡均为行动卡（CardType.ACTION），打出后进**绿色拾荒弃牌堆**（02-Card.md）
- 食物卡不是装备卡，不进装备区
- 食物卡消耗 1 行动点（标准行动点，非 extra_actions）
- 多余恢复浪费（如 hunger=2 时打 -5 食物卡，hunger 降到 1，多余 4 点无效）

### 7.2 绿洲地块

| 地块 | 触发时机 | 效果 |
|---|---|---|
| 绿洲（oasis） | ON_TURN_END_ON_BLOCK | 当前地块上所有玩家饥饿值 -1 |

#### 7.2.1 触发流程

```text
TurnManager 阶段 4b（回合结束地块效果）：
    对当前回合玩家所在地块：
        if block.block_type == OASIS:
            SkillExecutor.dispatch(ON_TURN_END_ON_BLOCK, {owner: player, block: block})
            # 绿洲 Skill（forced=true TRIGGER）：
            #   can_trigger: owner.current_block == oasis block
            #   execute: owner.decrease_hunger(1)
```

> ON_TURN_END_ON_BLOCK 是 01-Skill.md TriggerTiming 枚举新增时机（见第 11 节），用于绿洲、场地结束效果等地块触发。绿洲 Skill 是地块被动技能（forced=true，自动触发）。

### 7.3 特殊卡牌效果

| 卡牌 | 角色 | 类型 | 效果 | 实现 |
|---|---|---|---|---|
| 生存本能 | 猎手 | 行动卡 | 全队饥饿 -1 | ACTIVE Skill，execute 遍历存活玩家 decrease_hunger(1) |
| 马 | 猎手 | 装备卡 | ON_DISCARD 时全队饥饿 -1 | TRIGGER Skill，forced=false，ON_DISCARD 时机触发 |

> 生存本能与食物（小箱）效果相同，但是猎手专属行动卡。马是装备卡，弃置时触发全队恢复。

---

## 8. 能量饮料免疫机制

### 8.1 能量饮料卡牌

| 卡牌 | 角色 | 类型 | 效果 |
|---|---|---|---|
| 能量饮料 | 消防员 | 行动卡 | 免疫下一次饥饿伤害到下回合 + 抓 1 张牌 |

### 8.2 实现机制（Q4 + Q7 决策）

能量饮料用 `hunger_damage_immune` 字段 + SkillExecutor 检查实现，**不引入 event.cancel 机制**（ponytail YAGNI）。

```text
# 能量饮料 Skill
class_name EnergyDrinkSkill extends ActiveSkill
# skill_type = ACTIVE
# forced = false

func can_trigger(event, owner) -> bool:
    return owner is Survivor

func execute(event, owner) -> void:
    owner.hunger_damage_immune = true            # 设置免疫标记
    owner.draw_from_survivor_deck(1)             # 抓 1 张牌
```

### 8.3 免疫消耗流程

ON_HUNGER_DAMAGE 调度时（见 6.2 节）：

```text
if owner.hunger_damage_immune:
    owner.hunger_damage_immune = false           # 消耗免疫
    return                                       # 跳过 take_damage，hunger_damage_sequence 不变
```

- 免疫消耗后 `hunger_damage_sequence` **不变**（下次仍扣相同值）
- 饥饿值仍然 +1（只免疫伤害，不免疫等级增加，R1 v1 机制）

### 8.4 免疫时效（Q6 决策）

- **使用者下个回合开始时清除**：若免疫状态未被消耗，在 `Survivor.on_turn_start()` 中检查并清除
- 多人游戏中语义明确：玩家 A 打出能量饮料后，到玩家 A 的下个回合开始时清除（无论中间经过多少其他玩家回合）

```text
# Survivor.on_turn_start() 内：
func on_turn_start():
    hunger_damage_this_turn = false
    # 清除未消耗的能量饮料免疫（Q6：使用者下回合开始时清除）
    if hunger_damage_immune:
        hunger_damage_immune = false
```

### 8.5 流程示例

```text
玩家 A 饥饿状态（hunger=7，sequence=4）：
- 玩家 A 回合：打出能量饮料
    └─ hunger_damage_immune = true，抓 1 张牌

- 玩家 B 回合（结束 4b）：玩家 B 饥饿 +1（不影响玩家 A）

- 玩家 A 下回合（结束 4b）：玩家 A hunger 7→8
    ├─ ON_HUNGER 触发
    ├─ check_hunger_state：仍饥饿，无切换
    └─ ON_HUNGER_DAMAGE 调度：
        ├─ hunger_damage_immune=true → 消耗，hunger_damage_immune=false
        └─ 跳过 take_damage，hunger_damage_sequence 保持 4
    （能量饮料免疫生效，玩家 A 不扣血）

- 玩家 A 再下回合（结束 4b）：hunger 8→9
    └─ ON_HUNGER_DAMAGE：hunger_damage_immune=false → 扣 4 血，sequence=6

或：玩家 A 打出能量饮料后未在下次 +1 前进入下回合开始：
- 玩家 A 回合：打出能量饮料（hunger_damage_immune=true）
- 玩家 A 下回合开始 on_turn_start：
    └─ hunger_damage_immune=false（未消耗，清除）
```

---

## 9. 野地夹克饥饿换行动机制

### 9.1 野地夹克卡牌

| 卡牌 | 角色 | 类型 | 效果 |
|---|---|---|---|
| 野地夹克 | 消防员 | 装备卡 | 饥饿 <6 时可 +1 饥饿恢复 1 行动数（不消耗标准行动点） |

### 9.2 实现机制（Q8 决策）

野地夹克用 `extra_actions` 字段分离追踪，与 `action_points` 分开（07-CharacterCard Q2 倾向）。

```text
# 野地夹克 Skill
class_name FieldJacketSkill extends ActiveSkill
# skill_type = ACTIVE
# forced = false
# 触发条件：玩家主动激活（UI 按钮）

func can_trigger(event, owner) -> bool:
    return owner is Survivor \
        and owner.is_equipped_with("field_jacket") \
        and owner.hunger_level < 6             # 饥饿 <6 才能用

func execute(event, owner) -> void:
    owner.increase_hunger(1)                     # +1 饥饿（走标准流程，触发 ON_HUNGER 等）
    owner.extra_actions += 1                     # +1 额外行动数
```

### 9.3 行动点消耗顺序

```text
玩家执行行动时：
    if extra_actions > 0:
        extra_actions -= 1                       # 先消耗 extra_actions
    else:
        action_points -= 1                   # 再消耗 action_points
```

### 9.4 野地夹克 +1 与饥饿伤害

- 野地夹克 +1 走标准 `increase_hunger(1)`，触发完整 ON_HUNGER 系列时机
- **若 5→6**：进入饥饿状态，本回合不扣血（hunger_damage_this_turn=true）
- **若已在饥饿状态（≥6）**：野地夹克 can_trigger 返回 false（饥饿 <6 才能用），不能使用
- **能量饮料免疫**：若玩家有 hunger_damage_immune，野地夹克 +1 引起的扣血也会被免疫

### 9.5 流程示例

```text
玩家 A hunger=4，装备野地夹克：
- 玩家 A 回合行动 1：消耗 1 action_points（标准行动点）
- 玩家 A 主动激活野地夹克：
    ├─ can_trigger: hunger=4 <6 → true
    ├─ increase_hunger(1): hunger 4→5
    │    ├─ ON_HUNGER 触发
    │    ├─ check_hunger_state: hunger=5 未达 6，无切换
    │    └─ 阶段 3：is_hungry=false → 跳过扣血
    └─ extra_actions += 1
- 玩家 A 回合行动 2：消耗 1 extra_actions（野地夹克恢复的）
- 玩家 A 回合行动 3：消耗 1 action_points
- 玩家 A 主动激活野地夹克：
    ├─ can_trigger: hunger=5 <6 → true
    ├─ increase_hunger(1): hunger 5→6
    │    ├─ ON_HUNGER 触发
    │    ├─ check_hunger_state: is_hungry=true, hunger_damage_this_turn=true
    │    ├─ ON_HUNGER_STATE_ENTER 触发
    │    └─ 阶段 3：hunger_damage_this_turn=true → 跳过扣血
    └─ extra_actions += 1
- 玩家 A 回合行动 4：消耗 1 extra_actions
- 玩家 A 主动激活野地夹克：
    └─ can_trigger: is_hungry=true, hunger=6 ≥6 → false（饥饿状态不能用）
```

---

## 10. 饥饿对角色的影响

### 10.1 天赋禁用

饥饿状态下（`is_hungry == true`），角色天赋禁用：

- 天赋是 `data.talent_skill_ids` 列表关联的 Skill 实例（07-CharacterCard 第 2 节）
- ActiveSkill / TriggerSkill 子类的 `can_trigger` 内检查：

```text
func can_trigger(event, owner) -> bool:
    if owner is Survivor and owner.is_hungry:
        return false                            # 饥饿状态下天赋禁用
    # 其他条件检查...
```

- SkillExecutor 在调度前调用 `skill.can_trigger`，返回 false 时跳过该 Skill
- 饥饿状态下天赋完全不可用（ACTIVE 不能主动打出，TRIGGER 不能自动触发）

### 10.2 潜行值降低

| 状态 | 使用的潜行值 | 影响 |
|---|---|---|
| 正常状态（hunger 1-5） | `data.stealth_normal` | 潜行检定使用较高值 |
| 饥饿状态（hunger ≥ 6） | `data.stealth_hungry` | 潜行检定使用较低值（通常 -1） |

- `check_hunger_state()` 切换状态时同步更新 Survivor 的当前潜行值
- 潜行检定机制见 [14-CombatSystem.md](14-CombatSystem.md) 第 8 节

### 10.3 MVP 5 角色的潜行值

| 角色 | stealth_normal | stealth_hungry | 差值 |
|---|---|---|---|
| 外科医生 | 8 | 7 | -1 |
| 机械师 | 8 | 7 | -1 |
| 猎手 | 9 | 8 | -1 |
| 消防员 | 6 | 5 | -1 |
| 枪手 | 7 | 6 | -1 |

> 所有角色饥饿状态潜行值均 -1（D15 MVP 5 角色）。

---

## 11. ON_HUNGER 系列时机与 SkillExecutor 调度

### 11.1 新增 TriggerTiming 枚举（Q4 决策）

01-Skill.md 的 TriggerTiming 枚举新增以下时机：

```text
enum TriggerTiming {
    # ... 既有时机 ...
    ON_HUNGER,                 # 饥饿值 +1 后、状态切换前（用于"饥饿变化时"介入的技能）
    ON_HUNGER_STATE_ENTER,     # 进入饥饿状态（is_hungry: false → true）
    ON_HUNGER_STATE_EXIT,      # 退出饥饿状态（is_hungry: true → false）
    ON_HUNGER_DAMAGE,          # 饥饿伤害扣血前（用于能量饮料免疫拦截）
    ON_TURN_END_ON_BLOCK,      # 玩家所在地块的回合结束效果（用于绿洲等地块被动）
}
```

### 11.2 时机触发顺序

| 时机 | 触发条件 | 用途 |
|---|---|---|
| ON_HUNGER | `increase_hunger` 内 `hunger_level += amount` 后 | 野地夹克等需要在 +1 时介入的技能（实际野地夹克是 ACTIVE 主动技能，不走此时机；预留扩展） |
| ON_HUNGER_STATE_ENTER | `check_hunger_state` 内进入饥饿时 | "进入饥饿时"触发的天赋（暂无 MVP 角色，预留） |
| ON_HUNGER_STATE_EXIT | `check_hunger_state` 内退出饥饿时 | "退出饥饿时"触发的天赋（暂无 MVP 角色，预留） |
| ON_HUNGER_DAMAGE | `increase_hunger` 阶段 3 仍饥饿且需扣血时 | 能量饮料免疫拦截 + forced 饥饿伤害修改技能（暂无） |
| ON_TURN_END_ON_BLOCK | TurnManager 阶段 4b 玩家所在地块 | 绿洲 -1 饥饿 + 其他地块结束效果 |

### 11.3 SkillExecutor 调度规则

- **ON_HUNGER**：forced 串行调度（13-SkillExecutor 第 5 节），无可选技能（暂无 forced=false 的 ON_HUNGER 技能）
- **ON_HUNGER_STATE_ENTER / EXIT**：forced 串行调度
- **ON_HUNGER_DAMAGE**：先检查 `hunger_damage_immune`（字段拦截），再 forced 串行调度（可修改 event.amount），最后扣血结算（见 6.2 节）
- **ON_TURN_END_ON_BLOCK**：地块被动 Skill（forced=true）串行调度

### 11.4 与 13-SkillExecutor 的接口

HungerSystem 不直接调用 SkillExecutor.dispatch，而是由 `Survivor.increase_hunger` / `check_hunger_state` / TurnManager 阶段 4b 调用。所有调度走标准 SkillExecutor 入口（13-SkillExecutor.md 第 4 节）。

---

## 12. 与其他子系统的交互

### 12.1 与 TurnManager（12-TurnManager.md）

- **阶段 4b（回合结束地块效果）**：触发 ON_TURN_END_ON_BLOCK（绿洲 -1 饥饿）
- **阶段 4b 后**：调用 `survivor.increase_hunger(1)`（每回合 +1，R2 顺序：地块→饥饿→怪物）
- **阶段 4c**：怪物攻击（14-CombatSystem 第 6 节）
- **on_turn_start**：重置 `hunger_damage_this_turn = false` + 清除未消耗的 `hunger_damage_immune`

> R2 回合结束顺序：地块效果 → 饥饿 +1 → 怪物攻击。饥饿 +1 在地块之后、怪物之前，保证绿洲 -1 可能在饥饿 +1 前让玩家退出饥饿。

### 12.2 与 CombatSystem（14-CombatSystem.md）

- **take_damage 入口共用**：饥饿伤害走 `take_damage(amount, source=HUNGER, unavoidable=true)`，跳过 ON_DAMAGE_TAKEN 减伤调度（14-CombatSystem 第 5 节 unavoidable 机制）
- **source 标识**：HUNGER 是新增的 DamageSource 枚举值（与 MONSTER / PLAYER 并列），用于 ON_DEATH 时判定死因
- **死亡判定共用**：饥饿伤害扣血后 `current_hp <= 0` 走标准 `Survivor.die()` 流程（07-CharacterCard 第 6 节）
- **第 5 次直接死亡**：`hunger_damage_sequence == 10` 时直接调用 `die()`，不扣血

### 12.3 与 SkillExecutor（13-SkillExecutor.md）

- **调度入口**：`SkillExecutor.dispatch(timing, event)` 标准接口
- **forced 优先**：ON_HUNGER 系列时机目前所有相关技能均为 forced=true，走 forced 串行流程
- **能量饮料特殊处理**：ON_HUNGER_DAMAGE 调度前 SkillExecutor 检查 `owner.hunger_damage_immune`，true 时直接跳过 forced 调度与扣血（13-SkillExecutor 需扩展此特殊检查，见第 15 节 Q3）

### 12.4 与 CardSystem（02-Card.md）

- **食物卡打出**：玩家打出食物卡 → CardInstance.play → 触发食物卡 Skill（ACTIVE）→ execute 调用 `owner.decrease_hunger(amount)`
- **能量饮料打出**：同上，Skill 设置 `hunger_damage_immune = true` + draw(1)
- **马（装备卡）ON_DISCARD**：弃置时触发全队 -1 Skill
- **野地夹克（装备卡）ON_EQUIP**：装备后玩家获得主动激活技能（UI 按钮）

### 12.5 与 MapBlock（09-MapBlock.md）

- **绿洲地块**：block_type == OASIS，地块被动 Skill 监听 ON_TURN_END_ON_BLOCK
- **玩家所在地块查询**：`survivor.current_block` 用于 ON_TURN_END_ON_BLOCK 触发判定

---

## 13. 信号（UI 通知）

Survivor 发出信号，UI 层监听更新：

```text
# === 饥饿相关信号 ===
signal hunger_changed(new_hunger: int)                  # 饥饿值变化（UI 数字更新）
signal hunger_state_changed(is_hungry: bool)            # 饥饿状态切换（角色卡翻面动画）
signal hunger_damage_taken(amount: int)                 # 饥饿伤害扣血（红色飘字 + 震动）
signal hunger_damage_sequence_changed(seq: int)         # 序列变化（序列条更新）
signal hunger_immune_changed(immune: bool)              # 免疫状态变化（能量饮料图标显示）
signal hunger_damage_immune_consumed()                  # 免疫被消耗（图标消失动画）
```

### 13.1 信号触发时机

| 信号 | 触发时机 |
|---|---|
| hunger_changed | `hunger_level` 变化时（increase/decrease 内 emit） |
| hunger_state_changed | `is_hungry` 变化时（check_hunger_state 内 emit） |
| hunger_damage_taken | ON_HUNGER_DAMAGE 扣血成功后 emit（免疫消耗时不 emit） |
| hunger_damage_sequence_changed | `hunger_damage_sequence` 变化时（扣血后 / 退出饥饿重置时） |
| hunger_immune_changed | `hunger_damage_immune` 变化时（设置 / 消耗 / 清除） |
| hunger_damage_immune_consumed | 免疫被消耗时（hunger_damage_immune: true → false 且发生在 ON_HUNGER_DAMAGE） |

---

## 14. MVP 范围（D13）

MVP 阶段实现的饥饿功能：

| 功能 | MVP 状态 | 说明 |
|---|---|---|
| 饥饿值 +1（回合结束） | ✅ | TurnManager 阶段 4b 后调用 increase_hunger(1) |
| 饥饿值下限 1 | ✅ | decrease_hunger 内 max(1, ...) |
| 饥饿状态切换（R1） | ✅ | check_hunger_state + ON_HUNGER_STATE_ENTER/EXIT |
| 饥饿伤害序列 2/4/6/8/死亡 | ✅ | hunger_damage_sequence + ON_HUNGER_DAMAGE + unavoidable 入口 |
| 进入饥饿本回合不扣血 | ✅ | hunger_damage_this_turn 标记 |
| 7 种食物卡恢复 | ✅ | 每张食物卡一个 ACTIVE Skill |
| 食物箱仅存活玩家 | ✅ | GameSession.get_alive_survivors() |
| 绿洲地块 -1 | ✅ | ON_TURN_END_ON_BLOCK + 地块被动 Skill |
| 能量饮料免疫 | ✅ | hunger_damage_immune 字段 + SkillExecutor 检查 |
| 野地夹克换行动 | ✅ | extra_actions 字段分离追踪 |
| 天赋禁用 | ✅ | can_trigger 内检查 is_hungry |
| 潜行值降低 | ✅ | check_hunger_state 切换 stealth_normal/hungry |
| 饥饿 UI | ✅ | 信号驱动（饥饿值 / 序列条 / 翻面动画） |

---

## 15. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | 07-CharacterCard.md 第 5 节"饥饿伤害序列"注释与 v1 冲突 | **已决**：以本文档第 5 节为准（v1 机制：每回合 +1 扣血，序列 2/4/6/8/死亡）。待 07-CharacterCard.md 修订时同步修正注释（hunger_damage_sequence 字段注释 + 第 5 节流程描述） |
| 2 | ON_HUNGER 时机目前无 MVP 技能使用，是否预留 | **已决**：预留（TriggerTiming 枚举加入）。野地夹克是 ACTIVE 主动技能不走此时机，但预留用于未来扩展（如"饥饿 +1 时触发"的 forced 天赋） |
| 3 | SkillExecutor 是否需要为 ON_HUNGER_DAMAGE 特殊处理 hunger_damage_immune 检查 | **已决**：是。13-SkillExecutor.md 需补充：ON_HUNGER_DAMAGE 调度前先检查 `owner.hunger_damage_immune`，true 时跳过 forced 调度与扣血，消耗标记。待 13-SkillExecutor.md 修订时同步 |
| 4 | 野地夹克 UI 激活按钮的显示条件 | 倾向：装备野地夹克 + hunger <6 + 当前是自己的回合 → 显示按钮。具体 UI 设计待后期 |
| 5 | 食物卡多余恢复是否触发 ON_HUNGER_STATE_EXIT | **已决**：是。decrease_hunger 内调用 check_hunger_state，若退出饥饿则触发 ON_HUNGER_STATE_EXIT（即使恢复量超过当前饥饿值，按 max(1, ...) 处理后仍检查状态） |
| 6 | 能量饮料打出后立即生效还是下回合开始生效 | 倾向立即生效（打出后 hunger_damage_immune=true，下次 ON_HUNGER_DAMAGE 即可消耗）。待确认 |
| 7 | hunger_damage_sequence == 10 直接 die() 还是扣 10 血后判定 | **已决**：直接 die()。第 5 次 +1 触发时不扣血直接调用 die()（R1 v1 机制"第 5 次死亡"） |
| 8 | ON_HUNGER_STATE_ENTER / EXIT 是否需要 event 参数 | 倾向：ENTER 携带 `{owner, old_hunger, new_hunger}`，EXIT 携带 `{owner, old_hunger, new_hunger}`。待 SkillExecutor event 标准化时确认 |

---

## 附：决策应用索引

本文档应用的决策：

- **D13** MVP 最小可玩闭环（核心饥饿功能）
- **R1** 饥饿状态切换 + 伤害不可减免（达 6 翻面不扣血，序列 2/4/6/8/死亡，不可减免，退出重置）
- **R2** 回合结束效果触发顺序（地块 → 饥饿 → 怪物）

本文档记录的饥饿系统详细设计决策（编号待与 00-总览与设计决策.md 统一，当前临时编号 H1-H13，避免与现有 D83-D95 冲突）：

- **H1** 饥饿值下限为 1（多余恢复浪费）
- **H2** 食物箱"全队"范围仅包括存活玩家
- **H3** 食物卡 = Skill（每张食物卡一个 ACTIVE Skill，forced=false）
- **H4** 饥饿相关 TriggerTiming 新增 4 个：ON_HUNGER / ON_HUNGER_STATE_ENTER / ON_HUNGER_STATE_EXIT / ON_HUNGER_DAMAGE
- **H5** 能量饮料免疫用 `hunger_damage_immune` 字段 + SkillExecutor 在 ON_HUNGER_DAMAGE 调度前检查（不引入 event.cancel）
- **H6** 能量饮料时效：使用者下个回合开始时清除未消耗的免疫
- **H7** 野地夹克 +1 走标准 increase_hunger（触发完整 ON_HUNGER 系列时机）
- **H8** 野地夹克恢复的行动数用 `extra_actions` 字段分离追踪，消耗顺序：先 extra_actions 后 action_points
- **H9** 绿洲等地块结束效果用 ON_TURN_END_ON_BLOCK 时机（TriggerTiming 枚举新增）
- **H10** 饥饿伤害走 `take_damage(amount, HUNGER, unavoidable=true)` 入口（跳过 ON_DAMAGE_TAKEN 减伤调度）
- **H11** "进入饥饿本回合不扣血"用 `hunger_damage_this_turn` 标记实现（on_turn_start 重置）
- **H12** increase_hunger 内部触发顺序：ON_HUNGER → check_hunger_state（含 ON_HUNGER_STATE_ENTER/EXIT）→ ON_HUNGER_DAMAGE
- **H13** hunger_damage_sequence 字段语义：值=2/4/6/8/10（10=死亡），扣血后 +=2，退出饥饿重置回 2（修正 07-CharacterCard.md 注释）
