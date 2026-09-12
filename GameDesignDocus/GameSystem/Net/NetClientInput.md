# NetClientInput 客机输入适配器

> 以 `MxApoc_GDScript/src/net/net_client_input.gd` 为准（约 134 行）。
> `class_name NetClientInput`，`extends RefCounted`，非 autoload（客机侧适配器实例）。
> 职责：**客机输入请求适配器**。UI 可订阅 `requested`，再通过 `respond` 返回基本类型；接收 `INPUT_REQUEST`，解码 payload 为显示层可用的活对象。

---

## 一、职责

客机（含环回后的房主）侧接收权威发来的 `INPUT_REQUEST`：

- 订阅 `NetSession.message_received`，`_on_message` 解码并发出 `requested` 交给 UI。
- UI 处理完调用 `respond` 把选择结果编码回令牌，经 `NetSession.send_input_response` 发回权威。
- 过滤演出型请求（`NetViewSync.VISUAL_EVENT_NAMES`）。

---

## 二、常量 / 信号

**常量**：`NetProtocol`、`NetInputCodec`、`NetViewSync`（均 `preload`）。

**信号**：

| 信号 | 参数 | 发出时机 |
| --- | --- | --- |
| `requested` | `request_id: int, seat_id: int, request_type: String, payload: Dictionary` | `_on_message` 收到并解码一条 `INPUT_REQUEST` 后 |
| `request_state_changed` | 无 | `_active_requests` 增删或 `detach` 清空时 |

---

## 三、成员变量

| 变量 | 类型 | 用途 |
| --- | --- | --- |
| `_active_requests` | `Dictionary` | 活动请求表，`request_id` → `{seat_id, request_type, decoded_payload}` |

---

## 四、方法定义

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `attach` | `attach() -> void` | 连接 `NetSession.message_received` → `_on_message`（幂等） |
| `detach` | `detach() -> void` | 断开连接、清空 `_active_requests`、发 `request_state_changed` |
| `is_action_available` | `is_action_available(seat_id: int = -1) -> bool` | 当前座位活动请求是否正等待 `"action"` |
| `get_current_request` | `get_current_request(seat_id: int = -1) -> Dictionary` | 返回活动请求摘要 `{request_id, seat_id, request_type, decoded_payload}` |
| `get_action_request` | `get_action_request(seat_id: int = -1) -> Dictionary` | 仅当当前请求为 `"action"` 时返回该请求，否则空字典 |
| `respond` | `respond(request_id: int, seat_id: int, value: Variant) -> void` | **UI 应答入口**：校验匹配后编码回令牌，调 `NetSession.send_input_response`，删除活动请求并发 `request_state_changed` |

**私有方法**：`_encode_selection_response`（四类选择请求把选中对象映射回 `selection_tokens` 令牌）、`_find_candidate_index`（`==` 或 `NetInputCodec.encode` 兜底匹配）、`_on_message`（监听 INPUT_REQUEST）、`_drop_seat_requests`（删除同座位旧请求）。

---

## 五、关键业务逻辑（`_on_message`）

1. 忽略 `NetViewSync.VISUAL_EVENT_NAMES` 中的演出事件。
2. `request_type=="choose_target"` 时先 `NetInputCodec.apply_display_combat_fields` 刷新显示层战斗字段。
3. `NetInputCodec.decode(raw_payload, NetSession.get_display_game() or Game)` 解码 payload 为活对象引用。
4. `_drop_seat_requests(seat_id)` 丢掉同座位旧请求。
5. 写入 `_active_requests`，发 `request_state_changed` 后 `requested.emit`。

---

## 六、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | `message_received`、`send_input_response`、`get_display_game` |
| [NetInputCodec](./NetInputCodec.md) | `decode` / `apply_display_combat_fields` / `encode` |
| [NetViewSync](./NetViewSync.md) | `VISUAL_EVENT_NAMES` 过滤演出请求 |
| 客机 GUI 输入实现 | 通过 `requested` / `respond` / `is_action_available` / `get_current_request` 对接 |
