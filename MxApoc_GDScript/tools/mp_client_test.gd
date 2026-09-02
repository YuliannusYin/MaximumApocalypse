extends Node

## 手动联机客机测试场景：运行 `godot --path . res://tools/mp_client_test.tscn -- <ip> <port>`
## 默认 127.0.0.1:17950。连接主机、完成握手并发送 SEAT_CLAIM（用于真实环境双进程验证）。

func _ready() -> void:
	var ip := "127.0.0.1"
	var port := 17950
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		ip = args[0]
	if args.size() > 1:
		port = int(args[1])
	var err := NetSession.join_host(ip, port, "客机")
	print("[CLIENT] join ip=", ip, " port=", port, " err=", err, " mode=", NetSession.mode)
	NetSession.connected_to_host.connect(func() -> void:
		print("[CLIENT] connected, sending HELLO")
	)
	NetSession.host_ready.connect(func(pid: int, name: String, state: Dictionary) -> void:
		print("[CLIENT] host_ready pid=", pid, " name=", name, " seats=", state.get("seats", "MISSING"))
		NetSession.client_send(NetProtocol.Msg.SEAT_CLAIM, {"seat_index": 1, "survivor_id": "hunter"})
	)
	NetSession.connection_failed.connect(func() -> void:
		print("[CLIENT] connection_failed")
	)
	NetSession.disconnected.connect(func() -> void:
		print("[CLIENT] disconnected")
	)
	NetSession.client_message.connect(func(t: int, d: Dictionary) -> void:
		print("[CLIENT] msg t=", t, " d=", d)
	)
	await get_tree().create_timer(10.0).timeout
	print("[CLIENT] done")
	get_tree().quit()
