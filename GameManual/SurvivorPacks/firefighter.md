# 消防员
## 角色详情

# 消防员角色固有技能（非卡牌，开局即拥有）；生命值与潜行值由角色本身决定
求生者{
    角色名称: 消防员
    生命值上限: 32
    初始生命值: 32
    潜行值: 6
    饥饿状态潜行值: 5
    技能: {
        技能名: "拳打"
        技能描述: "行动：对一个目标造成2点伤害。"
        射程: "短距离"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        filterTarget: true # 任何目标都可用（含玩家、怪物）
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害(2, player) # 对目标造成2点伤害，伤害来源为玩家。
        }
    }
}

## 角色游戏牌库

求生者游戏牌{
    名字：防火头盔
    牌库中数量：2
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "防火头盔"
        技能描述: "被动：受到的伤害减一。"
        skillType: "装备"
        trigger: 受到伤害时
        filter: true # 任意来源的伤害均触发
        forced: true # 满足触发条件就强制执行，玩家不能选择不发动
        content:{
            trigger.num-- # trigger.num 为本次伤害的伤害值变量；将其减1，实现受到的伤害减1点
        }
    }
}

求生者游戏牌{
    名字：打火机
    牌库中数量：3
    类型：装备
    填充物上限：2
    初始填充数：2
    填充物类型：燃料
    大小：1格装备栏
    技能: {
        技能名: "打火机"
        技能描述: "行动：对射程内的所有怪物造成3点伤害。"
        射程: "短距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有燃料时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "打火机" ) > 0
        selectTarget: -1 # 选择所有目标
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            player.减少填充物数量( 1, "打火机" ) # 消耗1点燃料
            for i in List:
                i.受到伤害(3, player) # 对所有目标造成3点伤害，伤害来源为玩家。
        }
    }
}

求生者游戏牌{
    名字：急救包
    牌库中数量：3
    类型：行动
    射程：短距离
    行动条件：无
    行动效果：使射程内任一玩家一个目标恢复4点生命值。
    技能: {
        技能名: "急救包"
        技能描述: "行动：使射程内任一玩家一个目标恢复4点生命值。"
        射程: "短距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1
        filterTarget: return target.type == Human # 目标必须是人类类型（包含玩家幸存者，可用于自救或救他人）
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.恢复生命值(4) # 对目标恢复4点生命值
        }
    }
}

求生者游戏牌{
    名字：猎枪
    牌库中数量：1
    类型：装备
    子类：武器
    填充物上限：4
    初始填充数：4
    填充物类型：弹药
    大小：1格装备栏
    技能: {
        技能名: "猎枪"
        技能描述: "行动：对射程内的一个目标造成4点伤害，然后对你面前的所有目标造成2点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "猎枪" ) > 0
        selectTarget: 1 # 选择1个主目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内（即目标在玩家所在地块及其相邻地块中）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少填充物数量( 1, "猎枪" ) # 消耗1点弹药
            target.受到伤害(4, player) # 对主目标造成4点伤害，伤害来源为玩家
            List = getTarget(player.所在地图块()) # 获取玩家所在地图块的所有目标
            for i in List:
                if( i != player ) i.受到伤害(2, player) # 对溅射目标造成2点伤害，伤害来源为玩家
        }
    }
}

求生者游戏牌{
    名字：灭火器
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "灭火器"
        技能描述: "行动：击晕射程内的所有怪物，直到你的下个回合开始。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: -1 # 射程内的所有目标
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "短距离" # 目标必须在短距离范围内（即同一个地块内）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                i.击晕(player) # 击晕目标怪物，击晕来源为玩家（持续到玩家下个回合开始）
        }
    }
}

求生者游戏牌{
    名字：能量饮料
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "能量饮料"
        技能描述: "行动：直到你的下个回合开始，你免疫饥饿伤害。你抓一张牌"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.addTempSkill('能量饮料_satiety', until = "下个回合开始时") # 添加临时技能，持续到下个回合开始时失效
            player.draw(1) # 抓取一张牌
        }
        # subSkill 为临时技能定义：当受到饥饿类型伤害时取消该次伤害
        subSkill: {
            satiety: {
                trigger: 受到伤害时
                forced: true
                filter: return trigger.damageType == "饥饿" # 仅对饥饿伤害生效
                content: trigger.cancel() # 取消本次伤害结算
            }
        }
    }
}

求生者游戏牌{
    名字: 梯子
    牌库中数量: 2
    类型: 装备
    大小: 1格装备栏
    技能: {
        技能名: "梯子"
        技能描述: "被动：自动通过河流地图块的检定。弃置：抓取怪物卡前，可以弃置此装备，然后跳过抓取怪物卡的步骤。"
        trigger: 潜行检定前、抓取怪物卡前
        filter: true 
        content: {
            # 当触发「潜行检定前」且触发来源为河流地块时，终止河流检定结算（视为自动通过）
            if( trigger == "潜行检定前" && event.name == "河流" ){
                player.终止技能结算("河流")
            }
            # 当触发「抓取怪物卡前」时，玩家可选择弃置此装备以跳过本次抓怪
            else if( trigger == "抓取怪物卡前" ){
                if( player.choose(["是", "否"]) == "是" ){
                    player.discard(name = "梯子", position = "装备区")
                    trigger.cancel()
                }
            }
        }
    }
}

求生者游戏牌{
    名字: 闪光棒
    牌库中数量: 4
    类型: 行动
    技能: {
        技能名: "闪光棒"
        技能描述: "行动：将射程内的所有怪物吸引到你的面前。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: -1 # 选取所有目标
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "长距离" # 目标必须在长距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                修改i的纠缠目标为player # 自然语言描述：将怪物的纠缠目标改为玩家（待实现为具体函数调用）
        }
    }
}

求生者游戏牌{
    名字：我的斧子去哪儿了？
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "我的斧子去哪儿了？"
        技能描述: "行动：将游戏牌堆中的【值得信赖的斧子】置入你的装备区。并抓取一张拾荒卡。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            pile = player.getPile("游戏牌堆") # 获取玩家的游戏牌堆
            card = game.getCard(name = "值得信赖的斧子", pile) # 获取玩家游戏牌堆中的【值得信赖的斧子】牌
            if( card == null ){
                game.log("玩家游戏牌堆中没有【值得信赖的斧子】牌")
            }else{
                player.装备(card)
            }
            result = player.choose(prompt = "请选择你抓取的拾荒卡颜色：", ["red", "green", "blue"])
            牌堆 = player.获取拾荒牌堆(result) # 按颜色获取对应拾荒牌堆对象
            player.drawScavenge(1, 牌堆) # 抓取一张拾荒卡
        }
    }
}

求生者游戏牌{
    名字：消防员的耐力
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "消防员的耐力"
        技能描述: "行动：移动最多三格，然后抓取一张牌。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            maxSteps = 3 # 最多移动三格
            steps = 0
            while(steps < maxSteps){ 
                if( steps > 0 ) {
                    choice = player.choose(["继续移动", "停止移动"])
                    if( choice == "停止移动" ) {
                        break
                    }
                }
                target = player.chooseMapBlock({
                    filterTarget: return target != player.所在地图块() # 目标地块不能是当前所在地块
                    filterTargetRange: "中距离" # 目标必须在相邻地块
                })
                success = player.moveTo(target) # [修改] 2026-06-30: 修正 sccess→success；调用底层移动函数（见 PlayerSkill.md 中 player.moveTo 定义，会触发离开/进入地块钩子）
                if( !success ){
                    break # 移动失败（如河流潜行未通过）则中止后续移动
                }
                steps++
            }
            player.draw(1) # 移动结束后抓取一张牌
        }
    }
}

求生者游戏牌{
    名字：野地夹克
    牌库中数量：2
    类型：装备
    大小：1格装备栏
    技能: {
        技能名: "野地夹克"
        技能描述: "你可以增加一点饥饿值恢复一点行动数。"
        skillType: "装备"
        active: "行动阶段"
        usable: Infinity # 不限使用次数（只要饥饿值未达上限即可）
        # 玩家饥饿值上限为6，达到6时无法再用此技能换取行动次数
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家饥饿值" ) < 6
        content:{
            player.增加饥饿值( 1 ) # 增加1点饥饿值
            player.增加行动次数( 1 ) # 增加1点行动次数
        }
    }
}

求生者游戏牌{
    名字：氧气罐
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "氧气罐"
        射程: "中距离"
        技能描述: "行动：消耗一点打火机的燃料，然后对射程内的所有目标造成5点伤害。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "打火机" ) > 0 
        selectTarget: -1 # 选取所有目标
        filterTarget: return target != player 
        filterTargetRange: "中距离"
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少填充物数量(1, "打火机") 
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                i.受到伤害(5, player)
        }
    }
}

求生者游戏牌{
    名字：值得信赖的斧子
    牌库中数量：2
    类型：装备
    大小：2格装备栏
    技能: {
        技能名: "值得信赖的斧子"
        技能描述: "行动：对一个目标造成4点伤害。"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return target != player
        filterTargetRange: "短距离"
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害(4, player) # 对目标造成4点伤害
        }
    }
}