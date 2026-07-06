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
| inPhase | String | 当前所处回合阶段（"行动阶段" 等），技能 filter 用 |

### 区域字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 手牌区 | List\<Card\> | 手牌所在区域。上限 10 张 |
| 装备区 | List\<EquipmentCard\> | 装备牌所在区域。受装备栏容量限制 |
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
- **装备类**：卡牌进入装备区前/时/后、卡牌离开装备区前/时/后、弹药耗尽时
- **检定类**：潜行检定前/时/后、怪物出生检定前/时/后
- **弃牌/销毁类**：弃置牌前/时/后、销毁牌前/时/后

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
        target: NULL,
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
        event.target = card
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
    #    mechanic「感应地雷」在此对 event.target 造成伤害
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

        # 从原位置移除
        player.移除区域牌(card)

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

```gdscript
function player.moveTo(target) {
    source = player.get_current_block()

    event = {
        player: player,
        source: source,
        target: target,
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
> 潜行值 = 玩家潜行值 - (所在地块怪物数 + 怪物标记数)。
> 检定结果 ≤ 潜行值则成功，否则失败。

```gdscript
function player.sneakJudge() {
    num = countMonster(player.get_current_block()) + countMonsterMark(player.get_current_block())
    sneakValue = player.get_sneak() - num
    result = player.judge()
    if (result <= sneakValue) {
        return true
    } else {
        return false
    }
}
```

> **触发场景**：玩家进入有怪物标记的地块时（[moveTo](#moveto) 节点 10）；玩家回合行动阶段前（地块有怪物标记时）。
> **失败处理**：移除该地图块上的所有怪物标记，每移除一个怪物标记就抓一张怪物卡。

---

#### monsterSpawnJudge()

> 怪物出生检定方法。
> 检定结果对应地图块的 monster_spawn_value，匹配的地图块执行怪物出生逻辑。

```gdscript
function player.monsterSpawnJudge() {
    result = player.judge()
    List = 所有已经展示的，且 monster_spawn_value 等于 result 的地图块
    for i in List {
        if (i.countMonsterMark() < 3) {
            i.addMonsterMark(1)
        } else if (i.countMonsterMark() == 3 && i.hasPlayer()) {
            List2 = 此地图块上的所有玩家
            for j in List2 {
                j.drawMonster(1)
            }
        }
    }
}
```

> **触发场景**：玩家回合节点 5「怪物出生时」。

---

### 六、死亡流程

#### playerDeath(source)

> 实现 [Entity.death](../Core/Entity.md#6-抽象方法子类实现)。
> 流程：死亡前 → 死亡时 → 死亡后（清理 + 事件）。
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

    # 1. target 死亡前
    player.trigger("死亡前", event)

    # 2. target 死亡时
    player.trigger("死亡时", event)

    # 3. target 死亡后

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

    player.trigger("死亡后", event)

    # 检查游戏结束条件
    if (game.allPlayersDead()) {
        game.gameOver("lose")
    }
}
```

---

### 七、装备流程 [提案]

#### 装备(card)

> 装备进入装备区流程。
> 落地 [EventSystem §4.7](../Core/EventSystem.md#47-装备类) 的装备类 trigger。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 卡牌进入装备区前 | 可校验装备栏容量 [提案] |
| 2 | 卡牌进入装备区时 | 装备置入装备区 |
| 3 | 卡牌进入装备区后 | 装备进入完成 [提案] |

```gdscript
function player.装备(card) {
    event = {
        player: player,
        card: card,
        cancelled: false,
    }

    # 1. 卡牌进入装备区前 [提案]
    player.trigger("卡牌进入装备区前", event)
    if (event.cancelled) {
        return
    }

    # 2. 卡牌进入装备区时
    player.装备区.add(card)
    player.addSkill(card.技能)  # 装备技能挂载到玩家
    player.trigger("卡牌进入装备区时", event)

    # 3. 卡牌进入装备区后 [提案]
    player.trigger("卡牌进入装备区后", event)
}
```

---

#### 卸下(card)

> 装备离开装备区流程。
> 通常作为 `discard(card)` 的一部分被调用。

**事件钩子顺序**：

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 卡牌离开装备区前 | [提案] |
| 2 | 卡牌离开装备区时 | 装备离开装备区 |
| 3 | 卡牌离开装备区后 | [提案]；衍生 trigger「弹药耗尽时」 |

```gdscript
function player.卸下(card) {
    event = {
        player: player,
        card: card,
        cancelled: false,
    }

    # 1. 卡牌离开装备区前 [提案]
    player.trigger("卡牌离开装备区前", event)
    if (event.cancelled) {
        return
    }

    # 2. 卡牌离开装备区时
    player.装备区.remove(card)
    player.removeSkill(card.技能)  # 装备技能从玩家移除
    player.trigger("卡牌离开装备区时", event)

    # 3. 卡牌离开装备区后 [提案]
    player.trigger("卡牌离开装备区后", event)
}
```

---

### 八、填充物流程 [提案]

#### 消耗填充物(equipment, num, type)

> 装备填充物消耗流程（如枪械消耗弹药、打火机消耗燃料）。
> 落地 [EventSystem §4.7](../Core/EventSystem.md#47-装备类) 的「弹药耗尽时」trigger。

```gdscript
function player.消耗填充物(equipment, num, type) {
    # 扣减填充物
    equipment.填充物当前量 -= num

    # 检测填充物耗尽
    if (equipment.填充物当前量 <= 0) {
        event = {
            player: player,
            card: equipment,
            cancelled: false,
        }
        player.trigger("弹药耗尽时", event)
    }
}
```

---

### 九、底层接口与工具方法

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
| `增加装备栏(n)` / `减少装备栏(n)` | 调整装备栏容量 |

#### 行动管理

| 方法 | 说明 |
|------|------|
| `减少行动次数(n)` | 消耗行动次数 |
| `getNumber(key)` | 获取数值型状态（如"玩家剩余行动次数"） |

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
| [Monster](Monster.md) | 玩家怪物区持有怪物；可攻击其他玩家面前的怪物 |
| [Card](Card.md) | 手牌区/装备区/牌堆持有各类卡牌 |
| [MapBlock](MapBlock.md) | 玩家位于地块上；地块技能挂载到玩家身上 |
| [Game](../Game/Game.md) | Game 管理所有玩家；玩家死亡触发全灭判定 |
| [RoleCard](../Common/RoleCard.md) | 玩家持有角色卡 |
| [Pile](../Common/Pile.md) | 游戏牌堆/弃牌堆为 Pile 实例 |
| [Skill](../Common/Skill.md) | 通用行动技能 + 角色固有技能 + 装备技能均挂载在 Player 上 |
