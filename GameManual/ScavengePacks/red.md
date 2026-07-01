# 补给类拾荒牌

拾荒牌{
    大类：补给
    颜色：红色
    类型：行动牌
    名字：医疗用品（便携）
    数值：2
    技能: {
        skillType: "行动"
        技能名: "医疗用品（便携）"
        技能描述: "恢复2点生命值"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.生命值() < player.最大生命值() 
        filterTarget: return target == player
        content: {
            player.减少行动次数( 1 )
            player.增加生命值(2)
        }
    }
}

拾荒牌{
    大类：补给
    颜色：红色
    类型：行动牌
    名字：医疗用品（小型）
    数值：4
    技能: {
        skillType: "行动"
        技能名: "医疗用品（小型）"
        技能描述: "恢复4点生命值"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.生命值() < player.最大生命值() 
        filterTarget: return target == player
        content: {
            player.减少行动次数( 1 )
            player.增加生命值(4)
        }
    }
}

拾荒牌{
    大类：补给
    颜色：红色
    类型：行动牌
    名字：医疗用品（大型）
    数值：6
    技能: {
        skillType: "行动"
        技能名: "医疗用品（大型）"
        技能描述: "恢复6点生命值"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.生命值() < player.最大生命值()
        filterTarget: return target == player
        content: {
            player.减少行动次数( 1 )
            player.增加生命值(6)
        }
    }
}

拾荒牌{
    大类：补给
    颜色：红色
    类型：行动牌
    名字：解毒剂
    技能: {
        skillType: "行动"
        技能名: "解毒剂"
        技能描述: "清除所有的异常状态效果"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        filterTarget: return target == player
        content: {
            player.减少行动次数( 1 )
            player.清除所有的异常状态效果()
        }
    }
}

拾荒牌{
    大类：补给
    颜色：红色
    类型：装备牌
    名字：燃料
    大小：1格装备栏
    技能: {
        skillType: "装备"
        技能名: "燃料"
        技能描述: "抓取到此卡时,需要立即装备或者弃掉（不额外消耗行动次数）。"
        trigger: 抓取拾荒牌时 
        filter: return event.card.名字 == "燃料"
        content: {
            card = event.card
            choice = player.choose(["装备燃料", "弃掉燃料"])
            if( choice == "装备燃料" ){
                player.装备(card)
            } else {
                player.discard(card)
            }
        }
    }
}
