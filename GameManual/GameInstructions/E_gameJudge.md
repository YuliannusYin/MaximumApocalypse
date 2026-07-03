# 怪物出生检定

player.monsterSpawnJudge() # 具体查看[怪物出生检定方法](GameManual\PlayerSkill.md)。

# 潜行检定

player.sneakJudge() # 具体查看[潜行检定方法](GameManual\PlayerSkill.md)。
如果潜行检定成功，则无事发生。
如果潜行检定失败，移除该地图块上的所有怪物标记,每移除一个怪物标记就抓一张怪物卡。
如果怪物牌堆抓空了，重洗怪物弃牌堆并组成一个新怪物牌堆。