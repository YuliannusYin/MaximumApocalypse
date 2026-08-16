# RoleCard 角色卡类

> 职责：玩家角色卡，表示角色的正反面状态。
> 类名 `RoleCard`，继承 `RefCounted`。
> RoleCard **不继承** Entity（无技能、无 trigger），是状态标记。
> 饥饿值达 6 后翻面，减少饥饿值后恢复正面。

> 对齐代码：`MxApoc_GDScript/src/common/role_card.gd`

---

## 一、设计职责

角色卡用于追踪玩家的饥饿状态：

- **正面**：正常状态，饥饿值 1-5
- **反面**：饥饿状态，饥饿值达到 6 后翻面，叠加饥饿伤害标记

翻面后，玩家的潜行值可能变化（多数角色饥饿状态潜行值降低，见各角色定义如 [hunter.md](../../Resource/SurvivorPacks/hunter.md)）。`get_sneak()` 方法直接由 RoleCard 自身根据正反面返回对应潜行值。

---

## 二、字段

| 字段名 | 类型 | 默认值 | 说明 |
|------|------|------|------|
| `is_front_side` | bool | `true` | 正反面状态。`true` = 正面，`false` = 反面（饥饿状态） |
| `role_name` | String | `""` | 角色名称（如"猎人"、"消防员"） |
| `english_name` | String | `""` | 英文标识符（如 `"firefighter"`），用于图片资源路径查找 |
| `max_hp` | int | `0` | 生命值上限 |
| `initial_hp` | int | `0` | 初始生命值 |
| `sneak` | int | `0` | 正面潜行值 |
| `hunger_sneak` | int | `0` | 反面（饥饿状态）潜行值 |
| `equipment_capacity` | int | `5` | 装备栏格数上限。装备牌占用格数由卡牌尺寸字段决定 |
| `hand_size_limit` | int | `10` | 手牌上限 |
| `intrinsic_skills` | Array[Skill] | `[]` | 角色固有技能（开局即拥有，非卡牌） |

---

## 三、方法

### 1. flip()

翻面角色卡（正面 ↔ 反面）。

| 签名 | 返回 |
|------|------|
| `flip() -> void` | 无 |

- 切换 `is_front_side` 字段为相反值
- 触发场景：
  - 饥饿值达到 6 时翻面（见 [Player.md increase_hunger](../Entities/Player.md)）
  - 减少饥饿值后恢复正面（见 [Player.md decrease_hunger](../Entities/Player.md)）

---

### 2. is_front()

判断角色卡是否正面朝上。

| 签名 | 返回 |
|------|------|
| `is_front() -> bool` | `true` 表示当前正面朝上 |

- 直接返回 `is_front_side` 字段值

---

### 3. get_sneak()

获取当前潜行值（根据正反面返回对应值）。

| 签名 | 返回 |
|------|------|
| `get_sneak() -> int` | 当前潜行值 |

- **由 RoleCard 自身实现**，非 Player 委托
- 正面时返回 `sneak`；反面时返回 `hunger_sneak`

---

## 四、与饥饿流程的关系

> 详见 [Player.md increase_hunger / decrease_hunger](../Entities/Player.md)。

### 饥饿值达到 6

1. 角色卡翻面（若当前为正面）
2. 添加「饥饿伤害等级」标记
3. 按等级造成无来源伤害：等级 1-4 分别造成 2/4/6/8 点伤害，等级 5 致死

### 减少饥饿值

1. 饥饿值最低降至 1
2. 清除「饥饿伤害等级」标记
3. 角色卡恢复正面（若当前为反面）

---

## 五、与其他类的关系

| 关系 | 说明 |
|------|------|
| [Player](../Entities/Player.md) | Player 持有 RoleCard；饥饿流程操作角色卡翻面；潜行值查询委托给 `RoleCard.get_sneak()` |
| [Skill](Skill.md) | 角色固有技能遵循 Skill 结构 |
