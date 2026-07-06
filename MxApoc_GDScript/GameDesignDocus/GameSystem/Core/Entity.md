# Entity 实体基类

> 所有可挂载技能、可触发事件的实体的基类。
> 继承关系：Entity ← Player / Monster / Card / MapBlock
> 事件触发机制详见 [EventSystem.md](EventSystem.md)。

---

## 设计职责

Entity 基类负责：

1. **技能挂载**：维护实体身上的技能列表（角色固有技能、装备技能、地块技能、临时技能等）
2. **事件触发**：提供统一的 `trigger(triggerName, event)` 接口，遍历技能并执行匹配的 content
3. **通用流程**：提供跨子类共享的流程方法（如 `damage` 伤害流程）
4. **通用接口**：声明子类需实现的抽象方法（如 `death`）与通用查询接口

---

## 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| skills | List\<Skill\> | 挂载在该实体上的所有技能。`getAllSkills()` 返回此列表 |

> 子类各自扩展字段（如 Player 的 HP/饥饿/手牌区，Monster 的纠缠对象/射程等），详见各子类文档。

---

## 方法

### 1. 事件触发

#### entity.trigger(triggerName, event)

遍历实体上所有匹配 `triggerName` 的技能，依次执行。

> 机制详解、event schema、命名规范、全 trigger 索引见 [EventSystem.md](EventSystem.md)。

```gdscript
# 遍历实体上所有匹配 triggerName 的技能，依次执行。
# entity.getAllSkills() 返回该实体上所有技能（含角色固有技能、装备技能、临时技能等）。
# 技能 content 执行时，上下文中可访问以下变量：
#   - event：事件对象（按流程类型含不同字段：伤害流程 event.target/source/num/type；移动流程 event.targetBlock；抓牌流程 event.card；主动技能 event.targets；详见 EventSystem.md §2.2）
#   - trigger：当前触发的触发名称字符串（用于 trigger == "xxx" 判断多触发技能的分支）
# 技能的 trigger 字段可以是单个字符串（如 "造成伤害时"）或 "、" 分隔的多个字符串（如 "游戏开始时、受到伤害时"）。
function entity.trigger(triggerName, event) {
    event.triggerName = triggerName
    skills = entity.getAllSkills()
    for s in skills {
        triggerList = s.trigger.split("、")
        if (triggerList.contains(triggerName) && s.filter(event)) {
            s.content(event)
            if (event.cancelled) {
                break
            }
        }
    }
}
```

---

### 2. 技能挂载

#### entity.getAllSkills()

返回该实体身上的所有技能列表（含固有技能、装备技能、临时技能、地块技能等）。

#### entity.addSkill(skill)

向实体挂载一个技能（如地块技能挂载到玩家身上、装备技能随装备加入）。

#### entity.removeSkill(skill)

从实体移除一个技能（如装备离开装备区、离开地块时清理地块技能）。

---

### 3. 伤害流程（通用）

#### entity.damage(num, source, type = NULL)

> 「target 受到来自于 source 的 num 点类型为 type 的伤害」的流程方法。
> target 与 source 均为 Entity 子类实例（Player 或 Monster）。
> source = NULL 时表示无来源伤害（如饥饿伤害、中毒伤害），跳过所有 source 侧钩子。
> 流程节点 8 触发死亡判定，调用 target 的 `death(source)`（多态：Player 走 playerDeath，Monster 走 monsterDeath）。

**事件钩子顺序**：

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 造成伤害前 | source | source != NULL 时触发 |
| 2 | 受到伤害前 | target | 始终触发（含无来源伤害） |
| 3 | 造成伤害时 | source | source != NULL 时触发；可修改 `event.num`（伤害加成） |
| 4 | 受到伤害时 | target | **取消点**；可修改 `event.num`（伤害减免）或调用 `event.cancel()` |
| 5 | （系统扣血） | — | `target.生命值 -= event.num`，非钩子节点 |
| 6 | 造成伤害后 | source | source != NULL 时触发 |
| 7 | 受到伤害后 | target | 始终触发（含无来源伤害） |
| 8 | （死亡判定） | — | `target.生命值 <= 0` → 调用 `target.death(source)` |

**event 成员**：`event.target`、`event.source`（可为 NULL）、`event.num`（可读写）、`event.type`、`event.cancelled`、`event.cancel()`

```gdscript
function entity.damage(num, source, type = NULL) {
    if (num <= 0) {
        return
    }
    if (target.get_hp() <= 0) {
        return
    }

    # 构建事件对象
    event = {
        target: target,
        source: source,
        num: num,
        type: type,
        cancelled: false,
    }

    if (source != NULL) {
        # 1. source 造成伤害前
        source.trigger("造成伤害前", event)
        # 2. target 受到伤害前
        target.trigger("受到伤害前", event)
    } else {
        # 无来源伤害：跳过 source 相关钩子，仅触发 target 受到伤害前
        target.trigger("受到伤害前", event)
    }

    if (source != NULL) {
        # 3. source 造成伤害时 —— 技能可在此阶段修改 event.num（如伤害加成）
        source.trigger("造成伤害时", event)
    }

    # 4. target 受到伤害时 —— 取消点：技能可在此阶段调用 event.cancel() 取消本次伤害
    #    也可在此阶段修改 event.num（如伤害减免）
    target.trigger("受到伤害时", event)

    if (event.cancelled) {
        return
    }

    # 5. 系统内部执行扣血，不对外暴露成事件钩子
    target.reduce_hp(event.num)

    if (source != NULL) {
        # 6. source 造成伤害后
        source.trigger("造成伤害后", event)
    }

    # 7. target 受到伤害后
    target.trigger("受到伤害后", event)

    # 8. 如果目标生命值小于等于零，进入死亡流程（多态调用）
    if (target.get_hp() <= 0) {
        target.death(source)
    }
}
```

> **说明**：原 `DamageFlow.md` 中通过 `target.isPlayer()` / `target.isMonster()` 分支调用 `playerDeath` / `monsterDeath`，此处统一为多态调用 `target.death(source)`，由子类实现具体死亡流程。

---

### 4. 生命值接口（通用）

| 方法 | 说明 |
|------|------|
| `entity.get_hp()` | 返回当前生命值 |
| `entity.get_max_hp()` | 返回最大生命值上限 |
| `entity.reduce_hp(n)` | 直接扣血（底层原子方法，不触发钩子） |
| `entity.add_hp(n)` | 直接加血（底层原子方法，不触发钩子，不受最大值约束） |

> 子类可在此基础上增加受钩子约束的高层方法（如 Player 的 `recover(num)` 走完整 4 节点流程）。

---

### 5. 类型判断

| 方法 | 说明 |
|------|------|
| `entity.isPlayer()` | 是否为 Player 实例 |
| `entity.isMonster()` | 是否为 Monster 实例 |

> 用于流程中需要区分实体类型的场景。多数场景应优先使用多态（如 `death()`）而非类型判断。

---

### 6. 抽象方法（子类实现）

#### entity.death(source)

死亡流程的抽象方法，由子类实现：

- `Player.death(source)` → 调用 `playerDeath(source)`，见 [Player.md](../Entities/Player.md#playerdeath)
- `Monster.death(source)` → 调用 `monsterDeath(source)`，见 [Monster.md](../Entities/Monster.md#monsterdeath)

由 `entity.damage` 流程节点 8 在 target 生命值 ≤ 0 时调用。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| Player | 继承 Entity，扩展玩家状态与玩家专属流程 |
| Monster | 继承 Entity，扩展怪物属性与行动/攻击流程 |
| Card | 继承 Entity，卡牌自带技能（装备技能、行动牌效果、怪物卡技能） |
| MapBlock | 继承 Entity，地块技能挂载到进入的 Player 身上由 Player.trigger 触发 |
| Skill | 通过 `addSkill` / `removeSkill` 挂载到 Entity，见 [Skill.md](../Common/Skill.md) |
