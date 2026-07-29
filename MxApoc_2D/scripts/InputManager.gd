#InputManager.gd
extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_MONSTER = 2
const COLLISION_MASK_CARD_DECK = 4
const COLLISION_MASK_MAP_BLOCK = 16
const COLLISION_MASK_MONSTER_CARD = 32
const COLLISION_MASK_SCAVENGE_CARD = 64
const COLLISION_MASK_SCAVENGE_DECK = 128

var card_manager_reference
var map_manager_reference
var deck_reference
var monster_deck_reference
var scavenge_manager_reference
var scavenge_deck_reference

func _ready() -> void:
	card_manager_reference = $"../SurvivorCardManager"
	deck_reference = $"../SurvivorDeck"
	map_manager_reference = $"../MapManager"
	monster_deck_reference = $"../MonsterCardDeck"
	scavenge_manager_reference = $"../ScavengeCardManager"
	scavenge_deck_reference = $"../ScavengeDeck"
	
	
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
	if scavenge_manager_reference and scavenge_manager_reference.card_being_dragged:
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
			#print("点击怪物牌堆")
			if monster_deck_reference:
				monster_deck_reference.draw_monster_card()
			else:
				print("错误：InputManager 找不到 Deck 节点，请检查场景树路径！")
		elif result_collision_mask == COLLISION_MASK_MONSTER_CARD:
			print("点击怪物牌")
		elif result_collision_mask == COLLISION_MASK_SCAVENGE_CARD:
			# 点击手牌中的拾荒牌 → 开始拖拽
			var scavenge_card = result[0].collider.get_parent()
			if scavenge_card and scavenge_manager_reference:
				scavenge_manager_reference.start_drag(scavenge_card)
		elif result_collision_mask == COLLISION_MASK_SCAVENGE_DECK:
			# 获取点击到的具体 CollisionShape2D 节点
			var area = result[0].collider
			var shape_owner_id = area.shape_find_owner(result[0].shape)
			var shape_node = area.shape_owner_get_owner(shape_owner_id)
			
			if shape_node and scavenge_deck_reference:
				var color = ""
				# 根据你的节点名对应颜色
				match shape_node.name:
					"CollisionShape2D":
						color = "red"
					"CollisionShape2D2":
						color = "green"
					"CollisionShape2D3":
						color = "blue"
				
				if color != "":
					scavenge_deck_reference.draw_scavenge_card(color)
				else:
					print("【错误】未识别的 CollisionShape2D 名称: ", shape_node.name)
