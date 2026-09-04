extends Control

## 加载界面：灰屏 + 中间白色小球旋转 + "加载中..."文字。
## 开局/再开：真正执行 initialize_game，并异步加载下一场景；至少显示 MIN_DURATION。
## 退出：对局场景卸掉后 abort_session，同样至少显示 MIN_DURATION，再进主菜单。

const MIN_DURATION := 0.3
const DOT_COUNT := 5
const DOT_RADIUS := 6.0
const ORBIT_RADIUS := 30.0
const ROTATION_SPEED := 2.0
const SCENE_PATH := "res://scenes/LoadingScreen.tscn"
const GAME_SCENE_PATH := "res://scenes/GameScene2D.tscn"
const MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"

static var _next_scene_path: String = GAME_SCENE_PATH
static var _abort_session: bool = false
static var _prepare_game: bool = false
static var _clear_room: bool = false

var _dot_container: Node2D
var _elapsed: float = 0.0
var _destination: String = GAME_SCENE_PATH
var _should_abort: bool = false
var _should_prepare_game: bool = false
var _should_clear_room: bool = false


## 房间开局：在本页 initialize_game，随后进入 GameScene2D。
static func go_enter_game(tree: SceneTree) -> void:
	_next_scene_path = GAME_SCENE_PATH
	_abort_session = false
	_prepare_game = true
	_clear_room = false
	tree.change_scene_to_file(SCENE_PATH)


## 对局中返回主菜单：卸掉对局场景后清理调度器/旧协程，再进主菜单。
static func go_exit_to_menu(tree: SceneTree) -> void:
	_next_scene_path = MENU_SCENE_PATH
	_abort_session = true
	_prepare_game = false
	_clear_room = true
	tree.change_scene_to_file(SCENE_PATH)


## 结算后再开一局：在本页重新 initialize_game，保留房间选座。
static func go_restart_game(tree: SceneTree) -> void:
	_next_scene_path = GAME_SCENE_PATH
	_abort_session = false
	_prepare_game = true
	_clear_room = false
	tree.change_scene_to_file(SCENE_PATH)


func _ready() -> void:
	_destination = _next_scene_path
	_should_abort = _abort_session
	_should_prepare_game = _prepare_game
	_should_clear_room = _clear_room
	_next_scene_path = GAME_SCENE_PATH
	_abort_session = false
	_prepare_game = false
	_clear_room = false
	_build_ui()
	_run_loading()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	HudTheme.apply_screen_background(bg, Color("#101110"))
	add_child(bg)
	HudTheme.add_wasteland_backdrop(self, bg)

	var frame := Panel.new()
	frame.position = Vector2(555.0, 285.0)
	frame.size = Vector2(320.0, 235.0)
	HudTheme.apply_section_panel(frame, Color("#1d1c18"), HudTheme.GOLD_TEXT_DIM)
	add_child(frame)

	_dot_container = Node2D.new()
	_dot_container.position = Vector2(715.0, 360.0)
	add_child(_dot_container)

	for i in range(DOT_COUNT):
		var dot := ColorRect.new()
		var angle: float = TAU * i / DOT_COUNT
		dot.position = Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS - Vector2(DOT_RADIUS, DOT_RADIUS)
		dot.size = Vector2(DOT_RADIUS * 2.0, DOT_RADIUS * 2.0)
		dot.color = HudTheme.GOLD_TEXT if i % 2 == 0 else HudTheme.TEXT_DIM
		_dot_container.add_child(dot)

	var label := Label.new()
	label.text = "加载中..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(615.0, 430.0)
	label.size = Vector2(200.0, 30.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	add_child(label)


func _run_loading() -> void:
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(_destination)
	if _should_abort and Game != null and is_instance_valid(Game):
		Game.abort_session()
	if _should_clear_room:
		RoomState.clear()
	if _should_prepare_game and Game != null and is_instance_valid(Game):
		Game.initialize_from_room_state()
	while is_inside_tree():
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_destination)
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("LoadingScreen: 无法加载场景 %s" % _destination)
			get_tree().change_scene_to_file(_destination)
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MIN_DURATION:
			var packed: PackedScene = ResourceLoader.load_threaded_get(_destination)
			if packed != null:
				get_tree().change_scene_to_packed(packed)
			else:
				get_tree().change_scene_to_file(_destination)
			return
		await get_tree().process_frame


func _process(delta: float) -> void:
	_elapsed += delta
	if _dot_container != null and is_instance_valid(_dot_container):
		_dot_container.rotation += delta * ROTATION_SPEED
