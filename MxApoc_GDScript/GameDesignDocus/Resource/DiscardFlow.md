# 弃牌与销毁流程

---

# 弃置牌流程

# "player弃置卡牌到对应弃牌堆" 的流程方法
# 事件钩子顺序：
#   1. 弃置牌前（取消点：可调用 event.cancel() 取消本次弃牌）
#   2. 逐张弃置（每张：从原位置移除 → 进入对应弃牌堆 → 触发「弃置牌时」）
#   3. 弃置牌后（整体触发一次）
# 弃牌堆分派：按卡牌 source 自动分派
#   - source = "scavenge" → 对应颜色的拾荒弃牌堆（通过 card.颜色 查找）
#   - source = "game" 或其他 → 玩家游戏牌弃牌堆
# 重载签名（target 参数支持多种形态）：
#   - discard(card)                            弃置单张牌
#   - discard(cards)                           弃置多张牌（列表）
#   - discard(name, position=, quantity=1)     按名字+位置弃置 quantity 张
#   - discard(type, type=true)                 按类型弃置所有该类型牌
# position = NULL 时搜索所有区域（手牌区+装备区）
# 多张弃置时逐张触发「弃置牌时」，与 drawScavenge/drawMonster 模式对齐
# event 成员：event.player（弃牌者）、event.card（当前牌，「时」阶段可访问）、event.cards（实际弃置的牌列表）、event.num（计划弃置数）、event.cancelled、event.cancel()
function player.discard(target, position=NULL, quantity=1, type=NULL) {
    # 解析参数，确定要弃置的牌列表
    cardsToDiscard = []

    if (type != NULL) {
        # 按类型弃置：搜索所有区域中该类型的牌
        # 如电厂：discard("食物", type=true) 弃置所有食物类型牌
        allCards = player.getCards(position=position)
        for (card in allCards) {
            if (card.类型 == target) {
                cardsToDiscard.add(card)
            }
        }
    } else if (isCard(target)) {
        # 单张牌对象
        cardsToDiscard.add(target)
    } else if (isList(target)) {
        # 牌列表
        cardsToDiscard = target
    } else {
        # name 字符串：按名字+位置+数量查找
        cardsToDiscard = player.getCards(name=target, position=position, quantity=quantity)
    }

    if (cardsToDiscard.isEmpty()) {
        return
    }

    # 构建事件对象
    event = {
        player: player,
        num: cardsToDiscard.length,
        cards: [],            # 实际弃置的牌（"后"阶段可访问）
        card: NULL,           # 当前弃置的牌（"时"阶段可访问）
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
            # 拾荒卡进入对应颜色的拾荒弃牌堆
            game.getScavengePile(card.颜色).discardPile.add(card)
        } else {
            # 求生者游戏牌进入游戏牌弃牌堆
            player.游戏牌弃牌堆.add(card)
        }

        # 触发「弃置牌时」（每张触发）
        player.trigger("弃置牌时", event)
    }

    # 3. 弃置牌后（整体触发一次）
    player.trigger("弃置牌后", event)
}

---

# 销毁牌流程

# "player销毁卡牌（移出游戏）" 的流程方法
# 与 discard 的区别：销毁的牌不进入弃牌堆，而是移出游戏
# 事件钩子顺序：
#   1. 销毁牌前（取消点：可调用 event.cancel() 取消本次销毁）
#   2. 逐张销毁（每张：从原位置移除 → 移出游戏 → 触发「销毁牌时」）
#   3. 销毁牌后（整体触发一次）
# 重载签名（target 参数支持多种形态）：
#   - removeCard(card)                         销毁单张牌
#   - removeCard(name, position=, quantity=1)  按名字+位置销毁 quantity 张
#   - removeCard(cards)                        销毁多张牌（列表，与 discard 对齐，未直接出现但支持）
# 多张销毁时逐张触发「销毁牌时」
# event 成员：event.player（销毁者）、event.card（当前牌）、event.cards（实际销毁的牌列表）、event.num、event.cancelled、event.cancel()
# 命名统一：原 MapBlocks(坠毁点) 使用的 player.remove(card) 已统一为 player.removeCard(card)（见待定义方法.md §9.5）
function player.removeCard(target, position=NULL, quantity=1) {
    # 解析参数，确定要销毁的牌列表
    cardsToRemove = []

    if (isCard(target)) {
        # 单张牌对象
        cardsToRemove.add(target)
    } else if (isList(target)) {
        # 牌列表
        cardsToRemove = target
    } else {
        # name 字符串：按名字+位置+数量查找
        cardsToRemove = player.getCards(name=target, position=position, quantity=quantity)
    }

    if (cardsToRemove.isEmpty()) {
        return
    }

    # 构建事件对象
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
