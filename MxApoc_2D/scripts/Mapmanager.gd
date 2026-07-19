# MapManager.gd
extends Node2D
class_name MapManager

@export var cell_scene: PackedScene
@export var is_random: bool = true          
@export var cell_offset: Vector2 = Vector2(65.0, 65.0) 
@export var map_offset: Vector2 = Vector2(0.0, -60)


const MAPBLOCKS = [
	'军事基地[红、蓝][0]', '农场[绿][11]', '农场[绿][3]',
	'加油站[红][4]', '加油站[红][5]', '加油站[红][9]', '医院[红][3]',
	'坠毁点[][10]', '城市街道[红][6]', '城市街道[绿][8]', '城市街道[蓝][5]',
	'墓地[][4]', '山[][3]', '山[][9]', '工厂[蓝][4]', '强盗营地[][3]',
	'强盗营地[][9]', '旷野[][6]', '旷野[][8]', '机场[红、绿][8]', '森林[][5]',
	'森林[][8]', '沙漠[][10]', '沙漠[][4]', '河流[][10]', '河流[][11]',
	'游乐场[红、绿、蓝][6]', '电厂[][10]', '百货商店[绿][9]', '监狱[红、绿、蓝][9]',
	'绿洲[][11]', '警察局[蓝][6]', '购物中心[蓝][8]', '避难所[][12]',
	'避难所[][2]', '隧道[][10]', '隧道[][4]', '面包车[][6]'
]

var map_blocks_config = {
	"面包车": 1, "加油站": 2, "旷野": 2, "避难所": 1, "山": 2,
	"百货商店": 1, "机场": 1, "隧道": 2, "警察局": 1, "工厂": 1,
	"森林": 2, "医院": 1, "军事基地": 1, "城市街道": 2, "强盗营地": 1,
	"监狱": 1, "农场": 2, "沙漠": 1
}

var map_layout = [
	[-1, -1, -1, -1, -1, 1, 1, 2],
	[-1, -1, -1, -1, -1, 1, -1, 1],
	[-1, -1, -1, -1, 1, 1, 1, 1],
	[-1, -1, -1, 1, 3, 1, -1, -1],
	[-1, 3, 1, 1, 1, -1, -1, -1],
	[1, 1, -1, 1, -1, -1, -1, -1],
	[1, -1, 1, 3, -1, -1, -1, -1],
	[0, 1, 1, -1, -1, -1, -1, -1]
]

var all_blocks_database: Dictionary = {}
var map_data: Dictionary = {}


func _ready() -> void:
	if not cell_scene:
		push_error("MapManager: 尚未绑定 cell_scene 属性！")
		return
		
	_parse_all_database()
	generate_map()
	center_map_in_screen()
	
	get_tree().root.size_changed.connect(center_map_in_screen)


func _parse_all_database() -> void:
	all_blocks_database.clear()
	var regex = RegEx.new()
	regex.compile("^([^\\[]+)\\[([^\\]]*)\\]\\[(\\d+)\\]")
	
	for block_raw in MAPBLOCKS:
		var clean_str = block_raw.strip_edges()
		var result = regex.search(clean_str)
		if result:
			# 🟢 修正：对解析出来的键名和颜色等做 strip_edges() 处理，防止读取带有空格的文件名
			var block_name = result.get_string(1).strip_edges()
			var colors_raw = result.get_string(2).strip_edges()
			var number_val = result.get_string(3).to_int()
			
			var colors_array = []
			if colors_raw != "":
				colors_array = colors_raw.split("、")
				for i in range(colors_array.size()):
					colors_array[i] = colors_array[i].strip_edges()
				
			var data = {
				"name": block_name,
				"colors": colors_array,
				"number": number_val,
				"raw_filename": block_raw # 🟢 保持原始带空格的名字用作图片匹配
			}
			
			if not all_blocks_database.has(block_name):
				all_blocks_database[block_name] = []
			all_blocks_database[block_name].append(data)


func generate_map() -> void:
	for child in get_children():
		child.queue_free()
	map_data.clear()
	# 用于记录哪些地块需要后续翻开
	var blocks_to_reveal: Array[Node2D] = []
	# 🟢 分流池：起点与终点不应该进入被 shuffle 的公共池
	var spawn_pool: Array[Dictionary] = []       # 面包车 0
	var game_end_pool: Array[Dictionary] = []    # 军事基地 2
	var random_block_pool: Array[Dictionary] = [] # 其他所有随机块 1, 3
	
	for block_name in map_blocks_config.keys():
		var required_count = map_blocks_config[block_name]
		if all_blocks_database.has(block_name):
			var templates = all_blocks_database[block_name].duplicate()
			for i in range(required_count):
				var block_data = {}
				if templates.size() > 0:
					block_data = templates.pop_back()
				else:
					block_data = all_blocks_database[block_name][0].duplicate()
				
				# 分类装箱
				if block_name == "面包车":
					spawn_pool.append(block_data)
				elif block_name == "军事基地":
					game_end_pool.append(block_data)
				else:
					random_block_pool.append(block_data)

	if is_random:
		random_block_pool.shuffle()

	var rows = map_layout.size()
	for y in range(rows):
		var cols = map_layout[y].size()
		for x in range(cols):
			var tile_type = map_layout[y][x]
			if tile_type == -1:
				continue
				
			var block_instance = cell_scene.instantiate()
			if not block_instance:
				continue
				
			var current_grid_pos = Vector2i(x, y)
			block_instance.grid_pos = current_grid_pos
			block_instance.position = Vector2(x * cell_offset.x, y * cell_offset.y)
			
			var block_data = {"name": "空地", "colors": [], "number": 0, "raw_filename": ""}
			var should_reveal = false # 🟢 控制是否一开始就翻开
			
			# 🟢 按照 map_layout 的类型精准配对地块
			match tile_type:
				0: # 起点 (面包车)
					if not spawn_pool.is_empty():
						block_data = spawn_pool.pop_back()
					should_reveal = true
				2: # 终点 (军事基地)
					if not game_end_pool.is_empty():
						block_data = game_end_pool.pop_back()
					should_reveal = true
				1, 3: # 普通地块 / 目标标记点
					if not random_block_pool.is_empty():
						block_data = random_block_pool.pop_back()
					should_reveal = false
				
			add_child(block_instance)
			block_instance.initialize(block_data)
			
			# 🟢 不在循环里直接播，先收集起来
			if should_reveal:
				blocks_to_reveal.append(block_instance)
			
			map_data[current_grid_pos] = block_instance
	# 🟢 【重点】此时整个地图 8x8 已经全部生成完毕并铺在屏幕上了！
	# 我们在这里再播放动画：
	_play_start_animations(blocks_to_reveal)

func center_map_in_screen() -> void:
	if map_layout.is_empty():
		return
		
	var rows = map_layout.size()
	var cols = map_layout[0].size()
	
	var grid_pixel_size = Vector2(
		(cols - 1) * cell_offset.x,
		(rows - 1) * cell_offset.y
	)
	
	var viewport_size = get_viewport_rect().size
	var center_pos = (viewport_size - grid_pixel_size) / 2.0
	global_position = center_pos + map_offset


func _play_start_animations(blocks: Array[Node2D]) -> void:
	# 给予一个短暂的停顿（比如 0.3 秒），让玩家看清全图背景，再开始翻牌
	await get_tree().create_timer(0.3).timeout
	
	for block in blocks:
		if is_instance_valid(block):
			block.flip_block()
			# 如果你想要起点和终点有先后翻转的顺序感，可以在这里加一个小小的间隔：
			await get_tree().create_timer(1.0).timeout
