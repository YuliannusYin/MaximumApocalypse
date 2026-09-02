class_name NetProtocol
extends RefCounted

## 网络协议定义：消息类型常量。
## 实际传输基于 Godot 内置 Multiplayer（SceneMultiplayer + ENetMultiplayerPeer），
## 消息以 RPC 方法参数形式传递（见 NetSession._recv_host_message / _recv_client_message）。

enum Msg {
	HELLO,          ## 客机 -> 主机 握手：{name, version}
	HELLO_ACK,      ## 主机 -> 客机 握手确认：{peer_id, player_name, room_state}
	ROOM_STATE,     ## 主机 -> 客机 房间状态广播：{room_state}
	SEAT_CLAIM,     ## 客机 -> 主机 认领/放弃座位：{seat_index, survivor_id}
	START_GAME,     ## 主机 -> 客机 开始游戏：{}
	HEARTBEAT,      ## 双向 心跳保活：{}
	DISCONNECT,     ## 双向 主动断开：{reason}
	INPUT_REQUEST,  ## 主机 -> 客机 请求玩家决策（阶段二）：{req_id, type, ...}
	INPUT_RESPONSE, ## 客机 -> 主机 决策回复（阶段二）：{req_id, choice}
	SNAPSHOT,       ## 主机 -> 客机 全量状态快照（阶段二）：{state}
	GAME_EVENT,     ## 主机 -> 客机 游戏事件通知（阶段二）：{event, ...}
	GAME_OVER,      ## 主机 -> 客机 游戏结束（阶段二）：{result, stats}
}

## 协议版本号，握手时校验，不匹配则拒绝连接。
const PROTOCOL_VERSION := 1
