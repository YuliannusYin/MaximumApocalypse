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
        技能效果："游戏开始时，将牌库中的装备牌【柯尔特手枪】装备你的装备区。当你受到饥饿伤害时，将装备区或弃牌区中的【柯尔特手枪】重新洗回你的牌库。"
        trigger: 游戏开始时、受到伤害时
        filter: 无
        content: {
            if( trigger == "游戏开始时" ){
                pile = player.getPile("游戏牌堆") # 获取玩家的游戏牌堆
                card = game.getCard(name = "柯尔特手枪", pile) # 获取玩家游戏牌堆中的【柯尔特手枪】牌
                if( card == null ){
                    game.log("玩家游戏牌堆中没有【柯尔特手枪】牌")
                    return failure
                }
                player.装备(card)
            } else if( trigger == "受到伤害时" && trigger.damageType == "饥饿" ){ # 当受到饥饿伤害时触发。
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

## 角色卡牌库

求生者卡牌{
    名字：集中射击
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "集中射击"
        射程: "长距离"
        技能效果："消耗一枚弹药，对一个选定目标造成5点伤害。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get武器弹药() > 0
        complexTarget: true
        filterTarget1: 装备区内有弹药的武器。
        filterTarget2: true 
        filterTarget2Range: "长距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少武器弹药( 1, target1 ) # 消耗1枚弹药
            target2.受到伤害(5, player) # 对目标造成5点伤害
        }
    }
}

求生者卡牌{
    名字：扣动扳机让我快乐
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "扣动扳机让我快乐"
        技能效果："行动：本回合可以额外执行两个行动。"
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

求生者卡牌{
    名字：空尖弹
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "空尖弹"
        技能效果："行动：销毁本牌然后将一张弹药类武器填装满【空尖弹】弹药，这种弹药会让武器牌额外造成两点伤害。武器弹药耗尽时弃置武器牌。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && 玩家装备区有可以填充弹药的武器。
        filterTarget: return target == 玩家装备区内的弹药类武器牌
        content: {
            player.减少行动次数(1) # 消耗1点行动次数
            player.removeCard(结算区中的【空尖弹】)
            player.addSkill("空尖弹_damage")
            player.addSkill("空尖弹_remove")
            target.改变弹药类型("空尖弹")
            target.补满弹药()
        }
        subSkill: {
            damage:{
                trigger: 造成伤害时
                forced: true
                filter: return event.card.武器弹药类型 == "空尖弹"
                content: trigger.num += 2
            }
            remove:{
                trigger: 弹药耗尽时
                forced: true
                filter: return event.card.武器弹药类型 == "空尖弹"
                content: {
                    player.discard(event.card) # 弃置武器牌
                }
            }
        }
    }
}

求生者卡牌{
    名字：齐射
    牌库中数量：2
    类型：行动
    技能: {
        技能名: "齐射"
        技能描述: "行动：弃掉装备区内的所有弹药，对一个目标造成X次2伤害。（X为你以此法弃掉的弹药数量。）"
        射程: "中距离"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get武器弹药() > 0
        filterTarget: return target != player
        selectTarget: 1
        filterTargetRange: "中距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            num = player.get武器弹药()
            玩家弃置装备区所有弹药 # 消耗所有弹药
            for i in range(num):
                target.受到伤害( 2, player ) # 对目标造成2点伤害
        }
    }
}

求生者卡牌{
    名字：手榴弹
    牌库中数量：3
    类型：行动
    技能: {
        技能名: "手榴弹"
        技能描述: "行动：对一个目标造成5点伤害，并对其同一地块的所有目标造成3点伤害。"
        射程: "中距离"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get武器弹药() > 0
        filterTarget: return target != player
        selectTarget: 1
        filterTargetRange: "中距离"
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少武器弹药( 1, target ) # 消耗1枚弹药
            target.受到伤害( 5, player ) # 对目标造成5点伤害
            for i in range(3):
                target.受到伤害( 3, player ) # 对目标造成3点伤害
        }
    }
    射程：中距离
    行动条件：无。
    行动效果：对一个目标造成5点伤害，并对其同一地块的所有目标造成3点伤害。
}

求生者卡牌{
    名字：搜索尸体
    牌库中数量：2
    类型：行动
    射程：无
    行动条件：无
    行动效果：直到你的回合结束，你每杀死一个怪物就随机抓取一到两张拾荒卡牌（无地块拾荒颜色限制）。
}

求生者卡牌{
    名字：套索
    牌库中数量：3
    类型：行动
    射程：中距离
    行动条件：射程范围内有可以被击晕的怪物。
    行动效果：击晕一个怪物并将其移动至你的面前。
}

求生者卡牌{
    名字：战术领导力
    牌库中数量：3
    类型：行动
    射程：无
    行动条件：场上有其他玩家。
    行动效果：选择令一名玩家，使其立即执行一个行动。
}

求生者卡牌{
    名字：防弹衣
    牌库中数量：2
    类型：装备
    子类：防具
    大小：一格装备栏
    射程：无
    装备技能{
        触发时机：受到伤害时
        触发效果：受到的伤害减一
    }
}

求生者卡牌{
    名字：柯尔特手枪
    牌库中数量：1
    类型：装备
    子类：武器
    弹药上限：4
    初始弹药：4
    弹药类型：子弹
    大小：零格装备栏
    射程：中距离
    装备技能{
        行动条件：武器射程内有目标
        行动效果：对一个目标造成2点伤害。
    }
}

求生者卡牌{
    名字：马
    牌库中数量：2
    类型：装备
    子类：载具
    大小：两格装备栏
    射程：无
    装备技能1{
        行动条件：无
        行动效果：移动最多两格。
    }
    装备技能1{
        弃置条件：无
        弃置效果：弃置此牌将场上所有玩家的饥饿等级降低一点（此行为不消耗每回合的行动点数）。
    }
}

求生者卡牌{
    名字：游侠帽
    牌库中数量：2
    类型：装备
    子类：防具
    大小：一格装备栏
    射程：无
    装备技能1{
        触发时机：此装备进入玩家的装备区时。
        行动效果：玩家回复三点生命值。
    }
    装备技能1{
        触发条件：当你造成伤害时。
        效果：所有你造成的伤害加一。
    }
}

求生者卡牌{
    名字：左轮手枪
    牌库中数量：3
    类型：装备
    子类：武器
    弹药上限：6
    初始弹药：6
    弹药类型：子弹
    大小：一格装备栏
    射程：无
    装备技能{
        行动条件：武器射程内有两个及以上的目标
        行动效果：对一个目标造成3点伤害，然后你可以再花费一个弹药来攻击另一个目标。
    }
}