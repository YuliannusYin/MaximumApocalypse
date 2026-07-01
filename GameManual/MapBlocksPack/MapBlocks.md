# 地图块包

## 地图块配置

# 格式：地图块名字[拾荒牌堆颜色][地块刷怪点数]，例：游乐园[红、蓝、绿][6]、城市[红][8]、
# 拾荒牌堆颜色：该地块可拾荒的牌堆颜色（无颜色表示该地块不可拾荒）
# 地块刷怪点数：该地块的怪物刷怪点数

百货商店[绿][9]
避难所[][12]
避难所[][2]
城市街道[红][6]
城市街道[绿][8]
城市街道[蓝][5]
电厂[][10]
河流[][10]
河流[][11]
机场[红、绿][8]
警察局[蓝][6]
军事基地[红、蓝][0]
监狱[红、绿、蓝][9]
旷野[][6]
旷野[][8]
工厂[蓝][4]
购物中心[蓝][8]
加油站[红][9]
加油站[红][5]
加油站[红][4]
绿洲[][11]
面包车[][6]
墓地[][4]
农场[绿][3]
农场[绿][11]
强盗营地[][9]
强盗营地[][3]
山[][9]
山[][5]
隧道[][10]
隧道[][4]
森林[][5]
森林[][8]
沙漠[][10]
沙漠[][4]
游乐园[红、蓝、绿][6]
医院[红][3]
坠毁点[][10]

## 地图块详情

地图块{
    地图块名称: 百货商店
    技能: {
        技能名: "百货商店"
        技能描述: "展示：执行一次免费的拾荒行动"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: player.drawScavenge(1, 拾荒牌堆颜色) # 从该地块对应颜色的拾荒牌堆中抓取1张牌
    }
}

地图块{
    地图块名称: 避难所
    技能: {
        技能名: "避难所"
        技能描述: "若你本回合开始时不在这里，且在这里受到伤害时，你免疫伤害。"
        trigger: 回合开始时、受到伤害时
        filter: {
            # 若玩家已持有「避难所失效」标记，则本技能不触发（即本回合后续受击不再免疫）
            return !player.hasMarkSkill("避难所失效")
        }
        content: {
            if( trigger == "回合开始时" && player.所在地图块().hasSkill("避难所") ){
                # 回合开始时若已在避难所 → 添加「避难所失效」标记（持续到回合结束）→ 本回合后续受击不再免疫
                player.addMarkSkill(markName = "避难所失效", quantity = 1, Until = "回合结束") # 添加一个“避难所失效”的标记, 标记持续到“回合结束”。
            } else if( trigger == "受到伤害时" && player.所在地图块().hasSkill("避难所") ){
                # 回合开始时不在避难所（无标记）→ 此处受击免疫伤害
                player.免疫伤害()
            }
        }
    }
}

地图块{
    地图块名称: 城市街道
    技能: {
        技能名: "城市街道"
        技能描述: "展示：抓一张怪物卡"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: player.drawMonster(1) # 抓1张怪物卡
    }
}

地图块{
    地图块名称: 电厂
    技能: {
        技能名: "电厂"
        技能描述: "展示：弃掉所有的食物卡。进入：中毒层数加一。"
        trigger: 展示地块时、进入地块时
        filter: 无
        content: {
            if( trigger == "展示地块时" ){
                player.discard("食物") # 弃掉所有食物卡
            } else if( trigger == "进入地块时" && player.所在地图块().hasSkill("电厂") ){
                player.addPoison(1) # 中毒层数+1
            }
        }
    }
}

地图块{
    地图块名称: 河流
    技能: {
        技能名: "河流"
        技能描述: "进入此地块前，进行一次潜行检定，成功：移动到本地；失败：返回之前的地图块"
        trigger: 进入地块前
        filter: 无
        content: {
            if( !player.潜行检定() ){
                player.终止技能结算("移动")
                player.clearSkill("河流")
            }
        }
    }
}

地图块{
    地图块名称: 机场
    技能: {
        技能名: "机场"
        技能描述: "行动：如果这里没有怪物，移动到另一个已展示的地图块。"
        active: "行动阶段"
        filter: {
            # 需在行动阶段、有剩余行动次数、当前所在地块为机场、且该地块上无交战怪物时可用
            return ( player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.所在地图块().hasSkill("机场") && !player.所在地图块().有怪物() ) 
        }
        # 目标地块必须已展示、无怪物标记（未被放置怪物标记）、且不是玩家当前所在地块
        filterTarget: return target.已展示() && !target.有怪物标记() && target != player.所在地图块() # 目标地块不能是玩家当前所在地块
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            player.moveTo( target ) # 将玩家移至目标地块
        }
    }
}

地图块{
    地图块名称: 警察局
    技能: {
        技能名: "警察局"
        技能描述: "展示：执行一次免费的拾荒行动"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: player.drawScavenge(1, 拾荒牌堆颜色) # 从该地块对应颜色的拾荒牌堆中抓取1张牌
    }
}

地图块{
    地图块名称: 军事基地
    技能: {
        技能名: "军事基地"
        技能描述: "进入：对你面前的所有怪物各造成两点伤害"
        trigger: 进入地块时
        filter: 无
        content: {
            List = get纠缠玩家的怪物(player) # 获取所有与该玩家交战的怪物
            for i in List:
                i.受到伤害(2, player) # 对每只交战怪物造成2点伤害（函数对象.受到伤害(伤害值, 伤害来源)）
        }
    }
}

地图块{
    地图块名称: 监狱
    技能: {
        技能名: "监狱"
        技能描述: "展示：立即结束你的行动阶段。进入：减少一次行动次数"
        trigger: 展示地块时、进入地块时
        filter: 无
        content: {
            # 展示地块时：若当前处于行动阶段，立即结束行动阶段
            if( trigger == "展示地块时" && player.inPhase == "行动阶段" ){
                player.结束阶段( "行动阶段" )
            } else if( trigger == "进入地块时" && player.所在地图块().hasSkill( "监狱" ) ){
                player.减少行动次数(1) # 进入地块时：减少1点行动次数
            }
        }
    }
}

地图块{
    地图块名称: 旷野
    技能: {
        技能名: "旷野"
        技能描述: "进入：抓一张怪物卡"
        trigger: 进入地块时
        filter: 无
        content: player.drawMonster(1) # 抓1张怪物卡
    }
}

地图块{
    地图块名称: 工厂
    技能: {
        技能名: "工厂"
        技能描述: "展示：向所有相邻的地块各增加一个怪物标记"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: {
            List = get相邻的地块(player.所在地图块()) # 获取当前地块所有相邻的地块
            for i in List:
                i.添加怪物标记(1) # 为每个相邻地块添加1个怪物标记
        }
    }
}

地图块{
    地图块名称: 购物中心
    技能: {
        技能名: "购物中心"
        技能描述: "展示：执行一次免费的拾荒行动"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: player.drawScavenge(1, 拾荒牌堆颜色) # 从该地块对应颜色的拾荒牌堆中抓取1张牌
    }
}

地图块{
    地图块名称: 加油站
    技能: {
        技能名: "加油站"
        技能描述: "展示：执行一次免费的拾荒行动"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: player.drawScavenge(1, 拾荒牌堆颜色) # 从该地块对应颜色的拾荒牌堆中抓取1张牌
    }
}

地图块{
    地图块名称: 绿洲
    技能: {
        技能名: "绿洲"
        技能描述: "结束：减少一点饥饿值"
        trigger: 回合结束时
        filter: 无
        content: player.减少饥饿值(1) # 减少1点饥饿值
    }
}

地图块{
    地图块名称: 面包车 # 特殊地图块一般是玩家的出生点和结束点
}

地图块{
    地图块名称: 墓地
    技能: {
        技能名: "墓地"
        技能描述: "展示：每名玩家抓一张怪物卡。进入：抓一张怪物卡"
        trigger: 展示地块时、进入地块时
        filter: 无
        content: {
            if( trigger == "展示地块时" ){
                List = game.get场上所有玩家() # 获取场上所有玩家
                for i in List:
                    i.drawMonster(1) # 每名玩家各抓1张怪物卡
            }
            else if( trigger == "进入地块时" ){
                player.drawMonster(1) # 进入的玩家抓1张怪物卡
            }
        }
    }
}

地图块{
    地图块名称: 农场
    技能: {
        技能名: "农场"
        技能描述: "展示：执行一次免费的拾荒行动"
        trigger: 展示地块时 # 翻开该地块时触发
        filter: 无
        content: player.drawScavenge(1, 拾荒牌堆颜色) # 从该地块对应颜色的拾荒牌堆中抓取1张牌
    }
}

地图块{
    地图块名称: 强盗营地
    技能: {
        技能名: "强盗营地"
        技能描述: "进入：弃掉一张已装备的装备卡或者受到5点伤害"
        trigger: 进入地块时
        filter: 无
        content: {
            if( !player.hasCard(position = "装备区") ){
                # 无装备可弃 → 直接受到5点无源伤害
                player.受到伤害(5, 'nosource') #受到5点无源伤害
            } else {
                # 有装备 → 玩家选择弃置装备或受到伤害
                List = ["弃置装备", "受到伤害"]
                result = player.choose(List)
                if( result == "弃置装备" ){
                    player.chooseToDiscard(1, position = "装备区") #玩家选择弃置一张已装备的装备卡
                }
                else if( result == "受到伤害" ){
                    player.受到伤害(5, 'nosource') #受到5点无源伤害
                }
            }
        }
    }
}

地图块{
    地图块名称: 山
    技能: {
        技能名: "山"
        技能描述: "进入：抓一张牌"
        trigger: 进入地块时
        filter: 无
        content: player.draw(1) # 从玩家游戏牌库抓取1张牌
    }
}

地图块{
    地图块名称: 隧道
    技能: {
        技能名: "隧道"
        技能描述: "行动：移动到另一个已经展示的【隧道】地图块"
        active: "行动阶段"
        filter: {
            # 需在行动阶段、有剩余行动次数、且当前所在地块为隧道时可用
            return ( player.inPhase == "行动阶段" && player.getNumber( "玩家剩余行动次数" ) > 0 && player.所在地图块().hasSkill("隧道") ) 
        }
        filterTarget: return target.hasSkill("隧道") && target != player.所在地图块() # 目标地块必须为隧道、且不能是玩家当前所在地块
        content: {
            player.减少行动次数( 1 ) # 消耗1点行动次数
            # [修改] 2026-06-30: moveToMapBlock→moveTo，触发进入/离开/展示钩子（见 PlayerSkill.md player.moveTo）
            player.moveTo( target ) # 将玩家移至目标地块（触发全套地块钩子）
        }
    }
}

地图块{
    地图块名称: 森林
    技能: {
        技能名: "森林"
        技能描述: "进入此地块后，并在同一个回合内移动出此地块后，抓一张怪物卡"
        trigger: 进入地块时、离开地块时
        filter: 无
        content: {
            if( trigger == "进入地块时" ){
                # 进入森林时添加「森林里的怪兽」标记（持续到回合结束），用于记录本回合曾进入森林
                player.addMarkSkill(markName = "森林里的怪兽", quantity = 1, Until = "回合结束")
            }
            else if( trigger == "离开地块时" && player.hasMarkSkill("森林里的怪兽") ){
                # 同回合内进入又离开森林 → 抓1张怪物卡
                player.drawMonster(1)
            }
        }
    }
}

地图块{
    地图块名称: 沙漠
    技能: {
        技能名: "沙漠"
        技能描述: "进入：饥饿等级增加1"
        trigger: 进入地块时
        filter: 无
        content: player.增加饥饿值(1) # 饥饿等级+1
    }
}

地图块{
    地图块名称: 游乐园
    技能: {
        技能名: "游乐园"
        技能描述: "展示：弃掉三张牌。结束：弃掉一张牌"
        trigger: 展示地块时、回合结束时
        filter: 无
        content: {
            if( trigger == "展示地块时" ){
                player.chooseToDiscard(3) # 玩家选择弃置3张牌
            }
            else if( trigger == "回合结束时" ){
                player.chooseToDiscard(1) # 玩家选择弃置1张牌
            }
        }
    }
}

地图块{
    地图块名称: 医院
    技能: {
        技能名: "医院"
        技能描述: "进入：恢复一点生命值。结束：恢复两点生命值"
        trigger: 进入地块时、回合结束时
        filter: 无
        content: {
            if( trigger == "进入地块时" ){
                player.增加生命值(1) # 进入时恢复1点生命值
            }
            else if( trigger == "回合结束时" ){
                player.增加生命值(2) # 回合结束时恢复2点生命值
            }
        }
    }
}

地图块{
    地图块名称: 坠毁点
    技能: {
        技能名: "坠毁点"
        技能描述: "展示：每名玩家销毁一张装备。进入：销毁一张牌"
        trigger: 展示地块时、进入地块时
        filter: 无
        content: {
            if( trigger == "展示地块时" ){
                List = game.get场上所有玩家() # 获取场上所有玩家
                for i in List: # 遍历场上所有玩家
                    # 玩家装备区不为空时，随机销毁一张装备
                    if( i.装备区有牌() ){
                        i.remove( getCard(i, quantity = 1, position = "装备区", random = true) ) # 随机销毁玩家的一张装备
                    }
            }
            else if( trigger == "进入地块时" && player.区域内有牌() ){
                player.remove( getCard(player, quantity = 1, random = true) ) # 随机销毁玩家的一张牌
            }
        }
    }
}
