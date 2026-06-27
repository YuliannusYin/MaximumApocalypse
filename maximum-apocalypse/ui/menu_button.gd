# [新增] 2026-06-24: 自定义菜单按钮，实现悬停、点击和出现动画效果
extends Button

# 按钮文字
@export var button_text: String = "按钮":
	set(value):
		button_text = value
		text = value

# 出现动画延迟
@export var appear_delay: float = 0.0

# 着色器材质引用
var shader_material: ShaderMaterial

# 动画引用
var appear_tween: Tween
var hover_tween: Tween
var click_tween: Tween


# [新增] 2026-06-24: 初始化按钮
func _ready() -> void:
	# 设置按钮文字
	text = button_text

	# 获取着色器材质
	if material is ShaderMaterial:
		shader_material = material
		shader_material.set_shader_parameter("hover_intensity", 0.0)
		shader_material.set_shader_parameter("click_intensity", 0.0)

	# 初始状态：透明且缩小
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	# 连接信号
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# 延迟播放出现动画
	if appear_delay > 0.0:
		await get_tree().create_timer(appear_delay).timeout
	_play_appear_animation()


# [新增] 2026-06-24: 播放出现动画
func _play_appear_animation() -> void:
	if appear_tween:
		appear_tween.kill()

	appear_tween = create_tween()
	appear_tween.set_parallel(true)

	# 渐入效果
	appear_tween.tween_property(self, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 缩放效果
	appear_tween.tween_property(self, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


# [新增] 2026-06-24: 鼠标进入事件
func _on_mouse_entered() -> void:
	if shader_material:
		if hover_tween:
			hover_tween.kill()

		hover_tween = create_tween()
		hover_tween.tween_method(_set_hover_intensity, 0.0, 1.0, 0.2)


# [新增] 2026-06-24: 鼠标离开事件
func _on_mouse_exited() -> void:
	if shader_material:
		if hover_tween:
			hover_tween.kill()

		hover_tween = create_tween()
		hover_tween.tween_method(_set_hover_intensity, shader_material.get_shader_parameter("hover_intensity"), 0.0, 0.2)


# [新增] 2026-06-24: 按钮按下事件
func _on_button_down() -> void:
	if shader_material:
		if click_tween:
			click_tween.kill()

		click_tween = create_tween()
		click_tween.tween_method(_set_click_intensity, 0.0, 1.0, 0.1)


# [新增] 2026-06-24: 按钮释放事件
func _on_button_up() -> void:
	if shader_material:
		if click_tween:
			click_tween.kill()

		click_tween = create_tween()
		click_tween.tween_method(_set_click_intensity, shader_material.get_shader_parameter("click_intensity"), 0.0, 0.15)


# [新增] 2026-06-24: 设置悬停强度
func _set_hover_intensity(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("hover_intensity", value)


# [新增] 2026-06-24: 设置点击强度
func _set_click_intensity(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("click_intensity", value)