# GameStateSerializer 对局快照序列化

> 以 `MxApoc_GDScript/src/net/game_state_serializer.gd` 为准（约 1070 行）。
> `class_name GameStateSerializer`，`extends RefCounted`，非 autoload，**全部方法为 static**，纯静态工具类。
> 职责：**将房主运行时状态转换为可传输快照**。这是合作视图版本：所有玩家手牌都包含在快照中。序列化格式为纯 `Dictionary`（由 `NetSession` 封包传输）。

---

## 一、职责

- `snapshot(game)`：权威 `Game` 全量序列化为可传输 Dictionary。
- `apply(game, snapshot, ctx)`：按 `net_id` 把快照**原位应用**到显示 Game（房主自己的显示 Game 或客机 ViewGame）。
- `find_by_net_id(game, net_id)`：供 `NetInputCodec` 定位活实体。
- `apply_display_limited_action(player, remaining_actions)`：客机显示层迷你回合预算。

跨快照稳定性由调用方持有的 `ctx: Dictionary[int, Object]`（net_id → 实例）保证，`_prune_ctx` 防膨胀。

---

## 二、对外公开方法

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `snapshot` | `static func snapshot(game: Variant) -> Dictionary` | **序列化入口**：权威 `Game` 全量快照 |
| `apply` | `static func apply(game: Variant, snapshot: Dictionary, ctx: Dictionary) -> void` | **反序列化入口**：原位应用快照到 `game` |
| `find_by_net_id` | `static func find_by_net_id(game: Variant, net_id: int) -> Variant` | 按 net_id 线性查找实体（玩家/手牌/装备/怪物/牌堆/地块） |
| `apply_display_limited_action` | `static func apply_display_limited_action(player: Variant, remaining_actions: int) -> void` | 迷你回合预算写入 `_operation_context_stack`（`remaining_actions < 0` 清除；不得写正式 `action_count`） |

---

## 三、快照结构与格式

### 3.1 根结构（`snapshot()`）

```
{
  "match_id": String, "server_sequence": int, "mission_id": int,
  "players": Array[玩家行], "map": Array[地块行],
  "piles": Dictionary, "state_machine": Dictionary,
  "mission_state": Dictionary, "stats": Dictionary
}
```

### 3.2 玩家行

```
{ "net_id", "seat_number", "player_name", "hp", "max_hp", "hunger",
  "in_phase", "action_count", "max_action_count", "limited_remaining_actions",
  "is_ai", "alive", "current_block": {x,y},
  "hand": Array[卡牌行], "equipment": Array[装备行], "discard": Array[卡牌行],
  "game_deck": int, "monsters": Array[怪物行], "is_front_side": bool, "marks": Array }
```

### 3.3 卡牌行

`{ "net_id", "english_name", "card_name", "card_type", "source" }` + 可选 `card_subtype / size / range / color / charge_type / charge_max / charge_current / weapon`。

### 3.4 装备行

基础即卡牌行；若是 `Equipment` 实例，`net_id` 改为装备实体 net_id，并追加 `equipment_card`（嵌套源卡牌行）与 `charge_current/charge_max/charge_type/size/range/weapon`。

### 3.5 怪物行

`{ "net_id", "english_name", "monster_name", "card_name", "monster_type", "monster_level", "hp", "max_hp", "damage_value", "range", "stunned" }`。

### 3.6 地块行

`{ "net_id", "block_name", "x", "y", "state", "revealed", "monster_marks", "objective_marks": Array, "scavenge_colors": Array[String], "monster_spawn_value" }`。

### 3.7 piles

`{ "monster", "monster_discard", "red", "green", "blue", "scavenge_discard" }`（均只传**大小**）+ `"scavenge_discard_cards": Array[卡牌行]`（该堆独有传完整内容）。

### 3.8 state_machine

`{ "state", "current_player_seat", "last_player_seat", "turn_number", "game_result" }`（座位引用用编号，apply 时反查对象）。

---

## 四、反序列化流程（`apply` 执行顺序）

1. 空保护（`game == null` / `snapshot.is_empty()` 直接返回）。
2. `_ensure_mission`：按 `mission_id` 重建任务配置（`DataManager.get_mission` + `MissionConfig` + 挂组件）。
3. 记录旧位置 + `_apply_map` 重建地图（`previous_blocks` / `rebuilt_blocks`）。
4. 玩家循环：`_ensure_player` 取/建玩家 → 恢复 hp/hunger/phase/action_count、`hand`、`discard`、`equipment`、`game_deck` 大小、`monster_zone`、`current_block`、角色正背面、`marks`、显示层 `limited_action`。
5. 状态机恢复：座位号反查对象；`GAME_OVER` 时写 `game.game_over_called` 与 `game.game_result`。
6. 全局牌堆 + scavenge 弃牌堆、任务状态、统计。
7. `_sync_location_skills`：玩家换块/块技能重建时卸载旧技能、挂载新技能。
8. `_prune_ctx` 清理快照中不存在的 net_id。

**关键策略**：
- 引用不直接传对象：座位用 `seat_number`、地块用 `{x,y}` 坐标，apply 时反查。
- 卡牌/怪物/装备重建均有 claimed 防重（`_take_unused_monster` 明确禁止有 net_id 时按名偷取）。
- ViewGame 与权威 Game 差异化：`_setup_mission_components_for_world` 只对权威 `Game` 全量挂组件，ViewGame 只挂行动组件，避免触发器误吃 EventBus。

---

## 五、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | 调用 `apply(ViewGame, snapshot, ctx)` 与 `snapshot(Game)` |
| [NetInputCodec](./NetInputCodec.md) | 建卡 `create_card_from_payload`、填怪 `apply_monster_payload`；反向用 `find_by_net_id` |
| [DataManager](../../Engineering/DataFormat.md) | `get_survivor` / `get_mission` / `get_map_block_def_by_name` |
| [RoomState](../System/RoomState.md) | 座位 survivor 数据 |
| [StatsTracker](../System/StatsTracker.md) | `to_network_dict` / `apply_network_snapshot` |
| [GameStateMachine](../Core/GameStateMachine.md) | 状态机状态与结果枚举 |
