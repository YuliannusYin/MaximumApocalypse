# 数据格式规范

> 本文档定义 Resource 数据（卡牌/地图/任务）从设计 markdown 到运行时 JSON 的转换规范、JSON Schema、数据加载流程与验证规则。
> **设计源**：`GameDesignDocus/Resource/` 下的 markdown 文件（人类可读的设计文档）
> **运行时数据**：`data/` 下的 JSON 文件（Godot 解析的机器可读数据）
> **转换工具**：`tools/markdown_to_json.gd`（待实现）

---

## 一、数据流

```
GameDesignDocus/Resource/*.md   →   tools/markdown_to_json.gd   →   data/*.json   →   DataManager.load()
     (设计源 markdown)                  (转换工具)                    (运行时 JSON)        (运行时加载)
```

### 转换时机

- **开发期**：手动运行 `tools/markdown_to_json.gd` 将 markdown 转为 JSON
- **后续可选**：在 Godot 导入流程中自动转换（通过 EditorPlugin）

### 为什么不直接解析 markdown

1. **解析复杂**：markdown 格式灵活，直接解析需处理多种变体
2. **运行时性能**：JSON 解析比 markdown 解析快 10 倍以上
3. **类型安全**：JSON Schema 可验证数据完整性，markdown 难以验证
4. **Godot 原生支持**：Godot 有内置 JSON 解析器，无需第三方库

---

## 二、JSON Schema 定义

### 2.1 求生者数据（survivors/*.json）

对应设计文档：[Resource/SurvivorPacks/](../Resource/SurvivorPacks/)

```json
{
  "$schema": "survivor",
  "character_name": "消防员",
  "english_name": "firefighter",
  "max_hp": 5,
  "initial_hp": 5,
  "stealth": 2,
  "hunger_stealth": 1,
  "intrinsic_skills": [
    {
      "skill_name": "防火服",
      "skill_description": "受到的伤害减少1点",
      "trigger": "受到伤害时",
      "forced": true,
      "filter": "return event.type == 'damage'",
      "content": "event.num = max(event.num - 1, 0)"
    }
  ],
  "deck": [
    {
      "card_name": "消防斧",
      "english_name": "fire_axe",
      "count": 2,
      "card_type": "equipment",
      "size": 2,
      "skills": [
        {
          "skill_name": "劈砍",
          "skill_description": "对1个短距离内的怪物造成2点伤害",
          "active": "行动阶段",
          "filter": "return player.in_phase == 'action' && player.action_count > 0",
          "filter_target_range": "short",
          "content": "player.consume_action(1); target.take_damage(2, player, 'melee', self)"
        }
      ]
    }
  ]
}
```

#### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| character_name | String | 是 | 角色中文名 |
| english_name | String | 是 | 角色英文名（用作代码标识符） |
| max_hp | Int | 是 | 生命值上限 |
| initial_hp | Int | 是 | 初始生命值 |
| stealth | Int | 是 | 潜行值 |
| hunger_stealth | Int | 是 | 饥饿状态潜行值 |
| intrinsic_skills | Array | 是 | 角色固有技能列表 |
| deck | Array | 是 | 角色专属游戏牌堆 |

### 2.2 拾荒牌堆数据（scavenge/*.json）

对应设计文档：[Resource/ScavengePacks/](../Resource/ScavengePacks/)

```json
{
  "$schema": "scavenge_pile",
  "color": "blue",
  "category": "战备",
  "cards": [
    {
      "card_name": "手枪",
      "english_name": "pistol",
      "card_type": "equipment",
      "size": 1,
      "charge_type": "ammo",
      "charge_max": 3,
      "charge_initial": 2,
      "skills": [
        {
          "skill_name": "射击",
          "skill_description": "对1个中距离内的怪物造成1点伤害",
          "active": "行动阶段",
          "filter": "return player.in_phase == 'action' && player.action_count > 0",
          "filter_target_range": "medium",
          "content": "player.consume_action(1); player.consume_charge(self, 1); target.take_damage(1, player, 'ranged', self)"
        }
      ]
    }
  ]
}
```

#### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| color | String | 是 | 颜色：`red` / `green` / `blue` / `gray` |
| category | String | 是 | 大类：`战备` / `日常` / `通用` |
| cards | Array | 是 | 拾荒卡列表 |
| cards[].card_name | String | 是 | 卡牌中文名 |
| cards[].english_name | String | 是 | 卡牌英文名 |
| cards[].card_type | String | 是 | 类型：`action` / `equipment` |
| cards[].size | Int | 否 | 装备牌占格数（仅装备牌） |
| cards[].charge_type | String | 否 | 填充物类型（仅装备牌） |
| cards[].charge_max | Int | 否 | 填充物上限（仅装备牌） |
| cards[].charge_initial | Int | 否 | 初始填充物数（仅装备牌） |
| cards[].value | Int | 否 | 数值（弹药数/食物恢复量等） |
| cards[].skills | Array | 否 | 技能列表 |

### 2.3 怪物包数据（monsters/*.json）

对应设计文档：[Resource/MonsterPacks/](../Resource/MonsterPacks/)

```json
{
  "$schema": "monster_pack",
  "monster_type": "zombie",
  "monsters": [
    {
      "monster_name": "步行者",
      "english_name": "walker",
      "monster_level": "normal",
      "max_hp": 2,
      "initial_hp": 2,
      "attack_damage": 1,
      "range": "none",
      "skills": []
    },
    {
      "monster_name": "喷吐者",
      "english_name": "spitter",
      "monster_level": "elite",
      "max_hp": 3,
      "initial_hp": 3,
      "attack_damage": 2,
      "range": "short",
      "skills": [
        {
          "skill_name": "腐蚀喷吐",
          "skill_description": "攻击时附加1点中毒标记",
          "trigger": "怪物攻击时",
          "content": "event.target.add_mark('poison', 1)"
        }
      ]
    },
    {
      "monster_name": "僵尸王",
      "english_name": "zombie_king",
      "monster_level": "boss",
      "max_hp": 6,
      "initial_hp": 6,
      "attack_damage": 3,
      "range": "medium",
      "skills": [...]
    }
  ]
}
```

#### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| monster_type | String | 是 | 怪物类型：`alien` / `mutant` / `zombie` / `robot` |
| monsters | Array | 是 | 怪物卡列表 |
| monsters[].monster_level | String | 是 | 级别：`boss` / `elite` / `normal` |
| monsters[].range | String | 是 | 射程：`none` / `short` / `medium` / `long` / `infinity` |

### 2.4 任务包数据（missions/*.json）

对应设计文档：[Resource/MissionPacks/](../Resource/MissionPacks/)

```json
{
  "$schema": "mission",
  "mission_id": 5,
  "mission_name": "拆除炸弹",
  "english_name": "defuse_bomb",
  "difficulty": "normal",
  "van_fuel_required": 3,
  "intro_text": "上一组求生者...",
  "objective_text": "目标：找到满是灰尘的日记本...",
  "special_setup": "设置：把一个目标标记...",
  "monster_pack_type": "mutant",
  "map_blocks_config": {
    "加油站": 2,
    "旷野": 2,
    "避难所": 2
  },
  "map_layout": [
    [-1, -1, 1, 1, 2],
    [0, 1, 1, -1, 1],
    [-1, 1, 3, 1, -1]
  ],
  "map_legend": {
    "-1": "no_block",
    "0": { "type": "spawn", "block_name": "面包车" },
    "1": "random_block",
    "2": { "type": "game_end", "block_name": "面包车" },
    "3": { "type": "marked_block" }
  },
  "objective_marks": [
    {
      "mark_id": "mark_1",
      "mark_description": "找到日记本",
      "initial_monster_marks": 0,
      "remove_condition": null,
      "effect_code": "player.collect_item('dusty_diary', 1); player.draw_boss_card()"
    }
  ],
  "scavenge_config": {
    "red": [
      { "card_name": "食物", "count": 2 },
      { "card_name": "燃料", "count": 2 }
    ],
    "green": [...],
    "blue": [...]
  },
  "win_condition_code": "return player.has_item('dusty_diary') && game.mission_state.get('bomb_defused') == true && game.mission_state.get('turns_after_defuse') <= 3"
}
```

#### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mission_id | Int | 是 | 任务编号（0-12） |
| van_fuel_required | Int / null | 是 | 启动面包车所需燃料，`null` 表示不通过面包车胜利 |
| difficulty | String | 是 | 难度：`very_easy` / `easy` / `normal` / `hard` / `very_hard` / `tutorial` |
| map_layout | Array<Array<Int>> | 是 | 默认地图二维数组 |
| map_legend | Dict | 是 | 编号说明 |
| objective_marks | Array | 否 | 目标标记定义 |
| win_condition_code | String | 是 | 胜利条件代码（GDScript 表达式，`game.检查任务胜利条件()` 执行） |

> **关于 effect_code / win_condition_code**：这些是 GDScript 代码字符串，运行时通过 `eval()` 或 `Expression` 类执行。需注意安全沙箱（仅允许调用白名单 API）。

### 2.5 地图块数据（map_blocks/map_blocks.json）

对应设计文档：[Resource/MapBlocksPack/MapBlocks.md](../Resource/MapBlocksPack/MapBlocks.md)

```json
{
  "$schema": "map_blocks",
  "blocks": [
    {
      "block_name": "购物中心",
      "english_name": "shopping_mall",
      "scavenge_colors": ["red", "green", "blue"],
      "monster_spawn_value": 2,
      "skills": [
        {
          "skill_name": "拾荒",
          "skill_description": "玩家可拾荒红/绿/蓝色牌堆",
          "trigger": "进入地块时",
          "content": "..."
        }
      ]
    }
  ]
}
```

#### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| block_name | String | 是 | 地图块中文名 |
| english_name | String | 是 | 地图块英文名 |
| scavenge_colors | Array<String> | 是 | 可拾荒颜色集合 |
| monster_spawn_value | Int | 是 | 怪物生成点数 |
| skills | Array | 否 | 地块技能列表 |

---

## 三、技能结构 JSON Schema

所有卡牌/角色/地块的技能均遵循统一结构：

```json
{
  "skill_name": "射击",
  "english_name": "shoot",
  "skill_description": "对目标造成1点伤害",
  "active": "行动阶段",
  "trigger": null,
  "skill_type": "equipment",
  "forced": false,
  "filter": "return player.in_phase == 'action' && player.action_count > 0",
  "filter_target": "return target.is_monster() && target.is_alive()",
  "filter_target_range": "medium",
  "filter_card": null,
  "position": null,
  "select_card": 0,
  "select_target": 1,
  "range": null,
  "usable": null,
  "content": "player.consume_action(1); player.consume_charge(self, 1); target.take_damage(1, player, 'ranged', self)"
}
```

### 技能字段映射

| 设计文档字段 | JSON 字段 | 类型 | 说明 |
|-------------|----------|------|------|
| 技能名 | skill_name | String | 中文名 |
| — | english_name | String | 英文名（代码标识符） |
| 技能描述 | skill_description | String | 自然语言描述 |
| active | active | String / null | 可用阶段 |
| trigger | trigger | String / null | 触发名（英文，见 [IdentifierMapping.md](IdentifierMapping.md)） |
| skillType | skill_type | String / null | 技能类型 |
| forced | forced | Bool | 是否强制发动 |
| filter | filter | String / null | 过滤函数代码 |
| filterTarget | filter_target | String / null | 目标过滤函数代码 |
| filterTargetRange | filter_target_range | String / null | 目标距离限制 |
| filterCard | filter_card | String / null | 选牌过滤函数代码 |
| position | position | String / null | 选牌位置限定 |
| selectCard | select_card | Int | 需选择牌数 |
| selectTarget | select_target | Int | 需选择目标数 |
| 射程 | range | String / null | 攻击射程 |
| usable | usable | Int / null | 每回合可用次数 |
| content | content | String | 技能效果代码 |

> **代码字段**（filter / filter_target / filter_card / content / effect_code / win_condition_code）均为 GDScript 代码字符串，运行时通过 `Expression` 类编译执行。需建立安全沙箱，仅允许调用白名单 API（Player/Game/Monster/MapBlock 的公开方法）。

---

## 四、枚举值映射

JSON 中所有枚举值使用英文小写，对应关系见 [IdentifierMapping.md](IdentifierMapping.md)：

| 枚举类别 | 设计文档值 | JSON 值 |
|---------|----------|---------|
| 怪物级别 | 首领 / 精英 / 普通 | `boss` / `elite` / `normal` |
| 怪物类型 | 外星人 / 突变体 / 僵尸 / 机器人 | `alien` / `mutant` / `zombie` / `robot` |
| 射程 | 无 / 短距离 / 中距离 / 长距离 / Infinity | `none` / `short` / `medium` / `long` / `infinity` |
| 拾荒颜色 | 红色 / 绿色 / 蓝色 / 灰色 | `red` / `green` / `blue` / `gray` |
| 卡牌类型 | 行动 / 装备 | `action` / `equipment` |
| 任务难度 | 特别简单 / 非常简单 / 简单 / 正常 / 困难 / 非常困难 | `tutorial` / `very_easy` / `easy` / `normal` / `hard` / `very_hard` |
| 回合阶段 | 回合外 / 回合开始 / ... | `out_of_turn` / `turn_start` / ... |

---

## 五、数据加载流程

### 5.1 DataManager 设计

```gdscript
# src/data/data_manager.gd
extends Node

# 已加载的数据缓存
var _survivors: Dictionary = {}      # english_name -> SurvivorData
var _scavenge_piles: Dictionary = {}  # color -> Array[ScavengeCardData]
var _monster_packs: Dictionary = {}   # monster_type -> Array[MonsterCardData]
var _missions: Dictionary = {}        # mission_id -> MissionData
var _map_blocks: Dictionary = {}      # english_name -> MapBlockData

func _ready() -> void:
    _load_all()

func _load_all() -> void:
    _load_survivors()
    _load_scavenge_piles()
    _load_monster_packs()
    _load_missions()
    _load_map_blocks()

func _load_survivors() -> void:
    var dir := DirAccess.open("res://data/survivors/")
    for file in dir.get_files():
        if file.ends_with(".json"):
            var data := _load_json("res://data/survivors/" + file)
            var survivor := SurvivorData.new(data)
            _survivors[survivor.english_name] = survivor

func _load_json(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    var text := file.get_as_text()
    file.close()
    return JSON.parse_string(text)

# 公开查询接口
func get_survivor(english_name: String) -> SurvivorData:
    return _survivors[english_name]

func get_mission(mission_id: int) -> MissionData:
    return _missions[mission_id]

func get_scavenge_pile(color: String) -> Array:
    return _scavenge_piles[color]
```

### 5.2 数据类设计

每种数据对应一个数据类（RefCounted），封装 JSON 解析与运行时查询：

```gdscript
# src/data/survivor_data.gd
class_name SurvivorData extends RefCounted

var character_name: String
var english_name: String
var max_hp: int
var initial_hp: int
var stealth: int
var hunger_stealth: int
var intrinsic_skills: Array[SkillData]
var deck_config: Array  # [{card_name, count}]

func _init(data: Dictionary) -> void:
    character_name = data["character_name"]
    english_name = data["english_name"]
    max_hp = data["max_hp"]
    # ... 其余字段
```

### 5.3 运行时实例化

数据类是**静态配置**（不可变），运行时通过工厂方法创建**运行时实例**：

```gdscript
# 从数据创建 Player 实例
func create_player(survivor_data: SurvivorData) -> Player:
    var player := Player.new()
    player.character_name = survivor_data.character_name
    player.max_hp = survivor_data.max_hp
    player.hp = survivor_data.initial_hp
    player.stealth = survivor_data.stealth
    # 加载固有技能
    for skill_data in survivor_data.intrinsic_skills:
        player.add_skill(create_skill(skill_data))
    # 构建游戏牌堆
    player.game_deck = create_deck(survivor_data.deck_config)
    return player
```

---

## 六、数据验证规则

### 6.1 加载时验证

`tools/data_validator.gd` 在加载时检查：

| 验证项 | 规则 | 错误级别 |
|--------|------|---------|
| 必填字段 | Schema 中标记为必填的字段不能缺失 | Error（加载失败） |
| 类型检查 | 字段类型必须匹配 Schema | Error |
| 枚举值检查 | 枚举字段值必须在允许列表内 | Error |
| 引用完整性 | 卡牌/地块/任务的引用必须存在 | Error |
| 数值范围 | HP/伤害/数量等必须 > 0 | Warning |
| 技能代码语法 | filter/content 代码必须可编译 | Error |
| 牌堆数量 | 任务拾荒牌堆配置的牌总数符合预期 | Warning |

### 6.2 引用完整性检查

| 引用 | 检查规则 |
|------|---------|
| 任务包 → 怪物包 | `mission.monster_pack_type` 必须存在于 monsters/ 目录 |
| 任务包 → 地图块 | `map_legend` 中指定的 block_name 必须存在于 map_blocks.json |
| 任务包 → 拾荒牌 | `scavenge_config` 中的 card_name 必须存在于对应颜色的 scavenge/*.json |
| 技能 content → API | content 代码中调用的方法必须存在于 Player/Monster/Game 等类 |

### 6.3 验证工具用法

```bash
# 命令行运行验证工具
godot --headless --script tools/data_validator.gd -- --validate-all

# 输出示例
[OK] data/survivors/firefighter.json - valid
[OK] data/missions/mission_5.json - valid
[WARNING] data/monsters/zombie.json - boss card 'zombie_king' has no skills
[ERROR] data/missions/mission_8.json - references unknown block 'military_base'
```

---

## 七、markdown → JSON 转换规范

### 7.1 转换工具

`tools/markdown_to_json.gd` 解析 `GameDesignDocus/Resource/*.md`，输出 `data/*.json`。

### 7.2 转换规则

| markdown 元素 | JSON 元素 | 说明 |
|--------------|----------|------|
| `# 任务卡5` | `mission_id: 5` | 从标题提取编号 |
| `## 任务名` 下的文本 | `mission_name` | 章节内容 |
| `## 启动面包车所需燃料` 下的文本 | `van_fuel_required` | 解析数值或 NULL |
| `## 任务怪物包类型` 下的文本 | `monster_pack_type` | 直接映射 |
| `## 任务地图块配置` 下的 `地名 ×N` | `map_blocks_config: {地名: N}` | 解析数量 |
| `## 任务地图要求` 下的二维数组 | `map_layout` | 解析为二维数组 |
| `## 目标标记定义` 下的代码块 | `objective_marks` | 解析标记定义 |
| `## 任务拾荒牌堆配置` 下的 `牌名 ×N` | `scavenge_config` | 按颜色分组 |
| `Skill{ ... }` 代码块 | skill 对象 | 解析技能字段 |
| `filter: return ...` | `filter: "return ..."` | 代码转为字符串 |

### 7.3 转换流程

```
1. 读取 markdown 文件
2. 按 ## 标题分章节
3. 每章节内容按规则解析为 JSON 字段
4. 代码块（```gdscript）提取为代码字符串
5. 枚举值翻译为英文（中文 → 英文）
6. 输出 JSON 文件到 data/ 目录
7. 运行数据验证
```

---

## 八、与其他文档的关系

| 文档 | 说明 |
|------|------|
| [GodotProjectStructure.md](GodotProjectStructure.md) | 项目目录结构与 autoload 配置 |
| [IdentifierMapping.md](IdentifierMapping.md) | 中英文标识符完整映射（含枚举值） |
| [../Resource/README.md](../Resource/README.md) | Resource 数据格式说明（markdown 源格式） |
| [../GameSystem/Common/Skill.md](../GameSystem/Common/Skill.md) | Skill 结构字段规范（源定义） |
