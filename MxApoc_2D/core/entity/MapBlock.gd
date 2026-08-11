class_name MapBlock
extends BaseEntity

# ==============================================================================
# 枚举定义
# ==============================================================================
enum ScavengeColor {
	RED,
	GREEN,
	BLUE
}

enum Status {
	ALIVE,
	DESTROYED
}

# ==============================================================================
# 地块基础属性 (对应 JSON 静态数据)
# ==============================================================================
## 地块中文名
var block_name: String = ""

## 地块英文标识符
var english_name: String = ""

## 可拾荒颜色列表
var scavenge_colors: Array[ScavengeColor] = []

## 怪物生成阈值/数值
var monster_spawn_value: int = 0

## 该地图块所拥有的技能列表
var skills: Array[Skill] = []

# ==============================================================================
# 运行时状态属性 (Runtime State)
# ==============================================================================
## 是否已被探索/翻开展示
var is_revealed: bool = false

## 地块上的怪物标记数量
var monster_marks: int = 0

## 地块当前状态（存活/摧毁）
var map_status: Status = Status.ALIVE

## 轴网坐标 (如 Vector2(x, y))
var coordinate: Vector2 = Vector2.ZERO


# ==============================================================================
# 初始化与数据解析
# ==============================================================================

func _init() -> void:
	super(BaseEntity.Type.MAP_BLOCK)


## 从 JSON 转换为 Dictionary 的数据中初始化当前地块
func init_from_json_dict(data: Dictionary) -> void:
	block_name = data.get("block_name", "")
	english_name = data.get("english_name", "")
	monster_spawn_value = data.get("monster_spawn_value", 0)
	
	# 1. 解析拾荒颜色字符串数组并转为 Enum
	scavenge_colors.clear()
	var raw_colors: Array = data.get("scavenge_colors", [])
	for c_str in raw_colors:
		match str(c_str).to_lower():
			"red": scavenge_colors.append(ScavengeColor.RED)
			"green": scavenge_colors.append(ScavengeColor.GREEN)
			"blue": scavenge_colors.append(ScavengeColor.BLUE)

	# 2. 调用 SkillFactory 构建技能列表
	skills.clear()
	var raw_skills: Array = data.get("skills", [])
	for skill_dict in raw_skills:
		if skill_dict is Dictionary:
			var skill_obj: Skill = SkillFactory.create_skill_from_dict(skill_dict)
			skills.append(skill_obj)


# ==============================================================================
# 核心逻辑接口：响应技能与触发
# ==============================================================================

## 检查是否拥有指定英文名的技能
func has_skill(skill_eng_name: String) -> bool:
	for sk in skills:
		if sk.english_name == skill_eng_name:
			return true
	return false


## 检查是否拥有指定类型的技能
func get_skills_by_trigger(event_trigger_name: String) -> Array[Skill]:
	var matched: Array[Skill] = []
	for sk in skills:
		if sk.matches_trigger(event_trigger_name):
			matched.append(sk)
	return matched


## 当地块触发某事件时调用此函数（如 "on_reveal_block", "on_enter_block"）
func trigger_event(trigger_name: String, context: EffectContext) -> void:
	# 设置 context 的宿主来源为当前地块
	context.source = self
	context.trigger_name = trigger_name
	
	for sk in skills:
		# 1. 触发匹配校验
		if not sk.matches_trigger(trigger_name):
			continue
			
		# 2. 次数限制校验
		if not sk.is_usable():
			continue
			
		# 3. 前置 Condition 条件校验
		if not sk.check_filter(context):
			continue
			
		# 4. 执行技能包含的所有 Effect 节点
		for effect in sk.effects:
			effect.execute(context)
			
		# 记录使用次数
		sk.record_use()


# ==============================================================================
# 调试与测试工具 (Debug Tools)
# ==============================================================================

## 将当前地块的全部属性格式化打印到控制台
func print_debug_info() -> void:
	print("\n========== [MapBlock Debug Info] ==========")
	print("【基础信息】")
	print("  • 唯一 ID (unique_id): ", unique_id) # <--- 打印来自 BaseEntity 的 unique_id
	print("  • 实体类型 (type): ", type)         # <--- BaseEntity.Type.MAP_BLOCK
	print("  • 坐标 (Coordinate): ", coordinate)
	print("  • 名称 (Name): %s (%s)" % [block_name, english_name])
	print("  • 刷怪值 (Monster Spawn Value): ", monster_spawn_value)
	
	# 解析颜色 Enum 为易读文本
	var color_names := []
	for c in scavenge_colors:
		match c:
			ScavengeColor.RED: color_names.append("红色(RED)")
			ScavengeColor.GREEN: color_names.append("绿色(GREEN)")
			ScavengeColor.BLUE: color_names.append("蓝色(BLUE)")
	print("  • 拾荒颜色 (Scavenge Colors): ", color_names if color_names.size() > 0 else "无 (None)")

	print("\n【运行状态】")
	print("  • 是否翻开 (Is Revealed): ", "是 (True)" if is_revealed else "否 (False)")
	print("  • 怪物标记数量 (Monster Marks): ", monster_marks)
	print("  • 地块状态 (Status): ", "存活 (ALIVE)" if map_status == Status.ALIVE else "被摧毁 (DESTROYED)")
	
	print("\n【绑定技能列表 (共 %d 个)】" % skills.size())
	for i in range(skills.size()):
		var skill: Skill = skills[i]
		print("  --- 技能 #%d ---" % (i + 1))
		print("    - 技能名: %s (%s)" % [skill.skill_name, skill.english_name])
		print("    - 触发时机(Trigger): ", skill.get("trigger") if "trigger" in skill else "N/A")
		print("    - 主动类型(Active): ", skill.get("active") if "active" in skill else "N/A")
		print("    - 描述: ", skill.skill_description)
		if "effects" in skill and skill.effects is Array:
			print("    - 包含效果(Effects): %d 个" % skill.effects.size())
	print("===========================================\n")
