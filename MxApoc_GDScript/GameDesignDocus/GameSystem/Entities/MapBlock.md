# MapBlock 地图块类

> 继承：[Entity](../Core/Entity.md)
> 职责：地图块属性、展示机制、怪物标记管理与地块技能挂载。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 设计原则

**所有地图块技能全部挂载到玩家身上，由 `player.trigger()` 统一触发。**

玩家进入地块时，地块技能挂载到 Player 身上（`player.获取地块技能(target)`）；离开时清理（`source.清除技能(player)`）。这样玩家身上的所有技能（角色固有、装备、地块、临时）都能通过 `player.trigger()` 统一遍历。

> 详见 [Player.moveTo](Player.md#moveto) 节点 4/7。

---

## 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 名字 | String | 地图块名称（如"避难所"、"面包车"、"军事基地"） |
| 技能 | List\<Skill\> | 地块技能（继承自 Entity 的 skills） |
| 怪物生成点数 | Int | monster_spawn_value。怪物出生检定时，投骰结果匹配的地块生成怪物 |
| 拾荒颜色 | Set\<String\> | 该地块可拾荒的牌堆颜色集合（红/绿/蓝子集）。空集合表示不可拾荒 |
| 是否展示 | Bool | revealed 状态。玩家首次进入时翻开（展示），触发「展示地块时」效果 |
| 怪物标记数 | Int | 地块上的怪物标记数，最多 3 个 |

### 地图块配置格式

> 详见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。
> 格式：`地图块名字[拾荒牌堆颜色][地块刷怪点数]`，例：`游乐园[红、蓝、绿][6]`、`城市[红][8]`。

---

## 信号量（triggers）

| trigger 名 | 触发时机 | 触发对象 |
|-----------|---------|---------|
| 展示地块时 | 地块首次翻开时 | 地块技能（挂载到 player 后由 player.trigger 触发） |

> 地块的其他 trigger（如「回合开始时」、「行动阶段结束时」、「受到伤害时」）由地块技能声明，挂载到 player 后在对应流程触发。例：避难所声明 `trigger: 回合开始时、受到伤害时`。

---

## 方法

### 展示(触发效果, player)

> 翻开未展示的地块。
> 触发场景：[Player.moveTo](Player.md#moveto) 节点 9 中目标地块未展示时。

```gdscript
function block.展示(触发效果, player) {
    block.是否展示 = true

    if (触发效果) {
        # 触发「展示地块时」效果（如百货商店：执行一次免费拾荒）
        # 地块技能已挂载到 player 身上，由 player.trigger 触发
        player.trigger("展示地块时", {player: player, block: block})
    }
}
```

---

### 怪物标记管理

| 方法 | 说明 |
|------|------|
| `addMonsterMark(n)` | 增加 n 个怪物标记（上限 3） |
| `removeMonsterMark(n)` | 移除 n 个怪物标记 |
| `countMonsterMark()` | 返回当前怪物标记数 |
| `hasMonsterMark()` | 是否有怪物标记（countMonsterMark() > 0） |
| `countMonster()` | 返回地块上当前纠缠玩家的怪物总数（怪物卡数） |
| `hasPlayer()` | 是否有玩家在此地块 |
| `hasColor()` | 是否可拾荒（拾荒颜色集合非空） |
| `hasSkill(name)` | 是否具备指定名字的地块技能 |

#### 怪物标记规则

- 地块怪物标记最多 3 个
- 怪物出生检定时，匹配地块若标记 < 3 → +1 标记；标记 = 3 且有玩家 → 每位玩家抓 1 怪物卡（见 [Player.monsterSpawnJudge](Player.md#monsterspawnjudge)）
- 玩家进入有怪物标记的地块时进行潜行检定，失败 → 移除所有标记并抓等量怪物卡（见 [Player.moveTo](Player.md#moveto) 节点 10）

---

### 地块技能挂载

| 方法 | 说明 |
|------|------|
| `获取地块技能(player)` | 将地块技能挂载到 player 身上（由 player.获取地块技能 调用） |
| `清除技能(player)` | 从 player 身上移除地块技能 |

> 这两个方法实际定义在 Player 类（`player.获取地块技能(block)` / `block.清除技能(player)`），通过 `player.addSkill` / `player.removeSkill` 操作。详见 [Player.moveTo](Player.md#moveto)。

---

### 拾荒

| 方法 | 说明 |
|------|------|
| `hasColor()` | 该地块是否可拾荒 |
| `getColors()` | 返回可拾荒的颜色集合 |

> 玩家在该地块拾荒时，从对应颜色的拾荒牌堆抓牌（见 [Player.drawScavenge](Player.md#drawscavenge)）。

---

## 地图块类型示例

> 完整地块列表见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。

| 地块名 | 拾荒颜色 | 刷怪点数 | 关键效果 |
|--------|---------|---------|---------|
| 面包车 | — | 6 | 多数任务的出生点与结束点 |
| 避难所 | — | 12/2 | 回合开始时不在则本回合受击免疫 |
| 军事基地 | 红、蓝 | 0 | 进入时造成伤害 |
| 监狱 | 红、绿、蓝 | 9 | 进入时减行动次数 |
| 旷野 | — | 6/8 | 进入时抓怪物 |
| 森林 | — | 5/8 | 同回合内进入又离开 → 抓怪物 |
| 河流 | — | 10/11 | 进入需潜行检定，失败 → 阻止移动 |
| 游乐园 | 红、蓝、绿 | 6 | 回合结束时触发效果 |
| 百货商店 | 绿 | 9 | 展示时免费拾荒 |
| 电厂 | — | 10 | 弃置食物类牌 |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。地块技能通过 Entity 机制挂载与触发 |
| [Player](Player.md) | 玩家位于地块上；地块技能挂载到 Player 身上 |
| [Game](../Game/Game.md) | Game 管理地图区域（所有地块） |
| [Skill](../Common/Skill.md) | 地块技能遵循 Skill 结构 |
