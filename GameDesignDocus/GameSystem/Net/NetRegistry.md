# NetRegistry 房间注册表

> 以 `MxApoc_GDScript/src/net/net_registry.gd` 为准（约 332 行）。
> `class_name NetRegistry`，`extends RefCounted`，非 autoload——由 `NetSession` 实例化持有。
> 职责：**房主权威侧的"唯一事实来源"**——房间信息、玩家、座位、阶段、序号、token。所有大厅/房间状态变更先写 registry，再经 `NetSession` 广播快照。

---

## 一、职责

`NetRegistry` 是房间/玩家/座位的**权威内存模型**，不直接参与网络传输；`snapshot()` 生成可传输的大厅快照（`ROOM_SNAPSHOT` / `JOIN_ACCEPTED.room_snapshot` 的 payload）。

内部 `preload`：`NetProtocol`、`NetId`。

---

## 二、常量

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `MATCH_READY_TIMEOUT_MS` | `15 * 1000` | 对局就绪等待超时（被 `ServerRuntime` 读取） |
| `MAX_PLAYERS` | `6` | 与 `NetProtocol.MAX_PLAYERS` 同值 |

---

## 三、成员变量

| 变量 | 类型 | 用途 |
| --- | --- | --- |
| `room_id` | `String` | 房间 id（`NetId.make_id("r")`） |
| `host_name` | `String` | 房主昵称 |
| `phase` | `String` | `"closed"` / `"lobby"` / `"playing"` |
| `online_multiplayer` | `bool` | 是否联机房间 |
| `port` | `int` | 监听端口 |
| `settings_revision` | `int` | 房间配置版本号 |
| `match_id` | `String` | 对局 id（`NetId.make_id("m")`） |
| `match_seed` | `int` | 对局随机种子 |
| `server_sequence` | `int` | 服务器快照自增序号 |
| `mission_mode` | `String` | 任务模式，默认 `"random"` |
| `mission_id` | `int` | 任务 id，默认 -1 |
| `variants` | `Dictionary` | 变体配置 |
| `players` | `Dictionary` | 以 player_id 为 key 的玩家表 |
| `seats` | `Array` | 座位数组 |

**players 单条记录**：`{player_id, display_name, peer_id, reconnect_token_hash, connection_state("connected"/"disconnected"), seat_ids: [], is_host: bool, last_seen_ms}`。

**seats 单条记录**：`{seat_id, controller_id, control_mode("human"/"ai"), survivor_id, survivor_name, is_ready}`。

---

## 四、方法定义

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `create_host` | `create_host(name: String, listen_port: int, configured_seats: Array) -> Dictionary` | 建房间：生成 room_id/token、登记房主（peer_id=1）、布置座位；返回 `{player_id, reconnect_token}` |
| `add_player` | `add_player(display_name: String, peer_id: int) -> Dictionary` | 大厅加人：校验 `phase=="lobby"` 与人数上限；返回 `{player_id, reconnect_token}`，失败返回 `{}` |
| `disconnect_player` | `disconnect_player(player_id: String) -> void` | 断线：peer_id 清零、状态置 `disconnected`，其座位 `control_mode` 改 `"ai"` |
| `touch_last_seen` | `touch_last_seen(player_id: String) -> void` | 刷新存活时间戳 |
| `player_has_human_seat` | `player_has_human_seat(player_id: String) -> bool` | 是否拥有真人座位 |
| `stale_connected_guest_ids` | `stale_connected_guest_ids(now_ms: int, timeout_ms: int) -> Array` | 筛出"已连接、非房主、有真人座位、超时未活跃"的玩家 id（心跳踢人用） |
| `clear_live_peer` | `clear_live_peer(player_id: String) -> void` | **开局移交**：清掉 listener 座位上的 peer_id==1，不判掉线、不改座位 |
| `connected_human_player_ids` | `connected_human_player_ids() -> Array` | 所有"已连接且有真人座位"的 player_id（开局应到名单） |
| `is_player_live_bound` | `is_player_live_bound(player_id: String) -> bool` | 是否仍有活跃连接绑定（`peer_id > 1`） |
| `convert_unbound_human_to_ai` | `convert_unbound_human_to_ai(player_id: String) -> void` | 无绑定真人转 AI：断开 + 座位改 `ai` |
| `room_owner_player_id` | `room_owner_player_id() -> String` | 找 `is_host==true` 的玩家 |
| `reconnect_player_by_token` | `reconnect_player_by_token(token: String, peer_id: int) -> String` | 校验 token 后恢复玩家连接并把座位改回 `human`；返回 player_id 或空 |
| `player_id_for_token` | `player_id_for_token(token: String) -> String` | 遍历 players 比对 token 哈希 |
| `can_reconnect` | `can_reconnect(player_id: String) -> bool` | 是否有未过期的重连 token |
| `reconnect_error_for_token` | `reconnect_error_for_token(token: String) -> String` | 返回 `ERROR_INVALID_TOKEN` / `ERROR_TOKEN_EXPIRED` / 空串 |
| `bind_seat` | `bind_seat(seat_id: int, controller_id: String, survivor_id: String, is_ai: bool = false) -> bool` | 大厅绑座：校验阶段/下标/玩家存在/幸存者唯一；写座位并 `settings_revision += 1` |
| `set_seat_survivor` | `set_seat_survivor(seat_id: int, survivor_id: String) -> bool` | 选角色：查重，空 survivor 则 `is_ready=false` |
| `replace_seats` | `replace_seats(configured_seats: Array, default_controller_id: String = "") -> void` | 整体重建座位 |
| `set_room_config` | `set_room_config(new_mission_mode: String, new_mission_id: int, new_variants: Dictionary) -> void` | 改任务配置 |
| `set_phase` | `set_phase(next_phase: String) -> void` | 切阶段 |
| `start_match` | `start_match(seed_value: int = -1) -> void` | 开局：`phase="playing"`、生成 match_id、seed、`server_sequence=0` |
| `next_server_sequence` | `next_server_sequence() -> int` | 服务器序号自增并返回 |
| `snapshot` | `snapshot(include_tokens: bool = false) -> Dictionary` | 生成房间快照 |

**私有方法**：`_set_seats`（按配置建座位）、`_rebuild_player_seat_ids`（重算玩家 `seat_ids`）、`_make_token`（`"%s-%s-%s" % [randi(), ticks_usec, randi()]`）、`_hash_token`（`Marshalls.utf8_to_base64(token.sha256_text())`，**只存哈希不存明文**）、`_player_has_human_seat`。

---

## 五、快照结构（`snapshot()`）

```
{
  "protocol_version": NetProtocol.VERSION,
  "room_id", "host_name", "online_multiplayer", "port", "phase",
  "max_seats": NetProtocol.MAX_SEATS,
  "match_id", "match_seed",
  "mission": {"mode", "mission_id"},
  "variants", "settings_revision", "server_sequence",
  "players": [ {player_id, display_name, peer_id, connection_state, seat_ids, is_host, last_seen_ms} ],
  "seats": [ {seat_id, controller_id, control_mode, survivor_id, survivor_name, is_ready} ]
}
```

注意：`reconnect_token_hash` 恒被擦除；`reconnect_token` 仅在 `include_tokens=true` 时保留。

---

## 六、关键业务逻辑

- **token 只存哈希**：`_hash_token` 用 SHA256 后 base64，杜绝明文泄露；重连时 `reconnect_player_by_token` 比对哈希。
- **开局移交**：`clear_live_peer` 清掉 listener 座位上的旧 peer 1，使房主可经环回以新连接身份回归。
- **掉线即转 AI**：`disconnect_player` / `convert_unbound_human_to_ai` 让失联座位由 AI 接管，规则不停摆。

---

## 七、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | 全量调用 registry 方法并广播快照 |
| [ServerRuntime](./ServerRuntime.md) | 读 `MATCH_READY_TIMEOUT_MS`，调 `start_match` / `connected_human_player_ids` / `clear_live_peer` / `is_player_live_bound` |
| [NetProtocol](./NetProtocol.md) | `DEFAULT_PORT` / `MAX_SEATS` / `VERSION` / `normalize_nickname` / 错误码 |
| [NetId](./NetId.md) | `make_id("r"/"p"/"m")` 生成 id |
