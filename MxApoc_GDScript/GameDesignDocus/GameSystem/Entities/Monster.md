# Monster 怪物类

> 继承：[Entity](../Core/Entity.md)
> 职责：怪物实体的属性、行动/攻击流程与死亡流程。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 实体化

怪物卡从怪物牌堆抓取后，在进入玩家怪物区时**实体化**为 Monster 实例（见 [Player.drawMonster](Player.md#drawmonster) 节点 2d）。实体化时：

- 设置 `纠缠对象` 为抓取它的玩家
- 初始化 `当前生命值 = 最大生命值`
- 从 MonsterCard 卡面数据复制属性到 Monster 实例

> MonsterCard（卡面数据）与 Monster（实体）的关系见 [Card.md](Card.md#monstercard)。

---

## 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 纠缠对象 | Player | 怪物所纠缠的玩家。怪物只攻击其纠缠对象所在地块的玩家（按射程） |
| 类型 | String | 外星人 / 突变体 / 僵尸 / 机器人。对应不同怪物包 |
| 级别 | String | 首领 / 精英 / 普通。影响怪物属性与技能 |
| 最大生命值 | Int | 生命值上限 |
| 当前生命值 | Int | 当前 HP。≤ 0 时进入死亡流程 |
| 伤害值 | Int | 怪物攻击造成的伤害 |
| 射程 | String | 无 / 短距离 / 中距离 / 长距离 / Infinity。决定怪物攻击范围 |
| 技能 | List\<Skill\> | 怪物自带技能（继承自 Entity 的 skills） |
| 击晕 | Bool | 击晕状态。击晕的怪物跳过行动 |

---

## 信号量（triggers）

> 完整 trigger 列表见 [EventSystem.md §4.4](../Core/EventSystem.md#44-怪物类)。

| trigger 名 | 触发时机 |
|-----------|---------|
| 怪物行动前 | 单个怪物行动前 |
| 怪物行动时 | 单个怪物开始行动 |
| 怪物攻击前 | 攻击前 |
| 怪物攻击时 | 根据射程对目标发动攻击 |
| 怪物攻击后 | 攻击后 |
| 怪物行动后 | 单个怪物行动结束 |
| 死亡前 | 怪物死亡前 |
| 死亡时 | 怪物死亡时（如僵尸女王、爆破机器人、方阵机器人） |
| 死亡后 | 怪物死亡后 |

---

## 方法

### 行动流程

> 玩家面前的怪物行动时，按怪物卡进入玩家怪物区的先后顺序行动。
> 触发场景：玩家回合节点 17「面前怪物行动时」（见 [D_gameFlow.md](../../GameInstructions/D_gameFlow.md)）。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 怪物行动前 | 单个怪物行动前 |
| 2 | 怪物行动时 | 怪物开始行动 |
| 3 | 怪物攻击前 | 攻击前 |
| 4 | 怪物攻击时 | 根据射程对目标发动攻击（见 [§攻击流程](#攻击流程)） |
| 5 | 怪物攻击后 | 攻击后；如僵尸潜行者 |
| 6 | 怪物行动后 | 单个怪物行动结束 |

```gdscript
function monster.行动() {
    event = {
        monster: monster,
        目标玩家: [],  # 按射程确定的攻击目标列表
    }

    # 击晕的怪物跳过行动
    if (monster.击晕) {
        monster.击晕 = false  # 击晕仅持续到下次行动
        return
    }

    # 1. 怪物行动前
    monster.trigger("怪物行动前", event)

    # 2. 怪物行动时
    monster.trigger("怪物行动时", event)

    # 3. 怪物攻击前
    monster.trigger("怪物攻击前", event)

    # 4. 怪物攻击时 —— 根据射程对目标发动攻击
    monster.trigger("怪物攻击时", event)
    monster.攻击()

    # 5. 怪物攻击后
    monster.trigger("怪物攻击后", event)

    # 6. 怪物行动后
    monster.trigger("怪物行动后", event)
}
```

> **注**：「怪物行动前/时/后」与玩家回合流程中的「面前怪物行动前/时」是不同层级的 trigger。前者是单个怪物级别，后者是玩家回合阶段级别。

---

### 攻击流程

> 怪物根据射程对目标发动攻击。
> 射程规则见 [F_gameRange.md](../../GameInstructions/F_gameRange.md)。

**怪物射程**（以纠缠玩家所在地块为中心）：

| 射程 | 攻击范围 |
|------|---------|
| 无 | 只攻击纠缠玩家 |
| 短距离 | 纠缠玩家所在地块上的所有玩家 |
| 中距离 | 纠缠玩家所在地块 1-2 格内的所有玩家 |
| 长距离 | 纠缠玩家所在地块 1-3 格内的所有玩家 |
| Infinity | 场上所有玩家 |

```gdscript
function monster.攻击() {
    # 按射程确定攻击目标列表
    目标列表 = getPlayersInRange(monster.纠缠对象.get_current_block(), monster.射程)

    for target in 目标列表 {
        # 对每个目标造成伤害（source = monster）
        target.damage(monster.伤害值, monster, "怪物攻击")
    }
}
```

> **event.目标玩家 的单值与列表歧义**：射程为「无」时单值，其他射程为列表。详见待定义方法文档。

---

### monsterDeath(source)

> 实现 [Entity.death](../Core/Entity.md#6-抽象方法子类实现)。
> 流程：死亡前 → 死亡时（触发怪物死亡事件） → 死亡后（移除怪物卡）。
> 取消点：无（死亡流程不可取消）。
> 触发场景：`entity.damage` 流程节点 8 中怪物生命值 ≤ 0。

```gdscript
function monster.monsterDeath(source) {
    event = {
        target: monster,
        source: source,
    }

    # 1. 怪物死亡前
    monster.trigger("死亡前", event)

    # 2. 怪物死亡时 —— 触发怪物死亡事件（如僵尸女王的技能在此触发）
    monster.trigger("死亡时", event)

    # 3. 怪物死亡后
    # 将怪物卡从求生者怪物区移除，进入怪物卡弃牌堆
    纠缠玩家 = monster.纠缠对象
    纠缠玩家.怪物区.remove(monster)
    怪物弃牌堆.add(monster)

    monster.trigger("死亡后", event)
}
```

> **trigger 别名**：「杀死怪物时」统一映射为「怪物死亡时」。
> **注意**：地图块/技能效果「弃置怪物」（如 hunter 迷彩服）为纯移除，**不**触发怪物死亡流程。

---

### 实体化方法

> 由 [Player.drawMonster](Player.md#drawmonster) 节点 2d 调用。

```gdscript
function monster.实体化(player) {
    monster.纠缠对象 = player
    monster.当前生命值 = monster.最大生命值
}
```

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。复用 trigger / damage / death 抽象方法 |
| [Player](Player.md) | 纠缠玩家；玩家怪物区持有怪物；玩家可攻击怪物 |
| [Card](Card.md) | MonsterCard 实体化后成为 Monster 实例 |
| [Game](../Game/Game.md) | 怪物牌堆/弃牌堆由 Game 管理 |
