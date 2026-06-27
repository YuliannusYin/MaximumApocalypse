extends Node2D

signal mission_selected(mission_data: MissionData)

var available_missions: Array[MissionData] = []
var mission_buttons: Array[Button] = []

func _ready() -> void:
	print("[MissionSelect] 选关场景初始化...")
	load_all_missions()
	display_mission_list()

func load_all_missions() -> void:
	var missions_folder = "res://godot/data/missions/"
	var dir = DirAccess.open(missions_folder)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var clean_name = file_name.replace(".remap", "")
				var full_path = missions_folder + clean_name
				var res = load(full_path)
				if res is MissionData:
					available_missions.append(res)
					print("[MissionSelect] 加载任务: " + res.mission_name)
			file_name = dir.get_next()
	else:
		push_error("[MissionSelect] 无法打开任务文件夹: " + missions_folder)

func display_mission_list() -> void:
	var start_y = 100
	var button_height = 60
	var spacing = 10
	
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var btn = Button.new()
		btn.text = mission.mission_name + " (" + mission.difficulty + ")"
		btn.position = Vector2(200, start_y + i * (button_height + spacing))
		btn.size = Vector2(400, button_height)
		
		btn.pressed.connect(_on_mission_button_pressed.bind(mission))
		
		add_child(btn)
		mission_buttons.append(btn)

func _on_mission_button_pressed(mission: MissionData) -> void:
	print("[MissionSelect] 选择任务: " + mission.mission_name)

	# 保存选中的关卡到GameState
	GameState.selected_mission = mission

	# 切换到角色选择场景
	var character_select_scene = load("res://godot/CharacterSelect.tscn")
	get_tree().change_scene_to_packed(character_select_scene)