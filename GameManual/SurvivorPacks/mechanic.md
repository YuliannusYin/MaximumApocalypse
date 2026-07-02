# 机械师
## 角色详情

# 机械师角色固有技能（非卡牌，开局即拥有）；生命值与潜行值由角色本身决定
求生者{
    角色名称: 机械师
    生命值上限: 26
    初始生命值: 26
    潜行值: 8
    饥饿状态潜行值: 7
    技能: {
        技能名: "维修"
        技能描述: "行动：从任一弃牌堆中选择一张装备牌，并把它放置在场上任一玩家的装备区中。"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且场上所有弃牌堆中至少有1张装备牌时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && 场上所有弃牌堆中至少有1张装备牌 # 自然语言描述，待实现为具体函数调用
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = 所有弃牌堆中的装备牌 # 获取所有弃牌堆中的装备牌（包括所有玩家的弃牌堆和拾荒弃牌堆），返回装备牌列表；自然语言描述，待实现为具体函数调用
            card = player.chooseCard(List) # 从所有装备牌中选择一张装备牌
            target = player.chooseTarget({
                selectTarget: 1 # 选择场上任一玩家
                filterTarget: return target.type == Human # 目标必须是人类类型（玩家）
                filterTargetRange: Infinity # 无距离限制
            })
            target.装备( card ) # 将装备牌放置到目标玩家的装备区
        }
    }
}

## 角色游戏牌库

求生者游戏牌{
    名字：扳手
    牌库中数量：3
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "扳手"
        技能描述: "行动：对一个目标造成2点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害(2, player) # 对目标造成2点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：钉子炸弹
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "钉子炸弹"
        技能描述: "行动：对射程内的最多3个怪物各造成5点伤害"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: [1, 3]
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                    i.受到伤害(5, player) # 对每个目标造成5点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：感应地雷
    牌库中数量：3
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "感应地雷"
        技能描述: "被动：当你抓取一张怪物卡后，弃掉此装备并对该怪物造成7点伤害。"
        skillType: "装备"
        trigger: 抓取怪物卡后
        filter: true
        forced: true # 强制发动
        content:{
            player.discard( name = "感应地雷", position = "装备区" ) # 弃掉此装备
            trigger.monster.受到伤害(7, player) # 对该怪物造成7点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：焊接头盔
    牌库中数量：2
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "焊接头盔"
        技能描述: "被动：受到的伤害减一。"
        skillType: "装备"
        trigger: 受到伤害时
        filter: true # 任意来源的伤害均触发
        forced: true # 强制发动
        content:{
            trigger.num-- # trigger.num 为本次伤害的伤害值变量；将其减1，实现受到的伤害减1点
        }
    }
}

求生者游戏牌{
    名字：检查武器
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "检查武器"
        技能描述: "行动：所有玩家造成的伤害增加1，直到其回合结束。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = getAllPlayers() # 获取场上所有玩家
            for i in List:
                i.addTempSkill('检查武器_damage', until = "回合结束时") # until 绑定到各玩家 i 自身的回合结束时
        }
        subSkill: {
            damage: {
                trigger: 造成伤害时
                forced: true
                filter: true
                content: trigger.num += 1 # 造成的伤害+1
            }
        }
    }
}

求生者游戏牌{
    名字：喷灯
    牌库中数量：2
    类型：装备
    填充物上限：3
    初始填充数：3
    填充物类型：燃料
    大小：2格装备栏
    技能: {
        技能名: "喷灯"
        技能描述: "行动：消耗1点燃料，对一个目标造成5点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有燃料时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "喷灯" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "喷灯" ) # 消耗1点燃料
            target.受到伤害(5, player) # 对目标造成5点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：启动汽车
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "启动汽车"
        技能描述: "行动：将任一玩家移动到任一已展示的地图块。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        complexTarget: true # 需选择两类目标（玩家+地图块），使用复合目标模式
        filterTarget1: return target.type == Human # 任一玩家
        filterTarget1Range: Infinity # 无距离限制
        filterTarget2: return target.已展示() # 任一已展示的地图块
        filterTarget2Range: Infinity # 无距离限制
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target1.moveTo(target2) # 调用底层移动函数（见 PlayerSkill.md 中 player.moveTo 定义，会触发离开/进入地块钩子）
        }
    }
}

求生者游戏牌{
    名字：升级
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "升级"
        技能描述: "行动：放置在射程内的任一武器上，那张武器额外造成1点伤害。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标装备
        filterTarget: return target.类型 == "装备"
        filterTargetRange: "中距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            该武器额外造成1点伤害 # 自然语言描述，待实现为具体函数调用；该武器额外造成1点伤害
        }
    }
}

求生者游戏牌{
    名字：手枪
    牌库中数量：1
    类型：装备
    填充物上限：4
    初始填充数：4
    填充物类型：弹药
    大小：1格装备栏
    技能: {
        技能名: "手枪"
        技能描述: "行动：消耗1枚弹药，对一个目标造成2点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "手枪" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内（即目标在玩家所在地块及其相邻地块中）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "手枪" ) # 消耗1枚弹药
            target.受到伤害(2, player) # 对目标造成2点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：无人机攻击
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "无人机攻击"
        技能描述: "行动：从1个地图块上移除所有怪物标记。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target = player.chooseMapBlock({
                filterTarget: return target.已展示() # 任一已展示的地图块
                filterTargetRange: Infinity # 无距离限制
            })
            target.移除所有怪物标记() # 纯移除，不触发"杀死怪物时"事件；自然语言描述，待实现为具体函数调用
        }
    }
}

求生者游戏牌{
    名字：阅读使用说明
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "阅读使用说明"
        技能描述: "行动：把你的一张装备卡装备给另一名玩家，然后你抓取一张牌。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        complexTarget: true # 需选择两类目标（装备牌+目标玩家），使用复合目标模式
        filterTarget1: return target.在玩家装备区内 # 玩家自己装备区内的一张装备牌
        filterTarget2: return target.type == Human && target != player # 另一名玩家
        filterTarget2Range: "中距离" # 目标必须在中距离范围内
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target2.装备( target1 ) # 将玩家选定的装备牌装备给目标玩家（装备函数应处理从原装备区移除）
            player.draw(1) # 抓取一张牌
        }
    }
}

求生者游戏牌{
    名字：自动炮塔
    牌库中数量：2
    类型：装备
    填充物上限：4
    初始填充数：4
    填充物类型：弹药
    大小：2格装备栏
    技能: {
        技能名: "自动炮塔"
        技能描述: "被动：每次你受到伤害时，自动炮塔对伤害来源造成4点伤害。"
        skillType: "装备"
        trigger: 受到伤害时
        # 仅当存在可反击的伤害来源时触发（饥饿等无来源伤害不触发）；排除自伤以防递归循环
        filter: return trigger.source != null && trigger.source != player
        forced: true # 强制发动
        content:{
            trigger.source.受到伤害(4, player) # 对伤害来源造成4点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：自制子弹
    牌库中数量：5
    类型：行动
    技能: {
        技能名: "自制子弹"
        技能描述: "行动：完全装填射程内的任一武器。"
        射程: "短距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标装备
        filterTarget: return target.类型 == "装备" && target.填充物类型 != null # 射程内的任一可装填武器
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.补满填充物() # 完全装填该武器
        }
    }
}
