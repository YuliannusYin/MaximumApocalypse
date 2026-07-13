# 使用卡牌

> 玩家在行动阶段可从手牌中使用卡牌。对应行动阶段行动选项 #3「从手牌中打出 1 张牌」（见 [D_gameFlow.md](D_gameFlow.md)）。

## 卡牌类型

在你的回合能使用的所有卡牌一共有两种：**行动**和**装备**。拾荒卡和求生者游戏牌都属于其中的某一种。

| 类型 | 使用方式 | 使用后去向 |
|------|---------|-----------|
| 行动牌 | 即时使用，按照卡牌文字执行效果 | 弃掉（按来源分派弃牌堆） |
| 装备牌 | 进入装备区，提供持续性技能效果 | 留在装备区 |

> 装填武器、吃食物和治疗玩家都属于行动牌，使用时都需要花费行动。

## 使用流程

从手牌中使用一张卡牌需要花费一个行动。流程方法见 [player.useCard](../GameSystem/Entities/Player.md#usecardcard)。

### 事件钩子

| 节点 | trigger 名 | 说明 |
|------|-----------|------|
| 1 | 使用卡牌前 | **取消点**；可校验行动次数、手牌合法性 |
| 2 | 使用卡牌时 | **取消点**；装备牌/行动牌分流的最后拦截点 |
| 3 | （系统结算） | 扣 1 点行动次数 → 按类型分流（装备/行动） |
| 4 | 使用卡牌后 | 整体触发一次 |

### 行动次数消耗

useCard 对装备牌和行动牌**统一消耗 1 点行动次数**。卡牌技能 content 内不再调用 `player.减少行动次数(1)`，由 useCard 流程统一负责。

### 卡牌类型分流

- **装备牌** → 调用 `player.装备(card)` 进入装备区（触发装备流程 trigger，见 [player.装备](../GameSystem/Entities/Player.md#装备card)）。装备栏容量校验失败时取消装备并提示。
- **行动牌** → 技能 content 由技能系统独立执行，执行后弃掉这张牌。

### 弃牌堆分流

行动牌使用后按 `card.source` 字段自动分派到对应弃牌堆：

- `source == "scavenge"`（拾荒卡）→ 拾荒弃牌堆
- `source == "game"`（求生者游戏牌）→ 游戏牌弃牌堆

> 在使用一张拾荒卡后，把它放到拾荒弃牌堆中，不要放到求生者的游戏牌弃牌堆中。此分派由 `player.discard(card)` 内部按 source 字段自动处理（见 [player.discard](../GameSystem/Entities/Player.md#discardtarget-positionnull-quantity1-typenull)）。

## trigger 索引

使用卡牌类 trigger 的完整定义见 [EventSystem §4](../GameSystem/Core/EventSystem.md#4-全-trigger-索引)。
