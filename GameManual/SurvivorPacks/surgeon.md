# 外科医生
## 角色详情

# 外科医生角色固有技能（非卡牌，开局即拥有）；生命值与潜行值由角色本身决定
求生者{
    角色名称: 外科医生
    生命值上限: 23
    初始生命值: 23
    潜行值: 8
    饥饿状态潜行值: 7
    技能: {
        技能名: "缝合"
        技能描述: "行动：使一名玩家回复1点生命。"
        射程: "短距离"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标
        filterTarget: return target.type == Human # 目标必须是人类类型（包含玩家幸存者，可用于自救或救他人）
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.recover(1) # 使目标回复1点生命（见 PlayerSkill.md 中 recover 定义）
        }
    }
}

## 角色游戏牌库

求生者游戏牌{
    名字：快速思考
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "快速思考"
        技能描述: "行动：抓取两张牌和一张拾荒卡。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.draw(2) # 从玩家游戏牌库抓取2张牌到手牌区
            result = player.choose(prompt = "请选择你抓取的拾荒卡颜色：", ["red", "green", "blue"]) # 玩家选择拾荒牌堆颜色（无地块颜色限制）
            牌堆 = player.获取拾荒牌堆(result) # 按颜色获取对应拾荒牌堆对象
            player.drawScavenge(1, 牌堆) # 从选定拾荒牌堆抓取1张拾荒卡
        }
    }
}

求生者游戏牌{
    名字：轮床
    牌库中数量：3
    类型：装备
    子类：工具
    大小：2格装备栏
    技能: {
        技能名: "轮床"
        技能描述: "行动：把一名玩家向你拉近1格，不触发地图块效果。"
        射程: "长距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标玩家
        filterTarget: return target.type == Human && target != player # 目标必须是另一名玩家
        filterTargetRange: "长距离" # 目标必须在长距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            # 把目标玩家向你拉近1格，不触发任何地块钩子（直接变更坐标，跳过离开/进入地块钩子和展示效果）
            target.向玩家拉近一格不触发效果(player) # 自然语言描述，待实现为具体函数调用
        }
    }
}

求生者游戏牌{
    名字：莫洛托夫鸡尾酒
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "莫洛托夫鸡尾酒"
        技能描述: "行动：对射程内的所有怪物造成3点伤害。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: -1 # 选择射程内的所有目标
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                i.受到伤害(3, player) # 对每个目标造成3点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：手术刀
    牌库中数量：3
    类型：装备
    子类：武器
    大小：1格装备栏
    技能1: {
        技能名: "手术刀"
        技能描述: "行动：对1个目标造成2点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害(2, player) # 对目标造成2点伤害，伤害来源为玩家
        }
    }
    技能2: {
        技能名: "手术刀·回复"
        技能描述: "被动：回复生命时，额外回复1点。"
        skillType: "装备"
        trigger: 回复生命时
        filter: true # 任意来源的回复均触发
        forced: true # 强制发动
        content:{
            trigger.num += 1 # trigger.num 为本次回复的回复量变量；将其加1，实现额外回复1点
        }
    }
}

求生者游戏牌{
    名字：手套
    牌库中数量：3
    类型：装备
    子类：工具
    大小：1格装备栏
    技能: {
        技能名: "手套"
        技能描述: "被动：回复生命时，额外回复1点。"
        skillType: "装备"
        trigger: 回复生命时
        filter: true # 任意来源的回复均触发
        forced: true # 强制发动
        content:{
            trigger.num += 1 # trigger.num 为本次回复的回复量变量；将其加1，实现额外回复1点
        }
    }
}

求生者游戏牌{
    名字：泰瑟枪
    牌库中数量：2
    类型：装备
    子类：武器
    大小：2格装备栏
    技能: {
        技能名: "泰瑟枪"
        技能描述: "行动：击晕一个怪物直到你的下回合开始。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.击晕(player, until = "下个回合开始时") # 击晕目标直到你的下个回合开始
        }
    }
}

求生者游戏牌{
    名字：希波克拉底誓言
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "希波克拉底誓言"
        技能描述: "行动：使任一玩家回复6点生命。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标
        filterTarget: return target.type == Human # 目标必须是人类类型（包含玩家幸存者，可用于自救或救他人）
        filterTargetRange: Infinity # 无距离限制
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.recover(6) # 使目标回复6点生命（见 PlayerSkill.md 中 recover 定义）
        }
    }
}

求生者游戏牌{
    名字：研钵
    牌库中数量：3
    类型：装备
    子类：载具
    大小：1格装备栏
    技能: {
        技能名: "研钵"
        技能描述: "行动：治疗射程内的一名玩家所有的状态效果，或者降低其饥饿等级1点。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标玩家
        filterTarget: return target.type == Human # 目标必须是人类类型（包含玩家幸存者，可用于自救或救他人）
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            choice = player.choose(["治疗所有状态效果", "降低饥饿等级1点"])
            if( choice == "治疗所有状态效果" ){
                target.治疗所有状态效果() # 自然语言描述，待实现为具体函数调用
            }
            else if( choice == "降低饥饿等级1点" ){
                target.decreaseHunger( 1 ) # 降低目标1点饥饿值（见 PlayerSkill.md 中 decreaseHunger 定义，最低降至1）
            }
        }
    }
}

求生者游戏牌{
    名字：注射类固醇
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "注射类固醇"
        技能描述: "行动：选择一名玩家，该玩家可以立即打出2张牌。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标玩家
        filterTarget: return target.type == Human # 目标必须是人类类型（包含玩家幸存者，可用于对自己使用）
        filterTargetRange: Infinity # 无距离限制
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            # 自然语言描述，待实现为具体函数调用；与「立即执行2个行动」有区别，特指使用2张手牌
            target.立即打出一张牌()
            target.立即打出一张牌()
        }
    }
}

求生者游戏牌{
    名字：注射肾上腺素
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "注射肾上腺素"
        技能描述: "行动：选择一名玩家，该玩家可以立即执行2个行动。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标玩家
        filterTarget: return target.type == Human # 目标必须是人类类型（包含玩家幸存者，可用于对自己使用）
        filterTargetRange: Infinity # 无距离限制
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            # 自然语言描述，待实现为具体函数调用（参考「战术领导力」的立即执行一个行动，此处执行2次）
            target.立即执行一个行动()
            target.立即执行一个行动()
        }
    }
}

求生者游戏牌{
    名字：钻头
    牌库中数量：2
    类型：装备
    子类：武器
    大小：1格装备栏
    技能: {
        技能名: "钻头"
        技能描述: "行动：对1个目标造成3点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害(3, player) # 对目标造成3点伤害，伤害来源为玩家
        }
    }
}
