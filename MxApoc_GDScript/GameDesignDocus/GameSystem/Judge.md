# 检定系统

# ——————————————————————————————————————————————

# 检定方法：随机投掷两颗大骰子，返回点数之和
function player.judge() {
    player.roll_two_dice()
    result = 两颗大骰子的点数之和
    return result
}

# ——————————————————————————————————————————————

# 潜行检定方法
# 潜行值 = 玩家潜行值 - (所在地块怪物数 + 怪物标记数)
# 检定结果 <= 潜行值则成功，否则失败
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

# ——————————————————————————————————————————————

# 怪物出生检定方法
# 检定结果对应地图块的 monster_spawn_value，匹配的地图块执行怪物出生逻辑
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
