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

任意座位均可设为真人或 AI（房间 `SeatItem`）。`Game.initialize_game` 只跳过 `type == "empty"`；`type == "ai"` 创建 `Player` 并设 `is_ai = true`。测试默认仍是 `CliPlayerInput`（`Player._init`）。对局场景里 `GameScene2D` 再按 `is_ai` 分配：真人共用 `_gui_input`，AI 新建 `AIPlayerInput`（`animation_input = _gui_input`，`think_seconds = 0.4`）。

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

- 手牌：`player.is_card_usable`；伤害牌在合法目标只剩求生者时不枚举；`target_type == equipment` 的伤害牌（如集中射击）还要求射程内有怪物，否则不枚举
- 技能：`player.can_use_active_skill`；伤害技能同样跳过「只能打人」；`reveal`（望远镜）在射程内没有未展示格时不枚举
- 移动：有效行动点 > 0 且 **怪物区为空** 时当前地块相邻格（有纠缠怪物不主动走）；只给**严格靠近**行进目标的邻格正分。远近用 `path_distance_to`（沿邻格 BFS），不是曼哈顿，否则任务 0 在 (2,1) 东侧空洞处所有邻格都会被判成更远而原地抽牌
- 抓牌：有效行动点 > 0 且牌堆非空；拾荒只枚举 **当前地块 `scavenge_colors`**（与 GUI 一致）
- 迷你回合白名单：`enumerate` 问 `player.is_action_type_allowed`（与 GUI 一致）。注射类固醇是 `["card"]`，只出手牌；肾上腺素 / 战术领导力空白名单不限制。评分器预览支援目标时可通过第二参数 `allowed_types` 覆盖（类固醇 `grant_types: ["card"]`）

`AIPlayerInput` 决策对齐 `CliPlayerInput`。`think_seconds` 默认 `0`（测试不卡）；场景里设 `0.4`。同一行动指纹连续 3 次则**跳过该选项再选次优**，不直接结束回合。卡牌空放（打出后仍在手）与展示类技能空放（行动点未变）本回合拉黑该指纹。`choose_block_inline`：最高分 ≤ 0 或格子不比当前更靠近行进目标则返回空（耐力 / 摩托车后续步停走）。

---

## 三、JSON `ai` 字段

玩家侧每张卡、每个技能（含被动、子技能）必须带 `ai`，与 `content` 同级。缺 `order` / `useful` 的数据在 `test_ai_data_complete` 中失败。

```json
"ai": {
  "order": 8,
  "useful": 80,
  "tags": ["damage", "weapon"],
  "effect": { "player": 0, "target": 2 },
  "grant_types": ["card"]
}
```

| 字段 | 含义 |
|------|------|
| `order` | 与其它合法行动比「先打哪张」。越大越优先。无主动使用的被动技能写 `0` |
| `useful` | 留牌价值 ∈ **[0, 100]**（弃牌 / 选牌时越高越留）。技能可写 `0` |
| `tags` | 供局势加成。见下表 |
| `effect.player` / `effect.target` | 无名杀 `result.player/target` 的数值版 |
| `grant_types` | 可选。仅 `grant_action` 使用：预览受援者合法行动时的类型白名单（如类固醇 `["card"]`）。省略则看全部类型 |

建议刻度：任务关键物 85–95；主力武器 / 关键装备 70–85；一般行动 50–70；弱牌 20–45；垃圾 0–20。

可选覆盖（少数复杂牌才写，走 `CodeExecutor.compile_score`，签名 `(player, target, event, game) -> float`）：

- `result`：覆盖对该目标的效果分（写入 `Skill.ai_result`）
- `check`：覆盖选牌 / 选目标时的单项分（写入 `Skill.ai_check`）

**怪物包 JSON** 每张怪物卡写 `"ai": { "threat": N }`（0–100）。默认公式：`clamp(等级基数 + max_hp + attack_damage * 2, 0, 100)`，基数 boss 55 / elite 35 / normal 15。`MonsterCard.instantiate` 拷到 `Monster.ai_threat`。伤害选目标：`score = threat + (预估伤害 ≥ hp ? 50 : 0) + 己方怪物区 +40`；先清自己回合结束会挨打的怪。

**地图块技能** 可另写 `"hazard": N`（旷野等高值）。`score_block` 减去该值，并按怪物标记数 × 2.5 惩罚，避免为抄近路走进回合结束抓怪的格子。

**任务行动**：任务 JSON 不写技能。各行动组件 `get_action_skill_decl()` 带 `ai`，`MissionConfig.mount_action_skills` 拷到 `Skill.ai`。默认 `order: 12, tags: ["mission"]`。

### 3.1 tags

`damage` `heal` `food` `fuel` `ammo` `equip` `move` `draw` `stealth` `mission` `aoe` `weapon` `reveal` `grant_action` `hunger_ap` `pull` `skip_hunger`

### 3.2 order 档位

| order | 用途 |
|------|------|
| 12 | 当前可执行的任务行动（加油 / 提交 / 解救 / 拆弹等） |
| 9 | 攻击（武器技能、拳打） |
| 8 | 装备武器 / 关键防具 |
| 7 | 装填弹药 / 燃料 |
| 6 | 治疗 |
| 5 | 食物（饥饿由评分器按**目标**再加分） |
| 4 | 对讲机 / 战术领导力（实际分看队友最佳着） |
| 3 | 制衡、非武器装备、望远镜、侦察 |
| 2 | 野地夹克等「加饥饿换行动」；伪装（逃生） |
| 1 | 轮床（默认不当主动着，仅拉近确实更接近行进目标时才有正分） |
| 0 | 被动 / 不主动用 |

### 3.3 effect 符号约定

JSON 里 `effect.target` 对 `damage` / `heal` 写**正数幅度**。评分器按 tags + `attitude` 决定正负：

- `damage`：最终分 ≈ `effect.player + (-attitude(target)) * |effect.target|` + 威胁；打怪物为正，打队友 / 自己为负
- `heal`：目标满血则 0；否则由缺血比主导（不含 order），避免满血缝合压过移动 / 拾荒
- `food`：按**目标**饥饿计分（≤1 为 0；≥3 / ≥5 两档）；使用者饥饿不低于目标时优先自己。饥饿 ≥ 5 或已有饥饿伤害标记时再抬一档
- `grant_action`：目标分 = 该玩家（含自己）当前最高合法行动分（只看一层）；`grant_types` 存在时只预览这些类型；无人有正分实着、或最佳着只是抽游戏牌 / 再支援则整张 ≤ 0
- `pull`（轮床）：默认 0；仅当目标未纠缠、距其行进目标 ≥ 2、且拉向自己会更接近该目标时给小正分
- `skip_hunger`（能量饮料）：仅在饥饿 ≥ 5 且手里没食物时为正；不当抽牌用
- 其它：`effect.player + attitude(target) * effect.target`

卡级 `order == 0` 时，出牌评分回退到该牌主动技能的 `order`。

装备栏按 **size 占用** 判断是否挤装；非武器且会超栏时重罚。溢出时若按 useful 从低到高丢掉的牌包含任务物资，**没战时该装备行动 ≤ 0**；**纠缠中允许丢物资换武器**。有纠缠怪物且当前没有可用的已装备武器攻击（`weapon`+`damage` 且 filter 通过；拳打无 `weapon` 不算）时，手里的武器装备加局势分，压过徒手攻击，先花 1 点装上再打。已有可用斧 / 打火机 / 猎枪时不加这项，优先挥已装备武器。**有效行动点 ≤ 1 时不加这项**，最后 1 点出伤害而不是换装。已装备同名武器再装同名 ≤ 0（打断维修→炮塔环）。`加油` 在任务仍缺该物资族时降权（允许给载具加，但不抢交任务）。自制子弹 / 阅读使用说明等以装备为目标时，任务物资给 -99。制衡按即将丢掉的两张 useful 计分；丢掉武器 / 治疗 / 食物 / 任务物时再扣。非任务需求且 useful 虚高的道具（如多余配件）在留牌时封顶，避免压过食物。伪装不按 `damage` 计；有可用已装备武器、或徒手能打死时不用。

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

不写死 13 个剧本。`AiMissionHints` 读行动组件 `ai_should_travel` 与胜利条件地名（物资族仍读 `params.card_name` / `items`）：

- 行进目标第一层：未完成且该玩家去了能做的行动点（物资类须已持有对应物品；无 `block_name` 的摧毁标记 / 解救检定则收集场上目标标记地块）。这一层非空则只用这一层
- 第二层（采集）：行动层为空且全队持有+已提交仍少于 `params.count` / `items` 时，走向拾荒牌堆里 **还剩该物资族** 的地块；同色剩余越多越优先（不写死加油站）
- 否则退回未完成的胜利条件地名：`all_players_at_block` 集结；`escort_equipment_at_block` **仅当该玩家装备着被护送卡**。不扫 lose / trigger 的 `block_name`
- 走向最近行进目标（图距离，绕空洞）；已在目标格则主动移动分 ≤ 0。采集格上且该色堆仍有目标物资时抬高拾荒分、压低非武器装备。不搜路径树：一步贪心沿递减的 BFS 距离即最短路
- **信使**：手牌或装备区持有尚未提交满额的任务物资时，移动再加约 +8，抽牌 / 侦察 / 维修 / 非武器装备约 -8，优先去交付而不是继续采
- 物资族：与现有「名（变体）」规则一致（`matches_item_family`）；匹配则 `useful + 15`（封顶 100），避免制衡 / 弃牌丢掉燃料。装备栏超限弃置时，有非任务候选则不丢任务物资
- 任务技能 filter 已通过时，order 至少 12 再加完成进度分
- 有纠缠怪物时不枚举主动移动
- 食物：饥饿 ≥ 3 即加分，≥ 5 再加一档；看目标不看使用者。饥饿 ≥ 5 时抽游戏牌 ≤ 0，含食物的拾荒堆加分
- 任务仍缺燃料时 `加油` 降权，不禁止

---

## 六、输入约定

`wait_action` 返回值与 `Player.dispatch_player_action` 一致：

```
{"type": "move"|"card"|"skill"|"pile_draw", "target"|"card"|"skill"|"pile_key": ...}
```

结束回合返回 `null`（不是空 Dictionary）。最高分 ≤ 0 也返回 `null`。

其它方法：

- `choose_target` / `choose_card` / `choose` / `choose_map_block` / `choose_block_inline`：对候选项打分；强制选择取最高；可取消且最高分 ≤ 0 则空 / 取消。prompt 含「弃」或「制衡」时选低 useful；「装备栏超限」有非任务候选时不丢任务物资；「维修 / 神通广大」回收时已装备同名降权。伤害类 `choose_target` 跳过其他求生者（列表只剩玩家时才从中选）；`grant_action` 选「最佳行动分」最高的玩家（含自己，类固醇按 `grant_types` 只看手牌）；装备目标若是仍缺的任务物资则 -99。多步移动 `choose_block_inline` 在已在目标格或无法更近时返回空
- `confirm` / `wait_judge_confirm`：默认确认（潜行检定：有怪标记或仍有行动点则确认）
- `wait_redraw_decision`：手里已有 `weapon` 牌则停止；否则重调。本局最多 20 次，避免牌库没有武器时卡死开局。已装备的武器不计入（枪手开局柯尔特不算「手里有武器」）
- `play_*_animation`：有 `animation_input` 则委托 GUI
