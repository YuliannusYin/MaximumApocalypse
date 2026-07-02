# 枪手
## 角色详情

求生者{
    角色名称: 枪手
    生命值上限: 28
    初始生命值: 28
    潜行值: 7
    饥饿状态潜行值: 6
    技能: {
        技能名: "快速拔枪"
        技能描述: "游戏开始时，将牌库中的装备牌【柯尔特手枪】装备你的装备区。当你受到饥饿伤害时，将装备区或弃牌区中的【柯尔特手枪】重新洗回你的牌库。"
        trigger: 游戏开始时、受到伤害时
        filter: true
        forced: true # 满足触发条件就强制执行
        content: {
            if( trigger == "游戏开始时" ){
                pile = player.getPile("游戏牌堆") # 获取玩家的游戏牌堆
                card = game.getCard(name = "柯尔特手枪", pile) # 获取玩家游戏牌堆中的【柯尔特手枪】牌
                if( card == null ){
                    game.log("玩家游戏牌堆中没有【柯尔特手枪】牌")
                    return failure
                }
                player.装备(card)
            } else if( trigger == "受到伤害时" && trigger.damageType == "饥饿" ){
                card = game.getCard(name = "柯尔特手枪", position = "场上") # 获取场上（所有的装备区、手牌区和牌堆）的【柯尔特手枪】牌
                if( card == null ){
                    game.log("场上没有【柯尔特手枪】牌")
                    return failure
                }
                pile = player.getPile("游戏牌堆") # 获取玩家的游戏牌堆
                player.addCardToPile(card, pile)
                player.洗牌(pile)
            }
        }
    }
}

## 角色游戏牌库

求生者游戏牌{
    名字：集中射击
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "集中射击"
        技能描述: "行动：消耗一枚弹药，对一个选定目标造成5点伤害。"
        射程: "长距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        complexTarget: true # 需选择两类目标（武器+攻击目标），使用复合目标模式
        filterTarget1: return target.在玩家装备区内 && target.填充物类型 == "弹药" && target.当前填充数 > 0 # 装备区内有弹药的武器
        filterTarget2: true # 任何目标都可用
        filterTarget2Range: "长距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target1.消耗填充物( 1, "弹药" )
            target2.受到伤害(5, player) # 对目标造成5点伤害
        }
    }
}

求生者游戏牌{
    名字：扣动扳机让我快乐
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "扣动扳机让我快乐"
        技能描述: "行动：本回合可以额外执行两个行动。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.增加最大行动次数( 2 ) # 增加2点最大行动次数
            player.addTempSkill('扣动扳机让我快乐_clear', until = "回合结束时" )
            player.增加行动次数( 2 ) # 增加2点行动次数
        }
        subSkill: {
            clear: {
                trigger: 回合结束前
                forced: true
                content: player.减少最大行动次数( 2 ) # 减少2点最大行动次数
            }
        }
    }
}

求生者游戏牌{
    名字：空尖弹
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "空尖弹"
        技能描述: "行动：销毁本牌然后将一张弹药类武器填装满【空尖弹】弹药，这种弹药会让武器牌额外造成两点伤害。武器弹药耗尽时弃置武器牌。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && 玩家装备区有可以填充弹药的武器 # [修改] 2026-07-02: 自然语言描述，待实现为具体函数调用
        selectTarget: 1 # 选择1个目标武器
        filterTarget: return target.在玩家装备区内 && target.填充物类型 == "弹药" # 目标必须是玩家装备区内的弹药类武器牌
        content: {
            player.减少行动次数(1) # 消耗1点行动次数
            player.removeCard( name = "空尖弹", position = "结算区" ) # 销毁本牌
            player.addSkill("空尖弹_damage")
            player.addSkill("空尖弹_remove")
            target.改变填充物类型("空尖弹")
            target.补满填充物()
        }
        subSkill: {
            damage:{
                trigger: 造成伤害时
                forced: true
                filter: return event.card.填充物类型 == "空尖弹"
                content: trigger.num += 2 # 空尖弹额外造成2点伤害
            }
            remove:{
                trigger: 弹药耗尽时
                forced: true
                filter: return event.card.填充物类型 == "空尖弹"
                content: {
                    player.discard(event.card) # 弃置武器牌
                }
            }
        }
    }
}

求生者游戏牌{
    名字：齐射
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "齐射"
        技能描述: "行动：弃掉装备区内的所有弹药，对一个目标造成X次2伤害。（X为你以此法弃掉的弹药数量。）"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get总填充物数量( "弹药" ) > 0
        filterTarget: return target != player
        selectTarget: 1
        filterTargetRange: "中距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            num = player.get总填充物数量( "弹药" ) # 自然语言描述，待实现为具体函数调用
            player.清空填充物( "弹药" ) # 统一为填充物API；自然语言描述，待实现为具体函数调用
            for i in range(num):
                target.受到伤害( 2, player ) # 对目标造成2点伤害
        }
    }
}

求生者游戏牌{
    名字：手榴弹
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "手榴弹"
        技能描述: "行动：对一个目标造成5点伤害，并对其同一地块的所有目标造成3点伤害。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        filterTarget: return target != player
        selectTarget: 1
        filterTargetRange: "中距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.受到伤害( 5, player ) # 对主目标造成5点伤害
            List = getTarget(target.所在地图块()) # 获取主目标所在地块的所有目标
            for i in List:
                if( i != target ) i.受到伤害( 3, player ) # 对同地块的其他目标造成3点伤害
        }
    }
}

求生者游戏牌{
    名字：搜索尸体
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "搜索尸体"
        技能描述: "行动：直到你的回合结束，你每杀死一个怪物就随机从一个拾荒牌堆抓取一张牌（无地块拾荒颜色限制）。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.addTempSkill('搜索尸体_draw', until = "回合结束时" ) # 添加临时技能，持续到回合结束时失效
        }
        subSkill: {
            draw: {
                trigger: 杀死怪物时
                forced: true
                filter: return trigger.source == player
                content: {
                    牌堆 = game.拾荒牌堆(random = true) # 随机选取一个拾荒牌堆（无地块颜色限制）
                    player.drawScavenge(1, 牌堆) # 从随机拾荒牌堆抓取1张牌
                }
            }
        }
    }
}

求生者游戏牌{
    名字：套索
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "套索"
        技能描述: "行动：击晕一个怪物并让其纠缠你。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1
        filterTarget: return target.type == Monster # 目标必须是怪物类型
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.击晕(player, until = "下个回合开始时")
            target.修改纠缠对象(player) # 修改怪物的纠缠目标为玩家
        }
    }
}

求生者游戏牌{
    名字：战术领导力
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "战术领导力"
        技能描述: "行动：选择另一名玩家，使其立即执行一个行动。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1
        filterTarget: return target.type == Human && target != player # 目标必须是另一名玩家
        filterTargetRange: Infinity # 无距离限制
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.立即执行一个行动() # 备注：暂保留自然语言描述
        }
    }
}

求生者游戏牌{
    名字：防弹衣
    牌库中数量：2
    类型：装备
    子类：防具
    大小：1格装备栏
    技能: {
        技能名: "防弹衣"
        技能描述: "被动：受到的伤害减一。"
        skillType: "装备"
        trigger: 受到伤害时
        filter: true # 任意来源的伤害均触发
        forced: true # 强制发动
        content:{
            trigger.num-- # 受到的伤害减1点
        }
    }
}

求生者游戏牌{
    名字：柯尔特手枪
    牌库中数量：1
    类型：装备
    子类：武器
    填充物上限：4
    初始填充数：4
    填充物类型：弹药
    大小：0格装备栏
    技能: {
        技能名: "柯尔特手枪"
        技能描述: "行动：对一个目标造成2点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "柯尔特手枪" ) > 0
        selectTarget: 1
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离"
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "柯尔特手枪" ) # 消耗1枚弹药
            target.受到伤害(2, player) # 对目标造成2点伤害
        }
    }
}

求生者游戏牌{
    名字：马
    牌库中数量：2
    类型：装备
    子类：载具
    大小：2格装备栏
    技能1: {
        技能名: "马·移动"
        技能描述: "行动：移动最多两格。"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            maxSteps = 2 # 最多移动两格
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
                success = player.moveTo(target) # 调用底层移动函数
                if( !success ){
                    break # 移动失败则中止后续移动
                }
                steps++
            }
        }
    }
    技能2: {
        技能名: "马·弃置"
        技能描述: "弃置：弃置此装备，将场上所有玩家的饥饿等级降低一点（不消耗行动次数）。"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" # 免费行动：不消耗行动次数
        content:{
            player.discard( name = "马", position = "装备区" ) # 弃置此装备
            List = getAllPlayers() # 获取场上所有玩家
            for i in List:
                i.decreaseHunger( 1 )
        }
    }
}

求生者游戏牌{
    名字：游侠帽
    牌库中数量：2
    类型：装备
    子类：防具
    大小：1格装备栏
    技能: {
        技能名: "游侠帽"
        技能描述: "被动：此装备进入玩家的装备区时，玩家回复三点生命值。"
        skillType: "装备"
        trigger: 卡牌进入装备区时、卡牌离开装备区时
        filter: return event.card.名字 == "游侠帽"
        forced: true
        content:{
            if( trigger == "卡牌进入装备区时"){
                player.recover(3)
                player.addSkill('游侠帽_damage')
            }
            else if( trigger == "卡牌离开装备区时" ){
                player.removeSkill('游侠帽_damage')
            }
        }
        subSkill: {
            damage: {
                trigger: 造成伤害时
                filter: true
                forced: true
                content:{
                    trigger.num += 1 # 你造成的伤害+1
                }
            }
        }
    }
    
}

求生者游戏牌{
    名字：左轮手枪
    牌库中数量：3
    类型：装备
    子类：武器
    填充物上限：6
    初始填充数：6
    填充物类型：弹药
    大小：1格装备栏
    技能: {
        技能名: "左轮手枪"
        技能描述: "行动：对一个目标造成3点伤害，然后你可以再花费一个弹药来攻击另一个目标。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "左轮手枪" ) > 0
        selectTarget: 1
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离"
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "左轮手枪" ) # 消耗1枚弹药
            target.受到伤害(3, player) # 对主目标造成3点伤害
            # 若仍有弹药，询问玩家是否再攻击另一个目标
            if( player.get填充物数量( "左轮手枪" ) > 0 && player.choose(["继续攻击", "停止"]) == "继续攻击" ){
                target2 = player.chooseTarget({
                    selectTarget: 1
                    filterTarget: return target2 != target # 不能是同一个目标
                    filterTargetRange: "中距离"
                })
                player.消耗填充物( 1, "左轮手枪" ) # 再消耗1枚弹药
                target2.受到伤害(3, player) # 对第二个目标造成3点伤害
            }
        }
    }
}
