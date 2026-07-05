# 系统层类 (scripts/system/)

本目录记录项目 `scripts/system/` 下已实现的类及其公有 API。

---

## Entity

- **文件**: `scripts/system/entity.gd`
- **类声明**: `class_name Entity extends RefCounted`
- **职责**: 所有实体（玩家、怪物）的基类，提供技能挂载、事件触发、伤害流程。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_skills` | `Array[Skill]` | 该实体上所有技能 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `get_all_skills() -> Array[Skill]` | 返回所有技能。子类可重写以聚合多来源。 |
| `add_skill(skill: Skill) -> void` | 添加技能。 |
| `remove_skill(skill: Skill) -> void` | 移除技能。 |
| `trigger(trigger_name: String, event: Event) -> void` | 遍历技能，依次触发匹配 `trigger_name` 的。规则见 GameSystem/EventTrigger.md。 |
| `damage(num: int, source: Variant = null, type: String = "") -> void` | 造成 `num` 点伤害。含 8 节点钩子链。`source=null` 时跳过 source 侧钩子。规则见 GameSystem/DamageFlow.md。 |
| `get_hp() -> int` | 当前生命值。子类必须重写。 |
| `reduce_hp(num: int) -> void` | 直接扣血。子类必须重写。 |
| `is_player() -> bool` | 是否为玩家。子类重写。默认 `false`。 |
| `is_monster() -> bool` | 是否为怪物。子类重写。默认 `false`。 |

### 私有方法

| 方法签名 | 说明 |
|----------|------|
| `_run_filter(skill: Skill, event: Event) -> bool` | 执行技能 filter，无 callable 时返回 true。 |
| `_run_content(skill: Skill, event: Event) -> void` | 执行技能 content。 |
| `_on_death(source: Variant) -> void` | 死亡流程入口，子类重写为 `playerDeath`/`monsterDeath`。当前 stub：空实现 + 警告日志。 |

---

## Player

- **文件**: `scripts/system/player.gd`
- **类声明**: `class_name Player extends Entity`
- **职责**: 玩家实体，包含生命值、饥饿值、潜行值、角色卡、标记、骰子检定等。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `name` | `String` | 玩家名字（玩家可见文本）。默认 `""`。 |
| `_max_hp` | `int` | 最大生命值。默认 `6`。 |
| `_hp` | `int` | 当前生命值。默认 `6`。 |
| `_hunger` | `int` | 当前饥饿值（1~6）。默认 `1`。 |
| `_sneak_value` | `int` | 潜行值。默认 `0`。 |
| `_role_card` | `RoleCard` | 角色卡。默认 `RoleCard.new()`。 |
| `_marks` | `Dictionary` | 标记字典。键为标记名，值为层数。 |
| `_current_block` | `Variant` | 当前所在地图块。`null` 表示未在地图上。 |
| `_dice_roller` | `Callable` | 注入的骰子 roller（测试用）。 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `set_max_hp(max_hp: int) -> void` | 设置最大生命值。 |
| `set_hp(hp: int) -> void` | 设置当前生命值。 |
| `set_hunger(hunger: int) -> void` | 设置饥饿值。 |
| `set_sneak(sneak_value: int) -> void` | 设置潜行值。 |
| `get_hp() -> int` | 当前生命值。（重写 Entity） |
| `get_max_hp() -> int` | 最大生命值上限。 |
| `get_hunger() -> int` | 当前饥饿值。 |
| `get_sneak() -> int` | 当前潜行值。 |
| `get_current_block() -> Variant` | 当前所在地图块。`null` 表示未在地图上。 |
| `set_current_block(block: MapBlock) -> void` | 设置当前所在地图块。 |
| `set_dice_roller(roller: Callable) -> void` | 注入骰子 roller（测试用）。roller 为无参 Callable，返回 int。 |
| `get_role_card() -> RoleCard` | 角色卡牌对象。 |
| `add_hp(num: int) -> void` | 直接增加 `num` 点生命值，不触发钩子，不受最大值约束。与 `recover` 的区别见待定义方法.md §9.6。 |
| `add_hunger(num: int) -> void` | 直接增加 `num` 点饥饿值，不走 `increaseHunger` 流程。与 `increaseHunger` 的区别见待定义方法.md §9.7。 |
| `reduce_hunger(num: int) -> void` | 直接减少 `num` 点饥饿值，不走 `decreaseHunger` 流程。最低降至 1。 |
| `add_sneak(num: int) -> void` | 增加潜行值。 |
| `reduce_sneak(num: int) -> void` | 减少潜行值（可为负）。 |
| `addMarkSkill(mark_name: String, quantity: int = 1) -> void` | 添加 `quantity` 层标记。默认 1。当前不支持 Until 参数。 |
| `removeMarkSkill(mark_name: String) -> void` | 移除标记（清零）。 |
| `countMark(mark_name: String) -> int` | 获取标记层数。无此标记返回 0。 |
| `hasMarkSkill(mark_name: String) -> bool` | 是否有指定标记（层数 > 0）。 |
| `reduce_hp(num: int) -> void` | 直接扣血 `num` 点。（重写 Entity） |
| `is_player() -> bool` | 是否为玩家。（重写 Entity）返回 `true`。 |
| `recover(num: int) -> void` | 恢复 `num` 点生命值，受最大值约束。4 节点钩子链：回复生命前/时/系统加血/后。规则见 GameSystem/PlayerState.md。 |
| `increaseHunger(num: int) -> void` | 增加 `num` 点饥饿值，逐点结算：到 6 翻面+加饥饿伤害标记，按等级造成无来源伤害。规则见 GameSystem/PlayerState.md。 |
| `decreaseHunger(num: int) -> bool` | 减少 `num` 点饥饿值，最低降至 1。清除饥饿伤害标记并翻回正面。返回是否成功减少。 |
| `poison() -> void` | 中毒结算：按 `poison` 标记层数造成无来源伤害。规则见 GameSystem/PlayerState.md。 |
| `roll_two_dice() -> int` | 投两颗大骰子，返回点数和（2-12）。测试可通过 `set_dice_roller` 注入固定返回。 |
| `judge() -> int` | 检定：投两颗大骰子，返回点数和（2-12）。规则见 GameSystem/Judge.md。 |
| `sneakJudge() -> bool` | 潜行检定：结果 <= 潜行值（减地块怪物数+标记数）则成功。规则见 GameSystem/Judge.md。 |
| `monsterSpawnJudge(revealed_blocks: Array[MapBlock] = []) -> void` | 怪物出生检定：投骰子匹配已展示地图块执行出生逻辑。规则见 GameSystem/Judge.md。 |
| `drawMonster(num: int) -> void` | 抓 `num` 张怪物卡。**当前 stub**。规则见 GameSystem/DrawFlow.md。 |
| `playerDeath(source: Variant) -> void` | 玩家死亡流程。**当前 stub**。规则见 GameSystem/DeathFlow.md。 |

### 私有/静态方法

| 方法签名 | 说明 |
|----------|------|
| `_on_death(source: Variant) -> void` | 重写 Entity，转发到 `playerDeath`。 |
| `_game_log_stub(msg: String) -> void` | 静态方法。game.log 的临时占位。 |

---

## MapBlock

- **文件**: `scripts/system/map_block.gd`
- **类声明**: `class_name MapBlock extends Entity`
- **职责**: 地图块实体，管理展示状态、怪物标记、玩家列表。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `monster_spawn_value` | `int` | 怪物生成点数（匹配 judge 结果，2-12）。默认 `0`。 |
| `_revealed` | `bool` | 是否已展示。默认 `false`。 |
| `_monster_marks` | `int` | 怪物标记数（0-3）。默认 `0`。 |
| `_monsters` | `Array` | 地块上的怪物列表。 |
| `_players` | `Array` | 地块上的玩家列表。 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `is_revealed() -> bool` | 是否已展示（翻开）。 |
| `countMonsterMark() -> int` | 怪物标记数（0-3）。 |
| `addMonsterMark(num: int) -> void` | 添加 `num` 个怪物标记。 |
| `removeAllMonsterMarks() -> void` | 移除所有怪物标记。 |
| `hasPlayer() -> bool` | 地块上是否有玩家。 |
| `countMonster() -> int` | 地块上的怪物数（stub，返回 `_monsters` 大小）。 |
| `addPlayer(entity: Variant) -> void` | 添加玩家到地块。`entity` 类型为 Variant 以避免与 Player 循环依赖。 |
| `removePlayer(entity: Variant) -> void` | 移除玩家。 |
| `set_revealed(revealed: bool) -> void` | 设置已展示（测试与后续展示机制用）。 |
| `get_players() -> Array` | 地块上的所有玩家（返回 `_players` 副本）。 |

---

## Skill

- **文件**: `scripts/system/skill.gd`
- **类声明**: `class_name Skill extends Resource`
- **职责**: 技能数据，包含触发名、过滤函数、内容函数。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `trigger` | `String` (@export) | 触发名。单个字符串或用"、"分隔的多个字符串。 |
| `filter` | `Callable` | 过滤函数。签名为 `(event: Event) -> bool`。默认恒真。 |
| `content` | `Callable` | 内容函数。签名为 `(event: Event) -> void`。默认空操作。 |

### 静态方法

| 方法签名 | 说明 |
|----------|------|
| `make(p_trigger: String, p_filter: Callable = Callable(), p_content: Callable = Callable()) -> Skill` | 静态构造：便于代码中创建技能实例。 |

---

## Event

- **文件**: `scripts/system/event.gd`
- **类声明**: `class_name Event extends RefCounted`
- **职责**: 事件对象，在 `trigger`/`damage` 等流程中传递上下文。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `trigger_name` | `String` | 触发名，由 `entity.trigger` 在循环外赋值。 |
| `source` | `Variant` | 事件来源。`null` 表示无来源。 |
| `target` | `Variant` | 事件目标。 |
| `num` | `int` | 数值参数（伤害点数、抓牌数、回复量等）。可被钩子修改。默认 `0`。 |
| `type` | `String` | 类型标签（如 "饥饿伤害"、"poison"）。默认 `""`。 |
| `cancelled` | `bool` | 是否已取消。默认 `false`。 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `cancel() -> void` | 取消事件。`trigger` 循环检测到 `cancelled` 后中断后续技能。 |

---

## RoleCard

- **文件**: `scripts/system/role_card.gd`
- **类声明**: `class_name RoleCard extends RefCounted`
- **职责**: 角色卡牌，管理正反面状态。

### 成员变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_is_front` | `bool` | 角色卡当前是否正面朝上。默认 `true`。 |

### 公有方法

| 方法签名 | 说明 |
|----------|------|
| `is_front() -> bool` | 角色卡当前是否正面朝上。 |
| `flip() -> void` | 翻面：正 ↔ 反切换。 |

---

## Dice

- **文件**: `scripts/system/dice.gd`
- **类声明**: `class_name Dice extends RefCounted`
- **职责**: 骰子工具类，提供静态投骰方法。

### 静态方法

| 方法签名 | 说明 |
|----------|------|
| `roll_two() -> int` | 投两颗标准骰子（1-6），返回点数和（2-12）。规则见 GameSystem/Judge.md。 |
