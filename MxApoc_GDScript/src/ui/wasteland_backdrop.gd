class_name WastelandBackdrop
extends Control

## 其他场景共用的轻量废土装饰层：透明暗纹、斜向划痕和固定颗粒。
## 仅负责绘制，不拦截鼠标，也不参与任何场景逻辑。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.02, 0.16))
	for i in range(18):
		var y := float(i * 67 - 120)
		draw_line(
			Vector2(-80.0, y),
			Vector2(size.x + 80.0, y + size.x * 0.12),
			Color(0.60, 0.46, 0.28, 0.035),
			2.0
		)
	for i in range(90):
		var px := fmod(float(i * 83 + 19), maxf(size.x, 1.0))
		var py := fmod(float(i * 47 + 23), maxf(size.y, 1.0))
		draw_circle(Vector2(px, py), 1.0 + float(i % 2), Color(0.72, 0.58, 0.36, 0.08))
