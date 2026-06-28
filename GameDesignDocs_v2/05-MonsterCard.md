# 05 - MonsterCard 与 Monster Entity

> 怪物卡 = `MonsterCardData`（Resource，怪物定义）+ `Monster`（Node，运行时实体）。
> 沿用 v1 决策"数据 = Resource / 实体 = Node"，与 `CharacterCardData → Survivor Node` 关系一致（02-Card.md Q8 决策）。
> 应用 v1 决策：D10（怪物牌库循环）、D11（玩家死亡纠缠怪物处理）、D13（MVP 仅僵尸包）、D16（怪物标记上限）、D17（初始抓怪按座次）、D23（怪物射程"无"定义）、D24（Skill 统一技能）、R3（怪物纠缠）。
> 本文档只定义基类与方法签名，不含具体怪物数据（zombie/alien 等见原版怪物包文件）。

---

## 1. 设计原则

- **数据 + 实体分离**：`MonsterCardData`（Resource）存怪物定义性字段（monster_id / max_hp / damage / 天赋 / 怪物包 / 级别）；`Monster`（Node）存运行时状态（current_hp / engaged_player / 击晕状态 等）。一份 `MonsterCardData` 可被多局游戏复用，每次抓到怪物卡时创建独立的 `Monster` 实例。
- **Entity 基类**：`Monster extends Entity`，与 `Survivor extends Entity` 平级（待 Entity 基类设计文档定义公共接口 `take_damage` / `die` 等）。
- **天赋 = Skill**：怪物天赋统一用 `skill_ids: Array[StringName]` 关联 `Skill` 实例（沿用 01-Skill.md），运行时由 `SkillRegistry` 查表。怪物天赋**均为 `forced=true` TRIGGER**（自动触发，玩家不能选择不触发，对应三国杀"锁定技"）。
- **怪物卡 vs 怪物标记分离**：怪物卡（纠缠玩家面前，回合结束攻击）与怪物标记（地块上，影响潜行检定）是两个独立系统，不互相转化（D11 已修正原版"死亡换标记"为"进怪物弃牌堆"）。
- **首领卡不进普通牌库**：首领卡由任务卡 `boss_config` 单独配置入场（见 06-MissionCard.md，待编写），普通+精英怪洗入怪物牌库。

---

## 2. MonsterCardData（Resource，怪物定义）

```text
class_name MonsterCardData extends PlayableCardData
# card_type = CardType.MONSTER
# source = CardSource.MONSTER_DECK（02-Card.md 第 6 节）
# size: 沿用 PlayableCardData.size（怪物卡通常 size=0，不进装备区）
# range: 沿用 PlayableCardData.range（怪物射程，D23）
# scavenger_color: 沿用 PlayableCardData.scavenger_color（怪物卡设 NONE，非拾荒卡）

# === 怪物身份 ===
@export var monster_id: StringName              # 怪物唯一标识（如 &"zombie_queen"）
@export var monster_name: String                # UI 显示名（如 "僵尸女王"）
@export var description: String                 # 怪物介绍（UI 用，可为空）

# === 怪物包与级别 ===
@export var monster_pack: MonsterPack           # 所属怪物包（见第 4 节）
@export var level: MonsterLevel                 # 怪物级别（见第 5 节）

# === 属性 ===
@export var max_hp: int                         # 初始血量（怪物卡无"生命值上限"概念，max_hp 即初始血量）
@export var damage: int                         # 攻击伤害（回合结束对玩家造成的固定伤害，不投骰）

# === 天赋 ===
@export var skill_ids: Array[StringName] = []   # 天赋技能 ID 列表（空=无天赋，均为 forced=true TRIGGER）
```

> `current_hp` / `engaged_player` / `is_stunned` 等运行时状态**不放 MonsterCardData**，而是放 Monster Node（Entity 层，见第 3 节）。这符合 02-Card.md Q8 决策"怪物卡的 current_hp 放在 Monster Node 上"。

---

## 3. Monster Entity（Node，运行时实体）

```text
class_name Monster extends Entity
# Entity 是 Node 子类，提供 take_damage/die 等公共接口（与 Survivor 共用，待 Entity 基类设计文档定义）

# === 引用怪物定义 ===
var data: MonsterCardData                       # 引用不可变的怪物卡数据
var card_instance: CardInstance                 # 关联的卡牌实例（怪物卡本体，location = IN_PLAY）

# === 生命 ===
var current_hp: int                             # 当前血量（初始 = data.max_hp）

# === 纠缠 ===
var engaged_player: Survivor = null             # 纠缠的玩家（R3，null = 未纠缠任何玩家）

# === 状态效果 ===
var is_stunned: bool = false                    # 击晕状态（被击晕期间不攻击）
var stunned_until_turn_owner: Survivor = null   # 击晕到哪个玩家的下回合开始（用于"击晕到下回合"）

# === 方法签名 ===

# --- 生命 ---
# 受到伤害（触发 ON_DAMAGE_TAKEN 时机，由 SkillExecutor 调度减伤技能如方阵机器人"范围内怪物受伤-1"）
# 血量归零时调用 die(source)
func take_damage(amount: int, source: Entity) -> void

# 死亡处理（触发 ON_KILL 时机，如僵尸女王"僵尸被消灭时击杀者抓怪物卡"）
# killer 是击杀者（用于效果结算），怪物卡进怪物弃牌堆（可重洗，D10）
func die(killer: Survivor) -> void

# --- 攻击 ---
# 攻击纠缠的玩家（回合结束阶段调用，触发 ON_MONSTER_ATTACK 时机）
# 攻击范围由 data.range 决定（D23），伤害固定 = data.damage
func attack() -> void

# --- 纠缠关系 ---
# 纠缠玩家（怪物卡被抓到玩家面前时调用，R3）
func engage(player: Survivor) -> void

# 解除纠缠（怪物被消灭 / 被卡牌效果赶走 / 玩家死亡时调用）
func disengage() -> void

# 移动到新玩家面前（如僵尸潜行者天赋"移动到血量最低玩家"，例外于"怪物不主动移动"）
# 多个玩家同为最低血量时：当前回合玩家优先 → 座次顺序最早者（D84）
func move_to_player(player: Survivor) -> void

# --- 击晕状态 ---
# 击晕（如套索/泰瑟枪/灭火器等卡牌效果）
# stunned_until_turn_owner 表示"击晕到该玩家的下回合开始"
func stun(until_turn_owner: Survivor) -> void

# 检查是否处于击晕状态（回合结束攻击前调用，若击晕则跳过攻击）
# 击晕在击晕者下回合开始时解除后，该怪物当回合正常攻击（D92）
func is_stunned_now(current_turn_owner: Survivor) -> bool

# --- 回合钩子（由 TurnManager 调用） ---
func on_turn_start(owner: Survivor) -> void     # 用于结算击晕到期等
func on_turn_end(owner: Survivor) -> void       # 用于触发攻击（owner 是纠缠的玩家）
```

> 怪物 Node 不存"位置"字段——怪物卡不占地块格子（R3），纠缠关系通过 `engaged_player` 引用表达。玩家移动时纠缠的怪物跟随玩家（逻辑上 `engaged_player` 不变）。

---

## 4. MonsterPack 枚举

```text
enum MonsterPack {
    ZOMBIE,   # 僵尸包（38 张，应用任务 0、1、2、3 第一章 僵尸篇）
    MUTANT,   # 突变体包（28 张，应用任务 4、5、6 第二章 突变体篇）
    ALIEN,    # 外星人包（27 张，应用任务 7、8、9 第三章 外星人篇）
    ROBOT,    # 机器人包（34 张，应用任务 10、11、12 第四章 机器人篇）
}
```

> 任务卡通过 `monster_pack` 字段指定本局使用的怪物包（见 06-MissionCard.md）。

---

## 5. MonsterLevel 枚举

```text
enum MonsterLevel {
    BOSS,     # 首领（由任务卡 boss_config 配置入场，不进普通怪物牌库）
    ELITE,    # 精英（通常有天赋，洗入怪物牌库）
    NORMAL,   # 普通（通常无天赋，洗入怪物牌库）
}
```

> 首领卡与普通/精英怪的入场路径不同：
> - 普通+精英怪：洗入怪物牌库，按规则抓取（D17 初始抓怪 / 地块效果 / 卡牌效果等）
> - 首领卡：由任务卡 `boss_config` 单独配置入场时机（如任务 2 首领卡洗入牌库底 10 张，D19）

---

## 6. 怪物纠缠机制（R3）

```text
纠缠关系建立：
  - 怪物卡被某玩家抓取时，创建 Monster Node 并 engage(player)
  - engaged_player 字段记录纠缠关系

纠缠关系持续到：
  1. 怪物被消灭（current_hp ≤ 0 → die(killer) → disengage()）
  2. 被卡牌效果赶走（如伪装"换掉面前非首领怪物" → disengage() + 怪物卡进怪物弃牌堆）
  3. 玩家死亡（D11 → 面前所有纠缠怪物置入怪物弃牌堆）

纠缠关系绑定玩家，不绑定地块：
  - 玩家移动时，纠缠的怪物卡跟随玩家（engaged_player 不变）
  - 怪物不主动改变纠缠对象（例外：僵尸潜行者天赋 ON_DAMAGE_DEALT 时移动到血量最低玩家）

怪物卡不占地块格子：
  - 怪物卡在玩家面前，是逻辑概念（不进 MapBlock 的实体列表）
  - 地块上的"怪物标记"是独立系统（见第 9 节）
  - 玩家可攻击其他玩家面前的怪物（需在射程内，见战斗系统文档）
```

---

## 7. 怪物射程与攻击范围（D23）

怪物射程沿用 `PlayableCardData.range`（02-Card.md 第 7 节，枚举 NONE/SHORT/MEDIUM/LONG）。怪物攻击范围以**纠缠玩家所在格**为中心：

| 射程 | 攻击范围 | 说明 |
|---|---|---|
| `NONE` | 只攻击纠缠的那一个玩家 | 即使同格有其他玩家也不受攻击（D23）；原版字段留空的射程统一按 `NONE` 处理（D83） |
| `SHORT` | 纠缠玩家所在格的所有玩家 | 同格其他玩家也受攻击 |
| `MEDIUM` | 纠缠玩家所在格 + 4 邻格的所有玩家 | 范围攻击 |
| `LONG` | 纠缠玩家为中心 5×5 减四角范围的所有玩家 | 范围攻击 |

> 怪物攻击在"纠缠玩家的回合结束阶段"触发（R2 顺序：地块 → 饥饿 → 怪物）。射程 MEDIUM/LONG 的怪物会波及范围内的其他玩家（即使不是他们的回合）。

---

## 8. 怪物牌库循环（D10）

```text
牌库构成：
  - 任务卡 monster_pack 指定本局使用的怪物包
  - 牌库 = 该怪物包的所有 ELITE + NORMAL 卡（首领卡除外）
  - 任务开始时洗混形成怪物牌库

牌库循环（D10，与拾荒牌库 D12 对比）：
  - 怪物卡被消灭 / 玩家死亡 → 置入怪物弃牌堆
  - 怪物牌库被抓空 → 怪物弃牌堆重新洗混为新的怪物牌库（可重洗）
  - 与拾荒牌库不同（拾荒弃牌堆不可重洗，D12）

抓怪物卡的时机：
  | 时机                | 来源           | 说明 |
  |---------------------|----------------|------|
  | 游戏设置第 8 步     | 系统初始化     | 每名玩家按座次顺序抓 1 张怪物卡（D17） |
  | 地块触发效果        | 地块技能       | 如旷野、墓地、城市街道"抓一张怪物卡" |
  | 卡牌效果            | 拾荒卡/装备卡  | 如伏击卡、感应地雷等 |
  | 怪物天赋            | 怪物技能       | 如僵尸女王、一大波僵尸、僵尸步行者（精英） |
  | 任务事件            | 任务系统       | 如首领卡配置触发（boss_config） |
```

---

## 9. 怪物标记系统（独立概念）

### 9.1 怪物标记 vs 怪物卡

PC 版严格区分两个独立概念：

| 概念 | 来源 | 位置 | 作用 |
|---|---|---|---|
| 怪物卡 | 怪物牌库抓取 | 纠缠玩家面前（IN_PLAY） | 回合结束攻击玩家；玩家可主动攻击消灭 |
| 怪物标记 | 怪物出生阶段投骰 | 地块上（ON_MAP） | 影响潜行检定（每标记 -1 潜行）；检定失败时移除并抓怪物卡 |

> 怪物卡和怪物标记是两个独立系统。怪物卡不占地块，怪物标记不是卡。两者不互相转化（D11 已修正原版"死亡换标记"为"进怪物弃牌堆"）。

### 9.2 怪物标记生成

```text
回合开始时执行怪物出生阶段（回合流程第 1 阶段）：
  1. 投 2 颗 D6 骰子，点和为 X
  2. 在 monster_spawn_value == X 的地块上放置 1 个怪物标记
  3. 若多块地块的 monster_spawn_value 都等于 X，则全部放置
  4. 检查怪物标记总数是否达上限（D16），达到则游戏失败
```

> 地块的 `monster_spawn_value` 字段见 09-MapBlock.md。骰子机制与投骰细节见 14-CombatSystem.md（待编写）。

### 9.3 怪物标记上限（D16）

```text
全局怪物标记总数 ≥ TaskCard.monster_token_limit（默认 30）→ 玩家失败
上限由任务卡配置，可由难度覆盖
```

### 9.4 怪物标记移除途径

| 途径 | 说明 |
|---|---|
| 潜行检定失败 | 移除该地块所有怪物标记，每移除 1 个抓 1 张怪物卡（见战斗系统文档） |
| 卡牌效果 | 如大炸药、无人机攻击等（04-ScavengerCard.md 第 11 节） |
| 任务特殊规则 | 如任务 11 清除目标标记地块的怪物标记 |

---

## 10. 怪物攻击机制

```text
攻击时机：
  回合结束阶段（回合流程第 5 阶段，R2 顺序）：
    1. 地块结束效果
    2. 饥饿 +1（触发饥饿伤害检查）
    3. 怪物攻击：每张纠缠当前回合玩家的怪物卡（未击晕）发起攻击

攻击伤害：
  - 怪物攻击伤害固定（data.damage 字段），不投骰
  - 攻击范围由 data.range 决定（见第 7 节）
  - 伤害可被装备效果减免（如焊接头盔 -1、防弹背心 -2，触发 ON_DAMAGE_TAKEN 时机）
  - 不可减免的伤害：饥饿伤害（R1）

攻击流程：
  1. SkillExecutor 触发 ON_MONSTER_ATTACK 时机（用于"攻击时"触发的天赋，如外星科学家"伤害+1"）
  2. 怪物对范围内所有玩家分别造成 data.damage 点伤害
  3. 每个受击玩家触发 ON_DAMAGE_TAKEN 时机（减伤技能在此调度）
  4. 怪物天赋 ON_DAMAGE_DEALT 时机在此之后触发（如僵尸潜行者"造成伤害后移动到血量最低玩家"）
```

> 战斗结算流程（含伤害减免、装备耐久、死亡判定）详见战斗系统文档（待编写）。

---

## 10.5 怪物天赋特殊规则（D83-D92 / D100）

### 10.5.1 空射程按 `NONE` 处理（D83）

原版部分怪物卡射程字段留空（如突变体老鼠、激光无人机、外星入侵者），PC 版统一按 `Range.NONE` 处理：仅攻击纠缠的那一个玩家，不波及同格或邻格其他玩家。

### 10.5.2 僵尸潜行者目标选择（D84）

僵尸潜行者天赋"移动到血量最低玩家"：多个玩家血量同为最低时，**当前回合玩家优先**；若当前回合玩家不是最低血量，则按**座次顺序最早者**选择。

### 10.5.3 外星飞船拦截（D85）

外星飞船"不能被射程为短距离的武器或行动选为目标"：
- 新增 `ON_TARGET_SELECT` 时机。
- 外星飞船持有 `forced=true` TRIGGER 技能，在 `ON_TARGET_SELECT` 时拦截"射程为短距离（SHORT）的武器或行动"，强制将其目标改为自己。
- 该技能由 SkillExecutor 在目标选择阶段调度，先于伤害结算。

### 10.5.4 外星科学家光环（D86）

外星科学家"所有外星人类怪物攻击时伤害 +1"：
- 采用《无名杀》式被动光环实现：外星科学家自身持有 `forced=true TRIGGER` 技能，时机为 `ON_MONSTER_ATTACK`。
- 条件：攻击者是 `MonsterPack.ALIEN` 的人类怪物（含外星科学家自身）。
- 效果：该次攻击伤害 +1。
- 多个外星科学家在场时效果可叠加（按实际在场数量计算）。

### 10.5.5 "区域内的一张牌"范围（D87）

怪物效果中"区域内的一张牌"指：**手牌区 + 装备区**。不含地图上的掉落卡、牌库、弃牌堆。

### 10.5.6 "摧毁装备牌"的归宿（D88）

怪物效果中的"摧毁装备牌"等同于 [`CardInstance.remove()`](02-Card.md)：该装备先触发 `ON_UNEQUIP`，然后移出本局游戏，不进入任何弃牌堆。

### 10.5.7 爆破机器人"本回合未移动"（D89）

爆破机器人天赋"本回合未移动时攻击伤害 +X"：
- "移动"仅统计玩家**主动执行的"移动"行动**。
- 被卡牌/效果强制移动（如机场传送、隧道穿梭、被击退）不算作"本回合移动"。
- 玩家在其他玩家回合被强制移动不计入自己回合的移动统计。

### 10.5.8 被赶走/伪装不触发消灭效果（D90）

怪物因 `disengage()` 离场（如伪装"换掉面前非首领怪物"、卡牌效果"赶走"）时，不触发该怪物的 `ON_KILL` / "被消灭/摧毁"相关天赋（如全能机器人、爆破机器人）。
- 只有 `current_hp ≤ 0` 导致的 `die()` 才触发消灭/摧毁效果。

### 10.5.9 强制弃牌为空则直接受伤（D91）

达克斯顿·贾格 / 军部残余武装 / 强盗 / 外星科学家的"弃 X 张牌，否则受 Y 点伤害"效果：
- 若目标区域（手牌区 + 装备区，见 D87）中卡牌数量 < X，则**直接受 Y 点伤害**，不弃牌。
- 目标区域为空时同样直接受伤。

### 10.5.10 击晕到期后攻击（D92）

怪物被击晕后，在击晕者下回合开始时解除击晕；若该怪物仍纠缠当前回合玩家，则**当回合正常攻击**（不再跳过）。详见第 3 节 `is_stunned_now()`。

### 10.5.11 地图边界外标记放置（D100）

怪物天赋或卡牌效果向相邻地块放置怪物标记时，若目标方向超出 `map_layout` 边界（无地块），则**直接忽略**，不放置标记，也不产生替代效果。

---

## 11. 4 怪物包总览

| 怪物包 | 总数 | 首领数 | 普通+精英 | 应用任务 | MVP 状态 |
|---|---|---|---|---|---|
| ZOMBIE（僵尸包） | 38 | 2 | 36 | 任务 0、1、2、3 | ✅ 详细设计见 v1 03-怪物系统设计.md 第 6 节 |
| MUTANT（突变体包） | 28 | 2 | 26 | 任务 4、5、6 | 待后续设计 |
| ALIEN（外星人包） | 27 | 2 | 25 | 任务 7、8、9 | 待后续设计 |
| ROBOT（机器人包） | 34 | 2 | 32 | 任务 10、11、12 | 待后续设计 |
| **合计** | **127** | **8** | **119** | 任务 0-12 | - |

> 各怪物包的详细卡牌清单见原版怪物包文件（`桌游实体/基础版/怪物包/*.md`）与 v1 文档 `GameDesignDocs_v1/03-怪物系统设计.md` 第 6 节（僵尸包详细设计）。数据录入阶段将每张卡提取为 `.tres` 文件存放在 `data/monsters/<pack>/` 目录。

---

## 12. MVP 怪物范围（D13）

MVP 阶段仅实现**僵尸包**：

| 范围 | 内容 |
|---|---|
| 怪物包 | 僵尸包（38 张） |
| 首领卡 | 由任务 0 的 `boss_config` 配置（任务 0 为 `NONE`，无首领） |
| 普通牌库 | 36 张（6 种 × 6 张，首领卡除外） |
| 验证目标 | 移动 / 拾荒 / 战斗 / 饥饿 / 燃料 / 胜利核心循环 |

> 任务 0（教程）无首领卡（`boss_config.mechanic = NONE`，见 06-MissionCard.md），仅使用普通 + 精英怪。

僵尸包构成（共 38 张）：

| 怪物 | 级别 | 数量 | 有天赋 |
|---|---|---|---|
| 僵尸女王 | BOSS | 1 | ✅ |
| 一大波僵尸 | BOSS | 1 | ✅ |
| 僵尸狗 | NORMAL | 6 | ❌ |
| 僵尸士兵 | NORMAL | 6 | ❌ |
| 僵尸步行者 | NORMAL | 6 | ❌ |
| 僵尸步行者（精英） | ELITE | 6 | ✅ |
| 僵尸喷吐者（精英） | ELITE | 6 | ❌ |
| 僵尸潜行者（精英） | ELITE | 6 | ✅ |

> 详细字段与技能设计见 v1 `GameDesignDocs_v1/03-怪物系统设计.md` 第 6 节。

---

## 13. 怪物天赋与 Skill 类映射

怪物天赋 100% 可用 01-Skill.md 定义的 `Skill` 类描述，**无需扩展字段**：

| 原版天赋字段 | Skill 类字段 | 说明 |
|---|---|---|
| 触发时机 | `get_trigger_timings()` | 使用 01-Skill.md 枚举（ON_MONSTER_DRAWN / ON_KILL / ON_DAMAGE_DEALT / ON_MONSTER_ATTACK 等） |
| 触发效果 | `execute(event, owner)` | 具体逻辑在 EffectHandler 中实现 |
| - | `skill_type` | 怪物天赋均为 `TRIGGER`（自动触发，不消耗行动） |
| - | `forced` | 怪物天赋均为 `true`（锁定技，触发时机到就强制执行） |
| - | `can_trigger(event, owner)` | 检查触发条件（如"被消灭的怪物属于僵尸包"） |

> 怪物天赋的 `forced=true` 是关键：表示"锁定技"——触发时机到就强制执行，玩家不能选择不触发（与事件卡 04-ScavengerCard.md 第 7.1 节一致）。

### 13.1 怪物天赋触发时机总览

| 触发时机 | 典型天赋 | 示例怪物 |
|---|---|---|
| `ON_MONSTER_DRAWN` | 抓到该卡时触发 | 一大波僵尸、僵尸步行者（精英）、外星收割者、达克斯顿·贾格 |
| `ON_KILL` | 该怪物被消灭时触发 | 僵尸女王、全能机器人、爆破机器人 |
| `ON_DAMAGE_DEALT` | 该怪物造成伤害时触发 | 僵尸潜行者、狂暴的突变体、突变体老鼠、爆破机器人 |
| `ON_MONSTER_ATTACK` | 该怪物攻击时触发 | 外星收割者、外星指挥官、外星科学家、外星机械、外星入侵者、外星飞船 |
| `ON_STEALTH_CHECK` | 纠缠玩家潜行判定前触发 | 激光无人机 |
| `ON_DAMAGE_TAKEN` | 该怪物受到伤害时触发 | 方阵机器人（范围内机器人受伤 -1） |

> `ON_MONSTER_ATTACK`、`ON_STEALTH_CHECK`、`ON_TARGET_SELECT` 是怪物系统新增的触发时机（见 01-Skill.md TriggerTiming 枚举）。`ON_TARGET_SELECT` 用于外星飞船被动拦截（D85）。

---

## 14. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | 僵尸潜行者天赋"血量最低玩家"多个玩家血量相同时的目标选择 | **已决（D84）**：当前回合玩家优先 → 座次顺序最早者。详见第 10.5.2 节 |
| 2 | 僵尸步行者（精英）原版"射程："后为空 | **已决**：按 `NONE` 处理（只攻击纠缠玩家，D23） |
| 3 | `ON_MONSTER_ATTACK` 时机是否加入 01-Skill.md TriggerTiming 枚举 | **已决**：加入。已同步更新 01-Skill.md 第 3 节 TriggerTiming 枚举（用户决策）。用于外星包"攻击时"触发的天赋（外星收割者/外星指挥官/外星科学家/外星机械/外星入侵者/外星飞船） |
| 4 | 外星飞船"不能被射程为短距离的武器或行动选为目标"的实现方式 | **已决（D85）**：新增 `ON_TARGET_SELECT` 时机，外星飞船持有 forced=true TRIGGER 强制拦截短距离目标。详见第 10.5.3 节 |
| 5 | 外星科学家"所有外星人类怪物攻击时伤害 +1"的光环机制 | **已决（D86）**：参考《无名杀》被动技能实现，外星科学家自身持有 ON_MONSTER_ATTACK 被动光环。详见第 10.5.4 节 |
| 6 | 激光无人机"潜行判定前"是否需要 `ON_STEALTH_CHECK` 时机 | **已决**：加入。已同步更新 01-Skill.md 第 3 节 TriggerTiming 枚举（用户决策）。用于激光无人机"跳过潜行检定直接抓怪物卡"天赋 |
| 7 | 怪物卡 `.tres` 文件组织 | 倾向按怪物包分（`data/monsters/zombie/` / `mutant/` / `alien/` / `robot/`），便于按原版文件结构对照 |
| 8 | 首领卡 `boss_config` 数据结构 | 待 06-MissionCard.md 定义（倾向 `Dictionary` 含 `mechanic` / `boss_id` / `trigger_condition` 等字段） |
| 9 | 中毒层数的结算时机（回合开始 / 结束） | 沿用 07-CharacterCard.md Q3 待定 |
| 10 | 怪物 Node 是否在 `die()` 后立即销毁 | 倾向延迟销毁（等死亡动画 / UI 演出完成），由 GameSession 管理（与 07-CharacterCard Q5 一致） |
| 11 | 击晕状态"到下回合开始"的精确语义 | **已决**：`stunned_until_turn_owner` = 击晕者（如套索使用者），怪物在击晕者的下回合开始时解除击晕。`is_stunned_now(current_turn_owner)` 检查 `current_turn_owner == stunned_until_turn_owner` 时返回 false（已到期） |
| 12 | 怪物天赋的 `forced=true` 是否需要在 Skill 数据中显式设置 | **已决**：是。怪物天赋 Skill 的 `forced` 字段设为 `true`（01-Skill.md 基类字段），SkillExecutor.dispatch 走 forced 分支（不弹窗询问玩家） |

---

## 附：决策应用索引

本文档应用的决策：
- D10 怪物牌库循环（弃牌堆可重洗）
- D11 玩家死亡后纠缠怪物置入怪物弃牌堆（不换标记）
- D13 MVP 最小可玩闭环（仅僵尸包）
- D16 怪物标记上限由任务卡配置（默认 30）
- D17 初始怪物抓取按座次顺序
- D23 怪物射程"无"的定义（仅攻击纠缠玩家）
- D24 Skill 通用技能系统（怪物天赋统一为 forced=true TRIGGER 类 Skill）
- R2 回合结束效果触发顺序（地块 → 饥饿 → 怪物）
- R3 怪物纠缠机制（抽到即纠缠，绑定玩家不绑定地块）
- 02-Card.md Q8 决策（怪物卡 current_hp 放 Monster Node，不放 CardInstance）
- D83 空射程统一为 `NONE`
- D84 僵尸潜行者 tie-breaking（当前回合玩家优先 → 座次顺序最早者）
- D85 外星飞船被动实现（新增 `ON_TARGET_SELECT` 时机）
- D86 外星科学家光环（《无名杀》式被动实现）
- D87 "区域内" = 手牌区 + 装备区
- D88 "摧毁装备牌" = `remove()`
- D89 爆破机器人"本回合未移动"仅统计主动移动
- D90 `disengage()` 不触发消灭效果
- D91 强制弃牌为空直接受伤
- D92 击晕到期后当回合正常攻击
- D100 地图边界外标记放置忽略
