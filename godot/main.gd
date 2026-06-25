# [新增] 2026-06-24: 游戏主场景脚本，负责开始菜单的按钮响应
extends Node2D


# [新增] 2026-06-24: 场景进入时初始化
func _ready() -> void:
	pass # Replace with function body.


# [新增] 2026-06-24: 每帧更新（未使用delta参数）
func _process(_delta: float) -> void:
	pass


# [新增] 2026-06-24: 退出按钮点击响应，关闭游戏
func _on_quit_button_button_down() -> void:
	pass # Replace with function body.	
	get_tree().quit()


# [新增] 2026-06-24: 开始游戏按钮点击响应，切换到游戏场景
func _on_start_button_button_down() -> void:
	pass # Replace with function body.
	#get_tree().change_scene_to_file("res://godot/game.tscn")
	var scene_game = preload("res://godot/game.tscn")
	print("开始游戏按钮按下")
	get_tree().change_scene_to_packed(scene_game)