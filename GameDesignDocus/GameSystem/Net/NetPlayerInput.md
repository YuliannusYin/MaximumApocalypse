# NetworkPlayerInput 网络玩家输入

> 以 `MxApoc_GDScript/src/net/net_player_input.gd` 为准（约 306 行）。
> `class_name NetworkPlayerInput`，`extends IPlayerInput`（接口基类在 `src/ui/i_player_input.gd`）。
> 职责：**房主为远程真人座位创建的输入实现**。规则协程仍运行在房主，只有输入值通过 ENet 往返；把每个输入请求打包（候选对象本地持有、只发令牌），经 `NetSession.broadcast_input_request` 发出并 `await` 等响应。

---

## 一、职责

`NetworkPlayerInput` 是 `IPlayerInput` 的"远程输入"变体：

- 实现 `wait_action` / `choose` / `choose_card` / `choose_target` / `choose_map_block` / `choose_block_inline` / `confirm` / `show_card` 等接口。
- 请求-响应循环：`_request()` 把候选对象存本地 `selection_map`，payload 只含 `selection_tokens`（下标令牌），发出 `INPUT_REQUEST` 后死等 `response_arrived`。
- 演出类请求（动画）走 `_emit_visual()` → `GAME_EVENT` 单向广播，**不等 ACK**。

`RefCounted`，无 Node 生命周期；房主为每个远程真人座位创建一个实例。

---

## 二、常量 / 信号

**常量**：`NetProtocol`、`NetInputCodec`（均 `preload`）。

**信号**：

| 信号 | 参数 | 发出时机 |
| --- | --- | --- |
| `response_arrived` | `request_id: int, value: Variant` | 收到 `INPUT_RESPONSE` 或 pending 被中止（此时 `(-1, null)`） |
| `visual_requested` | `request_type: String, seat_id: int, payload: Dictionary` | `_emit_visual` 本地同步广播演出事件时 |

---

## 三、成员变量

| 变量 | 类型 | 用途 |
| --- | --- | --- |
| `_pending` | `Dictionary` | 待应答请求表，`request_id` → `{value, received, selection_map, request_type, seat_id}` |
| `_request_owner` | `Variant` | 当前输入请求所属玩家 |

---

## 四、方法定义

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_init` | `func _init() -> void` | 连接 `NetSession.message_received` → `_on_network_message` |
| `set_request_owner` | `set_request_owner(player: Variant) -> void` | 设置请求所属玩家 |
| `detach` | `detach() -> void` | 先 `abort_pending()`，再断开 `message_received` |
| `abort_pending` | `abort_pending() -> void` | 解开死等：所有未应答 pending 填值并标记 received，`emit(-1, null)` 唤醒协程；随后由 AI 接管 |
| `wait_action` | `wait_action(player: Variant) -> Variant` | 行动阶段：`_request(player, "action", limited_action_request_payload(player))` |
| `limited_action_request_payload` | `static func limited_action_request_payload(player: Variant) -> Dictionary` | 迷你回合预算：仅当 `operation_context.kind=="limited_action"` 时放 `operation_kind` 与 `remaining_actions`（不改正式 action_count） |
| `choose` | `choose(options: Array, prompt: String = "") -> Variant` | 从列表选一项 |
| `choose_card` | `choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array` | 选 n 张牌 |
| `choose_target` | `choose_target(n: int, skill: Variant, prompt: String = "", min_n: int = -1) -> Array` | 选目标；`n==-1` 或全选且 `Settings.skip_target_selection` 直接返回候选 |
| `choose_map_block` | `choose_map_block(blocks: Array, prompt: String = "") -> Variant` | 选一个地块 |
| `choose_block_inline` | `choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array` | 地图内联选块 |
| `confirm` | `confirm(message: String) -> bool` | 确认框 |
| `show_card` | `show_card(card: Card, target: Variant) -> void` | 演出：显示一张卡（`_emit_visual`） |
| `set_prompt` | `set_prompt(text: String) -> void` | 演出：广播 `set_prompt` |
| `wait_redraw_decision` | `wait_redraw_decision(player: Variant) -> bool` | 换牌决策（payload 带 `player.hand`） |
| `wait_judge_confirm` | `wait_judge_confirm(player: Variant, prompt: String, allow_cancel: bool) -> bool` | 判定确认 |
| `play_dice_animation` | `play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void` | 演出：骰子动画 |
| `play_monster_draw_animation` / `play_scavenge_draw_animation` / `play_card_destroy_animation` / `play_monster_skill_trigger_animation` | — | 演出动画 |
| `play_monster_attack_animation` | `play_monster_attack_animation(monster: Variant, targets: Array) -> void` | 怪物攻击动画（targets 转成 seat_number 数组随 payload 走） |

**私有方法**：`_abort_unanswered_for_seat`、`_abort_value_for`、`_get_card_candidates`、`_emit_visual`、`_request`、`_resolve_response_value`、`_decode_selection_result`、`_on_network_message`、`_seat_id_for_player`、`_controller_for_seat`。

---

## 五、核心请求流程（`_request`）

1. 取 `seat_id` / `controller_id`；`NetSession.next_request_id()` 分配 id。
2. `_abort_unanswered_for_seat`：同座位旧未应答请求先中止，避免客机丢弃后权威死等。
3. 把候选数组转为 `selection_tokens`（`str(index)` 令牌），对象本体留本地 `selection_map`；写入 `_pending[request_id]`。
4. `NetSession.broadcast_input_request(request_id, seat_id, owner_id, request_type, payload)` 发出。
5. `while … await response_arrived` 死等；收到后按 `selection_map` 把令牌解析回对象（`_resolve_response_value`）。
6. `choose_target` 成功后额外 `broadcast_game_event("target_links", …)`。

**中止默认值**（`_abort_value_for`）：`choose_card/choose_target/choose_block_inline` → `[]`；`confirm/redraw_decision` → `false`；`judge_confirm` → `true`；其余 → `null`。

---

## 六、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | `message_received`、`broadcast_input_request`、`send_input_response`、`next_request_id`、`broadcast_game_event`、`registry` |
| [NetInputCodec](./NetInputCodec.md) | `encode` / `decode` 处理请求值 |
| [IPlayerInput](../../../MxApoc_GDScript/src/ui/i_player_input.gd) | 实现的接口基类 |
| [Game](../../README.md) | 作为 `game` 参数解码 |
| [Settings](../../../MxApoc_GDScript/src/) | `skip_target_selection` 跳过选目标 |
