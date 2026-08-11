# SkillFactory.gd
class_name SkillFactory
extends RefCounted

## 专门负责解析 JSON 字典并生成 Skill 实例及其 Effect/Condition 逻辑树的工厂类


# ==============================================================================
# 主解析入口
# ==============================================================================

## 根据 JSON 传入的 skill 字典，创建并组装 Skill 对象
static func create_skill_from_dict(skill_dict: Dictionary) -> Skill:
	var skill := Skill.new()
	
	# 1. 基础字段解析
	skill.skill_name = skill_dict.get("skill_name", "")
	skill.english_name = skill_dict.get("english_name", "")
	skill.skill_description = skill_dict.get("skill_description", "")
	skill.skill_type = skill_dict.get("skill_type", "block")
	skill.trigger = skill_dict.get("trigger", "")
	skill.active_phase = skill_dict.get("active", "")
	skill.forced = skill_dict.get("forced", true)
	skill.select_target = skill_dict.get("select_target", 0)
	skill.target_type = skill_dict.get("target_type", "")
	skill.usable_limit = skill_dict.get("usable_limit", -1)
	
	# 2. 条件节点解析 (filter 与 filter_target)
	if skill_dict.has("filter") and skill_dict["filter"] is Dictionary:
		skill.filter_condition = _parse_condition(skill_dict["filter"])
		
	if skill_dict.has("filter_target") and skill_dict["filter_target"] is Dictionary:
		skill.filter_target_condition = _parse_condition(skill_dict["filter_target"])
		
	# 3. 效果节点列表解析 (effects)
	if skill_dict.has("effects") and skill_dict["effects"] is Array:
		for eff_dict in skill_dict["effects"]:
			var effect_node := _parse_effect(eff_dict)
			if effect_node != null:
				skill.effects.append(effect_node)
				
	return skill


# ==============================================================================
# Condition 条件分发与解析
# ==============================================================================

static func _parse_condition(dict: Dictionary) -> EffectCondition:
	var cond_type: String = dict.get("condition_type", "")
	
	match cond_type:
		"and":
			# 组合条件 AND
			var sub_conditions: Array[EffectCondition] = []
			for sub_dict in dict.get("conditions", []):
				var parsed := _parse_condition(sub_dict)
				if parsed: sub_conditions.append(parsed)
			return ConditionNodes.And.new(sub_conditions)
			
		"not":
			# 取反条件 NOT
			var inner := _parse_condition(dict.get("condition", {}))
			return ConditionNodes.Not.new(inner)
			
		"has_status_mark":
			# 检查是否有标记状态
			return ConditionNodes.HasStatusMark.new(
				dict.get("mark_name", "")
			)
			
		"in_phase":
			# 检查当前流程阶段
			return ConditionNodes.InPhase.new(dict.get("phase_name", ""))
			
		"has_action_points":
			# 检查剩余行动点数
			return ConditionNodes.HasActionPoints.new(dict.get("min_amount", 1))
			
		"has_card_type":
			# 检查玩家是否有指定类型手牌/装备
			return ConditionNodes.HasCardType.new(dict.get("card_type", ""))
			
		"block_has_no_monsters":
			return ConditionNodes.BlockHasNoMonsters.new()
			
		"is_revealed":
			return ConditionNodes.IsRevealed.new()
			
		"not_self_block":
			return ConditionNodes.NotSelfBlock.new()
			
		"has_skill":
			# 补全：检查实体是否拥有指定技能 (优先读 skill_name，备选 english_name)
			var target_skill: String = dict.get("skill_name", dict.get("english_name", ""))
			return ConditionNodes.HasSkill.new(target_skill)
			
		_:
			push_error("未知的 Condition 类型: %s" % cond_type)
			return null


# ==============================================================================
# Effect 效果分发与解析
# ==============================================================================

static func _parse_effect(dict: Dictionary) -> Effect:
	var eff_type: String = dict.get("effect_type", "")
	
	match eff_type:
		# ----- 逻辑控制节点 -----
		"branch_by_trigger":
			# 按触发时机分发子效果
			var branch_map: Dictionary = {}
			var raw_branches: Dictionary = dict.get("branches", {})
			for trig_key in raw_branches:
				var eff_list: Array[Effect] = []
				for sub_eff_dict in raw_branches[trig_key]:
					var parsed := _parse_effect(sub_eff_dict)
					if parsed: eff_list.append(parsed)
				branch_map[trig_key] = eff_list
			return EffectNodes.BranchByTrigger.new(branch_map)
			
		"branch":
			# If-Else 分支
			var cond := _parse_condition(dict.get("condition", {}))
			var true_effs: Array[Effect] = []
			for sub in dict.get("true_effects", []):
				var p := _parse_effect(sub); if p: true_effs.append(p)
			var false_effs: Array[Effect] = []
			for sub in dict.get("false_effects", []):
				var p := _parse_effect(sub); if p: false_effs.append(p)
			return EffectNodes.Branch.new(cond, true_effs, false_effs)

		# ----- 数值与常规动作节点 -----
		"draw_scavenge":
			return EffectNodes.DrawScavenge.new(dict.get("count", 1), dict.get("use_block_color", true))
			
		"draw_monster":
			return EffectNodes.DrawMonster.new(dict.get("count", 1), dict.get("target_player", "caster"))
			
		"draw_card":
			return EffectNodes.DrawCard.new(dict.get("count", 1))
			
		"add_status_mark":
			return EffectNodes.AddStatusMark.new(
				dict.get("mark_name", ""),
				dict.get("amount", 1),
				dict.get("duration", "turn_end")
			)
			
		"add_monster_mark_adjacent":
			# 补全：向相邻地块添加怪物标记
			return EffectNodes.AddMonsterMarkAdjacent.new(
				dict.get("amount", 1),
				dict.get("include_diagonals", false)
			)
			
		"cancel_event":
			return EffectNodes.CancelEvent.new()
			
		"consume_action":
			return EffectNodes.ConsumeAction.new(dict.get("amount", 1))
			
		"move_to_target":
			return EffectNodes.MoveToTarget.new()
			
		"heal":
			return EffectNodes.Heal.new(dict.get("amount", 1))
			
		"damage":
			return EffectNodes.Damage.new(dict.get("amount", 1))
			
		"change_hunger":
			return EffectNodes.ChangeHunger.new(dict.get("amount", 1))
			
		"choose_to_discard":
			return EffectNodes.ChooseToDiscard.new(dict.get("count", 1))

		_:
			push_error("未知的 Effect 类型: %s" % eff_type)
			return null