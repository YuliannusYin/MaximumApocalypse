# 战备类拾荒牌

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：弹药（少量）
    数值：2
    技能: {
        技能名: "弹药（少量）"
        技能描述: "行动：向一张武器卡填装2发弹药。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
        selectTarget: 1 # 选择1个目标武器
        filterTarget: return target.在玩家装备区内 && target.填充物类型 == "弹药" && target.当前填充数 < target.填充物上限  # 目标必须是玩家装备区内填充物类型为"弹药"且未满的装备
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.添加填充物( 2, "弹药" ) # [修改] 2026-07-01: 填装弹药→添加填充物，与 PlayerSkill.md 加油技能 API 统一
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：弹药（半盒）
    数值：3
    技能: {
        技能名: "弹药（半盒）"
        技能描述: "行动：向一张武器卡填装3发弹药。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标武器
        filterTarget: return target.在玩家装备区内 && target.填充物类型 == "弹药" && target.当前填充数 < target.填充物上限
        content:{
            player.减少行动次数( 1 )
            target.添加填充物( 3, "弹药" )
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：弹药（足量）
    数值：4
    技能: {
        技能名: "弹药（足量）"
        技能描述: "行动：向一张武器卡填装4发弹药。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标武器
        filterTarget: return target.在玩家装备区内 && target.填充物类型 == "弹药" && target.当前填充数 < target.填充物上限
        content:{
            player.减少行动次数( 1 )
            target.添加填充物( 4, "弹药" )
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：弹药（大量）
    数值：5
    技能: {
        技能名: "弹药（大量）"
        技能描述: "行动：向一张武器卡填装5发弹药。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标武器
        filterTarget: return target.在玩家装备区内 && target.填充物类型 == "弹药" && target.当前填充数 < target.填充物上限
        content:{
            player.减少行动次数( 1 )
            target.添加填充物( 5, "弹药" )
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：弹药（整盒）
    数值：无
    技能: {
        技能名: "弹药（整盒）"
        技能描述: "行动：将一张武器卡填装到满弹药。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标武器
        filterTarget: return target.在玩家装备区内 && target.填充物类型 == "弹药" && target.当前填充数 < target.填充物上限
        content:{
            player.减少行动次数( 1 )
            target.添加填充物( max, "弹药" )
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：装备牌
    名字：防弹背心
    大小：1格装备栏
    技能: {
        技能名: "防弹背心"
        技能描述: "被动：受到的伤害减少2点，使用三次后销毁。"
        skillType: "装备"
        trigger: 受到伤害时
        filter: true # 任意来源的伤害均触发
        forced: true # 强制发动
        content:{
            trigger.num -= 2 # trigger.num 为本次伤害的伤害值变量；将其减2，实现受到的伤害减2点
            player.addMark('防弹背心使用次数')
            if( player.countMark('防弹背心使用次数') >= 3 ){
                player.removeCard( name = "防弹背心", position = "装备区" ) # 达到3次后销毁此装备
            }
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：装备牌
    名字：对讲机
    大小：1格装备栏
    技能: {
        技能名: "对讲机"
        技能描述: "行动：选择另一名玩家，该玩家立即执行一个行动。"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标玩家
        filterTarget: return target.type == Human && target != player # 目标必须是另一名玩家
        filterTargetRange: Infinity # 无距离限制
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            # 备注：「立即执行一个行动」语义待定——是给目标 +1 行动次数，还是让其免费执行一个技能？暂保留自然语言描述
            target.立即执行一个行动()
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：装备牌
    名字：手枪
    大小：1格装备栏
    填充物上限：4
    初始填充数：4
    填充物类型：弹药
    技能: {
        技能名: "手枪"
        技能描述: "行动：对一个目标造成2点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "手枪" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少填充物数量( 1, "手枪" )
            target.受到伤害(2, player) # 对目标造成2点伤害，伤害来源为玩家
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：装备牌
    名字：背包
    大小：0格装备栏 # 背包自身不占装备栏格数
    技能: {
        技能名: "背包"
        技能描述: "被动：玩家增加1格装备栏。"
        skillType: "装备"
        trigger: 卡牌进入装备区时、卡牌离开装备区时
        filter: return event.card.名字 == "背包"
        forced: true
        content:{
            if( trigger == "卡牌进入装备区时" ) player.增加装备栏( 1 ) # 装备时玩家装备栏+1格
            else if( trigger == "卡牌离开装备区时" ) player.减少装备栏( 1 ) # 装备时玩家装备栏-1格
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：装备牌
    名字：手电筒
    大小：1格装备栏
    技能: {
        技能名: "手电筒"
        技能描述: "被动：当你执行拾荒行动时，改为展示牌堆顶两张牌，然后你选择保留其中一张，将另一张置于牌堆底。"
        skillType: "装备"
        trigger: 抓取拾荒牌前
        filter: true # 每次拾荒均触发
        forced: true # 强制发动，替代原有拾荒逻辑
        content:{
            player.cancel('drawScavenge')
            # cancel 替代原 drawScavenge 后，「抓取拾荒牌时」事件不再触发，故手电筒拾荒不会抓到「一无所获/伏击！」
            # 备注：trigger 机制需钩住 PlayerSkill.md 中「拾荒」技能的 content，将原「抓1张」改为「看2留1放1」
            牌堆 = player.当前拾荒牌堆() # 获取当前拾荒的牌堆
            顶两张 = 牌堆.查看顶( 2 ) # 查看牌堆顶2张牌（不抓取）
            保留 = player.choose( 顶两张 ) # 玩家选择保留其中1张
            player.获得( 保留 ) # 玩家获得保留的牌
            牌堆.置于底( 顶两张 - 保留 ) # 将另一张置于牌堆底
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：装备牌
    名字：双筒望远镜
    大小：1格装备栏
    技能: {
        技能名: "双筒望远镜"
        技能描述: "行动：展示一张地图块，且不触发它的展示效果。"
        射程: "长距离"
        skillType: "装备"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标地块
        filterTarget: return target.是地图块() && !target.已展示() # 目标必须是未展示的地图块
        filterTargetRange: "长距离" # 目标必须在长距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.展示(触发效果=false, player) # 展示但不触发"展示地块时"钩子
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：炸药
    技能: {
        技能名: "炸药"
        技能描述: "行动：移除一个没有怪物标记的地块上的任务标记，并对地块上的所有目标造成8点伤害。"
        射程: "长距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标地块
        filterTarget: return target.是地图块() && !target.有怪物标记() # 目标必须是一个没有怪物标记的地图块
        filterTargetRange: "长距离" # 目标必须在长距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.移除任务标记() # 移除地块上的任务标记
            List = getTarget( target ) # 获取地块上的所有目标
            for i in List:
                i.受到伤害( 8, player ) # 对地块上所有目标造成8点伤害
        }
    }
}

拾荒牌{
    大类：战备
    颜色：蓝色
    类型：行动牌
    名字：大炸药
    技能: {
        技能名: "大炸药"
        技能描述: "行动：摧毁一个地图板块。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0
        selectTarget: 1 # 选择1个目标地块
        filterTarget: return target.是地图块() && target.已展示() # 目标必须是一个地图块且已展示的地图块
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            # 备注：「摧毁地图板块」机制待定——地块上的玩家和怪物如何处理？地块是否从游戏中移除？暂保留自然语言描述
            target.removeMapBlock() # 移除目标地块
        }
    }
}
