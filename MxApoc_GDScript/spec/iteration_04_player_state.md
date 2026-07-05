# 轮次 04:PlayerState 玩家状态流程

> 状态: `[ ] 未开始`
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md) | 规则来源:[GameSystem/PlayerState.md](../GameDesignDocus/GameSystem/PlayerState.md)

---

## 1. 范围

本轮实现 4 个玩家状态变更流程,它们都依赖 03 轮的 `damage` 方法。包含:

1. **`player.recover(num)`**:恢复生命值,受最大值约束
2. **`player.increaseHunger(num)`**:增加饥饿值,含翻面与饥饿伤害结算
3. **`player.decreaseHunger(num)`**:减少饥饿值,清饥饿伤害标记并翻回正面
4. **`player.poison()`**:中毒结算,无来源伤害

**本轮实现的已定义方法**:
- `player.recover(num)`
- `player.increaseHunger(num)`
- `player.decreaseHunger(num)`
- `player.poison()`

**本轮 stub**:
- `game.log(msg)` —— 用 `print` 或 `push_warning` 替代,登记到待定义方法.md

**本轮不实现**:
- "回复生命前" / "回复生命后" trigger(J_gameEventFlow.md §16 标注 [提案],本轮暂不实现,先按 [提案] 调用 trigger 名,技能可挂载但本轮无测试用例)
- game 对象其他方法
- 标记的 Until 参数(02 轮已说明,延续)

---

## 2. 前置依赖

- **代码**: 01 轮 EventTrigger、02 轮 Player(生命值/饥饿值/标记/角色卡牌/增加生命值/增加饥饿值/减少饥饿值)、03 轮 damage
- **文档**: 已读 `GameSystem/PlayerState.md`

---

## 3. 设计要点(从 GameSystem/PlayerState.md 提炼)

### 3.1 recover(num) 伪代码
```
function player.recover(num) {
    if (num <= 0) { return }
    event = { player: player, num: num, cancelled: false }
    # 1. 回复生命前 [提案]
    player.trigger("回复生命前", event)
    # 2. 回复生命时(可修改 event.num,如 surgeon 手术刀·回复、手套:event.num += 1)
    player.trigger("回复生命时", event)
    if (event.cancelled) { return }
    # 3. 系统加血,受最大值约束,非钩子节点
    max = player.最大生命值() - player.生命值()
    if (event.num > max) { event.num = max }
    player.增加生命值(event.num)
    # 4. 回复生命后 [提案]
    player.trigger("回复生命后", event)
}
```
- **触发 4 节点钩子链**(回复生命前/时/系统加血/后),见 [J_gameEventFlow.md §16](../GameDesignDocus/GameInstructions/J_gameEventFlow.md#16-回复生命值流程)
- `event.num` 可被「回复生命时」钩子修改(surgeon 手术刀·回复、手套 forced:true 加 1)
- 系统加血受最大值约束(`event.num` 被 clamp 到 `最大生命值 - 生命值`)
- 调用 `增加生命值(event.num)`(02 轮已实现,不触发钩子、不受上限约束)
- 「回复生命前」/「回复生命后」为 [提案] 名,本轮按伪代码调用 trigger,但无技能挂载测试

### 3.2 increaseHunger(num) 伪代码
```
function player.increaseHunger(num) {
    if (num <= 0) { return }
    while (num > 0) {
        if (player.饥饿值() < 6) {
            player.增加饥饿值(1)
        } else if (player.饥饿值() == 6) {
            if (player.角色卡牌.is正面()) {
                player.角色卡牌.翻面()
            }
            player.addMarkSkill("饥饿伤害等级", 1)
        }

        if (player.countMark("饥饿伤害等级") > 0) {
            level = player.countMark("饥饿伤害等级")
            if (level == 1) { player.damage(2, NULL, "饥饿伤害") }
            else if (level == 2) { player.damage(4, NULL, "饥饿伤害") }
            else if (level == 3) { player.damage(6, NULL, "饥饿伤害") }
            else if (level == 4) { player.damage(8, NULL, "饥饿伤害") }
            else if (level >= 5) {
                game.log(player.名字 + "被饿死了")
                player.damage(player.最大生命值(), NULL, "饥饿伤害")
            }
        }
        num -= 1
    }
}
```
- **逐点结算**:每次循环 +1 饥饿或翻面+标记,然后立即结算饥饿伤害
- 饥饿值 < 6:仅 +1,不结算伤害
- 饥饿值 == 6:翻面(若正面) + 加 1 层饥饿伤害标记
- 有饥饿伤害标记时:按等级造成无来源伤害(2/4/6/8/最大生命值)
- level >= 5:致命伤害(最大生命值点),玩家应死亡
- 调用 `damage(num, NULL, "饥饿伤害")`(03 轮已实现,NULL 跳过 source 侧)

### 3.3 decreaseHunger(num) 伪代码
```
function player.decreaseHunger(num) {
    if (num <= 0) { return }
    max = player.饥饿值() - 1
    if (num > max) { num = max }
    if (num <= 0) {
        game.log("饥饿值已减少到1，无法继续减少")
        return false
    }
    player.减少饥饿值(num)
    if (player.countMark("饥饿伤害等级") > 0) {
        player.removeMarkSkill("饥饿伤害等级")
    }
    if (!player.角色卡牌.is正面()) {
        player.角色卡牌.翻面()
    }
}
```
- 最低降至 1(`max = 饥饿值 - 1`,若 max <= 0 则无法减少)
- 减少后:清除饥饿伤害标记(若有) + 翻回正面(若反面)
- 调用 `减少饥饿值(num)`(02 轮已实现,不走 decreaseHunger 流程)

### 3.4 poison() 伪代码
```
function player.poison() {
    if (player.countMark("poison") > 0) {
        num = player.countMark("poison")
        player.damage(num, NULL, "poison")
    }
}
```
- 按 poison 标记层数造成无来源伤害
- 无标记时不处理
- 调用 `damage(num, NULL, "poison")`(03 轮已实现)

---

## 4. 设计决策(需确认)

### 4.1 方法位置(提议)
4 个方法都在 `scripts/system/player.gd`(Player 类)上实现,因为:
- 设计文档 receiver 都是 `player`
- Player 已有 02 轮的基础属性与 03 轮的 damage

### 4.2 game.log stub(提议)
本轮无 game 对象。`game.log(msg)` stub 为:
```gdscript
# 在 Player 类内,或单独的 game.gd stub
static func _game_log_stub(msg: String) -> void:
    push_warning("[game.log stub] " + msg)
```
- 不创建 game autoload(后续轮次)
- 调用处用 `_game_log_stub(...)` 替代 `game.log(...)`
- 登记 `game.log` 为待定义方法,本轮 stub

### 4.3 recover 触发 4 节点钩子链
用户已确认设计文档为半成品,要求本轮补全「回复生命值」流程设计。已同步更新:
- [J_gameEventFlow.md §16](../GameDesignDocus/GameInstructions/J_gameEventFlow.md#16-回复生命值流程) 新增 4 节点流程(前/时/系统加血/后)
- [GameSystem/PlayerState.md](../GameDesignDocus/GameSystem/PlayerState.md) recover 伪代码改为触发钩子
- [K_gameTerminology.md §7.1](../GameDesignDocus/GameInstructions/K_gameTerminology.md#71-伤害类) 「回复生命时」去掉 [提案] 标记,新增「回复生命前」/「回复生命后」为 [提案]
- [待定义方法.md §9.6](../GameDesignDocus/待定义方法.md#96-player增加生命值n-与-playerrecovernum-的关系) 标记 ✅ 已解决

本轮:
- recover 按新伪代码实现 4 节点钩子链
- 「回复生命时」为已确认 trigger(surgeon 手术刀·回复、手套均使用),本轮须实现并测试
- 「回复生命前」/「回复生命后」为 [提案] 名,本轮按伪代码调用 trigger,但无技能挂载测试

### 4.4 increaseHunger 逐点结算
伪代码用 `while (num > 0)` 循环,每次 +1 并结算。本轮严格按伪代码实现,**不优化**为批量结算。原因:
- 每点饥饿可能触发不同等级的伤害
- 伤害可能触发玩家死亡(03 轮 stub),死亡后是否继续结算需明确(本轮:死亡 stub 不中断循环,因 playerDeath 为空实现)

### 4.5 死亡后是否继续结算(歧义,需确认)
increaseHunger 循环中,若某点伤害触发 playerDeath(本轮 stub 空实现),后续点是否继续?
- **本轮处理**: playerDeath 为 stub(空实现),玩家未真正死亡,循环继续
- **后续轮次**: DeathFlow 实现后,需明确玩家死亡是否中断 increaseHunger 循环
- **登记**: 在 `待定义方法.md` §9.x 登记此歧义

### 4.6 decreaseHunger 返回值
伪代码 `return false`(无法减少时)。GDScript 签名:
- 选项 A: `func decreaseHunger(num: int) -> bool:` 返回是否成功
- 选项 B: `func decreaseHunger(num: int) -> void:` 不返回(调用方不关心)

设计文档伪代码有 `return false`,本轮采用 **选项 A**(`-> bool`)。

### 4.7 命名说明
- `recover`/`increaseHunger`/`decreaseHunger`/`poison` 为已定义方法,保留英文原名(§3.2)
- 内部调用 `增加生命值`/`增加饥饿值`/`减少饥饿值`/`角色卡牌`/`addMarkSkill`/`countMark`/`removeMarkSkill` 保留 02 轮命名

---

## 5. 实施任务清单

1. [ ] 与用户确认 §4.5(死亡后继续结算);§4.3 已确认 recover 触发 4 节点钩子链
2. [ ] 在 `scripts/system/player.gd` 实现 `recover`(§3.1)
3. [ ] 在 `scripts/system/player.gd` 实现 `increaseHunger`(§3.2)
4. [ ] 在 `scripts/system/player.gd` 实现 `decreaseHunger`(§3.3)
5. [ ] 在 `scripts/system/player.gd` 实现 `poison`(§3.4)
6. [ ] 添加 `_game_log_stub`(§4.2)
7. [ ] 在 `待定义方法.md` §9.x 登记"increaseHunger 中玩家死亡是否中断循环"(§4.5)
8. [ ] 在 `待定义方法.md` 登记 `game.log` 为待定义(stub)
9. [ ] 新建 `tests/unit/test_player_state.gd`(§6 验收用例)
10. [ ] 运行 GUT 测试,全部通过
11. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI

---

## 6. 验收标准(测试用例)

测试文件:`tests/unit/test_player_state.gd`,继承 `GutTest`。
用 `Player.new()` 创建玩家,设置初始 HP/饥饿值/标记,调用方法后断言状态。

### 6.1 recover
- `test_recover_normal`: HP=3, max=6, `recover(2)` → HP=5
- `test_recover_exceeds_max_clamped`: HP=5, max=6, `recover(5)` → HP=6(不溢出)
- `test_recover_full_hp_noop`: HP=6, max=6, `recover(3)` → HP=6(max=0,不增加)
- `test_recover_zero_or_negative_noop`: `recover(0)` / `recover(-1)` → HP 不变
- `test_recover_triggers_回复生命时_hook`: 挂"回复生命时"技能(`event.num += 1`), HP=3, max=6, `recover(2)` → HP=6(2+1=3,clamp 到 max-HP=3,实际 +3)
- `test_recover_triggers_回复生命前_and_后_hooks`: 挂"回复生命前"和"回复生命后"技能(各设 flag), `recover(2)` → 两个 flag 均被设置(验证 [提案] trigger 名也能挂载和触发)
- `test_recover_cancel_in_回复生命时`: 挂"回复生命时"技能调用 `event.cancel()`, `recover(2)` → HP 不变, "回复生命后" 不触发
- `test_recover_negative_after_hook_clamped_to_zero`: 挂"回复生命时"技能 `event.num = -5`, `recover(2)` → HP 不变(clamp 后 max=0,加 0)

### 6.2 increaseHunger
- `test_increaseHunger_below_6_only_increases`: hunger=2, `increaseHunger(3)` → hunger=5,无饥饿伤害标记,HP 不变
- `test_increaseHunger_at_6_flips_role_card`: hunger=6, 角色卡正面, `increaseHunger(1)` → 角色卡反面, countMark("饥饿伤害等级")==1, HP 扣 2(level 1)
- `test_increaseHunger_at_6_already_flipped`: hunger=6, 角色卡反面, `increaseHunger(1)` → 角色卡仍反面(不重复翻), countMark==1, HP 扣 2
- `test_increaseHunger_level_2_deals_4_damage`: 已有 1 层标记,hunger=6, `increaseHunger(1)` → countMark==2, HP 扣 4
- `test_increaseHunger_level_3_deals_6_damage`: 2 层 → 3 层,HP 扣 6
- `test_increaseHunger_level_4_deals_8_damage`: 3 层 → 4 层,HP 扣 8
- `test_increaseHunger_level_5_lethal`: 4 层 → 5 层,`damage(最大生命值, NULL, "饥饿伤害")` → playerDeath 被调用(stub)
- `test_increaseHunger_multi_point_iteration`: hunger=4, `increaseHunger(3)` → 逐点:hunger=5(无伤害) → hunger=6(无伤害,仍未到6后翻面) → hunger=6 翻面+1层+2伤害
  - 注意:hunger=4,+1=5(<6,无结算),+1=6(==6,但伪代码 `if 饥饿值()<6` 不满足,走 elif 翻面+标记),+1=6(已翻面,再加标记 level 2,扣 4)
  - 实际:increaseHunger(3) 从 hunger=4 开始:第1点→hunger=5,第2点→hunger=6 翻面+1层+扣2,第3点→hunger仍6(elif 分支)+2层+扣4
- `test_increaseHunger_zero_or_negative_noop`: `increaseHunger(0)` → 无变化

### 6.3 decreaseHunger
- `test_decreaseHunger_normal`: hunger=4, `decreaseHunger(2)` → hunger=2,返回 true
- `test_decreaseHunger_floor_at_1`: hunger=2, `decreaseHunger(5)` → hunger=1(max=1),返回 true
- `test_decreaseHunger_already_at_1_returns_false`: hunger=1, `decreaseHunger(1)` → max=0,返回 false,hunger 仍 1
- `test_decreaseHunger_clears_饥饿伤害标记`: 有 2 层标记,hunger=6, `decreaseHunger(1)` → hunger=5,标记清除(countMark==0)
- `test_decreaseHunger_flips_role_card_back`: 角色卡反面, `decreaseHunger(1)` → 角色卡正面
- `test_decreaseHunger_zero_or_negative_noop`: `decreaseHunger(0)` → 无变化

### 6.4 poison
- `test_poison_no_mark_noop`: 无 poison 标记, `poison()` → HP 不变
- `test_poison_deals_damage_equal_to_mark_level`: poison 标记 3 层, HP=6, `poison()` → HP=3(扣 3,type="poison",source=null)
- `test_poison_uses_no_source_damage`: poison 标记 2 层, `poison()` → 调用 damage(2, NULL, "poison"),source 侧钩子不触发(可用 spy 验证)
- `test_poison_lethal_triggers_playerDeath`: poison 标记 10 层, HP=6, `poison()` → playerDeath 被调用(stub)

### 6.5 集成(与 03 轮 damage)
- `test_increaseHunger_damage_uses_null_source`: increaseHunger 触发的 damage,source 侧钩子不触发(挂 source 技能,断言不调用)
- `test_poison_damage_type_is_poison`: poison 触发的 damage,target 钩子内 `event.type == "poison"`

---

## 7. 风险与待澄清

| 项 | 说明 | 处理 |
|----|------|------|
| recover 钩子链设计 | 用户已确认设计文档为半成品,要求补全 | §4.3 已补全:J_gameEventFlow.md §16 新增 4 节点流程,PlayerState.md 伪代码已更新 |
| increaseHunger 死亡后是否继续 | playerDeath 本轮 stub 空实现,循环继续 | §4.5 登记 §9.x 歧义,后续 DeathFlow 轮次明确 |
| game.log 未实现 | 多处调用 | §4.2 stub 为 push_warning |
| increaseHunger 逐点结算性能 | 大 num 时多次 damage 调用 | 本轮不优化,严格按伪代码;后续若需优化再讨论 |
| 饥饿值 > 6 的状态 | 伪代码 `elif 饥饿值()==6` 暗示不会 >6,但若外部直接 `增加饥饿值` 导致 >6,increaseHunger 行为? | 本轮不处理;登记到待定义方法.md(饥饿值上限) |
| decreaseHunger 返回值类型 | 伪代码 `return false`,GDScript 用 bool | §4.6 选项 A |

---

## 8. 不做的事

- 不为「回复生命前」/「回复生命后」[提案] trigger 编写技能挂载测试用例(§4.3)
- 不实现 game 对象(仅 stub game.log)
- 不实现 playerDeath/monsterDeath 真实逻辑(03 轮已 stub)
- 不优化 increaseHunger 为批量结算(§4.4)
- 不处理饥饿值 > 6 的异常状态(§7)
- 不修改 `data/` 下任何文件
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不实现标记的 Until 参数
