# NetProtocol 协议常量与消息封装

> 以 `MxApoc_GDScript/src/net/net_protocol.gd` 为准（114 行）。
> `class_name NetProtocol`，`extends RefCounted`，非 autoload，**纯静态工具类**（全部方法 static）。
> 职责：**联机协议常量、消息封装和通用校验**。网络层只传输 JSON 可表示的数据，不传递 Godot 对象引用。

---

## 一、常量

### 基础常量

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `VERSION` | `1` | 协议版本号 |
| `DEFAULT_PORT` | `7777` | 默认监听端口 |
| `MAX_PORT` | `65535` | 端口上限 |
| `MAX_NICKNAME_LENGTH` | `24` | 昵称截断长度 |
| `MAX_SEATS` | `6` | 房间座位上限 |
| `MAX_PLAYERS` | `6` | 玩家上限（ENet server 最大连接数） |
| `HEARTBEAT_INTERVAL_MS` | `5000` | 客户端心跳间隔（5s） |
| `HEARTBEAT_TIMEOUT_MS` | `30000` | 心跳超时（30s 判掉线） |

### 消息类型常量（协议 opcode，均 String）

`join_request` / `join_accepted` / `reconnect_request` / `room_snapshot` / `room_command` / `input_request` / `input_response` / `command_result` / `leave_request` / `match_start` / `game_event` / `state_snapshot` / `resync_request` / `heartbeat` / `player_connected` / `player_disconnected` / `player_reconnected` / `room_closed` / `error`。

### 错误码常量（均 String）

`error_invalid_address` / `error_invalid_port` / `error_port_in_use` / `error_connect_timeout` / `error_connection_refused` / `error_online_disabled` / `error_protocol_mismatch` / `error_room_full` / `error_room_already_started` / `error_invalid_token` / `error_token_expired` / `error_invalid_command` / `error_stale_request` / `error_need_resync`。

---

## 二、消息信封格式

`make_message()` 产出 8 字段信封：

```
{
  "message_type":    String,   # opcode
  "protocol_version": int,     # = VERSION(1)
  "match_id":        String,   # 对局 id，大厅阶段为空串
  "sender_player_id": String,  # 发送方 player_id
  "client_sequence": int,      # 客户端自增序号
  "server_sequence": int,      # 服务器自增序号（快照排序用）
  "request_id":      int,      # 请求 id，默认 -1
  "payload":         Dictionary# 业务数据（深拷贝）
}
```

---

## 三、方法定义（全部 static）

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `make_message` | `make_message(message_type: String, payload: Dictionary = {}, sender_player_id: String = "", match_id: String = "", client_sequence: int = 0, server_sequence: int = 0, request_id: int = -1) -> Dictionary` | 组装标准消息信封；`payload` 深拷贝 |
| `has_message_envelope` | `has_message_envelope(message: Variant) -> bool` | 仅校验信封形状（Dictionary 且 message_type 非空、payload 是 Dictionary） |
| `is_valid_message` | `is_valid_message(message: Variant) -> bool` | 信封合法 **且** `protocol_version == VERSION` |
| `is_protocol_mismatch` | `is_protocol_mismatch(message: Variant) -> bool` | 信封合法但 `protocol_version != VERSION` |
| `normalize_nickname` | `normalize_nickname(value: String) -> String` | `strip_edges()` 后超长截断到 24 字符 |
| `parse_address` | `parse_address(value: String) -> Dictionary` | 解析 `host:port` / `[ipv6]:port`；全角冒号转半角；`localhost`→`127.0.0.1`；成功返回 `{ok:true, host, port}`，失败 `{ok:false, error}` |

---

## 四、关键业务逻辑

**校验链**：`has_message_envelope`（形状）→ `is_valid_message`（版本）→ `is_protocol_mismatch`（版本不符触发 `ERROR_PROTOCOL_MISMATCH`）。

**握手流程**：
- 加入：客机发 `join_request`（payload 含 `display_name`）→ 房主校验 `phase=="lobby"` 与人数 → 回 `join_accepted`（`{player_id, reconnect_token, room_snapshot}`）。
- 重连：客机发 `reconnect_request`（payload 含 `reconnect_token`）→ 房主 `reconnect_error_for_token` 校验 → 成功回带 player_id/token 的 `state_snapshot` 并广播 `player_reconnected`。
- 退出：`leave_request`。

---

## 五、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | 大量引用：`make_message` / 校验 / 消息类型 / 错误码 / 心跳常量 |
| [NetRegistry](./NetRegistry.md) | `DEFAULT_PORT` / `MAX_SEATS` / `VERSION` / `normalize_nickname` / 错误码 |
| [NetPlayerInput](./NetPlayerInput.md) / [NetClientInput](./NetClientInput.md) | `input_request` / `input_response` 判定 |
| UI（game_room / join_room_overlay / room_state） | 昵称规范化、`parse_address`、错误码文案映射 |
