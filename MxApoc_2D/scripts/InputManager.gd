#InputManager.gd
extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_MONSTER = 2
const COLLISION_MASK_CARD_DECK = 4
const COLLISION_MASK_MAP_BLOCK = 16
const COLLISION_MASK_MONSTER_CARD = 32


var card_manager_reference
var map_manager_reference
var deck_reference
var monster_deck_reference

func _ready() -> void:
	card_manager_reference = $"../SurvivorCardManager"
	deck_reference = $"../SurvivorDeck"
	map_manager_reference = $"../MapManager"
	monster_deck_reference = $"../MonsterCardDeck"
	
	
func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			emit_signal("left_mouse_button_clicked")
			raycast_at_cursor()
		else:
			emit_signal("left_mouse_button_released")
			
func raycast_at_cursor():
	if card_manager_reference and card_manager_reference.card_being_dragged:
		return
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var result_collision_mask = result[0].collider.collision_mask
		if result_collision_mask == COLLISION_MASK_CARD:
			var card_found = result[0].collider.get_parent()
			if card_found:
				card_manager_reference.start_drag(card_found)
		elif result_collision_mask == COLLISION_MASK_CARD_DECK:
			if deck_reference:
				deck_reference.draw_card()
			else:
				print("错误：InputManager 找不到 Deck 节点，请检查场景树路径！")
		elif result_collision_mask == COLLISION_MASK_MAP_BLOCK:
			#print("map!")
			var map_block = result[0].collider.get_parent()
			# 确保安全转换成功，且地块尚未翻开
			if map_block and not map_block.is_revealed:
				map_block.flip_block()
		elif result_collision_mask == COLLISION_MASK_MONSTER:
			print("点击怪物牌堆")
			if monster_deck_reference:
				monster_deck_reference.draw_monster_card()
			else:
				print("错误：InputManager 找不到 Deck 节点，请检查场景树路径！")
