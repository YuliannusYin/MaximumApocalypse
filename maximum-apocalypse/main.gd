# 游戏主场景脚本，负责开始菜单的按钮响应
extends Node2D

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _on_quit_button_button_down() -> void:
	get_tree().quit()

func _on_start_button_button_down() -> void:
	print("[Main] 开始游戏按钮按下，跳转到选关场景")
	var mission_select_scene = load("res://MissionSelect.tscn")
	get_tree().change_scene_to_packed(mission_select_scene)