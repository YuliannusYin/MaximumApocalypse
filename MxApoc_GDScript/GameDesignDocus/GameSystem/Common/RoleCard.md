# RoleCard 角色卡类

> 职责：玩家角色卡，表示角色的正反面状态。
> RoleCard 类**不继承** Entity（无技能、无 trigger），是状态标记。
> 饥饿值达 6 后翻面，减少饥饿值后恢复正面。

---

## 设计职责

角色卡用于追踪玩家的饥饿状态：

- **正面**：正常状态，饥饿值 1-5
- **反面**：饥饿状态，饥饿值达到 6 后翻面，叠加饥饿伤害标记

翻面后，玩家的潜行值可能变化（多数角色饥饿状态潜行值降低，见各角色定义如 [hunter.md](../../Resource/SurvivorPacks/hunter.md)）。

---

## 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 正反面状态 | Bool | true = 正面（is_front），false = 反面 |
| 角色名称 | String | 角色名（如"猎人"、"消防员"） |
| 生命值上限 | Int | 角色设定的最大生命值 |
| 初始生命值 | Int | 角色设定的初始生命值 |
| 潜行值 | Int | 正面潜行值 |
| 饥饿状态潜行值 | Int | 反面（饥饿状态）潜行值 |
| 装备栏容量 | Int | 角色设定的装备栏格数上限。装备牌占用格数由 `card.大小` 决定 |
| 角色固有技能 | List\<Skill\> | 角色开局即拥有的固有技能（非卡牌） |

---

## 方法

### flip()

> 翻面角色卡（正面 ↔ 反面）。
> 触发场景：
> - 饥饿值达到 6 时翻面（见 [Player.increaseHunger](../Entities/Player.md#increasehunger)）
> - 减少饥饿值后恢复正面（见 [Player.decreaseHunger](../Entities/Player.md#decreasehunger)）

```gdscript
function roleCard.flip() {
    roleCard.正反面状态 = !roleCard.正反面状态
    # 翻面后玩家的潜行值可能变化（由 Player.get_sneak() 根据正反面返回对应潜行值）
}
```

---

### is_front()

> 判断角色卡是否正面朝上。

```gdscript
function roleCard.is_front() {
    return roleCard.正反面状态
}
```

---

## 与饥饿流程的关系

> 详见 [Player.increaseHunger](../Entities/Player.md#increasehunger) / [Player.decreaseHunger](../Entities/Player.md#decreasehunger)。

### 饥饿值达到 6

1. 角色卡翻面（若当前为正面）
2. 添加「饥饿伤害等级」标记
3. 按等级造成无来源伤害：等级 1-4 分别造成 2/4/6/8 点伤害，等级 5 致死

### 减少饥饿值

1. 饥饿值最低降至 1
2. 清除「饥饿伤害等级」标记
3. 角色卡恢复正面（若当前为反面）

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Player](../Entities/Player.md) | Player 持有 RoleCard；饥饿流程操作角色卡翻面 |
| [Skill](Skill.md) | 角色固有技能遵循 Skill 结构 |
