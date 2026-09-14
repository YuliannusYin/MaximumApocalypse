# NetProtocol 协议常量与消息封装

> 以 `MxApoc_GDScript/src/net/net_protocol.gd` 为准。
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
| `HELLO_RETRY_INITIAL_MS` | `1000` | HELLO 首次重试间隔 |
| `HELLO_RETRY_MAX_MS` | `4000` | HELLO 重试间隔上限 |
| `HELLO_RETRY_MAX_ATTEMPTS` | `8` | HELLO 最多重试次数 |
| `IDENTITY_SLOT_HOST` / `IDENTITY_SLOT_GUEST` | `"host"` / `"guest"` | 身份文件槽名 |
| `IDENTITY_FILE_PATH` | `user://net_identity.json` | 旧单文件（迁移后删除） |
| `IDENTITY_FILE_PATH_HOST` | `user://net_identity_host.json` | 房主身份 |
| `IDENTITY_FILE_PATH_GUEST` | `user://net_identity_guest.json` | 客机身份 |

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
| `parse_address` | `parse_address(value: String) -> Dictionary` | 解析 `host:port` / `[ipv6]:port`；全角冒号转半角；`localhost`→`127.0.0.1`；成功 `{ok:true, host, port}`，失败 `{ok:false, error}` |
| `resolve_host` | `resolve_host(host: String) -> Dictionary` | 纯 IP 不走 DNS；否则 `IP.resolve_hostname`（先 IPv4）；成功 `{ok:true, ip}` |
| `identity_file_path_for_slot` | `identity_file_path_for_slot(slot: String) -> String` | host/guest 槽对应的 `user://` 路径 |
| `error_text` | `error_text(code: String, detail: String = "") -> String` | 给玩家看的错误文案；`detail` 非空优先用 detail |
| `client_create_error` | `client_create_error(result: int) -> Dictionary` | ENet `create_client` 返回码映射为协议错误 |

---

## 四、关键业务逻辑

**校验链**：`has_message_envelope`（形状）→ `is_valid_message`（版本）→ `is_protocol_mismatch`（版本不符触发 `ERROR_PROTOCOL_MISMATCH`）。

**握手流程**：
- 客机连上后 `_send_client_hello`：本地客机槽有凭证发 `reconnect_request`（`display_name` + `reconnect_token`），否则 `join_request`（`display_name`，可选 token）。
- 房主 `_try_resume_player`：token 命中且非误用房主凭证 → 认回；否则**唯一非房主同名**认回并签发新 token。
- 大厅未命中：`reconnect_request` 改走 `_handle_join` / `add_player`，回 `join_accepted`。
- 对局未命中：`INVALID_TOKEN` 或 `ROOM_ALREADY_STARTED`。菜单等待中收到 `INVALID_TOKEN` 时客机清凭证改发 `join_request`。
- 认回成功：带 `player_id` / `reconnect_token` 的 `state_snapshot`，并广播 `player_reconnected`。
- 退出：`leave_request`。
- HELLO 失败且传输仍在：1s 起指数退避到 4s，最多 8 次。

---

## 五、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | `make_message` / 校验 / 消息类型 / 错误码 / 心跳与 HELLO 常量 / 身份路径 / `resolve_host` / `error_text` |
| [NetRegistry](./NetRegistry.md) | `DEFAULT_PORT` / `MAX_SEATS` / `VERSION` / `normalize_nickname` / 错误码 |
| [NetPlayerInput](./NetPlayerInput.md) / [NetClientInput](./NetClientInput.md) | `input_request` / `input_response` 判定 |
| UI（game_room / join_room_overlay / room_state） | 昵称规范化、`parse_address`、`error_text` |
