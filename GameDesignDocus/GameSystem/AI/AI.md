# 合作 AI

> 职责：用输入替换实现电脑座位，不另开规则通道。决策为无名杀式贪心打分（枚举合法选项取最高分），不做博弈树搜索。
> 代码：`MxApoc_GDScript/src/ai/`。
> 本游戏为全合作 PvE，不猜身份、不复制无名杀 GPL 源码。

---

## 一、架构

引擎照常 `await player.input.*`。真人座位用 `GUIPlayerInput`（热座共享一份，走 `EventScheduler` 输入栈）；AI 座位用 `AIPlayerInput`，**直接返回值**，不入 GUI 的 InputRequest 栈。

```
Player.wait_player_action
  → player.input
      ├─ human：GUIPlayerInput
      └─ ai：AIPlayerInput
            ├─ LegalActions.enumerate
            ├─ AiScorer（JSON ai + 局势 + 任务提示）
            └─ play_*_animation → 委托共享 GUIPlayerInput（供旁观）
```

座位 0 锁定真人（房间 `SeatItem`）。`Game.initialize_game` 只跳过 `type == "empty"`；`type == "ai"` 创建 `Player` 并设 `is_ai = true`。测试默认仍是 `CliPlayerInput`（`Player._init`）。对局场景里 `GameScene2D` 再按 `is_ai` 分配：真人共用 `_gui_input`，AI 新建 `AIPlayerInput`（`animation_input = _gui_input`，`think_seconds = 0.4`）。

任务行动走技能栏 `type: "skill"`，不走已废弃的 `mission_action` 通道。结束回合：`wait_action` 返回 `null`。

---

## 二、模块

| 文件 | 类名 | 说明 |
|------|------|------|
| `legal_actions.gd` | `LegalActions` | 从规则层枚举行动阶段可选项（手牌 / 主动技能含任务金色技能 / 相邻移动 / 抓牌） |
| `ai_scorer.gd` | `AiScorer` | `attitude` / `order` / `useful` / `effect` / `score_action` |
| `ai_mission_hints.gd` | `AiMissionHints` | 从任务组件 `params` 推导目标地块与应留物资族 |
| `ai_player_input.gd` | `AIPlayerInput` | 实现全部 `IPlayerInput` |

`LegalActions.enumerate` 对齐规则，不抄 HUD：

- 手牌：`player.is_card_usable`
- 技能：`player.can_use_active_skill`
- 移动：有效行动点 > 0 时当前地块相邻格
- 抓牌：有效行动点 > 0 且牌堆非空（`game_deck` / 红绿蓝拾荒）

`AIPlayerInput` 决策对齐 `CliPlayerInput`。`think_seconds` 默认 `0`（测试不卡）；场景里设 `0.4`。同一行动指纹连续 3 次则结束回合，避免零消耗死循环。

---

## 三、JSON `ai` 字段

玩家侧每张卡、每个技能（含被动、子技能）必须带 `ai`，与 `content` 同级。缺 `order` / `useful` 的数据在 `test_ai_data_complete` 中失败。

```json
"ai": {
  "order": 8,
  "useful": 5,
  "tags": ["damage", "weapon"],
  "effect": { "player": 0, "target": 2 }
}
```

| 字段 | 含义 |
|------|------|
| `order` | 与其它合法行动比「先打哪张」。越大越优先。无主动使用的被动技能写 `0` |
| `useful` | 留牌价值（弃牌 / 选牌时越高越留）。任务物资给高 useful |
| `tags` | 供局势加成。见下表 |
| `effect.player` / `effect.target` | 无名杀 `result.player/target` 的数值版 |

可选覆盖（少数复杂牌才写，走 `CodeExecutor.compile_score`，签名 `(player, target, event, game) -> float`）：

- `result`：覆盖对该目标的效果分（写入 `Skill.ai_result`）
- `check`：覆盖选牌 / 选目标时的单项分（写入 `Skill.ai_check`）

**不补怪物包 JSON**：怪物技能由引擎强制结算。怪物造成的「请玩家选牌 / 确认」走卡牌 `useful` 与通用 confirm 启发式。

**任务行动**：任务 JSON 不写技能。各行动组件 `get_action_skill_decl()` 带 `ai`，`MissionConfig.mount_action_skills` 拷到 `Skill.ai`。默认 `order: 12, tags: ["mission"]`。

### 3.1 tags

`damage` `heal` `food` `fuel` `ammo` `equip` `move` `draw` `stealth` `mission` `aoe` `weapon`

### 3.2 order 档位

| order | 用途 |
|------|------|
| 12 | 当前可执行的任务行动（加油 / 提交 / 解救 / 拆弹等） |
| 9 | 攻击（武器技能、拳打） |
| 8 | 装备武器 / 关键防具 |
| 7 | 装填弹药 / 燃料 |
| 6 | 治疗 |
| 5 | 食物（饥饿将满时由评分器再加分） |
| 4 | 制衡等过牌 |
| 3 | 装备非武器 |
| 0 | 被动 / 不主动用 |

### 3.3 effect 符号约定

JSON 里 `effect.target` 对 `damage` / `heal` 写**正数幅度**。评分器按 tags + `attitude` 决定正负：

- `damage`：最终分 ≈ `effect.player + (-attitude(target)) * |effect.target|` + 威胁；打怪物为正，打队友 / 自己为负
- `heal`：最终分 ≈ `effect.player + attitude(target) * |effect.target|` + 低血加成
- 其它：`effect.player + attitude(target) * effect.target`

卡级 `order == 0` 时，出牌评分回退到该牌主动技能的 `order`。

---

## 四、态度

合作 PvE，态度固定，不随身份变化：

| 关系 | 值 |
|------|-----|
| 自己 | `2.0`（`AiScorer.ATT_SELF`） |
| 其他求生者 | `1.5`（`ATT_ALLY`） |
| 怪物 | `-2.0`（`ATT_ENEMY`） |
| 其它 / null | `0` |

---

## 五、任务意识

不写死 13 个剧本。`AiMissionHints` 读 `Game.mission_config` 各组件 `params.block_name` / `card_name` / `items`：

- 目标地块：走向最近目标；地块有怪则清怪优先于走开
- 物资族：与现有「名（变体）」规则一致（`matches_item_family`）；匹配则 `useful + 6`，避免制衡 / 弃牌丢掉燃料
- 任务技能 filter 已通过时，order 至少 12 再加完成进度分
- 有纠缠怪物时降低「走开」的移动分

---

## 六、输入约定

`wait_action` 返回值与 `Player.dispatch_player_action` 一致：

```
{"type": "move"|"card"|"skill"|"pile_draw", "target"|"card"|"skill"|"pile_key": ...}
```

结束回合返回 `null`（不是空 Dictionary）。最高分 ≤ 0 也返回 `null`。

其它方法：

- `choose_target` / `choose_card` / `choose` / `choose_map_block` / `choose_block_inline`：对候选项打分；强制选择取最高；可取消且最高分 ≤ 0 则空 / 取消。prompt 含「弃」时选低 useful
- `confirm` / `wait_judge_confirm`：默认确认（潜行检定：有怪标记或仍有行动点则确认）
- `wait_redraw_decision`：手牌平均 useful < 4 才重调
- `play_*_animation`：有 `animation_input` 则委托 GUI
