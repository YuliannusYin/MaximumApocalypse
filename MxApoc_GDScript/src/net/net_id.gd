class_name NetId
extends RefCounted

## 网络实例 id 分配器。
## 主机为每个卡牌/怪物/地块/玩家实例分配唯一的 net_id，
## 客户端据此在快照与输入 RPC 中跨端引用同一实例。

static var _counter := 0


static func next() -> int:
	NetId._counter += 1
	return NetId._counter


## 重置计数器（仅测试用）。
static func reset() -> void:
	NetId._counter = 0
