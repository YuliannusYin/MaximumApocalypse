# ServerLifetime 权威服存活策略

> 以 `MxApoc_GDScript/src/net/server_lifetime.gd` 为准（6 行）。
> `class_name ServerLifetime`，`extends RefCounted`，非 autoload，**纯常量类**（无任何方法）。
> 职责：**权威服存活策略**。第一版只用 `owner`：创建者离开即关服。

---

## 一、常量

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `OWNER` | `"owner"` | 创建者离开即关服（当前唯一实现） |
| `PERSISTENT` | `"persistent"` | 预留的常驻服策略（尚未实现） |

---

## 二、关键业务逻辑

无逻辑，仅作为常量字典存在，为 `ServerRuntime` 提供存活策略枚举值。当前实现 `ServerRuntime.lifetime = ServerLifetime.OWNER`：房主离开时权威端 `close_authority_room("owner_left")` 关闭会话。

---

## 三、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [ServerRuntime](./ServerRuntime.md) | `preload` 本类；`var lifetime: String = ServerLifetime.OWNER` |
