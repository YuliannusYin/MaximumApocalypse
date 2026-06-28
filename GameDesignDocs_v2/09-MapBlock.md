# 09 - MapBlock 系统

> MA 的地块系统抽象：25 种地块类型 + 38 个地块实例，由任务卡 `map_layout` 驱动填充到地图网格。
> 数据 = Resource / 实体 = Node2D（不可变 `MapBlockData` + 可变 `MapBlockInstance` 分离，与卡牌系统一致）。
> 本文档只定义基类与方法签名，不含具体地块实现与 skill 表。
> 应用 v1 决策：D3（任务卡内置布局 + 地块随机填充）、D4（25 种类型 / 38 实例）、D12（拾荒牌库空无法拾荒）、D16（怪物标记上限）、D24（地块技能统一为 Skill）。

---

## 1. 设计原则

- **数据 + 状态分离**：`MapBlockData`（Resource，不可变）存类型定义（block_id / scavenger_piles / monster_spawn_value / skill_ids 等）；`MapBlockInstance`（Node2D，可变）存运行时状态（grid_pos / is_revealed / monster_tokens 等）。同一份 `MapBlockData` 可被多个 `MapBlockInstance` 共享（多实例类型如城市街道 3 实例共享同一 data）。
- **MapBlockInstance 继承 Node2D**：地块是地图上的可视对象，进场景树后可挂子节点（地块 Sprite / 怪物标记节点 / 拾荒牌堆可视化等），便于 UI 集成与点击交互。
- **邻接关系由 MapGrid 统一管理**：`MapBlockInstance` 只存 `grid_pos: Vector2i`，邻接查询通过 `MapGrid.get_neighbor(pos, dir)` 集中处理，避免地块间双向引用同步问题（ponytail 风格）。
- **地块效果统一为 Skill**（D24）：所有地块触发效果（展示/进入/离开/行动/结束）均存 `skill_ids: Array[StringName]`，运行时由 `SkillExecutor` 调度（forced=true TRIGGER，自动触发）。
- **25 种地块详细 skill 表引用 v1**：本文档只定义基类与字段签名，25 种地块的详细属性与 skill 表见 [v1 04-地图系统设计.md](../GameDesignDocs_v1/04-地图系统设计.md) 第 5 章，38 实例池见第 6 章。

---

## 2. MapBlockData（Resource，地块类型定义）

```text
class_name MapBlockData extends Resource

# === 公共字段（所有地块类型都有） ===
@export var block_id: StringName                # 唯一标识（跨对象引用 key，如 &"general_store"）
@export var block_name: String                  # UI 显示名（中文，如 "百货商店"）
@export var scavenger_piles: Array[DeckColor] = []  # 拾荒牌堆颜色列表（空=不可拾荒，见第 4 节）
@export var monster_spawn_value: int = 0        # 刷怪骰子匹配值（2D6 点数和，0=安全地块，见第 10 节）
@export var skill_ids: Array[StringName] = []   # 关联技能 ID 列表（forced=true TRIGGER，由 SkillExecutor 调度）
@export var is_starting: bool = false           # 是否起始地块（仅面包车为 true）
@export var is_special: bool = false            # 是否特殊地块（面包车=true，不可被摧毁/移除）
@export var instances_config: Array[Dictionary] = []  # 多实例类型的 override 配置（见 2.1 节）
```

### 2.1 instances_config 字段说明

`instances_config` 存储该类型的多个实例的 override 配置，与 08-MissionCard.md 的 `scavenger_decks` 风格一致（Array[Dictionary]）。

| 场景 | instances_config 值 | 语义 |
|---|---|---|
| 单实例类型（如百货商店） | `[]`（空数组） | 1 个实例，用 data 默认值 |
| 多实例类型（如避难所 2 实例） | `[{...}, {...}]` | 2 个实例，各实例按 Dictionary 配置 override |

每个 Dictionary 的 key：

| key | 类型 | 必填 | 说明 |
|---|---|---|---|
| `"monster_spawn_value"` | int | 是 | 该实例的刷怪值（覆盖 data.monster_spawn_value） |
| `"scavenger_piles"` | Array[DeckColor] | 否 | 该实例的拾荒牌堆颜色（不填则用 data.scavenger_piles） |

**示例**（城市街道 3 实例）：

```text
instances_config = [
    {"monster_spawn_value": 6, "scavenger_piles": [DeckColor.RED]},
    {"monster_spawn_value": 8, "scavenger_piles": [DeckColor.GREEN]},
    {"monster_spawn_value": 5, "scavenger_piles": [DeckColor.BLUE]},
]
```

> instances_config 为空时，MapGenerator 创建 1 个实例并用 data 默认值；非空时，按数组长度创建对应数量实例，各实例按 Dictionary 设置 override。

---

## 3. MapBlockInstance（Node2D，运行时实例）

```text
class_name MapBlockInstance extends Node2D

# === 数据引用 ===
var data: MapBlockData                         # 引用不可变类型数据（多实例共享同一 data）

# === 实例标识与位置 ===
var instance_id: StringName                    # 实例唯一标识（如 &"city_street_2"）
var grid_pos: Vector2i                         # 网格坐标（x=col, y=row，由 MapGrid.set_block 时设置）

# === 运行时状态 ===
var is_revealed: bool = false                  # 是否已展示（背面/正面）
var monster_tokens: int = 0                    # 当前地块上的怪物标记数
var scavenger_pile_remaining: Dictionary = {}  # 各色拾荒牌堆剩余张数（Dictionary[DeckColor, int]，见第 9 节）

# === 实例级 override（从 data.instances_config 读取，-1/空表示用 data 默认值） ===
var monster_spawn_value_override: int = -1     # -1 = 用 data.monster_spawn_value
var scavenger_piles_override: Array[DeckColor] = []  # 空 = 用 data.scavenger_piles

# === 查询方法（合并 override 与 data 默认值） ===

# 获取该实例的拾荒牌堆颜色（override 优先）
func get_scavenger_piles() -> Array[DeckColor]:
    return scavenger_piles_override if not scavenger_piles_override.is_empty() else data.scavenger_piles

# 获取该实例的刷怪值（override 优先）
func get_monster_spawn_value() -> int:
    return monster_spawn_value_override if monster_spawn_value_override >= 0 else data.monster_spawn_value

# 该地块是否可拾荒（任一色堆剩余 > 0）
func can_scavenge() -> bool:
    if get_scavenger_piles().is_empty():
        return false
    for color in get_scavenger_piles():
        if scavenger_pile_remaining.get(color, 0) > 0:
            return true
    return false
```

> 设计取舍：`scavenger_pile_remaining` 存地块级剩余张数，便于 UI 显示"剩余 X 张"。初始化时从 `ScavengerDeckStack` 抓取对应张数填入（见第 9 节）。

---

## 4. DeckColor 枚举（引用 10-Deck.md）

`DeckColor` 枚举定义见 [10-Deck.md](10-Deck.md) 第 4 节，仅 3 值：

```text
enum DeckColor { RED, BLUE, GREEN }
```

| 颜色 | 标识 | 说明 |
|---|---|---|
| 红 | `DeckColor.RED` | 红色拾荒牌堆 |
| 蓝 | `DeckColor.BLUE` | 蓝色拾荒牌堆 |
| 绿 | `DeckColor.GREEN` | 绿色拾荒牌堆 |
| 无 | `[]`（空数组） | 该地块不可拾荒 |

多色地块（如机场 `[RED, GREEN]`）：玩家拾荒时可选择任一未抓空的色堆抓 1 张。

> `DeckColor` 仅 3 值（标识拾荒牌堆），与卡牌大类颜色（红/蓝/绿/灰 4 色大类）是独立概念，见 [04-ScavengerCard.md](04-ScavengerCard.md)。

---

## 5. Direction 枚举

```text
enum Direction {
    NORTH,  # 北（grid_pos.y -= 1）
    SOUTH,  # 南（grid_pos.y += 1）
    EAST,   # 东（grid_pos.x += 1）
    WEST,   # 西（grid_pos.x -= 1）
}
```

4 方向相邻（北/南/东/西），无对角线。

---

## 6. MapGrid（地图网格管理器）

```text
class_name MapGrid extends Node2D

const TILE_SIZE: int = 128  # 每格像素大小（UI 渲染用，可按美术资源调整）

var _blocks: Dictionary = {}  # Dictionary[Vector2i, MapBlockInstance]

# === 基本操作 ===

# 获取指定坐标的地块（无地块返回 null）
func get_block(pos: Vector2i) -> MapBlockInstance:
    return _blocks.get(pos, null)

# 放置地块到指定坐标（设置 grid_pos + Node2D.position + 挂为子节点）
func set_block(pos: Vector2i, block: MapBlockInstance) -> void:
    _blocks[pos] = block
    block.grid_pos = pos
    block.position = _grid_to_world(pos)
    add_child(block)

# 移除地块（从场景树释放 + 从字典删除）
func remove_block(pos: Vector2i) -> void:
    var block = _blocks.get(pos, null)
    if block != null:
        block.queue_free()
        _blocks.erase(pos)

# === 邻接查询 ===

# 获取指定坐标的相邻方向地块（无地块返回 null）
func get_neighbor(pos: Vector2i, dir: Direction) -> MapBlockInstance:
    return get_block(pos + _direction_offset(dir))

# 获取指定坐标的所有相邻地块（跳过空位）
func get_neighbors(pos: Vector2i) -> Array[MapBlockInstance]:
    var result: Array[MapBlockInstance] = []
    for dir in [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]:
        var neighbor = get_neighbor(pos, dir)
        if neighbor != null:
            result.append(neighbor)
    return result

# 判断两坐标是否相邻（曼哈顿距离 = 1）
func is_adjacent(pos_a: Vector2i, pos_b: Vector2i) -> bool:
    var diff = pos_a - pos_b
    return absi(diff.x) + absi(diff.y) == 1

# === 查询所有地块 ===

# 获取所有已展示的地块
func get_revealed_blocks() -> Array[MapBlockInstance]:
    var result: Array[MapBlockInstance] = []
    for pos in _blocks:
        var block = _blocks[pos]
        if block.is_revealed:
            result.append(block)
    return result

# 获取所有地块（含未展示）
func get_all_blocks() -> Array[MapBlockInstance]:
    return _blocks.values()

# 获取指定类型的所有实例
func get_blocks_by_type(block_id: StringName) -> Array[MapBlockInstance]:
    var result: Array[MapBlockInstance] = []
    for pos in _blocks:
        var block = _blocks[pos]
        if block.data.block_id == block_id:
            result.append(block)
    return result

# === 全局统计 ===

# 全局怪物标记总数（用于 D16 上限判定）
func get_total_monster_tokens() -> int:
    var total = 0
    for pos in _blocks:
        total += _blocks[pos].monster_tokens
    return total

# === 内部工具 ===

func _direction_offset(dir: Direction) -> Vector2i:
    match dir:
        Direction.NORTH: return Vector2i(0, -1)
        Direction.SOUTH: return Vector2i(0, 1)
        Direction.EAST: return Vector2i(1, 0)
        Direction.WEST: return Vector2i(-1, 0)
    return Vector2i.ZERO

func _grid_to_world(pos: Vector2i) -> Vector2:
    return Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)
```

---

## 7. 地块触发时机（TriggerTiming 增补）

01-Skill.md 的 `TriggerTiming` 枚举需追加以下地块专用时机（与 ON_HEAL / ON_DEATH 一起作为遗留更新，见第 14 节 Q1）：

```text
TriggerTiming (增补) =
    ON_REVEAL |              # 地块被展示时（翻面）
    ON_ENTER |               # 玩家进入地块时
    ON_LEAVE |               # 玩家离开地块时
    ON_ACTION |              # 玩家在地块上消耗行动执行地块行动
    ON_TURN_END_ON_BLOCK     # 玩家在此地块上结束回合时
```

| 触发时机 | 原版关键词 | 说明 |
|---|---|---|
| `ON_REVEAL` | 展示 | 地块从背面翻为正面时触发 |
| `ON_ENTER` | 进入 | 玩家移动进入已展示地块时触发 |
| `ON_LEAVE` | 离开 | 玩家从地块移动到相邻地块时触发 |
| `ON_ACTION` | 行动 | 玩家在地块上消耗 1 行动执行地块特殊行动（如机场、隧道） |
| `ON_TURN_END_ON_BLOCK` | 结束（在此地块上） | 玩家在此地块上结束回合时触发 |

> 完整 TriggerTiming 枚举合并：01-Skill.md 原 13 项 + 本节 5 项 + ON_HEAL + ON_DEATH = 20 项（待统一更新）。

---

## 8. 地块填充算法（D3）

### 8.1 决策概述（D3）

PC 版采用**任务卡内置布局 + 地块随机填充**策略：

- 任务卡 `map_layout` 字段存储二维数组，定义地图形状（固定排版）
- 地块内容从 38 个实例池随机抽取填充（保留重玩性）
- 程序化随机生成接口保留为未来扩展（见 8.5 节）

### 8.2 map_layout 数组值含义

| 值 | 含义 | 填充逻辑 |
|---|---|---|
| `0` | 空位 | 不放置地块 |
| `1` | 任意地块 | 从剩余实例池随机抽取一个实例 |
| `2` | 面包车 | 从实例池取 `van` 实例，标记 `is_revealed=true` |
| `3` | 必需地块占位 | 从 `required_blocks` 队首取一个类型，从该类型实例池随机选一个实例 |

> `map_layout` 字段定义见 [08-MissionCard.md](08-MissionCard.md) 第 4 节。`required_blocks` 与 `starting_block` 同在任务卡定义。

### 8.3 填充算法步骤

```text
输入：mission_data.map_layout, mission_data.required_blocks, mission_data.starting_block
输出：map_grid (MapGrid，已填充地块)

1. 初始化：
   - instance_pool ← build_instance_pool()  # 从所有 MapBlockData 构建 38 实例池（见 8.4）
   - required_queue ← mission_data.required_blocks 转为队列
   - map_grid ← MapGrid.new()

2. 遍历 map_layout（按行优先，y=row, x=col）：
   for y in range(map_layout.size()):
     for x in range(map_layout[y].size()):
       value = map_layout[y][x]
       pos = Vector2i(x, y)
       if value == 0:
         continue  # 空位
       elif value == 2:  # 面包车
         van = instance_pool.find_by_block_id(&"van")
         van.is_revealed = true
         map_grid.set_block(pos, van)
         instance_pool.remove(van)
       elif value == 3:  # 必需地块占位
         block_type = required_queue.pop_front()
         candidates = instance_pool.filter_by_block_id(block_type)
         if candidates.is_empty():
           push_error("必需地块实例不足: " + block_type)
         instance = candidates.pick_random()
         # 起始地块标记为已展示
         if block_type == mission_data.starting_block:
           instance.is_revealed = true
         map_grid.set_block(pos, instance)
         instance_pool.remove(instance)
       elif value == 1:  # 任意地块
         instance = instance_pool.pick_random()
         map_grid.set_block(pos, instance)
         instance_pool.remove(instance)

3. 验证：
   - required_queue 为空？（所有必需地块已放置）
   - 地块池实例数足够？（非空格子数 ≤ 38）
   - 所有非空地块从面包车可达（连通性，BFS 校验）

4. 返回 map_grid
```

### 8.4 实例池构建

```text
# 从 CardRegistry 扫描所有 MapBlockData，按 instances_config 构建实例池
static func build_instance_pool() -> Array[MapBlockInstance]:
    var pool: Array[MapBlockInstance] = []
    var all_block_data = CardRegistry.get_all_block_data()  # 扫描 res://data/map_blocks/ 下 .tres
    for data in all_block_data:
        if data.instances_config.is_empty():
            # 单实例类型：创建 1 个实例，用 data 默认值
            var instance = MapBlockInstance.new()
            instance.data = data
            instance.instance_id = _make_instance_id(data.block_id, 1)
            pool.append(instance)
        else:
            # 多实例类型：按 instances_config 创建 N 个实例
            for i in range(data.instances_config.size()):
                var config = data.instances_config[i]
                var instance = MapBlockInstance.new()
                instance.data = data
                instance.instance_id = _make_instance_id(data.block_id, i + 1)
                instance.monster_spawn_value_override = config.get("monster_spawn_value", -1)
                if config.has("scavenger_piles"):
                    instance.scavenger_piles_override = config["scavenger_piles"]
                pool.append(instance)
    return pool

static func _make_instance_id(block_id: StringName, index: int) -> StringName:
    return StringName(str(block_id) + "_" + str(index))
```

### 8.5 程序化随机生成接口（未来扩展）

保留接口 signature：

```text
generate_map(map_size: Vector2i, required_blocks: Array[StringName], min_distance_to_van: int, seed: int) -> MapGrid
```

MVP 阶段不实现，仅保留接口签名。未来玩家可选"内置布局"（使用任务卡 `map_layout`）或"随机生成"（调用此接口）。

---

## 9. 地块拾荒系统

### 9.1 拾荒牌堆初始化

地块实例初始化时，按 `get_scavenger_piles()` 从 `ScavengerDeckStack` 抓取对应张数填入 `scavenger_pile_remaining`：

```text
# 地块拾荒牌堆初始化（由 GameSession 在地图填充后调用）
func init_scavenger_piles(block: MapBlockInstance, deck_stack: ScavengerDeckStack) -> void:
    for color in block.get_scavenger_piles():
        # 从全局拾荒牌堆抓取该色堆的牌放入地块
        # 注意：地块不存具体卡牌实例，只存剩余张数（卡牌实例由 ScavengerDeckStack 管理）
        # 抓取时由 ScavengerDeckStack.draw(color) 返回 CardInstance，玩家拾荒时再抓
        block.scavenger_pile_remaining[color] = deck_stack.get_remaining_count(color)
```

> 实现要点：地块的 `scavenger_pile_remaining` 是"该色堆还有多少张"的计数，实际卡牌实例存在 `ScavengerDeckStack` 中。玩家拾荒时 `ScavengerDeckStack.draw(color)` 抓取卡牌，同时 `scavenger_pile_remaining[color] -= 1`。

### 9.2 拾荒行动定义

| 行动类型 | 消耗 | 触发 | 说明 |
|---|---|---|---|
| 标准拾荒 | 1 行动点 | 玩家主动 | 从当前地块任一未抓空的色堆抓 1 张拾荒卡到手牌 |
| 免费拾荒 | 0 行动点 | `free_scavenge_once` 效果 | 不消耗行动点，从当前地块任一未抓空的色堆抓 1 张 |

- 多色地块：玩家弹窗选择 1 个未抓空的色堆
- 某色堆 `scavenger_pile_remaining[color] == 0` 时该色不可拾（D12）
- 地块所有色堆都抓空时 `can_scavenge()` 返回 false，地块拾荒标记 UI 变灰

### 9.3 拾荒卡进入手牌

按 D9：拾荒到的装备卡先进**手牌**（占手牌位），后续需消耗 1 行动"使用"才能装备到装备区。例外：燃料卡（D5）抓取时立即三选一，不进手牌。

详见 [04-ScavengerCard.md](04-ScavengerCard.md) 与 [02-Card.md](02-Card.md) 第 10 节。

---

## 10. 怪物出生阶段（monster_spawn_value）

### 10.1 字段含义

`monster_spawn_value` = **骰子点数匹配值**（范围 0-12）。

在每个玩家回合的**"怪物出生"阶段**：

```text
1. 玩家投掷 2 颗大骰子
2. 记两骰点数之和为 X（范围 2-12）
3. 在每个正面朝上（is_revealed=true）且 get_monster_spawn_value() == X 的地块上
   放置 1 个怪物标记（monster_tokens += 1）
```

特殊值：
- `0`（军事基地）：永不通过骰子机制放置怪物标记（安全地块）
- 数值 2-12 对应 2 颗大骰子点数和的取值范围

### 10.2 怪物标记来源

| 来源 | 触发 | 说明 |
|---|---|---|
| 主要来源 | 怪物出生阶段骰子匹配 | 见 10.1 |
| 工厂 ON_REVEAL | `factory_spread_monsters` | 向所有相邻地块各增加 1 个怪物标记 |
| 卡牌效果 | 部分卡牌 skill | 如钉子炸弹、无人机攻击可手动添加/移除 |

### 10.3 怪物标记 vs 怪物卡

| 维度 | 怪物标记（Monster Token） | 怪物卡（Monster Card） |
|---|---|---|
| 来源 | 地块出生阶段骰子匹配 / 卡牌效果 | 玩家抓怪物卡（如城市街道 ON_ENTER） |
| 位置 | 地块上（不纠缠玩家） | 玩家面前（纠缠玩家，见 R3） |
| 攻击 | 不主动攻击 | 在玩家回合结束自动攻击纠缠玩家 |
| 处理 | 卡牌效果可移除（如无人机攻击） | 玩家攻击消灭 / 卡牌效果赶走 |

> 怪物标记与怪物卡是两个独立系统，不互相转化（D11 修正原版）。

### 10.4 怪物标记上限（D16）

- 全局怪物标记总数 ≥ 上限（默认 30）→ 玩家失败
- 上限由 `MissionCardData.monster_token_limit` 字段配置（见 [08-MissionCard.md](08-MissionCard.md)）
- `MapGrid.get_total_monster_tokens()` 提供全局统计
- UI：地图边缘显示当前标记数 / 上限

---

## 11. SkillExecutor 集成

### 11.1 SkillExecutor 扫描范围扩展

SkillExecutor 扫描对象需包含地块（见 v1 04-地图系统设计.md 第 10.1 节）：

```text
扫描对象 = [
    当前回合玩家,
    玩家装备区所有装备,
    玩家当前所在地块（MapBlockInstance）,    # ← 地块技能
    玩家所在地块上的所有怪物标记,
    玩家面前所有纠缠怪物,
]
```

### 11.2 地块事件触发流程

```text
1. 玩家执行"展示相邻地块"操作
   ↓
2. SkillExecutor 发出 ON_REVEAL 事件，target = 被展示的 MapBlockInstance
   ↓
3. SkillExecutor 扫描该地块的 data.skill_ids
   ↓
4. 对每个 trigger_timing == ON_REVEAL 的 Skill：
   - ConditionChecker 检查 condition
   - 通过 → 调用 EffectHandler[effect_id]
   ↓
5. 玩家移动进入该地块
   ↓
6. SkillExecutor 发出 ON_ENTER 事件 → 同流程触发 ON_ENTER 技能
```

### 11.3 ON_LEAVE 时序问题

森林"穿越抓怪"（`forest_pass_through`，ON_LEAVE）的特殊时序：

```text
玩家从森林 A 移动到地块 B
  ↓
1. ON_LEAVE 事件触发（target=森林 A）
   → 触发 forest_pass_through，但需检查 condition："本回合进入过森林 A"
   → 满足 → draw_monster_1
2. ON_ENTER 事件触发（target=地块 B）
   → 触发地块 B 的 ON_ENTER 技能
```

> ConditionChecker 需记录玩家本回合的"进入历史"列表 `entered_blocks_this_turn: Array[StringName]`。

---

## 12. 25 种地块类型索引

本文档只定义基类与字段签名，25 种地块的详细属性与 skill 表见 [v1 04-地图系统设计.md](../GameDesignDocs_v1/04-地图系统设计.md) 第 5 章。

| block_id | block_name | 章节引用 |
|---|---|---|
| `general_store` | 百货商店 | v1 5.1 |
| `shelter` | 避难所 | v1 5.2 |
| `city_street` | 城市街道 | v1 5.3 |
| `power_plant` | 电厂 | v1 5.4 |
| `river` | 河流 | v1 5.5 |
| `airport` | 机场 | v1 5.6 |
| `police_station` | 警察局 | v1 5.7 |
| `military_base` | 军事基地 | v1 5.8 |
| `prison` | 监狱 | v1 5.9 |
| `wasteland` | 旷野 | v1 5.10 |
| `factory` | 工厂 | v1 5.11 |
| `mall` | 购物中心 | v1 5.12 |
| `gas_station` | 加油站 | v1 5.13 |
| `oasis` | 绿洲 | v1 5.14 |
| `van` | 面包车（起始地块） | v1 5.15 |
| `graveyard` | 墓地 | v1 5.16 |
| `farm` | 农场 | v1 5.17 |
| `raider_camp` | 强盗营地 | v1 5.18 |
| `mountain` | 山 | v1 5.19 |
| `tunnel` | 隧道 | v1 5.20 |
| `forest` | 森林 | v1 5.21 |
| `desert` | 沙漠 | v1 5.22 |
| `amusement_park` | 游乐园 | v1 5.23 |
| `hospital` | 医院 | v1 5.24 |
| `crash_site` | 坠毁点 | v1 5.25 |

---

## 13. 38 个地块实例池

38 个地块实例（25 种类型）的完整配置表见 [v1 04-地图系统设计.md](../GameDesignDocs_v1/04-地图系统设计.md) 第 6 章。

实例池由 `MapGrid.build_instance_pool()` 从 `MapBlockData.instances_config` 构建（见 8.4 节）。城市街道 3 实例的 `scavenger_piles_override` 配置见 v1 6.1 节（方案 B：实例级覆盖）。

---

## 14. 待定问题

### Q1. 遗留：TriggerTiming 枚举同步

01-Skill.md 的 `TriggerTiming` 枚举需追加以下时机（用户决策"先放着"，与 ON_HEAL / ON_DEATH 一起更新）：

- `ON_HEAL`（06-Entity.md Q1）
- `ON_DEATH`（06-Entity.md Q2）
- `ON_REVEAL` / `ON_ENTER` / `ON_LEAVE` / `ON_ACTION` / `ON_TURN_END_ON_BLOCK`（本文档第 7 节）

合并后 TriggerTiming 枚举共 20 项（原 13 + 增补 7）。

### Q2. instances_config 数据结构确认

当前 `instances_config: Array[Dictionary]` 与 08-MissionCard.md 的 `scavenger_decks` 风格一致。是否需要改为独立 Resource 子类（如 `BlockInstanceConfig`）以便 .tres 编辑器可视化编辑？

- 当前方案：Array[Dictionary]，简单但 .tres 编辑器中无法可视化
- 备选方案：独立 `BlockInstanceConfig extends Resource` 子类，含 `monster_spawn_value: int` + `scavenger_piles: Array[DeckColor]` 字段

> 待确认是否与 08-MissionCard.md 的 BossConfig / TargetMarkerConfig 保持一致（独立 Resource 子类）。

### Q3. TILE_SIZE 常量

`MapGrid.TILE_SIZE` 当前硬编码为 128 像素，实际值待美术资源确定后调整。是否需要改为配置项？

### Q4. 程序化随机生成接口

第 8.5 节的 `generate_map()` 接口 MVP 阶段不实现。是否需要在本文档定义完整签名，还是仅保留为未来扩展备注？

### Q5. 骰子机制

"大骰子"与战斗/潜行检定的骰子关系待确认（详见未来战斗系统设计文档）。"怪物出生阶段"在玩家回合中的时序位置待 GameSession 文档确认（建议位于回合结束效果之后，见 R2）。

### Q6. 任务 6 核辐射扩散机制

原版"投出 7 时展示/移除外围地块"的"外围"如何定义？

- 建议方案：BFS 从面包车（地图中心）扩展，最外层非空地块为"外围"
- 待确认"外围"的精确定义

---

## 附：决策应用索引

本文档应用的决策：

- D3 任务卡内置布局 + 地块随机填充（`map_layout` 字段 + 实例池随机抽取）
- D4 仅用 MapBlocks.md（25 种地块类型，38 个地块实例）
- D7 `remove()` / `discard()` 术语统一（地块摧毁用 `remove_block()`）
- D11 怪物标记 vs 怪物卡分离（两个独立系统，不互相转化）
- D12 拾荒牌库空无法拾荒（`can_scavenge()` 返回 false）
- D16 怪物标记上限由任务卡配置（`get_total_monster_tokens()` 统计）
- D24 Skill 通用技能系统（地块技能统一为 `skill_ids` + SkillExecutor 调度）
- R2 回合结束顺序（地块→饥饿→怪物）
- R3 怪物纠缠机制（怪物卡纠缠玩家，怪物标记不纠缠）
