# 13 - SkillExecutor（技能调度器）

> MA 的技能调度中枢：在各时机点扫描所有已注册 Skill，按 ECA 模式（trigger → filter → content）调度执行。
> SkillExecutor 是 Node 子类，由 GameSession 持有（子节点），通过 `game_session` 字段反查 GameSession。
> 本文承接 [01-Skill.md](01-Skill.md) 第 8 节的简略框架，详细定义扫描范围、调度流程、递归触发处理与 UI 询问流程。
> 应用决策：D26-D32（Skill 系统）/ D46（装备卡技能单独遍历）/ D62-D63（GameSession 持有 + 协调者模式）。

---

## 1. 设计原则

- **SkillExecutor 由 GameSession 持有**：作为 GameSession 的子节点，通过 `game_session` 字段反查 GameSession。每局游戏随 GameSession 创建/销毁（与 11-GameSession.md 决策一致）。
- **集中调度 + 词汇表下沉**：SkillExecutor 只负责扫描候选 / 排队 / 询问 / 调用 execute；execute 内部的状态修改通过 owner.draw / target.take_damage 等词汇表方法下沉到 Entity/Card/MapBlock 基类（不在 SkillExecutor 内直接改状态）。
- **扫描顺序固定**：当前回合玩家 → 其他存活玩家（按座次）→ 所有存活怪物 → 当前地块 → 装备区（作为 Survivor 子步骤，见第 3 节）。同一时机多技能按此顺序串行处理。
- **forced 优先 + 队尾追加**：dispatch 时先收集所有候选 → 分两批处理（第一批 forced=true 串行执行；第二批 forced=false 逐个弹窗询问）→ execute 内部触发的新事件入队尾追加，避免嵌套调用栈爆栈。
- **实时查表，不维护缓存**：每次 dispatch 时遍历 owners，调 `owner.get_skills()` 走 SkillRegistry 查表（ponytail：YAGNI，避免缓存失效复杂性）。
- **UI 询问用 await 异步等待**：forced=false 候选弹窗询问玩家时，dispatch 流程 await 等待玩家选择，避免阻塞主线程（GDScript 4 推荐做法）。

---

## 2. SkillExecutor 类定义

```text
class_name SkillExecutor extends Node

const MAX_RECURSION_DEPTH: int = 64   # 递归触发深度上限（防死循环）

# === 引用 ===
var game_session: GameSession         # 反查 GameSession

# === 调度队列状态 ===
var _dispatch_queue: Array[GameEvent] = []   # 待处理事件队列
var _current_dispatch_depth: int = 0        # 当前递归深度
var _is_dispatching: bool = false           # 是否正在调度中（防止重入）

# === 信号（UI 通知） ===
signal skill_dispatched(skill_id: StringName, owner: Variant, event: GameEvent)  # 技能开始执行
signal skill_executed(skill_id: StringName, owner: Variant, event: GameEvent)    # 技能执行完毕
signal optional_skill_prompt(skill_id: StringName, owner: Variant, event: GameEvent)  # 询问玩家是否发动可选技能
signal dispatch_queue_empty()                 # 队列处理完毕（UI 可推进阶段）
signal recursion_depth_exceeded(event: GameEvent)  # 递归深度超限（调试/告警用）

# === 主入口：时机分发 ===

# 在各时机点由 TurnManager / GameSession / Entity 等调用
# event 由调用方构造（含 timing / source / target / player / amount / card / extra）
func dispatch(timing: TriggerTiming, event: GameEvent) -> void:
    event.timing = timing
    _dispatch_queue.append(event)
    if not _is_dispatching:
        _process_queue()

# === 队列处理循环 ===

func _process_queue() -> void:
    _is_dispatching = true
    while not _dispatch_queue.is_empty():
        if _current_dispatch_depth >= MAX_RECURSION_DEPTH:
            var dropped = _dispatch_queue.pop_front()
            recursion_depth_exceeded.emit(dropped)
            push_error("[SkillExecutor] MAX_RECURSION_DEPTH exceeded, dropping event: ", dropped.timing)
            break
        var event = _dispatch_queue.pop_front()
        _current_dispatch_depth += 1
        _dispatch_single_event(event)
        _current_dispatch_depth -= 1
    _is_dispatching = false
    dispatch_queue_empty.emit()

# === 单事件调度：收集候选 → 分两批处理 ===

func _dispatch_single_event(event: GameEvent) -> void:
    var candidates = _collect_candidates(event)
    # 第一批：forced=true 串行执行（按扫描顺序）
    for c in candidates:
        if c.skill.forced:
            _execute_skill(c.skill, c.owner, event)
    # 第二批：forced=false 逐个弹窗询问
    for c in candidates:
        if not c.skill.forced:
            var accepted = await _prompt_optional(c.skill, c.owner, event)
            if accepted:
                _execute_skill(c.skill, c.owner, event)

# === 候选收集（按扫描顺序遍历 owners + 装备区） ===

func _collect_candidates(event: GameEvent) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var timing = event.timing
    # 1. 当前回合玩家（含其装备区）
    var current_player = game_session.get_current_player()
    if current_player != null and current_player.is_alive:
        _collect_from_owner(current_player, timing, event, result)
        _collect_from_equipment(current_player, timing, event, result)
    # 2. 其他存活玩家（按座次顺序，含其装备区）
    for survivor in game_session.survivors:
        if survivor == current_player or not survivor.is_alive:
            continue
        _collect_from_owner(survivor, timing, event, result)
        _collect_from_equipment(survivor, timing, event, result)
    # 3. 所有存活怪物（纠缠任意玩家的 + 未纠缠的）
    for monster in game_session.get_all_monsters():
        if not monster.is_alive:
            continue
        _collect_from_owner(monster, timing, event, result)
    # 4. 当前地块
    if current_player != null and current_player.current_block != null:
        _collect_from_owner(current_player.current_block, timing, event, result)
    return result

# 从单个 owner（Entity / MapBlockInstance）收集匹配的 skill
func _collect_from_owner(owner: Variant, timing: TriggerTiming, event: GameEvent, out: Array[Dictionary]) -> void:
    for skill in owner.get_skills():
        if skill.skill_type != SkillType.TRIGGER:
            continue
        if not (timing in skill.get_trigger_timings()):
            continue
        if skill.can_trigger(event, owner):
            out.append({"skill": skill, "owner": owner})

# 从某 Survivor 的装备区收集匹配的 skill（owner = 装备卡 CardInstance）
func _collect_from_equipment(survivor: Survivor, timing: TriggerTiming, event: GameEvent, out: Array[Dictionary]) -> void:
    for card in survivor.equipment_zone:
        for skill in card.get_skills():
            if skill.skill_type != SkillType.TRIGGER:
                continue
            if not (timing in skill.get_trigger_timings()):
                continue
            if skill.can_trigger(event, card):
                out.append({"skill": skill, "owner": card})

# === 技能执行 ===

func _execute_skill(skill: Skill, owner: Variant, event: GameEvent) -> void:
    skill_dispatched.emit(skill.skill_id, owner, event)
    skill.execute(event, owner)
    skill_executed.emit(skill.skill_id, owner, event)
    # execute 内部若触发新事件（如 take_damage → ON_DAMAGE_TAKEN），
    # 新事件已通过 dispatch() 入队尾，_process_queue 循环会自动处理

# === 可选技能询问（UI 弹窗） ===

func _prompt_optional(skill: Skill, owner: Variant, event: GameEvent) -> bool:
    optional_skill_prompt.emit(skill.skill_id, owner, event)
    # await UI 层回传玩家选择（UI 监听 optional_skill_prompt 信号并显示弹窗）
    # UI 层调用 skill_executor.respond_optional_choice(accepted) 回传
    var accepted = await _wait_for_optional_choice()
    return accepted

var _optional_choice_callback: Callable  # 由 UI 层设置的可调用对象

func set_optional_choice_callback(cb: Callable) -> void:
    _optional_choice_callback = cb

func respond_optional_choice(accepted: bool) -> void:
    if _optional_choice_callback.is_valid():
        _optional_choice_callback.call(accepted)
        _optional_choice_callback = Callable()

func _wait_for_optional_choice() -> bool:
    # 简化伪代码：实际用 Signal 或 Promise 模式 await UI 回传
    # 见第 6 节"UI 询问异步模式"
    return await _optional_choice_signal

signal _optional_choice_signal(accepted: bool)

# === 主动入口 ===

# 玩家点击主动技按钮（UI 层调用）
func try_use_active(skill_id: StringName, owner: Variant, target: Variant = null) -> bool:
    var skill = SkillRegistry.get_skill(skill_id)
    if skill == null or skill.skill_type != SkillType.ACTIVE:
        return false
    if not (owner is Entity) or not owner.is_alive:
        return false
    var event = GameEvent.new()
    event.timing = TriggerTiming.ACTIVE_USE
    event.player = owner if owner is Survivor else game_session.get_current_player()
    event.source = owner
    event.target = target
    if not skill.can_trigger(event, owner):
        return false
    # 扣行动点（action_cost > 0 时）
    if skill.action_cost > 0:
        if not game_session.turn_manager.spend_action(skill.action_cost):
            return false
    _execute_skill(skill, owner, event)
    return true

# 玩家选弃此卡以触发弃牌技（UI 层调用）
func try_use_discard(skill_id: StringName, owner: CardInstance, target: Variant = null) -> bool:
    var skill = SkillRegistry.get_skill(skill_id)
    if skill == null or skill.skill_type != SkillType.DISCARD:
        return false
    var event = GameEvent.new()
    event.timing = TriggerTiming.ON_DISCARD_CHOICE
    event.player = game_session.get_current_player()
    event.source = owner
    event.target = target
    event.card = owner
    if not skill.can_trigger(event, owner):
        return false
    # 弃置 owner 卡（自动）—— 由 Card 基类的 discard 方法处理
    owner.discard()
    _execute_skill(skill, owner, event)
    return true
```

---

## 3. 扫描顺序与范围

### 3.1 扫描顺序（固定）

```text
1. 当前回合玩家（current_player）
   1a. current_player 的天赋/内置 skill_ids
   1b. current_player.equipment_zone 中每张装备卡的 skill_ids（owner = CardInstance）
2. 其他存活玩家（按座次顺序，跳过已死亡）
   2a. 该玩家的天赋/内置 skill_ids
   2b. 该玩家装备区每张装备卡的 skill_ids
3. 所有存活怪物（game_session.get_all_monsters()，跳过已死亡）
   - 怪物的 skill_ids（天赋/技能）
4. 当前地块（current_player.current_block）
   - 地块的 skill_ids（地块效果，forced=true TRIGGER）
```

> 装备区扫描作为 Survivor 扫描的子步骤（D46 + 用户决策）：扫到某 Survivor 时立即扫其装备区。owner = 装备卡 CardInstance（与 01-Skill.md Q2 倾向一致），execute 内通过 `event.player` 操作 Survivor。

### 3.2 扫描范围说明

| Owner 类型 | 技能来源 | 扫描方法 |
|---|---|---|
| Survivor | `CharacterCardData.talent_skill_ids` → `Entity.skill_ids` | `survivor.get_skills()` → `SkillRegistry.get_skill(id)` |
| Monster | `MonsterCardData.skill_ids` → `Entity.skill_ids` | `monster.get_skills()` → `SkillRegistry.get_skill(id)` |
| MapBlockInstance | `MapBlockData.skill_ids` | `block.get_skills()` → `SkillRegistry.get_skill(id)` |
| 装备卡 CardInstance | `EquipmentCardData.skill_ids` | `card.get_skills()` → `SkillRegistry.get_skill(id)` |

> MapBlockInstance 不继承 Entity（D47），但同样提供 `get_skills()` 方法返回 `skill_ids.map(SkillRegistry.get_skill)`，接口统一。

### 3.3 不扫描的对象

- **已死亡 Survivor**：`is_alive == false` 跳过（含其装备区）
- **已死亡 Monster**：`is_alive == false` 跳过
- **未展示地块**：`is_revealed == false` 不参与扫描（地块效果仅在展示后触发）
- **非当前玩家面前怪物**：仍扫描（怪物技能可能影响全局，如"所有玩家受伤"）

---

## 4. dispatch 调度流程

### 4.1 完整流程

```text
dispatch(timing, event) 流程：
  1. event.timing = timing
  2. event 入 _dispatch_queue 队尾
  3. 若 _is_dispatching == true：直接返回（队列循环会自动处理）
  4. _is_dispatching = true
  5. while _dispatch_queue 非空：
     a. 若 _current_dispatch_depth >= MAX_RECURSION_DEPTH：emit recursion_depth_exceeded，break
     b. event = _dispatch_queue.pop_front()
     c. _current_dispatch_depth += 1
     d. _dispatch_single_event(event)   ← 见 4.2
     e. _current_dispatch_depth -= 1
  6. _is_dispatching = false
  7. emit dispatch_queue_empty
```

### 4.2 单事件调度

```text
_dispatch_single_event(event) 流程：
  1. candidates = _collect_candidates(event)   ← 按 3.1 扫描顺序收集
  2. 第一批：for c in candidates where c.skill.forced == true：
     - _execute_skill(c.skill, c.owner, event)   ← 串行执行，可能修改 event
  3. 第二批：for c in candidates where c.skill.forced == false：
     - accepted = await _prompt_optional(c.skill, c.owner, event)  ← 弹窗询问
     - if accepted: _execute_skill(c.skill, c.owner, event)
  4. 单事件处理完毕（注意：execute 内部触发的新事件已入队尾，由 _process_queue 循环继续处理）
```

### 4.3 关键约束

- **forced 串行修改同一 event**：多个 forced=true 减伤技能（焊接头盔 / 防弹背心 / 方阵机器人）按扫描顺序串行修改 `event.amount`，最后一次性结算 `current_hp -= max(0, event.amount)`。SkillExecutor 不重复触发 take_damage。
- **forced 不询问**：forced=true 锁定技 can_trigger 通过后直接 execute，不弹窗（与三国杀锁定技一致）。
- **forced 顺序与扫描顺序一致**：第一批 forced 候选按扫描顺序执行（当前玩家 → 其他玩家 → 怪物 → 地块 → 装备区）。
- **可选技能逐个弹窗**：第二批 forced=false 候选按扫描顺序逐个弹窗询问，每个弹窗 Yes/No 二选一。

---

## 5. forced 候选处理

### 5.1 处理规则

| 规则 | 说明 |
|---|---|
| 执行时机 | 第一批，在所有 forced 候选收集完成后串行执行 |
| 执行顺序 | 按扫描顺序（当前玩家 → 其他玩家 → 怪物 → 地块 → 装备区） |
| 询问玩家 | 不询问，can_trigger 通过即 execute |
| can_trigger 失败 | 静默跳过（不提示玩家，与三国杀锁定技一致） |
| 修改 event | 直接修改 event.amount / event.target 等字段，后续 forced 候选看到的是修改后的 event |
| 触发新事件 | execute 内部调用 owner.draw / target.take_damage 等词汇表方法时，新事件入队尾追加 |

### 5.2 典型场景：多张减伤卡同时生效

```text
玩家 P 装备焊接头盔（-1）+ 防弹背心（-2，耐久 1）+ 方阵机器人 buff（范围内机器人受伤-1）
怪物攻击造成 5 点伤害 → take_damage(5, monster) 调度 ON_DAMAGE_TAKEN

_collect_candidates 收集到 3 个 forced 候选（按扫描顺序）：
  1. 焊接头盔（P 装备区）  can_trigger: event.target == owner.player → true
  2. 防弹背心（P 装备区）  can_trigger: event.target == owner.player + current_durability > 0 → true
  3. 方阵机器人 buff（怪物 owner？或玩家 buff？取决于具体技能设计）

第一批串行执行：
  焊接头盔.execute → event.amount = 5 - 1 = 4
  防弹背心.execute → event.amount = 4 - 2 = 2; current_durability -= 1（归零则 remove）
  方阵机器人.execute → event.amount = 2 - 1 = 1

回到 take_damage 流程：current_hp -= max(0, 1) = 1
```

> 注意：方阵机器人 buff 的 owner 设计待具体技能录入时确定。本例仅展示多 forced 串行修改 event 的模式。

---

## 6. 可选候选处理（UI 询问）

### 6.1 逐个弹窗模式

```text
第二批 forced=false 候选处理：
  for c in candidates where c.skill.forced == false:
    1. emit optional_skill_prompt(c.skill.skill_id, c.owner, event)
    2. await UI 层回传玩家选择（Yes/No）
    3. if Yes: _execute_skill(c.skill, c.owner, event)
    4. if No: 静默跳过
```

### 6.2 UI 询问异步模式

GDScript 4 推荐 await 异步等待模式，避免阻塞主线程：

```text
# SkillExecutor 侧
signal _optional_choice_signal(accepted: bool)

func _prompt_optional(skill, owner, event) -> bool:
    optional_skill_prompt.emit(skill.skill_id, owner, event)
    return await _optional_choice_signal   # 挂起等待

# UI 层侧
func _on_optional_skill_prompt(skill_id, owner, event):
    $PromptDialog.show(skill_id, owner, event)   # 显示弹窗

func _on_prompt_dialog_choice(accepted: bool):
    skill_executor._optional_choice_signal.emit(accepted)   # 回传选择
```

> 实际实现可用 `Signal.await` 或 Promise 模式。本文用简化伪代码示意。

### 6.3 默认行为

| 场景 | 默认行为 |
|---|---|
| 玩家超时未选择 | 默认 No（不发动） |
| UI 层未设置回调 | 默认 No（防止卡死） |
| 玩家死亡后触发的可选技能 | 跳过（owner.is_alive == false 已在扫描时过滤） |

---

## 7. 递归触发与队尾追加

### 7.1 递归触发场景

```text
玩家 P 攻击怪物 M（武器技能）→ M.take_damage(3, P)
  → 调度 ON_DAMAGE_TAKEN（target=M, source=P, amount=3）
    → M 的"受伤时对攻击者反伤 1"forced 技能 execute
      → P.take_damage(1, M)
        → 调度 ON_DAMAGE_TAKEN（target=P, source=M, amount=1）
          → 入队尾追加，不立即嵌套调用
    → M 的减伤技能 execute（若 forced）
    → M 死亡 → die(P)
      → 调度 ON_DEATH（target=M, source=P）入队尾
      → 调度 ON_KILL（killer=P, target=M）入队尾
原 ON_DAMAGE_TAKEN 处理完毕 → _process_queue 继续处理队尾的 ON_DAMAGE_TAKEN(P) → ON_DEATH → ON_KILL
```

### 7.2 队尾追加策略

```text
execute 内部调用词汇表方法时：
  - take_damage / heal / die / draw / discard / remove / equip / unequip / move 等方法
  - 这些方法内部调用 SkillExecutor.dispatch(timing, event)
  - dispatch 将新 event 入 _dispatch_queue 队尾
  - 当前 execute 返回后，_process_queue 循环继续处理队尾事件
```

### 7.3 递归深度上限

```text
const MAX_RECURSION_DEPTH: int = 64

_process_queue 循环每次处理一个 event 时：
  _current_dispatch_depth += 1
  若 _current_dispatch_depth >= MAX_RECURSION_DEPTH：
    emit recursion_depth_exceeded(event)
    push_error("[SkillExecutor] MAX_RECURSION_DEPTH exceeded")
    break（停止处理剩余队列）
```

> MAX_RECURSION_DEPTH=64 是安全阀，正常游戏不会触发。触发时通常是技能设计 bug（如 A 触发 B、B 触发 A 死循环）。push_error 提示开发者排查。

### 7.4 重入保护

```text
_is_dispatching: bool 标记防止重入：
  - dispatch(timing, event) 被调用时，若 _is_dispatching == true，仅入队不入循环
  - 这保证了 execute 内部触发的新事件不会立即嵌套处理，而是入队尾追加
```

---

## 8. 主动入口

### 8.1 try_use_active（主动技）

```text
try_use_active(skill_id, owner, target=null) -> bool 流程：
  1. SkillRegistry.get_skill(skill_id)，null 或非 ACTIVE 类型返回 false
  2. owner 必须是 Entity 且 is_alive == true
  3. 构造 GameEvent { timing=ACTIVE_USE, player=owner(Survivor)/当前回合玩家, source=owner, target=target }
  4. skill.can_trigger(event, owner) 返回 false 则返回 false
  5. action_cost > 0 时调 game_session.turn_manager.spend_action(action_cost)
     - 行动点不足返回 false
  6. _execute_skill(skill, owner, event)
  7. 返回 true
```

> 行动点扣除由 SkillExecutor 统一调用 TurnManager.spend_action，便于 UI 信号触发与失败回滚。

### 8.2 try_use_discard（弃牌技）

```text
try_use_discard(skill_id, owner, target=null) -> bool 流程：
  1. SkillRegistry.get_skill(skill_id)，null 或非 DISCARD 类型返回 false
  2. owner 必须是 CardInstance
  3. 构造 GameEvent { timing=ON_DISCARD_CHOICE, player=当前回合玩家, source=owner, target=target, card=owner }
  4. skill.can_trigger(event, owner) 返回 false 则返回 false
  5. owner.discard() —— 弃置此卡（由 Card 基类处理，隐含触发 ON_DISCARD 时机）
  6. _execute_skill(skill, owner, event)
  7. 返回 true
```

> 弃牌技的 owner 是被弃置的卡本身。execute 内部通过 `event.player` 操作玩家。

### 8.3 主动入口与 dispatch 的区别

| 维度 | dispatch | try_use_active / try_use_discard |
|---|---|---|
| 触发方 | 系统在各时机点调用 | 玩家通过 UI 主动点击 |
| 走队列 | 是（入 _dispatch_queue） | 否（直接 execute，不入队列） |
| 走候选收集 | 是 | 否（直接指定 skill_id + owner） |
| 弹窗询问 | forced=false 候选会弹窗 | 不弹窗（玩家已主动选择） |
| 行动点 | 不扣（被动触发不消耗行动点） | try_use_active 扣 action_cost |
| 弃牌 | 不弃 | try_use_discard 自动弃置 owner 卡 |

> 主动入口不走过队列与候选收集，但仍调 `_execute_skill`，execute 内部触发的新事件会走 dispatch 入队尾。

---

## 9. 与其他子系统的交互

### 9.1 与 SkillRegistry 的交互

```text
SkillExecutor 调 owner.get_skills() → 内部调 SkillRegistry.get_skill(skill_id)
SkillRegistry 是 autoload 单例（01-Skill.md 第 7 节），启动时扫描所有 Skill 子类 .gd 注册
```

### 9.2 与 Entity / MapBlockInstance 的交互

| 调用方 | 方法 | 说明 |
|---|---|---|
| SkillExecutor | `owner.get_skills()` | 返回 `Array[Skill]`，统一接口（Entity / MapBlockInstance / CardInstance 都提供） |
| SkillExecutor | `survivor.equipment_zone` | 扫描装备区时遍历（D46） |
| SkillExecutor | `game_session.get_current_player()` | 获取当前回合玩家（扫描顺序首位） |
| SkillExecutor | `game_session.survivors` | 遍历其他存活玩家 |
| SkillExecutor | `game_session.get_all_monsters()` | 遍历所有存活怪物（待 GameSession 提供） |
| SkillExecutor | `current_player.current_block` | 获取当前地块 |

> `game_session.get_all_monsters()` 待 11-GameSession.md 补充：返回当前所有 Monster 节点列表（含未纠缠的）。

### 9.3 与 TurnManager 的交互

```text
TurnManager 在各阶段切换时调用 SkillExecutor.dispatch(timing, event)：
  - 阶段 1 怪物出生：dispatch(ON_MONSTER_SPAWN_ROLL, ...) 等
  - 阶段 2 抓牌：dispatch(ON_CARD_DRAWN, ...)
  - 阶段 3 移动：dispatch(ON_REVEAL/ON_ENTER/ON_LEAVE, ...)
  - 阶段 4a 地块结束：dispatch(ON_TURN_END_ON_BLOCK, ...)
  - 阶段 4b 饥饿：dispatch(ON_HUNGER, ...) / dispatch(ON_HUNGER_DAMAGE, ...)
  - 阶段 4b.5 中毒：dispatch(ON_POISON_DAMAGE, ...)
  - 阶段 4c 怪物攻击：dispatch(ON_MONSTER_ATTACK, ...) / dispatch(ON_DAMAGE_TAKEN, ...)
```

### 9.4 与 Entity.take_damage 的交互

```text
Entity.take_damage(amount, source, unavoidable=false) 流程（06-Entity.md §3.1）：
  1. if not is_alive: return
  2. if unavoidable: 跳过 ON_DAMAGE_TAKEN 调度，直接 actual_amount = amount
  3. else:
     - 构造 GameEvent { timing=ON_DAMAGE_TAKEN, target=self, source=source, amount=amount, unavoidable=false }
     - SkillExecutor.dispatch(ON_DAMAGE_TAKEN, event)
     - actual_amount = max(0, event.amount)
  4. current_hp -= actual_amount
  5. damage_taken.emit(actual_amount, source, unavoidable)
  6. if current_hp <= 0: die(source)
```

> 14-CombatSystem.md 详述 unavoidable 参数与 take_damage 统一入口。SkillExecutor 仅负责调度 ON_DAMAGE_TAKEN 时机，不参与伤害结算本身。

---

## 10. 信号（UI 通知）

| 信号 | 参数 | 触发时机 | UI 用途 |
|---|---|---|---|
| `skill_dispatched` | skill_id, owner, event | 技能开始 execute 时 | 显示技能发动提示 / 高亮 owner |
| `skill_executed` | skill_id, owner, event | 技能 execute 返回时 | 关闭技能发动提示 / 推进演出 |
| `optional_skill_prompt` | skill_id, owner, event | forced=false 候选弹窗时 | UI 层显示"是否发动 XX？"弹窗 |
| `dispatch_queue_empty` | （无参） | 队列处理完毕时 | UI 层推进到下一阶段（如阶段切换） |
| `recursion_depth_exceeded` | event | 递归深度超 MAX 时 | 调试告警（正常游戏不触发） |

---

## 11. 待定问题

### Q1. owner 类型标注

`_collect_from_owner(owner: Variant, ...)` 的 owner 实际是 `Entity | MapBlockInstance | CardInstance` 的联合。GDScript 4 无联合类型，暂用 Variant。是否在文档中明确"owner 必须实现 `get_skills()` 接口"的协议约束？

- 候选 A：用 Variant + 文档约束（ponytail）
- 倾向 A

### Q2. game_session.get_all_monsters() 接口

11-GameSession.md 未定义此方法。是否补一个返回所有 Monster 节点的方法？或 SkillExecutor 自己维护一个 `_all_monsters: Array[Monster]` 列表，怪物创建/销毁时增删？

- 候选 A：GameSession 提供 `get_all_monsters()` 方法（遍历场景树或维护列表）
- 候选 B：SkillExecutor 维护 `_all_monsters` 列表，怪物 engage/disengage 时通知
- 倾向 A（GameSession 集中管理）

### Q3. 可选技能弹窗的"超时默认 No"是否需要

6.3 节默认超时 No。是否需要超时机制？还是 UI 层强制玩家必须选择（无超时）？

- 候选 A：UI 层强制玩家选择（无超时，避免误判）
- 候选 B：超时默认 No（防止卡死）
- 倾向 A（PC 版无超时需求）

### Q4. forced=false 候选弹窗的"全部 Yes / 全部 No"快捷按钮

同一时机多可选技能时，逐个弹窗可能繁琐。是否在 UI 层提供"全部 Yes / 全部 No"快捷按钮？

- 候选 A：提供快捷按钮（UI 层实现，不影响 SkillExecutor 接口）
- 候选 B：不提供，逐个弹窗
- 倾向 A（UI 体验，待 UI 设计层确认）

### Q5. 同 owner 多装备同时触发 forced 时的顺序

某 Survivor 装备区有多张装备卡同时匹配同一时机（如多张减伤卡）。3.1 节扫描顺序为"装备区每张卡按数组顺序"。是否需要额外的 priority 字段？

- 候选 A：按 equipment_zone 数组顺序（先装备的先触发）
- 候选 B：加 `priority: int` 字段（玩家可配置优先级）
- 倾向 A（ponytail，YAGNI priority）

### Q6. Monster 触发技能时 owner.player 字段

怪物技能 execute 时若需要操作当前回合玩家，应通过 `event.player`（由 GameEvent 携带）。GameSession 调度怪物攻击时是否在 event.player 填入被攻击的 Survivor？

- 候选 A：是，event.player = 被攻击的 Survivor（不是 current_player）
- 候选 B：event.player = current_player（当前回合玩家）
- 倾向 A（语义清晰：怪物技能作用对象是被攻击者）

### Q7. 装备卡 owner 在 execute 内如何访问 Survivor

装备卡作为 owner 时，execute 内访问 `event.player` 是否够用？还是需要 `owner.player`（装备卡持有玩家）字段？

- 候选 A：用 event.player（当前回合玩家，可能与装备持有者不同）
- 候选 B：CardInstance 提供 `get_owner_player()` 方法返回装备持有者
- 倾向 B（语义清晰，装备技能通常作用持有者）

### Q8. dispatch 的 event 对象复用

同一时机多 forced 候选串行修改同一 event 对象（如多张减伤卡）。若中途某 forced 候选 execute 内触发新事件（如反伤），新事件是独立的 event 对象，不影响当前 event？

- 候选 A：是，新事件独立 event 对象（dispatch 时构造新 GameEvent）
- 候选 B：共享引用（危险，不推荐）
- 倾向 A（已隐含在实现中）

### Q9. try_use_active 失败时的行动点回滚

try_use_active 第 5 步扣行动点后，第 6 步 _execute_skill 内部若抛异常或触发死亡导致流程中断，行动点是否回滚？

- 候选 A：不回滚（行动点已扣，异常情况由 GameSession 判定游戏结束）
- 候选 B：try-catch 回滚
- 倾向 A（ponytail，GDScript 异常场景罕见）

### Q10. SkillExecutor 是否需要"事件历史"调试记录

是否维护一个 `_event_history: Array[GameEvent]` 记录所有调度过的事件，便于调试与录像回放？

- 候选 A：不维护（YAGNI，需要时再加）
- 候选 B：维护（便于调试）
- 倾向 A

---

## 附：决策应用索引

本文档应用的决策：

- D26 Skill ECA 模式（trigger → filter → content，§4 调度流程）
- D27 SkillType 三类（TRIGGER 走 dispatch，ACTIVE/DISCARD 走主动入口，§8）
- D28 forced 锁定技标记（第一批串行执行不询问，§5）
- D29 数据 + 逻辑分离（SkillExecutor 通过 SkillRegistry 查表，§9.1）
- D30 规则集中 + UI 信号（SkillExecutor 集中调度，§10 信号）
- D31 owner 显式传入（_collect_from_owner / _execute_skill 第二参数，§2/§3）
- D32 GameEvent 三字段区分（source/target/player 职责区分，§2）
- D46 装备卡技能不通过 Entity.skill_ids 管理（_collect_from_equipment 单独扫描，§3.2）
- D47 MapBlock 不继承 Entity（_collect_from_owner 接受 Variant，§9.2）
- D62 GameSession 持有所有子系统（SkillExecutor 为 GameSession 子节点，§1）
- D63 GameSession 是协调者而非执行者（SkillExecutor 委托调度，§1）
- 用户决策：forced 优先 + 队尾追加（§4 调度流程 + §7 递归触发）
- 用户决策：分两批处理（第一批 forced 串行 / 第二批可选弹窗，§4.2）
- 用户决策：可选技能逐个弹窗（§6.1）
- 用户决策：装备卡作为 Survivor 扫描子步骤（§3.1）
- 用户决策：每次实时遍历查表（不维护 owner→skills 缓存，§1/§9.1）
- 用户决策：MAX_RECURSION_DEPTH=64 安全阀（§7.3）
- 用户决策：UI 询问用 await 异步等待（§6.2）
