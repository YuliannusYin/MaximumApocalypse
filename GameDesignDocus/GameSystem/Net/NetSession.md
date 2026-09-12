# NetSession 网络会话

> 以 `MxApoc_GDScript/src/net/net_session.gd` 为准（约 1101 行）。
> 注册为 autoload 单例，全局名 `NetSession`，`extends Node`，无 `class_name`。
> 职责：**房主权威网络会话**。所有业务数据经 `receive_message()` 进入同一校验入口；持有 ENet peer、MultiplayerAPI、房间状态注册表（`NetRegistry`）、身份持久化与心跳。

---

## 一、职责与定位

`NetSession` 是联机系统的**传输/会话/协议层枢纽**，常驻进程（autoload）：

- 管理 ENet 监听服务器 / 客户端连接（`create_host` / `join` / `reconnect_to_last_room` / `close_session`）。
- 统一封包、校验、分发消息（房主侧 `_handle_message`，客机侧 `_apply_client_inbound_message`）。
- 持有 `NetRegistry`（房间唯一事实来源）与动态 `ServerRuntime`（对局规则运行时）。
- 房主通过**环回客户端**自连本机，以 `client` 身份跑客机逻辑。
- 持久化玩家身份（`user://net_identity.json`）支持重连。
- 心跳保活与超时踢人。

角色由 `session_role`（`"none"/"host"/"client"`）+ `is_host` 分流，**同一份代码同时服务房主与客机**。

---

## 二、常量与预加载

| 常量 | 值 / 来源 | 用途 |
| --- | --- | --- |
| `NetProtocol` | `preload` | 协议常量/信封/校验 |
| `NetRegistry` | `preload` | 房间状态注册表类 |
| `NetInputCodec` | `preload` | 输入编解码 |
| `GameStateSerializer` | `preload` | 对局快照序列化 |
| `ServerRuntimeScript` | `preload` | 权威运行时脚本（动态实例化） |
| `LoopbackRpcScript` | `preload` | 环回 RPC 桩脚本 |
| `LOOPBACK_ROOT_NAME` | `"NetLoopbackRoot"` | 环回客户端挂载的根节点名 |
| `LOOPBACK_RPC_NAME` | `"NetSession"` | 环回 RPC 桩节点名 |

消息类型/错误码/心跳/端口等常量均取自 `NetProtocol`（见 [NetProtocol.md](./NetProtocol.md)）。

---

## 三、信号

| 信号 | 参数 | 发出时机 |
| --- | --- | --- |
| `session_changed` | `snapshot: Dictionary` | 房间快照变化（`_emit_snapshot`）、收到 JOIN_ACCEPTED / ROOM_SNAPSHOT / STATE_SNAPSHOT / MATCH_START、创建 host 后 |
| `connection_state_changed` | `state: String, detail: String` | 状态机迁移：`host` / `connecting` / `connected` / `joined` / `peer_connected` / `disconnected` / `match_started` / `closed` |
| `message_received` | `message: Dictionary` | 客机收到合法入站消息；权威端校验通过的服务端入站消息 |
| `network_error` | `code: String, detail: String` | 端口占用、连接失败、协议不匹配、token 失效、超时、房主关房等 |

---

## 四、成员变量

| 变量 | 类型 | 用途 |
| --- | --- | --- |
| `registry` | `NetRegistry` | 房间状态注册表 |
| `is_host` | `bool` | 本进程是否拥有 ENet 监听服务器 |
| `session_role` | `String` | `"none"/"host"/"client"` |
| `local_player_id` | `String` | 本机玩家 ID |
| `local_reconnect_token` | `String` | 本机重连凭证 |
| `_client_sequence` | `int` | 客户端出站消息序号 |
| `_connected_address` | `String` | 客机记住的房间地址 `host:port` |
| `_pending_nickname` | `String` | 客机待发送昵称 |
| `_saved_identity` | `Dictionary` | `{player_id, reconnect_token}`（来自 `user://net_identity.json`） |
| `_state_snapshot_dirty` | `bool` | 对局状态快照脏标记（每帧最多一份） |
| `_request_id_counter` | `int` | 请求 ID 计数器 |
| `server_runtime` | `Node` | 权威运行时实例（动态创建） |
| `_client_api` | `MultiplayerAPI` | 房主自连的环回 MultiplayerAPI |
| `_loopback_root` / `_loopback_stub` | `Node` | 环回根节点 / RPC 桩节点 |
| `_view_game` | `Node` | 客机侧"显示用对局"（ViewGame） |
| `applying_display_snapshot` | `bool` | 正在向 ViewGame 应用快照的标记 |
| `_closing` | `bool` | `close_session()` 重入保护 |
| `_awaiting_room_accept` | `bool` | 等待 JOIN_ACCEPTED / 快照确认 |
| `_last_heartbeat_sent_ms` | `int` | 上次心跳发送时刻 |

---

## 五、方法定义

### 5.1 会话生命周期

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `create_host` | `create_host(host_name: String, port: int, seats: Array) -> bool` | 建 ENet 监听服务器并初始化本机为房主；失败发 `ERROR_PORT_IN_USE` |
| `join` | `join(address: String, nickname: String) -> bool` | 客机加入房间；解析地址、`create_client`、发 `connecting` |
| `reconnect_to_last_room` | `reconnect_to_last_room() -> bool` | 对局中断线重连；保留凭证与 ViewGame，重建 ENet 客机连接 |
| `close_session` | `close_session() -> void` | 全量清理（停 Runtime、拆环回、清 ViewGame、关 peer、重置字段），`_closing` 防重入 |
| `ensure_server_runtime` | `ensure_server_runtime() -> Node` | 懒创建权威运行时，挂 `/root/ServerRuntime` |
| `has_active_server_runtime` | `has_active_server_runtime() -> bool` | 是否已有活动运行时 |
| `stop_server_runtime` | `stop_server_runtime() -> void` | 停止权威运行时 |
| `begin_online_match` | `begin_online_match() -> void` | 房主开局：`server_runtime.begin_match_from_lobby()` → 确保 ViewGame → 广播 `MATCH_START` |
| `return_match_to_lobby` | `return_match_to_lobby() -> void` | 对局结束回大厅（只改 phase 并广播） |
| `cleanup_match_for_lobby` | `cleanup_match_for_lobby() -> void` | 清 ViewGame、停 Runtime 供下一局重建 |
| `close_authority_room` | `close_authority_room(reason: String) -> void` | 广播 `ROOM_CLOSED` 后 `close_session()` |
| `next_request_id` | `next_request_id() -> int` | 请求 ID 自增 |

### 5.2 角色判定

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `is_authority` | `is_authority() -> bool` | 有活动 Runtime，或 `has_listen_server()`，或 `is_host && role=="host"` |
| `has_listen_server` | `has_listen_server() -> bool` | 当前 multiplayer API 是否为 ENet server |
| `is_room_owner` | `is_room_owner() -> bool` | registry 中本机玩家 `is_host`，或 `is_host && role!="none"` |
| `is_remote_client` | `is_remote_client() -> bool` | `session_role=="client"` 且非房主 |
| `uses_network_view` | `uses_network_view() -> bool` | `session_role=="client"`（环回后的房主也走客机通道） |
| `is_local_controlled_seat` | `is_local_controlled_seat(seat_id: int) -> bool` | 本机操作座位判定 |
| `filter_local_controlled_players` | `filter_local_controlled_players(players: Array) -> Array` | 过滤本机控制的玩家 |

### 5.3 显示对局（ViewGame）管理

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `get_display_game` | `get_display_game() -> Node` | 取 ViewGame，无则回退单例 `Game` |
| `peek_view_game` | `peek_view_game() -> Node` | 偷看 ViewGame（不创建） |
| `should_enter_match_scene` | `should_enter_match_scene() -> bool` | 客机重连进对局判定（`phase=="playing"` 且无权威 Runtime 且是远端客机） |
| `_ensure_view_game` / `_clear_view_game` | `-> Node` / `-> void` | 创建 / 销毁 ViewGame |
| `apply_display_game_snapshot` | `apply_display_game_snapshot(snapshot: Dictionary, ctx: Dictionary) -> void` | 把 `game_snapshot` 应用到 ViewGame；目标是权威 `Game` 则 `push_error` 拒绝 |
| `commit_display_settlement_to_game` | `commit_display_settlement_to_game() -> void` | 客机结算页把 ViewGame 的 `log_list/players/current_mission/game_result/state_machine/stats_tracker` 拷回单例 `Game` |

### 5.4 房主环回（Loopback）连接管理

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_enter_host_loopback` | `_enter_host_loopback() -> bool` | 房主自连本机 ENet 服务；建 `_client_api`、`tree.set_multiplayer(_client_api, _loopback_root)`、挂 `LoopbackRpcScript` 桩 |
| `_teardown_loopback_client` | `_teardown_loopback_client() -> void` | 断开信号、关 peer、`set_multiplayer(null)`、释放节点 |
| `_on_loopback_connected/_failed/_disconnected` | — | 环回回调；断开时权威端 `close_authority_room("owner_left")` |
| `_is_loopback_peer` / `_loopback_peer_id` / `_peer_is_connected` / `_client_transport_connected` | — | 传输连接判定 |
| `_rpc_loopback_to_host` | `_rpc_loopback_to_host(message: Dictionary) -> void` | 环回 RPC：`_loopback_stub.rpc_id(1, "receive_message", message)` |

### 5.5 客户端→服务端发送

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `send_room_command` | `send_room_command(command: String, payload: Dictionary = {}) -> void` | 房间命令（start / bind_seat / set_survivor） |
| `sync_room_config` | `sync_room_config() -> void` | 读 `/root/RoomState` 的 mission 配置写入 registry 并广播 |
| `send_input_response` | `send_input_response(request_id: int, seat_id: int, value: Variant) -> void` | 回复输入请求，`NetInputCodec.encode(value)` |
| `request_resync` | `request_resync() -> void` | 请求全量重同步 |
| `leave_room` | `leave_room() -> void` | 权威关房，否则发 `LEAVE_REQUEST` 后 `close_session()` |
| `_send_to_host` | `_send_to_host(message_type: String, payload: Dictionary = {}, request_id: int = -1) -> void` | **统一出站入口**：封包；有环回走 `_rpc_loopback_to_host`；`is_host` 直接 `_handle_message(message, 1)`；否则 `rpc_id(1, "receive_message", message)` |

### 5.6 权威端广播

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `broadcast_game_event` | `broadcast_game_event(event_name: String, payload: Dictionary) -> void` | 带 `registry.next_server_sequence()` 的 `GAME_EVENT` 广播 |
| `broadcast_state_snapshot` | `broadcast_state_snapshot(_snapshot: Dictionary = {}) -> void` | 别名 → `request_state_snapshot()` |
| `request_state_snapshot` | `request_state_snapshot() -> void` | 置脏标记，每帧合并发送一份 |
| `has_pending_state_snapshot` | `has_pending_state_snapshot() -> bool` | 是否有待发快照 |
| `_flush_pending_state_snapshot` | `_flush_pending_state_snapshot() -> bool` | 实际发送 `STATE_SNAPSHOT`（room_snapshot + `GameStateSerializer.snapshot(Game)`） |
| `broadcast_input_request` | `broadcast_input_request(request_id: int, seat_id: int, owner_id: String, request_type: String, payload: Dictionary) -> void` | 权威向指定玩家定向发 `INPUT_REQUEST`；owner 无 peer_id 则 `_handoff_player_inputs`（转 AI） |
| `_broadcast` / `_rpc_if_ready` / `_rpc_id_if_ready` | — | 带就绪检查的广播 / 定向 RPC |

### 5.7 RPC 消息分发（核心）

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `receive_message` | `@rpc("any_peer","reliable") receive_message(message: Dictionary) -> void` | **所有业务数据的统一校验入口**：协议版本不匹配 → `_on_protocol_mismatch()`；`is_valid_message` 校验；权威端收到远端 RPC → `_handle_message`；客机走 `_apply_client_inbound_message` |
| `receive_loopback_client_message` | `receive_loopback_client_message(message: Dictionary) -> void` | 环回桩回调的客机侧入口 |
| `_apply_client_inbound_message` | `_apply_client_inbound_message(message: Dictionary) -> void` | 客机入站分发：JOIN_ACCEPTED / ROOM_SNAPSHOT / STATE_SNAPSHOT / MATCH_START / ROOM_CLOSED / ERROR |
| `_server_api` / `_authority_sender_id` / `_is_incoming_authority_rpc` | — | 权威端判断 RPC 来源与发送者 ID |
| `_handle_message` | `_handle_message(message: Dictionary, sender_id: int) -> void` | **权威端分发中心**：先 `registry.touch_last_seen`；分发 JOIN / RECONNECT / ROOM_COMMAND / INPUT_RESPONSE / RESYNC / LEAVE / HEARTBEAT；未知 → `_reject(ERROR_INVALID_COMMAND)` |

### 5.8 房间加入 / 离开（权威侧）

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_handle_join` | `_handle_join(message: Dictionary, sender_id: int) -> void` | 仅 lobby 受理；满员 → `ERROR_ROOM_FULL`；成功回 `JOIN_ACCEPTED` 并广播快照 |
| `_handle_room_command` | `_handle_room_command(message: Dictionary, sender_id: int) -> void` | `start`（仅房主、lobby）、`bind_seat`（仅房主）、`set_survivor`（房主或座位控制者） |
| `_handle_leave` | `_handle_leave(message: Dictionary, sender_id: int) -> void` | 房主离开 → `close_authority_room("owner_left")`；普通玩家 → `_drop_remote_player` |
| `_handle_input_response` | `_handle_input_response(message: Dictionary, sender_id: int) -> void` | 校验 `_owns_seat` 后转发 `message_received` |
| `_drop_remote_player` | `_drop_remote_player(player_id: String, left: bool) -> void` | `disconnect_player` → `_handoff_player_inputs` → 广播 `PLAYER_DISCONNECTED` → 广播快照 |
| `_handoff_player_inputs` | `_handoff_player_inputs(player_id: String) -> void` | 对局中委托 `server_runtime.handoff_seats_to_ai` |
| `_is_owner_player` / `_can_edit_seat_survivor` / `_owns_seat` / `_player_for_peer` | — | 权限 / 座位归属 / peer 映射 |

### 5.9 重连

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_handle_reconnect` | `_handle_reconnect(message: Dictionary, sender_id: int) -> void` | 校验 token；重建绑定；对局中 `server_runtime.restore_network_inputs`；回 `STATE_SNAPSHOT` + 广播 `PLAYER_RECONNECTED` |
| `_send_client_hello` | `_send_client_hello() -> void` | 连上后有 token 发 `RECONNECT_REQUEST`，否则发 `JOIN_REQUEST` |
| `_on_server_disconnected` | `_on_server_disconnected() -> void` | 非权威且对局中有 token → 仅发 `disconnected` 等待重连；否则发错误并关会话 |
| `_on_connection_failed` | `_on_connection_failed() -> void` | 发 `ERROR_CONNECT_TIMEOUT`；对局中有 token 保留会话，否则关会话 |
| `_restore_client_identity` | `_restore_client_identity(payload: Dictionary) -> void` | 从 payload/嵌套快照/`_saved_identity` 恢复 player_id 与 token 并写盘 |
| `_finish_room_accept` | `_finish_room_accept(detail: String) -> void` | 置 `_awaiting_room_accept=false`，发 `joined` |
| `_load_saved_identity` / `_save_identity` / `_delete_saved_identity` | — | 身份持久化（`user://net_identity.json`） |

### 5.10 心跳 / 时序同步

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_tick_heartbeat` | `_tick_heartbeat() -> void` | 客机每 `HEARTBEAT_INTERVAL_MS`(5s) 发一次 `HEARTBEAT` |
| `_scan_heartbeat_timeouts` / `drop_stale_players` | `-> void` / `(now_ms: int = -1) -> Array` | 权威端对超过 `HEARTBEAT_TIMEOUT_MS`(30s) 未活跃的客机 `_drop_remote_player` |
| `_next_client_sequence` | `_next_client_sequence() -> int` | 客户端出站序号自增 |
| `_make_state_snapshot_message` | `_make_state_snapshot_message() -> Dictionary` | 对局中封装 `playing_resync_payload()` 为 `STATE_SNAPSHOT` 并递增 server_sequence |

### 5.11 其他

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `_on_peer_connected` / `_on_peer_disconnected` | — | 广播 `peer_connected`；断连时房主离开→关房，否则 `_drop_remote_player` |
| `_on_protocol_mismatch` | `_on_protocol_mismatch() -> void` | 权威端 `_reject(ERROR_PROTOCOL_MISMATCH)`，客机发 `network_error` |
| `_apply_snapshot` | `_apply_snapshot(snapshot: Dictionary) -> void` | 快照同步到 registry，并镜像到 `/root/RoomState` |
| `_emit_snapshot` | `_emit_snapshot() -> void` | 发 `session_changed` + 广播 `ROOM_SNAPSHOT` |

---

## 六、关键业务逻辑

### 6.1 房主环回（Loopback）

房主创建监听后，用**第二个 `MultiplayerAPI`** 自连 `127.0.0.1:port`：

- `_client_api = MultiplayerAPI.create_default_interface()`。
- `tree.set_multiplayer(_client_api, _loopback_root)` 让环回子树走独立 API，不污染全局 multiplayer。
- 挂载 `LoopbackRpcScript` 桩（节点名固定 `NetSession`），其 `rpc_id(1, "receive_message", message)` 承接环回 RPC。
- 环回后的房主 `session_role` 置 `"client"`，`uses_network_view()` 为 true，**与远端客机走完全相同的客户端路径**；唯一区别是权威端多一路 `_handle_message` 处理远端 RPC。

### 6.2 协议校验链

`has_message_envelope`（形状）→ `is_valid_message`（版本）→ `is_protocol_mismatch`（版本不符 → `ERROR_PROTOCOL_MISMATCH`）。任何不合法消息都被拒绝，保证线上只处理符合协议的 JSON 数据。

### 6.3 每帧最多一份快照

`request_state_snapshot()` 只置 `_state_snapshot_dirty`，`_process` 每帧末 `_flush_pending_state_snapshot()` 合并发送一份，避免大量日志把演出通道堵住。

### 6.4 输入请求定向发送与掉线接管

`broadcast_input_request` 只向目标 owner 的 peer 发送；若 owner 无 peer_id（掉线），直接 `_handoff_player_inputs` 把其座位转 AI，避免规则协程死等。

---

## 七、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetRegistry](./NetRegistry.md) | `registry` 成员，房间状态唯一事实来源 |
| [ServerRuntime](./ServerRuntime.md) | 动态创建，权威规则运行时 |
| [GameStateSerializer](./GameStateSerializer.md) | `snapshot(Game)` 生成对局快照、`apply(ViewGame, snapshot, ctx)` 应用 |
| [NetInputCodec](./NetInputCodec.md) | 输入/载荷编码 |
| [NetProtocol](./NetProtocol.md) | 消息信封、校验、常量 |
| [NetLoopbackRpc](./NetLoopbackRpc.md) | 环回桩，承接房主自连 RPC |
| [RoomState](../System/RoomState.md) | 大厅配置双向同步 |
| [DataManager](../../Engineering/DataFormat.md) | 校验 survivor 等静态数据 |
