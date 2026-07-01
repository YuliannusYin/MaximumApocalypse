Skill{
    技能名："移动"
    技能描述："移动到目标地块"
    active: "行动阶段"
    filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
    filterTarget: return target != player.所在地图块() # 目标地块不能是玩家当前所在地块
    filterTargetRange: "中距离" # 目标地块必须在中距离范围内（相邻地块）
    content: {
        player.减少行动次数( 1 ) # 消耗1点行动次数
        player.moveTo(target) # 调用底层函数
    }
} 

Skill{
    技能名："拾荒"
    技能描述："从可以进行拾荒的牌堆中抓取一张牌"
    active: "行动阶段"
    filter: {
        if( player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.所在地图块().hasColor() ){
            return true # 行动阶段、有剩余行动次数，且当前所在地块存在可拾荒的颜色牌堆时可用
        } else return false # 否则不可用
    }
    filterTarget: return getColor(target).isIn(getColor(player.所在地图块())) # 目标拾荒牌堆的颜色必须属于玩家所在地块的颜色集合
    content: {
        player.减少行动次数( 1 ) # 消耗1点行动次数
        player.drawScavenge(1, target) # 从目标拾荒牌堆中抓取1张牌
    }
}

Skill{
    技能名："摸牌"
    技能描述："从玩家游戏牌库中抓取一张牌"
    active: "行动阶段"
    filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段且有剩余行动次数时可用
    content: {
        player.减少行动次数( 1 ) # 消耗1点行动次数
        player.draw(1) # 从玩家游戏牌库抓取1张牌到手牌区
    }
}

Skill{
    技能名："制衡"
    技能描述："你可以弃置两张玩家游戏牌，然后从玩家游戏牌库中抓取一张牌"
    active: "行动阶段"
    usable: 1 # 每个回合的行动阶段限用1次
    filter: return player.inPhase == "行动阶段" # 免费行动：不消耗行动次数，仅在行动阶段可用
    selectCard: 2 # 需选择2张牌
    filterCard: return getSource(card) == player # 只能选来源于“玩家游戏牌库”的牌（即必须是玩家游戏牌）
    position: "手牌区" # 选牌位置限定为手牌区
    content: {
        player.discard(cards)
        player.draw(1) # 从玩家游戏牌库抓取1张牌
    }
}

Skill{
    技能名："交易"
    技能描述："你可以选择一张拾荒牌牌和同地图块内另一玩家，然后你将该拾荒牌牌向该玩家展示，其可以选择一张手中的拾荒牌与你交易。"
    active: "行动阶段"
    usable: 1 # 每个回合的行动阶段限用1次
    filter: return player.inPhase == "行动阶段" && getPlayerNumber(player.所在地图块()) > 1 # 免费行动：不消耗行动次数；需在行动阶段，且当前地块上有超过1名玩家（即有交易对象）
    selectCard: 1 # 需选择1张牌
    filterCard: return getSource(card) == scavenge # 选中的牌必须来源于拾荒牌堆（即必须是拾荒牌）
    position: "手牌区" # 选牌位置限定为手牌区
    selectTarget: 1 # 需选择1个目标
    filterTargetRange: "短距离" # 目标必须在短距离范围内（同地块内）
    filterTarget: return target.hasScavengeCard() && target != player # 目标必须持有拾荒牌，且不能是玩家自己
    content: {
        # 向目标展示所选的拾荒牌
        player.showCard(card, target)
        
        # 询问目标是否同意交易
        list = ["同意", "拒绝"]
        result = target.choose( list )

        # 若目标同意，则进行双方拾荒牌交换
        if( result == "同意" ){

            # 目标从其手牌区中选择1张拾荒牌
            card2 = target.chooseCard(1, position="手牌区", source="scavenge") #target选择手牌区中的一张拾荒牌
            
            target.getCard(card) # 目标获得玩家展示的牌
            player.getCard(card2) # 玩家获得目标选定的牌
        } 
    }
}

Skill{
    技能名："加油"
    技能描述："行动：消耗一个燃料，为面包车或燃料型装备补充燃料。"
    active: "行动阶段"
    usable: Infinity # 不限使用次数
    filter: return player.inPhase == "行动阶段" && 玩家装备区里有'燃料' # 自然语言描述，待实现为具体函数调用；免费行动：不消耗行动次数；需在行动阶段，且玩家持有燃料
    filterTargetRange: "短距离" # 目标必须在短距离范围内
    filterTarget: {
        # [修改] 2026-07-01: 修正类型矛盾——原 target == player.所在地图块() && target == "面包车" 不可能同时成立（target 不可能既等于地块对象又等于字符串），改为分项判断地块名
        if( target == player.所在地图块() && player.所在地图块().名字 == "面包车" ){ # 目标是玩家所在地块的面包车
            return true
        } else if( target.填充物类型 == "燃料" ){ # 目标是填充物类型为"燃料"的装备
            return true
        }
        return false
    }
    content: {
        player.discard( name = "燃料", quantity = 1, position = "装备区" ) 

        # 根据目标类型执行不同的加油逻辑
        if( target == "面包车" ){ # 目标是面包车：玩家往面包车添加1个燃料
            target.加油(1, player) # 玩家往面包车添加1个燃料
        }
        else{ # 目标是装备：添加该装备允许的最大燃料量
            target.添加填充物(max, "燃料") # 往装备添加最大燃料量
        }
    }
}

function player.moveTo(target) { # 底层移动函数（不扣行动次数，只负责移动和触发钩子）
    source = player.所在地图块()

    # 1. 离开所在地块前（扣费已由调用方处理，这里不再扣）
    # 2. 离开所在地块时
    source.触发("离开地块时", player)

    # 3. 进入目标地块前（准入检定）
    if( target.触发("进入地块前", player) == false ){
        return false  # 移动失败（如河流潜行失败）
    }

    # 4. 移动时（坐标变更）
    player.moveToMapBlock( target )

    # 5. 离开所在地块后（清除旧地块技能）
    source.清除技能( player )

    # 6. 进入目标地块时
    target.触发("进入地块时", player)

    # 7. 进入目标地块后（展示地图块并触发展示效果）
    if( !target.已展示() ) {
        target.展示(触发效果=true, player) # 玩家展示地块并触发"展示地块时"钩子
    }

    return true  # 移动成功
}

