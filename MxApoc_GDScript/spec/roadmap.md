# 自底向上实施路线图

> 把 `GameDesignDocus/` 中的桌游规则翻译为 GDScript 系统,从最底层基础设施开始,小步快跑,每轮 1-2 个已定义方法或 1 个实体类,每轮用 GUT 单元测试验收。
>
> 配套文档:[验收方法与标准](verification.md) | [AGENTS.md](../AGENTS.md) | [已定义方法](../GameDesignDocus/已定义方法.md)

---

## 1. 总体策略

- **方向**: 自底向上。先搭事件系统与实体骨架,再实现核心流程,最后拼 GameScene。
- **粒度**: 每轮 1-2 个已定义方法或 1 个实体类。单轮工作量可控,反馈频繁。
- **验证**: 每轮配套 GUT 单元测试,验收通过才进入下一轮。
- **规则对齐**: 实现前必读对应 `GameSystem/` 文档;实现后把条目从 `待定义方法.md` 迁移到 `已定义方法.md`。
- **不写 GameScene**: 本路线图 5 轮内不触碰 GameScene,GameScene 仍是占位。等 5 轮完成后再讨论上层主循环。

---

## 2. 依赖分析

```
EventTrigger ─┬─→ DamageFlow ──→ PlayerState(increaseHunger/poison)
              │                  ↑
              └─→ Player 实体 ──┘
                    │
                    └─→ Judge(sneakJudge/monsterSpawnJudge 需地图块 stub)
```

关键约束:
- `PlayerState.increaseHunger` 与 `poison` 内部调用 `player.damage(...)`,所以 **DamageFlow 必须先于 PlayerState**。
- `Judge.sneakJudge` 依赖 `countMonster(mapBlock)` / `countMonsterMark(mapBlock)`(待定义全局函数),本轮用 stub 地图块。
- `Judge.monsterSpawnJudge` 依赖 `player.drawMonster(1)`(已定义但未实现),本轮 stub。

---

## 3. 轮次概览

| 轮次 | 范围 | 已定义方法 | 前置依赖 | 验收要点 |
|------|------|-----------|---------|---------|
| [01](iteration_01_event_trigger.md) | EventTrigger 系统:Skill 资源、Event 对象、Entity 基类、`entity.trigger` | `entity.trigger(triggerName, event)` | 无 | 触发链顺序、filter 过滤、`event.cancel()` 中断、复合 trigger(、分隔) |
| [02](iteration_02_player_entity.md) | Player 实体骨架:HP/饥饿/潜行属性、标记系统、角色卡牌、基础数值方法 | (基础方法,非已定义) | 01 | 属性读写、标记增删查、角色卡翻面、数值边界 |
| [03](iteration_03_damage_flow.md) | DamageFlow:8 节点钩子链、source=NULL 处理、死亡判定入口 stub | `target.damage(num, source, type=NULL)` | 01, 02 | 8 节点顺序、source=NULL 跳过 source 侧、`event.cancel()` 取消、num 修改、死亡触发 |
| [04](iteration_04_player_state.md) | PlayerState:recover、increaseHunger、decreaseHunger、poison | `recover`、`increaseHunger`、`decreaseHunger`、`poison` | 01, 02, 03 | recover 上限、饥饿翻面、饥饿伤害等级 1-5、poison 无来源伤害 |
| [05](iteration_05_judge.md) | Judge:judge、sneakJudge、monsterSpawnJudge | `judge`、`sneakJudge`、`monsterSpawnJudge` | 02(地图块 stub) | 骰子随机性、潜行值计算、出生检定地图块匹配 |

---

## 4. 本路线图之外(后续轮次,暂不细化)

按依赖顺序,5 轮之后可能的方向:
- **DeathFlow**(playerDeath/monsterDeath):依赖 DamageFlow。
- **DrawFlow**(draw/drawScavenge/drawMonster):依赖 EventTrigger,与 DamageFlow 平级。
- **Movement**(moveTo):依赖 EventTrigger + MapBlock 实体。
- **DiscardFlow**(discard/removeCard):依赖 EventTrigger + Card 实体。
- **MapBlock 实体**:依赖 Entity 基类。
- **Card 实体**:依赖 Entity 基类。
- **Monster 实体**:依赖 Entity 基类。
- **数据层补全**:怪物包/拾荒卡/地图块/求生者游戏牌堆,可与上述并行。
- **GameScene 主循环**:依赖上述大部分模块。

这些在当前 5 轮完成后再规划。

---

## 5. 不做的事

- **不重构现有 UI 代码**(main_menu/game_room/game_scene/seat_item/settings_dialog)。
- **不补全数据层**(怪物/拾荒卡/地图块),除非某轮的 stub 影响验收。
- **不实现 GameScene 真实逻辑**,GameScene 仍只显示 `RoomState.snapshot()`。
- **不实现待定义方法**(如 `player.add_hp`、`player.equip` 等),除非本轮范围明确包含。
- **不解决 §9.x 歧义**,除非本轮实现受阻。受阻时按 AGENTS.md §3.3 登记/询问。

---

## 6. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| Skill 资源结构设计 docs 未明确定义 | 01 轮需自行设计结构 | 在 iteration_01 文档中提出方案,若用户有意见再调整 |
| 标记系统(mark skill)结构未定义 | 02 轮需设计 | 同上 |
| 角色卡牌翻面机制未定义 | 02 轮需设计 | 同上 |
| DamageFlow 死亡判定调用未实现的 playerDeath/monsterDeath | 03 轮需 stub | stub 为空函数 + 日志,登记到待定义方法.md |
| Judge.monsterSpawnJudge 依赖未实现的 drawMonster | 05 轮需 stub | 同上 |
| GUT 框架未安装 | 验收无法运行 | 01 轮前置:在 project.godot 中配置 GUT |

---

## 7. 状态跟踪

每轮开始时,在对应 `iteration_XX_*.md` 文档顶部更新状态标记:
- `[ ] 未开始` / `[~] 进行中` / `[x] 已完成`

完成后在本表第 1 列加 ✅。
