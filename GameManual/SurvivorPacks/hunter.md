# 猎人
## 角色详情

# 猎人角色固有技能（非卡牌，开局即拥有）；生命值与潜行值由角色本身决定
求生者{
    角色名称: 猎人
    生命值上限: 24
    初始生命值: 24
    潜行值: 9
    饥饿状态潜行值: 8
    技能: {
        技能名: "侦察"
        技能描述: "行动：最多展示两个相邻的地图块，且不触发任何地块触发效果。"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且所在地块存在相邻未展示地块时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && 玩家所在地块有相邻且未展示的地图块 # 自然语言描述，待实现为具体函数调用
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            maxReveal = 2 # 最多展示两个相邻地块
            count = 0
            while( count < maxReveal ){
                target = player.chooseMapBlock({
                    filterTarget: return target.已展示() == false # 目标地块必须未被展示
                    filterTargetRange: "中距离" # 目标必须在相邻地块
                })
                if( target == null ) break # 无可选地块则停止
                target.展示(触发效果=false, player) # 展示地块但不触发地块效果
                count++
                if( count < maxReveal ){
                    choice = player.choose(["继续展示", "停止展示"])
                    if( choice == "停止展示" ) break
                }
            }
        }
    }
}

## 角色游戏牌库

求生者游戏牌{
    名字：背包
    牌库中数量：2
    类型：装备
    大小：0格装备栏
    技能: {
        技能名: "背包"
        技能描述: "被动：增加一格角色装备栏。"
        skillType: "装备"
        trigger: 卡牌进入装备区时、卡牌离开装备区时
        filter: return event.card.名字 == "背包"
        forced: true # 强制发动
        content:{
            if( trigger == "卡牌进入装备区时" ){
                player.增加装备栏( 1 )
            }
            else if( trigger == "卡牌离开装备区时" ){
                player.减少装备栏( 1 )
            }
        }
    }
}

求生者游戏牌{
    名字：爆头
    牌库中数量：4
    类型：行动
    技能: {
        技能名: "爆头"
        技能描述: "行动：使用装备区里的【弓】或【弩】，对一个目标造成6点伤害。"
        射程: "长距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && ( player.hasEquipment( "弓" ) || player.hasEquipment( "弩" ) )
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "长距离" # 目标必须在长距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害( 6, player ) # 对目标造成6点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：捕熊陷阱
    牌库中数量：5
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "捕熊陷阱"
        技能描述: "弃置：弃置此装备，对射程内的一个目标造成4点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" # 免费行动：不消耗行动次数，弃置本装备作为代价
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.discard( name = "捕熊陷阱", position = "装备区" ) # 弃置此装备
            target.受到伤害( 4, player ) # 对目标造成4点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：弓
    牌库中数量：3
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "弓"
        技能描述: "行动：对一个目标造成2点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害( 2, player ) # 对目标造成2点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：火焰箭
    牌库中数量：2
    类型：装备
    填充物上限：3
    初始填充数：3
    填充物类型：燃料
    大小：1格装备栏
    技能: {
        技能名: "火焰箭"
        技能描述: "行动：使用装备区里的【弓】或【弩】，对一个目标造成4点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "火焰箭" ) > 0 && ( player.hasEquipment( "弓" ) || player.hasEquipment( "弩" ) )
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "火焰箭" ) # 消耗1点燃料
            target.受到伤害( 4, player ) # 对目标造成4点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：砍刀
    牌库中数量：2
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "砍刀"
        技能描述: "行动：对一个目标造成3点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害( 3, player ) # 对目标造成3点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：摩托车
    牌库中数量：2
    类型：装备
    填充物上限：2
    初始填充数：2
    填充物类型：燃料
    大小：2格装备栏
    技能: {
        技能名: "摩托车"
        技能描述: "行动：消耗1点燃料，最多移动3格。"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有燃料时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "摩托车" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "摩托车" ) # 消耗1点燃料
            maxSteps = 3 # 最多移动3格
            steps = 0
            while( steps < maxSteps ){
                if( steps > 0 ){
                    choice = player.choose(["继续移动", "停止移动"])
                    if( choice == "停止移动" ) break
                }
                target = player.chooseMapBlock({
                    filterTarget: return target != player.所在地图块() # 目标地块不能是当前所在地块
                    filterTargetRange: "中距离" # 目标必须在相邻地块
                })
                success = player.moveTo(target) # 调用底层移动函数（见 PlayerSkill.md 中 player.moveTo 定义，会触发离开/进入地块钩子）
                if( !success ){
                    break # 移动失败（如河流潜行未通过）则中止后续移动
                }
                steps++
            }
        }
    }
}

求生者游戏牌{
    名字：弩
    牌库中数量：2
    类型：装备
    填充物上限：8
    初始填充数：8
    填充物类型：弹药
    大小：2格装备栏
    技能: {
        技能名: "弩"
        技能描述: "行动：消耗1点弹药，对一个目标造成3点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "弩" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "弩" ) # 消耗1点弹药
            target.受到伤害( 3, player ) # 对目标造成3点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：圈套
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "圈套"
        技能描述: "行动：对一个怪物造成1点伤害并击晕，直到你的下个回合开始。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害( 1, player ) # 对目标造成1点伤害，伤害来源为玩家
            target.击晕(player, until = "下个回合开始时") # 击晕目标直到你的下个回合开始
        }
    }
}

求生者游戏牌{
    名字：生存本能
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "生存本能"
        技能描述: "行动：使场上所有玩家的饥饿值降低1点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = getAllPlayers() # 获取场上所有玩家
            for i in List:
                i.decreaseHunger( 1 ) # 降低1点饥饿值（见 PlayerSkill.md 中 decreaseHunger 定义，最低降至1）
        }
    }
}

求生者游戏牌{
    名字：神通广大
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "神通广大"
        技能描述: "行动：从场上所有弃牌堆中选一张装备牌，将其置入场上任一玩家的装备区中。"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且场上所有弃牌堆中至少有1张装备牌时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && 场上所有弃牌堆中至少有1张装备牌 # 自然语言描述，待实现为具体函数调用
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = 所有弃牌堆中的装备牌 # 获取所有弃牌堆中的装备牌（包括所有玩家的弃牌堆和拾荒弃牌堆）, 然后返回装备牌列表
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

求生者游戏牌{
    名字：迷彩服
    牌库中数量：2
    类型：装备
    大小：1格装备栏
    技能1: {
        技能名: "迷彩服·潜行"
        技能描述: "被动：角色的潜行值加2。"
        skillType: "装备"
        trigger: 卡牌进入装备区时、卡牌离开装备区时
        filter: return event.card.名字 == "迷彩服"
        forced: true # 强制发动
        content:{
            if( trigger == "卡牌进入装备区时" ){
                player.增加潜行值( 2 ) # 自然语言描述，待实现为具体函数调用
            }
            else if( trigger == "卡牌离开装备区时" ){
                player.减少潜行值( 2 ) # 自然语言描述，待实现为具体函数调用
            }
        }
    }
    技能2: {
        技能名: "迷彩服·弃置"
        技能描述: "弃置：受到3点伤害，然后弃置掉你面前的一张非首领怪物，并替换为一个怪物标记。"
        skillType: "装备"
        active: "行动阶段"
        # 免费行动：不消耗行动次数；需你面前有非首领怪物
        filter: return player.inPhase == "行动阶段" && 玩家面前有非首领怪物 # 自然语言描述，待实现为具体函数调用
        content:{
            player.discard( name = "迷彩服", position = "装备区" ) # 弃置此装备
            player.受到伤害( 3, player ) # 受到3点伤害
            player.弃置面前的一张非首领怪物并替换为怪物标记() # 自然语言描述，待实现为具体函数调用；纯移除不触发「杀死怪物时」事件
        }
    }
}

求生者游戏牌{
    名字：夜色掩护
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "夜色掩护"
        技能描述: "行动：从任一拾荒牌堆中抓取3张牌，然后弃置一张拾荒牌。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            result = player.choose(prompt = "请选择拾荒堆颜色：", ["red", "green", "blue"])
            牌堆 = player.获取拾荒牌堆(result) # 按颜色获取对应拾荒牌堆对象
            player.drawScavenge(3, 牌堆) # 抓取最多3张拾荒牌到手牌区（牌堆不足则抓完）
            player.chooseToDiscard(1, position = "手牌区", source = "scavenge")
        }
    }
}
