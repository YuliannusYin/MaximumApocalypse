# 其他类拾荒牌

拾荒牌{
    大类：其他
    颜色：灰色
    类型：行动牌
    名字：一无所获
    技能: {
        技能名: "一无所获"
        技能描述: "抓取到此牌时，立即弃掉。"
        skillType: "行动"
        trigger: 抓取拾荒牌时
        forced: true # 强制发动
        filter: return event.card.名字 == "一无所获"
        content:{
            player.discard(event.card) # 立即弃置
        }
    }
}

拾荒牌{
    大类：其他
    颜色：灰色
    类型：行动牌
    名字：伏击！
    技能: {
        技能名: "伏击！"
        技能描述: "抓取到此牌时，立即抓取一张怪物卡，然后弃掉此卡。"
        skillType: "行动"
        trigger: 抓取拾荒牌时
        forced: true # 强制发动
        filter: return event.card.名字 == "伏击！"
        content:{
            player.drawMonster(1) # 立即抓取一张怪物卡
            player.discard(event.card) # 弃掉此卡
        }
    }
}

拾荒牌{
    大类：其他
    颜色：灰色
    类型：行动牌
    名字：多余配件
    技能: {
        技能名: "多余配件"
        技能描述: "行动：从你的弃牌堆将一张牌返回手牌。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段、有剩余行动次数时可用
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = player.获取角色游戏牌弃牌堆()
            if( List.length == 0){
                game.log("玩家没有弃牌堆中的牌")
                return false
            }
            card = player.chooseCard(1, List) # 选择1张弃牌堆中的牌
            player.gain(card) # 将选中的牌添加到玩家手牌区
        }
    }
}

拾荒牌{
    大类：其他
    颜色：灰色
    类型：物品
    名字：脏毯子
    特殊：作为游戏结算时的物品。
}

拾荒牌{
    大类：其他
    颜色：灰色
    类型：物品
    名字：老报纸
    特殊：作为游戏结算时的物品。
}

拾荒牌{
    大类：其他
    颜色：灰色
    类型：物品
    名字：满是灰尘的日记本
    特殊：作为游戏结算时的物品。
}

拾荒牌{
    大类：其他
    颜色：灰色
    类型：装备牌
    名字：科学家
    大小：1格装备栏
    技能: {
        技能名: "科学家"
        技能描述: "被动：携带'科学家'的玩家无法通过任何潜行判定。"
        skillType: "装备"
        trigger: 潜行检定时
        forced: true # 强制发动
        filter: return player.hasEquipment( "科学家" ) # 仅当玩家装备了科学家时触发
        content:{
            player.修改本次潜行检定结果为失败() # 自然语言描述：设置本次潜行检定结果为失败，待实现为具体函数调用
        }
    }
}
