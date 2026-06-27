extends Node2D

signal characters_selected(character_ids: Array[String])

var available_characters: Array[PlayerData] = []
var selected_characters: Array[String] = []
var character_buttons: Array[Button] = []
var selected_count_label: Label
var confirm_button: Button
var min_players: int = 1
var max_players: int = 4

func _ready() -> void:
	print("[CharacterSelect] 角色选择场景初始化...")
	load_all_characters()
	display_character_list()
	create_ui_elements()

func load_all_characters() -> void:
	var characters_folder = "res://data/characters/"
	var dir = DirAccess.open(characters_folder)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var clean_name = file_name.replace(".remap", "")
				var full_path = characters_folder + clean_name
				var res = load(full_path)
				if res is PlayerData:
					available_characters.append(res)
					print("[CharacterSelect] 加载角色: " + res.character_name)
			file_name = dir.get_next()
	else:
		push_error("[CharacterSelect] 无法打开角色文件夹: " + characters_folder)

func display_character_list() -> void:
	var start_y = 100
	var button_height = 50
	var spacing = 10

	for i in range(available_characters.size()):
		var character = available_characters[i]
		var btn = Button.new()
		btn.text = character.character_name + " (HP: " + str(character.max_hp) + ")"
		btn.position = Vector2(200, start_y + i * (button_height + spacing))
		btn.size = Vector2(300, button_height)

		btn.pressed.connect(_on_character_button_pressed.bind(character.id))

		add_child(btn)
		character_buttons.append(btn)

func create_ui_elements() -> void:
	# 已选择数量标签
	selected_count_label = Label.new()
	selected_count_label.text = "已选择: 0/" + str(max_players) + " 角色"
	selected_count_label.position = Vector2(200, 500)
	selected_count_label.add_theme_font_size_override("font_size", 16)
	add_child(selected_count_label)

	# 确认按钮
	confirm_button = Button.new()
	confirm_button.text = "开始游戏"
	confirm_button.position = Vector2(200, 550)
	confirm_button.size = Vector2(200, 50)
	confirm_button.disabled = true  # 初始禁用
	confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(confirm_button)

	# 提示文本
	var hint_label = Label.new()
	hint_label.text = "选择 " + str(min_players) + "-" + str(max_players) + " 个角色开始游戏"
	hint_label.position = Vector2(200, 50)
	hint_label.add_theme_font_size_override("font_size", 18)
	add_child(hint_label)

func _on_character_button_pressed(character_id: String) -> void:
	# 如果已选择，取消选择
	if selected_characters.has(character_id):
		selected_characters.erase(character_id)
		print("[CharacterSelect] 取消选择角色: " + character_id)
	else:
		# 如果未达到上限，添加选择
		if selected_characters.size() < max_players:
			selected_characters.append(character_id)
			print("[CharacterSelect] 选择角色: " + character_id)
		else:
			print("[CharacterSelect] 已达到角色上限")
			return

	# 更新UI
	update_selection_ui()

func update_selection_ui() -> void:
	selected_count_label.text = "已选择: " + str(selected_characters.size()) + "/" + str(max_players) + " 角色"

	# 更新按钮状态
	for btn in character_buttons:
		var character_id = _get_character_id_from_button(btn)
		if selected_characters.has(character_id):
			btn.modulate = Color(0.5, 0.8, 0.5)  # 已选择显示绿色
		else:
			btn.modulate = Color(1, 1, 1)  # 未选择显示白色

	# 更新确认按钮
	confirm_button.disabled = selected_characters.size() < min_players

func _get_character_id_from_button(btn: Button) -> String:
	# 从按钮文本提取角色ID（需要遍历角色数据）
	for character in available_characters:
		if btn.text.contains(character.character_name):
			return character.id
	return ""

func _on_confirm_pressed() -> void:
	print("[CharacterSelect] 确认选择角色: " + str(selected_characters))
	characters_selected.emit(selected_characters)

	# 保存选择的角色到GameState
	GameState.selected_character_ids = selected_characters

	# 切换到游戏场景
	var game_scene = load("res://game.tscn")
	get_tree().change_scene_to_packed(game_scene)