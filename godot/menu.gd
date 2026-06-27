# [新增] 2026-06-24: 主菜单脚本，处理开始游戏和退出游戏的逻辑
extends Control

# 开始按钮引用
@onready var start_button: Button = $MainContainer/ButtonContainer/StartButtonContainer/StartButton
# 退出按钮引用
@onready var exit_button: Button = $MainContainer/ButtonContainer/ExitButtonContainer/ExitButton
# 标题引用
@onready var title_label: Label = $MainContainer/Title
# 装饰元素引用
@onready var ruins_icon: TextureRect = $Decorations/RuinsIcon
@onready var zombie_icon: TextureRect = $Decorations/ZombieIcon
@onready var survivor_icon: TextureRect = $Decorations/SurvivorIcon
# 按钮图标引用
@onready var start_icon: TextureRect = $MainContainer/ButtonContainer/StartButtonContainer/StartIcon
@onready var exit_icon: TextureRect = $MainContainer/ButtonContainer/ExitButtonContainer/ExitIcon


# [新增] 2026-06-24: 初始化菜单
func _ready() -> void:
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

	# 播放标题出现动画
	_play_title_animation()

	# 播放装饰元素动画
	_play_decoration_animations()


# [新增] 2026-06-24: 播放标题出现动画
func _play_title_animation() -> void:
	# 初始状态：透明且向上偏移
	title_label.modulate.a = 0.0
	title_label.position.y -= 30

	# 创建动画
	var tween := create_tween()
	tween.set_parallel(true)

	# 渐入效果
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 下移效果
	tween.tween_property(title_label, "position:y", title_label.position.y + 30, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# [新增] 2026-06-24: 播放装饰元素动画
func _play_decoration_animations() -> void:
	# 废墟图标：缓慢飘动
	var ruins_tween := create_tween()
	ruins_tween.set_loops()
	ruins_tween.tween_property(ruins_icon, "position:y", ruins_icon.position.y + 10, 2.0).set_ease(Tween.EASE_IN_OUT)
	ruins_tween.tween_property(ruins_icon, "position:y", ruins_icon.position.y - 10, 2.0).set_ease(Tween.EASE_IN_OUT)

	# 僵尸图标：缓慢移动
	var zombie_tween := create_tween()
	zombie_tween.set_loops()
	zombie_tween.tween_property(zombie_icon, "position:x", zombie_icon.position.x + 5, 3.0).set_ease(Tween.EASE_IN_OUT)
	zombie_tween.tween_property(zombie_icon, "position:x", zombie_icon.position.x - 5, 3.0).set_ease(Tween.EASE_IN_OUT)

	# 求生者图标：轻微旋转
	var survivor_tween := create_tween()
	survivor_tween.set_loops()
	survivor_tween.tween_property(survivor_icon, "rotation", 0.05, 4.0).set_ease(Tween.EASE_IN_OUT)
	survivor_tween.tween_property(survivor_icon, "rotation", -0.05, 4.0).set_ease(Tween.EASE_IN_OUT)


# [新增] 2026-06-24: 开始按钮点击事件
func _on_start_button_pressed() -> void:
	# TODO: 切换到游戏主场景
	# 目前只是打印日志
	print("开始游戏按钮被点击")

	# 示例：切换到游戏场景（需要先创建游戏场景）
	# get_tree().change_scene_to_file("res://godot/game.tscn")


# [新增] 2026-06-24: 退出按钮点击事件
func _on_exit_button_pressed() -> void:
	# 退出游戏
	get_tree().quit()
