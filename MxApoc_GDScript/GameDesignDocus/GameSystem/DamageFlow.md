# 伤害流程

# “target受到来自于source的num点类型为type的伤害” 的流程方法
# 事件钩子顺序：
#   1. source造成伤害前（source != NULL 时）
#   2. target受到伤害前
#   3. source造成伤害时（source != NULL 时，可修改 event.num）
#   4. target受到伤害时（取消点：可调用 event.cancel()）
#   5. 系统内部扣血
#   6. source造成伤害后（source != NULL 时）
#   7. target受到伤害后
#   8. 死亡判定 → playerDeath / monsterDeath
function target.damage(num, source, type = NULL ) {
    if (num <= 0) {
        return
    }
    if (target.生命值 <= 0) {
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
        # 1. source造成伤害前
        source.trigger("造成伤害前", event)
        # 2. target受到伤害前
        target.trigger("受到伤害前", event)
    } else {
        # 无来源伤害：跳过 source 相关钩子，仅触发 target 受到伤害前
        target.trigger("受到伤害前", event)
    }

    if (source != NULL) {
        # 3. source造成伤害时 —— 技能可在此阶段修改 event.num（如伤害加成）
        source.trigger("造成伤害时", event)
    }

    # 4. target受到伤害时 —— 取消点：技能可在此阶段调用 event.cancel() 取消本次伤害
    #    也可在此阶段修改 event.num（如伤害减免）
    target.trigger("受到伤害时", event)

    if (event.cancelled) {
        return
    }

    # 5. 系统内部执行扣血，不对外暴露成事件钩子
    target.生命值 -= event.num

    if (source != NULL) {
        # 6. source造成伤害后
        source.trigger("造成伤害后", event)
    }

    # 7. target受到伤害后
    target.trigger("受到伤害后", event)

    # 8. 如果目标生命值小于等于零，进入死亡流程
    if (target.生命值 <= 0) {
        if (target.isPlayer()) {
            target.playerDeath(source)
        } else if (target.isMonster()) {
            target.monsterDeath(source)
        }
    }
}