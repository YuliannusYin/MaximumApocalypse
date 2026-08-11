extends Node

# 使用最新的类名 MapManagerNew
var map_manager: MapManagerNew

func _ready() -> void:
	# 1. 实例化新版地图管理器节点
	map_manager = MapManagerNew.new()
	
	# 2. 加入场景树（会自动触发 map_manager 的 _ready() 并加载 JSON 模板）
	add_child(map_manager)
	
	# 3. 生成 3x3 初始地图（传空字符串 "" 开启全随机模板填充）
	print("==========================================")
	print("开始测试：生成 3x3 地图")
	print("==========================================")
	map_manager.generate_grid(3, 3, "")

	# 4. 控制台打印地图数据
	_print_grid_status()

	# 5. 构建运行上下文
	var target_coord := Vector2(1, 1)
	var context := EffectContext.new()
	context.caster = self # 纯测试，用 self 充当触发者
	context.extra_data["current_phase"] = "action_phase"

	# 6. 测试翻开与踏入地块
	print("\n==========================================")
	print("测试：玩家翻开并进入地块 (1,1)")
	print("==========================================")
	
	map_manager.reveal_block_at(target_coord, context)
	map_manager.enter_block_at(target_coord, context)

	# 7. 再次打印互动后的地图全局状态
	print("\n互动后的地图状态：")
	_print_grid_status()

	# 8. 打印地块 (1,1) 的全部详细属性
	var block_1_1 := map_manager.get_block_at(target_coord)
	if block_1_1:
		print("\n==========================================")
		print("详细属性调试：地块 (1,1) 展开输出")
		print("==========================================")
		block_1_1.print_debug_info()


## 纯控制台可视化打印地图矩阵状态
func _print_grid_status() -> void:
	print("\n---当前地图网格数据---")
	for y in range(map_manager.grid_size.y):
		var line_str := ""
		for x in range(map_manager.grid_size.x):
			var coord := Vector2(x, y)
			
			var block: MapBlock = map_manager.get_block_at(coord)
			
			if block:
				var reveal_symbol := " [已翻开] " if block.is_revealed else " [未翻开] "
				line_str += "(%d,%d):%s%-12s\t" % [x, y, reveal_symbol, block.block_name]
			else:
				line_str += "(%d,%d): [空地块]\t" % [x, y]
		print(line_str)
	print("----------------------\n")
