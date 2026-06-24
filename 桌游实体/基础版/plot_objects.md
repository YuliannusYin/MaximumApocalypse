# [新增] 2026-06-23: 地块对象数据整理，从 maps.md 提取并结构化

```yaml
plots:
  - name: 百货商店
    scavenge_marker:
      - 绿
    monster_spawn_value:
      - 9
    trigger_effect:
      展示: 执行一次免费的拾荒行动

  - name: 坠毁点
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 10
    trigger_effect:
      展示: 每名玩家摧毁一张装备
      进入: 烧毁一张卡牌

  - name: 电厂
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 10
    trigger_effect:
      进入: 弃掉所有的食物卡。中毒

  - name: 工厂
    scavenge_marker:
      - 蓝
    monster_spawn_value:
      - 4
    trigger_effect:
      展示: 向所有相邻的地块各增加一个怪物标记

  - name: 墓地
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 4
    trigger_effect:
      展示: 每名玩家抓一张怪物卡

  - name: 沙漠
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 4
      - 10
    trigger_effect:
      进入: 饥饿等级增加1

  - name: 森林
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 5
      - 8
    trigger_effect:
      停止: 如果你本会合继续移动，抓一张怪物卡

  - name: 机场
    scavenge_marker:
      - 绿
      - 红
    monster_spawn_value:
      - 8
    trigger_effect:
      行动: 如果这里没有怪物，移动到另一个已展示的地图块

  - name: 沼泽
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 4
      - 8
    trigger_effect:
      进入: 成功：放置1个怪物标记；失败：纠缠你的所有怪物立刻激活

  - name: 城市街道
    scavenge_marker:
      - 蓝5
      - 红6
      - 绿8
    monster_spawn_value:
      - 5
      - 6
      - 8
    trigger_effect:
      进入: 抓一张怪物卡

  - name: 隧道
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 4
      - 10
    trigger_effect:
      行动: 移动到另一个已展示的隧道地图块

  - name: 避难所
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 2
      - 12
    trigger_effect:
      特殊: 当你本回合开始时不在这里且在这里结束回合时，你免疫伤害

  - name: 军事基地
    scavenge_marker:
      - 蓝
      - 红
    monster_spawn_value:
      - 0
    trigger_effect:
      进入: 对你面前的所有怪物各造成2点伤害

  - name: 山
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 5
      - 9
    trigger_effect:
      进入: 抓一张牌

  - name: 丛林
    scavenge_marker:
      - 绿
    monster_spawn_value:
      - 3
      - 11
    trigger_effect:
      展示: 弃掉一张已打出的装备卡
      进入: 抽1张怪物卡

  - name: 加油站
    scavenge_marker:
      - 红
    monster_spawn_value:
      - 4
      - 5
      - 9
    trigger_effect:
      展示: 执行一次免费的拾荒行动

  - name: 城堡
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 9
    trigger_effect:
      进入: 游戏中所有怪物生命值回复至满血

  - name: 荒野
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 6
      - 8
    trigger_effect:
      展示: 抓一张怪物卡
      结束: 抓一张怪物卡

  - name: 祭坛
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 6
    trigger_effect:
      展示: 放置3个怪物标记

  - name: 游乐园
    scavenge_marker:
      - 蓝
      - 绿
      - 红
    monster_spawn_value:
      - 6
    trigger_effect:
      展示: 弃掉3张牌
      结束: 弃掉1张牌

  - name: 警察局
    scavenge_marker:
      - 蓝
    monster_spawn_value:
      - 6
    trigger_effect:
      展示: 执行一次免费的拾荒行动

  - name: 农场
    scavenge_marker:
      - 绿
    monster_spawn_value:
      - 3
      - 11
    trigger_effect:
      展示: 执行一次免费的拾荒行动

  - name: 购物中心
    scavenge_marker:
      - 蓝
    monster_spawn_value:
      - 8
    trigger_effect:
      展示: 执行一次免费的拾荒行动

  - name: 教堂
    scavenge_marker:
      - 红
    monster_spawn_value:
      - 10
    trigger_effect:
      进入: 击晕1个此处的怪物
      结束: 再次执行怪物出生

  - name: 花园
    scavenge_marker:
      - 绿
    monster_spawn_value:
      - 5
    trigger_effect:
      结束: 治愈所有状态效果

  - name: 绿洲
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 11
    trigger_effect:
      结束: 饥饿等级减少1点

  - name: 河流
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 10
      - 11
    trigger_effect:
      检定: 成功：移动到本地图块；失败返回之前的地图块

  - name: 面包车
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 6
    trigger_effect:
      - 无

  - name: 监狱
    scavenge_marker:
      - 蓝
      - 绿
      - 红
    monster_spawn_value:
      - 9
    trigger_effect:
      展示: 结束你的会合
      进入: 失去1个行动点

  - name: 强盗营地
    scavenge_marker:
      - 无
    monster_spawn_value:
      - 3
      - 9
    trigger_effect:
      进入: 弃掉一张已装备的装备卡或受到5点伤害

  - name: 医院
    scavenge_marker:
      - 红
    monster_spawn_value:
      - 3
    trigger_effect:
      进入: 恢复1点生命
      结束: 恢复2点生命
```