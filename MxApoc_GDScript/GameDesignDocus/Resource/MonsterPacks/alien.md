# 外星人类怪包

## 构成

外星收割者（首领）×1
外星指挥官（首领）×1
外星科学家（精英）×5
外星机械（精英）×4
外星入侵者（精英）×7
外星飞船（精英）×3
外星士兵（精英）×6

## 怪物详情

# 怪物卡进入求生者怪物区时会实体化，实体化后的怪物卡具备以下属性：
#   怪物级别、怪物类型、最大生命值、当前生命值、攻击伤害、射程、技能
# 怪物类型统一为"外星人"；部分技能在"造成伤害时"触发，需以伤害来源（event.source）是否为外星人怪物作为判定条件
# "烧毁"统一按"销毁（移出游戏）"处理，被销毁的牌不进入任何弃牌堆；销毁范围为目标玩家的手牌区与装备区
# 销毁 API：player.removeCard(...)，支持按名字+位置销毁（如 removeCard(name=, position=)，见 SurvivorPacks/gunslinger.md）与按卡牌对象销毁（如 removeCard(card)，本包随机销毁场景使用）

怪物卡{
    名字: 外星收割者
    怪物级别: 首领
    怪物类型: "外星人"
    最大生命值: 25
    初始生命值: 25
    攻击伤害: 5
    射程: "无" # 仅攻击其所纠缠的玩家
    技能1: {
        技能名: "外星收割者-摧毁装备"
        技能描述: "当此怪物卡被玩家抓取后，摧毁场上所有的装备牌。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后 # 对应事件流程"怪物卡进入求生者怪物区后"节点
        forced: true # 强制发动
        filter: true
        content: {
            List = getAllPlayers() # 场上所有玩家
            for i in List:
                装备 = getCard(i, position = "装备区") # 获取该玩家装备区内的所有装备牌
                for c in 装备:
                    i.removeCard(c) # 销毁该装备牌（移出游戏）
        }
    }
    技能2: {
        技能名: "外星收割者-烧毁"
        技能描述: "当此怪物卡攻击时，随机销毁目标玩家区域内的一张牌。"
        skillType: "Monster"
        trigger: 怪物攻击时 # 对应怪物行动流程"怪物攻击时"节点
        forced: true
        filter: true
        content: {
            目标玩家 = event.目标玩家 # 受到本次怪物攻击的玩家
            card = getCard(目标玩家, quantity = 1, position = ["手牌区", "装备区"], random = true) # 从其手牌区与装备区中随机选取一张牌
            目标玩家.removeCard(card) # 销毁该牌（移出游戏）
        }
    }
}

怪物卡{
    名字: 外星指挥官
    怪物级别: 首领
    怪物类型: "外星人"
    最大生命值: 22
    初始生命值: 22
    攻击伤害: 4
    射程: "无"
    技能1: {
        技能名: "外星指挥官-集结修复"
        技能描述: "当此怪物卡被玩家抓取后，将场上所有的外星人类怪物回复到满生命值。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后
        forced: true
        filter: true
        content: {
            List = getAllPlayers() # 场上所有玩家
            for p in List:
                for m in p.怪物区: # 该玩家求生者怪物区内所有已实体化的怪物；自然语言描述，待实现为具体函数调用
                    if( m.怪物类型 == "外星人" ){
                        m.生命值 = m.最大生命值 # 回复到满生命值（含本怪物自身）
                    }
        }
    }
    技能2: {
        技能名: "外星指挥官-烧毁"
        技能描述: "当此怪物卡攻击时，随机销毁目标玩家区域内的两张牌。"
        skillType: "Monster"
        trigger: 怪物攻击时
        forced: true
        filter: true
        content: {
            目标玩家 = event.目标玩家
            cards = getCard(目标玩家, quantity = 2, position = ["手牌区", "装备区"], random = true) # 随机选取两张牌（区域内牌不足则全部销毁）
            for c in cards:
                目标玩家.removeCard(c) # 销毁（移出游戏）
        }
    }
}

怪物卡{
    名字: 外星科学家
    怪物级别: 精英
    怪物类型: "外星人"
    最大生命值: 9
    初始生命值: 9
    攻击伤害: 1
    射程: "无"
    技能1: {
        技能名: "外星科学家-勒索装备"
        技能描述: "当此怪物卡被玩家抓取时，抓取该卡的玩家弃掉一张装备区内的装备，否则受到六点伤害。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后
        forced: true
        filter: true
        content: {
            抓取者 = event.玩家 # 抓取此卡的玩家
            if( 抓取者.hasCard(position = "装备区") ){
                # 装备区有装备：玩家选择弃置一张装备或受到6点伤害
                choice = 抓取者.choose(["弃置一张装备", "受到6点伤害"])
                if( choice == "弃置一张装备" ){
                    抓取者.chooseToDiscard(1, position = "装备区") # 弃置一张装备区内的装备（进入游戏牌弃牌堆）
                }
                else if( choice == "受到6点伤害" ){
                    抓取者.damage(6, self) # 受到6点来自此怪物的伤害
                }
            }
            else{
                # 装备区无装备：直接受到6点伤害
                抓取者.damage(6, self)
            }
        }
    }
    技能2: {
        技能名: "外星科学家-协同强化"
        技能描述: "所有外星人类怪物攻击时，造成的伤害加一。"
        skillType: "Monster"
        trigger: 造成伤害时 # 钩在伤害结算流程的"source攻击target时"节点，修改伤害值变量
        forced: true
        filter: return event.source.怪物类型 == "外星人" # 仅当伤害来源为外星人类怪物时触发
        content: {
            event.num += 1 # 造成的伤害+1
        }
    }
}

怪物卡{
    名字: 外星机械
    怪物级别: 精英
    怪物类型: "外星人"
    最大生命值: 18
    初始生命值: 18
    攻击伤害: 4
    射程: "无"
    技能: {
        技能名: "外星机械"
        技能描述: "当此怪物卡被玩家抓取后，随机销毁抓取该卡的玩家的两张牌。"
        skillType: "Monster"
        trigger: 怪物卡进入求生者怪物区后
        forced: true
        filter: true
        content: {
            抓取者 = event.玩家
            cards = getCard(抓取者, quantity = 2, position = ["手牌区", "装备区"], random = true) # 随机选取两张牌（区域内牌不足则全部销毁）
            for c in cards:
                抓取者.removeCard(c) # 销毁（移出游戏）
        }
    }
}

怪物卡{
    名字: 外星入侵者
    怪物级别: 精英
    怪物类型: "外星人"
    最大生命值: 7
    初始生命值: 7
    攻击伤害: 3
    射程: "无" # 原文此字段为空，按多数外星人设定补为"无"
    技能: {
        技能名: "外星入侵者"
        技能描述: "当此怪物卡攻击时，随机销毁目标玩家区域内的一张牌。"
        skillType: "Monster"
        trigger: 怪物攻击时
        forced: true
        filter: true
        content: {
            目标玩家 = event.目标玩家
            card = getCard(目标玩家, quantity = 1, position = ["手牌区", "装备区"], random = true)
            目标玩家.removeCard(card) # 销毁（移出游戏）
        }
    }
}

怪物卡{
    名字: 外星飞船
    怪物级别: 精英
    怪物类型: "外星人"
    最大生命值: 10
    初始生命值: 10
    攻击伤害: 6
    射程: "无"
    技能1: {
        技能名: "外星飞船-烧毁"
        技能描述: "当此怪物卡攻击时，随机销毁目标玩家区域内的一张牌。"
        skillType: "Monster"
        trigger: 怪物攻击时
        forced: true
        filter: true
        content: {
            目标玩家 = event.目标玩家
            card = getCard(目标玩家, quantity = 1, position = ["手牌区", "装备区"], random = true)
            目标玩家.removeCard(card) # 销毁（移出游戏）
        }
    }
    技能2: {
        技能名: "外星飞船-高空规避"
        技能描述: "被动：不能被射程为短距离的武器或行动选为目标。"
        skillType: "Monster"
        被动: true
        # 任何射程为"短距离"的武器或行动在选目标时，跳过本怪物
    }
}

怪物卡{
    名字: 外星士兵
    怪物级别: 精英
    怪物类型: "外星人"
    最大生命值: 15
    初始生命值: 15
    攻击伤害: 3
    射程: "长距离" # 攻击 1、2、3 位置上的所有玩家
    技能: 无
}
