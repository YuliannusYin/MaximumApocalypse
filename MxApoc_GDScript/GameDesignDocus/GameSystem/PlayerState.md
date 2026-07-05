# 玩家状态系统

# ——————————————————————————————————————————————

# 恢复生命值方法
# 走完整 4 节点事件流程（前/时/系统加血/后），见 J_gameEventFlow.md §16
# 系统加血受最大生命值上限约束；event.num 可被「回复生命时」钩子修改
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
    max = player.最大生命值() - player.生命值()
    if (event.num > max) {
        event.num = max
    }
    player.增加生命值(event.num)

    # 4. 回复生命后 [提案]
    player.trigger("回复生命后", event)
}

# ——————————————————————————————————————————————

# 增加饥饿值方法
# 饥饿值达到 6 后翻面角色卡，并逐级叠加饥饿伤害标记
# 饥饿伤害为无来源伤害（source = NULL），由 damage 流程跳过 source 侧钩子
function player.increaseHunger(num) {
    if (num <= 0) {
        return
    }
    while (num > 0) {
        if (player.饥饿值() < 6) {
            player.增加饥饿值(1)
        } else if (player.饥饿值() == 6) {
            if (player.角色卡牌.is正面()) {
                player.角色卡牌.翻面()
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
                game.log(player.名字 + "被饿死了")
                player.damage(player.最大生命值(), NULL, "饥饿伤害")
            }
        }

        num -= 1
    }
}

# ——————————————————————————————————————————————

# 减少饥饿值方法
# 饥饿值最低降至 1，减少后清除饥饿伤害标记并恢复角色卡正面
function player.decreaseHunger(num) {
    if (num <= 0) {
        return
    }
    max = player.饥饿值() - 1
    if (num > max) {
        num = max
    }
    if (num <= 0) {
        game.log("饥饿值已减少到1，无法继续减少")
        return false
    }
    player.减少饥饿值(num)
    if (player.countMark("饥饿伤害等级") > 0) {
        player.removeMarkSkill("饥饿伤害等级")
    }
    if (!player.角色卡牌.is正面()) {
        player.角色卡牌.翻面()
    }
}

# ——————————————————————————————————————————————

# 中毒结算方法
# 在玩家回合的"求生者中毒状态结算"阶段调用
# 中毒伤害为无来源伤害（source = NULL）
function player.poison() {
    if (player.countMark("poison") > 0) {
        num = player.countMark("poison")
        player.damage(num, NULL, "poison")
    }
}