# 僵尸类怪包

## 构成

僵尸女王（首领）
一大波僵尸（首领）
僵尸狗 * 6
僵尸士兵 * 6
僵尸步行者 * 6
僵尸步行者（精英）* 6
僵尸喷吐者（精英）* 6
僵尸潜行者（精英）* 6

## 详情

僵尸女王{
    怪物级别: 首领
    初始血量: 18
    攻击伤害: 5
    技能: {
        技能名: "僵尸女王"
        技能描述："当场上任何僵尸类型怪物被消灭时，消灭该怪物的玩家必须抓取一张新的怪物卡。" 
        skillType: "Monster"
        trigger: 怪物被消灭时
        filter: return trigger.subType == "ZOMBIE"
        forced: true
        content:{
            player.drawMonster(1)
        }
    }
}

一大波僵尸{
    怪物级别：首领
    初始血量：16
    攻击伤害：4
    射程：短距离
    技能: {
        技能名: "一大波僵尸"
        技能描述："在抓取该卡玩家的所有相邻地块上各放置一个怪物标记。该玩家再抓取一张怪物卡。"
        skillType: "Monster"
        trigger: 抓取怪物时
        filter: return event.monster.name == "一大波僵尸"
        forced: true
        content:{
            List = get相邻的地块(player.所在地图块()) # 获取当前地块所有相邻的地块
            for i in List:
                i.添加怪物标记(1) # 为每个相邻地块添加一个怪物标记
            player.drawMonster(1)
        }
    }
}

僵尸狗{
    怪物级别：普通
    初始血量：5
    攻击伤害：4
    射程：无
}

僵尸士兵{
    怪物级别：普通
    初始血量：8
    攻击伤害：4
    射程：无
}

僵尸步行者{
    怪物级别：普通
    初始血量：4
    攻击伤害：2
    射程：无
}

僵尸步行者（精英）{
    怪物级别：精英
    初始血量：4
    攻击伤害：2
    射程：无
    技能: {
        技能名: "僵尸步行者"
        技能描述："抓取此卡的玩家再抓取一张怪物卡。"
        skillType: "Monster"
        trigger: 抓取怪物时
        filter: return event.monster.name == "僵尸步行者"
        forced: true
        content:{
            player.drawMonster(1)
        }
    }
}

僵尸喷吐者（精英）{
    怪物级别：精英
    初始血量：6
    攻击伤害：2
    射程：中距离
}

僵尸潜行者（精英）{
    怪物级别：精英
    初始血量：12
    攻击伤害：5
    射程：中距离
    技能: {
        技能名: "僵尸潜行者"
        技能描述："攻击后，移动到并纠缠场上血量最低的玩家面前"
        skillType: "Monster"
        trigger: 怪物攻击后
        filter: return event.monster.name == "僵尸潜行者"
        filterTarget: return target.type == "HUMAN" && target.isMinHp()
        filterTargetRange: Infinity # 无距离限制
        forced: true
        content:{
            修改"僵尸潜行者"的纠缠目标为target
        }
    }
}