# 轮次 02:Player 实体骨架

> 状态: `[ ] 未开始`
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md) | 规则来源:[GameSystem/PlayerState.md](../GameDesignDocus/GameSystem/PlayerState.md) | [待定义方法](../GameDesignDocus/待定义方法.md) §1.5/1.7

---

## 1. 范围

本轮实现 Player 实体骨架与基础状态查询/变更方法,为 03 轮 DamageFlow 与 04 轮 PlayerState 提供承载实体。包含 2 个新类与若干基础方法:

1. **RoleCard 类**:角色卡牌(正面/翻面)
2. **Player 类**:`extends Entity`,承载 HP/饥饿/潜行/标记/角色卡牌
3. **基础状态查询方法**:`生命值()`/`最大生命值()`/`饥饿值()`/`潜行值()`/`所在地图块()`
4. **基础数值变更方法**:`增加生命值(n)`/`减少生命值(n)`/`增加饥饿值(n)`/`减少饥饿值(n)`/`增加潜行值(n)`/`减少潜行值(n)`
5. **标记系统**:`addMarkSkill`/`removeMarkSkill`/`countMark`/`hasMarkSkill`

**本轮实现的方法**(待定义方法,本轮首次定义+实现,见 [待定义方法.md](../GameDesignDocus/待定义方法.md) §1.5/1.7):
- `player.生命值()` / `player.最大生命值()` / `player.饥饿值()` / `player.潜行值()` / `player.所在地图块()`
- `player.增加生命值(n)` / `player.增加饥饿值(n)` / `player.减少饥饿值(n)` / `player.增加潜行值(n)` / `player.减少潜行值(n)`
- `player.addMarkSkill(markName, quantity)` / `player.removeMarkSkill(markName)` / `player.countMark(markName)` / `player.hasMarkSkill(markName)`
- `player.角色卡牌.is正面()` / `player.角色卡牌.翻面()` (RoleCard 类方法)

**本轮不实现**:
- `recover`/`increaseHunger`/`decreaseHunger`/`poison`(04 轮,依赖 DamageFlow)
- `damage`(03 轮)
- `player.减少生命值(n)`(设计文档未明确出现,但 damage 流程需要;03 轮实现 damage 时一并定义)
- `player.增加行动次数` 等其他待定义方法
- 标记系统的 `Until` 参数(本轮简化,只支持永久标记,见 §4.3)
- `addMark`(§9.10 待澄清,本轮不实现)
- `player.所在地图块()` 的真实实现(本轮 stub 返回 null)

---

## 2. 前置依赖

- **代码**: 01 轮 EventTrigger(Entity 基类、Skill、Event)
- **文档**: 已读 `GameSystem/PlayerState.md`、`待定义方法.md` §1.5/1.7、§9.6/9.7/9.10

---

## 3. 设计要点(从 GameSystem/PlayerState.md 与待定义方法.md 提炼)

PlayerState.md 内部调用了以下 Player 接口(本轮需提供):
- `player.最大生命值()` / `player.生命值()` / `player.增加生命值(num)` —— recover 用
- `player.饥饿值()` / `player.增加饥饿值(1)` / `player.减少饥饿值(num)` —— increaseHunger/decreaseHunger 用
- `player.角色卡牌.is正面()` / `player.角色卡牌.翻面()` —— 翻面用
- `player.addMarkSkill("饥饿伤害等级", 1)` / `player.countMark("饥饿伤害等级")` / `player.removeMarkSkill("饥饿伤害等级")` —— 饥饿伤害标记用
- `player.countMark("poison")` —— poison 用
- `player.damage(num, NULL, "饥饿伤害")` —— 04 轮(03 轮实现 damage)

Judge.md 内部调用了:
- `player.潜行值()` —— sneakJudge 用
- `player.所在地图块()` —— sneakJudge/monsterSpawnJudge 用
- `player.随机投掷两颗大骰子()` —— judge 用(05 轮)

---

## 4. 设计决策(需确认)

### 4.1 RoleCard 类(提议)
新建 `scripts/system/role_card.gd`:
```gdscript
class_name RoleCard extends RefCounted

## 角色卡当前是否正面。
var _is_front: bool = true

## 是否正面朝上。
func is正面() -> bool:
    return _is_front

## 翻面(正↔反)。
func 翻面() -> void:
    _is_front = not _is_front
```
- 用 `RefCounted`,轻量,不需挂节点树
- 方法名保留中文(设计文档用 `player.角色卡牌.is正面()` / `player.角色卡牌.翻面()`,AGENTS.md §3.6 允许)
- 本轮仅实现正反面状态,不实现角色卡上的技能(技能通过 Player 的 `_skills` 管理)

### 4.2 Player 类(提议)
新建 `scripts/system/player.gd`:
```gdscript
class_name Player extends Entity

## 玩家名字(玩家可见文本)。
var 名字: String = ""

var _max_hp: int = 6
var _hp: int = 6
var _hunger: int = 1
var _sneak_value: int = 0
var _role_card: RoleCard = RoleCard.new()
var _marks: Dictionary = {}  # mark_name -> quantity (int)
var _current_block: Variant = null  # 02 轮 stub,05 轮接 MapBlock

# ——— 状态查询 ———

## 当前生命值。
func 生命值() -> int:
    return _hp

## 最大生命值上限。
func 最大生命值() -> int:
    return _max_hp

## 当前饥饿值(1~6,6 后翻面)。
func 饥饿值() -> int:
    return _hunger

## 当前潜行值(基础值,不含地块怪物减成;sneakJudge 自行减成)。
func 潜行值() -> int:
    return _sneak_value

## 当前所在地图块。02 轮 stub,返回 null。
func 所在地图块() -> Variant:
    return _current_block

## 角色卡牌对象。
func 角色卡牌() -> RoleCard:
    return _role_card

# ——— 数值变更(不触发钩子) ———

## 直接增加 n 点生命值,不触发"回复生命时"钩子,不受最大值约束。
## 与 recover 的区别见 §9.6。
func 增加生命值(n: int) -> void:
    if n <= 0:
        return
    _hp += n

## 直接增加 n 点饥饿值,不走 increaseHunger 流程(不翻面、不加饥饿伤害标记)。
## 与 increaseHunger 的区别见 §9.7。
func 增加饥饿值(n: int) -> void:
    if n <= 0:
        return
    _hunger += n

## 直接减少 n 点饥饿值,不走 decreaseHunger 流程(不清饥饿伤害标记、不翻回)。
## 最低降至 1。与 decreaseHunger 的区别见 §9.7。
func 减少饥饿值(n: int) -> void:
    if n <= 0:
        return
    _hunger = max(1, _hunger - n)

## 增加潜行值。
func 增加潜行值(n: int) -> void:
    if n <= 0:
        return
    _sneak_value += n

## 减少潜行值。
func 减少潜行值(n: int) -> void:
    if n <= 0:
        return
    _sneak_value -= n

# ——— 标记系统 ———

## 添加 quantity 层标记。quantity 默认 1。
## 本轮不支持 Until 参数(永久标记),后续轮次扩展。
func addMarkSkill(mark_name: String, quantity: int = 1) -> void:
    if quantity <= 0:
        return
    _marks[mark_name] = int(_marks.get(mark_name, 0)) + quantity

## 移除标记(清零)。
func removeMarkSkill(mark_name: String) -> void:
    _marks.erase(mark_name)

## 获取标记层数。无此标记返回 0。
func countMark(mark_name: String) -> int:
    return int(_marks.get(mark_name, 0))

## 是否有指定标记(层数 > 0)。
func hasMarkSkill(mark_name: String) -> bool:
    return countMark(mark_name) > 0
```

### 4.3 标记系统简化说明

设计文档中 `addMarkSkill` 签名为 `(markName, quantity=, Until=)`,`Until` 控制标记何时清除(如 "回合结束")。本轮:
- **不实现 `Until`**:标记只能通过 `removeMarkSkill` 主动移除
- **原因**:`Until` 涉及回合流程钩子(本路线图未实现),本轮无法验证其行为
- **后续**:06+ 轮实现回合流程时,补 `Until` 参数与回合结束清理逻辑
- **登记**:在 `待定义方法.md` 中注明本轮 `addMarkSkill` 为简化版

### 4.4 §9.6/§9.7/§9.10 处理

| 歧义 | 本轮处理 | 理由 |
|------|---------|------|
| §9.6 `增加生命值` vs `recover` | 本轮 `增加生命值` 不触发钩子、不受上限约束(直接 `_hp += n`);`recover` 04 轮实现(走上限+钩子) | 与 §9.6 建议一致 |
| §9.7 `增加饥饿值` vs `increaseHunger` | 本轮 `增加饥饿值`/`减少饥饿值` 仅数值变更,不翻面/不加标记;`increaseHunger`/`decreaseHunger` 04 轮实现 | 与 §9.7 建议一致 |
| §9.10 `addMark` vs `addMarkSkill` | 本轮不实现 `addMark`,只用 `addMarkSkill`;§9.10 留待后续轮次统一 | 本轮无调用方需要 `addMark` |

**这些处理需用户确认。若同意,在 §9.6/9.7/9.10 条目中标注"按此方案实现"。**

### 4.5 目录结构(本轮后)
```
scripts/
├── system/
│   ├── entity.gd          # 01 轮
│   ├── event.gd           # 01 轮
│   ├── skill.gd           # 01 轮
│   ├── role_card.gd       # 02 轮新增
│   └── player.gd          # 02 轮新增
├── autoload/              # 已有
└── ui/                    # 已有
```

---

## 5. 实施任务清单

1. [ ] 与用户确认 §4.4 的 §9.6/9.7/9.10 处理方案
2. [ ] 新建 `scripts/system/role_card.gd`(§4.1)
3. [ ] 新建 `scripts/system/player.gd`(§4.2)
4. [ ] 在 `待定义方法.md` 中为本轮实现的方法补充定义(若需明确签名)
5. [ ] 新建 `tests/unit/test_player.gd`(§6 验收用例)
6. [ ] 运行 GUT 测试,全部通过
7. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI

---

## 6. 验收标准(测试用例)

测试文件:`tests/unit/test_player.gd`,继承 `GutTest`。

### 6.1 状态查询
- `test_new_player_has_default_hp`: 新建 Player,`生命值()` == 6,`最大生命值()` == 6
- `test_new_player_has_default_hunger`: `饥饿值()` == 1
- `test_new_player_has_default_sneak`: `潜行值()` == 0
- `test_new_player_role_card_front`: `角色卡牌().is正面()` == true
- `test_所在地图块_returns_null_stub`: `所在地图块()` == null

### 6.2 增加生命值(§9.6 处理)
- `test_增加生命值_increases_hp`: HP=3, `增加生命值(2)` → HP=5
- `test_增加生命值_exceeds_max_not_clamped`: HP=5, max=6, `增加生命值(5)` → HP=10(不受上限约束,与 recover 区别)
- `test_增加生命值_zero_or_negative_noop`: `增加生命值(0)` / `增加生命值(-1)` → HP 不变

### 6.3 增加饥饿值(§9.7 处理)
- `test_增加饥饿值_increases_hunger`: hunger=2, `增加饥饿值(3)` → hunger=5
- `test_增加饥饿值_does_not_flip_at_6`: hunger=6, `增加饥饿值(1)` → hunger=7(不翻面,与 increaseHunger 区别)
- `test_增加饥饿值_zero_or_negative_noop`

### 6.4 减少饥饿值(§9.7 处理)
- `test_减少饥饿值_decreases_hunger`: hunger=4, `减少饥饿值(2)` → hunger=2
- `test_减少饥饿值_floor_at_1`: hunger=2, `减少饥饿值(5)` → hunger=1(最低 1)
- `test_减少饥饿值_does_not_clear_marks`: 有饥饿伤害标记时,`减少饥饿值` 不清除标记(与 decreaseHunger 区别)

### 6.5 潜行值
- `test_增加潜行值` / `test_减少潜行值` / `test_减少潜行值_can_go_negative`(潜行值可为负)

### 6.6 角色卡牌
- `test_角色卡牌_翻面_toggles`: 初始正面,`翻面()` → 反面,再 `翻面()` → 正面

### 6.7 标记系统
- `test_addMarkSkill_adds_quantity`: `addMarkSkill("poison", 2)` → `countMark("poison")` == 2
- `test_addMarkSkill_default_quantity_1`: `addMarkSkill("poison")` → countMark == 1
- `test_addMarkSkill_accumulates`: `addMarkSkill("poison", 1)` + `addMarkSkill("poison", 2)` → countMark == 3
- `test_removeMarkSkill_clears`: 添加后 `removeMarkSkill("poison")` → countMark == 0, hasMarkSkill == false
- `test_countMark_nonexistent_returns_0`: `countMark("不存在的标记")` == 0
- `test_hasMarkSkill`: 添加后 true,移除后 false
- `test_addMarkSkill_zero_or_negative_noop`: `addMarkSkill("poison", 0)` → countMark == 0

### 6.8 与 Entity 集成
- `test_player_inherits_entity_skills`: Player `extends Entity`,`add_skill`/`get_all_skills`/`trigger` 可用
- `test_player_trigger_invokes_skills`: Player 挂技能后,`trigger("受到伤害时", event)` 正确触发(复用 01 轮机制)

---

## 7. 风险与待澄清

| 项 | 说明 | 处理 |
|----|------|------|
| §9.6/9.7/9.10 歧义 | 本轮处理方案需用户确认 | §4.4 提议方案,动笔前确认 |
| `增加生命值` 不受上限约束 | 与 recover 行为不同,可能违反直觉 | 在 `##` 文档注释中明确指出,Complex Logic 加 `# 规则引用: 待定义方法.md §9.6` |
| 标记系统不支持 Until | 本轮无法验证回合结束清理 | 后续 06+ 轮补;本轮在 `addMarkSkill` 文档注释中标注"本轮不支持 Until" |
| `所在地图块` 返回 null | 05 轮 sneakJudge 需要真实地图块 | 05 轮实现 MapBlock stub 时补;本轮 sneakJudge 不实现 |
| `减少生命值` 未实现 | damage 流程(03 轮)需要直接扣血 | 03 轮实现 damage 时,在 Player 上补 `减少生命值(n)` 方法 |
| Player 不挂节点树 | 用 RefCounted,无 `_ready` | 单元测试用 `Player.new()`;后续 GameScene 集成时可能需要 Node 包装 |

---

## 8. 不做的事

- 不实现 `recover`/`increaseHunger`/`decreaseHunger`/`poison`(04 轮)
- 不实现 `damage`(03 轮)
- 不实现 `所在地图块` 真实逻辑(05 轮 MapBlock stub)
- 不实现 `addMark`(§9.10)
- 不实现标记的 `Until` 参数
- 不实现 `player.减少生命值`(03 轮 damage 用)
- 不修改 `data/` 下任何文件
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不实现具体求生者技能(各 SurvivorPack 实现时)
