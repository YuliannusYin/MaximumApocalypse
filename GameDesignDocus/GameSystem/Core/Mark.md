# Mark 实体标记

> 以 `src/core/mark.gd` 为准。运行时管理在 [Entity](./Entity.md) 上。
> 类名 `Mark`，继承 `RefCounted`。与地块「目标标记 / 怪物标记」不是同一概念：后者见 [MapBlock.md](../Entities/MapBlock.md)。

---

## 设计意图

实体（玩家、怪物、卡牌、地块）可挂命名标记，同时支持**计数**与**集合项**。UI 用 `mark_text` / `mark_content` / `visible` 渲染。参考无名杀 mark 系统。

Player 文档中的 `poison`、`hunger_damage_level`、`moved_this_turn` 等均为本结构，不再是「标记名 → int」的扁平字典。

---

## 字段

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `name` | String | `""` | 标识名（字典键） |
| `mark_text` | String | `""` | UI 显示文本；空则用 `name` |
| `mark_content` | String | `""` | tooltip |
| `visible` | bool | true | 是否在 UI 渲染 |
| `count` | int | 0 | 计数值 |
| `items` | Array | [] | 集合项 |

`get_display_text()`：`mark_text` 非空用其，否则用 `name`。

---

## Entity 上的管理接口

`Entity.marks` 为 `Dictionary[String, Mark]`。

| 方法 | 说明 |
|------|------|
| `add_mark(name, quantity=1, mark_text="", mark_content="", visible=true)` | 不存在则创建；存在则累加 count，非空文案覆盖 |
| `remove_mark(name)` | 删除该 mark |
| `count_mark(name) -> int` | 不存在返回 0 |
| `has_mark(name) -> bool` | 是否存在 |
| `get_mark(name) -> Mark` | 不存在返回 null |
| `add_mark_item` / `remove_mark_item` / `get_mark_items` | 集合项 |
| `clear_mark_count` / `clear_mark_items` | 清零计数或清空集合，不删除 mark |
| `add_mark_skill(name, n=1, expire_trigger="", ...)` | `add_mark` 后挂内部 Skill，在 `expire_trigger` 触发时移除 mark 与该 Skill |
| `has_mark_skill(name)` | 等价 `has_mark` |

变更时发射 EventBus：`mark_added` / `mark_changed` / `mark_removed`。[GameActions](EventScheduler.md) 提供 `add_mark` / `add_mark_skill` 门面，经调度器入栈。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](./Entity.md) | 持有 `marks` 字典 |
| [Player](../Entities/Player.md) | 饥饿、中毒、本回合已移动等 |
| [EventBus](../System/EventBus.md) | UI 订阅 mark 信号 |
| [MapBlock](../Entities/MapBlock.md) | 目标标记 / 怪物标记是地块字段，不是本类 |
