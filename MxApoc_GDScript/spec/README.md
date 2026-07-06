# Spec:实施计划文档

> 自底向上、小步快跑地把 `GameDesignDocus/` 桌游规则翻译为 GDScript 代码。
>
> 本目录存放实施计划与验收标准,**不含代码**。代码产出在 `scripts/system/`,测试在 `tests/unit/`。

---

## 阅读顺序

1. [roadmap.md](roadmap.md) —— 总体路线图(5 轮概览、依赖分析、风险)
2. [verification.md](verification.md) —— 验收方法与标准(GUT 框架、测试要求)
3. iteration_01 ~ iteration_05 —— 各轮详细计划

---

## 文档清单

| 文档 | 状态 | 范围 |
|------|------|------|
| [roadmap.md](roadmap.md) | ✅ 已完成 | 5 轮路线图、依赖、风险 |
| [verification.md](verification.md) | ✅ 已完成 | GUT 验收方法、测试用例要求 |
| [iteration_01_event_trigger.md](iteration_01_event_trigger.md) | `[x] 已完成` | EventTrigger 系统:Skill/Event/Entity/`entity.trigger` |
| [iteration_02_player_entity.md](iteration_02_player_entity.md) | `[x] 已完成` | Player 实体骨架:HP/饥饿/潜行/标记/角色卡牌 |
| [iteration_03_damage_flow.md](iteration_03_damage_flow.md) | `[x] 已完成` | DamageFlow:`target.damage` 8 节点钩子链 |
| [iteration_04_player_state.md](iteration_04_player_state.md) | `[x] 已完成` | PlayerState:recover/increaseHunger/decreaseHunger/poison |
| [iteration_05_judge.md](iteration_05_judge.md) | `[x] 已完成` | Judge:judge/sneakJudge/monsterSpawnJudge + MapBlock stub |
| [iteration_06_card.md](iteration_06_card.md) | `[ ] 未开始` | Card 实体 + DrawFlow + DiscardFlow:CardData/Card 双层类 + Pile + Game 骨架 + 5 个已定义方法真实逻辑 |

---

## 轮次依赖图

```
01 EventTrigger ─┬─→ 02 Player 实体 ─┬─→ 03 DamageFlow ──→ 04 PlayerState
                  │                    │
                  └────────────────────┴─→ 05 Judge(地图块 stub)
                                          │
                                          └─→ 06 Card + DrawFlow + DiscardFlow(Card/Pile/Game + 5 个已定义方法)
```

每轮前置依赖见各 iteration 文档 §2。

---

## 待用户确认的决策点

以下决策在各 iteration 文档中提出,动笔前需用户确认:

### iteration_01
- Skill 结构(filter/content 用 Callable)是否够灵活 ✅ 已确认
- Event.source/target 用 Variant 是否可接受 ✅ 已确认
- GUT 是否为偏好的测试框架 ✅ 已确认

### iteration_02
- §9.6:`add_hp` 不触发钩子、不受上限约束,`recover` 走完整流程 ✅ 已确认
- §9.7:`add_hunger`/`reduce_hunger` 仅数值变更,`increaseHunger`/`decreaseHunger` 走完整流程 ✅ 已确认
- §9.10:本轮不实现 `addMark`,只用 `addMarkSkill` ✅ 已确认
- 标记系统不支持 `Until` 参数(后续轮次补) ✅ 已确认

### iteration_03
- `is_player` vs `isPlayer` 命名(设计文档用 camelCase,本轮提议 snake_case) ✅ 已确认
- playerDeath/monsterDeath 为 stub 是否可接受 ✅ 已确认

### iteration_04
- recover 触发 4 节点钩子链(回复生命前/时/系统加血/后) ✅ 已确认并补全设计文档(J_gameEventFlow.md §16 新增,PlayerState.md 伪代码更新,§9.6 已解决)
- increaseHunger 中玩家死亡后是否继续结算(本轮 stub 不中断)
- decreaseHunger 返回 bool ✅ 已确认

### iteration_05
- "大骰子"点数范围(本轮假设 1-6 标准骰子)
- countMonster/countMonsterMark 改为 MapBlock 方法(设计文档用全局函数)
- monsterSpawnJudge 接受 revealed_blocks 参数(设计文档无参)
- sneakJudge 仅返回 bool,不实现失败分支(失败分支由调用方处理)

### iteration_06
- 本轮范围:Card + DrawFlow + DiscardFlow(一次性大轮次)✅ 已确认
- 类结构:Card + CardData 双层(都有子类)✅ 已确认
- 数据层:不落地,代码内联 ✅ 已确认
- §9.14 `card.在玩家装备区内`:本轮不解决(stub)✅ 已确认
- 拾荒弃牌堆:不分色单一堆(修订 DiscardFlow.md)✅ 已确认
- game 对象:新建最小骨架(持有全局牌堆)✅ 已确认
- 装备区/怪物区:Array[Card](非 Pile)✅ 已确认
- §4.1 类层级(Card→ItemCard→ScavengeCard/SurvivorGameCard;Card→MonsterCard)⏳ 待确认
- §4.2 API 命名(get_*/add_filler/refill_filler 等英文译名)⏳ 待确认
- §4.4 Pile 接口设计 ⏳ 待确认
- §4.5 Game 对象接口设计 ⏳ 待确认
- §4.6 Player 卡牌区域与 getCards 搜索范围 ⏳ 待确认

---

## 状态约定

- `[ ] 未开始` —— 计划已写,未动笔
- `[~] 进行中` —— 正在实现
- `[x] 已完成` —— 实现完成,验收通过

每轮开始时在对应文档顶部更新状态标记。

---

## 相关文档

- [AGENTS.md](../AGENTS.md) —— AI Agent 项目说明书(行为约束、编码规范)
- [GameDesignDocus/已定义方法.md](../GameDesignDocus/已定义方法.md) —— 已定义方法契约清单
- [GameDesignDocus/待定义方法.md](../GameDesignDocus/待定义方法.md) —— 待定义方法与 §9.x 歧义
