extends GutTest

# 测试 scripts/system/entity.gd 的 trigger 方法。
# 覆盖 spec/iteration_01_event_trigger.md §6.1-6.6 全部用例。

var _call_log: Array[String] = []


func before_each() -> void:
	_call_log.clear()


# --- 6.1 触发链顺序 ---

func test_trigger_calls_matching_skills_in_order() -> void:
	var entity := Entity.new()
	entity.add_skill(_make_recording_skill("受到伤害时", "A"))
	entity.add_skill(_make_recording_skill("受到伤害时", "B"))
	entity.add_skill(_make_recording_skill("受到伤害时", "C"))
	var event := Event.new()
	entity.trigger("受到伤害时", event)
	assert_eq(_call_log, ["A", "B", "C"], "技能应按添加顺序触发")


# --- 6.2 filter 过滤 ---

func test_trigger_skills_with_false_filter_not_called() -> void:
	var entity := Entity.new()
	entity.add_skill(Skill.make("受到伤害时", func(event: Event) -> bool: return false, _record_callable("A")))
	entity.add_skill(_make_recording_skill("受到伤害时", "B"))
	var event := Event.new()
	entity.trigger("受到伤害时", event)
	assert_eq(_call_log, ["B"], "filter 返回 false 的技能 content 不被调用")


func test_trigger_no_skills_matching() -> void:
	var entity := Entity.new()
	var event := Event.new()
	entity.trigger("不存在的事件", event)
	assert_eq(_call_log, [], "无技能匹配时正常返回不崩溃")
	assert_false(event.cancelled, "无技能时 cancelled 保持 false")


# --- 6.3 复合 trigger(、分隔) ---

func test_trigger_matches_skill_with_multiple_trigger_names() -> void:
	var entity := Entity.new()
	entity.add_skill(_make_recording_skill("游戏开始时、受到伤害时", "X"))
	var event := Event.new()
	entity.trigger("受到伤害时", event)
	assert_eq(_call_log, ["X"], "复合 trigger 的子串应匹配")
	_call_log.clear()
	entity.trigger("游戏开始时", Event.new())
	assert_eq(_call_log, ["X"], "复合 trigger 的另一子串也应匹配")
	_call_log.clear()
	entity.trigger("造成伤害时", Event.new())
	assert_eq(_call_log, [], "未在复合 trigger 中的名字不应匹配")


# --- 6.4 event.cancel() 中断 ---

func test_cancel_stops_subsequent_skills() -> void:
	var entity := Entity.new()
	entity.add_skill(_make_recording_skill("受到伤害时", "A"))
	entity.add_skill(_make_cancel_skill("受到伤害时", "B"))
	entity.add_skill(_make_recording_skill("受到伤害时", "C"))
	var event := Event.new()
	entity.trigger("受到伤害时", event)
	assert_eq(_call_log, ["A", "B"], "cancel 后续技能不再调用")
	assert_true(event.cancelled, "cancelled 应为 true")


func test_cancel_does_not_affect_already_executed() -> void:
	var entity := Entity.new()
	entity.add_skill(_make_recording_skill("受到伤害时", "A"))
	entity.add_skill(_make_cancel_skill("受到伤害时", "B"))
	var event := Event.new()
	entity.trigger("受到伤害时", event)
	assert_eq(_call_log, ["A", "B"], "已执行技能的副作用保留")


# --- 6.5 event 成员可读写 ---

func test_trigger_name_set_before_loop() -> void:
	var entity := Entity.new()
	var captured: Array[String] = []
	entity.add_skill(Skill.make("受到伤害时", Callable(), func(event: Event) -> void: captured.append(event.trigger_name)))
	var event := Event.new()
	entity.trigger("受到伤害时", event)
	assert_eq(captured, ["受到伤害时"], "技能 content 内 event.trigger_name 应为触发的名字")


func test_skill_content_can_modify_event_num() -> void:
	var entity := Entity.new()
	entity.add_skill(Skill.make("受到伤害时", Callable(), func(event: Event) -> void: event.num += 5))
	var event := Event.new()
	event.num = 10
	entity.trigger("受到伤害时", event)
	assert_eq(event.num, 15, "技能 content 应能修改 event.num")


func test_skill_filter_can_read_event_fields() -> void:
	var entity := Entity.new()
	entity.add_skill(Skill.make(
		"受到伤害时",
		func(event: Event) -> bool: return event.source != null,
		_record_callable("A")
	))
	var event_with_source := Event.new()
	event_with_source.source = Entity.new()
	entity.trigger("受到伤害时", event_with_source)
	assert_eq(_call_log, ["A"], "source != null 时 filter 通过,技能执行")
	_call_log.clear()
	var event_no_source := Event.new()
	event_no_source.source = null
	entity.trigger("受到伤害时", event_no_source)
	assert_eq(_call_log, [], "source == null 时 filter 拒绝,技能不执行")


# --- 6.6 source=NULL 容忍 ---

func test_trigger_with_null_source() -> void:
	var entity := Entity.new()
	entity.add_skill(_make_recording_skill("受到伤害时", "A"))
	var event := Event.new()
	event.source = null
	entity.trigger("受到伤害时", event)
	assert_eq(_call_log, ["A"], "source = null 时不崩溃,技能正常触发")


# --- 私有辅助 ---

func _make_recording_skill(trig: String, label: String) -> Skill:
	return Skill.make(trig, Callable(), _record_callable(label))


func _make_cancel_skill(trig: String, label: String) -> Skill:
	return Skill.make(trig, Callable(), func(event: Event) -> void:
		_call_log.append(label)
		event.cancel()
	)


func _record_callable(label: String) -> Callable:
	return func(event: Event) -> void:
		_call_log.append(label)
