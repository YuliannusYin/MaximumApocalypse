extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	var scene_game = preload("res://godot/menu.tscn")
	get_tree().change_scene_to_packed(scene_game)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_quit_button_button_down() -> void:
	pass # Replace with function body.	
	get_tree().quit()


func _on_start_button_button_down() -> void:
	pass # Replace with function body.
	#get_tree().change_scene_to_file("res://godot/game.tscn")
	var scene_game = preload("res://godot/menu.tscn")
	get_tree().change_scene_to_packed(scene_game)
