# Skill 技能结构

> 职责：定义技能的字段规范，并提供通用行动技能实例。
> Skill **不继承** Entity，是挂载在 Entity 上的数据结构。
> 技能通过 [Entity.trigger](../Core/Entity.md#1-事件触发) 被遍历与执行。

---

## 一、Skill 结构定义

### 完整字段规范

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 技能名 | String | 是 | 技能名称 |
| 技能描述 | String | 是 | 技能效果的自然语言描述 |
| active | String | 否 | 可主动使用的技能声明可用阶段（如"行动阶段"） |
| trigger | String | 否 | 触发名，支持「、」分隔的复合触发（如"游戏开始时、受到伤害时"） |
| skillType | String | 否 | 技能类型（如"装备"、"行动"） |
| forced | Bool | 否 | 是否强制发动（默认 false） |
| filter | Function | 否 | 触发条件过滤函数，参数为 event，返回 Bool |
| filterTarget | Function | 否 | 目标过滤函数，返回 Bool |
| filterTargetRange | String | 否 | 目标距离限制（无/短距离/中距离/长距离/Infinity） |
| filterCard | Function | 否 | 选牌过滤函数 |
| position | String | 否 | 选牌位置限定（如"手牌区"） |
| selectCard | Int | 否 | 需选择的牌数 |
| selectTarget | Int | 否 | 需选择的目标数 |
| 射程 | String | 否 | 攻击型技能的射程 |
| usable | Int / Infinity | 否 | 每回合可用次数限制 |
| content | Function | 是 | 技能效果执行体，参数为 event |

### 技能类型

| 类型 | 说明 |
|------|------|
| 主动技能 | 声明 `active`，玩家在对应阶段主动使用（如通用行动技能） |
| 触发技能 | 声明 `trigger`，在对应事件节点自动触发（如装备技能、地块技能） |
| 被动技能 | 无 active 无 trigger，提供持续性效果（如背包增加装备栏） |

### content 执行上下文

技能 `content(event)` 执行时可访问：

| 变量 | 说明 |
|------|------|
| `event` | 事件对象（结构随流程类型变化，见 [EventSystem §2](../Core/EventSystem.md#2-event-对象-schema)） |
| `trigger` | 当前触发的 trigger 名字符串（复合触发时用于分支判断） |
| `player` | 技能所属的玩家（主动技能与玩家侧触发技能） |
| `target` | 选定的目标（主动技能） |

### 复合触发示例

```
trigger: 回合开始时、受到伤害时
content: {
    if (trigger == "回合开始时") {
        # 回合开始时分支
    } else if (trigger == "受到伤害时") {
        # 受到伤害时分支
    }
}
```

---

## 二、通用行动技能

> 6 个所有玩家共享的通用行动技能。
> 这些技能是 [Player](../Entities/Player.md) 类的固有技能，在行动阶段可用。
> 行动阶段玩家可按任意组合执行共 4 个行动（可多次执行同一行动）。

### 行动选项

1. 横向或竖向移动 1 格（移动技能）
2. 从求生者游戏牌堆中抓 1 张牌（摸牌技能）
3. 从手牌中打出 1 张牌
4. 执行 1 张已经在游戏中的卡牌上的行动
5. 拾荒：根据当前地点押 1 张拾荒卡（拾荒技能）

### 免费行动

- 每回合一次：弃掉两张求生者游戏牌来从游戏牌堆抓一张新牌（制衡技能）
- 每回合一次：与另一名同地图块玩家交易拾荒卡（交易技能）

---

### 移动

```gdscript
Skill{
    技能名："移动"
    技能描述："移动到目标地块"
    active: "行动阶段"
    filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
    filterTarget: return target != player.get_current_block()
    filterTargetRange: "中距离"  # 目标地块必须在中距离范围内（相邻地块）
    content: {
        player.减少行动次数( 1 )
        player.moveTo(target)  # 调用底层函数，见 Player.md#moveto
    }
}
```

---

### 拾荒

```gdscript
Skill{
    技能名："拾荒"
    技能描述："从可以进行拾荒的牌堆中抓取一张牌"
    active: "行动阶段"
    filter: {
        if( player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get_current_block().hasColor() ){
            return true
        } else return false
    }
    filterTarget: return getColor(target).isIn(getColor(player.get_current_block()))
    content: {
        player.减少行动次数( 1 )
        player.drawScavenge(1, target)  # 见 Player.md#drawscavenge
    }
}
```

---

### 摸牌

```gdscript
Skill{
    技能名："摸牌"
    技能描述："从玩家游戏牌堆中抓取一张牌"
    active: "行动阶段"
    filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
    content: {
        player.减少行动次数( 1 )
        player.draw(1)  # 见 Player.md#draw
    }
}
```

---

### 制衡

```gdscript
Skill{
    技能名："制衡"
    技能描述："你可以弃置两张玩家游戏牌，然后从玩家游戏牌堆中抓取一张牌"
    active: "行动阶段"
    usable: 1  # 每个回合的行动阶段限用1次
    filter: return player.inPhase == "行动阶段"  # 免费行动：不消耗行动次数
    selectCard: 2
    filterCard: return getSource(card) == player  # 只能选求生者游戏牌
    position: "手牌区"
    content: {
        player.discard(cards)  # 见 Player.md#discard
        player.draw(1)
    }
}
```

---

### 交易

```gdscript
Skill{
    技能名："交易"
    技能描述："你可以选择一张拾荒牌牌和同地图块内另一玩家，然后你将该拾荒牌牌向该玩家展示，其可以选择一张手中的拾荒牌与你交易。"
    active: "行动阶段"
    usable: 1
    filter: return player.inPhase == "行动阶段" && getPlayerNumber(player.get_current_block()) > 1
    selectCard: 1
    filterCard: return getSource(card) == scavenge  # 必须是拾荒牌
    position: "手牌区"
    selectTarget: 1
    filterTargetRange: "短距离"  # 同地块内
    filterTarget: return target.hasScavengeCard() && target != player
    content: {
        # 向目标展示所选的拾荒牌
        player.showCard(card, target)

        # 询问目标是否同意交易
        list = ["同意", "拒绝"]
        result = target.choose( list )

        # 若目标同意，则进行双方拾荒牌交换
        if( result == "同意" ){
            # 目标从其手牌区中选择1张拾荒牌
            card2 = target.chooseCard(1, position="手牌区", source="scavenge")

            target.getCard(card)  # 目标获得玩家展示的牌
            player.getCard(card2)  # 玩家获得目标选定的牌
        }
    }
}
```

---

### 加油

```gdscript
Skill{
    技能名："加油"
    技能描述："行动：消耗一个燃料，为面包车或燃料型装备补充燃料。"
    active: "行动阶段"
    usable: Infinity  # 不限使用次数
    filter: return player.inPhase == "行动阶段" && 玩家装备区里有'燃料'  # 免费行动：不消耗行动次数
    filterTargetRange: "短距离"
    filterTarget: {
        if( target == player.get_current_block() && player.get_current_block().名字 == "面包车" ){
            return true
        } else if( target.填充物类型 == "燃料" ){
            return true
        }
        return false
    }
    content: {
        player.discard( name = "燃料", quantity = 1, position = "装备区" )

        # 根据目标类型执行不同的加油逻辑
        if( target.名字 == "面包车" ){
            target.加油(1, player)  # 玩家往面包车添加1个燃料
        }
        else{
            target.添加填充物(max, "燃料")  # 往装备添加最大燃料量
        }
    }
}
```

---

## 三、其他技能来源

> 通用行动技能之外，技能还来自以下来源，均遵循上述 Skill 结构。

| 来源 | 挂载位置 | 说明 |
|------|---------|------|
| 角色固有技能 | Player | 角色开局即拥有，非卡牌。见各 [SurvivorPacks](../../Resource/SurvivorPacks/) |
| 装备技能 | Player（装备时） | 装备牌进入装备区时挂载，离开时移除。见 [Player.装备](../Entities/Player.md#装备) |
| 行动牌效果 | Card | 即时使用，使用后弃掉 |
| 地块技能 | Player（进入地块时） | 地块技能挂载到进入的玩家身上，离开时清理。见 [MapBlock](../Entities/MapBlock.md) |
| 怪物技能 | Monster | 怪物自带技能。见 [Monster](../Entities/Monster.md) |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | Skill 通过 addSkill 挂载到 Entity，由 Entity.trigger 遍历执行 |
| [EventSystem](../Core/EventSystem.md) | trigger 字段引用 EventSystem 定义的 trigger 名 |
| [Player](../Entities/Player.md) | 通用行动技能是 Player 的固有技能 |
| [RoleCard](RoleCard.md) | 角色固有技能存储在 RoleCard 上 |
