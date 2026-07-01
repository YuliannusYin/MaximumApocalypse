# 食物类拾荒牌

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（微量）
    数值：1
    技能: {
        技能名: "食物（微量）"
        技能描述: "玩家饥饿值减少1点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.getNumber( "玩家饥饿值" ) > 1 # 行动阶段、有剩余行动次数、饥饿值大于1时可用（饥饿值最小为1，已为1时不需再使用）
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少饥饿值( 1 ) # 玩家饥饿值减少1点
        }
    }
}

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（小额）
    数值：2
    技能: {
        技能名: "食物（小额）"
        技能描述: "玩家饥饿值减少2点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.getNumber( "玩家饥饿值" ) > 1 # 饥饿值最小为1，已为1时不需再使用
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少饥饿值( 2 ) # 玩家饥饿值减少2点
        }
    }
}

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（标准）
    数值：3
    技能: {
        技能名: "食物（标准）"
        技能描述: "玩家饥饿值减少3点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.getNumber( "玩家饥饿值" ) > 1 # 饥饿值最小为1，已为1时不需再使用
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少饥饿值( 3 ) # 玩家饥饿值减少3点
        }
    }
}

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（足量）
    数值：4
    技能: {
        技能名: "食物（足量）"
        技能描述: "玩家饥饿值减少4点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.getNumber( "玩家饥饿值" ) > 1 # 饥饿值最小为1，已为1时不需再使用
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少饥饿值( 4 ) # 玩家饥饿值减少4点
        }
    }
}

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（大量）
    数值：5
    技能: {
        技能名: "食物（大量）"
        技能描述: "玩家饥饿值减少5点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.getNumber( "玩家饥饿值" ) > 1 # 饥饿值最小为1，已为1时不需再使用
        filterTarget: return target == player # 仅作用于玩家自身
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.减少饥饿值( 5 ) # 玩家饥饿值减少5点
        }
    }
}

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（小箱）
    数值：1
    技能: {
        技能名: "食物（小箱）"
        技能描述: "所有玩家的饥饿值减少1点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段、有剩余行动次数时可用（不限定自身饥饿值，因效果作用于全体玩家）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = getAllPlayers() # 获取场上所有玩家
            for i in List:
                i.减少饥饿值( 1 ) # 饥饿值-1（饥饿值最小为1）
        }
    }
}

拾荒牌{
    大类：食物
    颜色：绿色
    类型：行动牌
    名字：食物（大箱）
    数值：2
    技能: {
        技能名: "食物（大箱）"
        技能描述: "所有玩家的饥饿值减少2点。"
        skillType: "行动"
        active: "行动阶段"
        filter: return player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 # 行动阶段、有剩余行动次数时可用（不限定自身饥饿值，因效果作用于全体玩家）
        content:{
            player.减少行动次数( 1 ) # 消耗1点行动次数
            List = getAllPlayers() # 获取场上所有玩家
            for i in List:
                i.减少饥饿值( 2 ) # 饥饿值-2（饥饿值最小为1）
        }
    }
}
