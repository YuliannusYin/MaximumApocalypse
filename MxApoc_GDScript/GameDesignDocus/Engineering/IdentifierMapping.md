# 标识符映射表（中文 → 英文）

> 本文档定义设计文档中的中文标识符到 GDScript 代码中英文标识符（snake_case）的完整映射。
> **命名规范**：类名 PascalCase，方法名/变量名 snake_case，常量/枚举值 UPPER_SNAKE_CASE。
> **映射原则**：意译优先于音译；保留游戏术语特色（如 `van` 面包车）；避免歧义。

---

## 一、类名映射

### 1.1 Core 核心类

| 设计文档类名 | GDScript 类名 | 文件名 | 说明 |
|-------------|---------------|--------|------|
| Entity | `Entity` | `entity.gd` | 实体基类 |
| EventSystem | `EventSystem` | `event_system.gd` | 事件系统（静态工具类） |
| GameStateMachine | `GameStateMachine` | `game_state_machine.gd` | 游戏状态机 |

### 1.2 Entities 实体类

| 设计文档类名 | GDScript 类名 | 文件名 | 说明 |
|-------------|---------------|--------|------|
| Player | `Player` | `player.gd` | 玩家类 |
| Monster | `Monster` | `monster.gd` | 怪物类 |
| Card | `Card` | `card.gd` | 卡牌基类 |
| ScavengeCard | `ScavengeCard` | `card.gd` | 拾荒卡 |
| SurvivorGameCard | `SurvivorGameCard` | `card.gd` | 求生者游戏牌 |
| EquipmentCard | `EquipmentCard` | `card.gd` | 装备牌 |
| MonsterCard | `MonsterCard` | `card.gd` | 怪物卡（实体化前） |
| MapBlock | `MapBlock` | `map_block.gd` | 地图块类 |
| ObjectiveMark | `ObjectiveMark` | `map_block.gd` | 目标标记结构 |

### 1.3 Game 游戏全局类

| 设计文档类名 | GDScript 类名 | 文件名 | 说明 |
|-------------|---------------|--------|------|
| Game | `Game` | `game.gd` | 游戏全局类 |
| MissionConfig | `MissionConfig` | `mission_config.gd` | 任务配置结构 |

### 1.4 Common 通用结构

| 设计文档类名 | GDScript 类名 | 文件名 | 说明 |
|-------------|---------------|--------|------|
| Pile | `Pile` | `pile.gd` | 牌堆类 |
| RoleCard | `RoleCard` | `role_card.gd` | 角色卡类 |
| Skill | `Skill` | `skill.gd` | 技能结构 |

### 1.5 Data 数据类（新增，见 DataFormat.md）

| 数据类名 | 文件名 | 说明 |
|---------|--------|------|
| `SurvivorData` | `survivor_data.gd` | 求生者静态数据 |
| `ScavengeCardData` | `scavenge_card_data.gd` | 拾荒卡静态数据 |
| `MonsterCardData` | `monster_card_data.gd` | 怪物卡静态数据 |
| `MissionData` | `mission_data.gd` | 任务静态数据 |
| `MapBlockData` | `map_block_data.gd` | 地图块静态数据 |
| `SkillData` | `skill_data.gd` | 技能静态数据 |
| `DataManager` | `data_manager.gd` | 数据管理器（autoload） |

---

## 二、枚举值映射

### 2.1 怪物级别（MonsterLevel）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 首领 | `BOSS` | 首领卡 |
| 精英 | `ELITE` | 精英怪 |
| 普通 | `NORMAL` | 普通怪 |

```gdscript
enum MonsterLevel { BOSS, ELITE, NORMAL }
```

### 2.2 怪物类型（MonsterType）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 外星人 | `ALIEN` | alien |
| 突变体 | `MUTANT` | mutant |
| 僵尸 | `ZOMBIE` | zombie |
| 机器人 | `ROBOT` | robot |

```gdscript
enum MonsterType { ALIEN, MUTANT, ZOMBIE, ROBOT }
```

### 2.3 射程（Range）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 无 | `NONE` | 玩家只能指定自己 / 怪物只攻击纠缠对象 |
| 短距离 | `SHORT` | 1 格 |
| 中距离 | `MEDIUM` | 1-2 格 |
| 长距离 | `LONG` | 2-3 格（不含 1 格） |
| Infinity | `INFINITY` | 任意距离 |

```gdscript
enum Range { NONE, SHORT, MEDIUM, LONG, INFINITY }
```

### 2.4 拾荒颜色（ScavengeColor）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 红色 | `RED` | 危险类，含伏击 |
| 绿色 | `GREEN` | 日常类 |
| 蓝色 | `BLUE` | 战备类，最安全 |
| 灰色 | `GRAY` | 通用（一无所获/伏击） |

```gdscript
enum ScavengeColor { RED, GREEN, BLUE, GRAY }
```

### 2.5 卡牌类型（CardType）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 行动 | `ACTION` | 行动牌 |
| 装备 | `EQUIPMENT` | 装备牌 |

```gdscript
enum CardType { ACTION, EQUIPMENT }
```

### 2.6 卡牌来源（CardSource）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| scavenge | `SCAVENGE` | 拾荒牌堆 |
| game | `GAME` | 游戏牌堆 |
| monster | `MONSTER` | 怪物牌堆 |

```gdscript
enum CardSource { SCAVENGE, GAME, MONSTER }
```

### 2.7 任务难度（Difficulty）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 特别简单 | `TUTORIAL` | 教程关 |
| 非常简单 | `VERY_EASY` | |
| 简单 | `EASY` | |
| 正常 | `NORMAL` | |
| 困难 | `HARD` | |
| 非常困难 | `VERY_HARD` | |

```gdscript
enum Difficulty { TUTORIAL, VERY_EASY, EASY, NORMAL, HARD, VERY_HARD }
```

### 2.8 回合阶段（Phase）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 回合外 | `OUT_OF_TURN` | 默认值 |
| 回合开始 | `TURN_START` | |
| 怪物出生 | `MONSTER_SPAWN` | |
| 摸牌阶段 | `DRAW` | |
| 行动阶段 | `ACTION` | |
| 饥饿结算 | `HUNGER` | |
| 中毒结算 | `POISON` | |
| 怪物行动 | `MONSTER_ACTION` | |
| 回合结束 | `TURN_END` | |

```gdscript
enum Phase { OUT_OF_TURN, TURN_START, MONSTER_SPAWN, DRAW, ACTION, HUNGER, POISON, MONSTER_ACTION, TURN_END }
```

### 2.9 游戏状态（GameState）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 等待开始 | `WAITING` | |
| 游戏中 | `PLAYING` | |
| 游戏结束 | `GAME_OVER` | |

```gdscript
enum GameState { WAITING, PLAYING, GAME_OVER }
```

### 2.10 游戏结果（GameResult）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| win | `WIN` | 胜利 |
| lose | `LOSE` | 失败 |

```gdscript
enum GameResult { WIN, LOSE }
```

### 2.11 伤害类型（DamageType）

| 设计文档值 | 枚举值 | 说明 |
|----------|--------|------|
| 近战 | `MELEE` | 近战伤害 |
| 远程 | `RANGED` | 远程伤害 |
| 饥饿 | `HUNGER` | 饥饿伤害（无来源） |
| 中毒 | `POISON` | 中毒伤害（无来源） |
| 其他 | `OTHER` | 其他类型 |

```gdscript
enum DamageType { MELEE, RANGED, HUNGER, POISON, OTHER }
```

---

## 三、字段映射

### 3.1 Entity 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| skills | `skills` | `Array[Skill]` | 技能列表 |

### 3.2 Player 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 生命值 | `hp` | `int` | 当前生命值 |
| 最大生命值 | `max_hp` | `int` | 生命值上限 |
| 饥饿值 | `hunger` | `int` | 1-6 |
| 潜行值 | `stealth` | `int` | 基础潜行值 |
| 饥饿状态潜行值 | `hunger_stealth` | `int` | 饥饿状态下的潜行值 |
| 行动次数 | `action_count` | `int` | 当前行动次数 |
| 最大行动次数 | `max_action_count` | `int` | 行动次数上限 |
| inPhase | `in_phase` | `Phase` | 当前回合阶段 |
| 手牌区 | `hand` | `Array[Card]` | 手牌（上限 10） |
| 装备区 | `equipment_zone` | `Array[EquipmentCard]` | 装备牌区域 |
| 怪物区 | `monster_zone` | `Array[Monster]` | 玩家面前的怪物 |
| 游戏牌堆 | `game_deck` | `Pile` | 求生者游戏牌堆 |
| 游戏牌弃牌堆 | `game_discard_pile` | `Pile` | 游戏牌弃牌堆 |
| 角色卡 | `role_card` | `RoleCard` | 角色卡 |
| 当前地块 | `current_block` | `MapBlock` | 玩家所在地块 |
| 座位号 | `seat_number` | `int` | 座位次序 |
| 名字 | `character_name` | `String` | 角色名 |

### 3.3 Player 标记

| 设计文档标记 | GDScript 标记 key | 类型 | 说明 |
|-------------|-------------------|------|------|
| 中毒标记 | `"poison"` | `int` | 中毒层数 |
| 饥饿伤害等级 | `"hunger_damage_level"` | `int` | 1-5 |
| 避难所失效 | `"shelter_disabled"` | `bool` | 回合结束清除 |
| 本回合已移动 | `"moved_this_turn"` | `bool` | 回合开始清除 |

### 3.4 Monster 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 类型 | `monster_type` | `MonsterType` | 怪物类型 |
| 级别 | `monster_level` | `MonsterLevel` | 怪物级别 |
| 最大生命值 | `max_hp` | `int` | 生命值上限 |
| 当前生命值 | `current_hp` | `int` | 当前生命值 |
| 伤害值 | `attack_damage` | `int` | 攻击伤害 |
| 射程 | `range` | `Range` | 怪物射程 |
| 纠缠对象 | `attack_target` | `Player` | 纠缠的玩家 |
| 击晕 | `stunned` | `bool` | 是否被击晕 |

### 3.5 Card 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 名字 | `card_name` | `String` | 卡牌中文名 |
| 英文名 | `english_name` | `String` | 卡牌英文名（content 代码按名查找，如 game.get_card） |
| 类型 | `card_type` | `CardType` | 卡牌类型 |
| source | `source` | `CardSource` | 卡牌来源 |
| 大小 | `size` | `int` | 占用装备栏格数 |
| 射程 | `range` | `Range` | 行动牌射程 |
| 颜色 | `color` | `ScavengeColor` | 拾荒卡颜色 |
| 填充物类型 | `charge_type` | `String` | 弹药/燃料/空尖弹等 |
| 填充物上限 | `charge_max` | `int` | 填充物上限 |
| 填充物当前量 | `charge_current` | `int` | 当前填充物数量 |
| 装备区标记 | `in_equipment_area` | `bool` | 标记装备牌是否在玩家装备区内 |

### 3.6 MapBlock 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 地图块名称 | `block_name` | `String` | 地块中文名 |
| 坐标 | `coordinate` | `Vector2i` | `{x, y}` |
| 拾荒颜色 | `scavenge_colors` | `Array[ScavengeColor]` | 可拾荒颜色集合 |
| 怪物生成点数 | `monster_spawn_value` | `int` | 怪物出生检定点数 |
| 怪物标记 | `monster_marks` | `int` | 怪物标记数（0-3） |
| 已展示 | `is_revealed` | `bool` | 是否已翻开 |
| 已摧毁 | `is_destroyed` | `bool` | 是否已摧毁 |
| 目标标记 | `objective_marks` | `Array[ObjectiveMark]` | 目标标记列表 |

### 3.7 ObjectiveMark 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 标记ID | `mark_id` | `String` | 标记唯一标识 |
| 标记描述 | `mark_description` | `String` | 标记描述 |
| 初始怪物标记数 | `initial_monster_marks` | `int` | 预置怪物标记数 |
| 移除条件 | `remove_condition` | `Callable` | 移除条件函数 |
| 标记效果 | `effect` | `Callable` | 标记效果函数 |
| 已触发 | `is_triggered` | `bool` | 是否已触发（一次性） |

### 3.8 Game 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 玩家列表 | `players` | `Array[Player]` | 所有玩家 |
| 当前玩家 | `current_player` | `Player` | 当前行动玩家 |
| 地图区域 | `map_area` | `Dictionary` | 坐标 → MapBlock |
| 怪物牌堆 | `monster_deck` | `Pile` | 怪物牌堆 |
| 怪物弃牌堆 | `monster_discard_pile` | `Pile` | 怪物弃牌堆 |
| 拾荒牌堆 | `scavenge_piles` | `Dictionary` | 颜色 → Pile |
| 拾荒弃牌堆 | `scavenge_discard_piles` | `Dictionary` | 颜色 → Pile |
| 游戏结束点地块 | `game_end_block` | `MapBlock` | 游戏结束点 |
| 面包车燃料 | `van_fuel` | `int` | 面包车已添加燃料 |
| 任务配置 | `mission_config` | `MissionConfig` | 任务配置 |
| 同生共死模式 | `coop_death_mode` | `bool` | 同生共死开关 |
| 状态机 | `state_machine` | `GameStateMachine` | 状态机实例 |
| 当前任务 | `current_mission` | `MissionData` | 当前任务数据 |

### 3.9 MissionConfig 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 启动面包车所需燃料 | `van_fuel_required` | `int / null` | NULL 表示不通过面包车胜利 |
| 检查胜利条件 | `check_win_condition` | `Callable` | 胜利判定函数 |
| 任务状态 | `mission_state` | `Dictionary` | 任务运行时状态 |

### 3.10 GameStateMachine 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 当前状态 | `current_state` | `GameState` | 游戏状态 |
| 回合队列 | `turn_queue` | `Array[Player]` | 回合顺序队列 |
| 当前玩家 | `current_player` | `Player` | 当前行动玩家 |
| 额外回合队列 | `extra_turn_queue` | `Array[Player]` | 额外回合队列 |
| 跳过标记 | `skip_next_turn` | `Dictionary` | 玩家 → 是否跳过下回合 |

### 3.11 Pile 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 牌列表 | `cards` | `Array[Card]` | 牌堆中的卡牌列表 |

### 3.12 RoleCard 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 装备栏容量 | `equipment_capacity` | `int` | 装备栏格数上限 |
| 已翻面 | `is_flipped` | `bool` | 是否已翻面（饥饿状态） |
| 饥饿伤害等级 | `hunger_damage_level` | `int` | 翻面后的饥饿伤害等级 |

### 3.13 Skill 字段

| 设计文档字段 | GDScript 字段 | 类型 | 说明 |
|-------------|---------------|------|------|
| 技能名 | `skill_name` | `String` | 技能名 |
| 技能描述 | `skill_description` | `String` | 技能描述 |
| active | `active` | `String / null` | 可用阶段 |
| trigger | `trigger` | `String / null` | 触发名 |
| skillType | `skill_type` | `String / null` | 技能类型 |
| forced | `forced` | `bool` | 是否强制发动 |
| filter | `filter` | `Callable / null` | 过滤函数 |
| filterTarget | `filter_target` | `Callable / null` | 目标过滤函数 |
| filterTargetRange | `filter_target_range` | `Range / null` | 目标距离限制 |
| filterCard | `filter_card` | `Callable / null` | 选牌过滤函数 |
| position | `position` | `String / null` | 选牌位置限定 |
| selectCard | `select_card` | `int` | 需选择牌数 |
| selectTarget | `select_target` | `int` | 需选择目标数 |
| 射程 | `range` | `Range / null` | 攻击射程 |
| usable | `usable` | `int / null` | 每回合可用次数 |
| content | `content` | `Callable` | 技能效果执行体 |

---

## 四、方法映射

### 4.1 Entity 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| entity.trigger(triggerName, event) | `trigger(trigger_name: String, event: Dictionary) -> void` | 触发技能 |
| entity.getAllSkills() | `get_all_skills() -> Array[Skill]` | 获取所有技能 |
| entity.addSkill(skill) | `add_skill(skill: Skill) -> void` | 挂载技能 |
| entity.removeSkill(skill) | `remove_skill(skill: Skill) -> void` | 移除技能 |
| entity.damage(num, source, type, card) | `damage(num: int, source: Entity, type: DamageType = null, card: Card = null) -> void` | 伤害流程 |
| entity.get_hp() | `get_hp() -> int` | 获取生命值 |
| entity.get_max_hp() | `get_max_hp() -> int` | 获取最大生命值 |
| entity.reduce_hp(n) | `reduce_hp(n: int) -> void` | 直接扣血 |
| entity.add_hp(n) | `add_hp(n: int) -> void` | 直接加血 |
| entity.isPlayer() | `is_player() -> bool` | 是否为 Player |
| entity.isMonster() | `is_monster() -> bool` | 是否为 Monster |
| entity.death(source) | `death(source: Entity) -> void` | 死亡流程（抽象） |

### 4.2 Player 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| player.recover(num) | `recover(num: int) -> void` | 回复生命流程 |
| player.increaseHunger(num) | `increase_hunger(num: int) -> void` | 增加饥饿值 |
| player.decreaseHunger(num) | `decrease_hunger(num: int) -> void` | 减少饥饿值 |
| player.poison() | `poison() -> void` | 中毒结算 |
| player.draw(n) | `draw(n: int) -> void` | 抓游戏牌 |
| player.drawScavenge(n, pile) | `draw_scavenge(n: int, pile: Pile) -> void` | 抓拾荒牌 |
| player.drawMonster(n) | `draw_monster(n: int) -> void` | 抓怪物卡 |
| player.discard(target, position, quantity, type) | `discard(target, position: String = null, quantity: int = 1, type: String = null) -> void` | 弃置牌 |
| player.removeCard(target, position, quantity) | `remove_card(target, position: String = null, quantity: int = 1) -> void` | 销毁牌 |
| player.moveTo(target) | `move_to(target: MapBlock) -> void` | 移动到地块 |
| player.judge() | `judge() -> int` | 投骰检定 |
| player.sneakJudge() | `sneak_judge() -> bool` | 潜行检定 |
| player.monsterSpawnJudge() | `monster_spawn_judge() -> void` | 怪物出生检定 |
| player.playerDeath(source) | `player_death(source: Entity) -> void` | 玩家死亡流程 |
| player.useCard(card) | `use_card(card: Card) -> void` | 使用卡牌 |
| player.装备(card) | `equip(card: EquipmentCard) -> void` | 装备牌进入装备区 |
| player.卸下(card) | `unequip(card: EquipmentCard) -> void` | 装备牌离开装备区 |
| player.消耗填充物(equipment, num) | `consume_charge(equipment: EquipmentCard, num: int) -> void` | 消耗填充物 |
| player.开始回合() | `start_turn() -> void` | 开始回合（21 节点流程） |
| player.立即执行一个行动(num) | `execute_immediate_action(num: int = 1) -> void` | 迷你回合 |
| player.弃置面前的一张非首领怪物并替换为怪物标记() | `discard_non_boss_monster_to_mark() -> void` | 弃置非首领怪物 |
| player.向玩家拉近一格不触发效果(target) | `move_closer_no_effect(target: Player) -> void` | 拉近一格 |
| player.治疗所有状态效果() | `cure_all_status_effects() -> void` | 治疗状态 |
| player.立即打出一张牌() | `play_card_immediately() -> void` | 立即打出 |
| player.收集物品(卡牌名, 数量) | `collect_item(card_name: String, count: int) -> void` | 收集物品（任务系统） |
| player.hasItem(卡牌名) | `has_item(card_name: String) -> bool` | 判断是否持有物品 |
| player.drawBossCard() | `draw_boss_card() -> void` | 抽首领卡 |
| player.获得解救科学家的选项() | `get_rescue_scientist_option() -> void` | 解救科学家选项 |
| player.记录科学家信息() | `record_scientist_info() -> void` | 记录科学家信息 |
| player.扣除行动次数(n) | `consume_action(n: int) -> void` | 扣除行动次数（= reduce_action_count 别名，content 代码统一调用名） |
| player.增加行动次数(n) | `add_action(n: int) -> void` | 增加行动次数 |
| player.添加临时技能(skill_id, expire_trigger) | `add_temp_skill(skill_id: String, expire_trigger: String) -> void` | 临时技能挂载（expire_trigger 触发后自动移除） |
| player.获取牌堆(name) | `get_pile(name: String) -> Variant` | 按名获取牌堆（deck/hand/equipment/discard） |
| player.gain(card) | `gain(card: Card) -> void` | 将卡牌加入手牌区 |
| player.getDiscardPile() | `get_discard_pile() -> Pile` | 返回游戏牌弃牌堆 |

### 4.3 Player 查询接口

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| player.getNumber("xxx") | `get_number(key: String) -> int` | 查询数值标记 |
| player.getEquipment("xxx") | `get_equipment(name: String) -> EquipmentCard` | 按名获取装备 |
| player.hasEquipment("xxx") | `has_equipment(name: String) -> bool` | 判断是否持有装备 |
| player.get填充物数量("xxx") | `get_charge_count(equipment_name: String) -> int` | 查询装备填充物数量（装备不存在返回 0） |
| player.get_current_block() | `get_current_block() -> MapBlock` | 获取当前地块 |

### 4.4 Player 选择器（UI 交互）

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| player.等待玩家行动() | `wait_player_action() -> void` | 等待玩家行动（UI 驱动） |
| target.choose(list) | `choose(options: Array) -> int` | 列表选择 |
| target.chooseCard(n, position, source) | `choose_card(n: int, position: String, source: String) -> Array[Card]` | 选牌 |
| player.chooseCard(n, param, filter) | `choose_card(n: int, param: Variant, filter: Variant = null) -> Array` | 选择卡牌（param 为 String 按 position 查询；为 Array 直接作为候选列表） |
| player.chooseTarget(n, skill) | `choose_target(n: int, skill: Variant) -> Array` | 选择目标（n=-1 全部；skill 含 target_type/filter_target） |
| player.showCard(card, target) | `show_card(card: Card, target: Player) -> void` | 展示卡牌 |

### 4.5 Monster 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| monster.行动() | `act() -> void` | 怪物行动 |
| monster.攻击() | `attack() -> void` | 怪物攻击 |
| monster.修改纠缠对象(target) | `change_engaged_target(target: Player) -> void` | 修改纠缠对象 |
| monster.monsterDeath(source) | `monster_death(source: Entity) -> void` | 怪物死亡 |
| monster.击晕(source, expire_trigger) | `stun(source: Variant, expire_trigger: String) -> void` | 击晕怪物（设置 stunned=true，行动时清除并跳过） |
| MonsterCard.实体化(player) | `instantiate(player: Player) -> Monster` | 怪物卡实体化 |

### 4.6 MapBlock 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| block.展示(触发效果, player) | `reveal(trigger_effect: bool, player: Player) -> void` | 展示地块 |
| block.getCoordinate() | `get_coordinate() -> Vector2i` | 获取坐标 |
| block.setCoordinate(x, y) | `set_coordinate(x: int, y: int) -> void` | 设置坐标 |
| block.isAlive() | `is_alive() -> bool` | 是否存活 |
| block.isDestroyed() | `is_destroyed() -> bool` | 是否已摧毁 |
| block.getAdjacentBlocks() | `get_adjacent_blocks() -> Array[MapBlock]` | 获取相邻地块 |
| block.distanceTo(other) | `distance_to(other: MapBlock) -> int` | 曼哈顿距离 |
| block.getBlocksInRange(range) | `get_blocks_in_range(range: Range) -> Array[MapBlock]` | 射程内地块 |
| block.getPlayersInRange(range) | `get_players_in_range(range: Range) -> Array[Player]` | 射程内玩家 |
| block.getPlayers() | `get_players() -> Array[Player]` | 地块上玩家 |
| block.hasObjectiveMark() | `has_objective_mark() -> bool` | 是否有目标标记 |
| block.addObjectiveMark(mark) | `add_objective_mark(mark: ObjectiveMark) -> void` | 添加目标标记 |
| block.removeObjectiveMark(mark) | `remove_objective_mark(mark: ObjectiveMark) -> void` | 移除目标标记 |
| block.removeAllObjectiveMarks() | `remove_all_objective_marks() -> void` | 移除所有目标标记 |
| block.triggerObjectiveMarks(player) | `trigger_objective_marks(player: Player) -> void` | 触发目标标记 |
| block.countMonsterMark() | `count_monster_marks() -> int` | 怪物标记数 |
| block.addMonsterMark() | `add_monster_mark() -> void` | 添加怪物标记 |
| block.removeMonsterMark() | `remove_monster_mark() -> void` | 移除怪物标记 |
| block.hasColor() | `has_scavenge_color() -> bool` | 是否可拾荒 |
| mapBlock.isMapBlock() | `is_map_block() -> bool` | 是否为地图块（供 filter_target 区分地块目标） |

### 4.7 Game 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| game.startGame() | `start_game() -> void` | 开始游戏 |
| game.gameOver(result) | `game_over(result: GameResult) -> void` | 游戏结束 |
| game.allPlayersDead() | `all_players_dead() -> bool` | 所有玩家死亡 |
| game.removeCard(card) | `remove_card(card: Card) -> void` | 移出游戏 |
| game.getScavengePile(颜色) | `get_scavenge_pile(color: ScavengeColor) -> Pile` | 获取拾荒牌堆 |
| game.log(message) | `log(message: String) -> void` | 输出日志 |
| game.buildMap(missionConfig) | `build_map(mission_config: MissionConfig) -> void` | 构建地图 |
| game.getBlockByCoord(x, y) | `get_block_by_coord(x: int, y: int) -> MapBlock` | 按坐标获取地块 |
| game.getBlocksByName(name) | `get_blocks_by_name(name: String) -> Array[MapBlock]` | 按名获取地块 |
| game.getAdjacentAliveBlocks(block) | `get_adjacent_alive_blocks(block: MapBlock) -> Array[MapBlock]` | 相邻存活地块 |
| game.destroyMapBlock(block, source) | `destroy_map_block(block: MapBlock, source: Entity) -> void` | 摧毁地块 |
| game.检查任务胜利条件() | `check_mission_win_condition() -> bool` | 检查任务胜利 |
| game.createScavengeCard(cardName) | `create_scavenge_card(card_name: String) -> Card` | 按 card_name 创建拾荒卡实例 |
| game.getCard(英文名, pile) | `get_card(card_english_name: String, pile: Variant) -> Card` | 从牌堆查找卡牌（pile 可为 Pile 或 Array） |
| game.getTarget(block) | `get_target(block: MapBlock) -> Array` | 获取地块上玩家+怪物 |

### 4.8 GameStateMachine 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| gsm.startGame() | `start_game() -> void` | 启动游戏 |
| gsm.gameOver(result) | `game_over(result: GameResult) -> void` | 游戏结束 |
| gsm.nextTurn() | `next_turn() -> void` | 下一个回合 |
| gsm.getCurrentPlayer() | `get_current_player() -> Player` | 获取当前玩家 |
| gsm.checkWinCondition() | `check_win_condition() -> bool` | 胜利判定 |
| gsm.queueExtraTurn(player) | `queue_extra_turn(player: Player) -> void` | 加入额外回合 |
| gsm.skipNextTurn(player) | `skip_next_turn(player: Player) -> void` | 跳过下回合 |

### 4.9 Pile 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| pile.draw() | `draw() -> Card` | 抓一张牌 |
| pile.isEmpty() | `is_empty() -> bool` | 是否为空 |
| pile.add(card) | `add(card: Card) -> void` | 加入底部 |
| pile.shuffle() | `shuffle() -> void` | 洗牌 |
| pile.shuffleInto(targetPile) | `shuffle_into(target_pile: Pile) -> void` | 洗入目标牌堆 |
| pile.getAll() | `get_all() -> Array[Card]` | 获取所有牌 |
| pile.peekTop(n) | `peek_top(n: int) -> Array` | 查看牌堆顶 n 张牌（不移除） |
| pile.putBottom(card) | `put_bottom(card: Card) -> void` | 将一张牌置于牌堆底 |

### 4.10 EquipmentCard 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| equipmentCard.fillCharge() | `fill_charge() -> void` | 将填充物填满到上限 |

### 4.11 ScavengeCard 方法

| 设计文档方法 | GDScript 方法 | 说明 |
|-------------|---------------|------|
| scavengeCard.getColor() | `get_color() -> String` | 返回拾荒卡颜色 |

---

## 五、Trigger 名映射

> Trigger 名在 JSON 数据中用英文 snake_case，在 EventSystem 中注册时用英文常量。
> 完整 trigger 索引见 [EventSystem.md §4](../GameSystem/Core/EventSystem.md) 与 [K_gameTerminology.md §7](../GameInstructions/K_gameTerminology.md#7-事件-trigger)。

### 5.1 伤害类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 造成伤害前 | `before_deal_damage` | 否 |
| 造成伤害时 | `on_deal_damage` | 否 |
| 造成伤害后 | `after_deal_damage` | 否 |
| 受到伤害前 | `before_take_damage` | 否 |
| 受到伤害时 | `on_take_damage` | ✅ 是 |
| 受到伤害后 | `after_take_damage` | 否 |
| 回复生命前 | `before_recover` | 否 |
| 回复生命时 | `on_recover` | 否 |
| 回复生命后 | `after_recover` | 否 |

### 5.2 移动类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 离开地块前 | `before_leave_block` | 否 |
| 离开地块时 | `on_leave_block` | 否 |
| 离开地块后 | `after_leave_block` | 否 |
| 进入地块前 | `before_enter_block` | ✅ 是 |
| 进入地块时 | `on_enter_block` | 否 |
| 进入地块后 | `after_enter_block` | 否 |
| 展示地块时 | `on_reveal_block` | 否 |

### 5.3 怪物类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 怪物卡进入求生者怪物区前 | `before_monster_enter_zone` | 否 |
| 怪物卡进入求生者怪物区时 | `on_monster_enter_zone` | 否 |
| 怪物卡进入求生者怪物区后 | `after_monster_enter_zone` | 否 |
| 怪物行动前 | `before_monster_act` | 否 |
| 怪物行动时 | `on_monster_act` | 否 |
| 怪物行动后 | `after_monster_act` | 否 |
| 怪物攻击前 | `before_monster_attack` | 否 |
| 怪物攻击时 | `on_monster_attack` | 否 |
| 怪物攻击后 | `after_monster_attack` | 否 |
| 怪物死亡前 | `before_monster_death` | 否 |
| 怪物死亡时 | `on_monster_death` | 否 |
| 怪物死亡后 | `after_monster_death` | 否 |
| 玩家死亡前 | `before_player_death` | 否 |
| 玩家死亡时 | `on_player_death` | 否 |
| 玩家死亡后 | `after_player_death` | 否 |

### 5.4 回合类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 回合开始前 | `before_turn_start` | 否 |
| 回合开始时 | `on_turn_start` | 否 |
| 怪物出生前 | `before_monster_spawn` | 否 |
| 怪物出生时 | `on_monster_spawn` | 否 |
| 摸牌阶段前 | `before_draw_phase` | 否 |
| 行动阶段前 | `before_action_phase` | 否 |
| 行动阶段结束前 | `before_action_phase_end` | 否 |
| 行动阶段结束时 | `on_action_phase_end` | 否 |
| 求生者饥饿状态结算前 | `before_hunger_settlement` | 否 |
| 求生者饥饿状态结算时 | `on_hunger_settlement` | 否 |
| 求生者中毒状态结算前 | `before_poison_settlement` | 否 |
| 求生者中毒状态结算时 | `on_poison_settlement` | 否 |
| 面前怪物行动前 | `before_zone_monster_act` | 否 |
| 面前怪物行动时 | `on_zone_monster_act` | 否 |
| 回合结束前 | `before_turn_end` | 否 |
| 回合结束时 | `on_turn_end` | 否 |

### 5.5 抓牌类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 抓取游戏牌前 | `before_draw_game_card` | ✅ 是 |
| 抓取游戏牌时 | `on_draw_game_card` | ✅ 是 |
| 抓取游戏牌后 | `after_draw_game_card` | 否 |
| 抓取怪物卡前 | `before_draw_monster_card` | ✅ 是 |
| 抓取怪物卡时 | `on_draw_monster_card` | 否 |
| 抓取怪物卡后 | `after_draw_monster_card` | 否 |
| 抓取拾荒牌前 | `before_draw_scavenge_card` | ✅ 是 |
| 抓取拾荒牌时 | `on_draw_scavenge_card` | 否 |
| 抓取拾荒牌后 | `after_draw_scavenge_card` | 否 |

### 5.6 使用卡牌类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 使用卡牌前 | `before_use_card` | ✅ 是 |
| 使用卡牌时 | `on_use_card` | ✅ 是 |
| 使用卡牌后 | `after_use_card` | 否 |

### 5.7 装备类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 卡牌进入装备区前 | `before_equip` | ✅ 是 |
| 卡牌进入装备区时 | `on_equip` | 否 |
| 卡牌进入装备区后 | `after_equip` | 否 |
| 卡牌离开装备区前 | `before_unequip` | ✅ 是 |
| 卡牌离开装备区时 | `on_unequip` | 否 |
| 卡牌离开装备区后 | `after_unequip` | 否 |
| 消耗填充物前 | `before_consume_charge` | ✅ 是 |
| 消耗填充物时 | `on_consume_charge` | ✅ 是 |
| 消耗填充物后 | `after_consume_charge` | 否 |
| 填充物耗尽时 | `on_charge_depleted` | 否 |

### 5.8 检定类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 潜行检定前 | `before_sneak_judge` | 否 |
| 潜行检定时 | `on_sneak_judge` | 否 |
| 潜行检定后 | `after_sneak_judge` | 否 |
| 怪物出生检定前 | `before_spawn_judge` | 否 |
| 怪物出生检定时 | `on_spawn_judge` | 否 |
| 怪物出生检定后 | `after_spawn_judge` | 否 |

### 5.9 游戏类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 游戏开始时 | `on_game_start` | 否 |
| 游戏结束时 | `on_game_over` | 否 |

### 5.10 弃牌类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 弃置牌前 | `before_discard` | ✅ 是 |
| 弃置牌时 | `on_discard` | 否 |
| 弃置牌后 | `after_discard` | 否 |

### 5.11 销毁类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 销毁牌前 | `before_remove_card` | ✅ 是 |
| 销毁牌时 | `on_remove_card` | 否 |
| 销毁牌后 | `after_remove_card` | 否 |

### 5.12 地图类 trigger

| 设计文档 trigger 名 | 英文常量 | 取消点 |
|-------------------|---------|--------|
| 摧毁地块前 | `before_destroy_block` | ✅ 是 |
| 摧毁地块时 | `on_destroy_block` | 否 |
| 摧毁地块后 | `after_destroy_block` | 否 |
| 触发目标标记时 | `on_trigger_objective_mark` | 否 |

---

## 六、Event 字段映射

| 设计文档字段 | GDScript event key | 类型 | 说明 |
|-------------|-------------------|------|------|
| triggerName | `"trigger_name"` | `String` | 当前 trigger 名 |
| cancelled | `"cancelled"` | `bool` | 是否已取消 |
| cancel() | `event["cancel"]()` | `Callable` | 取消函数 |
| target | `"target"` | `Entity` | 受伤实体/死亡实体 |
| source | `"source"` | `Entity / null` | 伤害来源 |
| num | `"num"` | `int` | 伤害/回复/抓牌数 |
| type | `"type"` | `DamageType` | 伤害类型 |
| card | `"card"` | `Card / null` | 武器牌 |
| player | `"player"` | `Player` | 玩家 |
| source_block | `"source_block"` | `MapBlock` | 离开的地块 |
| target_block | `"target_block"` | `MapBlock` | 进入的地块 |
| cards | `"cards"` | `Array[Card]` | 抓到的牌列表 |
| pile | `"pile"` | `Pile` | 牌堆 |
| sneakValue | `"sneak_value"` | `int` | 潜行检定阈值 |
| result | `"result"` | `Dictionary` | 检定结果 `{value, success}` |
| skipJudge | `"skip_judge"` | `bool` | 是否跳过投骰 |
| block | `"block"` | `MapBlock` | 被摧毁的地块 |
| mark | `"mark"` | `ObjectiveMark` | 目标标记 |
| targets | `"targets"` | `Array` | 主动技能目标列表 |

---

## 七、通用行动技能名映射

| 设计文档技能名 | 英文标识符 | 说明 |
|--------------|----------|------|
| 移动 | `move` | 移动到目标地块 |
| 拾荒 | `scavenge` | 抓拾荒牌 |
| 摸牌 | `draw_game_card` | 抓游戏牌 |
| 制衡 | `mulligan` | 弃2抓1 |
| 交易 | `trade` | 交易拾荒卡 |
| 加油 | `refuel` | 补充燃料 |

---

## 八、任务状态键名映射

任务运行时状态（`mission_state` 字典）的常用键名：

| 设计文档键名 | 英文 key | 使用任务 | 说明 |
|-------------|---------|---------|------|
| 已记录科学家信息 | `"scientist_info_recorded"` | 8 | 已记录科学家信息 |
| 科学家装备牌 | `"scientist_equipment_card"` | 3/8/9 | 科学家装备牌实例 |
| 已解救科学家 | `"scientist_rescued"` | 1/3/8 | 已解救科学家 |
| 炸弹已解除 | `"bomb_defused"` | 5 | 炸弹已解除 |
| 解除后回合计数 | `"turns_after_defuse"` | 5 | 解除后的回合数 |
| 已摧毁发射器数 | `"destroyed_launchers"` | 9 | 已摧毁的外星发射器数 |
| 已修车次数 | `"van_repaired_count"` | 6 | 面包车维修次数 |
| 已清除目标标记 | `"cleared_objectives"` | 11 | 已清除的目标标记数 |

---

## 九、映射维护规则

1. **新增标识符**：设计文档新增字段/方法/trigger 时，必须同步更新本映射表
2. **命名一致性**：英文标识符在代码、JSON 数据、文档中保持一致
3. **避免冲突**：新增标识符前检查是否与已有标识符冲突
4. **版本管理**：标识符重命名需在映射表中标注旧名 → 新名的迁移说明
5. **自动化校验**：`tools/identifier_checker.gd`（待实现）可校验代码中的标识符是否符合本映射表

---

## 十、与其他文档的关系

| 文档 | 说明 |
|------|------|
| [GodotProjectStructure.md](GodotProjectStructure.md) | 项目目录结构与编码规范 |
| [DataFormat.md](DataFormat.md) | JSON 数据格式（使用本表的枚举值映射） |
| [../GameSystem/](../GameSystem/README.md) | 系统设计源文档（中文标识符来源） |
| [../GameInstructions/K_gameTerminology.md](../GameInstructions/K_gameTerminology.md) | 游戏术语表（trigger 名来源） |

---

## 十一、消防员卡牌使用流程新增映射

> 以下映射为消防员卡牌使用流程（`data/survivors/firefighter.json`）落地新增的标识符。
> 方法/字段映射已并入对应章节，此处集中索引并记录信号变更（无既有信号章节）。

### 11.1 新增方法/字段索引

| 标识符 | 类别 | 所在章节 |
|--------|------|---------|
| `consume_action(n)` | Player 方法 | §4.2 |
| `add_action(n)` | Player 方法 | §4.2 |
| `add_temp_skill(skill_id, expire_trigger)` | Player 方法 | §4.2 |
| `get_pile(name)` | Player 方法 | §4.2 |
| `get_charge_count(equipment_name)` | Player 查询接口 | §4.3（参数名由 `name` 更新为 `equipment_name`） |
| `choose_target(n, skill)` | Player 选择器 | §4.4 |
| `stun(source, expire_trigger)` | Monster 方法 | §4.5 |
| `get_card(card_english_name, pile)` | Game 方法 | §4.7 |
| `get_target(block)` | Game 方法 | §4.7 |
| `log(message)` | Game 方法 | §4.7（已存在，= `log_message` 别名） |
| `english_name` | Card 字段 | §3.5 |

### 11.2 信号变更

| 信号 | 旧签名 | 新签名 | 所在文件 | 说明 |
|------|--------|--------|---------|------|
| `choose_target_requested` | `choose_target_requested(n: int)` | `choose_target_requested(n: int, skill: Variant)` | `src/ui/gui_player_input.gd` | 携带 skill 以便 UI 按 `target_type`/`filter_target` 构建候选并过滤；`i_player_input.gd`、`cli_player_input.gd`、`game_scene_2d.gd` 同步适配 |
