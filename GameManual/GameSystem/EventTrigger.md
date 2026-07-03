# 事件触发系统

# 遍历实体上所有匹配 triggerName 的技能，依次执行。
# entity.getAllSkills() 返回该实体上所有技能（含角色固有技能、装备技能、临时技能等）。
# 技能 content 执行时，上下文中可访问以下变量：
#   - event：事件对象（event.num、event.source、event.target、event.type、event.cancel() 等）
#   - trigger：当前触发的触发名称字符串（用于 trigger == "xxx" 判断多触发技能的分支）
# 技能的 trigger 字段可以是单个字符串（如 "造成伤害时"）或 "、" 分隔的多个字符串（如 "游戏开始时、受到伤害时"）。
function entity.trigger(triggerName, event) {
    event.triggerName = triggerName
    skills = entity.getAllSkills()
    for s in skills {
        triggerList = s.trigger.split("、")
        if (triggerList.contains(triggerName) && s.filter(event)) {
            s.content(event)
            if (event.cancelled) {
                break
            }
        }
    }
}