# 技能（Skill）

> 本文档定义游戏中所有"技能"对象的数据结构。
> 技能是挂在实体上的可执行单元：当 `entity.trigger(triggerName, event)` 被调用时，匹配 `trigger` 的技能依次执行 `filter` 与 `content`。
> 与 [EventTrigger.md](EventTrigger.md)（触发机制）、[entity.md](entity.md)（实体）、[event.md](event.md)（事件对象）配套。
> 文档创建日期：2026-07-04 · 技能结构补全日期：2026-07-07

---

## 目录

- [1. Skill 基础结构](#1-skill-基础结构)
- [2. 技能分类](#2-技能分类)
- [3. 通用字段](#3-通用字段)
- [4. active 技能字段（主动技能）](#4-active-技能字段主动技能)
- [5. 被动技能字段](#5-被动技能字段)
- [6. subSkill 子技能（临时技能）](#6-subskill-子技能临时技能)
- [7. 复合目标模式](#7-复合目标模式)
- [8. 选牌字段](#8-选牌字段)
- [9. 各类卡牌的技能载体字段](#9-各类卡牌的技能载体字段)
- [10. 技能字段速查表](#10-技能字段速查表)

---

## 1. Skill 基础结构

**类声明**：`class_name Skill extends Resource`
**职责**：技能数据，包含触发名、过滤函数、内容函数。
**代码对齐**：[scripts/system/skill.gd](../../../scripts/system/skill.gd) · [docs/system-classes.md](../../../docs/system-classes.md#Skill)

### 1.1 基础成员变量（已实现）

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `trigger` | `String` (@export) | `""` | 触发名。单个字符串或用"、"分隔的多个字符串（如 `"游戏开始时、受到伤害时"`） |
| `filter` | `Callable` | `Callable()` | 过滤函数。签名 `(event: Event) -> bool`。无 callable 时返回 `true` |
| `content` | `Callable` | `Callable()` | 内容函数。签名 `(event: Event) -> void`。无 callable 时空操作 |

### 1.2 静态方法

| 方法签名 | 说明 |
|----------|------|
| `make(p_trigger: String, p_filter: Callable = Callable(), p_content: Callable = Callable()) -> Skill` | 静态构造：便于代码中创建技能实例 |

### 1.3 设计原则

- **数据驱动**：技能为 `Resource`，可序列化；`filter`/`content` 为 `Callable`，由代码绑定具体逻辑。
- **触发名优先**：被动技能靠 `trigger` 字段匹配事件钩子；主动技能（active）靠 `active` 字段匹配玩家行动阶段。
- **复合触发**：`trigger` 字段支持「、」分隔的多个触发名，技能 content 内可通过 `trigger == "xxx"` 判断分支（见 [EventTrigger.md](EventTrigger.md)）。
- **延迟字段**：[skill.gd](../../../scripts/system/skill.gd) 当前仅实现 3 个基础字段，设计文档中其他字段（`技能名`/`技能描述`/`active`/`forced`/`selectTarget`/`filterTarget`/`filterTargetRange`/`usable`/`selectCard`/`filterCard`/`position`/`射程`/`skillType`/`complexTarget`/`subSkill`）待按需添加。

---

## 2. 技能分类

按载体与触发方式分类：

| 分类 | 载体 | 触发方式 | skillType | 典型示例 |
|------|------|----------|-----------|----------|
| 角色固有技能 | 求生者 | active 主动 / 被动 | — | firefighter「拳打」（active）、gunslinger「快速拔枪」（被动） |
| 装备技能 | 求生者游戏牌（装备） | active 主动 / 被动 | `"装备"` | firefighter「打火机」（active）、防火头盔（被动） |
| 行动技能 | 求生者游戏牌（行动）/ 拾荒牌（行动牌） | active 主动 | `"行动"` | firefighter「急救包」、green「食物」、red「医疗用品」、blue「弹药」 |
| 怪物技能 | 怪物卡 | 被动 | `"Monster"` | zombie「僵尸女王」、alien「外星收割者」 |
| 地块技能 | 地图块 | 被动 | — | MapBlocks「避难所」、「电厂」、「游乐园」 |
| 临时技能 | 玩家（运行时挂载） | 被动 | — | firefighter「能量饮料_satiety」、gunslinger「扣动扳机让我快乐 subSkill」 |

---

## 3. 通用字段

> 适用于所有技能类型。

| 字段 | 类型 | 说明 |
|------|------|------|
| `技能名` | `String` **\[待实现]** | 技能名称（玩家可见文本）。如 `"拳打"`、`"防火头盔"` |
| `技能描述` | `String` **\[待实现]** | 技能描述（玩家可见文本）。如 `"行动：对一个目标造成2点伤害。"` |
| `trigger` | `String` | 触发名。被动技能必填。支持「、」分隔的多个触发名 |
| `filter` | `Callable` | 过滤函数。签名 `(event: Event) -> bool`。返回 `false` 则不执行 content |
| `content` | `Callable` | 内容函数。签名 `(event: Event) -> void`。技能主体逻辑 |
| `forced` | `bool` **\[待实现]** | 是否强制发动。`true` 时满足 `filter` 即强制执行，玩家不能选择不发动。被动技能常用 |

> **filter 语义**：被动技能的 `filter` 判断"本次触发是否应该执行"（如 firefighter 防火头盔：`filter: true` 表示任意伤害均触发）；active 技能的 `filter` 判断"当前是否可用"（如 `player.inPhase == "行动阶段"`）。

---

## 4. active 技能字段（主动技能）

> 主动技能由玩家在行动阶段主动发动，消耗行动次数。包括角色固有技能中的主动技能、装备技能中的主动技能、行动牌技能。

| 字段 | 类型 | 说明 |
|------|------|------|
| `active` | `String` **\[待实现]** | 激活阶段。当前取值仅 `"行动阶段"`。filter 中常配合 `player.inPhase == "行动阶段"` 判断 |
| `usable` | `int \| "Infinity"` **\[待实现]** | 每回合使用次数限制。`1` = 每回合 1 次（如制衡、交易），`Infinity` = 不限次（如加油、野地夹克）。未设置时默认每回合可多次使用（受行动次数限制） |
| `射程` | `String` **\[待实现]** | 武器/攻击技能的射程。取值 `"无"` / `"短距离"` / `"中距离"` / `"长距离"` / `"Infinity"`。详见 [F_gameRange.md](../../GameInstructions/F_gameRange.md) |
| `selectTarget` | `int \| [int, int]` **\[待实现]** | 选择目标数量。`1` = 选 1 个，`-1` = 选所有匹配目标，`[1, 3]` = 选 1-3 个，`0` 或不设置 = 无需选目标（自身技能） |
| `filterTarget` | `Callable` **\[待实现]** | 目标过滤函数。签名 `(target) -> bool`。常见判断：`target.type == Monster`、`target == player`、`target.在玩家装备区内` |
| `filterTargetRange` | `String` **\[待实现]** | 目标射程过滤。取值同 `射程`。系统按 [F_gameRange.md](../../GameInstructions/F_gameRange.md) 的射程地图筛选可达目标 |

### 4.1 active 技能 filter 常见模式

```gdscript
# 标准模式：行动阶段 + 有剩余行动次数
filter: return player.inPhase == "行动阶段" && player.getNumber("玩家剩余行动次数") > 0

# 装备武器模式：行动阶段 + 有行动次数 + 有填充物
filter: return player.inPhase == "行动阶段"
    && player.getNumber("玩家剩余行动次数") > 0
    && player.get填充物数量("打火机") > 0

# 食物模式：行动阶段 + 有行动次数 + 饥饿值大于1
filter: return player.inPhase == "行动阶段"
    && player.getNumber("玩家剩余行动次数") > 0
    && player.getNumber("玩家饥饿值") > 1

# 免费行动模式：行动阶段（不消耗行动次数）
filter: return player.inPhase == "行动阶段"
    && getPlayerNumber(player.get_current_block()) > 1  # 交易：地块有其他玩家
```

### 4.2 active 技能 content 常见模式

```gdscript
# 攻击型
content: {
    player.减少行动次数(1)
    player.消耗填充物(1, "打火机")  # 装备武器
    List = event.target  # 经 filter 筛选后的目标列表
    for i in List:
        i.damage(3, player)
}

# 自身效果型（食物、医疗用品）
content: {
    player.减少行动次数(1)
    player.decreaseHunger(1)  # 或 player.recover(2)
}

# 复杂行动型（移动+抓牌）
content: {
    player.减少行动次数(1)
    # ... 多步逻辑
    player.moveTo(target)
    player.draw(1)
}
```

---

## 5. 被动技能字段

> 被动技能由 `trigger` 匹配事件钩子自动触发。包括装备被动、怪物被动、地块被动、角色固有被动、临时技能。

| 字段 | 类型 | 说明 |
|------|------|------|
| `trigger` | `String` | 触发名。必填。详见 [K_gameTerminology.md §7](../../GameInstructions/K_gameTerminology.md#7-事件-trigger) 事件 trigger 列表 |
| `filter` | `Callable` | 过滤函数。判断本次触发是否应该执行 |
| `content` | `Callable` | 内容函数。常见操作：修改 `event.num`、调用 `event.cancel()`、调用其他流程方法 |
| `forced` | `bool` | 是否强制发动。`true` = 满足 filter 即强制执行 |

### 5.1 被动技能 content 常见模式

```gdscript
# 伤害减免（防火头盔、焊接头盔）
content: event.num--  # event.num 减 1

# 伤害取消（避难所）
content: player.免疫伤害()  # 应通过 event.cancel() 实现

# 加摸牌（firefighter 猎犬）
content: event.num += 1  # 抓牌数 +1

# 触发其他流程（感应地雷）
content: {
    player.discard(name = "感应地雷", position = "装备区")
    event.target.damage(7, player)
}

# 多触发分支（firefighter 梯子、gunslinger 快速拔枪）
content: {
    if (trigger == "潜行检定前" && event.name == "河流") {
        event.cancel()
    } else if (trigger == "抓取怪物卡前") {
        if (player.choose(["是", "否"]) == "是") {
            player.discard(name = "梯子", position = "装备区")
            event.cancel()
        }
    }
}
```

---

## 6. subSkill 子技能（临时技能）

> 部分技能（如 firefighter 能量饮料、gunslinger 扣动扳机让我快乐、mechanic 检查武器、surgeon、veteran 反击开始）会通过 `player.addTempSkill(skillName, until=)` 添加临时技能到玩家身上，持续到 `until` 时机失效。
> subSkill 是这些临时技能的定义，挂在主技能的 `subSkill` 字段下。

| 字段 | 类型 | 说明 |
|------|------|------|
| `subSkill` | `Dictionary` **\[待实现]** | 子技能定义。键为子技能标识（如 `"satiety"`），值为子技能结构（含 `trigger`/`forced`/`filter`/`content`） |
| `until` | `String` **\[待实现]** | 持续时间。`addTempSkill` 参数，取值如 `"下个回合开始时"`、`"回合结束时"` |

### 6.1 subSkill 结构示例

```gdscript
# firefighter 能量饮料
技能: {
    技能名: "能量饮料"
    active: "行动阶段"
    content: {
        player.减少行动次数(1)
        player.addTempSkill('能量饮料_satiety', until = "下个回合开始时")
        player.draw(1)
    }
    subSkill: {
        satiety: {
            trigger: 饥饿状态结算前
            forced: true
            filter: true
            content: event.cancel()  # 跳过本次饥饿状态结算
        }
    }
}
```

### 6.2 subSkill 与主技能的关系

- subSkill 通过 `player.addTempSkill(skillName, until=)` 挂载到玩家身上，作为独立技能参与 `entity.trigger`。
- subSkill 失效时机由 `until` 决定，常见时机：`"下个回合开始时"`、`"回合结束时"`。
- subSkill 内可访问主技能 content 中的局部变量？**待澄清**（当前未在代码中实现）。

---

## 7. 复合目标模式

> 部分技能需要同时选择两类目标（如 gunslinger 集中射击：先选武器 + 再选攻击目标）。复合目标模式通过 `complexTarget` 标识。

| 字段 | 类型 | 说明 |
|------|------|------|
| `complexTarget` | `bool` **\[待实现]** | 是否启用复合目标模式。`true` 时使用 `filterTarget1`/`filterTarget2` 而非 `filterTarget`/`filterTargetRange` |
| `filterTarget1` | `Callable` **\[待实现]** | 第一类目标过滤（如装备区内的武器） |
| `filterTarget2` | `bool` **\[待实现]** | 第二类目标过滤（如任意目标） |
| `filterTarget2Range` | `String` **\[待实现]** | 第二类目标的射程过滤 |

### 7.1 复合目标示例

```gdscript
# gunslinger 集中射击
技能: {
    技能名: "集中射击"
    射程: "长距离"
    skillType: "行动"
    active: "行动阶段"
    filter: return player.inPhase == "行动阶段" && player.getNumber("玩家剩余行动次数") > 0
    complexTarget: true
    filterTarget1: return target.在玩家装备区内
        && target.填充物类型 == "弹药"
        && target.当前填充数 > 0  # 装备区内有弹药的武器
    filterTarget2: true  # 任何目标都可用
    filterTarget2Range: "长距离"
    content: {
        player.减少行动次数(1)
        target1.消耗填充物(1, "弹药")
        target2.damage(5, player)
    }
}
```

> **content 内变量**：复合目标模式下，content 内通过 `target1`/`target2` 访问两类选中目标。

---

## 8. 选牌字段

> 部分技能（如制衡、交易）需要玩家选牌。这些字段定义选牌的数量与过滤条件。

| 字段 | 类型 | 说明 |
|------|------|------|
| `selectCard` | `int` **\[待实现]** | 需选择的牌数。如制衡 `2`、交易 `1` |
| `filterCard` | `Callable` **\[待实现]** | 选牌过滤函数。签名 `(card) -> bool`。常见判断：`getSource(card) == player`（玩家游戏牌）、`getSource(card) == scavenge`（拾荒牌） |
| `position` | `String` **\[待实现]** | 选牌位置限定。如 `"手牌区"` |

### 8.1 选牌示例

```gdscript
# 制衡
技能: {
    技能名: "制衡"
    active: "行动阶段"
    usable: 1  # 每回合 1 次
    filter: return player.inPhase == "行动阶段"
    selectCard: 2
    filterCard: return getSource(card) == player  # 只能选玩家游戏牌
    position: "手牌区"
    content: {
        player.discard(cards)
        player.draw(1)
    }
}

# 交易
技能: {
    技能名: "交易"
    active: "行动阶段"
    usable: 1
    filter: return player.inPhase == "行动阶段"
        && getPlayerNumber(player.get_current_block()) > 1
    selectCard: 1
    filterCard: return getSource(card) == scavenge
    position: "手牌区"
    selectTarget: 1
    filterTargetRange: "短距离"
    filterTarget: return target.hasScavengeCard() && target != player
    content: { /* ... */ }
}
```

---

## 9. 各类卡牌的技能载体字段

> 技能挂在卡牌/实体上，卡牌本身有自己的属性字段。下表列出各类卡牌的载体字段（非技能字段）。

### 9.1 求生者游戏牌

> 详见 [SurvivorPacks/](../../Resource/SurvivorPacks/) 各文件。

| 字段 | 类型 | 说明 |
|------|------|------|
| `名字` | `String` | 卡牌名字（如 `"防火头盔"`） |
| `牌堆中数量` | `int` | 该牌在求生者游戏牌堆中的数量 |
| `类型` | `String` | `"装备"` 或 `"行动"` |
| `大小` | `String` | 占用装备栏格数（如 `"1格装备栏"`、`"2格装备栏"`）。仅装备牌有此字段 |
| `填充物上限` | `int` | 装备卡填充物上限。仅可填充装备有此字段 |
| `初始填充数` | `int` | 装备卡初始填充数。仅可填充装备有此字段 |
| `填充物类型` | `String` | 装备卡填充物类型。取值如 `"弹药"`、`"燃料"`。仅可填充装备有此字段 |
| `技能` | `Skill` | 该牌的技能 |

### 9.2 求生者角色卡

> 详见 [SurvivorPacks/](../../Resource/SurvivorPacks/) 各文件 `## 角色详情` 部分。

| 字段 | 类型 | 说明 |
|------|------|------|
| `角色名称` | `String` | 角色名（如 `"消防员"`） |
| `生命值上限` | `int` | 最大生命值上限（如消防员 32） |
| `初始生命值` | `int` | 初始生命值 |
| `潜行值` | `int` | 基础潜行值（如消防员 6） |
| `饥饿状态潜行值` | `int` | 角色卡翻面后的潜行值（如消防员 5） |
| `技能` | `Skill` | 角色固有技能 |

### 9.3 怪物卡

> 详见 [MonsterPacks/](../../Resource/MonsterPacks/) 各文件。

| 字段 | 类型 | 说明 |
|------|------|------|
| `名字` | `String` | 怪物卡名字（如 `"僵尸女王"`） |
| `怪物级别` | `String` | `"首领"` / `"精英"` / `"普通"` |
| `怪物类型` | `String` | `"外星人"` / `"突变体"` / `"僵尸"` / `"机器人"` |
| `最大生命值` | `int` | 最大生命值上限 |
| `初始生命值` | `int` | 实体化时的初始生命值（通常 = 最大生命值） |
| `攻击伤害` | `int` | 攻击造成的伤害值 |
| `射程` | `String` | `"无"` / `"短距离"` / `"中距离"` / `"长距离"` / `"Infinity"` |
| `技能` | `Skill` 或 `无` | 该怪物的技能。普通怪物常为 `无` |

### 9.4 拾荒牌

> 详见 [ScavengePacks/](../../Resource/ScavengePacks/) 各文件。

| 字段 | 类型 | 说明 |
|------|------|------|
| `大类` | `String` | 拾荒牌大类（如 `"战备"`、`"食物"`、`"补给"`） |
| `颜色` | `String` | `"蓝色"` / `"绿色"` / `"红色"` |
| `类型` | `String` | 卡牌类型（如 `"行动牌"`） |
| `名字` | `String` | 拾荒牌名字（如 `"弹药（少量）"`） |
| `数值` | `int` | 数值参数（如弹药数、恢复量、饥饿值减少量） |
| `技能` | `Skill` | 该牌的技能 |

### 9.5 地图块

> 详见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。

| 字段 | 类型 | 说明 |
|------|------|------|
| `地图块名称` | `String` | 地图块名称（如 `"避难所"`） |
| `拾荒颜色` | `Array[String]` | 该地块可拾荒的牌堆颜色集合 |
| `怪物生成点数` | `int` | 怪物生成点数（2-12） |
| `技能` | `Skill` | 该地块的技能 |

---

## 10. 技能字段速查表

| 字段 | 类型 | 适用技能类型 | 说明 |
|------|------|--------------|------|
| `技能名` | `String` | 全部 | 技能名称（玩家可见） |
| `技能描述` | `String` | 全部 | 技能描述（玩家可见） |
| `trigger` | `String` | 被动 | 触发名，支持「、」分隔 |
| `filter` | `Callable` | 全部 | 过滤函数 `(event) -> bool` |
| `content` | `Callable` | 全部 | 内容函数 `(event) -> void` |
| `forced` | `bool` | 被动 | 是否强制发动 |
| `active` | `String` | active | 激活阶段（`"行动阶段"`） |
| `usable` | `int \| "Infinity"` | active | 每回合使用次数限制 |
| `射程` | `String` | active | 武器射程 |
| `selectTarget` | `int \| [int, int]` | active | 选择目标数量 |
| `filterTarget` | `Callable` | active | 目标过滤函数 |
| `filterTargetRange` | `String` | active | 目标射程过滤 |
| `complexTarget` | `bool` | active | 是否复合目标模式 |
| `filterTarget1` | `Callable` | active（复合） | 第一类目标过滤 |
| `filterTarget2` | `bool` | active（复合） | 第二类目标过滤 |
| `filterTarget2Range` | `String` | active（复合） | 第二类目标射程过滤 |
| `selectCard` | `int` | active | 选牌数量 |
| `filterCard` | `Callable` | active | 选牌过滤函数 |
| `position` | `String` | active | 选牌位置限定 |
| `skillType` | `String` | 装备/行动/怪物 | 卡牌类型标识 |
| `subSkill` | `Dictionary` | 临时技能载体 | 子技能定义 |
| `until` | `String` | 临时技能 | 持续时间 |

> **命名风格**：技能字段大量使用中文标识符（`技能名`/`技能描述`/`射程`/`填充物上限`等），与代码字段（`trigger`/`filter`/`content`/`forced` 等英文）并存。这是历史设计选择，玩家可见文本与配置字段用中文，运行时机制字段用英文。
