# Game 游戏全局类

> 以 `src/game/game.gd` 为准。
> 职责：游戏全局状态管理与跨玩家/跨区域操作。
> Game 类**不继承** Entity（无技能、无 trigger），是全局管理器。
> 注册为 autoload，全局名 `Game`，无 `class_name`，继承 `Node`。
> 游戏初始化与开局流程见 [GameInstructions/02_开局与流程.md](../../GameInstructions/02_开局与流程.md)。
> 状态管理（游戏阶段/游戏结果/当前回合玩家/回合队列）委托给 [GameStateMachine](../Core/GameStateMachine.md)。

---

## 字段

### 全局区域

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `monster_pile` | Pile | null | 怪物卡牌堆。空了重洗怪物弃牌堆组成新牌堆 |
| `monster_discard_pile` | Pile | null | 怪物卡弃牌区域 |
| `red_scavenge_pile` | Pile | null | red 拾荒牌堆。最危险（含伏击！） |
| `green_scavenge_pile` | Pile | null | green 拾荒牌堆 |
| `blue_scavenge_pile` | Pile | null | blue 拾荒牌堆。最安全 |
| `scavenge_discard_pile` | Pile | null | 所有颜色的拾荒牌弃置后都进入此弃牌堆（不分颜色） |
| `map_area` | Array | [] | 所有存活的地块列表。地块被摧毁后从列表中移除 |
| `map_width` | int | 0 | 地图网格的列数（x 方向），由任务地图模板二维数组确定 |
| `map_height` | int | 0 | 地图网格的行数（y 方向），由任务地图模板二维数组确定 |
| `card_resolution_area` | Array | [] | 卡牌结算时的临时区域 |
| `players` | Array | [] | 本局游戏的所有玩家（按座位顺序） |

### 状态机相关

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `state_machine` | GameStateMachine | null | 游戏状态机实例。`_ready()` 中创建并 `init()`。管理游戏阶段、游戏结果、当前回合玩家、回合队列等。详见 [GameStateMachine.md](../Core/GameStateMachine.md) |
| `mission_config` | MissionConfig | null | 本局任务配置。由 `initialize_game` 从 MissionData 构造。详见 [MissionConfig.md](./MissionConfig.md) |
| `stats_tracker` | StatsTracker | null | 本局统计聚合器。`_ready()` 中创建。详见 [StatsTracker.md](../System/StatsTracker.md) |
| `coop_death_mode` | bool | false | 同生共死变体。开启后任一玩家死亡即所有求生者输掉游戏。默认 false |
| `current_mission` | Variant | null | 本局任务的 MissionData 引用（可能为 Dictionary 或 Resource） |
| `removed_cards` | Array | [] | 移出游戏的卡牌列表（区别于进入弃牌堆的卡牌） |
| `log_list` | Array | [] | 游戏日志消息列表，同时通过 `EventBus.publish_log` 推送 UI |

### 测试用标记

> 向后兼容字段，由 `state_machine.game_over` 同步设置。

| 字段名 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `game_over_called` | bool | false | 是否已调用过 `game_over` |
| `game_result` | String | "" | 游戏结果字符串："win" / "lose" |

---

## 方法

### _ready()

> autoload 初始化钩子。创建 `state_machine`（并调用 `init()`）与 `stats_tracker`。

### 日志

#### log_message(message)

> 输出游戏日志。方法名避开 GDScript 内置 `log()`（自然对数）。
> 将 message 追加到 `log_list`，并通过 `EventBus.publish_log(message)` 同步推送给 UI 日志面板订阅者。

#### log(message)

> `log_message` 的别名，供 content 代码统一调用。

---

### 状态机委托

#### start_game()

> 游戏开局流程。**委托给** [GameStateMachine.start_game()](../Core/GameStateMachine.md)，使用 `await` 等待完成。
> 在 `initialize_game` 之后调用。依次执行：状态转换 setup → playing → 抓初始手牌（含可选重调）→ 抓初始怪物卡 → 触发「游戏开始时」trigger → 进入第一玩家回合。
> 落地 [EventSystem §4.12](../Core/EventSystem.md) 的「游戏开始时」trigger。

#### game_over(result)

> 游戏结束流程。接受 String 参数 "win" / "lose"，转换为 `GameStateMachine.GameResult` 枚举后委托给 [GameStateMachine.game_over()](../Core/GameStateMachine.md)。
> 若 `state_machine` 无效，则直接设置 `game_over_called = true`、`game_result = result`（向后兼容路径）。
> 触发场景：所有玩家死亡（lose）；或胜利条件达成（win）。
> 落地 [EventSystem §4.12](../Core/EventSystem.md) 的「游戏结束时」trigger。

##### 游戏失败条件

> 失败条件为**即时检查**，由各流程触发后调用 `game_over("lose")`。详见 [GameStateMachine.md](../Core/GameStateMachine.md)。

- **所有玩家死亡** → `all_players_dead()` 为真 → `game_over("lose")`（[Player.playerDeath](../Entities/Player.md) 末尾检查）
- **怪物牌堆重洗后仍空**（所有怪物卡都在场上）→ `game_over("lose")`（见 [Player.drawMonster](../Entities/Player.md)）
- **同生共死变体**：`coop_death_mode` 为真时，任一玩家死亡即 `game_over("lose")`（[Player.playerDeath](../Entities/Player.md) 末尾在全灭判定之前检查）
- **任务特定失败**：任务系统检查后调用 `game_over("lose")`（如任务 8 潜行检定失败且无日记本）

##### 游戏胜利条件

> 胜利条件为**回合结束时检查**，在 [GameStateMachine.check_win_condition()](../Core/GameStateMachine.md) 中实现。
> 详见 [GameInstructions/02_开局与流程.md](../../GameInstructions/02_开局与流程.md)。
> 在玩家的回合结束时，胜利条件才触发（玩家依然会在回合结束前受到伤害）。

- 玩家完成了任务（`check_mission_win_condition()` 委托给 `mission_config.check_win_condition`）
- 往「面包车」添加了所需要的燃料值（`mission_config.van_fuel_required`；为 -1 时跳过此条件及以下条件）
- 所有存活玩家都返回到了地图块「面包车」上
- 地图块「面包车」内没有任何怪物和怪物标记

> **燃料值为 -1（NULL）**：表示该任务不通过启动面包车胜利（如任务 4/8/9/11），此时仅检查任务胜利条件。详见 [MissionConfig.md](./MissionConfig.md)。

#### next_turn()

> 进入下一玩家回合。**委托给** [GameStateMachine.next_turn()](../Core/GameStateMachine.md)，使用 `await` 等待完成。按座位顺序循环并处理跳过/额外回合。

#### get_current_player()

> 返回当前回合玩家。**委托给** [GameStateMachine.get_current_player()](../Core/GameStateMachine.md)。`state_machine` 无效时返回 null。

#### check_mission_win_condition()

> 检查任务特定胜利条件。
> 若 `mission_config` 为 null 或 `mission_config.check_win_condition` 不是有效 Callable，返回 false；否则 `call()` 该 Callable 并返回其布尔结果。
> 由 [GameStateMachine.check_win_condition()](../Core/GameStateMachine.md) 调用，作为胜利判定的第一项条件。

> **设计说明**：
> - 任务胜利条件由任务包自行定义，支持任意复杂逻辑（如任务 8 检查"已记录科学家信息 + 所有玩家在军事基地"、任务 9 检查"已摧毁 2 个发射器 + 科学家在坠碎点"等）
> - 任务状态存储在 `mission_config.mission_state` 字典中，由任务包各方法（如 `player.记录科学家信息()`）写入
> - 与面包车胜利条件的关系：若 `van_fuel_required == -1`，[check_win_condition](../Core/GameStateMachine.md) 仅依赖本方法；否则两者均需满足

---

### 地图管理

#### build_map(mission_config_arg)

> 根据任务包配置构建游戏地图。触发场景：游戏初始化步骤 4「根据任务说明构建地图」。
>
> **构建逻辑**（模板 + 指定 + 随机）：
> 1. 清空 `map_area`、`map_width`、`map_height`
> 2. 读取配置的 `map_template` 二维数组，确定 `map_height`（行数）和 `map_width`（列数）
> 3. 读取 `spawn_block_name`（出生点地块名）与 `end_block_name`（结束点地块名）
> 4. 统计 `map_template` 中 code 0（出生点）和 code 2（结束点）格子数；这两类格子直接使用指定地块名，需从 `map_block_config` 的对应计数中扣除，否则同名地块会重复出现在地图上
> 5. 构建 `block_pool`：遍历 `map_block_config`，对每条 `{block_name, count}`，扣除同名 spawn/end 的格子数后按数量展开。若该地块在 DataManager 中有 variants（变体），则将变体索引随机洗混后逐一入池，否则 variant_index 置 -1
> 6. 遍历 `map_template` 二维数组，按编码实例化地块：
>    - `-1`（无地块）→ 跳过
>    - `0`（出生点）→ 使用 `spawn_block_name`；若该地块有 variants 则随机选一个 variant_index
>    - `1`（未知随机地块）→ 从 `block_pool` 中随机抽取一项（pop_at），取其 `block_name` 与 `variant_index`
>    - `2`（游戏结束点）→ 使用 `end_block_name`；若该地块有 variants 则随机选一个 variant_index
>    - `3`（标记地块）→ 从 `block_pool` 中随机抽取一项；实例化后从配置的 `objective_marks` 列表 `pop_front` 取一个目标标记调用 `block.add_objective_mark(mark)`，并根据标记的 `initial_monster_marks` 字段调用 `block.add_monster_mark(initial_marks)` 预置怪物标记
> 7. 对 code 0/2/3 的地块设置 `block.revealed = true`（默认展示）
> 8. 调用 `_create_map_block(block_name, variant_index)` 实例化地块，`block.set_coordinate(x, y)` 设置坐标，追加到 `map_area`

> **任务地图模板编码**：
> - `-1` = 无地块
> - `0` = 出生点（任务包指定地块名，如"购物中心"）
> - `1` = 未知随机地块（从地块池随机抽取）
> - `2` = 游戏结束点（任务包指定地块名，如"面包车"）
> - `3` = 标记地块（从地块池随机抽取 + 添加目标标记 + 预置怪物标记）

> **地块池耗尽**：若 `block_pool` 不够（code 1/3 位置过多），跳过该格。
> **目标标记**：任务包通过 `objective_marks` 数组按 `pop_front` 顺序返回 ObjectiveMark 结构（标记ID、描述、效果函数、`initial_monster_marks` 等）。
> **预置怪物标记**：标记地块可根据目标标记的 `initial_monster_marks` 字段预置怪物标记（任务 9/11）。预置的怪物标记与怪物出生检定添加的标记共用同一字段，上限 3。

#### destroy_map_block(block, source)

> 摧毁地块流程。触发场景：[blue.md 大炸药](../../Resource/ScavengePacks/blue.md)「行动：摧毁一个地图板块」。
> 落地 [EventSystem §4.13](../Core/EventSystem.md) 的「摧毁地块前/时/后」trigger。
>
> **6 节点处理逻辑**：
> 1. 构造 `event = EventSystem.create_destroy_block_event(source, block)`
> 2. 触发 `before_destroy_block`（取消点）：对所有 `players` 调用 `await player.trigger("before_destroy_block", event)`；若 `EventSystem.is_cancelled(event)` 为真，返回 false
> 3. 处理地块上的玩家（弹出到相邻存活地块）：
>    - 调用 `block.get_players()` 获取地块上的玩家
>    - 调用 `block.get_adjacent_blocks()` 获取相邻存活地块
>    - 相邻为空：玩家受到 5 点无源伤害（紧急逃生失败），日志输出 `LogColors.player(player.player_name) + " 无处可逃，受到 5 点伤害"`，`player.damage(5, null, "block_destroy")`
>    - 相邻非空：`target = await player.choose_map_block(adjacent)`；若 `target == null` 取 `adjacent[0]`；调用 `block._clear_skills_for_player(player)` 清理旧地块技能；`player.current_block = target` 底层坐标变更（不触发完整移动钩子）；`target._acquire_skills_for_player(player)` 获取新地块技能；若 `target` 未展示则 `await target.reveal(true, player)` 展示（触发「展示地块时」效果）
> 4. 消灭地块上的所有怪物标记：`block.monster_marks = 0`
> 5. 触发 `on_destroy_block`（系统结算）：对所有 `players` 调用 `await player.trigger("on_destroy_block", event)`
> 6. 地块状态变更：`block.block_state = "destroyed"`，`map_area.erase(block)`，日志输出 `LogColors.block(block.block_name) + " 被摧毁了"`
> 7. 触发 `after_destroy_block`（通知）：对所有 `players` 调用 `await player.trigger("after_destroy_block", event)`
> 8. 返回 true

> **trigger 触发对象**：所有 player（按座位顺序）。Game 类不继承 Entity，无自身 trigger。
> **玩家弹出规则**：弹出不消耗行动次数，不触发完整移动钩子（非主动移动）；清理旧地块技能 → 底层坐标变更 → 获取新地块技能 → 展示未展示的地块。
> **地块上的怪物卡**：怪物纠缠的是玩家而非地块，玩家弹出后怪物继续纠缠该玩家（不随地块摧毁死亡）。
> **目标标记**：地块被摧毁时，其上的目标标记一并销毁（未触发的标记不会再触发）。

#### get_block_by_coord(x, y)

> 通过坐标查询存活的地块。遍历 `map_area`，返回第一个 `is_alive()` 且 `coordinate["x"] == x` 且 `coordinate["y"] == y` 的地块；未找到返回 null。
> 触发场景：[MapBlock.getAdjacentBlocks](../Entities/MapBlock.md)、距离计算、射程判定等。已摧毁的地块已从 `map_area` 移除，不会被查询到。坐标越界时返回 null。

#### get_blocks_by_name(block_name)

> 按名字查询所有同名的存活地块。遍历 `map_area`，返回 `is_alive()` 且 `block_name` 匹配的地块列表。
> 触发场景：隧道技能（移动到另一个已展示的隧道地块）、机场技能等。

#### get_adjacent_alive_blocks(block)

> 返回地块的四向相邻存活地块。**直接转调** [MapBlock.get_adjacent_blocks()](../Entities/MapBlock.md)。
> 用于地块摧毁时玩家弹出目标选择。

---

### 玩家查询

#### get_all_players()

> 返回 `players` 数组（所有玩家，按座位顺序）。

#### get_alive_players()

> 返回所有存活玩家。遍历 `players`，过滤 `is_instance_valid` 与 `is_alive()` 的玩家。

#### all_players_dead()

> 检查是否所有玩家死亡。遍历 `players`，若存在任一 `is_alive()` 的玩家返回 false，否则返回 true。
> 由 [Player.playerDeath](../Entities/Player.md) 末尾调用，判定全灭。

#### get_engaged_monsters(player)

> 返回玩家面前纠缠的怪物列表。若 `player` 无效或不含 `monster_zone` 字段返回空数组；否则返回 `player.monster_zone`。

---

### 卡牌与目标查询

#### get_target(block)

> 返回地块上的所有目标（玩家 + 怪物），用于猎枪/氧气罐的溅射。
> 怪物随其纠缠玩家所在地块判定位置（怪物存于 `player.monster_zone`）。
> 遍历 `players`，对每个 `get_current_block() == block` 的玩家追加玩家本身，再追加其 `monster_zone` 中所有有效怪物。

#### remove_card(card)

> 将卡牌移出游戏（区别于进入弃牌堆）。追加到 `removed_cards`。
> 触发场景：玩家死亡时所有求生者游戏牌移出游戏（见 [Player.playerDeath](../Entities/Player.md)）；或 [Player.removeCard](../Entities/Player.md) 销毁流程。
> **销毁 vs 弃置**：销毁（remove_card）移出游戏不进弃牌堆；弃置（discard）进入对应弃牌堆。

#### get_scavenge_pile(color)

> 获取指定颜色的拾荒牌堆。
> 参数 color 为 "red" / "green" / "blue" 字符串，分别返回 `red_scavenge_pile` / `green_scavenge_pile` / `blue_scavenge_pile`；其他值返回 null。

#### get_random_card(player, areas)

> 从玩家指定区域随机返回一张牌；无牌返回 null。
> 参数 `areas` 为字符串数组，元素可为 "hand" / "equipment"：
> - "hand"：收集 `player.hand` 中所有牌
> - "equipment"：遍历 `player.equipment_zone`，将每个 Equipment 实体映射为其来源 `equipment_card`（保持"返回卡"语义）
> 收集完成后随机返回一张；空集返回 null。

#### create_scavenge_card(card_name)

> 根据卡牌名创建一张新的拾荒卡实例。**不消耗任何牌堆**中的牌，直接从 DataManager 加载的拾荒卡数据克隆一张新卡。
> 遍历 `["red", "green", "blue", "gray"]` 四色 DataManager.get_scavenge_pile(color)，按 `card_name` 精确匹配 ScavengeCardData；找到时调用 `_create_scavenge_card_from_data(card_data, color)` 创建实例并返回；未找到返回 null 并日志输出 `LogColors.card(card_name)`。
> 调用场景：[Player.收集物品](../Entities/Player.md)（任务物品直接生成加入手牌区）。

> **设计说明**：直接生成新卡牌而不从牌堆抽取，是因为任务物品（如「满是灰尘的日记本」）作为拾荒卡虽存在于拾荒牌堆中，但任务设计上希望玩家通过触发目标标记获得，而非随机抽到。这可能造成牌堆中仍存在同名卡（可接受，任务设计已考虑）。

#### get_card(card_english_name, pile)

> 从指定牌堆中查找并返回第一张匹配名称的卡牌；未找到返回 null。
> `pile` 可为 Pile 或 Array；运行时卡牌以 `card.card_name` 或 `card.english_name` 标识，二者任一匹配即返回。

#### get_all_discard_pile_equipments()

> 返回场上所有弃牌堆中的装备牌列表。
> 遍历每个 `player.game_discard_pile` 与全局 `scavenge_discard_pile`，调用 `pile.get_all()` 收集所有 `EquipmentCard` 类型卡牌。
> 调用场景：[hunter.md 神通广大](../../Resource/SurvivorPacks/hunter.md)、[mechanic.md 维修](../../Resource/SurvivorPacks/mechanic.md)。

#### has_equipment_in_discard_piles()

> 场上所有弃牌堆中是否至少有 1 张装备牌（filter 用，比 `get_all_discard_pile_equipments().size() > 0` 更高效）。遍历到第一张 `EquipmentCard` 即返回 true，否则返回 false。

#### get_step_toward(source, target)

> 返回从 source 朝 target 方向的相邻存活地块。用于 surgeon「拉近」技能的「向玩家拉近一格不触发效果」。
> 计算坐标差 `dx = target.x - source.x`、`dy = target.y - source.y`：
> - 若 `dx != 0`：先尝试 x 方向，`step_x = source.x + sign(dx)`，返回 `get_block_by_coord(step_x, source.y)`
> - 若 `dy != 0`：再尝试 y 方向，`step_y = source.y + sign(dy)`，返回 `get_block_by_coord(source.x, step_y)`
> - 若 `dx == 0 && dy == 0`：source 与 target 重合，返回 target
> - 无路径时返回 null

---

### 游戏初始化

#### initialize_game(mission, variants, seats)

> 游戏初始化：从 RoomState 创建玩家、构建地图、初始化牌堆。在 `start_game()` 前调用。
> 参数：
> - `mission: MissionData`：本局任务。为 null 时从 `DataManager.get_all_missions()` 随机抽取一个
> - `variants: Dictionary`：变体配置（如同生共死模式等）
> - `seats: Array`：座位列表，每项为 `{type, survivor}` 字典；`type == "empty"` 或 `"ai"` 的座位跳过

> **执行步骤**：
> 1. **确定任务**：mission 为 null 时随机抽取；赋值给 `current_mission`
> 2. **设置任务配置**：创建 `MissionConfig` 实例
>    - `van_fuel_required = int(mission.van_fuel_required)`（mission 字段为 null 时置 -1）
>    - 若 `mission.win_condition_code` 非空字符串，调用 `_compile_win_condition(mission.win_condition_code)` 编译并赋给 `mission_config.check_win_condition`
>    - `mission_config.mission_state = {}`
> 3. **创建玩家**：清空 `players`，遍历 `seats`：
>    - 跳过 `type == "empty"` 或 `"ai"` 的座位，或 `survivor == null` 的座位
>    - 创建 `Player`，设置 `seat_number`、`player_name = survivor.character_name`、`max_hp`、`hp = survivor.initial_hp`、`hunger = 1`
>    - `role_card = _create_role_card_from_survivor(survivor)`
>    - `game_deck = _create_player_deck(survivor)`、`game_discard_pile = Pile.new()`
>    - 挂载通用主动技能：遍历 `DataManager.get_common_skills()` 调用 `_create_skill_from_data` 后 `player.add_skill`
>    - 挂载角色固有技能：遍历 `player.role_card.intrinsic_skills` 调用 `player.add_skill`
>    - 追加到 `players`
> 4. **构建地图**：`map_config = _build_map_config(mission)`，调用 `build_map(map_config)`
> 5. **将玩家放到出生点**：`spawn_block = _find_spawn_block(mission)`，若非 null 则将所有 `players` 的 `current_block` 设为 `spawn_block`
> 6. **初始化全局牌堆**：调用 `_init_global_piles(mission)`
> 7. **初始化状态机**：`state_machine.init()`

#### _build_map_config(mission)

> 内部方法：从 MissionData 构建 `build_map()` 所需的配置 Dictionary。
> 字段映射：
> - `map_template` ← `mission.map_layout`
> - `map_block_config` ← 将 `mission.map_blocks_config`（`Dictionary{name: count}`）转为 `Array<{block_name, count}>`
> - `spawn_block_name` ← `mission.map_legend["0"].block_name`（无则空字符串）
> - `end_block_name` ← `mission.map_legend["2"].block_name`（无则空字符串）
> - `objective_marks` ← `mission.objective_marks.duplicate(true)`（深拷贝，因为 `build_map` 会 `pop_front` 消费）

#### _find_spawn_block(mission)

> 内部方法：查找任务的出生点地块。读取 `mission.map_legend["0"].block_name`，在 `map_area` 中查找第一个 `block_name` 匹配的地块；未找到返回 null。

#### _init_global_piles(mission)

> 内部方法：初始化全局牌堆（怪物牌堆 + 拾荒牌堆 + 弃牌堆）。
> **怪物牌堆**：新建 `monster_pile` 与 `monster_discard_pile`；从 `DataManager.get_monster_pack(mission.monster_pack_type)` 加载怪物卡数据，按 `card_data.count` 重复调用 `_create_monster_card_from_data` 创建实例加入 `monster_pile`；最后 `shuffle()`
> **拾荒牌堆**：新建 `scavenge_discard_pile`；对 `["red", "green", "blue"]` 三色分别：
> - 读取 `mission.scavenge_config[color]` 卡牌条目列表
> - 每条 `{card_name, count}` 按 count 重复：调用 `_find_scavenge_card_variants(card_name)` 查找匹配数据，取 `variants[i % variants.size()]`，调用 `_create_scavenge_card_from_data(card_data, color)` 创建实例加入 pile
> - 找不到时日志警告 `"警告：拾荒卡未找到 - " + color + "/" + LogColors.card(card_name)` 并跳过
> - `pile.shuffle()` 后赋给对应 `red_scavenge_pile` / `green_scavenge_pile` / `blue_scavenge_pile`

#### _find_scavenge_card_variants(card_name)

> 内部方法：按名称在所有颜色（red/green/blue/gray）的拾荒卡数据中查找匹配项。
> 先精确匹配 `card_data.card_name == card_name`，若无则前缀匹配 `card_data.card_name.begins_with(card_name + "（")`（如 "食物" 匹配 "食物（微量）"）。
> 返回所有匹配的 ScavengeCardData 数组（可能跨色）；精确匹配优先于前缀匹配。

#### _compile_win_condition(code)

> 内部方法：编译任务胜利条件代码字符串为 Callable。
> **特殊处理**：直接访问 `CodeExecutor` 的私有 static 成员，**不**走 `CodeExecutor.compile_*` 公开接口：
> - 拼接源码 `"extends RefCounted\nfunc _fn(game) -> bool:\n\t" + code`（注意签名是单参 `game`，与 `compile_filter` 的四参不同）
> - `script = GDScript.new()`、`script.source_code = full_code`
> - `script.resource_path = "res://addons/gut/not_a_real_file/wc_%d.gd" % CodeExecutor._path_counter`（直接读 `_path_counter`）
> - `CodeExecutor._path_counter += 1`（直接递增）
> - `script.reload()`；失败 `push_warning` 并返回空 Callable
> - 成功后 `CodeExecutor._scripts.append(script)`、`instance = script.new()`、`CodeExecutor._instances.append(instance)`（直接追加防 GC）
> - 返回闭包 `func() -> bool: return instance.call("_fn", Game)`（捕获全局 `Game` autoload 作为 game 参数）
>
> 详见 [CodeExecutor.md](../System/CodeExecutor.md) 与 [Engineering/CodeExecutor.md](../../Engineering/CodeExecutor.md)。

#### _config_get(config, field, default)

> 内部方法：从 Dictionary 或 Object 安全读取字段。Dictionary 走 `config.get(field, default)`，Object 走 `config.get(field)`（null 时返回 default）。

#### _create_map_block(block_name, variant_index)

> 内部方法：根据地块名创建 MapBlock 实例。从 DataManager 加载完整地块数据（`MapBlockData`）。
> - 新建 `MapBlock`，设置 `block_name`
> - 从 `DataManager.get_map_block_def_by_name(block_name)` 加载地块定义
> - 若 `variant_index` 有效：从 `block_def.variants[variant_index]` 读取 `scavenge_colors` 与 `monster_spawn_value` 覆盖默认值
> - 否则使用 `block_def` 默认值
> - 遍历 `block_def.skills`，调用 `_create_skill_from_data` 后 `block.add_skill`

---

### 工厂方法

> 从 `*Data` 类创建运行时实例的工厂方法。`*Data` 类详见 `src/data/`。

#### _create_skill_from_data(skill_data)

> 从 SkillData 创建 Skill 实例。复制全部字段：`skill_name`、`english_name`、`skill_description`、`active`、`trigger`、`skill_type`、`forced`、`position`、`select_card`、`select_target`、`usable`、`filter_target_range`、`range`、`target_type`、`defer_action_cost`。
> 代码字段经 `CodeExecutor` 编译为 Callable 后赋值：
> - `filter = CodeExecutor.compile_filter(skill_data.filter)`
> - `content = CodeExecutor.compile_content(skill_data.content)`
> - `filter_target = CodeExecutor.compile_filter_target(skill_data.filter_target)`
> - `filter_card = CodeExecutor.compile_filter_card(skill_data.filter_card)`
> - `confirm_prompt = CodeExecutor.compile_confirm_prompt(skill_data.confirm_prompt)`

#### _create_role_card_from_survivor(survivor)

> 从 SurvivorData 创建 RoleCard 实例。复制 `role_name = survivor.character_name`、`english_name`、`max_hp`、`initial_hp`、`sneak = survivor.stealth`、`hunger_sneak = survivor.hunger_stealth`、`equipment_capacity = survivor.equipment_slot`、`hand_size_limit`；遍历 `survivor.intrinsic_skills` 调用 `_create_skill_from_data` 后追加到 `rc.intrinsic_skills`。

#### _create_player_deck(survivor)

> 从 SurvivorData 创建玩家游戏牌堆。遍历 `survivor.deck` 字典数组，对每条 `{card_type, count, ...}` 按 count 重复调用 `_create_game_card_from_dict` 创建实例加入 Pile；最后 `shuffle()`。

#### _create_game_card_from_dict(card_dict)

> 从 survivor deck 字典创建游戏卡牌实例。按 `card_type` 分支：
> - `"equipment"` → 新建 `EquipmentCard`，设置 `charge_type`、`charge_max`、`charge_current = charge_initial`、`size`、`range`、`card_subtype = "equipment"`
> - `"action"` → 新建 `SurvivorGameCard`，设置 `card_subtype = "action"`、`range`
> - 其他 → 新建 `SurvivorGameCard`，`card_subtype = card_type`
>
> 公共字段：`card_name`、`english_name`、`card_type`、`source = "game"`。
> 遍历 `card_dict.skills`，对每项调用 `SkillData.new(raw)` 后 `_create_skill_from_data` 再 `card.add_skill`。

#### _create_scavenge_card_from_data(card_data, color)

> 从 ScavengeCardData 创建 ScavengeCard 实例。
> - 新建 `ScavengeCard`，设置 `card_name`、`english_name`、`card_type`、`color`、`source = "scavenge"`
> - 若 `card_type == "equipment"`：`scavenge_type = "equipment"`、`card_subtype = "equipment"`；否则 `scavenge_type = "consumable"`、`card_subtype = "action"`
> - EquipmentCard 继承字段：`size`、`charge_type`、`charge_max`、`charge_current = charge_initial`（非装备类拾荒卡的 charge 字段保持默认 0/空，无害）
> - 遍历 `card_data.skills` 调用 `_create_skill_from_data` 后 `card.add_skill`

#### _create_monster_card_from_data(card_data, monster_type)

> 从 MonsterCardData 创建 MonsterCard 实例。
> 设置 `card_name = card_data.monster_name`、`card_type = "monster"`、`source = "monster"`、`monster_type`、`monster_level = card_data.monster_level`、`max_hp`、`damage_value = card_data.attack_damage`、`range`；遍历 `card_data.skills` 调用 `_create_skill_from_data` 后 `card.add_skill`。

---

## 游戏初始化与开局流程

> 完整流程见 [GameInstructions/02_开局与流程.md](../../GameInstructions/02_开局与流程.md)。
> 步骤 1-6 为初始化（由 `initialize_game` 完成），步骤 7-9 由 `start_game()` 执行。

1. 加载本局游戏的所有求生者角色卡、立像和求生者游戏牌堆
2. 根据任务加载本局游戏的所有怪物卡，洗混组成怪物牌堆
3. 根据任务说明构建三个不同的拾荒牌堆（蓝、绿、红），分别洗乱
4. 根据任务说明构建地图
5. 根据任务说明将玩家立像放到初始地图块上
6. 初始化全局区域与各玩家区域
7. `start_game()` → 每个玩家从游戏牌堆抓 4 张牌作为初始手牌（可选一次重调）
8. `start_game()` → 每名玩家抓取一张怪物卡放到角色面前
9. `start_game()` → 触发「游戏开始时」trigger（按座位顺序对所有 player 触发）→ 进入第一玩家回合

> **手牌上限**：每名玩家手牌上限 10（`RoleCard.hand_size_limit`），初始 4 张不会触顶。重调不会触顶（最多 4 张换 4 张）。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [GameStateMachine](../Core/GameStateMachine.md) | Game 持有 `state_machine` 实例；`start_game` / `game_over` / `get_current_player` / `next_turn` 委托给状态机 |
| [MissionConfig](./MissionConfig.md) | Game 持有 `mission_config`，由 `initialize_game` 从 MissionData 构造 |
| [StatsTracker](../System/StatsTracker.md) | Game 持有 `stats_tracker`，订阅 EventBus 信号聚合本局统计 |
| [EventBus](../System/EventBus.md) | `log_message` 通过 `EventBus.publish_log` 推送 UI 日志面板 |
| [CodeExecutor](../System/CodeExecutor.md) | 工厂方法编译 skill 代码字段；`_compile_win_condition` 直接访问其私有 static 成员 |
| [LogColors](../System/LogColors.md) | 日志输出使用 `LogColors` 着色实体名 |
| [DataManager](../../Engineering/DataFormat.md) | 工厂方法从 DataManager 加载 `*Data` 类（`MapBlockData` / `SurvivorData` / `ScavengeCardData` / `MonsterCardData` / `SkillData` / 通用技能等） |
| [Player](../Entities/Player.md) | Game 管理所有玩家；玩家死亡触发全灭判定 |
| [Monster](../Entities/Monster.md) | Game 管理怪物牌堆 / 弃牌堆 |
| [Card](../Entities/Card.md) | Game 管理各类牌堆；`remove_card` 移出游戏 |
| [MapBlock](../Entities/MapBlock.md) | Game 管理地图区域；`build_map` / `destroy_map_block` / `_create_map_block` 维护地块生命周期 |
| [Pile](../Common/Pile.md) | 各牌堆为 Pile 实例 |
| [Entity](../Core/Entity.md) | Game 不继承 Entity，无 trigger |
