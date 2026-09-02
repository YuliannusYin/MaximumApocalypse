extends Node

## 手动联机主机测试场景：运行 `godot --path . res://tools/mp_host_test.tscn -- <port>`
## 默认端口 17950。启动主机后等待客机连接并打印事件（用于真实环境双进程验证）。

func _ready() -> void:
	var port := 17950
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		port = int(args[0])
	var err := NetSession.start_host(port, "主机")
	print("[HOST] start port=", port, " err=", err, " mode=", NetSession.mode, " peer_id=", NetSession.peer_id)
	NetSession.peer_connected.connect(func(pid: int) -> void:
		print("[HOST] peer connected: ", pid)
	)
	NetSession.peer_disconnected.connect(func(pid: int) -> void:
		print("[HOST] peer disconnected: ", pid)
	)
	NetSession.host_message.connect(func(pid: int, t: int, d: Dictionary) -> void:
		print("[HOST] msg pid=", pid, " t=", t, " d=", d)
		if t == NetProtocol.Msg.HELLO:
			NetSession.host_send_to(pid, NetProtocol.Msg.ROOM_STATE, {"room_state": RoomState.to_dict()})
	)
	await get_tree().create_timer(10.0).timeout
	print("[HOST] done")
	get_tree().quit()
