# 轮次 02:Player 实体骨架

> 状态: `[x] 已完成`
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md) | 规则来源:[GameSystem/PlayerState.md](../GameDesignDocus/GameSystem/PlayerState.md) | [待定义方法](../GameDesignDocus/待定义方法.md) §1.5/1.7

---

## 1. 范围

本轮实现 Player 实体骨架与基础状态查询/变更方法,为 03 轮 DamageFlow 与 04 轮 PlayerState 提供承载实体。包含 2 个新类与若干基础方法:

1. **RoleCard 类**:角色卡牌(正面/翻面)
2. **Player 类**:`extends Entity`,承载 HP/饥饿/潜行/标记/角色卡牌
3. **基础状态查询方法**:`get_hp()`/`get_max_hp()`/`get_hunger()`/`get_sneak()`/`get_current_block()`
4. **基础数值变更方法**:`add_hp(n)`/`reduce_hp(n)`/`add_hunger(n)`/`reduce_hunger(n)`/`add_sneak(n)`/`reduce_sneak(n)`
5. **标记系统**:`addMarkSkill`/`removeMarkSkill`/`countMark`/`hasMarkSkill`

**本轮实现的方法**(待定义方法,本轮首次定义+实现,见 [待定义方法.md](../GameDesignDocus/待定义方法.md) §1.5/1.7):
- `player.get_hp()` / `player.get_max_hp()` / `player.get_hunger()` / `player.get_sneak()` / `player.get_current_block()`
- `player.add_hp(n)` / `player.add_hunger(n)` / `player.reduce_hunger(n)` / `player.add_sneak(n)` / `player.reduce_sneak(n)`
- `player.addMarkSkill(markName, quantity)` / `player.removeMarkSkill(markName)` / `player.countMark(markName)` / `player.hasMarkSkill(markName)`
- `player.get_role_card().is_front()` / `player.get_role_card().flip()` (RoleCard 类方法)

**本轮不实现**:
- `recover`/`increaseHunger`/`decreaseHunger`/`poison`(04 轮,依赖 DamageFlow)
- `damage`(03 轮)
- `player.reduce_hp(n)`(设计文档未明确出现,但 damage 流程需要;03 轮实现 damage 时一并定义)
- `player.add_action_count` 等其他待定义方法
- 标记系统的 `Until` 参数(本轮简化,只支持永久标记,见 §4.3)
- `addMark`(§9.10 待澄清,本轮不实现)
- `player.get_current_block()` 的真实实现(本轮 stub 返回 null)

---

## 2. 前置依赖

- **代码**: 01 轮 EventTrigger(Entity 基类、Skill、Event)
- **文档**: 已读 `GameSystem/PlayerState.md`、`待定义方法.md` §1.5/1.7、§9.6/9.7/9.10

---

## 3. 设计要点(从 GameSystem/PlayerState.md 与待定义方法.md 提炼)

PlayerState.md 内部调用了以下 Player 接口(本轮需提供):
- `player.get_max_hp()` / `player.get_hp()` / `player.add_hp(num)` —— recover 用
- `player.get_hunger()` / `player.add_hunger(1)` / `player.reduce_hunger(num)` —— increaseHunger/decreaseHunger 用
- `player.get_role_card().is_front()` / `player.get_role_card().flip()` —— 翻面用
- `player.addMarkSkill("饥饿伤害等级", 1)` / `player.countMark("饥饿伤害等级")` / `player.removeMarkSkill("饥饿伤害等级")` —— 饥饿伤害标记用
- `player.countMark("poison")` —— poison 用
- `player.damage(num, NULL, "饥饿伤害")` —— 04 轮(03 轮实现 damage)

Judge.md 内部调用了:
- `player.get_sneak()` —— sneakJudge 用
- `player.get_current_block()` —— sneakJudge/monsterSpawnJudge 用
- `player.roll_two_dice()` —— judge 用(05 轮)

---

## 4. 设计决策(需确认)

### 4.1 RoleCard 类(提议)
新建 `scripts/system/role_card.gd`:
```gdscript
class_name RoleCard extends RefCounted

var _is_front: bool = true

## 角色卡当前是否正面朝上。
func is_front() -> bool:
    return _is_front

## 翻面(正↔反)。
func flip() -> void:
    _is_front = not _is_front
```
- 用 `RefCounted`,轻量,不需挂节点树
- 命名风格:`is_` 前缀的布尔查询、动词原形的动作方法(见 AGENTS.md §3.6)
- 本轮仅实现正反面状态,不实现角色卡上的技能(技能通过 Player 的 `_skills` 管理)

### 4.2 Player 类(提议)
新建 `scripts/system/player.gd`:
```gdscript
class_name Player extends Entity

## 玩家名字(玩家可见文本)。
var name: String = ""

var _max_hp: int = 6
var _hp: int = 6
var _hunger: int = 1
var _sneak_value: int = 0
var _role_card: RoleCard = RoleCard.new()
var _marks: Dictionary = {}  # mark_name -> quantity (int)
var _current_block: Variant = null  # 02 轮 stub,05 轮接 MapBlock

# ——— 状态查询 ———

## 当前生命值。
func get_hp() -> int:
    return _hp

## 最大生命值上限。
func get_max_hp() -> int:
    return _max_hp

## 当前饥饿值(1~6,6 后翻面)。
func get_hunger() -> int:
    return _hunger

## 当前潜行值(基础值,不含地块怪物减成;sneakJudge 自行减成)。
func get_sneak() -> int:
    return _sneak_value

## 当前所在地图块。02 轮 stub,返回 null。
func get_current_block() -> Variant:
    return _current_block

## 角色卡牌对象。
func get_role_card() -> RoleCard:
    return _role_card

# ——— 数值变更(不触发钩子) ———

## 直接增加 n 点生命值,不触发"回复生命时"钩子,不受最大值约束。
## 与 recover 的区别见 §9.6。
func add_hp(n: int) -> void:
    if n <= 0:
        return
    _hp += n

## 直接增加 n 点饥饿值,不走 increaseHunger 流程(不翻面、不加饥饿伤害标记)。
## 与 increaseHunger 的区别见 §9.7。
func add_hunger(n: int) -> void:
    if n <= 0:
        return
    _hunger += n

## 直接减少 n 点饥饿值,不走 decreaseHunger 流程(不清饥饿伤害标记、不翻回)。
## 最低降至 1。与 decreaseHunger 的区别见 §9.7。
func reduce_hunger(n: int) -> void:
    if n <= 0:
        return
    _hunger = max(1, _hunger - n)

## 增加潜行值。
func add_sneak(n: int) -> void:
    if n <= 0:
        return
    _sneak_value += n

## 减少潜行值。
func reduce_sneak(n: int) -> void:
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
| §9.6 `add_hp` vs `recover` | 本轮 `add_hp` 不触发钩子、不受上限约束(直接 `_hp += n`);`recover` 04 轮实现(走上限+钩子) | 与 §9.6 建议一致 |
| §9.7 `add_hunger` vs `increaseHunger` | 本轮 `add_hunger`/`reduce_hunger` 仅数值变更,不翻面/不加标记;`increaseHunger`/`decreaseHunger` 04 轮实现 | 与 §9.7 建议一致 |
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

1. [x] 与用户确认 §4.4 的 §9.6/9.7/9.10 处理方案(spec/README.md 已标记 ✅ 已确认)
2. [x] 新建 `scripts/system/role_card.gd`(§4.1)
3. [x] 新建 `scripts/system/player.gd`(§4.2)
4. [x] 在 `待定义方法.md` 中标记 §9.7 / §9.10 为 ✅ 已解决
5. [x] 新建 `tests/unit/test_player.gd`(§6 验收用例)
6. [x] 运行 GUT 测试,全部通过(28/28,加上 01 轮共 38/38)
7. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI(待用户在编辑器中手动验证)

---

## 6. 验收标准(测试用例)

测试文件:`tests/unit/test_player.gd`,继承 `GutTest`。

### 6.1 状态查询
- `test_new_player_has_default_hp`: 新建 Player,`get_hp()` == 6,`get_max_hp()` == 6
- `test_new_player_has_default_hunger`: `get_hunger()` == 1
- `test_new_player_has_default_sneak`: `get_sneak()` == 0
- `test_new_player_role_card_front`: `get_role_card().is_front()` == true
- `test_get_current_block_returns_null_stub`: `get_current_block()` == null

### 6.2 add_hp(§9.6 处理)
- `test_add_hp_increases_hp`: HP=3, `add_hp(2)` → HP=5
- `test_add_hp_exceeds_max_not_clamped`: HP=5, max=6, `add_hp(5)` → HP=10(不受上限约束,与 recover 区别)
- `test_add_hp_zero_or_negative_noop`: `add_hp(0)` / `add_hp(-1)` → HP 不变

### 6.3 add_hunger(§9.7 处理)
- `test_add_hunger_increases_hunger`: hunger=2, `add_hunger(3)` → hunger=5
- `test_add_hunger_does_not_flip_at_6`: hunger=6, `add_hunger(1)` → hunger=7(不翻面,与 increaseHunger 区别)
- `test_add_hunger_zero_or_negative_noop`

### 6.4 reduce_hunger(§9.7 处理)
- `test_reduce_hunger_decreases_hunger`: hunger=4, `reduce_hunger(2)` → hunger=2
- `test_reduce_hunger_floor_at_1`: hunger=2, `reduce_hunger(5)` → hunger=1(最低 1)
- `test_reduce_hunger_does_not_clear_marks`: 有饥饿伤害标记时,`reduce_hunger` 不清除标记(与 decreaseHunger 区别)

### 6.5 潜行值
- `test_add_sneak` / `test_reduce_sneak` / `test_reduce_sneak_can_go_negative`(潜行值可为负)

### 6.6 角色卡牌
- `test_role_card_flip_toggles`: 初始正面,`flip()` → 反面,再 `flip()` → 正面

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
| §9.6/9.7/9.10 歧义 | 本轮处理方案已确认 | §9.6 已解决(01 轮 recover 流程时);§9.7/§9.10 本轮已标记 ✅ 已解决 |
| `add_hp` 不受上限约束 | 与 recover 行为不同,可能违反直觉 | 在 `##` 文档注释中明确指出,Complex Logic 加 `# 规则引用: 待定义方法.md §9.6` |
| 标记系统不支持 Until | 本轮无法验证回合结束清理 | 后续 06+ 轮补;本轮在 `addMarkSkill` 文档注释中标注"本轮不支持 Until" |
| `get_current_block` 返回 null | 05 轮 sneakJudge 需要真实地图块 | 05 轮实现 MapBlock stub 时补;本轮 sneakJudge 不实现 |
| `reduce_hp` 未实现 | damage 流程(03 轮)需要直接扣血 | 03 轮实现 damage 时,在 Player 上补 `reduce_hp(n)` 方法 |
| Player 不挂节点树 | 用 RefCounted,无 `_ready` | 单元测试用 `Player.new()`;后续 GameScene 集成时可能需要 Node 包装 |
| 类名缓存需刷新 | 新增 class_name 后 GUT 首次跑会报 "Identifier not declared" | 实施时先跑 `godot --import` 刷新 `.godot/global_script_class_cache.cfg`,再跑测试 |
| 测试 set_xxx 方法 | Player 私有字段需通过 set_max_hp/set_hp/set_hunger/set_sneak 设置测试初值 | 这些 setter 仅供测试使用,生产代码不应调用(后续可考虑用 _init 参数或测试辅助类替代) |

---

## 8. 不做的事

- 不实现 `recover`/`increaseHunger`/`decreaseHunger`/`poison`(04 轮)
- 不实现 `damage`(03 轮)
- 不实现 `get_current_block` 真实逻辑(05 轮 MapBlock stub)
- 不实现 `addMark`(§9.10)
- 不实现标记的 `Until` 参数
- 不实现 `player.reduce_hp`(03 轮 damage 用)
- 不修改 `data/` 下任何文件
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不实现具体求生者技能(各 SurvivorPack 实现时)
