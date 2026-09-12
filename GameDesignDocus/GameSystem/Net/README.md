# 联机系统（Net）

> 本文档总览 `MxApoc_GDScript/src/net/` 联机子系统。该子系统由 **v0.37.0 ~ v0.37.5** 六个版本逐步引入（里程碑见文末 [版本历史](#版本历史)）。
> 源码位置：`MxApoc_GDScript/src/net/`。
> 联机采用 **房主权威（Host-Authoritative）** 架构：房主进程持有完整规则与权威 `Game`，远端玩家通过 `NetworkPlayerInput` 走输入请求-响应链路操作；客机用 **ViewGame 显示世界** + 快照/事件呈现对局。

---

## 一、核心设计原则

1. **线上只传 JSON 可表示数据，不传 Godot 对象引用**（见 [NetProtocol.md](./NetProtocol.md) 首行注释）。所有对象以 `net_id` / 座位号 / 坐标等**稳定标识**传递，应用时反查或重建。
2. **房主权威**：规则协程、随机数播种、任务推进全部运行在房主；客机不跑规则，只呈现。
3. **房主也走客机通道（Loopback）**：房主建监听后，用第二个 `MultiplayerAPI` 自连 `127.0.0.1`，以 `client` 身份跑同一套 UI 刷新与输入回路，保证两端行为一致。
4. **显示世界与权威世界分离**：客机（含环回后的房主）用 `ViewGame` 呈现，`Game` 单例只在权威侧驱动规则；结算时客机再把 ViewGame 结算字段拷回 `Game` 单例。
5. **全量快照 + ctx 复用**：`GameStateSerializer` 每份 `STATE_SNAPSHOT` 都是完整状态；跨快照的对象身份靠调用方持有的 `ctx`（`net_id → 实例`）维持。
6. **隐藏信息不传输**：未揭示牌堆（怪物堆、红/绿/蓝拾荒堆、个人牌堆）只传**大小**，不传牌序；`scavenge` 弃牌堆与手牌因属公开/合作视图而完整传输。

---

## 二、目录与类文档

| 文档 | 类 / 脚本 | 角色 | 生命周期 |
| --- | --- | --- | --- |
| [NetSession.md](./NetSession.md) | `NetSession`（autoload 单例，`net_session.gd`） | 传输/会话/协议层枢纽：ENet peer、消息封包校验、消息分发、房间状态、身份持久化、心跳 | 常驻 autoload |
| [ServerRuntime.md](./ServerRuntime.md) | `ServerRuntime`（`server_runtime.gd`） | 权威游戏规则运行时：开局初始化、真人/AI 输入绑定、EventBus 视觉中继广播 | 每局动态创建 |
| [NetRegistry.md](./NetRegistry.md) | `NetRegistry`（`net_registry.gd`） | 房主权威侧的"唯一事实来源"：房间/玩家/座位/阶段/序号/token | 随会话创建 |
| [GameStateSerializer.md](./GameStateSerializer.md) | `GameStateSerializer`（`game_state_serializer.gd`） | 权威 `Game` ↔ 可传输快照 的双向序列化 | 纯静态工具 |
| [NetInputCodec.md](./NetInputCodec.md) | `NetInputCodec`（`net_input_codec.gd`） | 输入候选/响应的稳定 ID 编解码，对象↔JSON 快照 | 纯静态工具 |
| [NetPlayerInput.md](./NetPlayerInput.md) | `NetworkPlayerInput`（`net_player_input.gd`） | 房主为远程真人座位创建的 `IPlayerInput` 实现 | 每座位一个 |
| [NetClientInput.md](./NetClientInput.md) | `NetClientInput`（`net_client_input.gd`） | 客机侧输入请求适配器：接收请求、UI 应答 | 客机一个 |
| [NetProtocol.md](./NetProtocol.md) | `NetProtocol`（`net_protocol.gd`） | 协议常量、消息信封、通用校验 | 纯静态工具 |
| [NetId.md](./NetId.md) | `NetId`（`net_id.gd`） | 字符串 id 与实体 net_id 分配 | 纯静态工具 |
| [NetViewSync.md](./NetViewSync.md) | `NetViewSync`（`net_view_sync.gd`） | 客机视图序号：快照去旧、事件去重、日志收集 | 纯静态工具 |
| [NetLoopbackRpc.md](./NetLoopbackRpc.md) | `net_loopback_rpc.gd` | 环回客户端 RPC 落点（节点名固定 `NetSession`） | 环回桩节点 |
| [ServerLifetime.md](./ServerLifetime.md) | `ServerLifetime`（`server_lifetime.gd`） | 权威服存活策略常量 | 纯常量类 |

---

## 三、消息信封与消息类型

每条消息由 `NetProtocol.make_message()` 封装为统一信封（详见 [NetProtocol.md](./NetProtocol.md)）：

```
{
  "message_type", "protocol_version", "match_id", "sender_player_id",
  "client_sequence", "server_sequence", "request_id", "payload"
}
```

| 消息类型 | 方向 | 用途 |
| --- | --- | --- |
| `join_request` | 客机→房主 | 加入房间（payload 含 `display_name`） |
| `join_accepted` | 房主→客机 | 回发 `player_id` / `reconnect_token` / `room_snapshot` |
| `reconnect_request` | 客机→房主 | 用 token 重连 |
| `room_snapshot` | 房主→全员 | 大厅状态广播 |
| `room_command` | 客机→房主 | 房间命令：`start` / `bind_seat` / `set_survivor` |
| `input_request` | 房主→指定客机 | 定向输入请求（action/选牌/选目标/confirm 等） |
| `input_response` | 客机→房主 | 输入请求应答 |
| `command_result` | — | 命令结果（预留） |
| `leave_request` | 客机→房主 | 主动离开 |
| `match_start` | 房主→全员 | 开局广播（含 match_id/seed/room_snapshot） |
| `game_event` | 房主→全员 | 权威对局事件（演出/日志/状态反馈） |
| `state_snapshot` | 房主→全员 | 权威对局全量快照 |
| `resync_request` | 客机→房主 | 主动索要全量快照 |
| `heartbeat` | 客机→房主 | 心跳保活 |
| `player_connected` / `player_disconnected` / `player_reconnected` | 房主→全员 | 玩家连接状态广播 |
| `room_closed` | 房主→全员 | 关房（payload `{reason}`） |
| `error` | 房主→客机 | 错误（payload `{code, detail}`） |

---

## 四、关键数据流

### 4.1 建立房间与加入

```
房主 create_host(name, port, seats)
  └─ ENet create_server + registry.create_host()
      └─ _enter_host_loopback()：第二个 MultiplayerAPI 自连 127.0.0.1
客机 join(address, nickname)
  └─ 解析地址 → create_client → 发 join_request
房主 _handle_join → registry.add_player → 回 join_accepted + 广播 room_snapshot
```

### 4.2 开局

```
房主 begin_online_match()
  └─ server_runtime.begin_match_from_lobby()（登记应到真人、start_match、记录 seed）
  └─ 广播 match_start
  └─ wait_until_match_prepared()
        └─ 等真人 peer 绑定齐 / 15s 超时未到者转 AI
        └─ prepare_from_room()：NetId.reset + Game.initialize_from_room_state + _attach_authority_inputs + _connect_visual_relays
```

### 4.3 输入请求-响应（核心回路）

```
[房主] 规则协程调用 NetworkPlayerInput.wait_action/choose_card/...
  └─ _request()：候选对象留本地 selection_map，payload 只含 selection_tokens（下标令牌）
        └─ NetSession.broadcast_input_request(request_id, seat_id, owner_id, type, payload)
              └─ ENet input_request ─▶ [客机]
[客机] NetClientInput._on_message → NetInputCodec.decode(payload, display_game) → requested.emit
  └─ UI（GUIPlayerInput 等）→ NetClientInput.respond()
        └─ _encode_selection_response 把选中对象映射回令牌
        └─ NetSession.send_input_response(request_id, seat_id, value) ─▶ ENet input_response ─▶ [房主]
[房主] NetworkPlayerInput._on_network_message 命中 _pending[request_id] → response_arrived.emit
  └─ 协程恢复 → _resolve_response_value 令牌映射回本地候选对象 → 规则应用
```

旁路：**演出类请求**（show_card、骰子、怪物攻击等）走 `_emit_visual()` → `broadcast_game_event`（`game_event` 单向广播，**不等 ACK**）。

### 4.4 对局状态同步

```
[房主] EventBus 事件 → server_runtime._relay_* → broadcast_game_event
[房主] request_state_snapshot()（每帧最多一份）→ GameStateSerializer.snapshot(Game) → state_snapshot
[客机] NetViewSync.should_apply_snapshot(seq) 去旧 → GameStateSerializer.apply(ViewGame, snapshot, ctx)
[客机] NetViewSync.event_dedup_key 去重 → 驱动演出/日志
```

### 4.5 断线重连与心跳

```
客机 每 5s 发 heartbeat；房主 30s 未活跃的真人玩家 → _drop_remote_player（座位转 AI）
客机对局中断线 → _on_server_disconnected 保留会话等待重连
  └─ reconnect_to_last_room()：保留 token 与 ViewGame，重建 ENet 客机连接
        └─ 发 reconnect_request → 房主校验 token → restore_network_inputs（AI 换回真人输入）
        └─ 回 state_snapshot + 广播 player_reconnected
```

---

## 五、与其他系统的关系

| 系统 | 关系 |
| --- | --- |
| [Game](../../README.md#gamesystem按代码分层) | 权威侧 `Game` 单例由 `ServerRuntime` 驱动并序列化；客机用 ViewGame 呈现，结算回写 |
| [EventBus](../System/EventBus.md) | `ServerRuntime` 把约 26 个游戏事件信号中继为网络 `game_event` |
| [RoomState](../System/RoomState.md) | `NetSession` 双向同步大厅配置（mission/variants/seats） |
| [DataManager](../../Engineering/DataFormat.md) | 校验/获取 survivor、mission、地图块、卡牌静态数据 |
| [PlayerStats](../System/PlayerStats.md) / [StatsTracker](../System/StatsTracker.md) | 统计面板进快照（`to_network_dict` / `apply_network_snapshot`），联机各端只归档自己操作的座位 |
| [IPlayerInput](../../../MxApoc_GDScript/src/ui/i_player_input.gd) | `NetworkPlayerInput` 实现该接口，替代本地 `GUIPlayerInput` 驱动规则 |
| [NetId](../Net/NetId.md) | 实体 net_id 分配（权威侧分配，客机靠快照回填） |

---

## 六、版本历史

| 版本 | tag | 里程碑 | 要点 |
| --- | --- | --- | --- |
| v0.37.0 | `b826eb1` | 建立房间与连接 | 新增 8 个 net 文件；ENet 房主权威、创建/加入/座位绑定/重连握手、输入请求-响应链路、快照+事件同步 |
| v0.37.1 | `e9d520d` | 服务器运行时与快照 | 新增 `ServerRuntime`/`ServerLifetime`；实体 net_id 快照原位应用；房主环回进客机 UI；`GameStateSerializer.apply` |
| v0.37.2 | `ec6c4d6` | 显示世界与视图同步 | 新增 `NetViewSync`/`NetLoopbackRpc`；ViewGame 与权威 Game 分离；环回独立 RPC 树；事件去重；掉线转 AI 可重连 |
| v0.37.3 | `599d6b4` | 权威转播回合/标记/受伤反馈 | `ServerRuntime` 视觉中继扩至约 26 类事件；怪物快照补齐战斗数值 |
| v0.37.4 | `0041daa` | 对局结算闭环 | 结算回大厅；客机结算回写 `Game`；日志同步、角色卡翻面/标记进快照 |
| v0.37.5 | `96299ff` | 断线重连与心跳保活 | 心跳/超时踢离；对局中断线自动重连（≤3 次）；迷你回合预算与选目标战斗字段同步 |
