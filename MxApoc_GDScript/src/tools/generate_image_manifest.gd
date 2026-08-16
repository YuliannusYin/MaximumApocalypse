@tool
class_name GenerateImageManifest
extends EditorScript

## 图片清单生成工具。
## 在 Godot 编辑器中：文件 → 运行脚本 → 选择此脚本，或在文件系统中右键此脚本 → 运行。
## 扫描 res://images/ 目录，生成 res://data/image_manifest.json。
## 导出版本中 .png/.jpg 会被编译为 .ctex 并重映射，源文件不在 PCK 中，
## 因此运行时改用预生成的清单记录 res:// 路径；本脚本用于在编辑器中重新生成该清单。

func _run() -> void:
	generate()

static func generate() -> void:
	var manifest: Dictionary = {}
	manifest["mapblock"] = _scan_flat_dir("res://images/mapblock")
	manifest["survivor"] = _scan_grouped_dir("res://images/survivor")
	manifest["gamemark"] = _scan_flat_dir("res://images/gamemark")
	manifest["monster"] = _scan_grouped_dir("res://images/monster")
	manifest["scavenging"] = _scan_flat_dir("res://images/scavenging")

	var json_str := JSON.stringify(manifest, "  ")
	var file := FileAccess.open("res://data/image_manifest.json", FileAccess.WRITE)
	if file == null:
		push_error("GenerateImageManifest: 无法写入 res://data/image_manifest.json")
		return
	file.store_string(json_str)
	file.close()

	var total := 0
	for key in manifest:
		var val = manifest[key]
		if val is Array:
			total += val.size()
		elif val is Dictionary:
			for sub in val:
				total += val[sub].size()
	print("GenerateImageManifest: 已生成清单，共 %d 张图片" % total)


## 扫描扁平目录，返回 res:// 路径数组（已排序）。
static func _scan_flat_dir(dir_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("无法打开目录: " + dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.begins_with(".") and _is_image(file_name):
			result.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


## 扫描分组目录（子目录为分组键），返回 Dictionary[group_name → Array[res:// path]]。
## 子目录键按名称排序，以保证输出确定。
static func _scan_grouped_dir(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	var sub_dirs: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("无法打开目录: " + dir_path)
		return result
	dir.list_dir_begin()
	var sub := dir.get_next()
	while sub != "":
		if dir.current_is_dir() and not sub.begins_with("."):
			sub_dirs.append(sub)
		sub = dir.get_next()
	dir.list_dir_end()
	sub_dirs.sort()
	for sub_name in sub_dirs:
		result[sub_name] = _scan_flat_dir(dir_path + "/" + sub_name)
	return result


## 判断文件是否为图片（.png 或 .jpg）。
static func _is_image(file_name: String) -> bool:
	return file_name.ends_with(".png") or file_name.ends_with(".jpg")
