# 老兵与狗
## 角色详情

# '老兵与狗'为"二位一体"的特殊角色：'老兵与狗'作为一个整体同时移动、共用行动次数与回合，但生命值与饥饿值'老兵'与'狗'各自独立计算。
# '老兵与狗'公用一个手牌区、游戏牌堆、游戏牌弃牌区，'老兵'与'狗'各自独立有一个装备区。
# 其中一方生命值≤0即永久死亡，另一方仍可继续存活并单独行动。
# player 指代'老兵与狗'，用 player.dog 指代狗，用 player.veteran 指代老兵。
# "狗还活着"判定为 player.dog.get_hp() > 0；"狗已死亡"判定为 player.dog.get_hp() <= 0。
# 装备归属：武器类（M1加兰德步枪、迫击炮、鲁格手枪）与防具类（狗哨、军牌）装备于'老兵'装备区；狗项圈装备于狗的装备区。

# 老兵和狗注意事项
当扮演'老兵和狗'进行游戏被怪物攻击时，你可以选择让敌人攻击哪个角色，但是如果怪物有射程，那么它既攻击老兵，又攻击狗。
如果两个角色都没有死亡，那么使用两个角色中最低的潜行数值进行潜行检定。
如果一名角色死亡，你可以继续进行游戏，直到另一名角色也死亡。

# '老兵与狗'角色固有技能（非卡牌，开局即拥有）；生命值与潜行值由角色本身决定
特殊求生者{
    求生者1{
        角色名称: 老兵
        生命值上限: 22
        初始生命值: 22
        潜行值: 7
        饥饿状态潜行值: 6
        技能: {
            技能名: "把你的爪子拿开"
            技能描述: "行动：对老兵造成2点伤害，然后狗直到你的下回合开始免疫伤害。"
            active: "行动阶段"
            # 行动阶段、有剩余行动次数、且狗还活着时可用（狗需存活才能获得免疫）
            filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
            content:{
                player.减少行动次数( 1 ) # 消耗1点行动次数
                player.veteran.damage( 2, player ) # 老兵对自己造成2点伤害
                player.dog.addTempSkill( '把你的爪子拿开_immune', until = "下个回合开始时" ) # 狗获得免疫，持续到下个回合开始时失效
            }
            subSkill: {
                immune: {
                    trigger: 受到伤害时
                    forced: true # 强制发动
                    filter: true # 任意来源的伤害均取消
                    content: event.cancel() # 取消本次伤害结算
                }
            }
        }
    }
    求生者2{
        角色名称: 狗
        生命值上限: 12
        初始生命值: 12
        潜行值: 9
        饥饿状态潜行值: 8
        技能: {
            技能名: "咬他们"
            技能描述: "行动：对中距离内的一个目标造成3点伤害，然后狗受到1点伤害。"
            射程: "中距离"
            active: "行动阶段"
            filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
            selectTarget: 1 # 选择1个目标
            filterTarget: return true # 任何目标都可用
            filterTargetRange: "中距离" # 目标必须在中距离范围内
            content:{
                player.减少行动次数( 1 ) # 消耗1点行动次数（共用行动次数池）
                target.damage( 3, player.dog ) 
                player.dog.damage( 1, player ) # 狗受到1点伤害
            }
        }
    }
}

## 角色游戏牌堆

求生者游戏牌{
    名字: 把他们撕成碎片
    牌堆中数量: 2
    类型: 行动
    技能: {
        技能名: "把他们撕成碎片"
        技能描述: "行动：如果狗还活着，对中距离内的最多3个目标造成3点伤害。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗还活着时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
        selectTarget: [1, 3] # 选择1~3个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                i.damage( 3, player ) # 对每个目标造成3点伤害，伤害来源为'老兵与狗'
        }
    }
}

求生者游戏牌{
    名字: 反击开始
    牌堆中数量: 2
    类型: 行动
    技能: {
        技能名: "反击开始"
        技能描述: "行动：如果狗已死亡，直到你的下回合开始，老兵造成的伤害加3。"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗已死亡时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() <= 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.veteran.addTempSkill( '反击开始_damage', until = "下个回合开始时" ) # 添加临时技能，持续到下个回合开始时失效
        }
        subSkill: {
            damage: {
                trigger: 造成伤害时
                forced: true # 强制发动
                filter: true
                content: event.num += 3 # 老兵造成的伤害+3
            }
        }
    }
}

求生者游戏牌{
    名字: 狗哨
    牌堆中数量: 2
    类型: 装备
    大小: 1格装备栏
    归属：老兵装备区
    技能: {
        技能名: "狗哨"
        技能描述: "行动：如果狗还活着，移除长距离内一个地图块上的1个怪物标记，然后狗受到2点伤害。"
        射程: "长距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗还活着时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target = player.chooseMapBlock({
                filterTarget: return target.countMonsterMark() > 0 # 目标地块上至少有1个怪物标记
                filterTargetRange: "长距离" # 目标必须在长距离范围内
            })
            target.移除怪物标记( 1 ) # 移除地块上的1个怪物标记；自然语言描述，待实现为具体函数调用
            player.dog.damage( 2, player )
        }
    }
}

求生者游戏牌{
    名字: 干死你们
    牌堆中数量: 2
    类型: 行动
    技能: {
        技能名: "干死你们"
        技能描述: "行动：如果狗已死亡，对中距离内的所有目标造成6点伤害。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗已死亡时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() <= 0
        selectTarget: -1 # 选取所有目标
        filterTarget: return target != player # 排除玩家自身
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = event.target # event.target 为经过 filter 筛选后的目标列表
            for i in List:
                i.damage( 6, player.veteran ) # 对每个目标造成6点伤害，伤害来源为老兵
        }
    }
}

求生者游戏牌{
    名字: 狗项圈
    牌堆中数量: 3
    类型: 装备
    大小: 0格装备栏
    归属：狗的装备区
    技能: {
        技能名: "狗项圈"
        技能描述: "被动：所有对狗造成的伤害减1。"
        skillType: "装备"
        trigger: 受到伤害时
        filter: true # 装备于狗身上，仅狗受到伤害时触发
        forced: true # 强制发动
        content:{
            event.num-- # event.num 为本次伤害的伤害值变量；将其减1，实现受到的伤害减1点
        }
    }
}

求生者游戏牌{
    名字: 军牌
    牌堆中数量: 2
    类型: 装备
    大小: 0格装备栏
    归属：老兵装备区
    技能: {
        技能名: "军牌"
        技能描述: "装备时，老兵和狗各恢复2点生命值。被动：所有对老兵造成的伤害减1。"
        skillType: "装备"
        trigger: 卡牌进入装备区时、受到伤害时
        filter: true
        forced: true # 强制发动
        content:{
            if( trigger == "卡牌进入装备区时" && event.card.名字 == "军牌" ){ # 装备时
                player.veteran.recover( 2 ) # 老兵恢复2点生命值
                if( player.dog.get_hp() > 0 ) player.dog.recover( 2 ) # 狗存活时也恢复2点生命值
            }
            else if( trigger == "受到伤害时" ){
                event.num-- # 受到的伤害减1点
            }
        }
    }
}

求生者游戏牌{
    名字: M1加兰德步枪
    牌堆中数量: 2
    类型: 装备
    填充物上限: 4
    初始填充数: 4
    填充物类型: 弹药
    大小: 2格装备栏
    归属：老兵装备区
    技能: {
        技能名: "M1加兰德步枪"
        技能描述: "行动：消耗1枚弹药，对一个目标造成8点伤害。"
        射程: "长距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "M1加兰德步枪" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "长距离" # 目标必须在长距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "M1加兰德步枪" ) # 消耗1枚弹药
            target.damage( 8, player.veteran )
        }
    }
}

求生者游戏牌{
    名字: 迫击炮
    牌堆中数量: 2
    类型: 装备
    填充物上限: 3
    初始填充数: 3
    填充物类型: 弹药
    大小: 2格装备栏
    归属：老兵装备区
    技能: {
        技能名: "迫击炮"
        技能描述: "行动：消耗1枚弹药，选择一个地图块，移除其上所有怪物标记，或对该地图块的所有目标造成6点伤害。"
        射程: "长距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "迫击炮" ) > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "迫击炮" ) # 消耗1枚弹药
            target = player.chooseMapBlock({
                filterTarget: return target.is_revealed() # 任一已展示的地图块
                filterTargetRange: "长距离" # 目标必须在长距离范围内
            })
            # 询问玩家选择效果
            choice = player.choose( ["移除怪物标记", "造成伤害"] )
            if( choice == "移除怪物标记" ){
                target.removeAllMonsterMarks() # 移除该地图块上所有怪物标记
            }
            else if( choice == "造成伤害" ){
                List = getTarget( target ) # 获取该地图块的所有目标
                for i in List:
                    i.damage( 6, player.veteran ) # 对每个目标造成6点伤害，伤害来源为老兵
            }
        }
    }
}

求生者游戏牌{
    名字: 取回
    牌堆中数量: 3
    类型: 行动
    技能: {
        技能名: "取回"
        技能描述: "行动：如果狗还活着，从任一颜色的拾荒牌堆中抓取3张牌，然后弃置2张拾荒牌。"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗还活着时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            result = player.choose( prompt = "请选择拾荒牌堆颜色：", ["red", "green", "blue"] )
            牌堆 = player.获取拾荒牌堆( result ) # 按颜色获取对应拾荒牌堆对象（任意颜色，不限于所在地块）
            player.drawScavenge( 3, 牌堆 ) # 抓取3张拾荒牌到手牌区（牌堆不足则抓完）
            player.chooseToDiscard( 2, position = "手牌区", source = "scavenge" ) # 弃置2张拾荒牌
        }
    }
}

求生者游戏牌{
    名字: 鲁格手枪
    牌堆中数量: 2
    类型: 装备
    填充物上限: 5
    初始填充数: 5
    填充物类型: 弹药
    大小: 1格装备栏
    归属：老兵装备区
    技能: {
        技能名: "鲁格手枪"
        技能描述: "行动：消耗1枚弹药，对一个目标造成4点伤害。"
        射程: "中距离"
        skillType: "装备"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、有弹药时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.get填充物数量( "鲁格手枪" ) > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.消耗填充物( 1, "鲁格手枪" ) # 消耗1枚弹药
            target.damage( 4, player.veteran ) # 对目标造成4点伤害，伤害来源为老兵
        }
    }
}

求生者游戏牌{
    名字: 相信它的直觉
    牌堆中数量: 3
    类型: 行动
    技能: {
        技能名: "相信它的直觉"
        技能描述: "行动：如果狗还活着，展示最多2个相邻且未展示的地图块，不触发它们的展示效果。"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗还活着时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            maxReveal = 2 # 最多展示2个相邻地块
            count = 0
            while( count < maxReveal ){
                target = player.chooseMapBlock({
                    filterTarget: return target.is_revealed() == false # 目标地块必须未被展示
                    filterTargetRange: "中距离" # 目标必须在相邻地块
                })
                if( target == null ) break # 无可选地块则停止
                target.展示( 触发效果 = false, player ) # 展示地块但不触发地块效果
                count++
                if( count < maxReveal ){
                    choice = player.choose( ["继续展示", "停止展示"] )
                    if( choice == "停止展示" ) break
                }
            }
        }
    }
}

求生者游戏牌{
    名字: 抓捕小动物
    牌堆中数量: 2
    类型: 行动
    技能: {
        技能名: "抓捕小动物"
        技能描述: "行动：如果狗还活着，将老兵和狗的饥饿等级各降低2点。"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗还活着时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.veteran.decreaseHunger( 2 ) # 老兵饥饿等级降低2点（见 GameSystem/PlayerState.md 中 decreaseHunger 定义，最低降至1）
            player.dog.decreaseHunger( 2 ) # 狗饥饿等级降低2点
        }
    }
}

求生者游戏牌{
    名字: 致残
    牌堆中数量: 3
    类型: 行动
    技能: {
        技能名: "致残"
        技能描述: "行动：如果狗还活着，击晕一个目标并对它造成2点伤害。"
        射程: "中距离"
        skillType: "行动"
        active: "行动阶段"
        # 行动阶段、有剩余行动次数、且狗还活着时可用
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.dog.get_hp() > 0
        selectTarget: 1 # 选择1个目标
        filterTarget: return true # 任何目标都可用
        filterTargetRange: "中距离" # 目标必须在中距离范围内
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            target.damage( 2, player.dog ) # 对目标造成2点伤害，伤害来源为狗
            target.击晕( player.dog, until = "下个回合开始时" ) # 击晕目标直到你的下个回合开始
        }
    }
}
