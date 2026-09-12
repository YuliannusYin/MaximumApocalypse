# NetId ID 生成与实体编号

> 以 `MxApoc_GDScript/src/net/net_id.gd` 为准（44 行）。
> `class_name NetId`，`extends RefCounted`，非 autoload，**纯静态工具类**。
> 职责：两类 ID——字符串房间/玩家/对局 id（`make_id`）与整数实体 `net_id`（`next`/`assign`）。实体 id 只有权威侧分配，客机靠快照回填，保证多端实体 id 一致。

---

## 一、静态变量

| 变量 | 用途 |
| --- | --- |
| `static var _counter: int = 0` | 字符串 id 序号 |
| `static var _entity_counter: int = 0` | 实体 net_id 递增 |

---

## 二、方法定义（全部 static）

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `make_id` | `make_id(prefix: String) -> String` | 生成 `"<prefix>_<ticks_usec>_<counter>"`（prefix 常见 `"r"`/`"p"`/`"m"`） |
| `next` | `next() -> int` | 实体 net_id 自增并返回（从 1 起） |
| `reset` | `reset() -> void` | 实体计数清零（开局时调用，保证每局 net_id 从 1 起） |
| `should_allocate` | `should_allocate() -> bool` | 决定当前是否分配实体 id（见下） |
| `assign` | `assign(entity: Variant) -> void` | 若 `should_allocate()` 且实体有 `net_id` 属性则赋 `entity.net_id = next()` |

---

## 三、关键业务逻辑（`should_allocate`）

反射式依赖 `/root/NetSession`：

- 有活动 `ServerRuntime` → **始终分配**（v0.37.5 调整，保证房主套 ViewGame 快照时权威 instantiate 拿得到 net_id）。
- `applying_display_snapshot` 或 `session_role=="client"` → **不分配**（客机联机不分配实体 id，等权威快照盖上）。
- 单机 / 本进程权威 / 测试 → 分配。

---

## 四、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetRegistry](./NetRegistry.md) | `make_id("r"/"p"/"m")` 生成房间/玩家/对局 id |
| [ServerRuntime](./ServerRuntime.md) | 开局 `NetId.reset()` |
| 实体层 | `monster_card.gd` / `equipment_card.gd` 调 `NetId.assign(entity)` |
| [NetSession](./NetSession.md) | 反射查 `has_active_server_runtime` / `applying_display_snapshot` / `session_role` |
