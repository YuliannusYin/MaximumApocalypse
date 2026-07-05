# 轮次 03:DamageFlow 伤害流程

> 状态: `[x] 已完成`
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md) | 规则来源:[GameSystem/DamageFlow.md](../GameDesignDocus/GameSystem/DamageFlow.md) | 事件流程:[J_gameEventFlow.md §1](../GameDesignDocus/GameInstructions/J_gameEventFlow.md)

---

## 1. 范围

本轮实现伤害流程,这是 PlayerState(increaseHunger/poison) 的前置依赖。包含:

1. **`target.damage(num, source, type=NULL)` 方法**:在 Entity 基类上实现 8 节点钩子链
2. **Player 补 `reduce_hp(n)` 方法**:02 轮未实现,本轮补
3. **Entity 辅助接口**:`is_player()`/`is_monster()`/`_on_death(source)` 的默认实现
4. **playerDeath/monsterDeath stub**:空实现 + 日志,登记到待定义方法.md

**本轮实现的已定义方法**:
- `target.damage(num, source, type=NULL)` —— 见 [已定义方法](../GameDesignDocus/已定义方法.md)

**本轮 stub 的已定义方法**(不实现真实逻辑,仅空函数 + 日志):
- `target.playerDeath(source)` —— 04+ 轮实现 DeathFlow 时补
- `target.monsterDeath(source)` —— 同上(Monster 实体也未实现)

**本轮不实现**:
- `playerDeath`/`monsterDeath` 真实逻辑(后续 DeathFlow 轮次)
- Monster 实体(后续轮次)
- 饥饿伤害/poison 的调用方(04 轮 PlayerState)

---

## 2. 前置依赖

- **代码**: 01 轮 EventTrigger(Entity/Event/Skill)、02 轮 Player(get_hp/get_role_card/标记)
- **文档**: 已读 `GameSystem/DamageFlow.md`、`J_gameEventFlow.md §1`

---

## 3. 设计要点(从 GameSystem/DamageFlow.md 提炼)

伪代码原文(关键部分):
```
function target.damage(num, source, type = NULL) {
    if (num <= 0) { return }              // 前置检查 1:非正伤害不处理
    if (target.get_hp() <= 0) { return }   // 前置检查 2:已死亡目标不再受伤

    event = { target, source, num, type, cancelled: false }

    if (source != NULL) {
        source.trigger("造成伤害前", event)   // 节点 1
        target.trigger("受到伤害前", event)   // 节点 2
    } else {
        target.trigger("受到伤害前", event)   // 节点 2(无来源也触发)
    }

    if (source != NULL) {
        source.trigger("造成伤害时", event)   // 节点 3(可修改 event.num)
    }

    target.trigger("受到伤害时", event)       // 节点 4(取消点,可修改 event.num 或 cancel)

    if (event.cancelled) { return }          // 取消则不扣血

    target.reduce_hp(event.num)              // 节点 5(系统扣血,非钩子)

    if (source != NULL) {
        source.trigger("造成伤害后", event)   // 节点 6
    }

    target.trigger("受到伤害后", event)       // 节点 7(始终触发,含无来源)

    if (target.get_hp() <= 0) {              // 节点 8(死亡判定)
        if (target.isPlayer()) {
            target.playerDeath(source)
        } else if (target.isMonster()) {
            target.monsterDeath(source)
        }
    }
}
```

关键点:
- **前置检查**: `num <= 0` 或 `target.get_hp() <= 0` 时直接返回,**不触发任何钩子**
- **source=NULL 分支**: 跳过节点 1/3/6(source 侧),但节点 2/4/5/7/8 正常执行
- **节点 4 取消点**: `event.cancel()` 后跳过节点 5/6/7/8(不扣血、不触发后置钩子、不判死亡)
- **event.num 可修改**: 节点 3(source 侧)和节点 4(target 侧)可修改 `event.num`,节点 5 用修改后的值扣血
- **节点 5 非钩子**: 直接扣血,不对外暴露为事件
- **节点 7 始终触发**: 含无来源伤害(source=NULL)
- **节点 8 死亡判定**: `get_hp() <= 0` 才触发;is_player/is_monster 都 false 时(如地块)不触发死亡流程

---

## 4. 设计决策(需确认)

### 4.1 damage 方法位置(提议)
在 **Entity 基类** 实现 `damage`,Player 与后续 Monster 均继承自 Entity,可直接调用。
```gdscript
# scripts/system/entity.gd 追加

## 造成 num 点伤害。source=null 时为无来源伤害(跳过 source 侧钩子)。
## 8 节点钩子链见 GameSystem/DamageFlow.md。
func damage(num: int, source: Variant = null, type: String = "") -> void:
    if num <= 0:
        return
    if get_hp() <= 0:
        return

    var event := Event.new()
    event.target = self
    event.source = source
    event.num = num
    event.type = type

    if source != null:
        source.trigger("造成伤害前", event)
        target.trigger("受到伤害前", event)
    else:
        trigger("受到伤害前", event)

    if source != null:
        source.trigger("造成伤害时", event)

    trigger("受到伤害时", event)

    if event.cancelled:
        return

    reduce_hp(event.num)

    if source != null:
        source.trigger("造成伤害后", event)

    trigger("受到伤害后", event)

    if get_hp() <= 0:
        _on_death(source)
```

### 4.2 Entity 辅助接口(提议)
在 Entity 基类追加:
```gdscript
## 当前生命值。子类必须重写。
func get_hp() -> int:
    return 0

## 直接扣血 n 点(非钩子)。子类必须重写。
func reduce_hp(n: int) -> void:
    pass

## 是否为玩家。子类重写。
func is_player() -> bool:
    return false

## 是否为怪物。子类重写。
func is_monster() -> bool:
    return false

## 死亡流程入口。子类重写为 playerDeath/monsterDeath。
## 本轮 stub:空实现 + 日志。
func _on_death(source: Variant) -> void:
    push_warning("Entity._on_death called, but no override. source=%s" % str(source))
```

### 4.3 Player 重写(提议)
在 Player 类追加:
```gdscript
## 直接扣血 n 点。可降至 0 以下(死亡判定由 damage 处理)。
func reduce_hp(n: int) -> void:
    if n <= 0:
        return
    _hp -= n

func is_player() -> bool:
    return true

## 玩家死亡流程。本轮 stub;真实逻辑见 GameSystem/DeathFlow.md(后续轮次)。
## 规则引用: GameSystem/DeathFlow.md
func playerDeath(source: Variant) -> void:
    push_warning("playerDeath stub called on %s. source=%s" % [name, str(source)])

func _on_death(source: Variant) -> void:
    playerDeath(source)
```

### 4.4 命名说明

| 方法 | 命名 | 依据 |
|------|------|------|
| `damage` | 英文原名 | 已定义方法契约(§3.2) |
| `playerDeath`/`monsterDeath` | 英文原名(camelCase) | 已定义方法契约(§3.2) |
| `get_hp`/`reduce_hp` | snake_case | 状态查询用 `get_` 前缀,原子扣血用 `reduce_` 前缀(AGENTS.md §3.6) |
| `is_player`/`is_monster` | snake_case | `is_` 前缀的布尔查询(AGENTS.md §3.6) |

设计文档伪代码用 `isPlayer()`,本轮改为 `is_player()`。**此偏差需用户确认。** 若用户要求严格保留 `isPlayer`,则改回。

### 4.5 Event 类补充(01 轮)
01 轮 Event 类已有 `source`/`target`/`num`/`type`/`cancelled`/`cancel()`,无需扩展。本轮直接使用。

### 4.6 目录结构(本轮后)
```
scripts/system/
├── entity.gd          # 追加 damage/get_hp/reduce_hp/is_player/is_monster/_on_death
├── event.gd           # 01 轮(无改动)
├── skill.gd           # 01 轮(无改动)
├── role_card.gd       # 02 轮(无改动)
└── player.gd          # 追加 reduce_hp/is_player/playerDeath/_on_death
```

---

## 5. 实施任务清单

1. [x] 与用户确认 §4.4 的 `is_player` vs `isPlayer` 命名(spec/README.md 已确认 snake_case)
2. [x] 在 `scripts/system/entity.gd` 追加 `damage`/`get_hp`/`reduce_hp`/`is_player`/`is_monster`/`_on_death`(§4.1, §4.2)
3. [x] 在 `scripts/system/player.gd` 追加 `reduce_hp`/`is_player`/`playerDeath`/`_on_death`(§4.3)
4. [x] 在 `GameDesignDocus/待定义方法.md` 中登记 `playerDeath`/`monsterDeath` 为 stub 状态(新增 §10.1)
5. [x] 新建 `tests/unit/test_damage_flow.gd`(§6 验收用例,21 用例)
6. [x] 运行 GUT 测试,全部通过(59/59 通过,含 01/02 轮回归)
7. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI(待用户手动验证)

---

## 6. 验收标准(测试用例)

测试文件:`tests/unit/test_damage_flow.gd`,继承 `GutTest`。
用 Player 作为 target/source,挂载临时 Skill(用 Callable 注入)记录钩子触发顺序。

### 6.1 前置检查
- `test_damage_zero_num_returns_immediately`: `damage(0, source)` → 无钩子触发,HP 不变
- `test_damage_negative_num_returns_immediately`: `damage(-1, source)` → 同上
- `test_damage_to_dead_target_no_effect`: target HP=0, `damage(5, source)` → 无钩子触发,HP 仍 0

### 6.2 正常伤害流程(8 节点顺序)
- `test_damage_triggers_8_nodes_in_order`: source 与 target 不同,target 挂"受到伤害前/时/后"记录技能,source 挂"造成伤害前/时/后"记录技能;`damage(3, source)` 后断言触发顺序为 `["造成伤害前","受到伤害前","造成伤害时","受到伤害时","受到伤害后"]`(节点 5 非钩子不记录,节点 6 在 7 前)
  - 完整顺序:造成伤害前 → 受到伤害前 → 造成伤害时 → 受到伤害时 → (扣血) → 造成伤害后 → 受到伤害后
- `test_damage_reduces_target_hp`: target HP=6, `damage(3, source)` → HP=3
- `test_damage_default_type_empty`: `damage(3, source)`(不传 type) → event.type == ""

### 6.3 source=NULL(无来源伤害)
- `test_damage_no_source_skips_source_hooks`: `damage(3, null)` → 只触发 target 侧"受到伤害前/时/后",source 侧不触发(因 source 为 null)
- `test_damage_no_source_reduces_hp`: `damage(3, null)` → HP 正确扣减
- `test_damage_no_source_triggers_target_hooks_only`: 触发顺序为 `["受到伤害前","受到伤害时","受到伤害后"]`

### 6.4 event.num 修改
- `test_source_on_dealing_damage_modifies_num`: source 在"造成伤害时"把 `event.num += 2`;`damage(3, source)` → HP 扣 5
- `test_target_on_taking_damage_modifies_num`: target 在"受到伤害时"把 `event.num -= 1`(减免);`damage(3, source)` → HP 扣 2
- `test_both_modify_num_additively`: source +2,target -1;`damage(3, source)` → HP 扣 4

### 6.5 event.cancel()(取消点)
- `test_cancel_at_taking_damage_prevents_hp_loss`: target 在"受到伤害时"调用 `event.cancel()`;`damage(3, source)` → HP 不变
- `test_cancel_skips_subsequent_hooks`: 取消后,"造成伤害后"/"受到伤害后"均不触发
- `test_cancel_does_not_trigger_death`: target HP=1, 取消 `damage(5, source)` → HP 仍 1,不调用 playerDeath

### 6.6 死亡判定
- `test_damage_lethal_triggers_playerDeath`: target HP=3, `damage(5, source)` → HP=-2, playerDeath 被调用(本轮 stub,用 `assert_called` 或 spy 验证)
- `test_damage_non_lethal_no_playerDeath`: target HP=6, `damage(3, source)` → HP=3, playerDeath 不调用
- `test_damage_exact_lethal_triggers_death`: target HP=3, `damage(3, source)` → HP=0, playerDeath 调用(<=0 触发)

### 6.7 钩子内 event 字段可读
- `test_taking_damage_can_read_source`: target 在"受到伤害时"读取 `event.source`,断言等于传入的 source
- `test_dealing_damage_can_read_target`: source 在"造成伤害时"读取 `event.target`,断言等于 target
- `test_taking_damage_can_read_type`: `damage(3, source, "饥饿伤害")` → target 钩子内 `event.type == "饥饿伤害"`

---

## 7. 风险与待澄清

| 项 | 说明 | 处理 |
|----|------|------|
| `is_player` vs `isPlayer` 命名 | 设计文档用 camelCase,本轮提议 snake_case | §4.4 提议,动笔前确认 |
| playerDeath/monsterDeath 为 stub | 本轮不实现真实死亡流程 | stub 为 `push_warning` + 空函数;登记到待定义方法.md |
| Monster 实体未实现 | is_monster 默认 false,无 Monster 测试 | 本轮只测 Player 作为 target;Monster 后续轮次 |
| `target.get_hp() -= event.num` 实现 | 设计文档用属性赋值,本轮用 `reduce_hp(n)` 方法 | 方法形式与 02 轮一致;`reduce_hp` 不触发钩子(节点 5 非钩子) |
| Event.source/target 类型 | 01 轮为 Variant,本轮传 Entity/Player | 保持 Variant;02 轮文档已说明 |
| damage 在 Entity 基类 | Entity 是 RefCounted,无节点树 | 单元测试用 `Player.new()`;后续 GameScene 集成时验证 |

---

## 8. 不做的事

- 不实现 `playerDeath`/`monsterDeath` 真实逻辑(后续 DeathFlow 轮次)
- 不实现 Monster 实体(后续轮次)
- 不实现 `recover`/`increaseHunger`/`decreaseHunger`/`poison`(04 轮)
- 不修改 `data/` 下任何文件
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不实现"伤害类型"的特殊处理(如 "饥饿伤害"/"poison" 仅作为 type 字符串传递,本轮不分支)
- 不解决 §9.x 歧义(本轮无相关)
