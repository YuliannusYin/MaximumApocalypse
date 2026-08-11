# EffectContext.gd
class_name EffectContext
extends RefCounted

## 效果执行上下文
## 传递技能触发或效果执行时的所有相关对象与数据

## 技能/效果的宿主来源（例如：某个 MapBlock、Card 或 Equipment）
var source: Object = null

## 效果的发起者/施加者（例如：玩家 Player）
var caster: Object = null

## 效果的直接目标（例如：被选中的 MapBlock、目标 Monster 或 Player）
var target: Object = null

## 触发的事件名称（例如："on_reveal_block"、"on_enter_block"）
var trigger_name: String = ""

## 附带的额外数据（例如：传入的伤害数值、调用的游戏状态管理器指针等）
var extra_data: Dictionary = {}

# 便捷创建工厂方法
static func create(p_source: Object, p_caster: Object, p_target: Object = null, p_trigger: String = "", p_extra: Dictionary = {}) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.source = p_source
	ctx.caster = p_caster
	ctx.target = p_target
	ctx.trigger_name = p_trigger
	ctx.extra_data = p_extra
	return ctx