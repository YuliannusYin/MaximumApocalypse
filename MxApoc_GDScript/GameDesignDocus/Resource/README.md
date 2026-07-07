# Resource 数据定义

> 卡牌、地图块、任务等游戏数据的具体定义。
> 技能伪代码中的流程方法定义见 [GameSystem/](../GameSystem/README.md)，规则说明见 [GameInstructions/](../GameInstructions/README.md)。

---

## 目录结构

```
Resource/
│
├── SurvivorPacks/      # 求生者包（角色 + 角色专属游戏牌堆）
│   ├── firefighter.md    消防员
│   ├── gunslinger.md     枪手
│   ├── hunter.md         猎人
│   ├── mechanic.md       机械师
│   ├── surgeon.md        外科医生
│   └── veteran.md        老兵
│
├── ScavengePacks/      # 拾荒牌堆（按颜色分包）
│   ├── blue.md           蓝色（战备类，最安全）
│   ├── green.md          绿色（日常类）
│   ├── red.md            红色（危险类，含伏击）
│   └── gray.md           灰色（通用：一无所获 / 伏击）
│
├── MonsterPacks/       # 怪物包（按类型分包）
│   ├── alien.md          外星人
│   ├── mutant.md         突变体
│   ├── robot.md          机器人
│   └── zombie.md         僵尸
│
├── MissionPacks/       # 任务包（剧本关卡）
│   └── basic-mission_0.md ~ basic-mission_12.md   13 个任务
│
└── MapBlocksPack/      # 地图块包
    └── MapBlocks.md      全部地图块定义
```

---

## 数据格式

### 求生者包（SurvivorPacks/）

每个文件定义一个求生者角色，包含：

```
求生者{
    角色名称: <名字>
    生命值上限: <数值>
    初始生命值: <数值>
    潜行值: <数值>
    饥饿状态潜行值: <数值>
    技能: { ... }              # 角色固有技能（非卡牌，开局即拥有）
}

求生者游戏牌{                   # 角色专属游戏牌堆中的每张牌
    名字: <牌名>
    牌堆中数量: <数值>
    类型: 装备 / 行动
    大小: <格数>                # 装备牌占用的装备栏格数
    填充物上限/初始填充数/填充物类型:  # 装备牌可选字段
    技能: { ... }
}
```

### 拾荒牌堆（ScavengePacks/）

每个文件定义一种颜色的拾荒牌堆，包含多张拾荒牌：

```
拾荒牌{
    大类: 战备 / 日常 / 通用
    颜色: 蓝色 / 绿色 / 红色 / 灰色
    类型: 行动牌 / 装备牌
    名字: <牌名>
    数值: <数值或无>            # 弹药数、食物恢复量等
    大小: <格数>                # 装备牌可选
    填充物上限/初始填充数/填充物类型:  # 装备牌可选
    技能: { ... }
}
```

颜色对应难度：蓝色最安全（战备类）、绿色（日常类）、红色最危险（含伏击）、灰色为通用牌（一无所获 / 伏击）。

### 怪物包（MonsterPacks/）

每个文件定义一种类型的怪物包，包含多张怪物卡：

```
# 文件头注释说明本包怪物类型、级别体系、trigger 映射关系

怪物卡{
    名字: <怪物名>
    怪物级别: 首领 / 精英 / 普通
    怪物类型: "外星人" / "突变体" / "僵尸" / "机器人"
    最大生命值: <数值>
    初始生命值: <数值>
    攻击伤害: <数值>
    射程: "无" / "短距离" / "中距离" / "长距离"
    技能: { ... } 或 无         # 普通怪通常无技能
}
```

怪物卡进入玩家怪物区时**实体化**，获得纠缠对象、当前生命值等运行时属性。详见 [Monster.md](../GameSystem/Entities/Monster.md)。

### 任务包（MissionPacks/）

每个文件定义一个任务关卡：

```
任务名: <名字>
任务难度: <难度等级>
启动面包车所需燃料: <数值或NULL>
任务介绍: <剧情文本>
任务目标: <目标说明>
任务特殊设置: <初始状态>
任务怪物包类型: <引用 MonsterPacks 中的包名>
任务地图块配置: <地图块列表与数量>
任务地图要求: <网格矩阵 + 特殊位置地块名 + 目标标记定义>
任务拾荒牌堆配置: <三色牌堆的牌组成>
```

> **启动面包车所需燃料**：数值表示该任务需往面包车添加指定燃料才能胜利；`NULL` 表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时胜利条件由任务目标定义，通过 `game.任务配置.检查胜利条件()` 函数判断。详见 [GameSystem/Game/Game.md 任务配置结构](../GameSystem/Game/Game.md#任务配置结构missionconfig)。

#### 任务地图要求格式

任务地图要求由三部分组成：**默认地图**（二维数组）+ **特殊位置地块名** + **目标标记定义**。

```
## 任务地图要求

默认地图 = [
    [-1, -1, 1, 1, 2],
    [0, 1, 1, -1, 1],
    [-1, 1, 3, 1, -1]
]

无地块 = -1
出生点 = 0 = "购物中心"          # 编号 0 的位置使用指定地块名
未知随机地块 = 1                  # 从任务地图块配置的地块池中随机抽取
游戏结束点 = 2 = "面包车"         # 编号 2 的位置使用指定地块名
标记地块 = 3                     # 编号 3 的位置从地块池随机抽取 + 添加目标标记 + 预置怪物标记

## 目标标记定义（如有标记地块）

目标标记1 {
    标记ID: "标记1"
    标记描述: "收集 3 个多余零件和 2 个医疗用品"
    标记效果: (player) => {
        # 伪代码：直接将指定卡牌添加到玩家手牌区（不从拾荒牌堆拿取）
        player.收集物品("多余零件", 3)
        player.收集物品("医疗用品", 2)
    }
}

目标标记2 {
    标记ID: "标记2"
    标记描述: "抓取首领卡，收集 3 个脏毯子"
    标记效果: (player) => {
        player.drawBossCard()
        player.收集物品("脏毯子", 3)
    }
}

目标标记3 {
    标记ID: "标记3"
    标记描述: "被守卫的目标：预置 3 个怪物标记，清除所有怪物标记后移除"
    初始怪物标记数: 3                # 地图构建时为地块预置的怪物标记数（默认 0）
    移除条件: (block) => {           # 每次 removeMonsterMark 后检查，返回 true 时自动移除标记（默认 NULL）
        return block.countMonsterMark() == 0
    }
    标记效果: (player) => {
        game.log(player.名字 + " 发现了被守卫的目标！清除所有怪物标记以移除。")
    }
}
```

> **构建逻辑**：详见 [Game.buildMap](../GameSystem/Game/Game.md#buildmapmissionconfig)。
> - `-1`（无地块）→ 跳过
> - `0`（出生点）→ 使用指定地块名实例化
> - `1`（未知随机地块）→ 从地块池随机抽取
> - `2`（游戏结束点）→ 使用指定地块名实例化
> - `3`（标记地块）→ 从地块池随机抽取 + 按顺序添加目标标记 + 按 `初始怪物标记数` 预置怪物标记
>
> **目标标记**：玩家进入标记地块时触发效果（一次性）。标记效果由任务包定义，详见 [MapBlock 目标标记结构](../GameSystem/Entities/MapBlock.md#目标标记结构objectivemark)。
>
> **初始怪物标记数**：标记地块可预置怪物标记（任务 9 每个 2 个、任务 11 每个 3 个）。预置的怪物标记与怪物出生检定添加的标记共用同一字段，上限 3。
>
> **移除条件**：声明 `移除条件` 的标记在 `removeMonsterMark` 后自动检查，条件满足时调用 `removeObjectiveMark(mark)` 移除标记。典型场景：任务 11「清除所有怪物标记后移除目标标记」。未声明 `移除条件` 的标记只能通过炸药等技能或摧毁地块移除。

### 地图块包（MapBlocksPack/）

`MapBlocks.md` 定义全部地图块，分两部分：

1. **地图块配置**：`名字[拾荒牌堆颜色][刷怪点数]` 列表
2. **地图块详情**：每个地块的技能定义

```
地图块{
    地图块名称: <名字>
    技能: {
        技能名: <名字>
        技能描述: <描述>
        trigger: 展示地块时 / 进入地块时 / 进入地块前 / 离开地块时 / 回合开始时 / 回合结束时 / ...
        filter: { ... }
        content: { ... }
    }
}
```

地块技能在玩家进入地块时**挂载到 Player 身上**，由 `player.trigger()` 统一触发；离开时清理。详见 [MapBlock.md](../GameSystem/Entities/MapBlock.md)。

---

## 与 GameSystem/ 的关系

| 本目录（数据） | GameSystem/（流程定义） |
|------|------|
| 卡牌技能的 `content` 伪代码 | 调用 [Player](../GameSystem/Entities/Player.md) / [Monster](../GameSystem/Entities/Monster.md) / [Game](../GameSystem/Game/Game.md) 的方法 |
| 卡牌技能的 `trigger` 字段 | 引用 [EventSystem.md](../GameSystem/Core/EventSystem.md) 定义的 trigger 名 |
| 技能结构（字段规范） | 由 [Skill.md](../GameSystem/Common/Skill.md) 定义 |
| 怪物卡实体化 | 由 [Monster.md](../GameSystem/Entities/Monster.md) 实体化流程处理 |
| 地图块技能挂载 | 由 [Player.moveTo](../GameSystem/Entities/Player.md#moveto) 在进入地块时挂载 |

> **技能伪代码中的方法调用**（如 `player.damage()`、`target.recover()`、`player.drawMonster()`）均定义在 GameSystem/ 中。遇到不熟悉的方法时，查阅 [GameSystem/README.md 的核心流程速查表](../GameSystem/README.md#核心流程速查)。
