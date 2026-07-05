# API 契约速查 (docs/API_CONTRACTS.md)

设计中已定义方法的签名、关键约束与当前实现状态。完整规则定义见 `GameDesignDocus/` 对应文档。

---

## 已实现

以下方法已在 `scripts/system/` 中实现,签名与契约一致,且已通过 GUT 单元测试。

| 方法签名 | 定义位置 | 关键约束 | 实现位置 |
|---------|---------|---------|---------|
| `entity.trigger(trigger_name: String, event: Event) -> void` | GameSystem/EventTrigger.md | 遍历技能,依次触发匹配 trigger_name 的;cancel 后中断 | entity.gd |
| `target.damage(num: int, source: Variant = null, type: String = "") -> void` | GameSystem/DamageFlow.md | 含 8 节点钩子链;source=null 时跳过 source 侧 trigger | entity.gd |
| `player.recover(num: int) -> void` | GameSystem/PlayerState.md | 受最大值约束;4 节点钩子:回复生命前/时/系统加血/后 | player.gd |
| `player.increaseHunger(num: int) -> void` | GameSystem/PlayerState.md | 逐点结算;到 6 翻面+加饥饿伤害标记;按等级造成无来源伤害 | player.gd |
| `player.decreaseHunger(num: int) -> bool` | GameSystem/PlayerState.md | 最低降至 1;清除饥饿伤害标记并翻回;返回是否成功减少 | player.gd |
| `player.poison() -> void` | GameSystem/PlayerState.md | 按 poison 标记层数造成无来源伤害 | player.gd |
| `player.judge() -> int` | GameSystem/Judge.md | 投两颗大骰子返回点数和(2-12) | player.gd |
| `player.sneakJudge() -> bool` | GameSystem/Judge.md | 结果 <= 潜行值(减地块怪物数+标记数)则成功 | player.gd |
| `player.monsterSpawnJudge(revealed_blocks: Array[MapBlock] = []) -> void` | GameSystem/Judge.md | 投骰子匹配已展示地图块执行出生逻辑 | player.gd |

---

## 已定义但仅 Stub

以下方法已在 `GameDesignDocus/已定义方法.md` 中定义契约,但当前实现为空/stub。

| 方法签名 | 定义位置 | 当前状态 |
|---------|---------|---------|
| `target.playerDeath(source: Variant) -> void` | GameSystem/DeathFlow.md | stub:仅 push_warning |
| `target.monsterDeath(source: Variant) -> void` | GameSystem/DeathFlow.md | 未实现 |
| `player.moveTo(target) -> void` | GameSystem/Movement.md | 未实现 |
| `player.draw(n: int) -> void` | GameSystem/DrawFlow.md | 未实现 |
| `player.drawScavenge(n: int, pile) -> void` | GameSystem/DrawFlow.md | 未实现 |
| `player.drawMonster(num: int) -> void` | GameSystem/DrawFlow.md | stub:仅 push_warning |
| `player.discard(target, position=NULL, quantity=1, type=NULL) -> void` | GameSystem/DiscardFlow.md | 未实现 |
| `player.removeCard(target, position=NULL, quantity=1) -> void` | GameSystem/DiscardFlow.md | 未实现 |

---

## 辅助原子方法(非已定义方法契约,但被已定义方法内部调用)

| 方法签名 | 所在文件 | 说明 |
|---------|---------|------|
| `add_hp(num: int) -> void` | player.gd | 直接加血,不触发钩子,不受上限约束。与 recover 区别见待定义方法.md §9.6 |
| `add_hunger(num: int) -> void` | player.gd | 直接加饥饿值,不走 increaseHunger 流程 |
| `reduce_hunger(num: int) -> void` | player.gd | 直接减饥饿值,不走 decreaseHunger 流程。最低降至 1 |
| `add_sneak(num: int) -> void` | player.gd | 增加潜行值 |
| `reduce_sneak(num: int) -> void` | player.gd | 减少潜行值(可为负) |
| `addMarkSkill(mark_name: String, quantity: int = 1) -> void` | player.gd | 添加标记 |
| `removeMarkSkill(mark_name: String) -> void` | player.gd | 移除标记(清零) |
| `countMark(mark_name: String) -> int` | player.gd | 获取标记层数 |
| `hasMarkSkill(mark_name: String) -> bool` | player.gd | 是否有指定标记 |
