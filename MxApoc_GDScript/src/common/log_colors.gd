class_name LogColors
extends RefCounted

## 日志实体名 BBCode 着色工具类。
## 统一封装日志中角色名/怪物名/卡牌名/技能名/地图块名的着色逻辑。
## 配合 RichTextLabel（bbcode_enabled = true）使用。

## 颜色常量（与 spec 对齐）
const PLAYER: String = "#73d0ff"  ## 角色名：浅天蓝色
const MONSTER: String = "#ff7b7b"  ## 怪物名：浅珊瑚红
const CARD: String = "#d299ff"  ## 卡牌名：淡紫
const SKILL: String = "#ffd370"  ## 技能名：暖金黄色
const BLOCK: String = "#88dd88"  ## 地图块名：薄荷绿
const TEXT: String = "#cccccc"  ## 其他字符：浅灰白
const BG: String = "#1E2228"  ## 日志背景：深暗色


## 角色名着色（浅天蓝）。返回 [color=#73d0ff]"name"[/color]
static func player(name: String) -> String:
	return _wrap(name, PLAYER)


## 怪物名着色（浅珊瑚红）。返回 [color=#ff7b7b]"name"[/color]
static func monster(name: String) -> String:
	return _wrap(name, MONSTER)


## 卡牌名着色（淡紫）。返回 [color=#d299ff]"name"[/color]
static func card(name: String) -> String:
	return _wrap(name, CARD)


## 技能名着色（暖金黄）。返回 [color=#ffd370]"name"[/color]
static func skill(name: String) -> String:
	return _wrap(name, SKILL)


## 地图块名着色（薄荷绿）。返回 [color=#88dd88]"name"[/color]
static func block(name: String) -> String:
	return _wrap(name, BLOCK)


## 根据 skill_type 决定技能名颜色：block→绿、monster→红、其他→紫。
## 用于 Entity.trigger 中输出"触发了技能名"日志。
static func skill_by_type(name: String, skill_type: String) -> String:
	var color: String = CARD
	if skill_type == "block":
		color = BLOCK
	elif skill_type == "monster":
		color = MONSTER
	return _wrap(name, color)


## 去掉日志中的颜色 BBCode，保留引号与正文。用于导出纯文本。
static func strip_bbcode(message: String) -> String:
	return _strip_with_regex(message, _make_bbcode_regex())


## 将日志数组拼成纯文本，每条一行。
static func to_plain_log(messages: Array) -> String:
	var regex := _make_bbcode_regex()
	var lines: PackedStringArray = PackedStringArray()
	for msg in messages:
		lines.append(_strip_with_regex(str(msg), regex))
	return "\n".join(lines)


## 内部：用指定颜色包裹双引号文本
static func _wrap(name: String, color: String) -> String:
	return "[color=%s]\"%s\"[/color]" % [color, name]


static func _strip_with_regex(message: String, regex: RegEx) -> String:
	if regex == null:
		return message
	return regex.sub(message, "", true)


static func _make_bbcode_regex() -> RegEx:
	var regex := RegEx.new()
	var err: int = regex.compile("\\[/?color(?:=#[0-9a-fA-F]+)?\\]")
	if err != OK:
		return null
	return regex
