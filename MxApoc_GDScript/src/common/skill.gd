class_name Skill
extends RefCounted

## 技能结构定义。
## 不继承 Entity，是挂载在 Entity 上的数据结构。
## 字段规范见 GameDesignDocus/GameSystem/Common/Skill.md 与 IdentifierMapping.md §3.13。
## trigger 字段支持「、」分隔的复合触发。

## 技能名
var skill_name: String = ""
## 英文名
var english_name: String = ""
## 技能描述
var skill_description: String = ""
## 可主动使用的技能声明可用阶段（如 "行动阶段"）。空字符串表示非主动技能
var active: String = ""
## 触发名，支持「、」分隔的复合触发（如 "游戏开始时、受到伤害时"）。空字符串表示无触发
var trigger: String = ""
## 技能类型（如 "装备"、"行动"）
var skill_type: String = ""
## 是否强制发动
var forced: bool = false
## 触发条件过滤函数，参数为 event，返回 bool。Callable() 表示无过滤（恒真）
var filter: Callable = Callable()
## 目标过滤函数，返回 bool
var filter_target: Callable = Callable()
## 目标距离限制（"short"/"medium"/"long"/"infinity"，空字符串表示无限制）
var filter_target_range: String = ""
## 选牌过滤函数
var filter_card: Callable = Callable()
## 选牌位置限定（如 "手牌区"）
var position: String = ""
## 需选择的牌数
var select_card: int = 0
## 需选择的目标数
var select_target: int = 0
## 范围模式最小选择数（-1 = 精确模式，必须选 select_target 个；>=0 时允许 [select_target_min, select_target] 个）
var select_target_min: int = -1
## 攻击射程（"short"/"medium"/"long"/"infinity"，空字符串表示无）
var range: String = ""
## 每回合可用次数限制。-1 表示不限（Infinity）
var usable: int = -1
## 技能效果执行体，参数为 event
var content: Callable = Callable()
## 目标类型（""/"block"/"entity"/"pile"/"equipment"），用于 use_active_skill 目标选择
var target_type: String = ""
## 动态确认提示函数，返回 String。Callable() 表示使用默认格式
var confirm_prompt: Callable = Callable()
## 是否延迟结算行动消耗
var defer_action_cost: bool = false
var window_prompt: String = ""

## 运行时：本回合已使用次数（用于 usable 限制）
var used_count: int = 0

## 子技能：键为本地短名，值为编译完成的 Skill 实例。
## 由 Game._create_skill_from_data 在编译父技能时递归编译填充。
var sub_skills: Dictionary = {}


## 判断本技能是否响应指定 trigger 名。
## trigger 字段支持「、」分隔的复合触发。
func matches_trigger(trigger_name: String) -> bool:
	if trigger.is_empty():
		return false
	var triggers: PackedStringArray = trigger.split("、")
	return triggers.has(trigger_name)


## 执行 filter。无 filter 时返回 true（恒通过）。
## player 为触发技能的实体，event 中可能包含 target 字段。
func execute_filter(player: Variant, event: Dictionary) -> bool:
	if not filter.is_valid():
		return true
	return filter.call(player, event.get("target", null), event, Game)


## 执行 content。
## player 为触发技能的实体，event 中可能包含 target 字段。
## content 代码可通过 EventSystem.cancel(event) 取消事件，调用方用 EventSystem.is_cancelled(event) 检查。
## 新内容可使用局部变量 actions 执行嵌套操作；CodeExecutor 会自动等待其完成。
func execute_content(player: Variant, event: Dictionary) -> void:
	if content.is_valid():
		var actions: GameActions = event.get("actions", null)
		var owns_actions: bool = actions == null
		if owns_actions:
			actions = GameActions.new(player, Game, Game.event_scheduler)
			event["actions"] = actions
		await content.call(player, event.get("target", null), event, Game)
		if owns_actions:
			await actions.flush()
			event.erase("actions")


## 执行 confirm_prompt，返回动态确认提示文本。无有效 Callable 时返回空字符串。
func execute_confirm_prompt(player: Variant) -> String:
	if not confirm_prompt.is_valid():
		return ""
	return confirm_prompt.call(player, null, {}, Game)


## 本回合是否仍可使用（受 usable 限制）。
func is_usable() -> bool:
	if usable < 0:
		return true
	return used_count < usable


## 记录一次使用。
func record_use() -> void:
	used_count += 1


## 重置使用次数（回合开始时调用）。
func reset_use_count() -> void:
	used_count = 0
