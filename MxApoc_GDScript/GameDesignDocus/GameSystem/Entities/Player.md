# Player 玩家类

> 继承：[Entity](../Core/Entity.md)
> 职责：玩家实体的状态、区域、行动与玩家专属流程方法。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 字段

### 状态字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 生命值 | Int | 当前 HP。≤ 0 时玩家死亡 |
| 最大生命值 | Int | 生命值上限。恢复不超过此值 |
| 饥饿值 | Int | 1-6。每回合 +1。达 6 后翻面角色卡并叠加饥饿伤害标记 |
| 潜行值 | Int | 用于潜行检定。基础潜行值 - (地块怪物数 + 怪物标记数) |
| 行动次数 | Int | 每回合 4 次。移动/抓牌/出牌/拾荒/执行卡牌行动各消耗 1 次 |
| 最大行动次数 | Int | 行动次数上限。部分技能可临时增加 |
| inPhase | String | 当前所处回合阶段，技能 filter 用。可选值：`"回合外"`（默认） / `"回合开始"` / `"怪物出生"` / `"摸牌阶段"` / `"行动阶段"` / `"饥饿结算"` / `"中毒结算"` / `"怪物行动"` / `"回合结束"`。值在 [开始回合](#十回合流程) 各阶段切换 |

### 区域字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 手牌区 | List\<Card\> | 手牌所在区域。上限 10 张 |
| 装备区 | List\<EquipmentCard\> | 装备牌所在区域。受装备栏容量限制（容量由角色卡 `装备栏容量` 字段决定，见 [RoleCard](../Common/RoleCard.md)） |
| 怪物区 | List\<Monster\> | 玩家面前的怪物卡区域。怪物卡进入此区时与玩家纠缠 |
| 游戏牌堆 | Pile | 求生者游戏牌堆。抓牌从此处；牌堆空时玩家死亡 |
| 游戏牌弃牌堆 | Pile | 求生者游戏牌弃牌区域 |

### 关联对象

| 字段 | 类型 | 说明 |
|------|------|------|
| 角色卡 | RoleCard | 玩家角色卡。饥饿值达 6 后翻面，减少饥饿值后恢复正面 |
| 当前地块 | MapBlock | 玩家所在地图块 |
| 座位号 | Int | 玩家在游戏房间中的座位次序 |

### 标记

| 标记 | 说明 |
|------|------|
| 中毒标记 (`poison`) | 回合结算时受到等量伤害（无来源伤害） |
| 饥饿伤害等级 | 角色卡翻面后的标记。等级 1-5 分别造成 2/4/6/8/致死伤害 |
| 避难所失效 | 避难所技能的临时标记，持续到回合结束 |
| 其他临时标记 | 各技能/地块添加的标记 |

> 标记管理通过 `countMark` / `addMarkSkill` / `removeMarkSkill` / `hasMarkSkill` 等方法。

---

## 信号量（triggers）

> 完整 trigger 列表见 [EventSystem.md §4](../Core/EventSystem.md#4-全-trigger-索引)。Player 类涉及的 trigger 领域：

- **伤害/回复类**：受到伤害前/时/后、回复生命前/时/后
- **移动类**：离开地块前/时/后、进入地块前/时/后
- **回合类**：回合开始前/时、怪物出生前/时、摸牌阶段前、行动阶段前/结束前/结束时、饥饿结算前/时、中毒结算前/时、面前怪物行动前/时、回合结束前/时
- **抓牌类**：抓取游戏牌前/时/后、抓取拾荒牌前/时/后、抓取怪物卡前/时/后、怪物卡进入求生者怪物区前/时/后
- **使用卡牌类**：使用卡牌前/时/后
- **装备类**：卡牌进入装备区前/时/后、卡牌离开装备区前/时/后、消耗填充物前/时/后、填充物耗尽时
- **检定类**：潜行检定前/时/后、怪物出生检定前/时/后
- **弃牌/销毁类**：弃置牌前/时/后、销毁牌前/时/后
- **游戏类**：游戏开始时、游戏结束时
- **地图类**：摧毁地块前/时/后、触发目标标记时

---

## 方法

### 一、状态管理

#### recover(num)

> 回复生命值方法。
> 走完整 4 节点事件流程（前/时/系统加血/后）。
> 系统加血受最大生命值上限约束；`event.num` 可被「回复生命时」钩子修改。

```gdscript
function player.recover(num) {
    if (num <= 0) {
        return
    }

    event = {
        player: player,
        num: num,
        cancelled: false,
    }

    # 1. 回复生命前
    player.trigger("回复生命前", event)

    # 2. 回复生命时 —— 技能可在此阶段修改 event.num（如 surgeon 手术刀·回复、手套：event.num += 1）
    player.trigger("回复生命时", event)

    if (event.cancelled) {
        return
    }

    # 3. 系统加血，受最大生命值上限约束，非钩子节点
    max = player.get_max_hp() - player.get_hp()
    if (event.num > max) {
        event.num = max
    }
    player.add_hp(event.num)

    # 4. 回复生命后 [提案]
    player.trigger("回复生命后", event)
}
```

> 与 `player.add_hp(n)` 的区别：`add_hp` 为底层原子方法，直接修改生命值，不触发钩子且不受最大值约束；`recover` 走完整 4 节点流程。

---

#### increaseHunger(num)

> 增加饥饿值方法。
> 饥饿值达到 6 后翻面角色卡，并逐级叠加饥饿伤害标记。
> 饥饿伤害为无来源伤害（source = NULL），由 damage 流程跳过 source 侧钩子。

```gdscript
function player.increaseHunger(num) {
    if (num <= 0) {
        return
    }
    while (num > 0) {
        if (player.get_hunger() < 6) {
            player.add_hunger(1)
        } else if (player.get_hunger() == 6) {
            if (player.get_role_card().is_front()) {
                player.get_role_card().flip()
            }
            player.addMarkSkill("饥饿伤害等级", 1)
        }

        if (player.countMark("饥饿伤害等级") > 0) {
            level = player.countMark("饥饿伤害等级")
            if (level == 1) {
                player.damage(2, NULL, "饥饿伤害")
            } else if (level == 2) {
                player.damage(4, NULL, "饥饿伤害")
            } else if (level == 3) {
                player.damage(6, NULL, "饥饿伤害")
            } else if (level == 4) {
                player.damage(8, NULL, "饥饿伤害")
            } else if (level >= 5) {
                game.log(player.name + "被饿死了")
                player.damage(player.get_max_hp(), NULL, "饥饿伤害")
            }
        }

        num -= 1
    }
}
```

---

#### decreaseHunger(num)

> 减少饥饿值方法。
> 饥饿值最低降至 1，减少后清除饥饿伤害标记并恢复角色卡正面。

```gdscript
function player.decreaseHunger(num) {
    if (num <= 0) {
        return
    }
    max = player.get_hunger() - 1
    if (num > max) {
        num = max
    }
    if (num <= 0) {
        game.log("饥饿值已减少到1，无法继续减少")
        return false
    }
    player.reduce_hunger(num)
    if (player.countMark("饥饿伤害等级") > 0) {
        player.removeMarkSkill("饥饿伤害等级")
    }
    if (!player.get_role_card().is_front()) {
        player.get_role_card().flip()
    }
}
```

---

#### poison()

> 中毒结算方法。
> 在玩家回合的「求生者中毒状态结算」阶段调用。
> 中毒伤害为无来源伤害（source = NULL）。

```gdscript
function player.poison() {
    if (player.countMark("poison") > 0) {
        num = player.countMark("poison")
        player.damage(num, NULL, "poison")
    }
}
```

---

### 二、抓牌流程

#### draw(n)

> 「player 从其求生者游戏牌堆抓取 n 张牌到手牌区」的流程方法。
> 牌堆为空时尝试抓取 → 触发玩家死亡（source = NULL）。
> 手牌上限由上层校验，draw() 不处理。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 抓取游戏牌前 | **取消点** |
| 2 | 抓取游戏牌时 | **取消点**；可修改 event.num |
| 3 | （逐张抓取） | 每张抓取前检查牌堆，牌堆为空 → playerDeath(NULL) |
| 4 | 抓取游戏牌后 | 可访问 event.cards |

```gdscript
function player.draw(n) {
    if (n <= 0) {
        return
    }

    event = {
        player: player,
        num: n,
        cards: [],
        cancelled: false,
    }

    # 1. 抓取游戏牌前（取消点）
    player.trigger("抓取游戏牌前", event)
    if (event.cancelled) {
        return
    }

    # 2. 抓取游戏牌时（取消点：可修改 event.num 或 cancel()）
    player.trigger("抓取游戏牌时", event)
    if (event.cancelled) {
        return
    }

    # 3. 逐张抓取
    #    每张抓取前检查牌堆：牌堆为空时尝试抓取 → 触发玩家死亡
    for (i = 0; i < event.num; i++) {
        if (player.游戏牌堆.isEmpty()) {
            player.playerDeath(NULL)
            return
        }
        card = player.游戏牌堆.draw()
        player.手牌区.add(card)
        event.cards.add(card)
    }

    # 4. 抓取游戏牌后
    player.trigger("抓取游戏牌后", event)
}
```

---

#### drawScavenge(n, pile)

> 「player 从指定拾荒牌堆抓取 n 张牌到手牌区」的流程方法。
> pile 参数为 pile 对象（颜色字符串需调用方先通过 `game.getScavengePile()` 转换）。
> 牌堆为空时停止抓取（不重洗弃牌堆）。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 抓取拾荒牌前 | **取消点**（如手电筒替代为「看2留1放1」） |
| 2 | （逐张抓取） | 抓1张→入手牌区→触发「时」→抓下一张；牌堆空则停止 |
| 3 | 抓取拾荒牌时 | 每张牌触发一次 |
| 4 | 抓取拾荒牌后 | 所有牌抓取完成 |

```gdscript
function player.drawScavenge(n, pile) {
    if (n <= 0) {
        return
    }

    event = {
        player: player,
        pile: pile,
        num: n,
        cards: [],
        card: NULL,
        cancelled: false,
    }

    # 1. 抓取拾荒牌前（取消点）
    #    手电筒（blue.md）在此取消并替代为「看2留1放1」逻辑
    player.trigger("抓取拾荒牌前", event)
    if (event.cancelled) {
        return
    }

    # 2. 逐张抓取
    #    牌堆为空时停止（不重洗弃牌堆）
    #    每张牌入手牌区后触发「抓取拾荒牌时」
    #    卡片技能可能立即处理：一无所获弃掉、伏击！drawMonster、燃料装备
    for (i = 0; i < event.num; i++) {
        if (pile.isEmpty()) {
            break
        }
        card = pile.draw()
        player.手牌区.add(card)
        event.cards.add(card)
        event.card = card

        # 3. 抓取拾荒牌时（每张牌触发一次）
        player.trigger("抓取拾荒牌时", event)
    }

    # 4. 抓取拾荒牌后
    player.trigger("抓取拾荒牌后", event)
}
```

---

#### drawMonster(n)

> 「player 从怪物牌堆抓取 n 张怪物卡到玩家怪物区」的流程方法。
> 怪物牌堆空时重洗怪物弃牌堆；重洗后仍为空（所有怪物卡都在场上）→ `game.gameOver("lose")`。
> 每张怪物卡在节点 3-4 之间实体化（设置纠缠对象、初始化生命值）。
> 节点 5 内 zombie 一大波僵尸、僵尸步行者会递归调用 drawMonster。

**事件钩子顺序**（每张怪物卡走 2a-2f 节点，全部抓完后走节点 3）：

| 节点 | trigger 名 | 触发对象 | 说明 |
|------|-----------|---------|------|
| 1 | 抓取怪物卡前 | player | **取消点**（如 firefighter「梯子」） |
| 2a | （牌堆空重洗） | — | 牌堆空时重洗怪物弃牌堆；重洗后仍空 → gameOver("lose") |
| 2b | 抓取怪物卡时 | player | 每张触发 |
| 2c | 怪物卡进入求生者怪物区前 | player | 每张触发 |
| 2d | （实体化） | — | 设置纠缠对象、初始化生命值 |
| 2e | 怪物卡进入求生者怪物区时 | player | 每张触发 |
| 2f | 怪物卡进入求生者怪物区后 | player | 每张触发；如 zombie 一大波僵尸、僵尸步行者递归调用 drawMonster |
| 3 | 抓取怪物卡后 | player | 整体触发一次；如 mechanic「感应地雷」 |

```gdscript
function player.drawMonster(n) {
    if (n <= 0) {
        return
    }

    event = {
        player: player,
        num: n,
        cards: [],
        card: NULL,
        cancelled: false,
    }

    # 1. 抓取怪物卡前（取消点）
    #    firefighter「梯子」在此取消跳过抓怪
    player.trigger("抓取怪物卡前", event)
    if (event.cancelled) {
        return
    }

    # 2. 逐张抓取
    for (i = 0; i < event.num; i++) {
        # a. 牌堆空时重洗怪物弃牌堆
        if (怪物牌堆.isEmpty()) {
            怪物弃牌堆.shuffleInto(怪物牌堆)
            # 重洗后仍为空 → 游戏失败（所有怪物卡都在场上）
            if (怪物牌堆.isEmpty()) {
                game.gameOver("lose")
                return
            }
        }

        # 抓取怪物卡
        card = 怪物牌堆.draw()
        event.card = card
        event.cards.add(card)

        # b. 抓取怪物卡时（每张触发）
        player.trigger("抓取怪物卡时", event)

        # c. 怪物卡进入求生者怪物区前（每张触发）
        player.trigger("怪物卡进入求生者怪物区前", event)

        # d. 实体化（设置纠缠对象、初始化生命值等）
        card.纠缠对象 = player
        card.生命值 = card.最大生命值

        # e. 怪物卡进入求生者怪物区时（每张触发）
        player.怪物区.add(card)
        player.trigger("怪物卡进入求生者怪物区时", event)

        # f. 怪物卡进入求生者怪物区后（每张触发）
        #    zombie 一大波僵尸、僵尸步行者在此递归调用 drawMonster
        player.trigger("怪物卡进入求生者怪物区后", event)
    }

    # 3. 抓取怪物卡后（整体触发一次）
    #    mechanic「感应地雷」在此对 event.card 造成伤害
    player.trigger("抓取怪物卡后", event)
}
```

---

### 三、弃牌与销毁流程

#### discard(target, position=NULL, quantity=1, type=NULL)

> 「player 弃置卡牌到对应弃牌堆」的流程方法。
> 弃牌堆分派：按卡牌 source 自动分派（scavenge → 对应颜色拾荒弃牌堆，game → 游戏牌弃牌堆）。
>
> **重载签名**：
> - `discard(card)` 弃置单张牌
> - `discard(cards)` 弃置多张牌（列表）
> - `discard(name, position=, quantity=1)` 按名字+位置弃置 quantity 张
> - `discard(type, type=true)` 按类型弃置所有该类型牌
>
> position = NULL 时搜索所有区域（手牌区+装备区）。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 弃置牌前 | **取消点** |
| 2 | 弃置牌时 | 每张：从原位置移除 → 进入对应弃牌堆 → 触发 |
| 3 | 弃置牌后 | 整体触发一次 |

```gdscript
function player.discard(target, position=NULL, quantity=1, type=NULL) {
    # 解析参数，确定要弃置的牌列表
    cardsToDiscard = []

    if (type != NULL) {
        # 按类型弃置：搜索所有区域中该类型的牌
        allCards = player.getCards(position=position)
        for (card in allCards) {
            if (card.类型 == target) {
                cardsToDiscard.add(card)
            }
        }
    } else if (isCard(target)) {
        cardsToDiscard.add(target)
    } else if (isList(target)) {
        cardsToDiscard = target
    } else {
        cardsToDiscard = player.getCards(name=target, position=position, quantity=quantity)
    }

    if (cardsToDiscard.isEmpty()) {
        return
    }

    event = {
        player: player,
        num: cardsToDiscard.length,
        cards: [],
        card: NULL,
        cancelled: false,
    }

    # 1. 弃置牌前（取消点）
    player.trigger("弃置牌前", event)
    if (event.cancelled) {
        return
    }

    # 2. 逐张弃置
    for (card in cardsToDiscard) {
        event.card = card
        event.cards.add(card)

        # 如果牌在装备区，先走卸下流程（触发卡牌离开装备区 trigger，移除技能）
        # 否则从其他区域（手牌区）移除
        if (player.装备区.contains(card)) {
            player.卸下(card)  # 内部从装备区移除 + 移除技能 + 触发离开 trigger
        } else {
            player.移除区域牌(card)
        }

        # 进入对应弃牌堆（按 source 自动分派）
        if (card.source == "scavenge") {
            game.getScavengePile(card.颜色).discardPile.add(card)
        } else {
            player.游戏牌弃牌堆.add(card)
        }

        # 触发「弃置牌时」（每张触发）
        player.trigger("弃置牌时", event)
    }

    # 3. 弃置牌后（整体触发一次）
    player.trigger("弃置牌后", event)
}
```

---

#### removeCard(target, position=NULL, quantity=1)

> 「player 销毁卡牌（移出游戏）」的流程方法。
> 与 discard 的区别：销毁的牌不进入弃牌堆，而是移出游戏（调用 `game.removeCard(card)`）。
>
> **重载签名**：支持 card 对象 / cards 列表 / name+position+quantity。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 销毁牌前 | **取消点** |
| 2 | 销毁牌时 | 每张：从原位置移除 → 移出游戏 → 触发 |
| 3 | 销毁牌后 | 整体触发一次 |

```gdscript
function player.removeCard(target, position=NULL, quantity=1) {
    cardsToRemove = []

    if (isCard(target)) {
        cardsToRemove.add(target)
    } else if (isList(target)) {
        cardsToRemove = target
    } else {
        cardsToRemove = player.getCards(name=target, position=position, quantity=quantity)
    }

    if (cardsToRemove.isEmpty()) {
        return
    }

    event = {
        player: player,
        num: cardsToRemove.length,
        cards: [],
        card: NULL,
        cancelled: false,
    }

    # 1. 销毁牌前（取消点）
    player.trigger("销毁牌前", event)
    if (event.cancelled) {
        return
    }

    # 2. 逐张销毁
    for (card in cardsToRemove) {
        event.card = card
        event.cards.add(card)

        # 从原位置移除
        player.移除区域牌(card)

        # 移出游戏（不进入弃牌堆）
        game.removeCard(card)

        # 触发「销毁牌时」（每张触发）
        player.trigger("销毁牌时", event)
    }

    # 3. 销毁牌后（整体触发一次）
    player.trigger("销毁牌后", event)
}
```

> **命名统一**：原 MapBlocks(坠毁点) 的 `player.remove(card)` 已统一为 `player.removeCard(card)`。

---

### 四、移动流程

#### moveTo(target)

> 底层移动函数（不扣行动次数，只负责移动和触发钩子）。
> 核心原则：所有地图块技能全部挂载到玩家身上，由 `player.trigger()` 统一触发。
> 取消点：节点 5「进入地块前」可 `event.cancel()`，取消时回滚目标地块技能。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 离开地块前 | 玩家离开当前地块前 |
| 2 | 离开地块时 | 如森林：同回合内进入又离开 → 抓怪物 |
| 3 | 离开地块后 | 离开完成 |
| 4 | （获取目标地块技能） | `player.获取地块技能(target)`，将目标地块技能挂载到玩家 |
| 5 | 进入地块前 | **取消点**；准入检定（如河流：潜行失败 → cancel()） |
| 6 | （移动时） | 坐标变更：`player.moveToMapBlock(target)` |
| 7 | （清理旧地块技能） | `source.清除技能(player)`，移动成功后才清理 |
| 8 | 进入地块时 | 一次性进入效果（军事基地造成伤害、监狱减行动、旷野抓怪物等） |
| 9 | 进入地块后 | 展示未展示的地块（触发「展示地块时」）；player.trigger |
| 10 | （潜行检定） | 目标地块有怪物标记时进行潜行检定，失败 → 移除标记并抓怪物 |
| 11 | （触发目标标记） | 如果目标地块有未触发的目标标记，触发标记效果（一次性） |

```gdscript
function player.moveTo(target) {
    source = player.get_current_block()

    event = {
        player: player,
        source: source,
        targetBlock: target,
        cancelled: false,
    }

    # 1. 离开所在地块前
    player.trigger("离开地块前", event)

    # 2. 离开所在地块时
    #    如森林：同回合内进入又离开 → 抓怪物
    player.trigger("离开地块时", event)

    # 3. 离开所在地块后
    player.trigger("离开地块后", event)

    # 4. 获取目标地块技能（先获取，再准入检定，确保目标地块技能已在玩家身上）
    player.获取地块技能(target)

    # 5. 进入目标地块前（准入检定：技能已在玩家身上，可调用 event.cancel() 阻止移动）
    #    如河流：潜行检定失败 → event.cancel()
    player.trigger("进入地块前", event)
    if (event.cancelled) {
        # 移动取消，回滚：移除刚获取的目标地块技能
        target.清除技能(player)
        return false
    }

    # 6. 移动时（坐标变更）
    player.moveToMapBlock(target)

    # 7. 清理旧地块技能（移动成功后再清理 source 的技能，确保回滚时玩家仍保留旧技能）
    source.清除技能(player)

    # 8. 进入目标地块时（一次性效果：军事基地造成伤害、监狱减行动次数、旷野抓怪物等）
    player.trigger("进入地块时", event)

    # 9. 进入目标地块后
    #    展示未展示的地图块（触发"展示地块时"效果）
    if (!target.is_revealed()) {
        target.展示(触发效果 = true, player)
    }
    player.trigger("进入地块后", event)

    # 10. 如果目标地块上有怪物标记，玩家需要进行潜行检定
    if (target.hasMonsterMark()) {
        if (!player.sneakJudge()) {
            num = target.countMonsterMark()
            target.removeMonsterMark(num)
            player.drawMonster(num)
        }
    }

    # 11. 触发目标标记（如果有且未触发）
    #     目标标记效果由任务包定义，一次性触发
    #     落地 EventSystem §4.13 的「触发目标标记时」trigger
    target.triggerObjectiveMarks(player)

    return true
}
```

---

### 五、检定系统

#### judge()

> 基础检定方法：随机投掷两颗大骰子，返回点数之和。

```gdscript
function player.judge() {
    player.roll_two_dice()
    result = 两颗大骰子的点数之和
    return result
}
```

---

#### sneakJudge()

> 潜行检定方法。
> 走前/时/后三节点 trigger 流程。
> 潜行值 = 玩家潜行值 - (所在地块怪物数 + 怪物标记数)。
> 检定结果 ≤ 潜行值则成功，否则失败。
> 落地 [EventSystem §4.9](../Core/EventSystem.md#49-检定类) 的「潜行检定前/时/后」trigger。
>
> **event.result 类型**：结构体 `{ value: 骰子点数, success: 布尔值 }`。
> **跳过投骰**：技能在「前」节点设置 `event.skipJudge = true` + `event.result = { value, success }` 可跳过投骰并指定结果。
> **修改结果**：技能在「时」节点可直接赋值 `event.result = { value, success }` 覆盖投骰结果。
> **失败处理**：由调用方负责（如 [moveTo](#moveto) 节点 10 移除标记并抓怪物）。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 潜行检定前 | 技能可设置 `skipJudge=true` + `result` 跳过投骰 |
| 2 | （系统投骰） | 若未跳过：投骰并计算 result；若跳过：使用技能指定的 result |
| 3 | 潜行检定时 | 技能可修改 event.result（如 gray 科学家设为失败） |
| 4 | 潜行检定后 | 非取消点；可查询 event.result |

```gdscript
function player.sneakJudge() {
    num = countMonster(player.get_current_block()) + countMonsterMark(player.get_current_block())
    sneakValue = player.get_sneak() - num

    event = {
        player: player,
        sneakValue: sneakValue,
        result: NULL,       # 检定结果，结构体 { value: 骰子点数, success: 布尔值 }
        skipJudge: false,   # 是否跳过投骰
        cancelled: false,
    }

    # 1. 潜行检定前
    #    技能可设置 skipJudge=true + result={...} 跳过投骰
    #    如 firefighter「梯子」对河流地块：skipJudge=true, result={ value: 0, success: true }
    #    如 robot「激光无人机」：skipJudge=true, result={ value: 999, success: false }
    player.trigger("潜行检定前", event)

    # 2. 系统投骰（若未跳过）
    if (!event.skipJudge) {
        diceValue = player.judge()
        success = (diceValue <= event.sneakValue)
        event.result = { value: diceValue, success: success }
    }
    # 若 skipJudge=true，event.result 由「前」节点技能设置

    # 3. 潜行检定时
    #    技能可修改 event.result（如 gray 科学家设为 { value: 999, success: false }）
    player.trigger("潜行检定时", event)

    # 4. 潜行检定后（非取消点）
    player.trigger("潜行检定后", event)

    # 返回检定结果（成功/失败），失败处理由调用方负责
    return event.result.success
}
```

> **触发场景**：玩家进入有怪物标记的地块时（[moveTo](#moveto) 节点 10）；玩家回合行动阶段前（地块有怪物标记时）。
> **失败处理**：由调用方负责（如 moveTo 节点 10：移除所有怪物标记，每移除一个抓一张怪物卡）。

---

#### monsterSpawnJudge()

> 怪物出生检定方法。
> 走前/时/后三节点 trigger 流程。
> 检定结果（骰子点数）对应地图块的 monster_spawn_value，匹配的地图块执行怪物出生逻辑。
> 落地 [EventSystem §4.9](../Core/EventSystem.md#49-检定类) 的「怪物出生检定前/时/后」trigger。
>
> **event.result 类型**：结构体 `{ value: 骰子点数, success: 布尔值 }`（success 字段无意义，恒为 true）。
> **跳过投骰**：技能在「前」节点设置 `event.skipJudge = true` + `event.result = { value, success }` 可跳过投骰并指定骰子点数。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 怪物出生检定前 | 技能可设置 `skipJudge=true` + `result` 跳过投骰 |
| 2 | （系统投骰） | 若未跳过：投骰并计算 result；若跳过：使用技能指定的 result |
| 3 | 怪物出生检定时 | 技能可修改 event.result |
| 4 | 怪物出生检定后 | 非取消点；可查询 event.result |
| 5 | （结果处理） | 匹配地块：标记 < 3 → +1 标记；标记 = 3 且有玩家 → 每位玩家抓 1 怪物 |

```gdscript
function player.monsterSpawnJudge() {
    event = {
        player: player,
        result: NULL,       # 检定结果，结构体 { value: 骰子点数, success: 布尔值 }（success 无意义）
        skipJudge: false,
        cancelled: false,
    }

    # 1. 怪物出生检定前
    player.trigger("怪物出生检定前", event)

    # 2. 系统投骰（若未跳过）
    if (!event.skipJudge) {
        diceValue = player.judge()
        event.result = { value: diceValue, success: true }  # success 无意义，恒为 true
    }

    # 3. 怪物出生检定时
    player.trigger("怪物出生检定时", event)

    # 4. 怪物出生检定后（非取消点）
    player.trigger("怪物出生检定后", event)

    # 5. 结果处理：匹配地块的 monster_spawn_value
    List = 所有已经展示的，且 monster_spawn_value == event.result.value 的地图块
    for (i in List) {
        if (i.countMonsterMark() < 3) {
            i.addMonsterMark(1)
        } else if (i.countMonsterMark() == 3 && i.hasPlayer()) {
            List2 = 此地图块上的所有玩家
            for (j in List2) {
                j.drawMonster(1)
            }
        }
    }
}
```

> **触发场景**：玩家回合节点 5「怪物出生时」。
> **注**：D_gameFlow.md 中的「怪物出生前/时」是玩家回合阶段级别的 trigger，与此处的检定流程 trigger 不同层级。

---

### 六、死亡流程

#### playerDeath(source)

> 实现 [Entity.death](../Core/Entity.md#6-抽象方法子类实现)。
> 流程：玩家死亡前 → 玩家死亡时 → 玩家死亡后（清理 + 事件）。
> 取消点：无（死亡流程不可取消）。
> 触发场景：`entity.damage` 流程节点 8 中玩家生命值 ≤ 0；或游戏牌堆无牌时摸牌。

**清理内容**：
- a. 怪物区怪物 → 弃牌堆，等量怪物标记（最多3个）放回地块
- b. 所有求生者游戏牌移出游戏
- c. 拾荒卡按颜色洗回对应拾荒牌堆

```gdscript
function player.playerDeath(source) {
    event = {
        target: player,
        source: source,
    }

    # 1. target 玩家死亡前
    player.trigger("玩家死亡前", event)

    # 2. target 玩家死亡时
    player.trigger("玩家死亡时", event)

    # 3. target 玩家死亡后

    # 3a. 把其角色面前的所有怪物置入弃牌堆，替换为等量的怪物标记（最多3个）
    怪物列表 = player.怪物区.getAll()
    markCount = min(怪物列表.length, 3)
    for m in 怪物列表 {
        player.怪物区.remove(m)
        怪物弃牌堆.add(m)
    }
    if (markCount > 0) {
        player.get_current_block().addMonsterMark(markCount)
    }

    # 3b. 将场上所有该角色的求生者游戏牌移出游戏
    #     覆盖手牌区、装备区、游戏牌堆、游戏牌弃牌堆
    游戏牌列表 = player.getAllGameCards()
    for c in 游戏牌列表 {
        game.removeCard(c)
    }

    # 3c. 该角色携带的所有拾荒卡根据颜色洗回对应拾荒牌堆
    拾荒牌列表 = player.getCards(source = "scavenge")
    for c in 拾荒牌列表 {
        颜色 = c.颜色
        player.removeCard(c)
        game.getScavengePile(颜色).add(c)
    }
    # 各颜色拾荒牌堆分别洗牌
    for 颜色 in ["red", "green", "blue"] {
        game.getScavengePile(颜色).shuffle()
    }

    player.trigger("玩家死亡后", event)

    # 检查游戏结束条件
    if (game.allPlayersDead()) {
        game.gameOver("lose")
    }
}
```

---

### 七、使用卡牌流程

#### useCard(card)

> 「玩家从手牌中使用一张卡牌」的流程方法。
> 对应行动阶段行动选项 #3「从手牌中打出 1 张牌」（见 [D_gameFlow.md](../../GameInstructions/D_gameFlow.md)）。
> 使用规则见 [H_useCard.md](../../GameInstructions/H_useCard.md)。
>
> **统一消耗行动次数**：useCard 对装备牌和行动牌统一消耗 1 点行动次数。卡牌 content 内不再调用 `player.减少行动次数(1)`。
> **卡牌类型分流**：
> - 装备牌 → 调用 `player.装备(card)`（§八）进入装备区，不弃掉
> - 行动牌 → 技能系统独立执行 content（useCard 不直接调用 `card.技能.content()`），执行后弃掉
> **弃牌堆分流**：行动牌使用后按 `card.source` 字段分派（scavenge → 拾荒弃牌堆，game → 游戏牌弃牌堆），由 `player.discard(card)` 内部处理（见 §三 discard）。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 使用卡牌前 | **取消点**；可校验行动次数、手牌合法性 |
| 2 | 使用卡牌时 | **取消点**；装备牌/行动牌分流的最后拦截点 |
| 3 | （系统结算） | 扣 1 点行动次数 → 按类型分流（装备/行动） |
| 4 | 使用卡牌后 | 整体触发一次 |

```gdscript
function player.useCard(card) {
    event = {
        player: player,
        card: card,
        cancelled: false,
    }

    # 1. 使用卡牌前（取消点）
    player.trigger("使用卡牌前", event)
    if (event.cancelled) {
        return false
    }

    # 2. 使用卡牌时（取消点）
    player.trigger("使用卡牌时", event)
    if (event.cancelled) {
        return false
    }

    # 3. 系统结算：统一消耗 1 点行动次数
    player.减少行动次数(1)

    # 按卡牌类型分流
    if (card.类型 == "装备") {
        # 装备牌：进入装备区（内部触发装备流程 trigger）
        # 装备栏容量校验失败时由 装备() 内部取消并提示
        player.装备(card)
    } else {
        # 行动牌：技能 content 由技能系统独立执行
        # useCard 不直接调用 card.技能.content()，由技能系统统一调度
        # [技能系统执行 content]
        game.skillSystem.execute(card.技能, event)

        # 弃掉这张牌（按 source 字段分流，见 §三 discard）
        player.discard(card)
    }

    # 4. 使用卡牌后
    player.trigger("使用卡牌后", event)
    return true
}
```

> **设计说明**：
> - 行动牌的技能 content 由技能系统独立执行（`game.skillSystem.execute`），而非 useCard 直接调用。这保持技能执行的统一调度（filter 校验、目标选择等由技能系统处理）。
> - 装备牌进入装备区时，装备栏容量校验失败由 `player.装备(card)` 内部处理（取消装备并提示），useCard 不重复校验。
> - 行动牌使用后的弃牌由 `player.discard(card)` 按 `card.source` 自动分派到对应弃牌堆。

---

### 八、装备流程

#### 装备(card)

> 装备进入装备区流程。
> 落地 [EventSystem §4.8](../Core/EventSystem.md#48-装备类) 的装备类 trigger。
>
> **系统预校验**（节点 1 trigger 之后、节点 2 之前，非钩子节点）：
> 1. **同名装备校验**：装备区有同名装备 → 直接弃置同名装备（走 `player.discard` 流程，内部调用卸下）
> 2. **装备栏容量校验**：装备后超过装备栏容量 → 玩家选择弃置装备区的装备牌直到能容下；无法容下则取消装备并提示
>
> 装备栏容量由角色卡 `装备栏容量` 字段决定（见 [RoleCard](../Common/RoleCard.md)），可被技能（如背包）修改。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 卡牌进入装备区前 | **取消点** |
| — | （系统预校验） | 同名装备校验 + 装备栏容量校验，非钩子节点 |
| 2 | 卡牌进入装备区时 | 装备置入装备区 + 技能挂载 |
| 3 | 卡牌进入装备区后 | 装备进入完成 |

```gdscript
function player.装备(card) {
    event = {
        player: player,
        card: card,
        cancelled: false,
    }

    # 1. 卡牌进入装备区前（取消点）
    player.trigger("卡牌进入装备区前", event)
    if (event.cancelled) {
        return false
    }

    # 系统预校验（非钩子节点）
    # a. 同名装备校验：弃置装备区中的同名装备
    sameNameEquipments = player.装备区.filter(e => e.名字 == card.名字)
    for (e in sameNameEquipments) {
        player.discard(e)  # discard 内部检测到牌在装备区时先调用卸下流程
    }

    # b. 装备栏容量校验：装备后超过容量时，玩家选择弃置装备直到能容下
    while (player.已用装备栏() + card.大小 > player.装备栏容量) {
        # 玩家从装备区选择弃置一张装备牌
        toDiscard = player.chooseCard(position="装备区", quantity=1)
        if (toDiscard == NULL) {
            # 玩家无法或不愿弃置更多装备 → 取消装备并提示
            game.prompt("装备栏容量不足，无法装备")
            return false
        }
        player.discard(toDiscard)
    }

    # 2. 卡牌进入装备区时
    player.装备区.add(card)
    player.addSkill(card.技能)  # 装备技能挂载到玩家
    player.trigger("卡牌进入装备区时", event)

    # 3. 卡牌进入装备区后
    player.trigger("卡牌进入装备区后", event)
    return true
}
```

> **设计说明**：
> - 同名装备校验在装备栏容量校验之前执行：先弃置同名装备腾出空间，再校验容量是否足够。
> - 装备栏容量校验时，玩家选择弃置装备是交互操作（`player.chooseCard`），玩家可以随时选择不弃置（返回 NULL），此时取消装备。
> - `player.discard(e)` 内部检测到牌在装备区时，会先调用 `player.卸下(e)` 触发卡牌离开装备区 trigger 并移除技能，再进入弃牌堆（见 §三 discard）。

---

#### 卸下(card)

> 装备离开装备区流程。
> 通常作为 `discard(card)` 的一部分被调用（discard 检测到牌在装备区时先调用卸下）。
> 卸下只负责从装备区移除 + 移除技能 + 触发 trigger，不负责进入弃牌堆。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 卡牌离开装备区前 | **取消点** |
| 2 | 卡牌离开装备区时 | 从装备区移除 + 技能移除 |
| 3 | 卡牌离开装备区后 | 装备离开完成 |

```gdscript
function player.卸下(card) {
    event = {
        player: player,
        card: card,
        cancelled: false,
    }

    # 1. 卡牌离开装备区前（取消点）
    player.trigger("卡牌离开装备区前", event)
    if (event.cancelled) {
        return false
    }

    # 2. 卡牌离开装备区时
    player.装备区.remove(card)
    player.removeSkill(card.技能)  # 装备技能从玩家移除
    player.trigger("卡牌离开装备区时", event)

    # 3. 卡牌离开装备区后
    # 填充物耗尽时的衍生场景见 §九 填充物流程
    player.trigger("卡牌离开装备区后", event)
    return true
}
```

---

### 九、填充物流程

#### 消耗填充物(equipment, num)

> 装备填充物消耗流程（如枪械消耗弹药、打火机消耗燃料、摩托车消耗燃料、空尖弹特殊弹药等）。
> 走前/时/后三节点；扣减后若填充物耗尽则衍生触发「填充物耗尽时」。
> 落地 [EventSystem §4.8](../Core/EventSystem.md#48-装备类) 的「消耗填充物前/时/后」与「填充物耗尽时」trigger。
>
> **签名约束**：`equipment` 为装备对象（非装备名），由调用方先通过 `player.getEquipment(name)` 获取。
> **填充物不足**：若 `equipment.填充物当前量 < num`，取消执行并提示（不扣减、不触发任何 trigger）。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 消耗填充物前 | **取消点** |
| 2 | 消耗填充物时 | **取消点**；可修改 event.num |
| 3 | （系统扣减） | `equipment.填充物当前量 -= event.num` |
| 4 | 消耗填充物后 | 可访问 event.num、event.equipment |
| 5 | 填充物耗尽时 | **衍生**：扣减后若 `填充物当前量 <= 0` 则触发（每张牌独立触发） |

```gdscript
function player.消耗填充物(equipment, num) {
    # 前置校验：填充物不足时取消执行并提示
    if (equipment.填充物当前量 < num) {
        game.prompt(equipment.名字 + "填充物不足，无法消耗")
        return false
    }

    event = {
        player: player,
        equipment: equipment,
        card: equipment,  # 兼容：event.card 同时指向该装备，便于技能按 event.card 访问
        num: num,
        cancelled: false,
    }

    # 1. 消耗填充物前（取消点）
    player.trigger("消耗填充物前", event)
    if (event.cancelled) {
        return false
    }

    # 2. 消耗填充物时（取消点：可修改 event.num 或 cancel()）
    player.trigger("消耗填充物时", event)
    if (event.cancelled) {
        return false
    }

    # 3. 系统扣减（非钩子节点）
    equipment.填充物当前量 -= event.num

    # 4. 消耗填充物后
    player.trigger("消耗填充物后", event)

    # 5. 衍生：填充物耗尽时
    #    扣减后若填充物当前量 <= 0 则触发
    #    典型场景：gunslinger 空尖弹 subSkill remove 在此弃置武器牌
    if (equipment.填充物当前量 <= 0) {
        player.trigger("填充物耗尽时", event)
    }

    return true
}
```

---

### 十、回合流程

#### 开始回合()

> 玩家回合的完整流程方法，由 [GameStateMachine.nextTurn()](../Core/GameStateMachine.md#nextturn) 调用。
> 实现玩家回合流程 21 节点（详见 [D_gameFlow.md](../../GameInstructions/D_gameFlow.md) 与 [J_gameEventFlow.md §10](../../GameInstructions/J_gameEventFlow.md#10-玩家回合流程)）。
> 节点 21「胜利判定」由状态机在 `开始回合()` 返回后调用 `checkWinCondition()` 执行，不在本方法内。
>
> **设计原则**：线性流程，按节点顺序依次执行；每个阶段切换 `player.inPhase`，技能可通过 `inPhase` 过滤当前可用 trigger。
> **死亡中断**：玩家可能在摸牌阶段（牌堆空）、饥饿结算（饥饿伤害致死）、中毒结算、面前怪物行动等阶段死亡，死亡后立即 return，后续节点不再执行。
> **trigger 触发对象**：均为 player 自身（player.trigger）。

**事件钩子顺序**（与 [J_gameEventFlow.md §10](../../GameInstructions/J_gameEventFlow.md#10-玩家回合流程) 一致）：

| 节点 | trigger 名 | inPhase | 说明 |
|------|-----------|---------|------|
| 1 | （进入玩家回合） | `"回合开始"` | 重置行动次数与回合临时标记，非钩子节点 |
| 2 | 回合开始前 | `"回合开始"` | 回合开始前 trigger |
| 3 | 回合开始时 | `"回合开始"` | 如 MapBlocks（避难所、电厂） |
| 4 | 怪物出生前 | `"怪物出生"` | 怪物出生检定前 trigger |
| 5 | 怪物出生时 | `"怪物出生"` | 调用 [monsterSpawnJudge()](#monsterspawnjudge) 进行怪物出生检定 |
| 6 | 摸牌阶段前 | `"摸牌阶段"` | 摸牌前 trigger |
| 7 | （摸牌阶段） | `"摸牌阶段"` | `player.draw(1)`，牌堆空 → 玩家死亡 |
| 8 | 行动阶段前 | `"行动阶段"` | 含潜行检定（地块有怪物标记时，检定在 trigger 之前执行） |
| 9 | （行动阶段） | `"行动阶段"` | 执行 4 个行动 + 免费行动（制衡、交易） |
| 10 | 行动阶段结束前 | `"行动阶段"` | 如 gunslinger（扣动扳机让我快乐 subSkill） |
| 11 | 行动阶段结束时 | `"行动阶段"` | 行动阶段结束 |
| 12 | 求生者饥饿状态结算前 | `"饥饿结算"` | 如 firefighter（野地夹克 subSkill） |
| 13 | 求生者饥饿状态结算时 | `"饥饿结算"` | `player.increaseHunger(1)` |
| 14 | 求生者中毒状态结算前 | `"中毒结算"` | 中毒结算前 |
| 15 | 求生者中毒状态结算时 | `"中毒结算"` | `player.poison()`（有中毒标记时） |
| 16 | 面前怪物行动前 | `"怪物行动"` | 面前怪物行动前 |
| 17 | 面前怪物行动时 | `"怪物行动"` | 面前怪物按进入顺序行动（见 [I_monsterAction.md](../../GameInstructions/I_monsterAction.md)） |
| 18 | 回合结束前 | `"回合结束"` | 如 gunslinger、MapBlocks（游乐园、警察局、城市街道） |
| 19 | 回合结束时 | `"回合结束"` | 如 MapBlocks（游乐园） |
| 20 | （退出玩家回合） | `"回合外"` | 重置 inPhase，非钩子节点 |
| 21 | （胜利判定） | — | 由 [GameStateMachine.checkWinCondition()](../Core/GameStateMachine.md#checkwincondition) 在 `开始回合()` 返回后执行 |

**event 成员**：`event.player`（始终为该玩家）、`event.cancelled`、`event.cancel()`（多数节点非取消点，仅在少数节点有意义）

```gdscript
function player.开始回合() {
    event = {
        player: player,
        cancelled: false,
    }

    # === 节点 1：进入玩家回合（非钩子节点） ===
    player.inPhase = "回合开始"
    # 重置本回合相关状态
    player.设置行动次数(player.最大行动次数)
    player.清除回合临时标记()  # 如"避难所失效"等持续到回合结束的标记

    # === 节点 2：回合开始前 ===
    player.trigger("回合开始前", event)

    # === 节点 3：回合开始时 ===
    #    如 MapBlocks（避难所、电厂）
    player.trigger("回合开始时", event)

    # === 节点 4：怪物出生前 ===
    player.inPhase = "怪物出生"
    player.trigger("怪物出生前", event)

    # === 节点 5：怪物出生时 ===
    #    进行怪物出生检定（见 §五 monsterSpawnJudge）
    player.trigger("怪物出生时", event)
    player.monsterSpawnJudge()

    # === 节点 6：摸牌阶段前 ===
    player.inPhase = "摸牌阶段"
    player.trigger("摸牌阶段前", event)

    # === 节点 7：摸牌阶段（非钩子节点） ===
    #    从求生者的游戏牌堆抓取一张牌；牌堆空 → 玩家死亡（由 draw 内部触发 playerDeath）
    player.draw(1)

    # 玩家可能在摸牌阶段死亡（牌堆空），死亡后流程中止
    if (!player.isAlive()) {
        return
    }

    # === 节点 8：行动阶段前 ===
    player.inPhase = "行动阶段"
    # 如果玩家所在地块上有怪物标记，玩家需要进行潜行检定
    # （与 moveTo 节点 10 一致的失败处理：移除标记 + 抓怪物）
    block = player.get_current_block()
    if (block.hasMonsterMark()) {
        if (!player.sneakJudge()) {
            num = block.countMonsterMark()
            block.removeMonsterMark(num)
            player.drawMonster(num)
        }
    }
    player.trigger("行动阶段前", event)

    # === 节点 9：行动阶段（非钩子节点） ===
    #    执行 4 个行动 + 免费行动（制衡、交易）
    #    系统等待玩家通过 UI 选择 active="行动阶段" 的技能或选择结束行动
    #    行动次数耗尽或玩家主动结束时进入下一节点
    player.等待玩家行动()

    # === 节点 10：行动阶段结束前 ===
    #    如 gunslinger（扣动扳机让我快乐 subSkill）
    player.trigger("行动阶段结束前", event)

    # === 节点 11：行动阶段结束时 ===
    player.trigger("行动阶段结束时", event)

    # === 节点 12：求生者饥饿状态结算前 ===
    player.inPhase = "饥饿结算"
    #    如 firefighter（野地夹克 subSkill）
    player.trigger("求生者饥饿状态结算前", event)

    # === 节点 13：求生者饥饿状态结算时 ===
    player.trigger("求生者饥饿状态结算时", event)
    player.increaseHunger(1)

    # 玩家可能在饥饿结算后死亡（饥饿伤害致死），死亡后流程中止
    if (!player.isAlive()) {
        return
    }

    # === 节点 14：求生者中毒状态结算前 ===
    player.inPhase = "中毒结算"
    player.trigger("求生者中毒状态结算前", event)

    # === 节点 15：求生者中毒状态结算时 ===
    player.trigger("求生者中毒状态结算时", event)
    player.poison()

    # 玩家可能在中毒结算后死亡，死亡后流程中止
    if (!player.isAlive()) {
        return
    }

    # === 节点 16：面前怪物行动前 ===
    player.inPhase = "怪物行动"
    player.trigger("面前怪物行动前", event)

    # === 节点 17：面前怪物行动时 ===
    #    玩家面前的怪物按进入求生者怪物区的顺序行动，先进入的先行动
    #    详见 I_monsterAction.md
    player.trigger("面前怪物行动时", event)
    for (monster in player.怪物区) {
        monster.action()  # 单个怪物行动流程，见 I_monsterAction.md
    }

    # 玩家可能在面前怪物行动后死亡，死亡后流程中止
    if (!player.isAlive()) {
        return
    }

    # === 节点 18：回合结束前 ===
    player.inPhase = "回合结束"
    #    如 gunslinger（扣动扳机让我快乐 subSkill）、MapBlocks（游乐园、警察局、城市街道）
    player.trigger("回合结束前", event)

    # === 节点 19：回合结束时 ===
    #    如 MapBlocks（游乐园）
    player.trigger("回合结束时", event)

    # === 节点 20：退出玩家回合（非钩子节点） ===
    player.inPhase = "回合外"

    # === 节点 21：胜利判定 ===
    #    由 GameStateMachine.nextTurn() 在本方法返回后调用 checkWinCondition()
    #    不在 player.开始回合() 内执行
}
```

> **设计说明**：
> - **节点 8 潜行检定**：行动阶段前的潜行检定与 [moveTo](#moveto) 节点 10 一致，失败时移除所有怪物标记并每移除一个抓一张怪物卡。这一检定在「行动阶段前」trigger **之前**执行，确保 trigger 触发时地块已无怪物标记。
> - **节点 9 行动阶段**：`player.等待玩家行动()` 为占位方法，实际由 UI 层驱动；行动次数耗尽或玩家主动结束时返回。
> - **死亡中断**：摸牌/饥饿/中毒/怪物行动后均检查 `isAlive()`，死亡则立即 return，后续节点不再执行。玩家死亡流程（playerDeath）由 [draw](#drawn) / [increaseHunger](#increasehungernum) / [poison](#poison) / 怪物攻击流程内部触发。
> - **节点 21 位置**：胜利判定放在状态机而非 `player.开始回合()` 内，原因是 `checkWinCondition()` 涉及跨玩家状态查询（所有存活玩家位置、面包车状态等），属于游戏级而非玩家级职责。
> - **trigger 触发对象**：所有 trigger 均为 `player.trigger`（玩家身上的技能）。Game 类不继承 Entity 无自身 trigger；MapBlocks 的地块技能已挂载到 player 身上，由 `player.trigger` 统一触发。

---

### 十一、迷你回合流程

#### 立即执行一个行动(num=1)

> 让玩家立即插入一个**仅含行动阶段**的迷你回合。
> 跳过摸牌/饥饿/中毒/面前怪物行动等阶段，仅保留行动阶段。
> 触发场景：被其他玩家技能指定为目标时——如 gunslinger「战术领导力」、surgeon「希波克拉底誓言」(num=2)、blue「对讲机」。
> 行动次数：迷你回合内行动次数 = num（默认 1），由调用方指定。
> 不触发「回合开始前/时」「回合结束前/时」等回合级 trigger，避免与正常回合的回合级 trigger 重复触发（如 MapBlocks 避难所、gunslinger 扣动扳机让我快乐）。
> 迷你回合内的行动可正常触发其他事件流程（伤害、移动、抓牌等），这些流程的 trigger 正常执行。

```gdscript
function player.立即执行一个行动(num=1) {
    # 保存当前阶段（迷你回合结束后恢复）
    originalPhase = player.inPhase

    # 切换到行动阶段
    player.inPhase = "行动阶段"
    player.设置行动次数(num)  # 迷你回合内行动次数

    # 玩家执行 num 次行动（含免费行动），与正常回合行动阶段一致
    # 系统等待玩家通过 UI 选择 active="行动阶段" 的技能或选择结束行动
    # 行动次数耗尽或玩家主动结束时返回

    # 恢复原阶段
    player.inPhase = originalPhase
}
```

> **设计说明**：
> - 迷你回合本质是"额外的行动机会"，不是完整回合，因此跳过所有非行动阶段
> - 不引入专用的「迷你回合开始/结束」trigger，避免 trigger 数量膨胀；如未来有技能需要钩在迷你回合开始/结束，再行提案
> - 迷你回合内可使用 `usable: 1` 的免费行动（如制衡、交易），但 usable 计数与正常回合共享（避免同一回合内重复使用）
> - 嵌套调用不推荐：迷你回合内触发的技能若再次调用 `立即执行一个行动`，可能产生递归，需调用方自行控制

---

### 十二、底层接口与工具方法

#### 生命值/饥饿值/潜行值

| 方法 | 说明 |
|------|------|
| `get_hp()` / `get_max_hp()` | 继承自 Entity |
| `add_hp(n)` / `reduce_hp(n)` | 继承自 Entity（底层原子方法） |
| `get_hunger()` / `add_hunger(n)` / `reduce_hunger(n)` | 饥饿值读写 |
| `get_sneak()` | 获取潜行值（含饥饿状态修正） |

#### 区域管理

| 方法 | 说明 |
|------|------|
| `get_current_block()` | 返回当前所在地块 |
| `get_role_card()` | 返回角色卡 |
| `getCards(source=, position=, name=, quantity=)` | 按条件查询玩家区域中的牌 |
| `getAllGameCards()` | 返回所有求生者游戏牌（手牌+装备+牌堆+弃牌堆） |
| `移除区域牌(card)` | 从所在区域移除一张牌（内部方法） |

#### 标记管理

| 方法 | 说明 |
|------|------|
| `countMark(name)` | 返回指定标记的数量 |
| `addMarkSkill(markName, quantity, Until)` | 添加标记，可指定持续时间 |
| `removeMarkSkill(markName)` | 移除标记 |
| `hasMarkSkill(name)` / `hasMark(name)` | 判断是否持有标记 |

#### 装备管理

| 方法 | 说明 |
|------|------|
| `hasEquipment(name)` | 是否装备了指定装备 |
| `getEquipment(name)` | 按装备名返回装备区中的装备对象（找不到返回 NULL） |
| `已用装备栏()` | 返回装备区所有装备牌占用格数之和（`sum(card.大小)`） |
| `增加装备栏(n)` / `减少装备栏(n)` | 调整装备栏容量 |

#### 行动管理

| 方法 | 说明 |
|------|------|
| `设置行动次数(n)` | 设置当前行动次数（[开始回合](#十回合流程) 节点 1 重置为 `最大行动次数`） |
| `减少行动次数(n)` | 消耗行动次数 |
| `getNumber(key)` | 获取数值型状态（如"玩家剩余行动次数"） |
| `等待玩家行动()` | 占位方法，由 UI 层驱动玩家在行动阶段执行行动（[开始回合](#十回合流程) 节点 9 调用） |
| `清除回合临时标记()` | 清除持续到回合结束的临时标记（如"避难所失效"） |
| `isAlive()` | 玩家是否存活（生命值 > 0） |

#### 选择器（玩家交互）

| 方法 | 说明 |
|------|------|
| `choose(list)` | 从选项列表中选择一个 |
| `chooseCard(n, position=, source=)` | 从指定区域选择 n 张牌 |
| `chooseMapBlock(options)` | 选择一个地图块 |
| `showCard(card, target)` | 向目标玩家展示一张牌 |

---

## 通用行动技能

> 6 个通用行动技能（移动、拾荒、摸牌、制衡、交易、加油）定义在 [Skill.md](../Common/Skill.md#通用行动技能) 中。
> 这些技能是 Player 类的固有技能，所有玩家共享。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。复用 trigger / damage / 生命值接口 |
| [GameStateMachine](../Core/GameStateMachine.md) | 状态机调用 `player.开始回合()` 执行完整回合流程 |
| [Monster](Monster.md) | 玩家怪物区持有怪物；可攻击其他玩家面前的怪物 |
| [Card](Card.md) | 手牌区/装备区/牌堆持有各类卡牌 |
| [MapBlock](MapBlock.md) | 玩家位于地块上；地块技能挂载到玩家身上 |
| [Game](../Game/Game.md) | Game 管理所有玩家；玩家死亡触发全灭判定 |
| [RoleCard](../Common/RoleCard.md) | 玩家持有角色卡 |
| [Pile](../Common/Pile.md) | 游戏牌堆/弃牌堆为 Pile 实例 |
| [Skill](../Common/Skill.md) | 通用行动技能 + 角色固有技能 + 装备技能均挂载在 Player 上 |
