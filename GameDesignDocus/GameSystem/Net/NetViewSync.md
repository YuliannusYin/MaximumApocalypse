# NetViewSync 客机视图同步

> 以 `MxApoc_GDScript/src/net/net_view_sync.gd` 为准（73 行）。
> `class_name NetViewSync`，`extends RefCounted`，非 autoload，**纯静态工具类**。
> 职责：**客机视图序号**——快照丢旧包；`GAME_EVENT` 不因序号落后丢弃，只按键去重。

---

## 一、常量

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `VISUAL_EVENT_NAMES` | `Array` | 视觉类请求名单：`show_card` / `dice_animation` / `monster_draw_animation` / `scavenge_draw_animation` / `card_destroy_animation` / `monster_skill_animation` / `monster_attack_animation`；客机收到这些 `INPUT_REQUEST` 不送规则层 |

---

## 二、方法定义（全部 static）

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `should_apply_snapshot` | `should_apply_snapshot(sequence: int, last_snapshot_sequence: int) -> bool` | `sequence <= 0 or sequence > last_snapshot_sequence` 才应用——旧包直接丢 |
| `event_dedup_key` | `event_dedup_key(sequence: int, event_name: String, payload: Variant) -> String` | 生成 `"<seq>\|<event>\|<payload_id>\|<extra>"` 去重键；`log` 事件附加消息文本 |
| `append_guest_log` | `append_guest_log(log_list: Array, message: String, is_authority: bool) -> void` | 客机把 log 事件写进结算页 log_list；权威（房主已在 `log_message` 写过）跳过防重复 |
| `apply_game_over_logs` | `apply_game_over_logs(log_list: Array, logs: Variant) -> void` | 对局结束时用权威全量日志覆盖，补漏包/中途加入 |
| `copy_event_log_if_empty` | `copy_event_log_if_empty(log_list: Array, event_log: Array) -> void` | 结算切场景前兜底：log_list 仍空则拷临时事件日志 |

**私有方法**：`_payload_key_id`（优先顶层 `net_id`，其次遍历 `card/monster/player/block` 嵌套取 net_id，最后回退 `seat_id`）、`_entity_net_id`。

---

## 三、关键业务逻辑

- **快照**：只按 `server_sequence` 递增应用，旧包（序号 ≤ 已应用）直接丢弃。
- **事件**：不因序号落后丢弃，用 `event_dedup_key` 去重（`sequence|event_name|payload net_id/seat_id`），保证演出不重复也不丢。
- **日志三条线**：`append_guest_log`（增量）、`apply_game_over_logs`（结算覆盖）、`copy_event_log_if_empty`（场景切换兜底）。

---

## 四、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [game_scene_2d](../../../MxApoc_GDScript/src/ui/game_scene_2d.gd) | 快照序号过滤、事件去重、日志收集 |
| [NetClientInput](./NetClientInput.md) | `VISUAL_EVENT_NAMES` 过滤演出请求 |
