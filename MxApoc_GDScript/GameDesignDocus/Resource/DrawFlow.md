# 抓牌流程

# "player从其求生者游戏牌堆抓取n张牌到手牌区" 的流程方法
# 事件钩子顺序：
#   1. 抓取游戏牌前（取消点：可调用 event.cancel() 取消本次抓牌）
#   2. 抓取游戏牌时（取消点：可修改 event.num，可调用 event.cancel() 取消）
#   3. 逐张抓取（每张抓取前检查牌堆，牌堆为空时调用 playerDeath(NULL)）
#   4. 抓取游戏牌后
# 牌堆为空时尝试抓取 → 触发玩家死亡（source = NULL）
# 手牌上限由上层校验，draw() 不处理
function player.draw(n) {
    if (n <= 0) {
        return
    }

    # 构建事件对象
    event = {
        player: player,
        num: n,            # 计划抓取的牌数（可在"时"阶段修改）
        cards: [],         # 实际抓取的牌（"后"阶段可访问）
        cancelled: false,
    }

    # 1. 抓取游戏牌前（取消点）
    player.trigger("抓取游戏牌前", event)
    if (event.cancelled) {
        return
    }

    # 2. 抓取游戏牌时（取消点：可修改 event.num 或调用 event.cancel()）
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

---

# 抓取拾荒牌流程

# "player从指定拾荒牌堆抓取n张牌到手牌区" 的流程方法
# 事件钩子顺序：
#   1. 抓取拾荒牌前（取消点：可调用 event.cancel() 取消本次抓牌，如手电筒替代为「看2留1放1」）
#   2. 逐张抓取：抓1张→入手牌区→触发「抓取拾荒牌时」→抓下一张
#   3. 抓取拾荒牌后
# 牌堆为空时停止抓取（不重洗弃牌堆，见 C_gameSetup.md）
# pile 参数统一为 pile 对象（颜色字符串需调用方先通过 game.getScavengePile() 转换）
# 手牌上限由上层校验，drawScavenge() 不处理
function player.drawScavenge(n, pile) {
    if (n <= 0) {
        return
    }

    # 构建事件对象
    event = {
        player: player,
        pile: pile,          # 拾荒牌堆对象
        num: n,              # 计划抓取的牌数（可在"前"阶段修改）
        cards: [],           # 实际抓取的牌（"后"阶段可访问）
        card: NULL,          # 当前抓取的牌（"时"阶段可访问，卡片技能用 event.card 过滤）
        cancelled: false,
    }

    # 1. 抓取拾荒牌前（取消点）
    #    手电筒（blue.md）在此取消并替代为「看2留1放1」逻辑
    player.trigger("抓取拾荒牌前", event)
    if (event.cancelled) {
        return
    }

    # 2. 逐张抓取
    #    牌堆为空时停止（不重洗弃牌堆，见 C_gameSetup.md）
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

---

# 抓取怪物卡流程

# "player从怪物牌堆抓取n张怪物卡到玩家怪物区" 的流程方法
# 事件钩子顺序（每张怪物卡走 2a-2f 节点，全部抓完后走节点 3）：
#   1. 抓取怪物卡前（取消点：可调用 event.cancel() 取消本次抓怪，如 firefighter「梯子」）
#   2. 逐张抓取（每张走完 a-f 完整流程后抓下一张）：
#      a. 牌堆空时重洗怪物弃牌堆；重洗后仍为空 → game.gameOver("lose")
#      b. 抓取怪物卡时（每张触发）
#      c. 怪物卡进入求生者怪物区前（每张触发）
#      d. （实体化：设置纠缠对象、初始化生命值等）
#      e. 怪物卡进入求生者怪物区时（每张触发）
#      f. 怪物卡进入求生者怪物区后（每张触发；如 zombie 一大波僵尸、僵尸步行者在此递归调用 drawMonster）
#   3. 抓取怪物卡后（整体触发一次；如 mechanic「感应地雷」）
# 怪物牌堆空时重洗怪物弃牌堆（与拾荒牌堆不同，见 C_gameSetup.md）
# 重洗后仍为空（所有怪物卡都在场上）→ 游戏失败
# event 成员：event.player（抓取者）、event.target（当前怪物卡，实体化后的怪物对象）
function player.drawMonster(n) {
    if (n <= 0) {
        return
    }

    # 构建事件对象
    event = {
        player: player,       # 抓取怪物卡的玩家
        num: n,               # 计划抓取的怪物卡数
        cards: [],            # 实际抓取的怪物卡列表（节点 3 可访问）
        target: NULL,         # 当前怪物卡（"时"及之后阶段可访问；节点 3 指向最后一张）
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
