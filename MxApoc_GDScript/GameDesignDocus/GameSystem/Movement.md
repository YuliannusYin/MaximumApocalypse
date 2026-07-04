# 移动系统

# 底层移动函数（不扣行动次数，只负责移动和触发钩子）
# 核心原则：所有地图块技能全部挂载到玩家身上，由 player.trigger() 统一触发
# 流程：离开地块前 → 离开地块时 → 离开地块后 → 获取目标技能 → 进入地块前（准入检定）→ 移动时 → 清理旧技能 → 进入地块时 → 进入地块后 → 潜行检定
function player.moveTo(target) {
    source = player.所在地图块()

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
    if (!target.已展示()) {
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