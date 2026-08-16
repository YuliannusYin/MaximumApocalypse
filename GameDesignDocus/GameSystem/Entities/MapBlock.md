# MapBlock 地图块类

> 继承：[Entity](../Core/Entity.md)
> 职责：地图块属性、坐标定位、展示机制、怪物标记管理、地块技能挂载、目标标记管理、面包车燃料管理与摧毁机制。
> 代码：`src/entities/map_block.gd`，`class_name MapBlock extends Entity`。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 设计原则

### 1. 地块技能挂载到玩家

**所有地图块技能全部挂载到玩家身上，由 `player.trigger()` 统一触发。**

玩家进入地块时，地块技能挂载到 Player 身上（内部方法 `_acquire_skills_for_player(player)`）；离开时清理（内部方法 `_clear_skills_for_player(player)`）。这样玩家身上的所有技能（角色固有、装备、地块、临时）都能通过 `player.trigger()` 统一遍历。

> 详见 [Player.move_to](Player.md#movetotarget-block) 节点 4 / 7。

### 2. 坐标定位与相邻关系

每个地块持有一个二维坐标 `(x, y)`，对应任务地图要求二维数组中的位置（`map[y][x]`）。相邻关系基于**四向**（上下左右），不含对角线。距离计算使用**曼哈顿距离** `|x1-x2| + |y1-y2|`。

### 3. 地块状态与摧毁

地块有两种状态：**存活**（`"alive"`）与**已摧毁**（`"destroyed"`）。被大炸药等效果摧毁的地块从 `Game.map_area` 移除，其上的玩家被弹出到相邻存活地块，怪物标记消灭。摧毁流程见 [Game.destroy_map_block](../Game/Game.md)。

### 4. 目标标记

部分任务（如任务 10、12）在地图上放置目标标记。目标标记挂载到地块上，玩家进入地块时触发效果（一次性）。标记效果由任务包定义。

### 5. 面包车燃料

「面包车」地块持有 `van_fuel` 字段表示当前燃料值。燃料上限取自 `Game.mission_config.van_fuel_required`（≤ 0 时表示无面包车胜利，上限为 0）。

---

## 字段

### 基础字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `block_name` | String | `""` | 地图块名称（如"避难所"、"面包车"、"军事基地"） |
| `coordinate` | Dictionary | `{"x": 0, "y": 0}` | 坐标 `{x, y}`。x=列，y=行。对应 `map[y][x]` |
| `monster_spawn_value` | int | `0` | 怪物生成点数。怪物出生检定时投骰结果匹配的地块生成怪物 |
| `scavenge_colors` | PackedStringArray | `[]` | 拾荒颜色集合（`"red"` / `"green"` / `"blue"` 子集）。空集合表示不可拾荒 |
| `revealed` | bool | `false` | 是否展示。玩家首次进入时翻开，触发展示地块时效果 |
| `monster_marks` | int | `0` | 怪物标记数（上限 3） |
| `block_state` | String | `"alive"` | 地块状态：`"alive"`（存活）/ `"destroyed"`（已摧毁）。摧毁后从 `Game.map_area` 移除 |
| `objective_marks` | Array | `[]` | 目标标记列表。空表示无标记。玩家进入时触发未触发的标记 |
| `van_fuel` | int | `0` | 面包车当前燃料值（仅"面包车"地块使用） |
| `skills` | List\<Skill\> | — | 地块技能（继承自 Entity 的 skills） |

### 目标标记结构（ObjectiveMark）

目标标记是挂载到地块上的 Dictionary，包含以下键：

| 键 | 类型 | 说明 |
|------|------|------|
| 标记ID | String | 如 "标记1"、"标记2" |
| 标记描述 | String | 自然语言描述，如 "收集 3 个多余零件和 2 个医疗用品" |
| 标记效果 | Callable | `(player) => void`，玩家进入地块时调用 |
| 已触发 | Bool | 是否已触发（一次性）。默认 false |
| 初始怪物标记数 | Int | 地图构建时为地块预置的怪物标记数。默认 0。用于任务 9/11 等标记地块需守卫的场景 |
| 移除条件 | Callable | `(block) => bool`。每次 `remove_monster_mark` 后检查，满足时自动移除标记。如任务 11：返回 `block.count_monster_mark() == 0` |
| 已移除 | Bool | 是否已被移除（区别于"已触发"）。默认 false。移除后不再参与任务胜利条件检查 |

> 标记效果由任务包定义，在地图构建时挂载到地块上。详见 [Game.build_map](../Game/Game.md)。
>
> **初始怪物标记数**：build_map 在 `add_objective_mark` 后调用 `block.add_monster_mark(mark.初始怪物标记数)` 预置怪物标记。
>
> **移除条件**：仅在 `remove_monster_mark` 后检查（怪物标记减少时）；`add_monster_mark` 不触发检查。条件返回 true 时调用 `remove_objective_mark(mark)`。典型场景：任务 11「清除所有怪物标记后移除目标标记」。

### 地图块配置格式

> 详见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。
> 格式：`地图块名字[拾荒牌堆颜色][地块刷怪点数]`，例：`游乐园[红、蓝、绿][6]`、`城市[红][8]`。

---

## 信号量（triggers）

| trigger 名 | 触发时机 | 触发对象 | 取消点 |
|-----------|---------|---------|--------|
| `on_reveal_block` 展示地块时 | 地块首次翻开时 | 地块技能（挂载到 player 后由 player.trigger 触发） | 否 |
| `before_destroy_block` 摧毁地块前 | 地块被摧毁前 | 所有 player（按座位顺序） | 是 |
| `on_destroy_block` 摧毁地块时 | 地块摧毁系统结算时（玩家弹出、怪物标记消灭、状态变更） | 所有 player | 否 |
| `after_destroy_block` 摧毁地块后 | 地块摧毁完成后 | 所有 player | 否 |
| `on_objective_mark_triggered` 触发目标标记时 | 玩家进入地块且触发未触发的目标标记后 | player | 否 |

> 地块的其他 trigger（如 `on_turn_start`、`on_take_damage`）由地块技能声明，挂载到 player 后在对应流程触发。例：避难所声明 `trigger = "on_turn_start、on_take_damage"`。
>
> 摧毁地块类 trigger 由 [Game.destroy_map_block](../Game/Game.md) 触发；触发目标标记时由 [Player.move_to](Player.md#movetotarget-block) 节点 11 触发。
>
> EventBus 信号：`block_revealed` / `monster_mark_changed` / `objective_mark_changed` / `objective_mark_triggered`，详见 [System/EventBus.md](../System/EventBus.md)。

---

## 方法

### 展示

`reveal(trigger_effect, player)`：翻开未展示的地块。触发场景：[Player.move_to](Player.md#movetotarget-block) 节点 9 中目标地块未展示时。

流程：

1. 设置 `revealed = true`
2. 输出展示日志（player 有效时输出"玩家 X 展示了 Y"，否则输出"Y 被揭示了"）
3. 发射 EventBus `block_revealed` 信号
4. 若 `trigger_effect = true`：构建事件 `{player, block: self}` 并 await `player.trigger("on_reveal_block", event)`（地块技能已挂载到 player）

### 展示查询

| 方法 | 说明 |
|------|------|
| `is_revealed() -> bool` | 是否已展示 |
| `get_spawn_value() -> int` | 返回怪物生成点数 |

### 怪物标记管理

| 方法 | 说明 |
|------|------|
| `add_monster_mark(n=1)` | 增加 n 个怪物标记（上限 3）。**不触发**目标标记移除条件检查。命中时输出"添加了 X 枚怪物标记"日志并发射 EventBus `monster_mark_changed` 信号 |
| `remove_monster_mark(n=1)` | 移除 n 个怪物标记。命中时输出日志与 `monster_mark_changed` 信号；随后检查所有目标标记的移除条件，满足时自动调用 `remove_objective_mark(mark)` |
| `remove_all_monster_marks()` | 移除地块上**所有**怪物标记（设为 0）。**纯移除**，不触发「怪物死亡时」事件。移除后同样检查目标标记移除条件。调用场景：mechanic 无人机攻击、veteran 搜索犬 |
| `count_monster_mark() -> int` | 返回当前怪物标记数 |
| `has_monster_mark() -> bool` | 是否有怪物标记 |
| `has_monster() -> bool` | 地块上是否有纠缠怪物（玩家面前的怪物） |
| `count_monster() -> int` | 返回地块上当前纠缠玩家的怪物总数（遍历 `Game.players` 累加 `monster_zone.size()`） |
| `has_player() -> bool` | 是否有玩家在此地块 |
| `has_color() -> bool` | 是否可拾荒（拾荒颜色集合非空） |
| `has_skill(skill_name) -> bool` | 是否具备指定名字的地块技能（同时匹配 `skill_name` 与 `english_name`） |
| `has_adjacent_unrevealed_block() -> bool` | 是否存在相邻且未展示的存活地块（filter 用，如 hunter 侦察） |

#### 怪物标记规则

- 地块怪物标记最多 3 个
- 怪物出生检定时，匹配地块若标记 < 3 → +1 标记；标记 = 3 且有玩家 → 每位玩家抓 1 怪物卡（见 [Player.monster_spawn_judge](Player.md#monster_spawn_judge)）
- 玩家进入有怪物标记的地块时进行潜行检定，失败 → 移除所有标记并抓等量怪物卡（见 [Player.move_to](Player.md#movetotarget-block) 节点 10）
- **目标标记移除条件检查**：`remove_monster_mark` 后遍历地块上所有未移除且声明了 `移除条件` 的目标标记，条件返回 true 时移除该标记。典型场景：任务 11「清除所有怪物标记后移除目标标记」

### 地块技能挂载（内部方法）

| 方法 | 说明 |
|------|------|
| `_acquire_skills_for_player(player)` | 将地块技能挂载到 player 身上（玩家进入地块时调用） |
| `_clear_skills_for_player(player)` | 从 player 身上移除地块技能（玩家离开地块时调用） |

### 坐标与位置查询

| 方法 | 说明 |
|------|------|
| `get_coordinate() -> Dictionary` | 返回 `{x, y}` 坐标 |
| `set_coordinate(x, y)` | 设置坐标（地图构建时使用） |
| `is_alive() -> bool` | 地块状态是否为 `"alive"` |
| `is_destroyed() -> bool` | 地块状态是否为 `"destroyed"` |
| `is_map_block() -> bool` | 是否为地图块（供 filter_target 中 `target.is_map_block()` 调用区分地块目标） |

### 相邻地块查询

`get_adjacent_blocks() -> Array`：返回四向（上下左右）相邻的存活地块。用于玩家移动目标选择、工厂技能（向相邻地块加怪物标记）、地块摧毁时玩家弹出等场景。

流程：遍历方向 `[(0, -1), (0, 1), (-1, 0), (1, 0)]`，按 `Game.get_block_by_coord(x, y)` 查询邻居，过滤掉无地块与已摧毁地块。

> `Game.get_block_by_coord(x, y)` 通过坐标查询地块，见 [Game.md](../Game/Game.md)。

### 距离计算

`distance_to(other) -> int`：计算当前地块到目标地块的曼哈顿距离 `|x1-x2| + |y1-y2|`。用于射程判定。

> 射程与距离的完整定义见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md)。

### 射程范围查询

| 方法 | 说明 |
|------|------|
| `get_blocks_in_range(range_str, for_monster=false) -> Array` | 返回指定射程范围内的所有存活地块 |
| `get_players_in_range(range_str, for_monster=false) -> Array` | 返回指定射程范围内的所有玩家（基于 `get_blocks_in_range` 累加各地块玩家） |

参数：

- `range_str`：`"short"` / `"medium"` / `"long"` / `"infinity"`
- `for_monster`：是否按怪物射程判定。**玩家与怪物的长距离射程范围不同**：
  - `"short"`：距离 = 0（同地块）
  - `"medium"`：距离 0-1
  - `"long"` + 玩家：距离 1-2（**不含同地块**）
  - `"long"` + 怪物：距离 0-2（**含同地块**）
  - `"infinity"`：所有存活地块

> **长距离射程修正**：代码实际为玩家长距离 1-2 格、怪物长距离 0-2 格（含同地块）。三方矛盾以代码为准统一，详见 [03_判定与术语.md](../../GameInstructions/03_判定与术语.md)。
>
> **`for_monster` 参数语义**：怪物射程以其纠缠玩家所在地块为中心；玩家射程以自己所在地块为中心。`get_players_in_range` 用于怪物攻击流程时需传 `for_monster=true`，详见 [Monster._attack](Monster.md#攻击流程)。

### 玩家查询

| 方法 | 说明 |
|------|------|
| `get_players() -> Array` | 返回该地块上的所有存活玩家（遍历 `Game.players`，匹配 `current_block == self`） |
| `has_player() -> bool` | 是否有存活玩家在此地块（`get_players().size() > 0`） |

### 面包车燃料管理

| 方法 | 说明 |
|------|------|
| `get_van_fuel() -> int` | 返回面包车当前燃料值 |
| `get_van_fuel_max() -> int` | 返回面包车油箱容量（取自 `Game.mission_config.van_fuel_required`）。`mission_config` 不存在或 `van_fuel_required <= 0` 时返回 0（即无面包车胜利任务） |
| `add_van_fuel(n=1)` | 增加面包车燃料（不超过 max），输出"添加了 X 桶燃料 (当前: a/b)"日志 |

### 目标标记管理

| 方法 | 说明 |
|------|------|
| `has_objective_mark() -> bool` | 是否有目标标记（且至少一个未移除） |
| `get_objective_marks() -> Array` | 返回目标标记列表 |
| `add_objective_mark(mark)` | 添加目标标记（地图构建时使用）。发射 EventBus `objective_mark_changed` 信号 |
| `remove_objective_mark(mark)` | 移除指定目标标记（设 `removed = true` 并从列表移除）。由 `remove_monster_mark` 检查移除条件后调用，或由炸药等技能直接调用。发射 `objective_mark_changed` 信号 |
| `remove_all_objective_marks()` | 移除地块上所有未移除的目标标记。由炸药等技能调用 |
| `trigger_objective_marks(player)` | 触发所有未触发且未移除的目标标记效果 |

`trigger_objective_marks(player)` 流程（针对每个未触发且未移除的标记）：

1. 执行标记效果（任务定义的 `effect` Callable，传入 player）
2. 设置 `triggered = true`
3. 发射 EventBus `objective_mark_triggered` 信号
4. 构建 `EventSystem.create_objective_mark_event` 事件，await `player.trigger("on_objective_mark_triggered", event)`

> **触发时机**：在 [Player.move_to](Player.md#movetotarget-block) 节点 11 中调用（进入地块后、潜行检定之后）。
> **一次性**：标记触发后 `triggered = true`，不会再次触发。
> **移除 vs 触发**：`triggered` 表示标记效果已执行（一次性）；`removed` 表示标记已从地块上移除（不再参与任务胜利条件检查）。两者独立：已触发的标记仍可被移除（如任务 12 标记触发后还需用大炸药摧毁地块）；未触发的标记也可被直接移除（如炸药移除任务 9 的外星发射器标记）。

### 内部方法

| 方法 | 说明 |
|------|------|
| `_check_objective_mark_remove_conditions()` | 检查所有目标标记的移除条件，满足时移除。由 `remove_monster_mark` / `remove_all_monster_marks` 调用 |

---

## 地图块类型示例

> 完整地块列表见 [MapBlocksPack/MapBlocks.md](../../Resource/MapBlocksPack/MapBlocks.md)。

| 地块名 | 拾荒颜色 | 刷怪点数 | 关键效果 |
|--------|---------|---------|---------|
| 面包车 | — | 6 | 多数任务的出生点与结束点；持有 `van_fuel` 字段 |
| 避难所 | — | 12/2 | 回合开始时不在则本回合受击免疫 |
| 军事基地 | 红、蓝 | 0 | 进入时造成伤害 |
| 监狱 | 红、绿、蓝 | 9 | 进入时减行动次数 |
| 旷野 | — | 6/8 | 进入时抓怪物 |
| 森林 | — | 5/8 | 同回合内进入又离开 → 抓怪物 |
| 河流 | — | 10/11 | 进入需潜行检定，失败 → 阻止移动 |
| 游乐园 | 红、蓝、绿 | 6 | 回合结束时触发效果 |
| 百货商店 | 绿 | 9 | 展示时免费拾荒 |
| 电厂 | — | 10 | 弃置食物类牌 |
| 机场 | 红、绿 | 8 | 行动：移动到另一个已展示且无怪物标记的地块 |
| 隧道 | — | 10/4 | 行动：移动到另一个已展示的隧道地块 |

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。地块技能通过 Entity 机制挂载与触发 |
| [Player](Player.md) | 玩家位于地块上；地块技能挂载到 Player 身上；玩家移动触发地块钩子 |
| [Game](../Game/Game.md) | Game 管理地图区域（所有存活地块）；Game 负责地图构建、地块查询与摧毁流程 |
| [Skill](../Common/Skill.md) | 地块技能遵循 Skill 结构 |
| [EventBus](../System/EventBus.md) | 发射 `block_revealed` / `monster_mark_changed` / `objective_mark_changed` / `objective_mark_triggered` 信号 |
