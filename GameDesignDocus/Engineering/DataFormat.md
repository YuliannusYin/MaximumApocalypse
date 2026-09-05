# 数据格式规范

> 本文档定义 `data/` 目录下运行时 JSON 文件的字段规范、加载流程、查询接口与代码字段编译机制。
> 所有字段名与类型均与 `MxApoc_GDScript/src/data/` 下的数据类、`data_manager.gd` 及实际 JSON 文件对齐。
> 标识符中英映射见 [IdentifierMapping.md](IdentifierMapping.md)；代码字段编译细节见 [CodeExecutor.md](CodeExecutor.md)。

---

## 一、数据加载流程

数据加载由 `data_manager.gd` 负责，该脚本在 `project.godot` 中注册为 autoload 单例，名为 `DataManager`。节点进入场景树时触发 `_ready`，进而调用 `_load_all` 完成全部静态数据加载。

### 1.1 加载入口

`_load_all` 依次调用 7 个 `_load_*` 私有方法：

| 加载方法 | 数据源 | 加载方式 |
| --- | --- | --- |
| `_load_survivors` | `data/survivors/` | 目录遍历 |
| `_load_variants` | `data/variants/` | 目录遍历 |
| `_load_scavenge_piles` | `data/scavenge/` | 目录遍历 |
| `_load_monster_packs` | `data/monsters/` | 目录遍历 |
| `_load_missions` | `data/missions/` | 目录遍历 |
| `_load_map_blocks` | `data/map_blocks/map_blocks.json` | 单文件 |
| `_load_common_skills` | `data/common_skills.json` | 单文件 |

### 1.2 两种加载方式

- **目录型**（求生者、变体、拾荒、怪物、任务）：通过 `_load_dir` 遍历目录下所有 `.json` 文件，逐个 `_load_json` 解析后回调 `_add_*` 方法构造数据类实例。
- **单文件型**（地图块、通用技能）：直接 `_load_json` 读取固定路径文件。

`_load_json` 内部使用 `FileAccess.open` 读取文本并以 `JSON.parse_string` 解析；打开或解析失败时通过 `push_error` 报错并返回 `null`。

### 1.3 缓存字段

加载结果存入 8 个缓存字段（7 个 Dictionary 与 1 个 Array）：

| 缓存字段 | 类型 | 键 / 元素 | 值 |
| --- | --- | --- | --- |
| `_survivors` | Dictionary | `english_name` | `SurvivorData` |
| `_variants` | Dictionary | `id` | `VariantData` |
| `_scavenge_piles` | Dictionary | `color` | `Array[ScavengeCardData]` |
| `_monster_packs` | Dictionary | `monster_type` | `Array[MonsterCardData]` |
| `_missions` | Dictionary | `mission_id`（int） | `MissionData` |
| `_map_blocks` | Dictionary | `english_name` | `MapBlockData` |
| `_map_blocks_by_name` | Dictionary | `block_name`（中文） | `MapBlockData` |
| `_common_skills` | Array | — | `SkillData` |

地图块同时以英文名与中文名两套键缓存，便于任务地图配置（中文名）与代码查询（英文名）双向查找。

---

## 二、查询接口

`DataManager` 对外暴露以下查询接口，返回值均为静态数据类实例或其集合：

| 接口 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `get_survivor` | `english_name: String` | `SurvivorData` | 按英文名获取求生者；不存在时 `push_error` 并返回 `null` |
| `get_all_survivors` | — | `Array` | 全部求生者 |
| `get_available_survivors` | — | `Array` | 可用求生者；开发模式返回全部，玩家模式仅返回消防员 |
| `has_survivor` | `english_name: String` | `bool` | 是否存在该求生者 |
| `get_variant` | `id: String` | `VariantData` | 按 id 获取变体 |
| `get_all_variants` | — | `Array` | 全部变体 |
| `get_mission` | `mission_id: int` | `MissionData` | 按编号获取任务；不存在时 `push_error` 并返回 `null` |
| `get_all_missions` | — | `Array` | 全部任务，按 `mission_id` 升序 |
| `get_available_missions` | — | `Array` | 可用任务；开发模式返回全部，玩家模式仅返回 0 号任务 |
| `has_mission` | `mission_id: int` | `bool` | 是否存在该任务 |
| `get_scavenge_pile` | `color: String` | `Array` | 按颜色获取拾荒牌堆；不存在返回空数组 |
| `get_monster_pack` | `monster_type: String` | `Array` | 按怪物类型获取怪物包；不存在返回空数组 |
| `get_map_block_def` | `english_name: String` | `MapBlockData` | 按英文名获取地图块定义 |
| `get_map_block_def_by_name` | `block_name: String` | `MapBlockData` | 按中文名获取地图块定义 |
| `get_common_skills` | — | `Array` | 全部通用主动技能 |

> `get_available_survivors` 与 `get_available_missions` 的"开发模式 / 玩家模式"分支依赖 `Settings.dev_mode`。

---

## 三、JSON Schema

### 3.1 survivors/*.json

求生者数据，每文件一名角色。`$schema` 值为 `"survivor"`。

**顶层字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `$schema` | String | 是 | 固定 `"survivor"` |
| `character_name` | String | 是 | 角色中文名 |
| `english_name` | String | 是 | 角色英文名（缓存键） |
| `max_hp` | Int | 是 | 生命值上限 |
| `initial_hp` | Int | 是 | 初始生命值 |
| `stealth` | Int | 是 | 潜行值 |
| `hunger_stealth` | Int | 是 | 饥饿状态潜行值 |
| `equipment_slot` | Int | 是 | 装备栏容量（默认 4） |
| `hand_size_limit` | Int | 是 | 手牌上限（默认 10） |
| `intrinsic_skills` | Array | 是 | 角色固有技能列表 |
| `deck` | Array | 是 | 角色专属游戏牌堆配置 |
| `sub_survivors` | Array | 否 | 子角色数据（仅老兵使用，含 `老兵` 与 `狗` 两名子角色） |

**`intrinsic_skills[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `skill_name` | String | 是 | 技能中文名 |
| `english_name` | String | 是 | 技能英文名 |
| `skill_description` | String | 是 | 技能描述 |
| `range` | String | 否 | 攻击射程（`short`/`medium`/`long`/`infinity`） |
| `active` | String | 否 | 可用阶段（主动技能） |
| `filter` | String | 否 | 可用条件代码 |
| `filter_target` | String | 否 | 目标筛选代码 |
| `filter_target_range` | String | 否 | 目标范围 |
| `select_target` | Int / Array&lt;Int&gt; | 否 | 目标选择数量 |
| `content` | String | 否 | 效果代码 |

> 固有技能还可携带 `sub_skills` 子技能对象（如能量饮料的饱腹子技能、老兵免疫子技能），供 `add_temp_skill` 临时挂载使用。

**`deck[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `card_name` | String | 是 | 卡牌中文名 |
| `english_name` | String | 是 | 卡牌英文名 |
| `count` | Int | 是 | 牌堆中该牌数量 |
| `card_type` | String | 是 | 卡牌类型（`action`/`equipment`） |
| `size` | Int | 否 | 装备占格数（仅装备牌） |
| `charge_type` | String | 否 | 填充物类型（带填充物装备） |
| `charge_max` | Int | 否 | 填充物上限（带填充物装备） |
| `charge_initial` | Int | 否 | 初始填充数（带填充物装备） |
| `range` | String | 否 | 射程（有射程的装备或行动牌） |
| `weapon` | Bool | 否 | 是否为武器牌（会造成伤害的装备）。缺省 `false`。用于「升级」等按武器筛选目标 |
| `skills` | Array | 否 | 卡牌技能列表（结构见第四节） |

### 3.2 scavenge/*.json

拾荒牌堆数据，每文件一种颜色。`$schema` 值为 `"scavenge_pack"`。**顶层无 `category` 字段**，颜色由 `color` 字段决定。

**顶层字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `$schema` | String | 是 | 固定 `"scavenge_pack"` |
| `color` | String | 是 | 颜色（`red`/`green`/`blue`/`gray`） |
| `cards` | Array | 是 | 拾荒卡列表 |

**`cards[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `card_name` | String | 是 | 卡牌中文名 |
| `english_name` | String | 是 | 卡牌英文名 |
| `card_type` | String | 是 | 卡牌类型枚举：`action` / `equipment` / `item` |
| `value` | Int | 否 | 数值（行动牌，如弹药数） |
| `size` | Int | 否 | 装备占格数（仅装备牌） |
| `charge_type` | String | 否 | 填充物类型（带填充物装备） |
| `charge_max` | Int | 否 | 填充物上限（带填充物装备） |
| `charge_initial` | Int | 否 | 初始填充数（带填充物装备） |
| `range` | String | 否 | 射程（有射程的装备） |
| `weapon` | Bool | 否 | 是否为武器牌（会造成伤害的装备）。缺省 `false` |
| `skills` | Array | 否 | 技能列表 |

**`cards[].skills[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `skill_name` | String | 是 | 技能中文名 |
| `english_name` | String | 是 | 技能英文名 |
| `skill_description` | String | 是 | 技能描述 |
| `skill_type` | String | 否 | 技能类型（主动技能为 `equipment` 或 `action`） |
| `active` | String | 否 | 可用阶段 |
| `target_type` | String | 否 | 目标类型（如 `equipment`） |
| `trigger` | String | 否 | 触发时机（被动技能） |
| `forced` | Bool | 否 | 是否强制发动 |
| `filter` | String | 否 | 可用条件代码 |
| `filter_target` | String | 否 | 目标筛选代码 |
| `filter_target_range` | String | 否 | 目标范围 |
| `select_target` | Int / Array&lt;Int&gt; | 否 | 目标选择数量 |
| `defer_action_cost` | Bool | 否 | 是否延迟消耗行动次数 |
| `range` | String | 否 | 攻击射程 |
| `content` | String | 否 | 效果代码 |

### 3.3 monsters/*.json

怪物包数据，每文件一种怪物类型。`$schema` 值为 `"monster_pack"`。**怪物数组字段名为 `cards`（不是 `monsters`）**。

**顶层字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `$schema` | String | 是 | 固定 `"monster_pack"` |
| `monster_type` | String | 是 | 怪物类型（`alien`/`mutant`/`zombie`/`robot`） |
| `cards` | Array | 是 | 怪物卡列表 |

**`cards[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `monster_name` | String | 是 | 怪物中文名 |
| `english_name` | String | 是 | 怪物英文名 |
| `monster_level` | String | 是 | 级别（`boss`/`elite`/`normal`） |
| `count` | Int | 是 | 该怪物卡在牌堆中的数量 |
| `max_hp` | Int | 是 | 生命值上限 |
| `initial_hp` | Int | 是 | 初始生命值 |
| `attack_damage` | Int | 是 | 攻击伤害 |
| `range` | String | 是 | 射程（`none`/`short`/`medium`/`long`/`infinity`） |
| `skills` | Array | 否 | 技能列表 |

**`cards[].skills[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `skill_name` | String | 是 | 技能中文名 |
| `english_name` | String | 是 | 技能英文名 |
| `skill_description` | String | 是 | 技能描述 |
| `skill_type` | String | 否 | 固定 `monster` |
| `passive` | Bool | 否 | 是否为被动技能；为 `true` 时可省略 `content` |
| `trigger` | String | 否 | 触发时机 |
| `forced` | Bool | 否 | 是否强制发动 |
| `filter` | String | 否 | 可用条件代码 |
| `content` | String | 否 | 效果代码（被动技能可无） |

> 示例：外星人包中"不能被短距离武器选为目标"的技能使用 `"passive": true` 且不带 `content`。

### 3.4 missions/*.json

任务数据，每文件一个任务。`$schema` 值为 `"mission"`。

**顶层字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `$schema` | String | 是 | 固定 `"mission"` |
| `mission_id` | Int | 是 | 任务编号（0-12） |
| `mission_name` | String | 是 | 任务中文名 |
| `english_name` | String | 是 | 任务英文名 |
| `difficulty` | String | 是 | 难度（`tutorial`/`very_easy`/`easy`/`normal`/`hard`/`very_hard`） |
| `van_fuel_required` | Int | 是 | 启动面包车所需燃料；`-1` 表示不通过面包车胜利 |
| `no_initial_monster_draw` | Bool | 否 | 开局跳过每名玩家的初始抓怪（如任务 11）；缺省 `false` |
| `intro_text` | String | 是 | 任务介绍 |
| `objective_text` | String | 是 | 任务目标 |
| `special_setup` | String | 是 | 特殊设置 |
| `monster_pack_type` | String | 是 | 怪物包类型 |
| `map_blocks_config` | Dictionary | 是 | 地块配置（键为地块中文名，值为数量） |
| `map_layout` | Array&lt;Array&lt;Int&gt;&gt; | 是 | 默认地图二维数组 |
| `map_legend` | Dictionary | 是 | 编号说明 |
| `objective_marks` | Array | 否 | 目标标记定义 |
| `scavenge_config` | Dictionary | 是 | 拾荒牌堆配置 |
| `win_conditions` | Array&lt;Object&gt; | 否 | 胜利条件组件声明列表，每项 `{ "component": <组件 id>, "params": {...} }` |
| `lose_conditions` | Array&lt;Object&gt; | 否 | 失败条件组件声明列表，结构同 `win_conditions` |
| `triggers` | Array&lt;Object&gt; | 否 | 触发器组件声明列表，结构同 `win_conditions` |
| `actions` | Array&lt;Object&gt; | 否 | 行动选项组件声明列表，结构同 `win_conditions` |
| `progress_conditions` | Array&lt;Object&gt; | 否 | 任务进度面板条件行声明，每项 `{ "text": <显示文案>, "type": <进度类型>, "params": {...} }`；面板按序号自动编号，完成加 `✔`，计数型显示 `(x/n)`；缺省为空（类型表见下） |
| `mission_script` | String | 否 | 专用任务脚本 id（空字符串表示无脚本） |

**`map_legend` 值类型：**

编号任意取值，含义由图例声明（引擎无硬编码编号语义）。值可为 `String` 或 `Object`：

- 字符串：`"no_block"`（无地块）、`"random_block"`（未知随机地块）。
- 对象：`{ "type": "spawn" | "game_end" | "random_block", "block_name": "<地块名>", "face": <bool>, "monster_mark": <int>, "mission_mark": <int> }`：
  - `type`：地块类型。`spawn`（出生点）/ `game_end`（游戏结束点）用 `block_name` 指定地块；`random_block` 从 `map_blocks_config` 抽取池取块。
  - `block_name`：指定地块名，`spawn` / `game_end` 必填。
  - `face`：初始是否翻开，缺省 `spawn` / `game_end` 为 `true`、`random_block` 为 `false`。
  - `monster_mark`：初始放置的怪物标记数，缺省 0，上限 3。
  - `mission_mark`：初始放置的任务标记数，缺省 0，按 `map_layout` 行优先顺序从 `objective_marks` 取 N 个。

> 旧 `marked_block` 类型已移除，其旧语义（随机地块 + 1 个任务标记 + 初始翻开）由 `{ "type": "random_block", "face": true, "mission_mark": 1 }` 表达。

**`scavenge_config` 结构：**

```
{
  "red":   [ { "card_name": "<卡牌名>", "count": <数量> }, ... ],
  "green": [ ... ],
  "blue":  [ ... ]
}
```

> `objective_marks[]` 元素含 `mark_id`、`mark_description`、`initial_monster_marks`、`remove_condition`、`effect_code` 字段。

**三层架构声明字段（`win_conditions` / `lose_conditions` / `triggers` / `actions` / `mission_script`）：**

> 任务逻辑采用三层架构，任务 JSON 只做**声明式配置**，不写代码：
> - **第一层（本文件）**：任务 JSON 通过上述五个字段声明组件 id / 脚本 id 及其 `params`
> - **第二层（可复用组件）**：`src/game/mission/components/` 下的组件类，由 `MissionComponentRegistry` 按 id 实例化并注入 `params`
> - **第三层（专用脚本）**：`src/game/mission/scripts/` 下的脚本类，由 `MissionScriptRegistry` 按 id 实例化，仅用于组件无法表达的极特殊任务逻辑
>
> 组件按声明位置区分职责：`win_conditions` 实现 `check_win`、`lose_conditions` 实现 `check_lose`、`triggers` 实现 `on_event`、`actions` 实现 `get_action_options`；脚本与组件共用同一套注入通道。
>
> **内置组件 id**（共 22 个，按声明位置分三类）：
> - **判定类**（实现 `check_win` / `check_lose`，声明于 `win_conditions` / `lose_conditions`）：`collect_items`（收集指定物品，params：`items`、`mode` hold/submit）/ `all_players_at_block`（全员抵达指定地块，params：`block_name`、`no_monster`）/ `escort_equipment_at_block`（护送指定卡牌抵达地块，直接查持有者，params：`card_name`、`block_name`）/ `kill_monsters`（击杀各怪物计数达标，params：`counts`；**需 `triggers`+`win_conditions` 双声明共享 `kill_counts` 计数**）/ `all_blocks_revealed`（全部地块已翻开）/ `objective_marks_cleared`（场上目标标记清至指定数，params：`count`，0=全清）/ `state_flag`（指定 mission_state 键为真即满足，params：`key`）/ `action_win_only`（行动直胜占位，`check_win` 恒 false，防止 win_conditions 为空时的空真误判）
> - **行动类**（实现 `get_action_options` 与 `get_action_skill_decl`，声明于 `actions`）：`spend_action_rescue`（花费行动解救目标卡并装备，params：`block_name`、`cost`、`card_name`、`skill_name` 可覆盖默认技能名）/ `destroy_current_mark`（花费行动摧毁当前地块目标标记，params：`cost`、`require_no_monster`）/ `submit_items`（在指定地块提交物品，params：`block_name`、`items`）/ `repair_van`（花费行动维修面包车累计次数，params：`block_name`、`card_name`、`times`）/ `defuse_bomb`（花费行动拆炸弹并可启动倒计时，params：`block_name`、`cost`、`card_name`、`countdown`）/ `upload_virus`（持指定装备在上传点花费行动直胜，params：`block_name`、`equipment`）/ `rescue_judge_win`（花费行动解救并潜行检定决胜，params：`card_name`）
> - **触发类**（实现 `on_event`，声明于 `triggers`）：`turn_countdown`（轮数倒计时，归零判负，params：`rounds`、`expire_kill_outside`、`auto_activate`）/ `mark_enter_reward`（首次进入指定目标标记地块发放奖励，params：`rewards`，按 `mark_id` 配 `cards` / `draw_boss`）/ `first_enter_draw_boss`（全队首次抵达指定地块抽首领卡，params：`block_name`）/ `reveal_mark_draw_boss`（展示带目标标记的地块时展示者抽首领卡，每地块仅一次）/ `card_discard_watch`（监视卡被弃置时销毁或判负，params：`card_name`、`on_discard` destroy/lose；**lose 模式需 `triggers`+`lose_conditions` 双声明共享 `card_discard_failed` 标记**）/ `setup_equip_card`（开局给玩家装备指定卡，params：`card_name`）/ `spawn_dice_effect`（怪物出生检定投出指定点数时执行外围地块效果，params：`value`、`block_name`）
>
> **行动组件技能化**：行动组件同时以 Skill 形式挂载技能栏——玩家进入匹配地块时，`MissionConfig.mount_action_skills(player, block)` 遍历行动组件的 `get_action_skill_decl()` 技能声明，`block_match` 匹配的组件构建为主动 Skill（`active="action"`、`skill_type="任务"`，技能栏金色按钮区分）挂到 `player.skills`；离开地块时 `unmount_action_skills(player)` 卸载（按 `english_name` 前缀 `mission_action_<组件索引>` 识别）。复用地块技能管线：filter 不满足时按钮灰化、confirm_prompt 确认门、use_active_skill 执行；技能栏为任务行动的唯一 UI 入口。地块匹配规则（`block_match`）：静态组件按 `params.block_name` 匹配地块名；动态组件（`destroy_current_mark` / `rescue_judge_win`）按地块存在未移除任务标记匹配。技能名默认表：`spend_action_rescue`→解救科学家（可用 `params.skill_name` 覆盖）、`destroy_current_mark`→摧毁目标、`submit_items`→提交物资、`repair_van`→维修面包车、`defuse_bomb`→解除炸弹、`upload_virus`→上传病毒、`rescue_judge_win`→解救科学家。
>
> **内置脚本 id**：当前无内置脚本（`MissionScriptRegistry` 内置注册为空；脚本通道保留给组件无法表达的极特殊任务逻辑）。
>
> 各组件 `params` 键名见组件类头注释；运行时写入的 `mission_state` 键名详见 `IdentifierMapping.md` §八。

**`progress_conditions[]` 进度类型（共 10 个 `type`）：**

`progress_conditions` 由任务进度面板读取显示。面板 `MissionProgressPanel`（`src/ui/mission_progress_panel.gd`）为常驻 UI 层右侧的固定尺寸滚动面板（200×150 @(1210,300)），每帧重算条件并做文本变更检测后刷新；条件行按序号自动编号，完成加 `✔` 前缀，计数型追加 `(x/n)` 后缀；未知 `type` 时 `push_error` 并跳过该行（不显示、不占序号）。面板判定语义与任务组件对齐：`all_at_block` ↔ `all_players_at_block` 组件、`escort_at_block` ↔ `escort_equipment_at_block` 组件、`hold_items` 变体族匹配 ↔ `collect_items` 组件、`van_boarding` ↔ 引擎面包车判定（`GameStateMachine.check_win_condition` 面包车段）。

| type | params | 显示形式 | 数据来源 |
| --- | --- | --- | --- |
| `van_fuel` | — | (x/n) | 面包车地块当前燃料 / `van_fuel_required`；无面包车地块或需求 ≤ 0 时容错为未完成（无后缀） |
| `van_boarding` | — | ✔ | 全部存活玩家在面包车地块（首块）且该地块无怪（无怪物标记、同地块玩家怪物卡之和为 0） |
| `state_flag` | `key` | ✔ | `mission_state[key]` 为真 |
| `state_count` | `key`、`name`（可选）、`target` | (x/n) | `name` 为空读 `mission_state[key]`，非空读 `mission_state[key][name]`；显示值钳制到 `target` |
| `hold_items` | `card_name`、`count` | (x/n) | 存活玩家手牌 + 装备区中该牌计数（变体族匹配：精确匹配或 `名（` 前缀，如"医疗用品"匹配"医疗用品（便携）"） |
| `submitted_count` | `card_name`、`count` | (x/n) | `mission_state.submitted_items[card_name]` |
| `all_at_block` | `block_name`、`no_monster`（可选） | ✔ | 全部存活玩家 `current_block` 地块名匹配；`no_monster` 时还需所在地块无怪；无存活玩家视为未完成 |
| `escort_at_block` | `card_name`、`block_name`、`no_monster`（可选） | ✔ | 存在存活玩家装备该卡（`has_equipment`）且 `current_block` 地块名匹配；`no_monster` 时还需该地块无怪 |
| `marks_cleared` | `count` | (x/n) | 已移除标记数 = `initial_objective_mark_count` − 存活地块剩余 `objective_marks` 之和（负数钳 0） |
| `all_revealed` | — | (x/n) | 存活地块已揭示数 / 存活地块总数；无存活地块时容错为未完成（无后缀） |

### 3.5 map_blocks/map_blocks.json

地图块定义，单文件。`$schema` 值为 `"map_blocks"`。

**顶层字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `$schema` | String | 是 | 固定 `"map_blocks"` |
| `blocks` | Array | 是 | 地图块定义列表 |

**`blocks[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `block_name` | String | 是 | 地块中文名 |
| `english_name` | String | 是 | 地块英文名 |
| `scavenge_colors` | Array&lt;String&gt; | 是 | 可拾荒颜色集合 |
| `monster_spawn_value` | Int | 是 | 怪物生成值 |
| `variants` | Array | 否 | 变体配置（同地块不同生成值/颜色） |
| `skills` | Array | 否 | 地块技能列表 |

**`variants[]` 字段：**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `scavenge_colors` | Array&lt;String&gt; | 是 | 该变体的拾荒颜色 |
| `monster_spawn_value` | Int | 是 | 该变体的怪物生成值 |

### 3.6 variants/*.json

变体数据，每文件一个变体。`$schema` 值为 `"variant"`。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `$schema` | String | 是 | 固定 `"variant"` |
| `id` | String | 是 | 变体 id（`crisis`/`famine`/`shared_fate`，缓存键） |
| `english_name` | String | 是 | 英文名（缺省时取 `id`） |
| `display_name` | String | 是 | 中文显示名 |
| `desc` | String | 是 | 变体说明 |

### 3.7 common_skills.json

通用主动技能数据。**顶层为数组**（非对象），每个元素为一个通用技能定义。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `skill_name` | String | 是 | 技能中文名 |
| `english_name` | String | 是 | 技能英文名 |
| `skill_description` | String | 是 | 技能描述 |
| `skill_type` | String | 是 | 固定 `common` |
| `active` | String | 否 | 可用阶段 |
| `target_type` | String | 否 | 目标类型 |
| `select_card` | Int | 否 | 卡牌选择数量 |
| `position` | String | 否 | 选牌位置限定（如 `hand`） |
| `filter_card` | String | 否 | 卡牌筛选代码 |
| `usable` | Int | 否 | 每回合可用次数（`-1` 表示不限） |
| `filter` | String | 否 | 可用条件代码 |
| `content` | String | 否 | 效果代码 |

### 3.8 image_manifest.json

图片资源清单，供 `image_cache.gd` 预加载使用。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `mapblock` | Array&lt;String&gt; | 地图块图片路径 |
| `survivor` | Object&lt;String, Array&lt;String&gt;&gt; | 键为求生者英文名，值为该角色相关图片路径数组 |
| `gamemark` | Array&lt;String&gt; | 游戏标记图片路径 |
| `monster` | Object&lt;String, Array&lt;String&gt;&gt; | 键为怪物类型，值为该类型怪物图片路径数组 |
| `scavenging` | Array&lt;String&gt; | 拾荒卡图片路径 |

---

## 四、技能字段规范（统一）

所有卡牌、角色、地块、怪物的技能均遵循统一字段结构。完整字段如下：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `skill_name` | String | 技能中文名 |
| `english_name` | String | 技能英文名（代码标识符） |
| `skill_description` | String | 自然语言描述 |
| `skill_type` | String | 技能类型枚举：`equipment` / `action` / `monster` / `block` / `common` / `任务`（任务行动技能，运行时由行动组件构建，非 JSON 声明） |
| `active` | String | 可用阶段（主动技能） |
| `trigger` | String | 触发时机（被动技能）；**可用中文顿号分隔多个触发**，如 `"on_reveal_block、on_enter_block"` |
| `forced` | Bool | 是否强制发动 |
| `filter` | String | 可用条件代码 |
| `filter_target` | String | 目标筛选代码 |
| `filter_target_range` | String | 目标范围 |
| `filter_card` | String | 卡牌筛选代码 |
| `position` | String | 选牌位置限定 |
| `select_card` | Int | 需选择牌数 |
| `select_target` | Int / Array&lt;Int&gt; | 需选择目标数；`-1` 表示射程内全部；数组如 `[1, 3]` 表示可选数量范围 |
| `range` | String | 攻击射程枚举：`short` / `medium` / `long` / `infinity` |
| `usable` | Int | 每回合可用次数（`-1` 表示不限） |
| `content` | String | 效果代码（**可选**；被动技能可无） |
| `target_type` | String | 目标类型 |
| `confirm_prompt` | String | 确认提示代码 |
| `defer_action_cost` | Bool | 是否延迟消耗行动次数 |
| `passive` | Bool | 是否为被动技能（可选；怪物技能使用） |

> 代码字段（`filter` / `content` / `filter_target` / `filter_card` / `confirm_prompt`）均为 GDScript 代码字符串，由 `CodeExecutor` 在运行时懒编译为 `Callable`，签名统一为 `(player, target, event, game)`。编译机制见第五节与 [CodeExecutor.md](CodeExecutor.md)。

---

## 五、代码字段编译

JSON 中的 `filter` / `content` / `filter_target` / `filter_card` / `confirm_prompt` 等"代码字段"是 GDScript 代码字符串，由 `code_executor.gd`（类名 `CodeExecutor`）在运行时懒编译为 `Callable`，供 `Skill` 在触发时执行。

**编译机制：** 通过 `GDScript.new()` 创建脚本对象，将代码字符串包装为 `extends RefCounted\nfunc _fn(player, target, event, game):\n    <代码>` 形式的源码后调用 `script.reload()` 编译。编译产物（脚本与实例）存入静态数组 `_scripts` 与 `_instances` 防止被垃圾回收。**本工程不使用 `Expression` 类，也不使用 `eval()`**——以此支持 `for` / `if` / `await` 等多语句结构。

**5 个 compile_* 接口：**

| 接口 | 入参 | 返回 Callable 签名 |
| --- | --- | --- |
| `compile_filter` | `code: String` | `(player, target, event, game) -> bool` |
| `compile_content` | `code: String` | `(player, target, event, game) -> void` |
| `compile_filter_target` | `code: String` | `(player, target, event, game) -> bool` |
| `compile_filter_card` | `code: String` | `(player, target, event, game) -> bool`（直接转调 `compile_filter_target`） |
| `compile_confirm_prompt` | `code: String` | `(player, target, event, game) -> String` |

**降级行为：** 编译失败时降级为 no-op——`filter` / `filter_target` / `filter_card` 恒真（返回 `true`），`content` 无操作，`confirm_prompt` 返回空字符串。空字符串代码同样视为 no-op。

**任务逻辑不走代码编译：** 任务胜利/失败条件与行动选项已改为三层架构的声明式组件/脚本配置（见 §3.4），不再使用代码字符串字段，与 `CodeExecutor` 的 `compile_*` 接口无关。

---

## 六、偏差修订记录

本节列出本次重写相对旧版文档修正的偏差，均以实际代码与 JSON 为准：

| 偏差项 | 旧文档描述 | 实际代码 / JSON | 修正 |
| --- | --- | --- | --- |
| 怪物数组字段名 | `monsters` | `cards` | 改为 `cards` |
| 拾荒顶层 `category` | 必填字段 | 实际无此字段 | 删除 |
| 求生者字段数 | 8 项 | 11 项 | 补 `equipment_slot` / `hand_size_limit` / `sub_survivors` |
| 怪物卡 `count` | 未列出 | 实际有 | 补充 |
| 地图块 `variants` | 5 字段 | 6 字段 | 补 `variants`（可选） |
| `card_type` 枚举 | `action` / `equipment` | 含 `item` | 补充 `item` |
| 技能 `skill_type` | 无枚举值 | `equipment`/`action`/`monster`/`block`/`common` | 补充枚举 |
| 技能 `passive` | 未提及 | 外星人包有 `passive: true` 且无 `content` | 补充；放宽 `content` 为可选 |
| 技能 `target_type` / `defer_action_cost` / `confirm_prompt` | 未提及 | 实际有 | 补充 |
| `select_target` 类型 | `Int` | 可为 `[1, 3]` 数组 | 改为 `Int \| Array<Int>` |
| `trigger` 多值 | 单值或 null | 可中文顿号分隔多触发 | 说明多值语法 |
| 数据类别数 | 仅 5 类 | 另有 `variants` / `common_skills` / `image_manifest` | 新增 3 类章节 |
| autoload 名 | 未明确 | `DataManager` | 明确 |
| `_load_all` 调用数 | 5 个 | 7 个（补 `_load_variants` / `_load_common_skills`） | 补齐 |
| 缓存字段数 | 5 个 Dictionary | 7 个 Dictionary + 1 个 Array | 补 `_variants` / `_map_blocks_by_name` / `_common_skills` |
| 代码字段编译方式 | `Expression` / `eval()` | `GDScript.new()` + `script.reload()` | 改为 `GDScript.new()` |
| `van_fuel_required` | `null` 表示无面包车胜利 | `-1` 哨兵值表示无面包车胜利 | 改为 `-1` |
| 查询接口 | 仅列 3 个 | 15 个 | 补全 `get_available_*` / `has_*` / `get_map_block_def_by_name` / `get_common_skills` 等 |
