class_name ImageCache
extends RefCounted

## 图片资源缓存。
## 通过预生成的清单 data/image_manifest.json 加载图片资源路径，提供按名称查询图片的接口。
## 首次调用任意查询方法时自动初始化（惰性加载）。
## 导出版本中 .png/.jpg 会被编译为 .ctex 并重映射，源文件不在 PCK 中，
## 因此不扫描目录，而是依赖清单中已记录的 res:// 路径加载。

static var _block_textures: Dictionary = {}  # block_name → Dictionary[variant_key → Texture2D]
static var _block_back_texture: Texture2D = null
static var _role_card_front: Dictionary = {}  # english_name → Texture2D
static var _role_card_back: Dictionary = {}  # english_name → Texture2D
static var _player_avatars: Dictionary = {}  # english_name → Texture2D
static var _monster_mark_texture: Texture2D = null
static var _objective_mark_texture: Texture2D = null
static var _monster_textures: Dictionary = {}  # monster_name → Texture2D
static var _monster_card_back_texture: Texture2D = null
static var _scavenge_card_back_texture: Texture2D = null
static var _card_textures: Dictionary = {}  # card_name → Texture2D
static var _initialized: bool = false
static var _manifest: Dictionary = {}

## 中文→英文颜色映射（图片文件名用中文，地块数据用英文）
const _COLOR_MAP: Dictionary = {"红": "red", "绿": "green", "蓝": "blue"}


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	var path := "res://data/image_manifest.json"
	if not FileAccess.file_exists(path):
		push_error("ImageCache: 清单文件不存在: " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ImageCache: 无法打开清单文件: " + path)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ImageCache: 清单文件解析失败: " + path)
		return
	_manifest = parsed
	_scan_block_images()
	_scan_role_card_images()
	_scan_gamemark_images()
	_scan_monster_images()
	_scan_monster_card_back()
	_scan_scavenge_card_back()
	_scan_card_images()


static func _scan_block_images() -> void:
	if not _manifest.has("mapblock"):
		return
	var paths: Array = _manifest["mapblock"]
	for path in paths:
		var p: String = path
		var clean_name := p.get_file().get_basename().strip_edges()
		if clean_name == "地图块背面":
			_block_back_texture = load(p)
		else:
			# 解析文件名格式：block_name[color1、color2...][spawn_value]
			var bracket_idx := clean_name.find("[")
			if bracket_idx > 0:
				var block_name := clean_name.substr(0, bracket_idx)
				var tex: Texture2D = load(p)
				if tex != null:
					var variant_key := _parse_variant_key(clean_name, bracket_idx)
					if not _block_textures.has(block_name):
						_block_textures[block_name] = {}
					_block_textures[block_name][variant_key] = tex


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
	if not _manifest.has("survivor"):
		return
	var survivor: Dictionary = _manifest["survivor"]
	for role_name in survivor.keys():
		var paths: Array = survivor[role_name]
		for path in paths:
			var p: String = path
			# 精确匹配文件主名以「角色牌正面/背面」结尾，排除「角色牌正面头像」等近似文件
			var stem: String = p.get_file().get_basename().strip_edges()
			if stem.ends_with("角色牌正面"):
				_role_card_front[role_name] = load(p)
			elif stem.ends_with("角色牌背面"):
				_role_card_back[role_name] = load(p)
			elif stem.ends_with("角色头像"):
				_player_avatars[role_name] = load(p)


static func _scan_gamemark_images() -> void:
	if not _manifest.has("gamemark"):
		return
	var paths: Array = _manifest["gamemark"]
	for path in paths:
		var p: String = path
		var stem: String = p.get_file().get_basename()
		if stem == "怪物标记":
			_monster_mark_texture = load(p)
		elif stem == "任务标记":
			_objective_mark_texture = load(p)


static func _scan_monster_images() -> void:
	if not _manifest.has("monster"):
		return
	var monster: Dictionary = _manifest["monster"]
	for _type in monster.keys():
		var paths: Array = monster[_type]
		for path in paths:
			var p: String = path
			var stem: String = p.get_file().get_basename()
			_monster_textures[stem] = load(p)


## 扫描怪物牌背面图片（images/monster 根目录，清单 monster_card_back 键）。
static func _scan_monster_card_back() -> void:
	if not _manifest.has("monster_card_back"):
		return
	var paths: Array = _manifest["monster_card_back"]
	if paths.is_empty():
		return
	_monster_card_back_texture = load(paths[0])


## 扫描拾荒牌背面图片（images/scavenging 目录，清单 scavenge_card_back 键）。
static func _scan_scavenge_card_back() -> void:
	if not _manifest.has("scavenge_card_back"):
		return
	var paths: Array = _manifest["scavenge_card_back"]
	if paths.is_empty():
		return
	_scavenge_card_back_texture = load(paths[0])


## 扫描卡牌图片：survivor 下各角色目录 + scavenging。
## 排除非卡牌图片（角色牌正面/背面/头像/游戏牌背面等），按 card_name 索引。
## 清单中列出的图片均已导入（含 .import 文件），直接 load() 即可。
static func _scan_card_images() -> void:
	# 扫描各角色目录下的卡牌图片
	if _manifest.has("survivor"):
		var survivor: Dictionary = _manifest["survivor"]
		for role_name in survivor.keys():
			var paths: Array = survivor[role_name]
			for path in paths:
				_add_card_texture(path)
	# 扫描拾荒卡图包
	if _manifest.has("scavenging"):
		var paths: Array = _manifest["scavenging"]
		for path in paths:
			_add_card_texture(path)


## 根据单个图片路径登记卡牌纹理，按文件主名（card_name）索引。
## 排除文件名包含"角色牌"、"头像"、"游戏牌背面"、"拾荒牌背面"的非卡牌图片。
static func _add_card_texture(path: String) -> void:
	var stem: String = path.get_file().get_basename().strip_edges()
	if stem.find("角色牌") < 0 and stem.find("头像") < 0 and stem.find("游戏牌背面") < 0 and stem.find("拾荒牌背面") < 0:
		_card_textures[stem] = load(path)


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


## 返回怪物牌背面纹理。无则返回 null。
static func get_monster_card_back_texture() -> Texture2D:
	_ensure_initialized()
	return _monster_card_back_texture


## 返回拾荒牌背面纹理。无则返回 null。
static func get_scavenge_card_back_texture() -> Texture2D:
	_ensure_initialized()
	return _scavenge_card_back_texture


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
