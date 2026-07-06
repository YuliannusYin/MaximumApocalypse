# Card 卡牌类

> 继承：[Entity](../Core/Entity.md)
> 职责：卡牌的通用属性与子类定义。卡牌自带技能（装备技能、行动牌效果、怪物卡技能）。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 类继承关系

```
Card（卡牌基类，继承 Entity）
├── ScavengeCard（拾荒卡）
├── SurvivorGameCard（求生者游戏牌）
│   └── EquipmentCard（装备牌，含填充物）
└── MonsterCard（怪物卡，实体化前）
```

---

## Card 基类

### 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 名字 | String | 卡牌名称 |
| 类型 | String | 卡牌类型（如"行动"、"装备"、"食物"等） |
| source | String | 卡牌来源："scavenge"（拾荒牌堆）/ "game"（游戏牌堆）/ "monster"（怪物牌堆） |
| 技能 | List\<Skill\> | 卡牌自带技能（继承自 Entity 的 skills） |

### 方法

| 方法 | 说明 |
|------|------|
| 继承自 Entity | trigger / getAllSkills / addSkill / removeSkill |

---

## ScavengeCard 拾荒卡

> 从拾荒牌堆获取的牌。使用后进入拾荒弃牌堆（非游戏牌弃牌堆）。

### 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 颜色 | String | red / green / blue。红色最危险（含伏击！），蓝色最安全 |

### 特殊牌

| 名字 | 颜色 | 说明 |
|------|------|------|
| 伏击！ | red | 抓取时触发怪物进入怪物区流程（在「抓取拾荒牌时」trigger 中处理） |
| 一无所获 | gray | 抓取时立即弃掉 |
| 燃料 | red | 抓取时可选装备或弃掉 |
| 手电筒 | blue | 在「抓取拾荒牌前」取消并替代为「看2留1放1」 |

---

## SurvivorGameCard 求生者游戏牌

> 玩家游戏牌堆中的牌。分为**行动牌**与**装备牌**两种。

### 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 类型 | String | "行动" 或 "装备" |
| 大小 | Int | 占用装备栏的格数（仅装备牌） |
| 射程 | String | 行动牌的射程（无/短距离/中距离/长距离/Infinity），见 [F_gameRange.md](../../GameInstructions/F_gameRange.md) |

### 行动牌

> 即时使用的卡牌。使用后弃掉。
> 装填武器、吃食物和治疗玩家都需要花费行动。

### EquipmentCard 装备牌

> 装备到装备区的卡牌。占用装备栏格数（由 `大小` 决定）。

#### 填充物相关字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 填充物类型 | String | 弹药 / 燃料 / 空尖弹 等 |
| 填充物上限 | Int | 装备卡填充物上限。补满填充物时不超过此值 |
| 填充物当前量 | Int | 当前填充物数量。耗尽时触发「弹药耗尽时」trigger |

#### 装备技能挂载

装备牌进入装备区时，其技能挂载到 Player 身上（见 [Player.装备](Player.md#装备)）；离开装备区时移除（见 [Player.卸下](Player.md#卸下)）。

---

## MonsterCard 怪物卡

> 怪物牌堆中的卡。进入玩家怪物区时**实体化**为 [Monster](Monster.md) 实例（见 [Player.drawMonster](Player.md#drawmonster) 节点 2d）。

### 字段（卡面数据）

| 字段 | 类型 | 说明 |
|------|------|------|
| 怪物类型 | String | 外星人 / 突变体 / 僵尸 / 机器人 |
| 怪物级别 | String | 首领 / 精英 / 普通 |
| 最大生命值 | Int | 怪物生命值上限 |
| 伤害值 | Int | 怪物攻击伤害 |
| 射程 | String | 无 / 短距离 / 中距离 / 长距离 / Infinity |
| 技能 | List\<Skill\> | 怪物技能 |

### 首领卡

> 特殊怪物卡。任务特殊设置中洗入怪物牌堆。

### 实体化

怪物卡进入玩家怪物区时，复制卡面数据到 Monster 实例：

```gdscript
function MonsterCard.实体化(player) {
    monster = new Monster()
    monster.类型 = self.怪物类型
    monster.级别 = self.怪物级别
    monster.最大生命值 = self.最大生命值
    monster.当前生命值 = self.最大生命值
    monster.伤害值 = self.伤害值
    monster.射程 = self.射程
    monster.技能 = self.技能
    monster.纠缠对象 = player
    return monster
}
```

---

## 卡牌使用流程

> 使用卡牌的规则见 [H_useCard.md](../../GameInstructions/H_useCard.md)。
> 从手牌中使用一张卡牌需要花费一个行动。即时卡牌作为一个行动使用，按照卡牌文字执行，然后弃掉。
> 装填武器、吃食物和治疗玩家都需要花费行动。使用拾荒卡后放到拾荒弃牌堆中。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。卡牌技能通过 Entity.trigger 触发 |
| [Player](Player.md) | 玩家手牌区/装备区/牌堆持有卡牌；装备牌技能挂载到 Player |
| [Monster](Monster.md) | MonsterCard 实体化为 Monster |
| [Game](../Game/Game.md) | Game 管理各类牌堆 |
| [Pile](../Common/Pile.md) | 卡牌存储在 Pile 实例中 |
| [Skill](../Common/Skill.md) | 卡牌自带技能遵循 Skill 结构 |
