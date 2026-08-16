# Player 玩家类

> 继承：[Entity](../Core/Entity.md)
> 职责：玩家实体的状态、区域、行动与玩家专属流程方法。
> 代码：`src/entities/player.gd`，`class_name Player extends Entity`。
> trigger 机制与全 trigger 索引见 [EventSystem.md](../Core/EventSystem.md)。

---

## 字段

### 状态字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `hp` | int | `0` | 当前生命值。≤ 0 时玩家死亡 |
| `max_hp` | int | `0` | 生命值上限。恢复不超过此值 |
| `hunger` | int | `1` | 饥饿值，范围 1-6。每回合 +1。达 6 后翻面角色卡并叠加饥饿伤害标记 |
| `stealth` | int | `0` | 潜行值（不含角色卡修正）。基础潜行值 - (地块怪物数 + 怪物标记数) |
| `action_count` | int | `0` | 行动次数。每回合 4 次。移动 / 抓牌 / 出牌 / 拾荒 / 执行卡牌行动各消耗 1 次 |
| `max_action_count` | int | `4` | 行动次数上限。部分技能可临时增加 |
| `in_phase` | String | `"idle"` | 当前所处回合阶段，技能 filter 用。值见下表 |
| `_phase_end_requested` | String | `""` | 内部信号：`end_phase` 设置后 `wait_player_action` 循环跳出 |

#### `in_phase` 中英映射

| 英文值 | 中文阶段 | 切换节点 |
|--------|---------|---------|
| `"idle"` | 回合外（默认） | 回合开始前 / 回合结束节点 20 |
| `"turn_start"` | 回合开始 | 节点 1 |
| `"monster_spawn"` | 怪物出生 | 节点 4 |
| `"draw"` | 摸牌阶段 | 节点 6 |
| `"action"` | 行动阶段 | 节点 8（迷你回合与立即出牌临时切换） |
| `"hunger"` | 饥饿结算 | 节点 12 |
| `"poison"` | 中毒结算 | 节点 14 |
| `"monster_action"` | 怪物行动 | 节点 16 |
| `"turn_end"` | 回合结束 | 节点 18 |
| `"round_zero"` | 第零轮重调 | 由 GameStateMachine `_round_zero` 设置 |

### 区域字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `hand` | Array\<Card\> | `[]` | 手牌区。上限 10 张 |
| `equipment_zone` | Array\<Equipment\> | `[]` | 装备区（持 Equipment 实体）。受装备栏容量限制（容量由 `RoleCard.equipment_capacity` 决定，见 [RoleCard](../Common/RoleCard.md)） |
| `monster_zone` | Array\<Monster\> | `[]` | 怪物区。玩家面前的怪物卡区域。怪物卡进入此区时与玩家纠缠 |
| `game_deck` | Pile | `null` | 求生者游戏牌堆。抓牌从此处；牌堆空时玩家死亡 |
| `game_discard_pile` | Pile | `null` | 求生者游戏牌弃牌堆 |

### 关联对象

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `role_card` | RoleCard | `null` | 角色卡。饥饿值达 6 后翻面，减少饥饿值后恢复正面 |
| `current_block` | MapBlock | `null` | 当前所在地块 |
| `seat_number` | int | `0` | 座位号（游戏房间中的座位次序） |
| `player_name` | String | `""` | 玩家名（用于日志输出与 EventBus 信号载荷） |

### 标记与输入

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `marks` | Dictionary\<String, int\> | `{}` | 标记字典。键 = 标记名，值 = 计数。如 `"poison"` / `"hunger_damage_level"` / `"moved_this_turn"` / `"shelter_disabled"` 等 |
| `input` | IPlayerInput | 自动 `CliPlayerInput.new()` | 输入接口（选择器、确认对话框、目标选择等） |

#### 常用标记

| 标记 | 说明 |
|------|------|
| `poison` | 中毒标记。回合结算时受到等量伤害（无来源伤害） |
| `hunger_damage_level` | 饥饿伤害等级。等级 1-5 分别造成 2/4/6/8/致死伤害 |
| `shelter_disabled` | 避难所失效标记，持续到回合结束 |
| `moved_this_turn` | 本回合已移动标记。爆破机器人天赋 2 等技能依赖。回合开始时清除 |
| 其他临时标记 | 各技能 / 地块添加的标记 |

> 标记管理通过 `count_mark` / `add_mark` / `remove_mark` / `has_mark` / `add_mark_skill` / `has_mark_skill` 等方法。

---

## 信号量（triggers）

> 完整 trigger 列表见 [EventSystem.md](../Core/EventSystem.md)。Player 类涉及的 trigger 领域：

- **伤害 / 回复类**：`before_take_damage` / `on_take_damage` / `after_take_damage`、`before_recover` / `on_recover` / `after_recover`
- **移动类**：`before_leave_block` / `on_leave_block` / `after_leave_block`、`before_enter_block` / `on_enter_block` / `after_enter_block`
- **回合类**：`before_turn_start` / `on_turn_start`、`before_monster_spawn` / `on_monster_spawn`、`before_draw_phase`、`before_action_phase` / `before_action_phase_end` / `on_action_phase_end`、`before_hunger_settlement` / `on_hunger_settlement`、`before_poison_settlement` / `on_poison_settlement`、`before_zone_monster_act` / `on_zone_monster_act`、`before_turn_end` / `on_turn_end`
- **抓牌类**：`before_draw_game_card` / `on_draw_game_card` / `after_draw_game_card`、`before_draw_scavenge_card` / `on_draw_scavenge_card` / `after_draw_scavenge_card`、`before_draw_monster_card` / `on_draw_monster_card` / `after_draw_monster_card`、`before_monster_enter_zone` / `on_monster_enter_zone` / `after_monster_enter_zone`
- **使用卡牌类**：`before_use_card` / `on_use_card` / `after_use_card`
- **装备类**：`before_equip` / `on_equip` / `after_equip`、`before_unequip` / `on_unequip` / `after_unequip`、`before_consume_charge` / `on_consume_charge` / `after_consume_charge` / `on_charge_depleted`
- **检定类**：`before_sneak_judge` / `on_sneak_judge` / `after_sneak_judge`、`before_spawn_judge` / `on_spawn_judge` / `after_spawn_judge`
- **弃牌 / 销毁类**：`before_discard` / `on_discard` / `after_discard`、`before_remove_card` / `on_remove_card` / `after_remove_card`
- **游戏类**：`on_game_start` / `on_game_over`
- **地图类**：`before_destroy_block` / `on_destroy_block` / `after_destroy_block`、`on_objective_mark_triggered`

> EventBus 信号：`hp_recovered` / `healing_done` / `player_hunger_changed` / `hunger_reduced` / `player_died` / `player_moved` / `phase_changed` / `card_drawn` / `scavenge_drawn` / `monster_card_drawn` / `card_discarded` / `card_used` / `equipment_equipped` / `equipment_unequipped` / `charge_consumed` / `skill_used` / `sneak_judge_triggered` 等，详见 [System/EventBus.md](../System/EventBus.md)。

---

## 方法

### 一、状态管理

#### `recover(num, source=null)`

回复生命值（4 节点）。`source` 为治疗来源（默认 null 表示自行回复）；`source != self` 时额外发射 `healing_done` 信号。

流程：

1. `num <= 0` 直接 return
2. 构建 `EventSystem.create_recover_event(self, num)`
3. `before_recover`（不取消）
4. `on_recover`（技能可修改 `event["num"]`，如 surgeon 手术刀·回复、手套：`num += 1`）
5. `EventSystem.is_cancelled(event)` 为 true 时 return
6. 系统加血：`event["num"]` 受 `max_hp - hp` 上限约束，调用 `add_hp(event["num"])`
7. 实际回复量 > 0 时输出日志、发射 `hp_recovered` 信号；`source != self` 时再发射 `healing_done(source, self, actual)`，否则发射 `healing_done(self, self, actual)`
8. `after_recover`

> 与 `add_hp(n)` 的区别：`add_hp` 为底层原子方法，直接修改生命值，不触发钩子且不受最大值约束；`recover` 走完整 4 节点流程。

#### `increase_hunger(num)`

增加饥饿值。饥饿值达到 6 后翻面角色卡并叠加 `hunger_damage_level` 标记。饥饿伤害为无来源伤害（source=null），由 damage 流程跳过 source 侧钩子。

流程（每点 hunger 迭代）：

1. `num <= 0` 直接 return；记录 `old_hunger`，输出"增加了 X 点饥饿值"日志
2. 循环 `num` 次：
   - `hunger < 6`：`hunger += 1`；若刚到 6，翻面角色卡（若仍正面）并 `add_mark("hunger_damage_level", 1)`
   - `hunger == 6`：翻面角色卡（若仍正面）并 `add_mark("hunger_damage_level", 1)`
   - 若 `count_mark("hunger_damage_level") > 0`，按等级触发伤害：
     - 等级 1 → `damage(2, null, "hunger")`
     - 等级 2 → `damage(4, null, "hunger")`
     - 等级 3 → `damage(6, null, "hunger")`
     - 等级 4 → `damage(8, null, "hunger")`
     - 等级 ≥ 5 → 输出"被饿死了"日志，`damage(max_hp, null, "hunger")`
3. 发射 EventBus `player_hunger_changed(self, old_hunger, hunger)` 信号

#### `decrease_hunger(num)`

减少饥饿值。最低降至 1，减少后清除 `hunger_damage_level` 标记并恢复角色卡正面。

流程：

1. `num <= 0` 直接 return
2. `max_reduce = hunger - 1`；`num > max_reduce` 时截断；截断后 `num <= 0` 时 return
3. `hunger -= num`，输出"减少了 X 点饥饿值"日志
4. 若 `count_mark("hunger_damage_level") > 0`：`remove_mark("hunger_damage_level")`
5. 若角色卡非正面：`role_card.flip()`
6. 发射 `hunger_reduced(self, num)` 信号

#### `poison()`

中毒结算。在玩家回合「中毒结算」阶段调用。中毒伤害为无来源伤害。

流程：若 `count_mark("poison") > 0`，`num = count_mark("poison")`，`damage(num, null, "poison")`。

---

### 二、抓牌流程

#### `draw(n)`

从求生者游戏牌堆抓 n 张牌（4 节点）。

流程：

1. `n <= 0` 直接 return
2. 构建 `EventSystem.create_draw_game_card_event(self, n)`
3. `before_draw_game_card`（取消点）
4. `on_draw_game_card`（取消点）
5. 逐张抓取（共 `event["num"]` 张）：
   - `game_deck` 为空 → 调用 `death(null)` 并 return（玩家死亡）
   - `card = game_deck.draw()`；`hand.append(card)`；发射 `card_drawn(self, card)` 信号；`event["cards"].append(card)`
6. 批量输出抓牌日志（"抓取了游戏牌 X, Y, ..."）
7. `after_draw_game_card`

#### `gain(card)`

将卡牌加入手牌区（content 代码调用入口）。

#### `draw_scavenge(n, pile)`

从指定拾荒牌堆抓 n 张牌（4 节点）。

流程：

1. `n <= 0` 直接 return
2. 构建 `EventSystem.create_draw_scavenge_event(self, pile, n)`
3. `before_draw_scavenge_card`（取消点）
4. 逐张抓取（共 `event["num"]` 张）：`pile` 为空时 break；`card = pile.draw()`；调用 `draw_scavenge_card(card, pile, event)` 处理单张
5. `after_draw_scavenge_card`

#### `draw_scavenge_card(card, pile, event)`

处理单张拾荒牌的抓取流程（加入手牌、日志、信号、触发抓取效果）。

流程：

1. `hand.append(card)`
2. 按 `pile` 匹配 `Game.red_scavenge_pile` / `green_scavenge_pile` / `blue_scavenge_pile`，输出"从 X 拾荒牌堆中抓取了拾荒牌 Y"日志
3. 发射 `scavenge_drawn(self, card)` 信号
4. `event["cards"].append(card)`；`event["card"] = card`
5. 收集卡上 `forced == true` 且 `matches_trigger("on_draw_scavenge_card")` 的技能，调用 `trigger_only("on_draw_scavenge_card", event, mounted_skills)`（避免已装备同名卡重复触发）

#### `draw_monster(n)`

从怪物牌堆抓 n 张怪物卡（7 节点 / 每张内部 6 子节点 a-f）。

流程：

1. `n <= 0` 直接 return
2. 构建 `EventSystem.create_draw_monster_event(self, n)`
3. `before_draw_monster_card`（取消点）
4. 逐张抓取（共 `event["num"]` 张）：
   - a. 牌堆空时重洗怪物弃牌堆；重洗后仍空 → `Game.game_over("lose")` 并 return
   - 抓取 `card = Game.monster_pile.draw()`；输出"抓取了怪物牌 X"日志；发射 `monster_card_drawn(self, card)` 信号
   - b. `on_draw_monster_card`（每张触发）
   - c. `before_monster_enter_zone`（每张触发）
   - d. 实体化：`monster = card.instantiate(self)`（设置纠缠对象、初始化生命值，详见 [MonsterCard.instantiate](Card.md#monstercard-怪物卡)）
   - e. `monster_zone.append(monster)`；输出"X 纠缠了 Y"日志；`on_monster_enter_zone`（player + monster 各触发一次）
   - f. `after_monster_enter_zone`（player + monster 各触发一次）
5. `after_draw_monster_card`（整体触发一次）

---

### 三、弃牌与销毁流程

#### `discard(target, position="", quantity=1, type="", silent=false)`

弃置卡牌到对应弃牌堆（3 节点）。

**参数**：

- `target`：可为 `Card` / `Equipment` / `Array` / `String`（卡牌名）
- `position`：区域名（`""` / `"hand"` / `"equipment"`）
- `quantity`：数量
- `type`：按 `card_type` 过滤（非空时按类型弃置）
- `silent`：静默弃置不输出"弃置了 X"日志（默认 false）。`use_card` 行动牌弃置时传 `true`

**流程**：

1. 解析待弃置卡牌列表 `cards_to_discard`：
   - `type != ""`：从 `get_cards(position)` 中筛选 `card.card_type == type`
   - `target is Array`：直接复制
   - `target is Equipment`：包装为单元素列表
   - `target is Card`：包装为单元素列表
   - 其他：按 `get_cards(position, target, quantity)` 查询
2. 列表为空时 return
3. 构建 `EventSystem.create_discard_event(self, cards_to_discard, ...)` 事件
4. `before_discard`（取消点）
5. 逐张弃置：
   - 解析装备实体 `entity = _resolve_equipment_entity(card)`
   - **装备区实体命中**：调用内部 `_unequip(entity)`（**不触发离开装备区 trigger**），来源卡 `src_card = entity.equipment_card` 入对应弃牌堆（`source == "scavenge"` → `Game.scavenge_discard_pile`，否则 → `game_discard_pile`）；非 silent 时输出日志；发射 `card_discarded(self, src_card)` 信号
   - **手牌卡**：`event["card"] = card`；`_remove_card_from_zone(card)`；按 `source` 入对应弃牌堆；非 silent 时输出日志；发射 `card_discarded(self, card)` 信号
   - `on_discard`（每张触发）
6. `after_discard`

> **偏差修正**：
> - discard 签名补 `silent` 参数（静默弃置不输出日志）
> - **discard 装备区处理走内部 `_unequip`（私有方法，不触发离开装备区 trigger）**，与外部 `unequip` 公开方法（3 节点 + trigger）不同
> - 弃牌堆永远收来源 `EquipmentCard`，不收 Equipment 实体

#### `remove_card(target, position="", quantity=1)`

销毁卡牌（移出游戏，3 节点）。

流程：

1. 解析待销毁卡牌列表（同 discard 的解析逻辑）
2. 构建 event（`card=null, cards=[], num=...`）
3. `before_remove_card`（取消点）
4. 逐张销毁（不入弃牌堆）：
   - 解析装备实体；`src_card = entity.equipment_card if entity != null else card`
   - `event["card"] = src_card`；`event["cards"].append(src_card)`
   - `_remove_card_from_zone(card)`
   - `Game.remove_card(src_card)`
   - `on_remove_card`（每张触发）
5. `after_remove_card`

---

### 四、移动流程

#### `move_to(target) -> bool`

底层移动函数（11 节点，不扣行动次数）。返回是否移动成功。

**事件钩子顺序**：

| 节点 | trigger / 操作 | 说明 |
|------|---------------|------|
| 1 | `before_leave_block` | 离开地块前 |
| 2 | `on_leave_block` | 离开地块时 |
| 3 | `after_leave_block` | 离开地块后 |
| 4 | `target._acquire_skills_for_player(self)` | 获取目标地块技能（先获取，再准入检定） |
| 5 | `before_enter_block`（取消点） | 进入地块前。取消时回滚：`target._clear_skills_for_player(self)`，返回 false |
| 6 | `current_block = target` + 日志 + `player_moved` 信号 + `add_mark("moved_this_turn")` | 移动时（坐标变更） |
| 7 | `source._clear_skills_for_player(self)` | 清理旧地块技能（移动成功后才清理） |
| 8 | `on_enter_block` | 进入地块时（一次性效果） |
| 8.5 | `current_block != target` 时 return false | on_enter_block 期间玩家被移动到其他地块，跳过后续 |
| 9 | `target.reveal(true, self)` + `after_enter_block` | 进入地块后（展示未展示的地块） |
| 10 | 潜行检定（地块有怪物标记时） | `sneak_judge()` 失败 → `remove_monster_mark(num)` + `draw_monster(num)` |
| 11 | `target.trigger_objective_marks(self)` | 触发目标标记 |

---

### 五、检定系统

#### `judge() -> int`

基础检定：投两颗骰子，返回点数之和（`randi_range(1, 6) * 2`）。

#### `sneak_judge(block_param=null) -> bool`

潜行检定（4 节点）。

流程：

1. `block = block_param if block_param != null else current_block`
2. 发射 `EventBus.sneak_judge_triggered(self, block)` 信号
3. 计算 `sneak_value = get_sneak() - (count_monster() + count_monster_mark())`（地块为 null 时怪物数与标记数均为 0）
4. 构建 `EventSystem.create_sneak_judge_event(self, sneak_value, block)`
5. `before_sneak_judge`
6. 系统投骰（若 `event["skip_judge"] == false`）：`dice_value = judge()`；输出"执行了潜行检定，点数为 X"日志；`event["result"] = {"value": dice_value, "success": dice_value <= sneak_value}`
7. `on_sneak_judge`
8. `after_sneak_judge`
9. 输出"潜行成功 / 失败"日志；返回 `event["result"]["success"]`

#### `monster_spawn_judge()`

怪物出生检定（5 节点）。

流程：

1. 构建 `EventSystem.create_spawn_judge_event(self)`
2. `before_spawn_judge`
3. 系统投骰（若 `event["skip_judge"] == false`）：`dice_value = judge()`；输出"执行了怪物生成，点数为 X"日志；`event["result"] = {"value": dice_value, "success": true}`
4. `on_spawn_judge`
5. `after_spawn_judge`
6. 结果处理：遍历 `Game.map_area` 中已展示地块，匹配 `get_spawn_value() == dice` 的地块：
   - `count_monster_mark() < 3` → `add_monster_mark(1)`
   - `count_monster_mark() == 3 and has_player()` → 对地块上每位存活玩家 `p.draw_monster(1)`

---

### 六、死亡流程

#### `death(source)`

玩家死亡流程（3 节点 + 回收）。触发场景：`hp <= 0` 或抓牌时牌堆空。

流程：

1. `hp = 0`；输出"死亡了"日志；发射 `EventBus.player_died(self, source)` 信号
2. 构建 `EventSystem.create_player_death_event(self, source)`
3. `before_player_death`
4. `on_player_death`
5. `after_player_death` 节点回收：
   - 3a. 怪物区怪物 → 弃牌堆；等量怪物标记（最多 3 个）放回 `current_block`
   - 3b. 所有求生者游戏牌（手牌 + 装备 + 牌堆 + 弃牌堆，装备追加来源 `equipment_card`）→ `Game.remove_card(c)` 移出游戏
   - 3c. 拾荒卡按颜色洗回对应拾荒牌堆：装备区解析来源 `ScavengeCard`，按 `get_color()` 入 `Game.get_scavenge_pile(color)`；最后 shuffle 三个拾荒牌堆
6. 检查游戏结束：`Game.coop_death_mode` 为 true → `Game.game_over("lose")`；`Game.all_players_dead()` → `Game.game_over("lose")`

---

### 七、使用卡牌流程

#### `use_card(card) -> bool`

从手牌中使用一张卡牌（4 节点）。

流程：

1. `action_count < 1` 时返回 false
2. 构建 event（`player, card, target=null, targets=[], cards=[]`）
3. `before_use_card`（取消点）
4. `on_use_card`（取消点）
5. 系统结算：消耗 1 点行动次数（**defer_action_cost 延迟消耗机制**：若 `card.card_type != "equipment"` 且存在 `active == "action"` 且 `defer_action_cost == true` 的技能，则延迟到 content 中消耗，本节点不消耗）
6. 按卡牌类型分流：
   - **装备牌**（`card_type == "equipment"`）：输出"使用了 X"日志；调用 `equip(card)`
   - **行动牌**：遍历卡牌所有 `active == "action"` 技能：
     - `execute_filter(self, event)` 不通过 → 跳过
     - `select_target > 0`：`choose_target(select_n, skill)` 选择目标（玩家取消则跳过该技能）；`event["target"] = targets[0]`，`event["targets"] = targets`
     - `select_target == -1`：自动选取全部合法目标
     - `select_card > 0`：`choose_card(select_card_n, "hand", skill.filter_card)` 选牌
     - 输出使用日志（有非自身目标时输出"对 X 使用了 Y"，否则输出"使用了 Y"）
     - `await skill.execute_content(self, event)` 执行 content
     - **defer 检查**：若延迟消耗且 `EventSystem.is_cancelled(event)` → 牌退回手牌，不弃牌，不触发 `after_use_card`，返回 false
     - 标记 `skill_executed = true`
   - 所有技能 filter 不通过时仍输出"使用了 X"日志
   - 弃牌：`await discard(card, "", 1, "", true)`（**静默弃置不输出"弃置了"日志**）
7. `after_use_card`；发射 `EventBus.card_used(self, card)` 信号；返回 true

> **defer_action_cost 延迟消耗机制**：技能声明 `defer_action_cost = true` 时，使用卡牌的系统结算节点（步骤 5）不消耗行动次数，改由技能 content 内自行消耗。若 content 中通过 `EventSystem.cancel(event)` 取消，则牌退回手牌、不弃牌、不触发 `after_use_card`。

#### `is_card_usable(card) -> bool`

判断手牌当前是否可被玩家使用（供 UI 确认按钮置灰）。装备牌直接可装备（无 filter 门槛）；行动牌需至少一个 `active == "action"` 技能 filter 通过，且若 `select_target > 0` 需存在合法候选目标。

---

### 八、装备流程

#### `equip(card) -> bool` 装备

装备进入装备区（3 节点 + 预校验）。

流程：

1. 构建 `EventSystem.create_equip_event(self, card)`
2. `before_equip`（取消点）
3. 系统预校验：
   - a. **同名装备校验**：弃置装备区中的同名装备（装备区持 Equipment 实体）。**燃料例外**：`card.english_name == "fuel"` 时跳过同名校验，允许多张燃料共存
   - b. **装备栏容量校验**：若 `role_card != null`，计算新装备 `size` 与现有装备总 `size` 之和；超出 `role_card.equipment_capacity` 时让玩家选装备弃置，弃置后仍超出或玩家取消 → `EventSystem.cancel(event)` 返回 false
4. `on_equip`：
   - `hand.erase(card)`
   - **实体化**：`card is EquipmentCard and card.has_method("instantiate")` 时 `entity = card.instantiate(self)`，`equipment_zone.append(entity)`；否则保底直接 `equipment_zone.append(card)`
   - **技能挂载**：从实体（或卡牌）`get_all_skills()` 挂载到 Player 身上
5. `after_equip`；输出"装备了 X"日志；发射 `EventBus.equipment_equipped(self, entity if entity != null else card)` 信号；返回 true

> **偏差修正**：
> - **equip 走 `card.instantiate(self)` 实体化**：创建 Equipment 实体加入 `equipment_zone`，技能从实体挂载到 Player
> - **燃料例外**：`english_name == "fuel"` 跳过同名校验，允许多张燃料共存

#### `unequip(card) -> bool` 卸下

装备离开装备区（3 节点）。

流程：

1. 解析装备实体 `entity = _resolve_equipment_entity(card)`；为 null 时返回 false
2. `src_card = entity.equipment_card`
3. 构建 `EventSystem.create_equip_event(self, src_card)`
4. `before_unequip`（取消点）
5. `on_unequip`：`equipment_zone.erase(entity)`；`entity.in_equipment_area = false`
6. 移除装备技能（在 `on_unequip` 之后，确保 `on_unequip` 触发器仍可见装备技能）
7. `after_unequip`；输出"卸下了 X"日志；发射 `EventBus.equipment_unequipped(self, src_card)` 信号；返回 true

#### `increase_equipment_slot(n)` / `decrease_equipment_slot(n)`

增减装备栏容量上限 n 格（不低于 0）。容量由 `RoleCard.equipment_capacity` 约束。

---

### 九、填充物流程

#### `consume_charge(equipment, num) -> bool` 消耗填充物

装备填充物消耗（4 节点 + 耗尽衍生）。`equipment` 可为 `Equipment` 实体或 `EquipmentCard`（实体方法委托到来源卡）。钩子 / 事件载荷收到的永远是来源 `EquipmentCard`（`entity.equipment_card`）。

流程：

1. 前置校验：`equipment` 无 `get_charge` 方法或 `get_charge() < num` 时返回 false
2. 解析来源卡：`equipment is Equipment and equipment.equipment_card != null` 时 `src_card = equipment.equipment_card`，否则 `src_card = equipment`
3. 构建 `EventSystem.create_consume_charge_event(self, src_card, num)`
4. `before_consume_charge`（取消点）
5. `on_consume_charge`（取消点）
6. 系统扣减：`equipment.consume_charge(event["num"])`（实体方法委托到来源卡）；输出"对 X 消耗了 Y 发填充物"日志
7. `after_consume_charge`；发射 `EventBus.charge_consumed(self, src_card, num)` 信号
8. 衍生：`equipment.get_charge() <= 0` 时 `on_charge_depleted`

#### `add_charge_to(equipment, amount, type)` / `fill_charge_to(equipment)`

为装备填装 / 填满填充物并输出日志。

#### `_format_target_name(target) -> String`（内部）

格式化目标名称为带颜色的字符串（怪物 / 玩家 / 地块 / 卡牌分别上色）。

---

### 十、回合流程

#### `start_turn()`

玩家回合完整流程（21 节点，节点 21 由状态机执行）。

| 节点 | 操作 / trigger | in_phase |
|------|---------------|----------|
| 1 | 进入玩家回合（非钩子）：`action_count = max_action_count`；`clear_turn_marks()`；重置主动技能使用次数 | `turn_start` |
| 2 | `before_turn_start` | — |
| 3 | `on_turn_start` | — |
| 4 | `before_monster_spawn` | `monster_spawn` |
| 5 | `on_monster_spawn` + `monster_spawn_judge()` | — |
| 6 | `before_draw_phase` | `draw` |
| 7 | 摸牌阶段：`draw(1)`；不存活时 return | — |
| 8 | 行动阶段前（含潜行检定）：`phase_changed` 信号；地块有怪物标记时 `sneak_judge()` 失败 → 移除标记 + `draw_monster(num)`；`before_action_phase` | `action` |
| 9 | 行动阶段：`wait_player_action()` | — |
| 10 | `before_action_phase_end` | — |
| 11 | `on_action_phase_end` | — |
| 12 | `before_hunger_settlement` | `hunger` |
| 13 | `on_hunger_settlement` + `increase_hunger(1)`；不存活时 return | — |
| 14 | `before_poison_settlement` | `poison` |
| 15 | `on_poison_settlement` + `poison()`；不存活时 return | — |
| 16 | `before_zone_monster_act` | `monster_action` |
| 17 | `on_zone_monster_act` + 遍历 `monster_zone` 调用 `monster.act()`；不存活时 return | — |
| 18 | `before_turn_end` | `turn_end` |
| 19 | `on_turn_end` | — |
| 20 | 退出玩家回合 | `idle` |
| 21 | 由状态机执行（切换到下一玩家） | — |

---

### 十一、迷你回合流程

#### `execute_action_immediately(num=1)`

立即执行一个行动（仅含行动阶段）。保存原 `in_phase`，切换到 `"action"`，设置 `action_count = num`，调用 `wait_player_action()`，结束后恢复原 `in_phase`。

---

### 十二、底层接口与工具方法

#### 生命值 / 饥饿值 / 潜行值

| 方法 | 说明 |
|------|------|
| `get_hp() -> int` / `get_max_hp() -> int` | 返回当前 / 最大生命值 |
| `reduce_hp(n)` / `add_hp(n)` | 减少（不低于 0）/ 增加（不超过 `max_hp`）生命值 |
| `is_player() -> bool` | 恒返回 true |
| `is_alive() -> bool` | `hp > 0` |
| `get_hunger() -> int` | 返回饥饿值 |
| `add_hunger(n)` / `reduce_hunger(n)` | 增加 / 减少饥饿值（`reduce_hunger` 不低于 1，发射 `hunger_reduced` 信号） |
| `get_sneak() -> int` | 返回潜行值（含饥饿状态修正）：`stealth + role_card.get_sneak()` |
| `add_sneak(n)` / `reduce_sneak(n)` | 增加 / 减少潜行值（不低于 0） |

#### 行动管理

| 方法 | 说明 |
|------|------|
| `get_action_count() -> int` / `set_action_count(n)` | 读取 / 设置行动次数 |
| `reduce_action_count(n)` | 扣减行动次数（不低于 0） |
| `consume_action(n)` | 扣除 n 点行动次数（content 代码字符串统一调用名，等价 `reduce_action_count`），输出"消耗了 X 点行动点数"日志 |
| `add_action(n)` | 增加 n 点行动次数（不低于 0），输出"增加了 X 点行动点数"日志（野地夹克使用） |

#### 区域管理

| 方法 | 说明 |
|------|------|
| `get_current_block() -> MapBlock` | 返回当前地块 |
| `get_role_card() -> RoleCard` | 返回角色卡 |
| `get_cards(position="", name="", quantity=0, source="") -> Array` | 按条件查询玩家区域中的牌。`position` 为 `""` / `"hand"` / `"equipment"`；`name` 同时匹配 `card_name` 与 `english_name` |
| `get_all_game_cards() -> Array` | 返回所有求生者游戏牌（手牌 + 装备来源卡 + 牌堆 + 弃牌堆） |
| `_remove_card_from_zone(card)` | 从所在区域移除一张牌（内部方法）。装备区持 Equipment 实体，需解析实体后 erase |
| `_unequip(target)` | 内部卸下装备（不触发钩子，供 discard 流程复用）。解析实体后 erase，置 `in_equipment_area = false`，移除技能 |
| `_resolve_equipment_entity(target) -> Equipment` | 解析装备实体：target 为 Equipment 时返回自身；为 EquipmentCard 时在装备区查找对应实体；为其他对象 / 字符串时按 `card_name` 匹配 |
| `has_non_boss_monster() -> bool` | 玩家面前是否有非首领怪物 |

#### 标记管理

| 方法 | 说明 |
|------|------|
| `count_mark(name) -> int` | 返回标记计数（不存在返回 0） |
| `add_mark(name, quantity=1)` | 增加标记 |
| `remove_mark(name)` | 移除标记 |
| `has_mark(name) -> bool` | 是否持有标记 |
| `has_mark_skill(name) -> bool` | 等价 `has_mark` |
| `add_mark_skill(name, n=1, expire_trigger="")` | 添加标记技能，在 `expire_trigger` 触发后自动移除标记（创建内部 Skill 监听 trigger） |
| `add_poison(n)` | 增加 n 层中毒标记 |
| `clear_turn_marks()` | 清除持续到回合结束的临时标记（`moved_this_turn` / `shelter_disabled`） |

#### 装备管理

| 方法 | 说明 |
|------|------|
| `has_equipment(name) -> bool` | 是否持有指定装备（匹配 `card_name` 或 `english_name`） |
| `get_equipment(name) -> Equipment` | 按名获取装备实体 |
| `get_charge_count(equipment_name) -> int` | 查询指定装备的当前填充物数量（不存在返回 0） |
| `has_card(type="") -> bool` | 是否持有指定类型的牌（无参时判断是否有任意牌） |

#### 牌堆查询

| 方法 | 说明 |
|------|------|
| `get_pile(name) -> Variant` | 按名称获取玩家牌堆。`"deck"` → `game_deck`；`"hand"` → `hand`；`"equipment"` → `equipment_zone`；`"discard"` → `game_discard_pile` |
| `get_discard_pile() -> Pile` | 返回游戏牌弃牌堆（content 代码调用入口） |
| `add_temp_skill(skill_id, expire_trigger)` | 添加临时技能，在 `expire_trigger` 触发后自动移除。`skill_id` 为预定义 ID（如 `"energy_drink_satiety"`） |

#### 选择器（玩家交互）

> 全部委托 `input` 接口实现。

| 方法 | 说明 |
|------|------|
| `choose(options, prompt="") -> Variant` | 通用选择器 |
| `confirm(message) -> bool` | 确认对话框 |
| `choose_card(n, param="hand", filter=null) -> Array` | 选择卡牌。`param` 为 String 时按 position 查询；为 Array 时直接作为候选列表 |
| `choose_target(n, skill=null) -> Array` | 选择目标。`n` 为数量（-1 表示全部），`skill` 含 `target_type` / `filter_target` 等 |
| `choose_map_block(param, prompt="") -> Variant` | 选择目标地块。`param` 为 Array 时直接作为候选；为 Dictionary 时按 `filter_target_range` 与 `filter_target` 构建候选 |
| `choose_block_inline(valid_blocks, prompt="", count=1) -> Array` | 内联选取地块（地图内联高亮，非弹窗） |
| `show_card(card, target)` | 展示卡牌 |
| `set_prompt(text)` | 设置 prompt 区文本 |
| `wait_redraw_decision() -> bool` | 等待玩家重调决策（第零轮专用）。返回 true 表示确定重调，false 表示取消 |
| `wait_player_action()` | 行动阶段循环：等待玩家操作（使用卡牌 / 使用主动技能 / 结束回合 / 移动 / 牌堆抓牌） |
| `_execute_pile_draw(pile_key)` | 执行牌堆抓牌动作（UI 牌堆点击触发）。`pile_key` 为 `"game_deck"` / `"red_scavenge"` / `"green_scavenge"` / `"blue_scavenge"` |
| `end_phase(phase)` | 设置标记让 `wait_player_action` 循环跳出 |
| `choose_to_discard(n, type="")` | 选择并弃置 n 张牌（可选类型过滤） |

#### `use_active_skill(skill)`

使用主动技能。处理目标选择和卡牌选择，然后执行 content。

流程：

1. 校验 `skill` 有效、`active` 非空、`is_usable()` 通过
2. 构建 event
3. `execute_filter(self, event)` 不通过 → return
4. 按 `target_type` 分支选择目标：
   - `"block"`：`current_block.get_blocks_in_range(filter_target_range)` 构建 candidates，经 `_filter_targets` 过滤，`choose_map_block(candidates)` 选择
   - `"entity"`：`current_block.get_players_in_range(filter_target_range)` 构建 candidates，经 `_filter_targets` 过滤，`choose(candidates)` 选择
   - `"pile"`：`current_block.scavenge_colors` 作为 candidates，`choose(colors)` 选择
   - `"equipment"`：`equipment_zone.duplicate()` 作为 candidates，经 `_filter_targets` 过滤，`choose(candidates)` 选择
   - 其他（`target_type` 为空）：按 `select_target` 选择目标（`> 0` 选 N 个；`== -1` 选全部合法目标）
5. `select_card > 0` 时 `choose_card(select_card_n, skill.position, skill.filter_card)` 选牌
6. 输出使用日志（有 target 时输出"对 X 使用了 Y"，无 target 时输出"使用了 Y"）
7. `await skill.execute_content(self, event)`
8. 取消检查：content 中通过 `EventSystem.cancel(event)` 取消时不记录使用，return
9. `skill.record_use()`；发射 `EventBus.skill_used(self, skill)` 信号

#### `_filter_targets(skill, candidates, event) -> Array`（内部）

用 `skill.filter_target` 过滤候选目标列表。`filter_target` 为空 Callable 时全保留。

#### `get_skill_valid_targets(skill) -> Array`

构建技能的合法目标候选列表（按 `target_type` 与 `filter_target_range` 构建并经 `_filter_targets` 过滤）。逻辑与 UI 层 `_on_choose_target_requested` 保持一致，供可用性判断复用。

#### `can_use_active_skill(skill) -> bool`

判断主动技能当前是否可使用（供 UI 确认按钮置灰判断）。依次检查：`active` 非空、`usable` 次数、`filter` 通过；若技能需要选目标则要求存在合法候选。

#### `get_number(key) -> int`

获取数值型状态。`"action_count"` → `action_count`；`"hp"` → `hp`；`"hunger"` → `hunger`；其他返回 0。

---

### 十三、技能辅助方法

#### `discard_non_boss_monster_to_mark()`

弃置面前的一张非首领怪物并替换为怪物标记。

流程：

1. 收集 `monster_zone` 中 `monster_level != "boss"` 的怪物作为候选
2. 候选为空时 return
3. `input.choose(candidates)` 选择怪物；为 null 时 return
4. `monster_zone.erase(monster)`；`Game.monster_discard_pile.add(monster.monster_card)`（来源卡入弃牌堆）
5. `current_block.add_monster_mark(1)`

> **注**：此为纯移除，**不**触发怪物死亡流程。

#### `pull_one_step(target)`

向玩家拉近一格不触发效果。

流程：取 `source_block = current_block`、`target_block = target.get_current_block()`，调用 `Game.get_step_toward(source_block, target_block)` 取得下一步地块，`current_block = next_block`。

#### `heal_all_status()`

治疗所有状态效果：移除 `poison` 与 `hunger_damage_level` 标记。

#### `play_card_immediately()`

立即打出一张牌（不消耗行动次数）。

流程：

1. `hand` 为空时 return
2. 保存原 `in_phase`，切换到 `"action"`
3. `input.choose_card(1, "hand")` 选牌；为空时恢复 `in_phase` 并 return
4. 装备牌：调用 `equip(card)`
5. 行动牌：`card.trigger("on_use_card", event)` 后 `discard(card)`
6. 恢复原 `in_phase`

---

### 十四、任务系统方法

#### `collect_item(card_name, quantity)`

收集物品（直接生成拾荒卡加入手牌区）。循环 `quantity` 次调用 `Game.create_scavenge_card(card_name)` 加入 `hand`；输出"获得了 X 张 Y"日志。

#### `has_item(card_name) -> bool`

判断是否持有指定名字的物品（手牌 + 装备区，匹配 `card_name`）。

#### `draw_boss_card()`

从怪物牌堆中筛选首领卡抽取。

流程：

1. 从 `Game.monster_pile.cards` 中查找 `monster_level == "boss"` 的卡，找到则 `pop_at` 取出
2. 牌堆中没有时从 `Game.monster_discard_pile.cards` 中查找
3. 都没有时输出"牌堆与弃牌堆中均无首领卡！"日志并 return
4. 放到怪物牌堆顶部 `push_front(boss_card)`，调用 `draw_monster(1)` 复用抓怪物流程

#### `rescue_scientist_option()`

获得解救科学家的选项。

流程：

1. `input.choose(["花费 1 行动解救科学家", "不解救"])`，选"不解救"时输出日志并 return
2. `action_count < 1` 时输出"行动次数不足"日志并 return
3. 从 `Game.mission_config.mission_state["scientist_equipment"]` 取科学家装备；为 null 时输出"科学家已被解救！"并 return
4. `reduce_action_count(1)`；`equip(scientist)`；清空 `scientist_equipment`；置 `scientist_rescued = true`；输出"解救了科学家，装备到面前！"日志

#### `record_scientist_info()`

记录科学家信息：置 `Game.mission_config.mission_state["scientist_info_recorded"] = true`，输出日志。

---

## 通用行动技能

> 通用行动技能（如移动、抓牌、拾荒等基础行动）的定义详见 [Common/Skill.md](../Common/Skill.md) 与 [02_开局与流程.md](../../GameInstructions/02_开局与流程.md)。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Entity](../Core/Entity.md) | 继承。复用 trigger / damage / death 抽象方法 |
| [Equipment](Equipment.md) | 装备区持 Equipment 实体；填充物接口委托来源卡 |
| [EquipmentCard](Card.md#equipmentcard-装备牌) | 装备牌实体化来源；弃置 / 回收时入弃牌堆 |
| [Monster](Monster.md) | 玩家怪物区持 Monster 实例；玩家可攻击怪物；怪物可攻击玩家 |
| [MapBlock](MapBlock.md) | 玩家位于地块上；地块技能挂载到 Player；玩家移动触发地块钩子 |
| [Game](../Game/Game.md) | Game 持全局牌堆 / 玩家；承担状态机委托、地图构建、卡牌 / 玩家 / 目标查询 |
| [RoleCard](../Common/RoleCard.md) | 玩家角色卡；提供 `equipment_capacity` / `get_sneak()` 等 |
| [Pile](../Common/Pile.md) | `game_deck` / `game_discard_pile` 为 Pile 实例 |
| [Skill](../Common/Skill.md) | 装备 / 地块 / 角色固有技能遵循 Skill 结构 |
| [EventBus](../System/EventBus.md) | 发射 `hp_recovered` / `healing_done` / `player_hunger_changed` / `hunger_reduced` / `player_died` / `player_moved` / `phase_changed` / `card_drawn` / `scavenge_drawn` / `monster_card_drawn` / `card_discarded` / `card_used` / `equipment_equipped` / `equipment_unequipped` / `charge_consumed` / `skill_used` / `sneak_judge_triggered` 等信号 |
