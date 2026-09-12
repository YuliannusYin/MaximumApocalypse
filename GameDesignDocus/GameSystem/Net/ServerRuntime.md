# ServerRuntime 权威运行时

> 以 `MxApoc_GDScript/src/net/server_runtime.gd` 为准（约 496 行）。
> `extends Node`，无 `class_name`，非 autoload——由 `NetSession.ensure_server_runtime()` 动态 `new()` 并挂到 root，每局创建、局后销毁。
> 职责：**同进程权威运行时**。开局后持有原 ENet server；规则协程仍运行在房主，UI 不再用 `GUIPlayerInput` 驱动规则；把 EventBus 游戏事件中继为网络广播。

---

## 一、职责

`ServerRuntime` 是**权威游戏规则层**：

- 开局初始化（`NetId.reset`、随机播种、`Game.initialize_from_room_state`）。
- 为每个座位装配输入：真人 → `NetworkPlayerInput`，AI → `AIPlayerInput`。
- 处理掉线转 AI（`handoff_seats_to_ai`）与重连恢复真人输入（`restore_network_inputs`）。
- 等待真人 peer 绑定齐（`MATCH_READY_TIMEOUT_MS` 超时未到转 AI）。
- 把约 26 个 `EventBus` 信号中继为网络 `game_event` 广播。

`NetSession` 是传输/会话层，`ServerRuntime` 是规则层；两者经 `NetSession` 的广播/快照接口间接通信。

---

## 二、常量与预加载

| 常量 | 值 / 来源 | 用途 |
| --- | --- | --- |
| `ServerLifetime` | `preload` | 存活策略常量（`OWNER`/`PERSISTENT`） |
| `AIPlayerInputScript` | `preload` | AI 输入实现 |
| `NetworkPlayerInputScript` | `preload` | 真人网络输入实现 |
| `MATCH_READY_TIMEOUT_MS` | `NetRegistry`（`15 * 1000`） | 就绪等待超时 |

---

## 三、信号

| 信号 | 参数 | 发出时机 |
| --- | --- | --- |
| `match_prepared` | 无 | `prepare_from_room()` 完成对局初始化后 |
| `match_aborted` | `reason: String` | `abort_owner_loopback_failed()` 发 `"owner_loopback_timeout"` |

---

## 四、成员变量

| 变量 | 类型 | 用途 |
| --- | --- | --- |
| `lifetime` | `String`（`ServerLifetime.OWNER`） | 存活策略，当前仅 `"owner"` |
| `_active` | `bool` | 运行时激活标记 |
| `_network_inputs` | `Array` | 真人座位的 `NetworkPlayerInput` 列表 |
| `_expected_player_ids` | `Array` | 开局应到齐的真人玩家 ID |
| `_owner_player_id` | `String` | 房主玩家 ID |
| `_waiting_for_peers` | `bool` | 是否等待所有真人 peer 绑定 |
| `_game_prepared` | `bool` | 对局是否已准备好 |
| `_wait_started_ms` | `int` | 等待开始时刻 |
| `_visual_relays_connected` | `bool` | EventBus 视觉中继是否已连接 |
| `_last_monster_mark_counts` | `Dictionary` | 各地块怪物标记数快照（去重脉冲广播） |

---

## 五、方法定义

### 5.1 生命周期

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `is_active` | `is_active() -> bool` | 是否激活 |
| `is_game_prepared` | `is_game_prepared() -> bool` | 对局是否已准备好 |
| `begin_match_from_lobby` | `begin_match_from_lobby() -> void` | 大厅点开始：置 `_active/_waiting_for_peers`、登记应到真人、`registry.start_match()`、取房主、若房主未 live 绑定则 `clear_live_peer` |
| `wait_until_match_prepared` | `wait_until_match_prepared() -> bool` | 协程（`await get_tree().process_frame`），循环 `_poll_match_ready()` 直到 `_game_prepared` |
| `prepare_from_room` | `prepare_from_room() -> void` | **核心初始化**：`NetId.reset()` → `_seed_match()` → `Game.initialize_from_room_state()` → `_attach_authority_inputs()` → `_connect_visual_relays()` → 置 `_game_prepared=true` → 通知 `NetSession.request_state_snapshot()` → 发 `match_prepared` |
| `start_game` | `start_game() -> void` | 调 `Game.start_game()` |
| `abort_owner_loopback_failed` | `abort_owner_loopback_failed() -> void` | 房主环回失败终止：发 `match_aborted("owner_loopback_timeout")` + `NetSession.close_authority_room` |
| `stop` | `stop() -> void` | 停激活、清输入、断开中继、`queue_free()` |
| `_process` | `_process(_delta: float) -> void` | 等待期逐帧 `_poll_match_ready()` |

### 5.2 等待 / 就绪判定

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_poll_match_ready` | `_poll_match_ready() -> void` | 若 `_all_expected_bound()` 直接 `prepare_from_room()`；超时 15s 后房主未绑定 → abort，否则把未绑定真人 `convert_unbound_human_to_ai()` 后放行 |
| `_all_expected_bound` | `_all_expected_bound() -> bool` | 所有 `_expected_player_ids` 均 `is_player_live_bound()` |

### 5.3 权威输入绑定

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_attach_authority_inputs` | `_attach_authority_inputs() -> void` | 遍历 `Game.players`：AI 座位 → 挂 `AIPlayerInputScript`（`think_seconds=0.4`）；真人 → 挂 `NetworkPlayerInputScript`（`set_request_owner(player)`）并收集进 `_network_inputs` |
| `handoff_seats_to_ai` | `handoff_seats_to_ai(player_id: String) -> void` | 掉线转 AI：`detach()` 旧输入并替换为 AI |
| `restore_network_inputs` | `restore_network_inputs(player_id: String) -> void` | 重连恢复：先 `detach()` 旧输入，把该玩家座位从 AI 换回 `NetworkPlayerInput` |
| `_seat_ids_for_controller` | `_seat_ids_for_controller(player_id: String) -> Dictionary` | 查该 controller 的座位集合 |
| `_seat_is_ai` | `_seat_is_ai(seat_number: int) -> bool` | 座位是否 `control_mode=="ai"` |
| `attach_seat_inputs` | `attach_seat_inputs(_gui_for_anim: Variant = null, _visual_cb: Callable = Callable()) -> void` | 把外部视觉回调接到每个 `NetworkPlayerInput.visual_requested` |
| `connect_visual_requested` | `connect_visual_requested(callback: Callable) -> void` | 连接视觉回调 |

### 5.4 视觉事件中继（EventBus → 网络广播）

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_connect_visual_relays` | `_connect_visual_relays() -> void` | 把约 26 个 `EventBus` 信号统一绑定到 `_relay_*` 回调，并 `_seed_monster_mark_counts()` |
| `_disconnect_visual_relays` | `_disconnect_visual_relays() -> void` | 对称解绑并清空计数 |
| `_bind_visual_relay` / `_unbind_visual_relay` | — | 去重连接 / 断开 |
| `_relay_game_over` | `_relay_game_over(result: int) -> void` | 广播 `game_over`（含 `_authority_stats_payload()` 与 `_authority_logs_payload()`），随后 `NetSession.return_match_to_lobby()` + `request_state_snapshot()` |
| `_relay_block_mark_changed` | `_relay_block_mark_changed(block: Variant) -> void` | 与 `_last_monster_mark_counts` 对比，仅在计数变化时发 `block_mark_pulse`（含 `increased` 标志） |
| `_relay_damage_taken` | `_relay_damage_taken(target, source, amount) -> void` | 附带 `shake`（来源为怪物则抖动反馈） |
| `_broadcast_visual` | `_broadcast_visual(event_name: String, payload: Dictionary) -> void` | 委托 `NetSession.broadcast_game_event()` |
| `_seat_of` / `_block_mark_key` / `_monster_mark_count` / `_find_monster_holder` / `_authority_stats_payload` / `_authority_logs_payload` / `_seed_match` / `_registry` | — | 辅助方法 |

其他 `_relay_*`（turn_started / phase_changed / monster_died_feedback / monster_spawned / player_state_changed / player_damage_feedback / player_heal_feedback / player_hunger_feedback / player_action_feedback 等）把本地事件转成**最小化视觉负载**（多含 `seat_id` 或坐标）经 `_broadcast_visual()` 发到网络。

---

## 六、关键业务逻辑

### 6.1 开局就绪等待

`begin_match_from_lobby` 登记应到真人（`registry.connected_human_player_ids()`），`wait_until_match_prepared` 循环等待。`_poll_match_ready`：

- 若全部真人已 live 绑定（`_all_expected_bound`）→ 直接 `prepare_from_room`。
- 超时 15s：房主未绑定 → `abort_owner_loopback_failed`；其余未绑定真人 → `convert_unbound_human_to_ai` 转 AI 后放行。

### 6.2 输入装配与切换

`_attach_authority_inputs` 为每个座位挂输入实现；掉线经 `handoff_seats_to_ai` 摘除 `NetworkPlayerInput`（`detach()` 解死等）替换为 AI；重连 `restore_network_inputs` 先 detach 旧输入再换回真人，防重复挂接。

### 6.3 视觉事件中继

`_connect_visual_relays` 把 EventBus 信号绑到 `_relay_*`，转成最小化负载广播；怪物标记脉冲用 `_last_monster_mark_counts` 去重，只有计数变化才广播，避免刷屏。

---

## 七、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | 动态创建/销毁；经 `broadcast_game_event` / `request_state_snapshot` / `registry` 通信 |
| [NetRegistry](./NetRegistry.md) | 读 `MATCH_READY_TIMEOUT_MS`、`start_match` / `connected_human_player_ids` / `clear_live_peer` / `is_player_live_bound` / `convert_unbound_human_to_ai` |
| [ServerLifetime](./ServerLifetime.md) | 存活策略常量 |
| [NetId](./NetId.md) | 开局 `NetId.reset()` |
| [NetPlayerInput](./NetPlayerInput.md) | 真人座位输入实现（`extends IPlayerInput`） |
| [AIPlayerInput](../../../MxApoc_GDScript/src/ai/ai_player_input.gd) | AI 座位输入实现 |
| [Game](../../README.md) | `initialize_from_room_state` / `start_game` / `players` / `log_list` / `state_machine` / `stats_tracker` / `map_area` |
| [EventBus](../System/EventBus.md) | 中继约 26 个游戏事件信号 |
