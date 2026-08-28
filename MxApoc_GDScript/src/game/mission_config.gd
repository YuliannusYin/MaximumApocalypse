class_name MissionConfig
extends RefCounted

## 任务配置结构。由任务包加载，存储本局任务的可配置项与运行时状态。
## 三层架构第二/三层运行时容器：持有按 JSON 声明挂载的组件实例与任务脚本实例。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md#任务配置结构missionconfig

## 启动面包车所需燃料值。-1 表示 NULL（该任务不通过面包车胜利，如任务 4/8/9/11）。
var van_fuel_required: int = -1

## 开局跳过初始怪物牌抓取（如任务 11）。
var no_initial_monster_draw: bool = false

## 开局时场上任务标记总数。由 Game.initialize_game() 在 build_map 之后
## 遍历 map_area 累加 block.objective_marks.size() 统计写入，
## 供 objective_marks_cleared 等组件计算已移除数。
var initial_objective_mark_count: int = 0

## 胜利条件组件列表。全部 check_win 为 true 才满足任务特定胜利条件。
var win_condition_components: Array = []

## 失败条件组件列表。任一 check_lose 为 true 即任务失败。
var lose_condition_components: Array = []

## 触发器组件列表。接收 Game 转发的游戏事件（on_event）。
var trigger_components: Array = []

## 行动选项组件列表。提供任务专属行动选项（get_action_options）。
var action_components: Array = []

## 任务脚本实例（第三层）。仅用于组件无法表达的极特殊任务逻辑，可为 null。
var mission_script_instance: MissionScript = null

## 任务特定运行时状态存储。各任务自行约定键名。
## 常用键见 IdentifierMapping.md §八（如 scientist_info_recorded / scientist_rescued / bomb_defused）。
var mission_state: Dictionary = {}


## 初始化全部组件与脚本实例。任务开始时由 Game.initialize_game() 调用。
func setup_components(game: Game) -> void:
	for component in win_condition_components:
		component.setup(game, self)
	for component in lose_condition_components:
		component.setup(game, self)
	for component in trigger_components:
		component.setup(game, self)
	for component in action_components:
		component.setup(game, self)
	if mission_script_instance != null:
		mission_script_instance.setup(game, self)


## 任务胜利条件判定。所有胜利组件为 true 且（无脚本或脚本为 true）才为 true；
## 无组件且无脚本时返回 true（空真）。
func check_win(game: Game) -> bool:
	for component in win_condition_components:
		if not component.check_win(game):
			return false
	if mission_script_instance != null and not mission_script_instance.check_win(game):
		return false
	return true


## 任务失败条件判定。任一失败组件或脚本返回 true 即为 true；否则 false。
func check_lose(game: Game) -> bool:
	for component in lose_condition_components:
		if component.check_lose(game):
			return true
	if mission_script_instance != null and mission_script_instance.check_lose(game):
		return true
	return false


## 事件转发。将游戏事件转发给全部触发器组件与脚本。
func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	for component in trigger_components:
		component.on_event(game, event_name, event)
	if mission_script_instance != null:
		mission_script_instance.on_event(game, event_name, event)


## 汇总任务行动选项。合并全部行动组件与脚本的返回值。
## 每项为 Dictionary，含 id / label / execute 键。
func get_action_options(game: Game, player: Player) -> Array:
	var options: Array = []
	for component in action_components:
		options.append_array(component.get_action_options(game, player))
	if mission_script_instance != null:
		options.append_array(mission_script_instance.get_action_options(game, player))
	return options


## 挂载任务行动技能：玩家进入地块时调用（与地块技能获取并列）。
## 遍历行动组件的技能声明（get_action_skill_decl），block_match 匹配的组件构建
## 主动 Skill（active="action"、skill_type="任务"）挂到 player.skills，
## 复用地块技能管线（技能栏显示、filter 灰化、confirm_prompt 确认门、use_active_skill 执行）。
## english_name 用组件在 action_components 中的数组索引（"mission_action_%d"）保证跨挂载稳定，
## 供 unmount_action_skills 识别。Skill 每次挂载均为新建实例（add_skill 按实例去重无法复用），
## 故先卸载旧任务行动技能再挂新的——幂等，重复调用不累积。
func mount_action_skills(player: Variant, block: MapBlock) -> void:
	if player == null or not is_instance_valid(player):
		return
	if block == null or not is_instance_valid(block):
		return
	unmount_action_skills(player)
	for i in range(action_components.size()):
		var component: MissionComponent = action_components[i]
		if component == null or not is_instance_valid(component):
			continue
		var decl: Variant = component.get_action_skill_decl()
		if decl == null or not (decl is Dictionary):
			continue
		var block_match: Callable = decl.get("block_match", Callable())
		if not block_match.is_valid() or not block_match.call(block):
			continue
		var skill: Skill = Skill.new()
		skill.skill_name = str(decl.get("skill_name", "任务行动"))
		skill.english_name = "mission_action_%d" % i
		skill.skill_type = "任务"
		skill.active = "action"
		skill.skill_description = skill.skill_name
		var decl_confirm: Callable = decl.get("confirm", Callable())
		if decl_confirm.is_valid():
			var confirm_ref: Callable = decl_confirm
			skill.skill_description = str(decl_confirm.call(player))
			skill.confirm_prompt = func(p, _t, _e, _g) -> String:
				return confirm_ref.call(p)
		var decl_filter: Callable = decl.get("filter", Callable())
		if decl_filter.is_valid():
			var filter_ref: Callable = decl_filter
			skill.filter = func(p, _t, _e, _g) -> bool:
				return filter_ref.call(p)
		var decl_execute: Callable = decl.get("execute", Callable())
		if decl_execute.is_valid():
			var execute_ref: Callable = decl_execute
			skill.content = func(p, _t, _e, _g) -> void:
				await execute_ref.call(p)
		player.add_skill(skill)


## 卸载全部任务行动技能：玩家离开地块/被迁移时调用（与地块技能清理并列）。
## 按 english_name 前缀 "mission_action_" 识别任务行动技能并移除。
func unmount_action_skills(player: Variant) -> void:
	if player == null or not is_instance_valid(player):
		return
	for skill in player.skills.duplicate():
		if skill is Skill and skill.english_name.begins_with("mission_action_"):
			player.remove_skill(skill)
