class_name ImageCache
extends RefCounted

## 图片资源缓存。
## 扫描 images/mapblock/ 和 images/survivor/ 目录，提供按名称查询图片的接口。
## 首次调用任意查询方法时自动初始化（惰性加载）。

static var _block_textures: Dictionary = {}  # block_name → Dictionary[variant_key → Texture2D]
static var _block_back_texture: Texture2D = null
static var _role_card_front: Dictionary = {}  # english_name → Texture2D
static var _role_card_back: Dictionary = {}  # english_name → Texture2D
static var _player_avatars: Dictionary = {}  # english_name → Texture2D
static var _monster_mark_texture: Texture2D = null
static var _objective_mark_texture: Texture2D = null
static var _monster_textures: Dictionary = {}  # monster_name → Texture2D
static var _card_textures: Dictionary = {}  # card_name → Texture2D
static var _initialized: bool = false

## 中文→英文颜色映射（图片文件名用中文，地块数据用英文）
const _COLOR_MAP: Dictionary = {"红": "red", "绿": "green", "蓝": "blue"}


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_scan_block_images()
	_scan_role_card_images()
	_scan_gamemark_images()
	_scan_monster_images()
	_scan_card_images()


static func _scan_block_images() -> void:
	var dir := DirAccess.open("res://images/mapblock")
	if dir == null:
		push_warning("ImageCache: 无法打开 res://images/mapblock 目录")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".png"):
			var clean_name := file.trim_suffix(".png").strip_edges()
			if clean_name == "地图块背面":
				_block_back_texture = load("res://images/mapblock/" + file)
			else:
				# 解析文件名格式：block_name[color1、color2...][spawn_value]
				var bracket_idx := clean_name.find("[")
				if bracket_idx > 0:
					var block_name := clean_name.substr(0, bracket_idx)
					var tex: Texture2D = load("res://images/mapblock/" + file)
					if tex != null:
						var variant_key := _parse_variant_key(clean_name, bracket_idx)
						if not _block_textures.has(block_name):
							_block_textures[block_name] = {}
						_block_textures[block_name][variant_key] = tex
		file = dir.get_next()


## 从文件名解析变体键。格式：block_name[color1、color2...][spawn_value]
## bracket_idx 为第一个 [ 的位置。
static func _parse_variant_key(clean_name: String, bracket_idx: int) -> String:
	# 提取第一个方括号内容（颜色）
	var first_bracket_end := clean_name.find("]", bracket_idx)
	var colors_str := ""
	if first_bracket_end > bracket_idx:
		colors_str = clean_name.substr(bracket_idx + 1, first_bracket_end - bracket_idx - 1)
	# 提取第二个方括号内容（刷怪点数）
	var second_bracket_start := clean_name.find("[", first_bracket_end)
	var spawn_value := ""
	if second_bracket_start > 0:
		var second_bracket_end := clean_name.find("]", second_bracket_start)
		if second_bracket_end > second_bracket_start:
			spawn_value = clean_name.substr(second_bracket_start + 1, second_bracket_end - second_bracket_start - 1)
	# 转换中文颜色为英文
	var english_colors: Array = []
	if colors_str != "":
		for part in colors_str.split("、"):
			var trimmed := part.strip_edges()
			if _COLOR_MAP.has(trimmed):
				english_colors.append(_COLOR_MAP[trimmed])
			else:
				english_colors.append(trimmed)
	english_colors.sort()
	var sorted_colors := ",".join(english_colors)
	return sorted_colors + "|" + spawn_value


static func _scan_role_card_images() -> void:
	var survivor_dir := DirAccess.open("res://images/survivor")
	if survivor_dir == null:
		push_warning("ImageCache: 无法打开 res://images/survivor 目录")
		return
	survivor_dir.list_dir_begin()
	var folder := survivor_dir.get_next()
	while folder != "":
		if survivor_dir.current_is_dir() and not folder.begins_with("."):
			var sub_dir := DirAccess.open("res://images/survivor/" + folder)
			if sub_dir != null:
				sub_dir.list_dir_begin()
				var file := sub_dir.get_next()
				while file != "":
					if not sub_dir.current_is_dir() and (file.ends_with(".jpg") or file.ends_with(".png")):
						# 精确匹配文件主名以「角色牌正面/背面」结尾，排除「角色牌正面头像」等近似文件
						var stem: String = file.get_basename()
						if stem.ends_with("角色牌正面"):
							_role_card_front[folder] = load("res://images/survivor/" + folder + "/" + file)
						elif stem.ends_with("角色牌背面"):
							_role_card_back[folder] = load("res://images/survivor/" + folder + "/" + file)
						elif stem.ends_with("角色头像"):
							_player_avatars[folder] = load("res://images/survivor/" + folder + "/" + file)
					file = sub_dir.get_next()
		folder = survivor_dir.get_next()


static func _scan_gamemark_images() -> void:
	var dir := DirAccess.open("res://images/gamemark")
	if dir == null:
		push_warning("ImageCache: 无法打开 res://images/gamemark 目录")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".png"):
			var stem: String = file.get_basename()
			if stem == "怪物标记":
				_monster_mark_texture = load("res://images/gamemark/" + file)
			elif stem == "任务标记":
				_objective_mark_texture = load("res://images/gamemark/" + file)
		file = dir.get_next()


static func _scan_monster_images() -> void:
	var root := DirAccess.open("res://images/monster")
	if root == null:
		push_warning("ImageCache: 无法打开 res://images/monster 目录")
		return
	root.list_dir_begin()
	var sub := root.get_next()
	while sub != "":
		if root.current_is_dir() and not sub.begins_with("."):
			var type_dir := DirAccess.open("res://images/monster/" + sub)
			if type_dir != null:
				type_dir.list_dir_begin()
				var file := type_dir.get_next()
				while file != "":
					if not type_dir.current_is_dir() and file.ends_with(".png"):
						var stem: String = file.get_basename()
						_monster_textures[stem] = load("res://images/monster/" + sub + "/" + file)
					file = type_dir.get_next()
		sub = root.get_next()


## 扫描卡牌图片：images/survivor/*/ 下所有卡牌 + images/scavenging/。
## 排除非卡牌图片（角色牌正面/背面/头像/游戏牌背面等），按 card_name 索引。
static func _scan_card_images() -> void:
	# 扫描各角色目录下的卡牌图片
	var survivor_dir := DirAccess.open("res://images/survivor")
	if survivor_dir != null:
		survivor_dir.list_dir_begin()
		var folder := survivor_dir.get_next()
		while folder != "":
			if survivor_dir.current_is_dir() and not folder.begins_with("."):
				_scan_card_images_in_dir("res://images/survivor/" + folder)
			folder = survivor_dir.get_next()
	# 扫描拾荒卡图包
	_scan_card_images_in_dir("res://images/scavenging")


## 扫描单个目录下的卡牌图片，按文件主名（card_name）索引。
## 排除文件名包含"角色牌"、"头像"、"游戏牌背面"的非卡牌图片。
## 未导入的资源（如 headless 模式下 texture 未生成 .ctex）注册为 null，避免引擎报错。
static func _scan_card_images_in_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and (file.ends_with(".png") or file.ends_with(".jpg")):
			var stem: String = file.get_basename().strip_edges()
			if stem.find("角色牌") < 0 and stem.find("头像") < 0 and stem.find("游戏牌背面") < 0:
				var path := dir_path + "/" + file
				if _is_texture_imported(path):
					_card_textures[stem] = load(path)
				else:
					_card_textures[stem] = null
		file = dir.get_next()


## 检查纹理资源是否已完成导入（.import 文件 [remap] 段含 path 字段指向已生成的 .ctex）。
## ResourceLoader.exists() 对仅有 .import 但未生成 .ctex 的资源仍返回 true，
## 直接 load() 会触发引擎 ERROR。headless 无 GPU 环境下纹理无法导入，需提前规避。
static func _is_texture_imported(path: String) -> bool:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return true  # 无 .import 文件，按可加载处理（让 load() 自行决定）
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return false
	var imported_path: String = cfg.get_value("remap", "path", "")
	if imported_path == "":
		return false  # 未导入（.import 含 valid=false，无 path 字段）
	return FileAccess.file_exists(imported_path)


## 按变体精确匹配返回纹理。无匹配时回退到该地块任意一张纹理。
static func get_block_texture(block_name: String, scavenge_colors: PackedStringArray = PackedStringArray(), monster_spawn_value: int = -1) -> Texture2D:
	_ensure_initialized()
	if not _block_textures.has(block_name):
		return null
	var variants: Dictionary = _block_textures[block_name]
	if variants.is_empty():
		return null
	# 构建变体键进行精确匹配
	if monster_spawn_value >= 0:
		var english_colors: Array = []
		for c in scavenge_colors:
			english_colors.append(c)
		english_colors.sort()
		var variant_key := ",".join(english_colors) + "|" + str(monster_spawn_value)
		if variants.has(variant_key):
			return variants[variant_key]
	# 回退：返回任意一张可用纹理
	var first_key: Variant = variants.keys()[0]
	return variants[first_key]


## 返回未展示地块的背面纹理。无则返回 null。
static func get_block_back_texture() -> Texture2D:
	_ensure_initialized()
	return _block_back_texture


## 返回指定求生者的角色牌正面/背面纹理。无匹配时返回 null。
static func get_role_card_texture(english_name: String, is_front: bool) -> Texture2D:
	_ensure_initialized()
	var dict: Dictionary = _role_card_front if is_front else _role_card_back
	return dict.get(english_name, null)


## 返回指定求生者的头像纹理。无匹配时返回 null。
static func get_player_avatar(english_name: String) -> Texture2D:
	_ensure_initialized()
	return _player_avatars.get(english_name, null)


## 返回怪物标记图标纹理。无则返回 null。
static func get_monster_mark_texture() -> Texture2D:
	_ensure_initialized()
	return _monster_mark_texture


## 返回任务标记图标纹理。无则返回 null。
static func get_objective_mark_texture() -> Texture2D:
	_ensure_initialized()
	return _objective_mark_texture


## 返回指定怪物的图片纹理。无匹配时返回 null。
static func get_monster_texture(monster_name: String) -> Texture2D:
	_ensure_initialized()
	return _monster_textures.get(monster_name, null)


## 返回指定卡牌的图片纹理。无匹配时返回 null。
## 查找策略：先按 card_name 精确匹配，未命中再用规范化名（全角（→_、去除全角）和！等）
## 匹配，使 card_name「弹药（少量）」能命中文件名「弹药_少量.png」、「伏击！」能命中「伏击.png」。
static func get_card_texture(card_name: String) -> Texture2D:
	_ensure_initialized()
	if _card_textures.has(card_name):
		return _card_textures[card_name]
	var normalized := _normalize_card_name(card_name)
	if normalized != card_name and _card_textures.has(normalized):
		return _card_textures[normalized]
	return null


## 规范化卡牌名用于图片查找。
## 将全角（替换为_、去除全角）、全角！等标点，使 card_name 与文件名约定对齐。
static func _normalize_card_name(name: String) -> String:
	var result := name.strip_edges()
	result = result.replace("（", "_")
	result = result.replace("）", "")
	result = result.replace("！", "")
	result = result.replace("(", "_")
	result = result.replace(")", "")
	result = result.replace("!", "")
	return result
