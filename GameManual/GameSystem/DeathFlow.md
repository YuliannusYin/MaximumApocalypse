# 死亡流程

# ——————————————————————————————————————————————

# “target（玩家）被source击杀” 的流程方法
# 流程：死亡前 → 死亡时 → 死亡后（清理 + 事件）
# 清理内容：
#   a. 怪物区怪物 → 弃牌堆，等量怪物标记（最多3个）放回地块
#   b. 所有求生者游戏牌移出游戏
#   c. 拾荒卡按颜色洗回对应拾荒牌堆
# 最后检查全灭 → 游戏失败
function target.playerDeath(source) {
    event = {
        target: target,
        source: source,
    }

    # 1. target死亡前
    target.trigger("死亡前", event)

    # 2. target死亡时
    target.trigger("死亡时", event)

    # 3. target死亡后

    # 3a. 把其角色面前的所有怪物置入弃牌堆，替换为等量的怪物标记（最多3个）
    怪物列表 = target.怪物区.getAll()
    markCount = min(怪物列表.length, 3)
    for m in 怪物列表 {
        target.怪物区.remove(m)
        怪物弃牌堆.add(m)
    }
    if (markCount > 0) {
        target.所在地图块().addMonsterMark(markCount)
    }

    # 3b. 将场上所有该角色的求生者游戏牌移出游戏
    #     覆盖手牌区、装备区、游戏牌堆、游戏牌弃牌堆
    游戏牌列表 = target.getAllGameCards()
    for c in 游戏牌列表 {
        game.removeCard(c)
    }

    # 3c. 该角色携带的所有拾荒卡根据颜色洗回对应拾荒牌堆
    拾荒牌列表 = target.getCards(source = "scavenge")
    for c in 拾荒牌列表 {
        颜色 = c.颜色
        target.removeCard(c)
        game.getScavengePile(颜色).add(c)
    }
    # 各颜色拾荒牌堆分别洗牌
    for 颜色 in ["red", "green", "blue"] {
        game.getScavengePile(颜色).shuffle()
    }

    target.trigger("死亡后", event)

    # 检查游戏结束条件
    if (game.allPlayersDead()) {
        game.gameOver("lose")
    }
}

# ——————————————————————————————————————————————

# “target（怪物）被source击杀” 的流程方法
# 流程：死亡前 → 死亡时（触发怪物死亡事件） → 死亡后（移除怪物卡）
function target.monsterDeath(source) {
    event = {
        target: target,
        source: source,
    }

    # 1. 怪物死亡前
    target.trigger("死亡前", event)

    # 2. 怪物死亡时 —— 触发怪物死亡事件（如僵尸女王的技能在此触发）
    target.trigger("死亡时", event)

    # 3. 怪物死亡后
    # 将怪物卡从求生者怪物区移除，进入怪物卡弃牌堆
    纠缠玩家 = target.纠缠对象
    纠缠玩家.怪物区.remove(target)
    怪物弃牌堆.add(target)

    target.trigger("死亡后", event)
}