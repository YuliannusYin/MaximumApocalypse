# 07 - CharacterCard 与 Survivor Entity

> 求生者角色牌 = `CharacterCardData`（Resource，角色定义）+ `Survivor`（Node，运行时实体）。
> 沿用 v1 决策"数据 = Resource / 实体 = Node"，与 `MonsterCardData → Monster Node` 关系一致（02-Card.md Q8 决策）。
> 应用 v1 决策：D6（装备栏容量默认 4 / 狗 0）、D8（死亡后装备按来源处理）、D11（纠缠怪物处理）、D15（MVP 5 角色）、R1（饥饿状态切换）、R3（怪物纠缠）、D80（行动中生成并装备的卡牌 source = SURVIVOR_DECK）、D82（枪手"搜索尸体"跨色随机拾荒）。
> 本文档只定义基类与方法签名，不含具体角色数据（firefighter/surgeon 等见原版角色包）。

---

## 1. 设计原则

- **数据 + 实体分离**：`CharacterCardData`（Resource）存角色定义性字段（character_id / max_hp / stealth / 天赋 / 牌库构成）；`Survivor`（Node）存运行时状态（current_hp / equipment_zone / hand / deck 等）。一份 `CharacterCardData` 可被多局游戏复用，每局游戏创建独立的 `Survivor` 实例。
- **Entity 基类**：`Survivor extends Entity`，`Entity` 是 `Node` 子类（定义公共接口 `take_damage` / `heal` / `die` 等，见 06-Entity.md）。`Monster` 继承 `Entity`；`MapBlock` 无生命值概念，不继承 `Entity`（D47，见 06-Entity.md 第 7 节）。
- **天赋 = Skill**：角色天赋统一用 `talent_skill_ids: Array[StringName]` 关联 `Skill` 实例（沿用 01-Skill.md），运行时由 `SkillRegistry` 查表。饥饿状态下天赋禁用（R1）通过 `can_trigger` 内检查 `is_hungry` 实现。
- **装备栏容量动态**：`equipment_slot_capacity` 是基础值（来自 `CharacterCardData`），实际容量受持续型被动影响（背包"+1 装备栏"通过 `increase_equipment_slot_capacity()` / `decrease_equipment_slot_capacity()` 修改，与 01-Skill.md 6.1 节对接）。
- **牌库 ID 引用**：`CharacterCardData.survivor_deck_card_ids` 只存卡牌 ID 列表（含重复 ID 表示多份），运行时由 `CardRegistry` 查表实例化 `CardInstance`（数据 + 逻辑分离）。

---

## 2. CharacterCardData（Resource，角色定义）

```text
class_name CharacterCardData extends CardData
# card_type = CardType.CHARACTER
# source = CardSource.MISSION（角色卡由任务/游戏系统发出，不进任何牌堆）

# === 角色身份 ===
@export var character_id: StringName              # 角色唯一标识（如 &"firefighter"）
@export var character_name: String                # UI 显示名（如 "消防员"）
@export var description: String                   # 角色介绍（UI 用）

# === 属性 ===
@export var max_hp: int                           # 生命值上限
@export var stealth_normal: int                   # 正常状态潜行值
@export var stealth_hungry: int                   # 饥饿状态潜行值
@export var equipment_slot_capacity: int = 4      # 装备栏基础容量（默认 4，狗为 0，D6）

# === 天赋 ===
@export var talent_skill_ids: Array[StringName] = []  # 天赋技能 ID 列表（通常 1 个，预留扩展）

# === 求生者牌库构成 ===
@export var survivor_deck_card_ids: Array[StringName] = []  # 牌库卡牌 ID 列表（含重复 ID 表示多份，运行时由 CardRegistry 实例化）
```

> CharacterCardData 不直接持有 `Skill` 实例或 `CardData` 实例，只存 ID 引用。运行时由 `SkillRegistry` / `CardRegistry` 查表返回实例（数据 + 逻辑分离）。

---

## 3. Survivor Entity（Node，运行时实体）

```text
class_name Survivor extends Entity
# Entity 是 Node 子类，提供 take_damage/heal/die 等公共接口（待 Entity 基类设计文档定义）

# === 引用角色定义 ===
var data: CharacterCardData                       # 引用不可变的角色卡数据

# === 生命与饥饿 ===
var current_hp: int
var hunger_level: int = 1                         # 初始饥饿等级 1
var is_hungry: bool = false                       # hunger ≥ 6 时 true（R1）
var hunger_damage_sequence: int = 2               # 下次饥饿伤害值（2/4/6/8/10，10=死亡；每次扣血后 +=2，退出饥饿重置回 2，详见 15-HungerSystem.md）
var hunger_damage_this_turn: bool = false         # 本回合是否已受饥饿伤害（用于"进入饥饿本回合不扣血"）

# === 状态效果 ===
var poison_stacks: int = 0                        # 中毒层数
var stunned_monsters: Array[Monster] = []         # 被击晕的怪物列表（临时状态）

# === 纠缠怪物 ===
var engaged_monsters: Array[Monster] = []         # 当前纠缠该玩家的怪物（R3，见 05-MonsterCard.md）

# === 装备区 ===
var equipment_zone: Array[CardInstance] = []      # 装备区（已装备卡列表）
var _equipment_slot_bonus: int = 0                # 装备栏容量加成（背包等持续型被动修改）

# === 手牌与牌库 ===
var hand: Array[CardInstance] = []                # 手牌（上限 10）
var deck: Array[CardInstance] = []                # 求生者牌库（运行时实例化）
var discard_pile: Array[CardInstance] = []        # 求生者弃牌堆

# === 位置 ===
var current_block: MapBlockInstance               # 当前所在地块（见 09-MapBlock.md）

# === 行动点 ===
var action_points: int = 0                        # 本回合剩余标准行动点（D81）
var extra_actions: int = 0                        # 额外行动数（如野地夹克恢复的，与标准行动点分开追踪）

# === 方法签名 ===

# --- 抓牌 ---
# 从求生者牌库抓 n 张到手牌
# 牌库空时玩家被淘汰（D10）
func draw_from_survivor_deck(n: int) -> void

# 从拾荒牌堆抓 n 张到手牌（拾荒卡来源 = SCAVENGER_DECK）
# pile_color: RED/BLUE/GREEN 三色牌堆标识
func draw_from_scavenger_deck(n: int, pile_color: DeckColor) -> void

# --- 生命 ---
# 受到伤害（触发 ON_DAMAGE_TAKEN 时机，由 SkillExecutor 调度减伤技能）
# amount 已经过减伤结算，source 是伤害来源（Monster/Survivor 等）
func take_damage(amount: int, source: Entity) -> void

# 回复生命（不超过 max_hp）
func heal(amount: int) -> void

# --- 饥饿 ---
func increase_hunger(amount: int) -> void
func decrease_hunger(amount: int) -> void
# 检查并切换 is_hungry 状态（R1）：
#   hunger ≥ 6 → is_hungry = true，stealth = stealth_hungry，天赋禁用
#   hunger ≤ 5 → is_hungry = false，stealth = stealth_normal，天赋恢复，hunger_damage_sequence 重置回 2
func check_hunger_state() -> void

# --- 装备 ---
# 装备卡进入装备区（调 card.equip(self)，由 CardInstance 内部检查容量）
# 返回 false 表示装备栏已满（调用方弹窗让玩家选 discard 谁）
func equip(card: CardInstance) -> bool

# 卸下装备（调 card.unequip()，触发 ON_UNEQUIP）
func unequip(card: CardInstance) -> void

# 获取实际装备栏容量（基础值 + 持续型被动加成）
func get_equipment_capacity() -> int

# 获取已用装备栏格数（∑ equipment_zone[i].data.size）
func get_equipment_used() -> int

# 持续型被动调用（背包"+1 装备栏"用，与 01-Skill.md 6.1 节对接）
func increase_equipment_slot_capacity(n: int) -> void
func decrease_equipment_slot_capacity(n: int) -> void

# --- 手牌 ---
# 加入手牌（返回 false 表示手牌已满，上限 10）
func add_to_hand(card: CardInstance) -> bool

# 从手牌弃置（调 card.discard(pile)）
func discard_from_hand(card: CardInstance, pile: Variant) -> void

# --- 移动 ---
# 移动到目标地块（触发 ON_MOVE 时机，可能触发地块效果）
func move_to(target_block: MapBlockInstance) -> void

# --- 拾荒 ---
# 从地块关联的拾荒牌堆抓 1 张（pile_color 来自 MapBlockInstance.get_scavenger_piles()）
func scavenge(pile_color: DeckColor) -> void

# --- 战斗 ---
# 用武器攻击目标（触发 ON_DAMAGE_DEALT 时机）
func attack(target: Entity, weapon: CardInstance) -> void

# 杀死怪物（触发 ON_KILL 时机，怪物卡进怪物弃牌堆）
func kill_monster(monster: Monster) -> void

# --- 状态效果 ---
func apply_poison(stacks: int) -> void
func stun_monster(monster: Monster) -> void

# --- 死亡 ---
# 死亡处理流程（见第 6 节，D8/D11）
func die() -> void

# --- 回合钩子（由 TurnManager 调用） ---
func on_turn_start() -> void
func on_turn_end() -> void
```

---

## 4. 装备栏容量（动态计算）

```text
实际容量 = data.equipment_slot_capacity + _equipment_slot_bonus

_equipment_slot_bonus 由持续型被动修改：
  - 背包"+1 装备栏"：ON_EQUIP 时 increase_equipment_slot_capacity(1)，ON_UNEQUIP 时 decrease_equipment_slot_capacity(1)
  - 见 01-Skill.md 6.1 节"持续型被动（双时机 + 分支）"
```

容量检查在 `CardInstance.equip(player)` 内部进行（02-Card.md Q3 决策）：
- `player.get_equipment_capacity() - player.get_equipment_used() >= card.data.size` → 允许装备
- 否则返回 false

---

## 5. 饥饿状态切换（R1）

```text
hunger 1-5（正常状态）：
  - is_hungry = false
  - stealth = data.stealth_normal
  - 天赋可用（can_trigger 内不阻拦）

hunger ≥ 6（饥饿状态）：
  - is_hungry = true
  - stealth = data.stealth_hungry
  - 天赋禁用（can_trigger 内检查 is_hungry 返回 false）
  - UI 表现：角色卡翻面（边框变红/图标变色）

饥饿伤害序列（饥饿状态下每次饥饿 +1 触发扣血，详见 15-HungerSystem.md 第 5 节）：
  - 第 1 次 +1：受 2 点伤害，hunger_damage_sequence = 4
  - 第 2 次 +1：受 4 点伤害，hunger_damage_sequence = 6
  - 第 3 次 +1：受 6 点伤害，hunger_damage_sequence = 8
  - 第 4 次 +1：受 8 点伤害，hunger_damage_sequence = 10
  - 第 5 次 +1：直接 die()（不扣血，R1 第 5 次死亡）
  - 退出饥饿（hunger ≤ 5）时 hunger_damage_sequence 重置回 2

进入饥饿状态的当回合不扣血（R1）：
  - hunger 从 5 涨到 6 时，is_hungry = true，hunger_damage_this_turn = true，本回合不再受饥饿伤害
  - 下次回合开始 on_turn_start 时 hunger_damage_this_turn = false，若仍 hunger ≥ 6，下次 +1 按 hunger_damage_sequence 扣血
```

> 饥饿伤害通过 `ON_HUNGER_DAMAGE` 时机触发，可被技能修改（如消防员"能量饮料"免疫饥饿伤害到下回合）。饥饿伤害调用 `take_damage(amount, source=HUNGER, unavoidable=true)`，跳过 ON_DAMAGE_TAKEN 减伤调度（R1 不可减免，详见 15-HungerSystem.md 第 5.2 节与 14-CombatSystem.md 第 5 节）。

---

## 6. 死亡处理（D8/D11）

```text
die() 流程：
  1. 装备卡处理（D8，按 source 区分）：
     - source = SURVIVOR_DECK → card.remove()（随玩家死亡移出游戏）
     - source = SCAVENGER_DECK → card.unequip() + 留在死亡地块（location = ON_MAP，可被同地块玩家花 1 行动捡起）
     - 注：remove/discard 均隐含触发 ON_UNEQUIP（02-Card.md 第 14 节）

  2. 纠缠怪物处理（D11）：
     - 面前所有纠缠怪物卡置入怪物弃牌堆（不生成怪物标记，不留在地块）
     - 怪物弃牌堆在怪物牌库空时可重洗（D10）

  3. 手牌处理：
     - 手牌中的求生者卡（source = SURVIVOR_DECK）→ 随玩家死亡移出游戏
     - 手牌中的拾荒卡（source = SCAVENGER_DECK）→ 留在死亡地块（location = ON_MAP）

  4. 牌库与弃牌堆：
     - 求生者牌库 + 求生者弃牌堆 → 随玩家死亡移出游戏

  5. Survivor Node 销毁
```

掉落卡捡起（D8）：
- 同地块玩家花 1 行动可捡起 1 张掉落卡（location = ON_MAP 的卡）
- 掉落卡包括：`SCAVENGER_DECK` 来源的装备卡、手牌中的拾荒卡

---

## 7. MVP 5 名角色（D15）

MVP 阶段可选 5 名角色（不含老兵+狗，见 D15）：

| character_id | character_name | max_hp | stealth_normal / hungry | 装备栏 | 定位 |
|---|---|---|---|---|---|
| `surgeon` | 外科医生 | 23 | 8 / 7 | 4 | 辅助/治疗 |
| `mechanic` | 机械师 | 26 | 8 / 7 | 4 | 装备/支援 |
| `hunter` | 猎手 | 24 | 9 / 8 | 4 | 侦查/远程 |
| `firefighter` | 消防员 | 32 | 6 / 5 | 4 | 坦克/近战 |
| `cowboy` | 枪手 | 28 | 7 / 6 | 4 | 远程/弹药 |

> 各角色的天赋 skill_ids 与 survivor_deck_card_ids 见原版角色包文件（`桌游实体/基础版/角色包/*.md`），数据录入阶段从原版提取为 `.tres` 文件。

---

## 8. 老兵 + 狗预留（D15 后期实现）

老兵+狗是"双角色单位"，MVP 阶段不实现（D15），但 `Survivor` 基类设计需预留接口：

- 选择老兵即同时获得老兵 + 狗两个 `Survivor` 实例
- 共享回合但分别结算生命 / 饥饿 / 装备区
- 老兵：max_hp 22，stealth 7/6，装备栏 4，天赋"把你的爪子拿开"
- 狗：max_hp 12，stealth 9/8，装备栏 0（D6），天赋"咬他们"

实现方式（待后期设计）：
- `Survivor` 增加 `companion: Survivor` 字段（狗作为老兵的伴随角色）
- 或 `Veteran` 子类持有 `Dog` 子类
- TurnManager 调度时按"角色组"分配回合

---

## 9. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | `Entity` 基类的公共接口（take_damage/heal/die 等）放在 Survivor 还是 Entity | 倾向放 Entity 基类，Survivor/Monster 共用。待 Entity 基类设计文档定义 |
| 2 | `extra_actions`（野地夹克恢复的额外行动）与 `action_points` 的消耗顺序 | 倾向先消耗 `extra_actions` 再消耗 `action_points`（v1 第 8.2 节，D81） |
| 3 | `poison_stacks` 的结算时机（回合开始/结束） | 待回合流程文档定义 |
| 4 | 手牌上限 10 的检查在 `add_to_hand` 内还是调用方 | 倾向 `add_to_hand` 内检查并返回 bool（与 equip 模式一致） |
| 5 | 玩家死亡后 Survivor Node 是否立即销毁 | 倾向延迟销毁（等死亡动画/UI 演出完成），由 GameSession 管理 |
| 6 | 老兵+狗的"双角色单位"具体实现 | 待 D15 后期实现时定，Survivor 基类先预留 companion 字段 |
| 7 | 天赋的 `can_trigger` 内如何检查 `is_hungry` | 倾向在 ActiveSkill/TriggerSkill 子类的 can_trigger 里写 `if owner.is_hungry: return false`（owner 是 Survivor 时） |
| 8 | `current_block` 的初始值（游戏开始时所有玩家在起始地块） | 由任务卡 `initial_setup` 定义，GameSession 初始化时设置 |
