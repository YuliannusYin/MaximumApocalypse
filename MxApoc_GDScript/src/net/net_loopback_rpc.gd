extends Node

## 本机环回客户端 RPC 入口。节点名必须是 NetSession，才能和权威侧相对路径对齐。


@rpc("any_peer", "reliable")
func receive_message(message: Dictionary) -> void:
	var session := get_node_or_null("/root/NetSession")
	if session != null and session.has_method("receive_loopback_client_message"):
		session.receive_loopback_client_message(message)
