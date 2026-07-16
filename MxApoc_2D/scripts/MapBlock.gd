# MapBlock.gd
extends Node2D

## 当地块被成功翻开时发射，将地块自身作为参数传递
signal flipped

## 缩放配置常量
const SCALE_DEFAULT = Vector2(1.0, 1.0)
const SCALE_HOVER = Vector2(1.1, 1.1) # 悬停放大 10%
const TWEEN_DURATION = 0.2             # 渐变时间（秒）

## 地块状态属性
var is_revealed: bool = false
var grid_pos: Vector2i = Vector2i.ZERO

# 自动获取视觉容器节点
@onready var visual_container: Node2D = $VisualContainer
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var image_sprite: Sprite2D = $VisualContainer/Image 

var scale_tween: Tween

var block_data: Dictionary = {
	"name": "",
	"colors": [],
	"number": -1,
	"raw_filename": "" 
}


func _ready() -> void:
	# 🟢 注意：如果一上来就被 reveal_instantly 设为了 true，不要覆盖重置它
	if not is_revealed:
		is_revealed = false
	visual_container.scale = SCALE_DEFAULT


## 鼠标进入：无论翻开与否，都平滑放大视觉容器
func _on_area_2d_mouse_entered() -> void:
	if anim_player.is_playing() and anim_player.current_animation == "map_flip":
		return
	_animate_scale(SCALE_HOVER)


## 鼠标移出：无论翻开与否，都平滑缩小视觉容器
func _on_area_2d_mouse_exited() -> void:
	_animate_scale(SCALE_DEFAULT)


## 供 InputManager 射线检测点击后进行【带动画】翻牌
func flip_block() -> void:
	if is_revealed:
		return
		
	is_revealed = true
	
	# 1. 翻牌前，先安全停止缩放渐变，强制恢复默认大小
	_kill_active_tween()
	visual_container.scale = SCALE_DEFAULT
	
	# 2. 播放翻牌动画
	if anim_player.has_animation("map_flip"):
		anim_player.play("map_flip")
	
	flipped.emit()


## 🟢 新增：供 MapManager 开局直接翻开起点和终点地块使用（免动画）
func reveal_instantly() -> void:
	is_revealed = true
	_kill_active_tween()
	visual_container.scale = SCALE_DEFAULT
	
	# 避开开局动画。直接将动画拉到终点，或者直接调用展示状态
	if anim_player.has_animation("map_flip"):
		anim_player.play("map_flip")
		anim_player.advance(10.0) # 🟢 推进播放时间，让动画瞬间播完停在最后一帧


## 供 MapManager 初始化该地块数据使用
func initialize(data: Dictionary) -> void:
	block_data = data
	_update_visuals()


## 内部辅助：根据数据更新卡面文本与图片
func _update_visuals() -> void:
	# 双保险：如果 image_sprite 依然为 null（极端情况），手动获取一次节点
	if not image_sprite:
		image_sprite = $VisualContainer/Image
		
	if image_sprite and block_data.raw_filename != "":
		# 拼装绝对路径
		var texture_path = "res://images/图包/地图块图包/" + block_data.raw_filename + ".png"
		
		if ResourceLoader.exists(texture_path):
			image_sprite.texture = load(texture_path)
		else:
			push_error("❌ 找不到图片资源，请检查路径是否完全一致: " + texture_path)
	else:
		print("⚠️ 无法加载：image_sprite 为 null 或没有 raw_filename")


## 内部辅助：执行平滑缩放（仅作用于 visual_container）
func _animate_scale(target_scale: Vector2) -> void:
	_kill_active_tween()
	scale_tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_SINE)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(visual_container, "scale", target_scale, TWEEN_DURATION)


## 内部辅助：安全清理 Tween
func _kill_active_tween() -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
