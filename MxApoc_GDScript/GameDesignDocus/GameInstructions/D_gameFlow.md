# 游戏流程

## 游戏循环

每名玩家按座位顺序轮流进行回合，直到游戏结束：

```
游戏开局 → seat1 玩家回合 → seat2 玩家回合 → seat3 玩家回合 → seat4 玩家回合
        ↑                                                              │
        └──────────────────────────────────────────────────────────────┘
                                   （循环直至游戏结束）
```

回合切换由 [GameStateMachine.nextTurn()](../GameSystem/Core/GameStateMachine.md#nextturn) 驱动；额外回合/跳过回合由状态机回合队列管理。

---

## 玩家回合流程

> 对应底层方法：[Player.开始回合()](../GameSystem/Entities/Player.md#十回合流程)。
> 完整 21 节点流程，含 7 个非钩子节点（节点 1/7/9/20/21）和 14 个钩子节点。
> 玩家在摸牌/饥饿/中毒/面前怪物行动后均可能死亡，死亡后流程中止（详见各节点说明）。

| # | 节点 | 阶段（inPhase） | 系统行为与说明 |
|---|------|---------------|---------------|
| 1 | （进入玩家回合） | `"回合开始"` | 非钩子节点。重置行动次数为 `最大行动次数`，清除回合临时标记（如"避难所失效"等持续到回合结束的标记） |
| 2 | 回合开始前 | `"回合开始"` | trigger 节点 |
| 3 | 回合开始时 | `"回合开始"` | trigger 节点（如 MapBlocks 避难所、电厂） |
| 4 | 怪物出生前 | `"怪物出生"` | trigger 节点 |
| 5 | 怪物出生时 | `"怪物出生"` | trigger 节点 + 进行一次[怪物出生检定](E_gameJudge.md)（`player.monsterSpawnJudge()`） |
| 6 | 摸牌阶段前 | `"摸牌阶段"` | trigger 节点 |
| 7 | （摸牌阶段） | `"摸牌阶段"` | 非钩子节点。从求生者游戏牌堆抓 1 张牌（`player.draw(1)`）。**牌堆空不能抓牌时，玩家死亡，流程中止** |
| 8 | 行动阶段前 | `"行动阶段"` | trigger 节点。**若玩家所在地块有怪物标记，先进行[潜行检定](E_gameJudge.md)**：检定在 trigger 之前执行，失败时移除该地块所有怪物标记，每移除一个抓一张怪物卡。trigger 触发时地块已无怪物标记 |
| 9 | （行动阶段） | `"行动阶段"` | 非钩子节点。执行 4 个行动 + 免费行动（详见下方[行动阶段](#行动阶段)）。行动次数耗尽或玩家主动结束时进入下一节点 |
| 10 | 行动阶段结束前 | `"行动阶段"` | trigger 节点（如 gunslinger「扣动扳机让我快乐」subSkill） |
| 11 | 行动阶段结束时 | `"行动阶段"` | trigger 节点 |
| 12 | 求生者饥饿状态结算前 | `"饥饿结算"` | trigger 节点（如 firefighter「野地夹克」subSkill） |
| 13 | 求生者饥饿状态结算时 | `"饥饿结算"` | trigger 节点 + `player.increaseHunger(1)`。**饥饿伤害致死时玩家死亡，流程中止** |
| 14 | 求生者中毒状态结算前 | `"中毒结算"` | trigger 节点 |
| 15 | 求生者中毒状态结算时 | `"中毒结算"` | trigger 节点 + `player.poison()`（玩家有中毒标记时受到等量伤害）。**中毒致死时玩家死亡，流程中止** |
| 16 | 面前怪物行动前 | `"怪物行动"` | trigger 节点 |
| 17 | 面前怪物行动时 | `"怪物行动"` | trigger 节点 + 玩家面前的怪物按进入求生者怪物区的顺序行动（先进入先行动），详见 [I_monsterAction.md](I_monsterAction.md)。**怪物攻击致死时玩家死亡，流程中止** |
| 18 | 回合结束前 | `"回合结束"` | trigger 节点（如 gunslinger「扣动扳机让我快乐」subSkill、MapBlocks 游乐园/警察局/城市街道） |
| 19 | 回合结束时 | `"回合结束"` | trigger 节点（如 MapBlocks 游乐园） |
| 20 | （退出玩家回合） | `"回合外"` | 非钩子节点。重置 `inPhase` |
| 21 | （胜利判定） | — | 非钩子节点。由 [GameStateMachine.checkWinCondition()](../GameSystem/Core/GameStateMachine.md#checkwincondition) 在 `开始回合()` 返回后执行。**注意：胜利条件只在玩家回合结束时检查（玩家依然会在回合结束前受到伤害）** |

> **死亡中断**：节点 7/13/15/17 后均检查 `player.isAlive()`，死亡则立即 return，后续节点不再执行。玩家死亡流程（`playerDeath`）由 draw / increaseHunger / poison / 怪物攻击流程内部触发，详见 [G_gameOver.md](G_gameOver.md)。
>
> **同生共死模式**：若开启 `game.同生共死模式`，任一玩家死亡即所有求生者输掉游戏（在 `playerDeath` 末尾全灭判定之前检查）。详见 [L_gameVariants.md](L_gameVariants.md)。

---

## 行动阶段

节点 9 行动阶段，玩家可执行 **4 个行动**（行动次数 = `最大行动次数`，通常为 4），可按任意组合执行以下行动，可多次执行同一行动：

### 普通行动（每个消耗 1 行动次数）

| 行动 | 说明 |
|------|------|
| 移动 | 横向或竖向移动 1 格（`player.moveTo(target)`，详见 [Player.moveTo](../GameSystem/Entities/Player.md#moveto)） |
| 抓牌 | 从求生者游戏牌堆抓 1 张牌（`player.draw(1)`，详见 [Player.draw](../GameSystem/Entities/Player.md#drawn)） |
| 出牌 | 从手牌中打出 1 张牌（`player.useCard(card)`，详见 [H_useCard.md](H_useCard.md)） |
| 执行已在场卡牌行动 | 执行 1 张已经在游戏中的卡牌上的行动（如装备牌的填充物消耗、武器开火等） |
| 拾荒 | 根据当前地块颜色抓 1 张拾荒卡（`player.drawScavenge(1, pile)`，详见 [Player.drawScavenge](../GameSystem/Entities/Player.md#drawscavengen-pile)） |

### 免费行动（不消耗行动次数，每回合各 1 次）

| 免费行动 | 说明 |
|---------|------|
| 制衡 | 每回合一次，弃掉 2 张求生者游戏牌，从求生者游戏牌堆抓 1 张新牌 |
| 交易 | 每回合一次，与另一名同地图块的玩家交易拾荒卡 |

### 行动次数与结束

- 行动次数耗尽（`player.行动次数 == 0`）时自动结束行动阶段
- 玩家可主动选择结束行动阶段（即使还有剩余行动次数）
- 实际由 UI 层驱动 `player.等待玩家行动()`，行动次数耗尽或玩家主动结束时返回

---

## 与其他文档的关系

| 主题 | 文档 |
|------|------|
| 玩家回合 21 节点源定义 | [Player.md §十 回合流程](../GameSystem/Entities/Player.md#十回合流程) |
| 状态机与回合队列 | [GameStateMachine.md](../GameSystem/Core/GameStateMachine.md) |
| 怪物出生检定 / 潜行检定 | [E_gameJudge.md](E_gameJudge.md) |
| 怪物行动细节 | [I_monsterAction.md](I_monsterAction.md) |
| 使用卡牌细节 | [H_useCard.md](H_useCard.md) |
| 游戏结束条件 | [G_gameOver.md](G_gameOver.md) |
| 事件流程汇总（trigger 名 + 节点） | [J_gameEventFlow.md §10 玩家回合流程](J_gameEventFlow.md#10-玩家回合流程) |
