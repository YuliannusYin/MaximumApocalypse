# 实体（Entity）

> 本文档定义游戏中所有"实体"对象的数据结构。
> 实体是技能挂载与事件触发的最小单位：凡能 `trigger(triggerName, event)` 的对象都是实体。
> 与 [EventTrigger.md](EventTrigger.md)（触发机制）、[event.md](event.md)（事件对象）、[skill.md](skill.md)（技能对象）配套。
> 文档创建日期：2026-07-04 · 实体结构补全日期：2026-07-07

---

## 目录

- [1. 继承关系](#1-继承关系)
- [2. Entity 基类](#2-entity-基类)
- [3. Player 玩家实体](#3-player-玩家实体)
- [4. Monster 怪物实体](#4-monster-怪物实体待实现)
- [5. MapBlock 地图块实体](#5-mapblock-地图块实体)
- [6. RoleCard 角色卡](#6-rolecard-角色卡)
- [7. Dice 骰子工具](#7-dice-骰子工具)
- [8. 实体与区域对象](#8-实体与区域对象待定义)

---

## 1. 继承关系

```
RefCounted
├── Entity                      # 基类：技能挂载 + 事件触发 + 伤害流程
│   ├── Player                  # 玩家（生命值/饥饿值/潜行值/角色卡/标记/当前地块/骰子）
│   ├── Monster                 # 怪物（待实现；纠缠对象/级别/类型/生命值/攻击伤害/射程）
│   └── MapBlock                # 地图块（展示状态/怪物标记/怪物列表/玩家列表/刷怪点数）
├── RoleCard                    # 角色卡（正反面）
└── Dice                        # 骰子工具（静态投骰）
```

> **设计原则**：所有可被技能挂载的对象都继承自 `Entity`。地块虽然是"地形"概念，但地块技能需要 `trigger`，因此 `MapBlock` 也继承 `Entity`。
> **代码对齐**：已实现部分见 [scripts/system/entity.gd](../../../scripts/system/entity.gd)、[player.gd](../../../scripts/system/player.gd)、[map_block.gd](../../../scripts/system/map_block.gd)、[role_card.gd](../../../scripts/system/role_card.gd)、[dice.gd](../../../scripts/system/dice.gd)。

---

## 2. Entity 基类

**类声明**：`class_name Entity extends RefCounted`
**职责**：所有实体的基类，提供技能挂载、事件触发、伤害流程入口。

### 2.1 成员变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `_skills` | `Array[Skill]` | `[]` | 该实体上所有技能。子类可重写 `get_all_skills()` 聚合多来源（如玩家 = 角色固有 + 装备 + 临时 + 地块） |

### 2.2 公有方法

| 方法签名 | 说明 |
|----------|------|
| `get_all_skills() -> Array[Skill]` | 返回该实体所有技能。子类可重写以聚合多来源 |
| `add_skill(skill: Skill) -> void` | 添加技能到 `_skills` |
| `remove_skill(skill: Skill) -> void` | 移除技能 |
| `trigger(trigger_name: String, event: Event) -> void` | 遍历技能，依次触发匹配 `trigger_name` 的。规则见 [EventTrigger.md](EventTrigger.md) |
| `damage(num: int, source: Variant = null, type: String = "") -> void` | 造成 `num` 点伤害。8 节点钩子链见 [DamageFlow.md](DamageFlow.md)。`source=null` 时跳过 source 侧钩子 |
| `get_hp() -> int` | 当前生命值。子类必须重写 |
| `reduce_hp(num: int) -> void` | 直接扣血（节点 5 非钩子）。子类必须重写 |
| `is_player() -> bool` | 是否为玩家。默认 `false` |
| `is_monster() -> bool` | 是否为怪物。默认 `false` |

### 2.3 私有方法

| 方法签名 | 说明 |
|----------|------|
| `_run_filter(skill: Skill, event: Event) -> bool` | 执行技能 filter，无 callable 时返回 `true` |
| `_run_content(skill: Skill, event: Event) -> void` | 执行技能 content |
| `_on_death(source: Variant) -> void` | 死亡流程入口。子类重写为 `playerDeath`/`monsterDeath` |

---

## 3. Player 玩家实体

**类声明**：`class_name Player extends Entity`
**职责**：玩家实体，含生命值/饥饿值/潜行值/角色卡/标记/当前地块/骰子检定等。
**代码对齐**：[scripts/system/player.gd](../../../scripts/system/player.gd) · [docs/system-classes.md](../../../docs/system-classes.md#Player)

### 3.1 成员变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `name` | `String` | `""` | 玩家名字（玩家可见文本） |
| `_max_hp` | `int` | `6` | 最大生命值上限。由求生者角色卡决定（如消防员 32） |
| `_hp` | `int` | `6` | 当前生命值。≤ 0 时玩家死亡 |
| `_hunger` | `int` | `1` | 当前饥饿值（1~6）。达到 6 后翻面角色卡并叠加饥饿伤害标记 |
| `_sneak_value` | `int` | `0` | 基础潜行值（不含地块怪物减成；`sneakJudge()` 自行减成）。由角色卡决定（如消防员 6，饥饿状态 5） |
| `_role_card` | `RoleCard` | `RoleCard.new()` | 角色卡牌对象 |
| `_marks` | `Dictionary` | `{}` | 标记字典。键为标记名（如 `"poison"`、`"饥饿伤害等级"`、`"避难所失效"`），值为层数 |
| `_current_block` | `Variant` | `null` | 当前所在地图块。`null` 表示未在地图上 |
| `_dice_roller` | `Callable` | `Callable()` | 注入的骰子 roller（测试用）。无参 Callable，返回 `int` |

### 3.2 状态查询方法

| 方法签名 | 说明 |
|----------|------|
| `get_hp() -> int` | 当前生命值（重写 Entity） |
| `get_max_hp() -> int` | 最大生命值上限 |
| `get_hunger() -> int` | 当前饥饿值 |
| `get_sneak() -> int` | 基础潜行值（不含地块减成） |
| `get_current_block() -> Variant` | 当前所在地图块 |
| `get_role_card() -> RoleCard` | 角色卡牌对象 |
| `is_player() -> bool` | 是否为玩家。返回 `true` |

### 3.3 状态修改方法（底层原子方法，不走事件流程）

> 与 [待定义方法.md §9.6](../待定义方法.md#96-playeradd_hpnum-与-playerrecovernum-的关系)、[§9.7](../待定义方法.md#97-playeradd_hungernum-与-playerincreasehungernum-的关系) 对齐：底层原子方法直接改数值，不触发钩子。

| 方法签名 | 说明 |
|----------|------|
| `set_max_hp(max_hp: int) -> void` | 设置最大生命值 |
| `set_hp(hp: int) -> void` | 设置当前生命值 |
| `set_hunger(hunger: int) -> void` | 设置饥饿值 |
| `set_sneak(sneak_value: int) -> void` | 设置潜行值 |
| `set_current_block(block: MapBlock) -> void` | 设置当前所在地图块 |
| `set_dice_roller(roller: Callable) -> void` | 注入骰子 roller（测试用） |
| `add_hp(num: int) -> void` | 直接加 `num` 点生命值，不触发"回复生命时"钩子，不受最大值约束 |
| `add_hunger(num: int) -> void` | 直接加 `num` 点饥饿值，不走 `increaseHunger` 流程（不翻面、不加饥饿伤害标记） |
| `reduce_hunger(num: int) -> void` | 直接减少 `num` 点饥饿值，不走 `decreaseHunger` 流程（不清饥饿伤害标记、不翻回）。最低降至 1 |
| `add_sneak(num: int) -> void` | 增加潜行值 |
| `reduce_sneak(num: int) -> void` | 减少潜行值 |
| `reduce_hp(num: int) -> void` | 直接扣血 `num` 点（重写 Entity；可降至 0 以下，死亡判定由 `damage` 处理） |

### 3.4 标记方法

| 方法签名 | 说明 |
|----------|------|
| `addMarkSkill(mark_name: String, quantity: int = 1) -> void` | 添加 `quantity` 层标记。**当前不支持 `Until` 参数**（永久标记，需主动 `removeMarkSkill` 移除） |
| `removeMarkSkill(mark_name: String) -> void` | 移除标记（清零） |
| `countMark(mark_name: String) -> int` | 获取标记层数。无此标记返回 `0` |
| `hasMarkSkill(mark_name: String) -> bool` | 是否有指定标记（层数 > 0） |

> **标记命名约定**：`"poison"`（中毒）、`"饥饿伤害等级"`（1-5 级）、`"避难所失效"`（避难所地块技能用，待实现 `Until` 后支持回合结束清除）。

### 3.5 状态流程方法（已定义，走事件钩子）

> 详见 [PlayerState.md](../2_player/PlayerState.md)。

| 方法签名 | 说明 |
|----------|------|
| `recover(num: int) -> void` | 恢复 `num` 点生命值，受最大值约束。4 节点钩子链：回复生命前/时/系统加血/后 |
| `increaseHunger(num: int) -> void` | 增加 `num` 点饥饿值，逐点结算：到 6 翻面 + 加饥饿伤害标记，按等级造成无来源伤害 |
| `decreaseHunger(num: int) -> bool` | 减少 `num` 点饥饿值，最低降至 1。清除饥饿伤害标记并翻回正面。返回是否成功减少 |
| `poison() -> void` | 中毒结算：按 `poison` 标记层数造成无来源伤害 |

### 3.6 检定方法

> 详见 [Judge.md](../4_judge/Judge.md)。

| 方法签名 | 说明 |
|----------|------|
| `roll_two_dice() -> int` | 投两颗大骰子，返回点数和（2-12）。测试可注入固定返回 |
| `judge() -> int` | 检定：投两颗大骰子，返回点数和 |
| `sneakJudge() -> bool` | 潜行检定：结果 ≤ 潜行值（减地块怪物数 + 标记数）则成功 |
| `monsterSpawnJudge(revealed_blocks: Array[MapBlock] = []) -> void` | 怪物出生检定。`revealed_blocks` 由调用方注入（本轮无 game 对象） |

### 3.7 抓牌/死亡方法

| 方法签名 | 状态 | 说明 |
|----------|------|------|
| `draw(n)` | 已定义 | 见 [DrawFlow.md](../DrawFlow.md) |
| `drawScavenge(n, pile)` | 已定义 | 见 [DrawFlow.md](../DrawFlow.md) |
| `drawMonster(num)` | stub | 见 [DrawFlow.md](../DrawFlow.md) · [待定义方法.md §10.3](../待定义方法.md#103-drawmonster--stub) |
| `playerDeath(source)` | stub | 见 [DeathFlow.md](../0_event/DeathFlow.md) · [待定义方法.md §10.1](../待定义方法.md#101-playerdeath--monsterdeath--stub) |

### 3.8 待定义的 Player 字段/属性

> 详见 [待定义方法.md](../待定义方法.md)。

| 属性签名 | 类型 | 说明 |
|----------|------|------|
| `player.inPhase` | `String` | 当前所处阶段。取值如 `"行动阶段"`。几乎被所有 active 技能 filter 引用 |
| `player.getNumber(name)` | `int` | 按名字获取数值状态。取值如 `"玩家剩余行动次数"`、`"玩家饥饿值"` |
| `player.怪物区` | 区域对象 | 玩家的求生者怪物区。纠缠玩家的怪物卡所在区域 |

---

## 4. Monster 怪物实体（待实现）

**类声明**：`class_name Monster extends Entity`（待实现）
**职责**：怪物卡实体化后的对象，与玩家纠缠，按射程攻击玩家。
**设计来源**：[C_gameSetup.md](../../GameInstructions/C_gameSetup.md#抓取怪物卡)（怪物属性）、[MonsterPacks/](../../Resource/MonsterPacks/) 各怪物包定义。

> **当前状态**：Monster 类尚未在 `scripts/system/` 中实现。设计文档（[DeathFlow.md](DeathFlow.md) `monsterDeath`、[J_gameEventFlow.md](../../GameInstructions/J_gameEventFlow.md) 怪物行动流程等）已大量引用怪物属性，本节为设计目标。

### 4.1 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `名字` | `String` | 怪物卡名字（如 `"僵尸女王"`）。玩家可见文本 |
| `怪物级别` | `String` | 取值 `"首领"` / `"精英"` / `"普通"`。影响怪物属性与技能 |
| `怪物类型` | `String` | 取值 `"外星人"` / `"突变体"` / `"僵尸"` / `"机器人"`。对应不同怪物包 |
| `最大生命值` | `int` | 最大生命值上限 |
| `_生命值` | `int` | 当前生命值。≤ 0 时进入 [怪物死亡流程](DeathFlow.md) |
| `攻击伤害` | `int` | 攻击造成的伤害值 |
| `射程` | `String` | 取值 `"无"` / `"短距离"` / `"中距离"` / `"长距离"` / `"Infinity"`。详见 [F_gameRange.md](../../GameInstructions/F_gameRange.md) 怪物射程 |
| `纠缠对象` | `Player` | 怪物所纠缠的玩家。一个怪物在同一时刻只能纠缠一个玩家。怪物只攻击其纠缠对象所在地块的玩家（按射程） |
| `_skills` | `Array[Skill]` | 继承自 Entity。怪物的固有技能 |

### 4.2 公有方法（设计目标）

| 方法签名 | 说明 |
|----------|------|
| `get_hp() -> int` | 当前生命值（重写 Entity） |
| `reduce_hp(num: int) -> void` | 直接扣血（重写 Entity） |
| `is_monster() -> bool` | 是否为怪物。返回 `true` |
| `monsterDeath(source: Variant) -> void` | 怪物死亡流程。规则见 [DeathFlow.md](DeathFlow.md) |
| `击晕(source, until=)` | 击晕怪物直到指定时机。`until` 取值如 `"下个回合开始时"` |
| `修改纠缠对象(target)` | 修改怪物的纠缠对象为目标玩家 |

### 4.3 实体化时机

> 详见 [DrawFlow.md](../DrawFlow.md) 抓取怪物卡流程。

怪物卡从怪物牌堆抓取后，在"怪物卡进入求生者怪物区前/时"之间实体化：
1. 设置 `纠缠对象 = player`（抓取者）
2. 初始化 `_生命值 = 最大生命值`
3. 置入玩家的 `怪物区`

### 4.4 怪物行动

> 详见 [I_monsterAction.md](../../GameInstructions/I_monsterAction.md) · [J_gameEventFlow.md §9](../../GameInstructions/J_gameEventFlow.md#9-怪物行动流程)。

玩家回合节点 17「面前怪物行动时」会按怪物卡进入怪物区的先后顺序逐个行动：怪物行动前 → 怪物行动时 → 怪物攻击前 → 怪物攻击时（按射程对目标发动攻击） → 怪物攻击后 → 怪物行动后。

---

## 5. MapBlock 地图块实体

**类声明**：`class_name MapBlock extends Entity`
**职责**：地图块实体，管理展示状态、怪物标记、地块上的玩家与怪物。
**代码对齐**：[scripts/system/map_block.gd](../../../scripts/system/map_block.gd)

### 5.1 成员变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `monster_spawn_value` | `int` | `0` | 怪物生成点数（匹配 `judge()` 结果，2-12）。怪物出生检定时，投骰结果匹配的地块生成怪物 |
| `_revealed` | `bool` | `false` | 是否已展示（翻开）。玩家首次进入时翻开，触发「展示地块时」 |
| `_monster_marks` | `int` | `0` | 怪物标记数（0-3）。标记 = 3 且有玩家时，玩家抓怪物卡而非加标记 |
| `_monsters` | `Array` | `[]` | 地块上的怪物列表（与玩家交战的怪物） |
| `_players` | `Array` | `[]` | 地块上的玩家列表 |
| `_skills` | `Array[Skill]` | `[]` | 继承自 Entity。地块技能 |

### 5.2 待定义的字段

> 详见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md) · [待定义方法.md §3](../待定义方法.md#3-mapblock-方法mapblockxxx)。

| 属性签名 | 类型 | 说明 |
|----------|------|------|
| `名字` | `String` | 地图块名称（如 `"面包车"`、`"避难所"`） |
| `拾荒颜色` | `Array[String]` | 该地块可拾荒的牌堆颜色集合（红/绿/蓝子集）。无颜色表示该地块不可拾荒 |

### 5.3 公有方法

| 方法签名 | 说明 |
|----------|------|
| `is_revealed() -> bool` | 是否已展示 |
| `countMonsterMark() -> int` | 怪物标记数（0-3） |
| `addMonsterMark(num: int) -> void` | 添加 `num` 个怪物标记 |
| `removeAllMonsterMarks() -> void` | 移除所有怪物标记 |
| `hasPlayer() -> bool` | 地块上是否有玩家 |
| `countMonster() -> int` | 地块上的怪物数 |
| `addPlayer(entity: Variant) -> void` | 添加玩家到地块 |
| `removePlayer(entity: Variant) -> void` | 移除玩家 |
| `get_players() -> Array` | 地块上的所有玩家（返回副本） |
| `set_revealed(revealed: bool) -> void` | 设置已展示（测试与后续展示机制用） |

### 5.4 待定义的方法

| 方法签名 | 说明 |
|----------|------|------|
| `展示(触发效果=, player)` | 展示地块，可选是否触发「展示地块时」钩子 |
| `有怪物标记()` | 判断是否有怪物标记 |
| `移除怪物标记(n)` | 移除 n 个怪物标记 |
| `有怪物()` | 判断地块上是否有交战怪物（区别于"有怪物标记"） |
| `hasSkill(name)` / `有技能(name)` | 判断地块是否有指定技能。**命名待统一**，见 [待定义方法.md §9.13](../待定义方法.md#913-mapblockhasskill-与-mapblock有技能-命名统一) |
| `清除技能(player)` | 清除挂载到 player 的本地块技能 |
| `removeMapBlock()` | 摧毁/移除地图板块（自然语言待实现） |
| `移除任务标记()` | 移除地块上的任务标记 |
| `加油(n, player)` | 玩家往面包车添加 n 个燃料（仅面包车地图块具备） |

---

## 6. RoleCard 角色卡

**类声明**：`class_name RoleCard extends RefCounted`
**职责**：角色卡牌，管理正反面状态。饥饿值达 6 后翻面，叠加饥饿伤害标记；减少饥饿值后恢复正面。
**代码对齐**：[scripts/system/role_card.gd](../../../scripts/system/role_card.gd)

### 6.1 成员变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `_is_front` | `bool` | `true` | 角色卡当前是否正面朝上 |

### 6.2 公有方法

| 方法签名 | 说明 |
|----------|------|
| `is_front() -> bool` | 角色卡当前是否正面朝上 |
| `flip() -> void` | 翻面：正 ↔ 反切换 |

### 6.3 翻面时机

- **翻为反面**：`player.increaseHunger()` 中，饥饿值达到 6 后翻面 + 叠加饥饿伤害标记
- **翻回正面**：`player.decreaseHunger()` 中，清除饥饿伤害标记后翻回正面

详见 [PlayerState.md](../2_player/PlayerState.md)。

---

## 7. Dice 骰子工具

**类声明**：`class_name Dice extends RefCounted`
**职责**：骰子工具类，提供静态投骰方法。
**代码对齐**：[scripts/system/dice.gd](../../../scripts/system/dice.gd)

### 7.1 静态方法

| 方法签名 | 说明 |
|----------|------|
| `roll_two() -> int` | 投两颗标准骰子（1-6），返回点数和（2-12）。用于 `Player.judge()` |

### 7.2 测试注入

`Player` 通过 `set_dice_roller(roller: Callable)` 注入固定返回值的 roller，绕过 `Dice.roll_two()`。详见 [Player §3.3](#3-状态修改方法底层原子方法不走事件流程)。

---

## 8. 实体与区域对象（待定义）

> 玩家身上的"区域"（手牌区/装备区/怪物区/游戏牌堆/游戏牌弃牌堆）和全局"区域"（怪物牌堆/怪物弃牌堆/三色拾荒牌堆/拾荒弃牌堆）目前作为设计概念存在，尚未在 `scripts/system/` 中定义数据结构。
> 详见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md#游戏初始化)（初始化全局区域与单个玩家区域）。

### 8.1 全局区域

| 区域 | 说明 | 牌堆空时行为 |
|------|------|--------------|
| 怪物牌堆 | 抓怪物卡的来源 | 重洗怪物弃牌堆组成新牌堆；重洗后仍空 → `game.gameOver("lose")` |
| 怪物弃牌堆 | 死亡/弃置的怪物卡进入此处 | 用于重洗为新怪物牌堆 |
| 三色拾荒牌堆 | 红/绿/蓝三色牌堆 | **不重洗**拾荒弃牌堆，停止抓取 |
| 拾荒弃牌堆 | 使用后的拾荒卡放置此处（不分颜色） | — |
| 卡牌结算区 | 卡牌结算时放置区（暂未在流程中使用） | — |

### 8.2 玩家区域

| 区域 | 说明 | 牌堆空时行为 |
|------|------|--------------|
| 求生者角色卡 | 玩家状态卡（生命值/饥饿值等）。由 `RoleCard` 类管理 | — |
| 求生者手牌区 | 手牌所在区域。手牌上限 10 | — |
| 求生者装备区 | 装备牌所在区域。有容量限制（装备栏） | — |
| 求生者怪物区 | 纠缠玩家的怪物卡所在区域 | — |
| 求生者游戏牌堆 | 抓游戏牌的来源 | **不重洗**游戏牌弃牌堆；牌堆空时尝试抓牌 → `playerDeath(NULL)` |
| 求生者游戏牌弃牌堆 | 弃置的求生者游戏牌进入此处 | — |

### 8.3 区域对象的方法（待定义）

> 详见 [待定义方法.md §1.6](../待定义方法.md#16-卡牌--牌堆操作)、[§7.4](../待定义方法.md#74-全局对象)。

| 方法签名 | 简述 |
|----------|------|
| `区域对象.isEmpty() -> bool` | 判断区域是否为空 |
| `区域对象.add(card) -> void` | 添加卡牌到区域 |
| `区域对象.draw() -> Card` | 从区域抓取一张卡 |
| `区域对象.remove(card) -> void` | 从区域移除卡牌 |
| `区域对象.getAll() -> Array` | 获取区域所有卡牌 |
| `区域对象.shuffleInto(other) -> void` | 洗入另一区域（如重洗弃牌堆到牌堆） |
| `区域对象.shuffle() -> void` | 洗牌 |
| `区域对象.discardPile` | 拾荒牌堆的弃牌堆子区域 |
