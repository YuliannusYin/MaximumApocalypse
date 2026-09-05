# 标识符映射表（中文 → 英文）

> 本文档定义设计文档中的中文标识符到 GDScript 代码中英文标识符的映射。
> 命名规范：类名 PascalCase，方法名 / 变量名 snake_case，常量 / 枚举值 UPPER_SNAKE_CASE。
> 映射原则：意译优先于音译；保留游戏术语特色（如 `van` 面包车）；避免歧义。
> 所有标识符均与 `MxApoc_GDScript/src/` 实际代码对齐。

---

## 一、类名映射

### 1.1 Core 核心类

| 设计文档类名 | GDScript 类名 | 文件 | 说明 |
| --- | --- | --- | --- |
| 实体 | `Entity` | `src/core/entity.gd` | 实体基类（技能挂载、伤害流程、触发） |
| 事件总线 | `EventBus` | `src/core/event_bus.gd` | 全局事件总线（autoload） |
| 事件系统 | `EventSystem` | `src/core/event_system.gd` | 事件工厂与取消机制（静态工具类） |
| 游戏状态机 | `GameStateMachine` | `src/core/game_state_machine.gd` | 游戏状态机与回合队列 |
| 玩家统计 | `PlayerStats` | `src/core/player_stats.gd` | 单玩家统计数据 |
| 统计跟踪器 | `StatsTracker` | `src/core/stats_tracker.gd` | 全局统计跟踪器 |

### 1.2 Common 通用结构

| 设计文档类名 | GDScript 类名 | 文件 | 说明 |
| --- | --- | --- | --- |
| 牌堆 | `Pile` | `src/common/pile.gd` | 牌堆类 |
| 角色卡 | `RoleCard` | `src/common/role_card.gd` | 角色卡类 |
| 技能 | `Skill` | `src/common/skill.gd` | 技能结构（运行时） |
| 日志着色 | `LogColors` | `src/common/log_colors.gd` | 日志着色工具 |

### 1.3 Data 数据类

| 设计文档类名 | GDScript 类名 | 文件 | 说明 |
| --- | --- | --- | --- |
| 数据管理器 | `DataManager` | `src/data/data_manager.gd` | 数据管理器（autoload） |
| 代码执行器 | `CodeExecutor` | `src/data/code_executor.gd` | 代码字段编译沙箱 |
| 求生者数据 | `SurvivorData` | `src/data/survivor_data.gd` | 求生者静态数据 |
| 拾荒卡数据 | `ScavengeCardData` | `src/data/scavenge_card_data.gd` | 拾荒卡静态数据 |
| 怪物卡数据 | `MonsterCardData` | `src/data/monster_card_data.gd` | 怪物卡静态数据 |
| 任务数据 | `MissionData` | `src/data/mission_data.gd` | 任务静态数据 |
| 地图块数据 | `MapBlockData` | `src/data/map_block_data.gd` | 地图块静态数据 |
| 技能数据 | `SkillData` | `src/data/skill_data.gd` | 技能静态数据 |
| 变体数据 | `VariantData` | `src/data/variant_data.gd` | 变体静态数据 |

### 1.4 Entities 实体类

| 设计文档类名 | GDScript 类名 | 文件 | 说明 |
| --- | --- | --- | --- |
| 卡牌 | `Card` | `src/entities/card.gd` | 卡牌基类 |
| 装备 | `Equipment` | `src/entities/equipment.gd` | 装备区实体类 |
| 装备牌 | `EquipmentCard` | `src/entities/equipment_card.gd` | 装备牌（继承 `SurvivorGameCard`） |
| 求生者游戏牌 | `SurvivorGameCard` | `src/entities/survivor_game_card.gd` | 求生者游戏牌（继承 `Card`） |
| 拾荒卡 | `ScavengeCard` | `src/entities/scavenge_card.gd` | 拾荒卡（继承 `EquipmentCard`） |
| 怪物 | `Monster` | `src/entities/monster.gd` | 怪物类 |
| 怪物卡 | `MonsterCard` | `src/entities/monster_card.gd` | 怪物卡（实体化前） |
| 地图块 | `MapBlock` | `src/entities/map_block.gd` | 地图块类 |
| 玩家 | `Player` | `src/entities/player.gd` | 玩家类 |

> 卡牌继承链：`ScavengeCard` → `EquipmentCard` → `SurvivorGameCard` → `Card` → `Entity`。

### 1.5 Game 游戏全局类

| 设计文档类名 | GDScript 类名 | 文件 | 说明 |
| --- | --- | --- | --- |
| 游戏 | `Game` | `src/game/game.gd` | 游戏全局类（autoload） |
| 任务配置 | `MissionConfig` | `src/game/mission_config.gd` | 任务运行时配置 |

### 1.6 UI 主要类

| 设计文档类名 | GDScript 类名 | 文件 |
| --- | --- | --- |
| 玩家输入接口 | `IPlayerInput` | `src/ui/i_player_input.gd` |
| 命令行玩家输入 | `CliPlayerInput` | `src/ui/cli_player_input.gd` |
| 图形界面玩家输入 | `GuiPlayerInput` | `src/ui/gui_player_input.gd` |
| 游戏场景 | `GameScene` | `src/ui/game_scene.gd` |
| 2D 游戏场景 | `GameScene2D` | `src/ui/game_scene_2d.gd` |
| 游戏房间 | `GameRoom` | `src/ui/game_room.gd` |
| 房间状态 | `RoomState` | `src/ui/room_state.gd`（autoload） |
| 全局设置 | `Settings` | `src/ui/settings.gd`（autoload） |
| 图片缓存 | `ImageCache` | `src/ui/image_cache.gd` |
| 事件日志面板 | `EventLogPanel` | `src/ui/event_log_panel.gd` |
| 弹窗管理器 | `PopupManager` | `src/ui/popup_manager.gd` |

> UI 层其余类见 [GodotProjectStructure.md §2.6](GodotProjectStructure.md)。

---

## 二、状态 / 枚举映射

### 2.1 游戏状态 GameState

| 中文 | 枚举值 | 说明 |
| --- | --- | --- |
| 等待开始 | `WAITING` | 默认值 |
| 游戏中 | `PLAYING` | |
| 游戏结束 | `GAME_OVER` | |

> 整型枚举，首成员为 `WAITING`（非 `SETUP`）。`game_over` 允许从 `WAITING` 强制进入 `GAME_OVER`。

### 2.2 游戏结果 GameResult

| 中文 | 枚举值 | 说明 |
| --- | --- | --- |
| 胜利 | `WIN` | |
| 失败 | `LOSE` | |

### 2.3 卡牌类型 card_type

| 中文 | 值 | 说明 |
| --- | --- | --- |
| 行动牌 | `action` | |
| 装备牌 | `equipment` | |
| 物品牌 | `item` | 拾荒牌堆中的物品（如脏毯子） |

### 2.4 技能类型 skill_type

| 中文 | 值 | 说明 |
| --- | --- | --- |
| 装备技能 | `equipment` | 装备牌技能 |
| 行动技能 | `action` | 行动牌技能 |
| 怪物技能 | `monster` | 怪物技能 |
| 地块技能 | `block` | 地图块技能 |
| 通用技能 | `common` | 通用主动技能 |
| 任务行动技能 | `任务` | 任务行动组件运行时构建挂载（非 JSON 声明），技能栏金色区分 |

### 2.5 射程 range

| 中文 | 值 | 说明 |
| --- | --- | --- |
| 无 | `none` | 怪物专用（只攻击纠缠对象） |
| 短距离 | `short` | |
| 中距离 | `medium` | |
| 长距离 | `long` | |
| 任意距离 | `infinity` | |

### 2.6 回合阶段 in_phase

`in_phase` 为字符串字段（非枚举），取以下小写英文值：

| 中文 | 值 | 说明 |
| --- | --- | --- |
| 回合外 | `idle` | 默认值 |
| 回合开始 | `turn_start` | |
| 怪物出生 | `monster_spawn` | |
| 摸牌阶段 | `draw` | |
| 行动阶段 | `action` | |
| 饥饿结算 | `hunger` | |
| 中毒结算 | `poison` | |
| 怪物行动 | `monster_action` | |
| 回合结束 | `turn_end` | |
| 第零轮重调 | `round_zero` | 第零轮重调阶段专用 |

### 2.7 其他枚举

| 类别 | 中文 → 值 |
| --- | --- |
| 怪物级别 monster_level | 首领 `boss` / 精英 `elite` / 普通 `normal` |
| 怪物类型 monster_type | 外星人 `alien` / 突变体 `mutant` / 僵尸 `zombie` / 机器人 `robot` |
| 拾荒颜色 color | 红色 `red` / 绿色 `green` / 蓝色 `blue` / 灰色 `gray` |
| 任务难度 difficulty | 特别简单 `tutorial` / 非常简单 `very_easy` / 简单 `easy` / 正常 `normal` / 困难 `hard` / 非常困难 `very_hard` |
| map_legend type | 出生点 `spawn` / 游戏结束点 `game_end` / 随机地块 `random_block` |

---

## 三、trigger 名映射（中文译名 → 英文键名）

trigger 名在 JSON 数据中用英文 snake_case，技能 `trigger` 字段可用中文顿号分隔多个触发（如 `"on_reveal_block、on_enter_block"`）。带 ✅ 的为取消点，技能可调用 `event["cancel"].call()` 或 `EventSystem.cancel(event)` 终止流程。

### 3.1 伤害类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 造成伤害前 | `before_deal_damage` | 否 |
| 造成伤害时 | `on_deal_damage` | 否 |
| 造成伤害后 | `after_deal_damage` | 否 |
| 受到伤害前 | `before_take_damage` | 否 |
| 受到伤害时 | `on_take_damage` | ✅ |
| 受到伤害后 | `after_take_damage` | 否 |

### 3.1.1 回复类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 回复生命前 | `before_recover` | 否 |
| 造成回复时 | `on_deal_recover` | 否 |
| 回复生命时 | `on_recover` | 否 |
| 回复生命后 | `after_recover` | 否 |

### 3.2 移动 / 地块类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 离开地块时 | `on_leave_block` | 否 |
| 进入地块前 | `before_enter_block` | ✅ |
| 进入地块时 | `on_enter_block` | 否 |
| 展示地块时 | `on_reveal_block` | 否 |
| 摧毁地块前 | `before_destroy_block` | ✅ |
| 摧毁地块时 | `on_destroy_block` | 否 |
| 摧毁地块后 | `after_destroy_block` | 否 |
| 触发目标标记时 | `on_trigger_objective_mark` | 否 |

### 3.3 怪物类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 怪物卡进入怪物区后 | `after_monster_enter_zone` | 否 |
| 怪物行动前 | `before_monster_act` | 否 |
| 怪物行动后 | `after_monster_act` | 否 |
| 怪物攻击后 | `after_monster_attack` | 否 |
| 怪物死亡时 | `on_monster_death` | 否 |
| 玩家死亡时 | `on_player_death` | 否 |

### 3.4 回合类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 回合开始时 | `on_turn_start` | 否 |
| 下一回合开始前 | `before_next_turn_start` | 否（用于击晕 / 临时技能过期） |
| 回合结束时 | `on_turn_end` | 否 |
| 行动阶段结束时 | `on_action_phase_end` | 否 |

### 3.5 抓牌类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 抓取游戏牌前 | `before_draw_game_card` | ✅ |
| 抓取游戏牌时 | `on_draw_game_card` | ✅ |
| 抓取游戏牌后 | `after_draw_game_card` | 否 |
| 抓取怪物卡前 | `before_draw_monster_card` | ✅ |
| 抓取怪物卡时 | `on_draw_monster_card` | 否 |
| 抓取拾荒牌前 | `before_draw_scavenge_card` | ✅ |
| 抓取拾荒牌时 | `on_draw_scavenge_card` | 否 |

### 3.6 使用卡牌 / 装备 / 弃牌类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 使用卡牌前 | `before_use_card` | ✅ |
| 使用卡牌时 | `on_use_card` | ✅ |
| 卡牌进入装备区时 | `on_equip` | 否 |
| 卡牌离开装备区时 | `on_unequip` | 否 |
| 消耗填充物前 | `before_consume_charge` | ✅ |
| 消耗填充物时 | `on_consume_charge` | ✅ |
| 弃置牌前 | `before_discard` | ✅ |
| 销毁牌前 | `before_remove_card` | ✅ |

### 3.7 检定 / 游戏类

| 中文 | 英文键名 | 取消点 |
| --- | --- | --- |
| 潜行检定前 | `before_sneak_judge` | 否 |
| 怪物出生检定前 | `before_spawn_judge` | 否 |
| 游戏开始时 | `on_game_start` | 否 |
| 游戏结束时 | `on_game_over` | 否 |

---

## 四、event schema 字段映射

`event` 为 Dictionary 类型，由 `EventSystem.create_event` 创建并注入 `trigger_name` / `cancelled` / `cancel` 三个基础字段，各流程工厂方法在此基础上追加专属字段。所有键名均为 snake_case：

| 中文 | event key | 类型 | 说明 |
| --- | --- | --- | --- |
| 当前触发名 | `trigger_name` | String | 由 `EventSystem.set_trigger_name` 写入 |
| 是否已取消 | `cancelled` | bool | |
| 取消函数 | `cancel` | Callable | 调用后置 `cancelled = true` |
| 受伤 / 死亡实体 | `target` | Entity | |
| 伤害来源 | `source` | Entity / null | `null` 表示无来源（饥饿 / 中毒） |
| 伤害 / 回复 / 抓牌数 | `num` | int | |
| 伤害类型 | `type` | Variant | 可为 String（`monster_attack`/`poison`/`hunger`/`block_destroy`）或 int |
| 武器牌 | `card` | Card / null | |
| 玩家 | `player` | Player | |
| 卡牌列表 | `cards` | Array&lt;Card&gt; | 抓到的牌 / 弃置的牌 |
| 主动技能目标列表 | `targets` | Array | |
| 离开的地块 | `source_block` | MapBlock | |
| 进入的地块 | `target_block` | MapBlock | |
| 牌堆 | `pile` | Pile | |
| 潜行检定阈值 | `sneak_value` | int | |
| 是否跳过投骰 | `skip_judge` | bool | |
| 检定结果 | `result` | Dictionary | `{ "value": int, "success": bool }` |
| 被摧毁的地块 | `block` | MapBlock | |
| 目标标记 | `mark` | Dictionary / ObjectiveMark | |
| 怪物 | `monster` | Monster | 怪物行动 event |
| 游戏结果 | `result` | int | 游戏结束 event（GameResult 枚举值） |
| 装备 | `equipment` | Variant | 消耗填充物 event（也通过 `card` 传递） |

---

## 五、关键方法名映射

按代码实际 snake_case 列出各类主要公开方法。

### 5.1 Entity

| 方法 | 说明 |
| --- | --- |
| `trigger(trigger_name, event)` | 遍历匹配技能并执行 |
| `trigger_only(trigger_name, event, skill_list)` | 仅在指定技能列表内触发 |
| `get_all_skills()` | 获取所有技能 |
| `add_skill(skill)` | 挂载技能 |
| `remove_skill(skill)` | 移除技能 |
| `damage(num, source, type, card)` | 伤害流程（8 节点） |
| `get_hp()` / `get_max_hp()` | 生命值查询 |
| `reduce_hp(n)` / `add_hp(n)` | 直接扣 / 加血（不触发钩子） |
| `is_player()` / `is_monster()` | 类型判断 |
| `death(source)` | 死亡流程（子类多态实现） |

### 5.2 Player

| 方法 | 说明 |
| --- | --- |
| `draw(n)` | 抓游戏牌 |
| `draw_scavenge(n, pile)` | 抓拾荒牌 |
| `draw_monster(n)` | 抓怪物卡 |
| `discard(target, position, quantity, type)` | 弃置牌（含 `silent` 参数） |
| `remove_card(target, position, quantity)` | 销毁牌 |
| `move_to(target)` | 移动到地块 |
| `equip(card)` | 装备进入装备区（走 `card.instantiate`） |
| `unequip(card)` | 装备离开装备区 |
| `consume_charge(equipment, num)` | 消耗填充物 |
| `consume_action(n)` / `add_action(n)` | 扣除 / 增加行动次数 |
| `use_card(card)` | 使用卡牌（含 `defer_action_cost` 机制） |
| `recover(num, source = null)` | 回复生命 |
| `increase_hunger(n)` / `decrease_hunger(n)` | 饥饿值增减 |
| `poison()` | 中毒结算 |
| `judge()` / `sneak_judge()` | 投骰 / 潜行检定 |
| `stun(source, expire_trigger)` | 击晕怪物 |
| `change_engaged_target(target)` | 修改纠缠对象 |
| `add_temp_skill(skill_id, expire_trigger)` | 临时技能挂载 |
| `get_pile(name)` | 按名获取牌堆 |
| `get_equipment(name)` / `has_equipment(name)` | 装备查询 |
| `get_charge_count(equipment_name)` | 装备填充物数量 |
| `get_number(key)` | 数值标记查询 |
| `get_current_block()` | 当前地块 |
| `choose_card(n, param, filter)` | 选牌 |
| `choose_target(n, skill)` | 选目标（`n=-1` 全部） |
| `confirm(prompt)` | 确认对话框 |
| `collect_item(card_name, count)` | 收集物品（任务系统） |
| `has_item(card_name)` | 是否持有物品 |
| `player_death(source)` | 玩家死亡流程 |
| `start_turn()` | 开始回合（21 节点流程） |

### 5.3 Monster / MonsterCard

| 方法 | 说明 |
| --- | --- |
| `Monster.act()` | 怪物行动 |
| `Monster.attack()` | 怪物攻击 |
| `Monster.change_engaged_target(target)` | 修改纠缠对象 |
| `Monster.monster_death(source)` | 怪物死亡 |
| `Monster.stun(source, expire_trigger)` | 击晕 |
| `MonsterCard.instantiate(player)` | 怪物卡实体化为 `Monster` |

### 5.4 MapBlock

| 方法 | 说明 |
| --- | --- |
| `reveal(trigger_effect, player)` | 展示地块 |
| `get_coordinate()` / `set_coordinate(x, y)` | 坐标 |
| `is_alive()` / `is_destroyed()` | 存活 / 摧毁状态 |
| `get_adjacent_blocks()` | 相邻地块 |
| `distance_to(other)` | 曼哈顿距离 |
| `get_blocks_in_range(range)` | 射程内地块 |
| `get_players_in_range(range)` / `get_players()` | 玩家查询 |
| `has_monster_mark()` / `count_monster_marks()` | 怪物标记 |
| `add_monster_mark(n)` / `remove_monster_mark()` | 怪物标记增减 |
| `get_van_fuel()` / `get_van_fuel_max()` / `add_van_fuel(n)` | 面包车燃料 |
| `has_skill(name)` | 是否含某技能 |
| `is_map_block()` | 是否为地图块（供 `filter_target` 区分） |

### 5.5 Game

| 方法 | 说明 |
| --- | --- |
| `start_game()` / `game_over(result)` | 开始 / 结束游戏 |
| `build_map(mission_config)` | 构建地图 |
| `destroy_map_block(block, source)` | 摧毁地块 |
| `get_block_by_coord(x, y)` | 按坐标获取地块 |
| `get_blocks_by_name(name)` | 按名获取地块 |
| `get_scavenge_pile(color)` | 获取拾荒牌堆 |
| `get_target(block)` | 地块上玩家 + 怪物 |
| `get_card(card_english_name, pile)` | 从牌堆查找卡牌 |
| `create_scavenge_card(card_name)` | 创建拾荒卡实例 |
| `get_all_players()` / `get_alive_players()` | 玩家查询 |
| `get_engaged_monsters(player)` | 玩家面前怪物 |
| `check_mission_win_condition()` | 任务胜利判定 |
| `log_message(message)` | 输出日志 |

### 5.6 GameStateMachine

| 方法 | 说明 |
| --- | --- |
| `init()` | 初始化状态机 |
| `start_game()` | 启动游戏 |
| `next_turn()` | 下一回合 |
| `game_over(result)` | 游戏结束 |
| `check_win_condition()` | 胜利判定（含面包车胜利） |
| `queue_extra_turn(player)` | 加入额外回合 |
| `skip_next_turn(player)` | 跳过下回合 |
| `get_current_player()` / `get_game_state()` / `get_game_result()` | 查询 |

### 5.7 Pile / RoleCard

| 方法 | 说明 |
| --- | --- |
| `Pile.draw()` | 抓一张牌 |
| `Pile.peek_top(n)` | 查看牌堆顶 n 张（不移除） |
| `Pile.put_bottom(card)` | 置于牌堆底 |
| `Pile.add(card)` | 加入底部 |
| `Pile.shuffle()` / `shuffle_into(target_pile)` | 洗牌 |
| `Pile.is_empty()` / `size()` | 空与大小 |
| `Pile.get_all()` | 获取所有牌 |
| `RoleCard.get_sneak()` | 按正反面返回潜行值 |

### 5.8 MissionConfig

| 方法 | 说明 |
| --- | --- |
| `mount_action_skills(player, block)` | 挂载任务行动技能：玩家进入地块时按行动组件 `get_action_skill_decl()` 声明构建 Skill（`english_name` 为 `mission_action_<组件索引>`）加入 `player.skills`，与地块技能获取并列 |
| `unmount_action_skills(player)` | 卸载全部任务行动技能：按 `english_name` 前缀 `mission_action_` 识别并 `remove_skill`，与地块技能清理并列 |

---

## 六、EventBus 信号映射

`EventBus`（autoload）的全部 signal，供 UI 层订阅。核心逻辑层通过 `EventBus.<signal>.emit(...)` 通知 UI：

| 信号 | 参数 | 说明 |
| --- | --- | --- |
| `player_died` | `(player, source)` | 玩家死亡 |
| `player_hp_changed` | `(player, old_value, new_value)` | 玩家生命值变化 |
| `player_hunger_changed` | `(player, old_value, new_value)` | 玩家饥饿值变化 |
| `card_drawn` | `(player, card)` | 抓牌 |
| `card_discarded` | `(player, card)` | 弃牌 |
| `card_used` | `(player, card)` | 使用卡牌 |
| `monster_spawned` | `(monster, player)` | 怪物出生 |
| `monster_died` | `(monster, source)` | 怪物死亡 |
| `monster_engaged_target_changed` | `(monster, old_target, new_target)` | 纠缠对象变更 |
| `block_revealed` | `(block, player)` | 地块展示 |
| `block_destroyed` | `(block, source)` | 地块摧毁 |
| `player_moved` | `(player, source_block, target_block)` | 玩家移动 |
| `objective_mark_triggered` | `(player, block, mark)` | 目标标记触发 |
| `monster_mark_changed` | `(block)` | 怪物标记变化 |
| `objective_mark_changed` | `(block)` | 目标标记变化 |
| `game_started` | `()` | 游戏开始 |
| `game_over` | `(result)` | 游戏结束 |
| `turn_started` | `(player)` | 回合开始 |
| `turn_ended` | `(player)` | 回合结束 |
| `equipment_equipped` | `(player, card)` | 装备进入装备区 |
| `equipment_unequipped` | `(player, card)` | 装备离开装备区 |
| `charge_consumed` | `(player, equipment, num)` | 消耗填充物 |
| `scavenge_drawn` | `(player, card)` | 抓拾荒牌 |
| `monster_card_drawn` | `(player, card)` | 抓怪物卡 |
| `phase_changed` | `(player, old_phase, new_phase)` | 回合阶段变化 |
| `action_consumed` | `(player, num)` | 消耗行动次数 |
| `sneak_judge_triggered` | `(player, block)` | 潜行检定触发 |
| `monster_spawn_judged` | `(player, value)` | 怪物出生检定投骰结果出来时 |
| `log_message` | `(message)` | 日志消息 |
| `damage_dealt` | `(source, target, amount)` | 造成伤害 |
| `damage_taken` | `(target, source, amount)` | 受到伤害 |
| `hp_recovered` | `(player, amount)` | 生命值回复 |
| `healing_done` | `(source, target, amount)` | 治疗他人 |
| `hunger_reduced` | `(player, amount)` | 饥饿值减少 |
| `skill_used` | `(player, skill)` | 使用主动技能 |
| `player_turn_started` | `(player)` | 玩家回合开始 |

> `EventBus.publish_log(message)` 为日志发布的便捷方法，内部 `emit` `log_message` 信号。

---

## 七、EventSystem 工厂方法映射

`EventSystem`（静态工具类）的全部 `create_*_event` 工厂方法。每个 event 均由 `create_event` 注入 `trigger_name` / `cancelled` / `cancel` 基础字段后追加流程专属字段：

| 工厂方法 | 签名 | 追加字段 |
| --- | --- | --- |
| `create_event` | `(initial: Dictionary = {})` | `trigger_name` / `cancelled` / `cancel`（基础） |
| `create_damage_event` | `(target, source, num, type, card = null)` | `target` / `source` / `num` / `type` / `card` |
| `create_recover_event` | `(player, num, source = null)` | `player` / `num` / `source` |
| `create_move_event` | `(player, source_block, target_block)` | `player` / `source_block` / `target_block` |
| `create_draw_game_card_event` | `(player, num)` | `player` / `num` / `cards` |
| `create_draw_scavenge_event` | `(player, pile, num)` | `player` / `pile` / `num` / `cards` / `card` |
| `create_draw_monster_event` | `(player, num)` | `player` / `num` / `cards` / `card` |
| `create_discard_event` | `(player, cards, num = 1)` | `player` / `card` / `cards` / `num` |
| `create_monster_death_event` | `(target, source)` | `target` / `source` |
| `create_player_death_event` | `(target, source)` | `target` / `source` |
| `create_equip_event` | `(player, card)` | `player` / `card` |
| `create_consume_charge_event` | `(player, equipment, num)` | `player` / `card` / `num` |
| `create_sneak_judge_event` | `(player, sneak_value, block = null)` | `player` / `block` / `sneak_value` / `result` / `skip_judge` |
| `create_spawn_judge_event` | `(player)` | `player` / `result` / `skip_judge` |
| `create_destroy_block_event` | `(source, block)` | `source` / `block` |
| `create_objective_mark_event` | `(player, block, mark)` | `player` / `block` / `mark` |
| `create_active_skill_event` | `(player, targets)` | `player` / `targets` |
| `create_game_start_event` | `(player)` | `player` |
| `create_game_over_event` | `(player, result)` | `player` / `result` |
| `create_monster_act_event` | `(monster)` | `monster` / `target_players` |

辅助静态方法：`cancel(event)`（取消事件）、`is_cancelled(event)`（是否已取消）、`set_trigger_name(event, trigger_name)`（写入当前触发名）。

---

## 八、mission_state 键映射

`MissionConfig.mission_state` 为任务特定运行时状态字典，由任务组件（`src/game/mission/components/`）读写（当前无内置任务脚本）。已约定的键：

| 键 | 类型 | 使用方 | 说明 |
| --- | --- | --- | --- |
| `kill_counts` | Dictionary{怪物名: Int} | `kill_monsters`（`triggers` 声明的实例写、`win_conditions` 声明的实例读） | 已击杀各怪物计数（双声明共享） |
| `submitted_items` | Dictionary{物品名: Int} | `submit_items`（写）、`collect_items`（`mode: submit` 时读） | 已在目标地块提交的物品计数 |
| `van_repair_count` | Int | `repair_van`（读写） | 面包车已维修次数 |
| `van_repaired` | Bool | `repair_van`（写） | 面包车是否已维修完成（达到 `times` 次后置 true） |
| `bomb_defused` | Bool | `defuse_bomb`（写） | 炸弹是否已被拆除 |
| `countdown_activate` | Bool | 外部组件（写）、`turn_countdown`（读） | 置 true 时在下一个 `on_event` 中激活倒计时，激活后清除该键 |
| `countdown_active` | Bool | `turn_countdown` | 倒计时是否已激活 |
| `countdown_remaining` | Int | `turn_countdown` | 倒计时剩余轮数 |
| `countdown_expired` | Bool | `turn_countdown` | 倒计时是否已归零（`check_lose` 依据此键判定失败） |
| `rescue_judge_done` | Bool | `rescue_judge_win`（读写） | 是否已执行过解救检定（任务 8，仅一次） |
| `card_discard_failed` | Bool | `card_discard_watch`（`triggers` 声明的实例写、`lose_conditions` 声明的实例读） | 监视卡被弃置且 `on_discard: lose` 时置 true（双声明共享，`check_lose` 依据此键判定失败） |
| `first_enter_done_<block_name>` | Bool | `first_enter_draw_boss`（读写） | 指定地块是否已有玩家首次抵达（全队共享一次，键名按 `block_name` 拼接） |
| `scientist_rescued` | Bool | `spend_action_rescue`（写）、`escort_equipment_at_block`（读） | 科学家（或解救目标卡）是否已被解救 |
| `scientist_holder` | Player | `spend_action_rescue`（写）、`escort_equipment_at_block`（读） | 解救目标的持有者玩家 |

> 说明：新组件新增 `mission_state` 键时，须同步本表。`spend_action_rescue` 与 `escort_equipment_at_block` 的键名可通过 `params` 的 `rescued_key` / `holder_key` 改写，默认即上表键名。`kill_monsters` 与 `card_discard_watch` 需在 `triggers` 与 `win_conditions` / `lose_conditions` 两处声明（两个实例共享同一 `mission_state`）。
