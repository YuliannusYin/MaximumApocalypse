# 01 - Skill 系统

> MA 的核心机制抽象：所有"触发时机 + 条件 + 效果"形态的能力统一用 Skill 类表达。
> 设计参照三国杀 ECA（Event-Condition-Action）模式，适配 Godot 4.7 + GDScript。
> 应用范围：角色天赋、装备卡技能、怪物卡技能、地块技能（沿用 v1 决策 D24）。
> 本文档只定义基类与方法签名，不含具体技能实现。

---

## 1. 设计原则

- **ECA 三段式**：trigger（时机）→ filter（条件）→ content（动作）
- **数据 + 逻辑分离**：Skill 是抽象 Resource 子类（.gd 逻辑）；卡牌/角色/地块的 .tres 数据里只存 `skill_ids: Array[StringName]`，运行时由 SkillRegistry 查表
- **规则集中 + UI 信号**：SkillExecutor 在各时机点扫描已注册 Skill 调用 filter/execute；状态变更通过信号驱动 UI
- **owner 显式传入**：filter/execute 第二参数为技能拥有者（解决"装备技能给本人用"等问题）
- **forced 锁定技标记**：`forced: bool` 字段标记 TRIGGER 技能是否强制发动。`forced=true` 时 can_trigger 通过后 SkillExecutor 直接调 execute（玩家不能拒绝，对应三国杀"锁定技"）；`forced=false` 时弹窗询问玩家"是否触发"。统一了 v1 中"被动技/触发技"的二分

---

## 2. SkillType 枚举

```text
enum SkillType {
    TRIGGER,   # 触发技：trigger/filter/execute 模式（含 forced=true 锁定技与 forced=false 可选触发）
    ACTIVE,    # 主动技：行动阶段消耗行动点主动使用（消防员"拳打"、外科医生"缝合"）
    DISCARD,   # 弃牌技：玩家主动弃此卡才触发（梯子、伪装）
}
```

> MA 不需要三国杀的视为技 / 距离技 / 禁止技。
> 持续型被动（焊接头盔"受伤-1"、背包"+1 装备栏"）统一用 `TRIGGER + forced=true` 表达，不再单设 PASSIVE 类型（见 6.1 节）。

---

## 3. TriggerTiming 枚举

```text
enum TriggerTiming {
    # 回合阶段
    ON_GAME_START,         # 游戏开始时
    ON_TURN_START,         # 回合开始时
    ON_TURN_END,           # 回合结束时

    # 抓牌
    ON_CARD_DRAWN,         # 求生者抓牌时（求生者牌库 / 拾荒牌堆）
    ON_MONSTER_DRAWN,      # 抓怪物卡时

    # 战斗
    ON_DAMAGE_DEALT,       # 造成伤害时
    ON_DAMAGE_TAKEN,       # 受到伤害时
    ON_HUNGER_DAMAGE,      # 受饥饿伤害时
    ON_KILL,               # 杀死怪物时
    ON_MONSTER_ATTACK,     # 怪物攻击时（怪物回合结束攻击纠缠玩家前触发，用于"攻击时"天赋如外星科学家"伤害+1"）
    ON_TARGET_SELECT,      # 选择目标时（D85：外星飞船强制拦截短距离目标）

    # 装备
    ON_EQUIP,              # 装备进入装备区时
    ON_UNEQUIP,            # 装备离开装备区时

    # 卡牌生命周期
    ON_DISCARD,            # 卡牌进弃牌堆时
    ON_REMOVE,             # 卡牌移出游戏时（D7 remove）

    # 地图
    ON_SCAVENGE,           # 拾荒时
    ON_MOVE,               # 玩家移动时（进入/离开地块）
    ON_STEALTH_CHECK,      # 潜行检定时（玩家进入有怪物标记的地块时触发，用于激光无人机"跳过检定直接抓怪物卡"等天赋）

    # 主动入口
    ACTIVE_USE,            # 玩家主动使用 ACTIVE 技能
    ON_DISCARD_CHOICE,     # 玩家主动弃置以触发 DISCARD 技能
}
```

> 此枚举随具体技能录入逐步扩展。

---

## 4. GameEvent 类

```text
class_name GameEvent extends RefCounted

var timing: TriggerTiming       # 触发时机
var source: Entity              # 触发来源（造成伤害的来源、抓牌的玩家等）
var target: Entity              # 目标（受击者、被攻击怪物等）
var player: Survivor            # 当前回合玩家
var card: Card                  # 相关卡牌（可空）
var amount: int                 # 数量 / 伤害值
var extra: Dictionary           # 灵活扩展字段
```

> `source` / `target` / `player` 职责区分：
> - `player`：当前回合玩家，通常是技能作用主体
> - `source`：动作发出方（如攻击者）
> - `target`：动作承受方（如被攻击者）
> - 三者可重合（玩家自己抓牌：player = source = target）

---

## 5. Skill 抽象基类

```text
class_name Skill extends Resource

# === 数据字段（可 .tres 序列化） ===
@export var skill_id: StringName        # 唯一标识，跨对象引用
@export var display_name: String        # UI 显示名
@export var description: String         # UI 描述（自然语言）
@export var skill_type: SkillType       # 技能类型
@export var forced: bool = false        # 锁定技标记（仅对 TRIGGER 有意义）：
                                        #   true  = can_trigger 通过后强制 execute（玩家不可拒绝，对应三国杀"锁定技"）
                                        #   false = can_trigger 通过后弹窗询问玩家是否发动

# === ECA 三段式（子类 override） ===

# E：触发时机列表（ACTIVE/DISCARD 可返回空数组，由调度器按默认时机注入）
func get_trigger_timings() -> Array[TriggerTiming]:
    return []

# C：是否可以触发 / 使用
# - TRIGGER：时机匹配后由 SkillExecutor 调用
# - ACTIVE/DISCARD：玩家点击使用时由 SkillExecutor 调用
# owner = 技能拥有者（角色 / 装备卡 / 地块 / 怪物）
func can_trigger(event: GameEvent, owner: Entity) -> bool:
    return false

# A：执行效果
# 在此调用 owner.draw(x, pile)、target.take_damage(amount, source) 等词汇表方法
# owner 参数同上
func execute(event: GameEvent, owner: Entity) -> void:
    pass
```

---

## 6. Skill 三大子类（仅签名差异说明）

```text
class_name TriggerSkill extends Skill
# skill_type = TRIGGER
# override get_trigger_timings() + can_trigger() + execute()
# 由 SkillExecutor.dispatch(timing, event) 在各时机点扫描调用
# forced=true  → 锁定技：can_trigger 通过后强制 execute
# forced=false → 可选触发：can_trigger 通过后弹窗询问玩家

class_name ActiveSkill extends Skill
# skill_type = ACTIVE
# override can_trigger()（玩家点击时检查可用性）+ execute()
# get_trigger_timings() 默认返回 [ACTIVE_USE]
# 通常消耗行动点：@export var action_cost: int = 1

class_name DiscardSkill extends Skill
# skill_type = DISCARD
# override can_trigger()（玩家选弃此卡时检查）+ execute()
# get_trigger_timings() 默认返回 [ON_DISCARD_CHOICE]
# execute 内部由 SkillExecutor 自动弃置 owner 卡（若 owner 是装备卡）
```

---

## 6.1 持续型被动 vs 事件型被动（统一用 TRIGGER + forced=true）

v1 中"被动技/触发技"的二分在 PC 版统一为：**所有被动均用 `TRIGGER + forced=true` 表达**，不再单设 PASSIVE 类型。区分仅在 `get_trigger_timings()` 与 `execute()` 内部分支。

### 事件型被动（单时机）

焊接头盔"受伤 -1"：

```text
class_name WeldingHelmetSkill extends TriggerSkill
func _init():
    skill_id = &"welding_helmet_damage_reduce"
    forced = true
func get_trigger_timings() -> Array[TriggerTiming]:
    return [ON_DAMAGE_TAKEN]
func can_trigger(event, owner) -> bool:
    return event.target == owner and event.amount > 0
func execute(event, owner) -> void:
    event.amount -= 1   # 直接修改事件对象，由调用方按修改后的 amount 结算
```

### 持续型被动（双时机 + 分支）

背包"+1 装备栏"：

```text
class_name BackpackSkill extends TriggerSkill
func _init():
    skill_id = &"backpack_add_slot"
    forced = true
func get_trigger_timings() -> Array[TriggerTiming]:
    return [ON_EQUIP, ON_UNEQUIP]
func can_trigger(event, owner) -> bool:
    return event.card == owner   # 仅本装备进出装备区时触发
func execute(event, owner) -> void:
    if event.timing == ON_EQUIP:
        event.player.increase_equipment_slot_capacity(1)
    elif event.timing == ON_UNEQUIP:
        event.player.decrease_equipment_slot_capacity(1)
```

### 关键约束

- **forced=true 仍过 can_trigger**：与三国杀锁定技一致。can_trigger 返回 false 时不发动
- **持续型被动必须双时机对称**：ON_EQUIP 加上去的属性必须在 ON_UNEQUIP 减回来
- **remove 隐含 ON_UNEQUIP**：装备被 `remove()` 移出游戏时，Card 生命周期需保证先触发 ON_UNEQUIP 再 remove（待 Card 基类设计时定义）

---

## 7. SkillRegistry（autoload 单例）

```text
class_name SkillRegistry extends Node

# 启动时扫描所有 Skill 子类 .gd 文件并实例化注册
# 表：skill_id -> Skill 实例

func get_skill(skill_id: StringName) -> Skill
func get_skills_by_owner(owner: Entity) -> Array[Skill]
    # 通过 owner.skill_ids 查表返回 Skill 实例列表
```

---

## 8. SkillExecutor（规则集中调度）

```text
class_name SkillExecutor extends Node

# 在各时机点由 TurnManager / GameSession 调用
func dispatch(timing: TriggerTiming, event: GameEvent) -> void:
    # 1. 收集所有已注册 Skill
    # 2. 对每个 skill：
    #    - 若 skill.skill_type == TRIGGER 且 timing ∈ skill.get_trigger_timings()
    #    - 找出该 skill 的所有 owner（拥有此 skill_id 的 Entity）
    #    - 调 skill.can_trigger(event, owner) == true 入队
    # 3. 队列按优先级排序（默认按 owner 扫描顺序；必要时加 priority 字段）
    # 4. 依次处理队列：
    #    - 若 skill.forced == true ：直接调 execute（锁定技，玩家不可拒绝）
    #    - 若 skill.forced == false：弹窗询问玩家"是否发动"，Yes 才调 execute
    # 5. execute 内部修改状态 + emit UI 信号

# 玩家点击主动技时调用
func try_use_active(skill_id: StringName, owner: Entity, event: GameEvent) -> bool:
    # 1. 检查 owner 是否拥有此 skill
    # 2. 调 can_trigger(event, owner)，false 则返回 false
    # 3. 扣行动点（若 skill.action_cost > 0）
    # 4. 调 execute(event, owner)
    # 5. 返回 true

# 玩家选弃此卡以触发弃牌技时调用
func try_use_discard(skill_id: StringName, owner: Entity, event: GameEvent) -> bool:
    # 1. 检查 owner 是否拥有此 skill 且 skill.skill_type == DISCARD
    # 2. 调 can_trigger(event, owner)，false 则返回 false
    # 3. 弃置 owner 卡（若 owner 是 Card）
    # 4. 调 execute(event, owner)
    # 5. 返回 true
```

---

## 9. 调用链示意

```text
TurnManager 阶段切换
    └─> SkillExecutor.dispatch(timing, event)
            ├─> 扫描所有 TRIGGER 类 Skill
            ├─> 对每个 owner 调 can_trigger(event, owner)
            ├─> 通过的入队、排序
            └─> 依次 execute(event, owner)
                    └─> 调用 owner.draw() / target.take_damage() 等"词汇表"方法
                            └─> 修改状态 + emit UI 信号
```

> 词汇表方法（draw / take_damage / discard / remove / equip / move / ...）将在
> 后续 Survivor / Card / Monster / MapBlock 等基类文档中定义。

---

## 10. 待定问题（写具体技能时再决）

| # | 问题 | 临时方案 |
|---|---|---|
| 1 | 同时机多技能触发顺序 | 默认按 owner 扫描顺序；必要时加 `priority: int` 字段 |
| 2 | 装备卡作为 owner 时，owner 是 Card 还是 Survivor | 倾向 owner = Card（装备卡本身），execute 内通过 `event.player` 操作 Survivor |
| 3 | 主动技 action_cost 是字段还是方法 | 暂定字段 `action_cost: int = 1`，复杂场景改方法 |
| 4 | 装备离开装备区时 ON_UNEQUIP 与 ON_DISCARD 时序 | 待 Card 基类设计时定义生命周期 |
| 5 | 技能间互相触发（A 的 execute 触发 B 的时机）是否允许递归 | 暂定允许，SkillExecutor 维护调用栈深度上限防死循环 |
| 6 | forced=false 时的 UI 询问超时/默认行为 | 待 UI 设计层定义（默认 No，还是默认 Yes） |
| 7 | 持续型被动对称触发的健壮性（如装备被 remove 而非 unequip） | 待 Card 基类生命周期设计时保证：remove 隐含触发 ON_UNEQUIP |
| 8 | forced=true 锁定技在 can_trigger 失败时是否给玩家提示 | 倾向不提示（与三国杀锁定技一致，静默不发动） |
| 9 | 多个 forced=true 锁定技同时修改同一事件（如多张减伤卡） | 按 owner 扫描顺序串行修改 event 对象，最终一次性结算 |
