extends Node2D

const CARD_SCENE_PATH = "res://scenes/MonsterCard.tscn"

# --- 4x3 网格参数配置 ---
const GRID_COLUMNS = 3       # 每行 3 张牌（3列）
const GRID_ROWS = 4          # 共 4 行
const MAX_ZONE_COUNT = 12    # 4x3 共 12 张牌

const CARD_WIDTH = 80        # 卡牌宽度
const CARD_HEIGHT = 110      # 卡牌高度
const SPACING_X = 1         # 卡牌左右间距
const SPACING_Y = 1         # 卡牌上下间距

# 区域左上角的起始偏移坐标（加了 @export 可以在编辑器检视面板直接调节）
@export var ZONE_OFFSET: Vector2 = Vector2(60, 75)

var player_hand = []

func _ready() -> void:
	pass

func add_card_to_zone(card, speed):

	if card not in player_hand:
		player_hand.append(card)
		update_hand_positions(speed)
	else:
		animate_card_to_position(card, card.card_position, speed)

func update_hand_positions(speed):
	for i in range(player_hand.size()):
		var new_position = calculate_card_position(i)
		var card = player_hand[i]
		card.card_position = new_position
		
		card.z_index = i 
		animate_card_to_position(card, new_position, speed)

# 计算 4x3 网格位置（以 ZONE_OFFSET 为左上角起点）
func calculate_card_position(index: int) -> Vector2:
	# 1. 计算行列号（0~11 映射到 4行 3列）
	var col = index % GRID_COLUMNS          # 列号：0, 1, 2
	var row = index / GRID_COLUMNS          # 行号：0, 1, 2, 3

	# 2. 单个格子所占的总宽/高
	var cell_w = CARD_WIDTH + SPACING_X
	var cell_h = CARD_HEIGHT + SPACING_Y

	# 3. 从起点坐标直接叠加偏移
	var x_pos = ZONE_OFFSET.x + (col * cell_w)
	var y_pos = ZONE_OFFSET.y + (row * cell_h)

	return Vector2(x_pos, y_pos)

func animate_card_to_position(card, new_position, speed):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func remove_card_from_zone(card, speed):
	if card in player_hand:
		player_hand.erase(card)
		update_hand_positions(speed)
