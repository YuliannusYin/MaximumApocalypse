# NetLoopbackRpc 环回 RPC 桥

> 以 `MxApoc_GDScript/src/net/net_loopback_rpc.gd` 为准（10 行）。
> **无 `class_name`**，`extends Node`，非 autoload——由 `NetSession` `preload` 后实例化挂树。
> 职责：**本机环回客户端 RPC 入口**。节点名必须是 `NetSession`，才能和权威侧相对路径对齐。

---

## 一、方法定义

```gdscript
@rpc("any_peer", "reliable")
func receive_message(message: Dictionary) -> void:
    var session := get_node_or_null("/root/NetSession")
    if session != null and session.has_method("receive_loopback_client_message"):
        session.receive_loopback_client_message(message)
```

- 环回客户端的 RPC 落点：客户端 `rpc_id(1, "receive_message", msg)` 打到这里，转发给权威侧的 `/root/NetSession.receive_loopback_client_message()`。
- `@rpc` 未设 `call_local`，即**仅远端执行**；脚本无业务逻辑，纯转发。

---

## 二、关键业务逻辑

让"房主 + 本机环回客户"模式下，客户端视角的 RPC 流量能到达权威会话。`NetSession` 是 autoload 在 `/root/NetSession`；环回客户端挂在另一棵 `MultiplayerAPI` 下，需要同名节点（`/root/NetLoopbackRoot/NetSession`）保证路径对齐，因此用本脚本作 stub 节点，其节点名固定为 `NetSession`。

---

## 三、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | `preload` 本脚本；`_ensure_loopback_client` 创建 `/root/NetLoopbackRoot` 与挂本脚本、名为 `"NetSession"` 的 stub 节点；权威侧配套方法 `receive_message`（`@rpc("any_peer","reliable")`）与 `receive_loopback_client_message` |
