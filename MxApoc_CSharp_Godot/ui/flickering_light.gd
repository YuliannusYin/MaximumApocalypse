# [新增] 2026-06-24: 灯光闪烁效果脚本
extends PointLight2D

# 闪烁频率
@export var flicker_frequency: float = 2.0
# 闪烁强度范围
@export var flicker_min: float = 0.5
@export var flicker_max: float = 1.5
# 颜色变化强度
@export var color_variation: float = 0.1

# 基础能量
var base_energy: float
# 基础颜色
var base_color: Color


# [新增] 2026-06-24: 初始化灯光
func _ready() -> void:
	base_energy = energy
	base_color = color

	# 开始闪烁动画
	_start_flickering()


# [新增] 2026-06-24: 开始闪烁动画
func _start_flickering() -> void:
	var tween := create_tween()
	tween.set_loops()

	# 闪烁循环
	while true:
		# 随机闪烁强度
		var target_energy = randf_range(flicker_min, flicker_max) * base_energy
		var duration = randf_range(0.1, 0.5)

		tween.tween_property(self, "energy", target_energy, duration).set_ease(Tween.EASE_IN_OUT)

		# 随机颜色变化
		var color_offset = Color(
			randf_range(-color_variation, color_variation),
			randf_range(-color_variation, color_variation),
			randf_range(-color_variation, color_variation),
			0.0
		)
		var target_color = base_color + color_offset

		tween.parallel().tween_property(self, "color", target_color, duration).set_ease(Tween.EASE_IN_OUT)

		# 等待一段时间
		await tween.finished
		await get_tree().create_timer(randf_range(0.05, 0.2)).timeout