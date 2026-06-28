# 06 - Entity 基类

> `Entity` 是 `Node` 子类，提供"有生命值的游戏对象"的公共接口（生命值 / 伤害结算 / 死亡处理 / 技能关联 / 回合钩子）。
> `Survivor extends Entity`（07-CharacterCard.md）+ `Monster extends Entity`（05-MonsterCard.md）共用此基类。
> 本文档只定义基类与方法签名，不含具体子类实现。

---

## 1. 设计原则

- **Entity 是 Node 子类**：Godot 中 Node 是游戏对象的基本单元，Entity 在其上添加生命值与技能关联。Survivor / Monster 作为 Node 可挂载到场景树，由 GameSession / TurnManager 统一调度。
- **数据 + 实体分离**：Entity 持有 `current_hp` 等运行时状态；`data`（CharacterCardData / MonsterCardData）持有定义性字段（max_hp / damage 等）。一份 data 可被多局游戏复用，每局创建独立的 Entity 实例。
- **公共接口集中**：`take_damage` / `heal` / `die` / `on_turn_start` / `on_turn_end` 等公共方法放在 Entity 基类，子类按需 override。
- **Skill 关联统一**：Entity 持有 `skill_ids: Array[StringName]`，SkillExecutor 通过此字段扫描技能（与 01-Skill.md 第 8 节对接）。
- **Entity 范围限定"有生命值的实体"**：仅 Survivor / Monster 继承 Entity。MapBlock 无生命值概念，单独继承 Node（与 v1 第 13 节"MapBlock 也继承 Entity"的描述不同，PC 版决策见第 7 节）。

---

## 2. Entity 基类

```text
class_name Entity extends Node

# === 生命值 ===
var max_hp: int                                  # 生命值上限（来自 data，初始化时设置）
var current_hp: int                              # 当前生命值（初始 = max_hp）
var is_alive: bool = true                        # 是否存活（current_hp ≤ 0 时 false）

# === 技能关联 ===
var skill_ids: Array[StringName] = []            # 关联技能 ID 列表（运行时由 SkillRegistry 查表）
                                                 # Survivor: 来自 CharacterCardData.talent_skill_ids
                                                 # Monster: 来自 MonsterCardData.skill_ids

# === 方法签名 ===

# --- 生命值 ---

# 受到伤害（触发 ON_DAMAGE_TAKEN 时机，由 SkillExecutor 调度减伤技能）
# amount 是原始伤害，source 是伤害来源（Entity）
# 通用流程见第 3 节，子类可 override 添加专属逻辑
func take_damage(amount: int, source: Entity) -> void

# 回复生命（不超过 max_hp）
# 通用流程见第 3 节
func heal(amount: int) -> void

# 死亡处理（触发 ON_DEATH 时机，子类必须 override 实现具体清理逻辑）
# source 是致死来源（用于效果结算）
# 子类 override 见第 4 节
func die(source: Entity) -> void

# --- 技能 ---

# 获取此 Entity 拥有的所有 Skill 实例（由 SkillRegistry 查表）
func get_skills() -> Array[Skill]:
    return skill_ids.map(func(id): return SkillRegistry.get_skill(id))

# --- 回合钩子（由 TurnManager 调用） ---
# owner 是当前回合玩家（与 self 可能不同，如怪物的 on_turn_end 在其纠缠玩家的回合结束时调用）
func on_turn_start(owner: Entity) -> void
func on_turn_end(owner: Entity) -> void
```

> Entity 不持有 `data` 字段——`data` 类型因子类而异（CharacterCardData / MonsterCardData），由子类自行声明。Entity 只提供运行时状态与公共接口。

---

## 3. 生命值与伤害结算

### 3.1 take_damage 通用流程

```text
take_damage(amount, source) 流程：
  1. 若 not is_alive: 返回（已死亡不再受伤）
  2. 构造 GameEvent { timing=ON_DAMAGE_TAKEN, target=self, source=source, amount=amount }
  3. SkillExecutor.dispatch(ON_DAMAGE_TAKEN, event)
     - 减伤技能在此调度（forced=true TRIGGER）：
       - 焊接头盔"受伤-1" → event.amount -= 1
       - 防弹背心"受伤-2" → event.amount -= 2 + current_durability -= 1（归零 remove）
       - 方阵机器人"范围内机器人受伤-1" → event.amount -= 1
     - 减伤技能直接修改 event.amount
  4. current_hp -= max(0, event.amount)   # 减伤后伤害不为负
  5. 若 current_hp ≤ 0:
     - current_hp = 0
     - is_alive = false
     - die(source)
```

> 不可减免的伤害（如饥饿伤害 R1）直接修改 current_hp，不经过 take_damage 流程（或 take_damage 内加 `unavoidable: bool` 参数跳过 ON_DAMAGE_TAKEN 调度，待 Q3 决定）。

### 3.2 heal 通用流程

```text
heal(amount) 流程：
  1. 若 not is_alive: 返回（已死亡不能回血）
  2. 构造 GameEvent { timing=ON_HEAL, target=self, amount=amount }
  3. SkillExecutor.dispatch(ON_HEAL, event)
     - "回复生命时额外+1"技能在此调度（手术刀/手套，forced=true TRIGGER）：
       - event.amount += 1
  4. current_hp = min(current_hp + event.amount, max_hp)
```

> `ON_HEAL` 时机待加入 01-Skill.md TriggerTiming 枚举（见 Q1）。

### 3.3 die 通用流程

```text
die(source) 流程：
  1. 若 not is_alive: 返回（防止重复死亡处理）
  2. is_alive = false
  3. 构造 GameEvent { timing=ON_DEATH, target=self, source=source }
  4. SkillExecutor.dispatch(ON_DEATH, event)   # 触发"死亡时"技能（若有）
  5. 子类 override 实现具体清理逻辑（见第 4 节）
```

> `ON_DEATH` 时机待加入 01-Skill.md TriggerTiming 枚举（见 Q2）。

---

## 4. 死亡处理（子类 override）

### 4.1 Survivor.die(source)

详见 07-CharacterCard.md 第 6 节。要点：
1. 装备卡处理（D8，按 source 区分）
2. 纠缠怪物处理（D11，置入怪物弃牌堆）
3. 手牌处理（求生者卡 remove / 拾荒卡留在地块）
4. 牌库与弃牌堆移出游戏
5. Survivor Node 延迟销毁（等死亡动画 / UI 演出）

### 4.2 Monster.die(killer)

详见 05-MonsterCard.md 第 3 节。要点：
1. 触发 ON_KILL 时机（如僵尸女王"僵尸被消灭时击杀者抓怪物卡"）
2. 解除纠缠关系（disengage）
3. 怪物卡进怪物弃牌堆（可重洗，D10）
4. Monster Node 延迟销毁（等死亡动画 / UI 演出）

---

## 5. Skill 关联

```text
Entity.skill_ids: Array[StringName]
  ↓ SkillRegistry.get_skill(skill_id) → Skill 实例
  ↓ SkillExecutor.dispatch(timing, event) 时扫描所有相关 Entity 的 skill_ids

get_skills() 实现：
  return skill_ids.map(func(id): return SkillRegistry.get_skill(id))
```

**初始化时机**：
- Survivor：GameSession 创建 Survivor 实例时，从 `CharacterCardData.talent_skill_ids` 复制到 `Entity.skill_ids`
- Monster：怪物卡被抓取创建 Monster 实例时，从 `MonsterCardData.skill_ids` 复制到 `Entity.skill_ids`

**装备卡技能的特殊处理**：
- 装备卡的技能**不**通过 Entity.skill_ids 管理（装备卡是 CardInstance，不是 Entity）
- SkillExecutor 扫描时单独遍历 `Survivor.equipment_zone`，对每个装备卡调 `card.data.skill_ids` 查表
- 这样设计的原因：装备卡会进出手牌 / 装备区，技能列表动态变化，不适合固化在 Entity.skill_ids

---

## 6. 回合钩子

```text
TurnManager 在阶段切换时调用所有相关 Entity 的钩子：

on_turn_start(owner):
  - owner 是当前回合玩家
  - Survivor override:
    - 重置 actions_remaining = 4（标准行动点）
    - 结算中毒（poison_stacks > 0 时扣血，待 Q4 决定结算时机）
    - 检查饥饿状态（若仍 is_hungry，按 hunger_damage_sequence 扣血）
  - Monster override:
    - 结算击晕到期（若 stunned_until_turn_owner == owner，解除击晕）

on_turn_end(owner):
  - owner 是当前回合玩家
  - Survivor override:
    - 按 R2 顺序结算：地块结束效果 → 饥饿+1 → 怪物攻击
  - Monster override:
    - 若 engaged_player == owner 且未击晕，调 attack()
```

> 回合钩子的具体实现细节由 TurnManager 文档（待编写）定义调度顺序与时机。

---

## 7. 与 v1 的差异：MapBlock 不继承 Entity

v1 第 13 节提到"MapBlock 等也继承 Entity"，PC 版决策**不采用**此设计：

| 维度 | v1 描述 | PC 版决策 | 理由 |
|---|---|---|---|
| MapBlock 继承 | MapBlock extends Entity | MapBlock extends Node | MapBlock 无 current_hp / take_damage / heal / die 等生命值概念 |
| MapBlock 技能 | 通过 Entity.skill_ids 管理 | MapBlock 自带 skill_ids 字段 | 字段独立，不依赖 Entity 基类 |
| SkillExecutor 扫描 | 统一扫描所有 Entity | 分两类扫描：Entity（Survivor/Monster）+ MapBlock | 略增复杂度，但语义清晰 |

> ponytail 取舍：避免 MapBlock 强制实现 take_damage / die 等无意义方法。MapBlock 的地块技能通过自身 skill_ids 字段关联 Skill，SkillExecutor 扫描时单独处理。

---

## 8. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | `ON_HEAL` 时机是否加入 01-Skill.md TriggerTiming 枚举 | **待用户决定**：手术刀/手套"回复生命时额外+1"需要此时机。候选方案 A=加入 ON_HEAL（与 ON_DAMAGE_TAKEN 对称，ECA 一致）/ B=在 heal() 内直接检查装备区（ponytail，避免新时机）。倾向 A |
| 2 | `ON_DEATH` 时机是否加入 01-Skill.md TriggerTiming 枚举 | **待用户决定**：目前无明确"死亡时"触发的技能，但预留此时机便于扩展。候选方案 A=加入 ON_DEATH（与 ON_KILL 对称）/ B=暂不加入，需要时再补。倾向 A |
| 3 | 不可减免伤害（如饥饿伤害 R1）是否经过 take_damage 流程 | **待后续决定**：候选方案 A=take_damage 加 `unavoidable: bool` 参数跳过 ON_DAMAGE_TAKEN 调度 / B=不可减免伤害直接修改 current_hp，不调 take_damage。倾向 A（统一入口，便于 UI 演出） |
| 4 | 中毒层数结算时机（回合开始 / 结束） | 沿用 07-CharacterCard.md Q3 待定 |
| 5 | Entity 是否需要 `is_alive` 字段 | **已决**：需要。`current_hp ≤ 0` 时设 false，防止重复死亡处理与已死亡实体继续受伤 |
| 6 | 同时机多技能触发顺序（priority 字段） | 沿用 01-Skill.md Q1 待定（默认按 owner 扫描顺序） |
| 7 | Entity Node 的场景树挂载方式（按玩家分组 / 按类型分组） | **待后续决定**：倾向按类型分组（`GameSession/Entities/Survivors/` + `GameSession/Entities/Monsters/`），便于 SkillExecutor 扫描 |
| 8 | 装备卡技能扫描是否需要在 Entity 基类提供通用接口 | **待后续决定**：候选方案 A=Entity 提供 `get_all_skill_sources() -> Array`（含自身 + 装备区）/ B=SkillExecutor 分别调 Entity.get_skills() + 遍历 equipment_zone。倾向 B（语义清晰，避免 Entity 知道装备区概念） |

---

## 附：决策应用索引

本文档应用的决策：
- 02-Card.md Q8 决策（怪物卡 current_hp 放 Monster Node = Entity 层）
- 07-CharacterCard.md 第 1 节（Survivor extends Entity）
- 05-MonsterCard.md 第 1 节（Monster extends Entity）
- 01-Skill.md 第 8 节（SkillExecutor 扫描所有相关对象的 skills 列表）
- R1 饥饿伤害不可减免（待 Q3 决定具体实现方式）
- R2 回合结束顺序（地块 → 饥饿 → 怪物，Survivor.on_turn_end 内结算）
