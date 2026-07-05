# 数据层 (data/)

本目录记录项目 `data/` 下已实现的数据 Resource 与数据访问器。

数据层遵循「数据 Resource + 数据访问器」双文件模式：
- `<thing>_data.gd`：`class_name <Thing>Data extends Resource`，仅 `@export` 字段，无方法。
- `<things>.gd`：`class_name <Things>`，含 `static var _ALL`、`static func _ensure_all()`、`static func get_all()`/`get_by_id(...)`、`static func _make(...)`。

---

## MissionData

- **文件**: `data/mission_data.gd`
- **类声明**: `class_name MissionData extends Resource`
- **职责**: 任务静态数据。

### @export 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `int` | 任务唯一标识，从 0 开始（0 为教程）。 |
| `name` | `String` | 任务名称。 |
| `difficulty` | `String` | 难度名称。取值："特别简单"/"非常简单"/"简单"/"正常"/"困难"/"非常困难"。 |
| `difficulty_order` | `int` | 难度排序值，由 difficulty 映射而来。见 `Missions.DIFFICULTY_ORDER`。 |
| `fuel` | `String` | 通关所需燃料数。空字符串表示未指定。 |
| `monster_pack` | `String` | 怪物包标识。取值："zombie"/"mutant"/"alien"/"robot"。 |
| `intro` | `String` | 任务背景介绍文本。 |
| `objective` | `String` | 任务目标文本。 |
| `special_setup` | `String` | 特殊设置说明文本。 |
| `map_blocks` | `Dictionary` | 地图块组成。键为地块名，值为该地块数量。 |
| `icon_path` | `String` | 图标资源路径。 |

---

## Missions

- **文件**: `data/missions.gd`
- **类声明**: `class_name Missions`
- **职责**: 任务数据访问器，懒加载 + 查询。

### 常量

| 常量 | 类型 | 说明 |
|------|------|------|
| `DIFFICULTY_ORDER` | `Dictionary` | 难度名称到排序值的映射。{"特别简单":0, "非常简单":1, "简单":2, "正常":3, "困难":4, "非常困难":5}。 |

### 静态变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_ALL` | `Array[MissionData]` | 懒加载的任务列表。 |

### 静态方法

| 方法签名 | 说明 |
|----------|------|
| `_ensure_all() -> void` | 确保 `_ALL` 已加载。 |
| `get_all() -> Array[MissionData]` | 获取所有任务，首次调用时懒加载。 |
| `get_by_id(id: int) -> MissionData` | 按 id 查询任务；未找到返回 `null`。 |
| `get_random() -> MissionData` | 随机返回一个任务。 |
| `_make(id: int, name: String, difficulty: String, fuel: String, monster_pack: String, intro: String, objective: String, special_setup: String, map_blocks: Dictionary) -> MissionData` | 私有构造。 |

### 已录入条目

| id | name | difficulty | fuel | monster_pack |
|----|------|-----------|------|-------------|
| 0 | 教程 | 特别简单 | 4 | zombie |
| 1 | 1. 解救科学家 | 简单 | 4 | zombie |
| 2 | 2. 收集样本 | 非常简单 | 4 | zombie |
| 3 | 3. 研制解药 | 简单 | (空) | zombie |
| 4 | 4. 核冬天 | 正常 | (空) | mutant |
| 5 | 5. 拆除炸弹 | 正常 | 3 | mutant |
| 6 | 6. 核辐射 | 正常 | 3 | mutant |
| 7 | 7. 侦查外星人地区 | 困难 | 4 | alien |
| 8 | 8. 情报恢复 | 困难 | (空) | alien |
| 9 | 9. 人类反击 | 非常困难 | (空) | alien |
| 10 | 10. 运输 | 困难 | 6 | robot |
| 11 | 11. 保护基地 | 困难 | (空) | robot |
| 12 | 12. 烧死那群机器人 | 非常困难 | 3 | robot |

---

## SurvivorData

- **文件**: `data/survivor_data.gd`
- **类声明**: `class_name SurvivorData extends Resource`
- **职责**: 求生者静态数据。

### @export 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 求生者唯一标识（英文 snake_case）。 |
| `display_name` | `String` | 求生者显示名称（中文）。 |
| `hp` | `int` | 生命值上限。 |
| `stealth` | `int` | 潜行值，用于怪物生成检定。 |
| `hunger_stealth` | `int` | 饥饿检定时的潜行值。 |
| `skill_name` | `String` | 技能名称。 |
| `skill_desc` | `String` | 技能描述文本。 |
| `is_special` | `bool` | 是否为特殊角色（如"老兵与狗"二位一体）。 |
| `special_note` | `String` | 特殊角色的额外规则说明；非特殊角色为空字符串。 |
| `icon_path` | `String` | 图标资源路径。 |

---

## Survivors

- **文件**: `data/survivors.gd`
- **类声明**: `class_name Survivors`
- **职责**: 求生者数据访问器，懒加载 + 查询。

### 静态变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_ALL` | `Array[SurvivorData]` | 懒加载的求生者列表。 |

### 静态方法

| 方法签名 | 说明 |
|----------|------|
| `_ensure_all() -> void` | 确保 `_ALL` 已加载。 |
| `get_all() -> Array[SurvivorData]` | 获取所有求生者，首次调用时懒加载。 |
| `get_by_id(id: String) -> SurvivorData` | 按 id 查询求生者；未找到返回 `null`。 |
| `_make(id: String, display_name: String, hp: int, stealth: int, hunger_stealth: int, skill_name: String, skill_desc: String, is_special: bool, special_note: String) -> SurvivorData` | 私有构造。 |

### 已录入条目

| id | display_name | hp | stealth | hunger_stealth | skill_name | is_special |
|----|-------------|-----|---------|---------------|------------|------------|
| firefighter | 消防员 | 32 | 6 | 5 | 拳打 | false |
| gunslinger | 枪手 | 28 | 7 | 6 | 快速拔枪 | false |
| hunter | 猎人 | 24 | 9 | 8 | 侦察 | false |
| mechanic | 机械师 | 26 | 8 | 7 | 维修 | false |
| surgeon | 外科医生 | 23 | 8 | 7 | 缝合 | false |
| veteran | 老兵与狗 | 22 | 7 | 6 | 把你的爪子拿开 | true |

---

## VariantData

- **文件**: `data/variant_data.gd`
- **类声明**: `class_name VariantData extends Resource`
- **职责**: 变体静态数据。

### @export 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 变体唯一标识。 |
| `display_name` | `String` | 变体显示名称（中文）。 |
| `desc` | `String` | 变体效果说明。 |

---

## Variants

- **文件**: `data/variants.gd`
- **类声明**: `class_name Variants`
- **职责**: 变体数据访问器，懒加载 + 查询。

### 静态变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `_ALL` | `Array[VariantData]` | 懒加载的变体列表。 |

### 静态方法

| 方法签名 | 说明 |
|----------|------|
| `_ensure_all() -> void` | 确保 `_ALL` 已加载。 |
| `get_all() -> Array[VariantData]` | 获取所有变体，首次调用时懒加载。 |
| `get_by_id(id: String) -> VariantData` | 按 id 查询变体；未找到返回 `null`。 |
| `_make(id: String, display_name: String, desc: String) -> VariantData` | 私有构造。 |

### 已录入条目

| id | display_name | desc |
|----|-------------|------|
| crisis | 危机四伏 | 往初始拾荒牌堆中添加更多的"伏击"。 |
| famine | 大饥荒 | 玩家随机投掷骰子来决定初始饥饿等级。 |
| shared_fate | 同生共死 | 当任何玩家被消灭时，所有求生者输掉游戏。 |
