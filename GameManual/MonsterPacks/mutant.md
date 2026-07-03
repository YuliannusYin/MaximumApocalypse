# 突变体怪包

## 构成

狂暴的突变体（首领）×1
达克斯顿·贾格（首领）×1
军部残余武装（精英）×4
强盗（精英）×6
突变体老鼠 ×8
突变体 ×8

## 怪物详情

# 怪物卡进入求生者怪物区时会实体化，实体化后的怪物卡具备以下属性：
#   怪物级别、怪物类型、最大生命值、当前生命值、攻击伤害、射程、技能
# 本包怪物类型统一为"突变体"
# 中毒效果用 addMarkSkill("poison", 1) 添加一层中毒标记，中毒伤害在该玩家回合的"求生者中毒状态结算"阶段结算（见 D_gameFlow.md 第13-14步）；对应 GameSystem/PlayerState.md 中 player.poison() 的 countMark 结算（标记名为 'poison'）
# "弃掉装备/拾荒卡"为弃置（进入对应弃牌堆），与"销毁（移出游戏）"不同
# 怪物攻击时的"目标玩家"按射程确定：射程"无"仅攻击纠缠的玩家；射程"短距离"攻击玩家所在地块上的所有玩家；以此类推（见 F_gameRange.md）

怪物卡{
    名字: 狂暴的突变体
    怪物级别: 首领
    怪物类型: "突变体"
    最大生命值: 30
    初始生命值: 30
    攻击伤害: 5
    射程: "短距离" # 攻击玩家所在地块（1位置）上的所有玩家
    技能: {
        技能名: "狂暴的突变体"
        技能描述: "当此怪物卡攻击时，对所有受到攻击的玩家添加一层中毒效果。"
        skillType: "Monster"
        trigger: 怪物攻击时 # 对应怪物行动流程"怪物攻击时"节点
        forced: true # 强制发动
        filter: true
        content: {
            List = event.目标玩家 # 本次怪物攻击的所有目标玩家（按射程确定）
            for p in List:
                p.addMarkSkill("poison", 1) # 添加一层中毒标记
        }
    }
}

怪物卡{
    名字: 达克斯顿·贾格
    怪物级别: 首领
    怪物类型: "突变体"
    最大生命值: 24
    初始生命值: 24
    攻击伤害: 4
    射程: "中距离" # 攻击 1 和 2 位置上的所有玩家
    技能: {
        技能名: "达克斯顿贾格"
        技能描述: "当此怪物卡被玩家抓取时，所有玩家弃掉一张装备区内的装备，否则受到四点伤害。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后
        forced: true
        filter: true
        content: {
            List = getAllPlayers() # 场上所有玩家，各自独立结算
            for p in List:
                if( p.hasCard(position = "装备区") ){
                    # 装备区有装备：该玩家选择弃置一张装备或受到4点伤害
                    choice = p.choose(["弃置一张装备", "受到4点伤害"])
                    if( choice == "弃置一张装备" ){
                        p.chooseToDiscard(1, position = "装备区") # 弃置一张装备区内的装备（进入游戏牌弃牌堆）
                    }
                    else if( choice == "受到4点伤害" ){
                        p.damage(4, self) # 受到4点来自此怪物的伤害
                    }
                }
                else{
                    # 装备区无装备：直接受到4点伤害
                    p.damage(4, self)
                }
        }
    }
}

怪物卡{
    名字: 军部残余武装
    怪物级别: 精英
    怪物类型: "突变体"
    最大生命值: 10
    初始生命值: 10
    攻击伤害: 4
    射程: "无" # 仅攻击其所纠缠的玩家
    技能: {
        技能名: "军部残余武装"
        技能描述: "当此怪物卡被玩家抓取后，抓取该卡的玩家弃掉一张装备区内的装备，否则受到四点伤害。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后
        forced: true
        filter: true
        content: {
            抓取者 = event.玩家 # 抓取此卡的玩家
            if( 抓取者.hasCard(position = "装备区") ){
                # 装备区有装备：玩家选择弃置一张装备或受到4点伤害
                choice = 抓取者.choose(["弃置一张装备", "受到4点伤害"])
                if( choice == "弃置一张装备" ){
                    抓取者.chooseToDiscard(1, position = "装备区") # 弃置一张装备区内的装备
                }
                else if( choice == "受到4点伤害" ){
                    抓取者.damage(4, self) # 受到4点来自此怪物的伤害
                }
            }
            else{
                # 装备区无装备：直接受到4点伤害
                抓取者.damage(4, self)
            }
        }
    }
}

怪物卡{
    名字: 强盗
    怪物级别: 精英
    怪物类型: "突变体"
    最大生命值: 7
    初始生命值: 7
    攻击伤害: 3
    射程: "无"
    技能: {
        技能名: "强盗"
        技能描述: "当此怪物卡被玩家抓取后，抓取该卡的玩家弃掉一张拾荒卡，否则受到三点伤害。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后
        forced: true
        filter: true
        content: {
            抓取者 = event.玩家
            if( 抓取者.hasCard(position = "手牌区", source = "scavenge") ){
                # 手牌区有拾荒牌：玩家选择弃置一张拾荒牌或受到3点伤害
                choice = 抓取者.choose(["弃置一张拾荒牌", "受到3点伤害"])
                if( choice == "弃置一张拾荒牌" ){
                    抓取者.chooseToDiscard(1, position = "手牌区", source = "scavenge") # 弃置一张手牌区中的拾荒牌（进入拾荒弃牌堆）
                }
                else if( choice == "受到3点伤害" ){
                    抓取者.damage(3, self) # 受到3点来自此怪物的伤害
                }
            }
            else{
                # 手牌区无拾荒牌：直接受到3点伤害
                抓取者.damage(3, self)
            }
        }
    }
}

怪物卡{
    名字: 突变体老鼠
    怪物级别: 精英
    怪物类型: "突变体"
    最大生命值: 5
    初始生命值: 5
    攻击伤害: 2
    射程: "无"
    技能: {
        技能名: "突变体老鼠"
        技能描述: "当此怪物卡攻击时，对所有受到攻击的玩家添加一层中毒效果。"
        skillType: "Monster"
        trigger: 怪物攻击时
        forced: true
        filter: true
        content: {
            List = event.目标玩家
            for p in List:
                p.addMarkSkill("poison", 1) # 添加一层中毒标记
        }
    }
}

怪物卡{
    名字: 突变体
    怪物级别: 精英
    怪物类型: "突变体"
    最大生命值: 8
    初始生命值: 8
    攻击伤害: 5
    射程: "无"
    技能: 无
}
