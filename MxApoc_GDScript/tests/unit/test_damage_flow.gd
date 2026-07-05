extends GutTest

# 测试 scripts/system/entity.gd 的 damage 方法(8 节点钩子链)。
# 覆盖 spec/iteration_03_damage_flow.md §6.1-6.7 全部用例。


var _call_log: Array[String] = []


class _SpyPlayer extends Player:
	var death_called: bool = false
	var death_source: Variant = null
	func playerDeath(source: Variant) -> void:
		death_called = true
		death_source = source


func before_each() -> void:
	_call_log.clear()


# --- 6.1 前置检查 ---

func test_damage_zero_num_returns_immediately() -> void:
	var target := Player.new()
	target.set_hp(5)
	var source := Player.new()
	target.add_skill(_make_recording_skill("受到伤害前", "T前"))
	target.damage(0, source)
	assert_eq(target.get_hp(), 5, "num=0 不扣血")
	assert_eq(_call_log, [], "num=0 不触发任何钩子")


func test_damage_negative_num_returns_immediately() -> void:
	var target := Player.new()
	target.set_hp(5)
	var source := Player.new()
	target.add_skill(_make_recording_skill("受到伤害前", "T前"))
	target.damage(-1, source)
	assert_eq(target.get_hp(), 5, "num<0 不扣血")
	assert_eq(_call_log, [], "num<0 不触发任何钩子")


func test_damage_to_dead_target_no_effect() -> void:
	var target := Player.new()
	target.set_hp(0)
	var source := Player.new()
	target.add_skill(_make_recording_skill("受到伤害前", "T前"))
	target.damage(5, source)
	assert_eq(target.get_hp(), 0, "已死亡目标 HP 不变")
	assert_eq(_call_log, [], "已死亡目标不触发钩子")


# --- 6.2 正常伤害流程(8 节点顺序) ---

func test_damage_triggers_8_nodes_in_order() -> void:
	var target := Player.new()
	var source := Player.new()
	target.add_skill(_make_recording_skill("受到伤害前", "受到伤害前"))
	target.add_skill(_make_recording_skill("受到伤害时", "受到伤害时"))
	target.add_skill(_make_recording_skill("受到伤害后", "受到伤害后"))
	source.add_skill(_make_recording_skill("造成伤害前", "造成伤害前"))
	source.add_skill(_make_recording_skill("造成伤害时", "造成伤害时"))
	source.add_skill(_make_recording_skill("造成伤害后", "造成伤害后"))
	target.damage(3, source)
	# 完整顺序:造成伤害前 → 受到伤害前 → 造成伤害时 → 受到伤害时 → (扣血) → 造成伤害后 → 受到伤害后
	assert_eq(_call_log, ["造成伤害前", "受到伤害前", "造成伤害时", "受到伤害时", "造成伤害后", "受到伤害后"], "8 节点顺序")


func test_damage_reduces_target_hp() -> void:
	var target := Player.new()
	target.set_hp(6)
	var source := Player.new()
	target.damage(3, source)
	assert_eq(target.get_hp(), 3, "HP=6 - 3 = 3")


func test_damage_default_type_empty() -> void:
	var target := Player.new()
	var captured_type: Array[String] = []
	target.add_skill(Skill.make("受到伤害时", Callable(), func(ev: Event) -> void: captured_type.append(ev.type)))
	var source := Player.new()
	target.damage(3, source)
	assert_eq(captured_type, [""], "未传 type 时 event.type == ''")


# --- 6.3 source=NULL(无来源伤害) ---

func test_damage_no_source_skips_source_hooks() -> void:
	var target := Player.new()
	var source := Player.new()
	target.add_skill(_make_recording_skill("受到伤害前", "T前"))
	target.add_skill(_make_recording_skill("受到伤害时", "T时"))
	target.add_skill(_make_recording_skill("受到伤害后", "T后"))
	source.add_skill(_make_recording_skill("造成伤害前", "S前"))
	source.add_skill(_make_recording_skill("造成伤害时", "S时"))
	source.add_skill(_make_recording_skill("造成伤害后", "S后"))
	target.damage(3, null)
	assert_eq(_call_log, ["T前", "T时", "T后"], "source=null 只触发 target 侧钩子")


func test_damage_no_source_reduces_hp() -> void:
	var target := Player.new()
	target.set_hp(5)
	target.damage(3, null)
	assert_eq(target.get_hp(), 2, "source=null 仍正常扣血")


func test_damage_no_source_triggers_target_hooks_only() -> void:
	var target := Player.new()
	target.add_skill(_make_recording_skill("受到伤害前", "受到伤害前"))
	target.add_skill(_make_recording_skill("受到伤害时", "受到伤害时"))
	target.add_skill(_make_recording_skill("受到伤害后", "受到伤害后"))
	target.damage(3, null)
	assert_eq(_call_log, ["受到伤害前", "受到伤害时", "受到伤害后"], "无来源伤害触发 3 节点")


# --- 6.4 event.num 修改 ---

func test_source_on_dealing_damage_modifies_num() -> void:
	var target := Player.new()
	target.set_hp(10)
	var source := Player.new()
	source.add_skill(Skill.make("造成伤害时", Callable(), func(ev: Event) -> void: ev.num += 2))
	target.damage(3, source)
	assert_eq(target.get_hp(), 5, "原 3 + 2 = 5 伤害")


func test_target_on_taking_damage_modifies_num() -> void:
	var target := Player.new()
	target.set_hp(10)
	var source := Player.new()
	target.add_skill(Skill.make("受到伤害时", Callable(), func(ev: Event) -> void: ev.num -= 1))
	target.damage(3, source)
	assert_eq(target.get_hp(), 8, "原 3 - 1 = 2 伤害,HP=10-2=8")


func test_both_modify_num_additively() -> void:
	var target := Player.new()
	target.set_hp(10)
	var source := Player.new()
	source.add_skill(Skill.make("造成伤害时", Callable(), func(ev: Event) -> void: ev.num += 2))
	target.add_skill(Skill.make("受到伤害时", Callable(), func(ev: Event) -> void: ev.num -= 1))
	target.damage(3, source)
	assert_eq(target.get_hp(), 6, "原 3 +2 -1 = 4 伤害,HP=10-4=6")


# --- 6.5 event.cancel()(取消点) ---

func test_cancel_at_taking_damage_prevents_hp_loss() -> void:
	var target := Player.new()
	target.set_hp(5)
	var source := Player.new()
	target.add_skill(_make_cancel_skill("受到伤害时"))
	target.damage(3, source)
	assert_eq(target.get_hp(), 5, "取消后不扣血")


func test_cancel_skips_subsequent_hooks() -> void:
	var target := Player.new()
	var source := Player.new()
	target.add_skill(_make_cancel_skill("受到伤害时"))
	target.add_skill(_make_recording_skill("受到伤害后", "T后"))
	source.add_skill(_make_recording_skill("造成伤害后", "S后"))
	target.damage(3, source)
	assert_eq(_call_log, [], "取消后造成伤害后/受到伤害后均不触发")


func test_cancel_does_not_trigger_death() -> void:
	var target := _SpyPlayer.new()
	target.set_hp(1)
	target.set_max_hp(1)
	var source := Player.new()
	target.add_skill(_make_cancel_skill("受到伤害时"))
	target.damage(5, source)
	assert_eq(target.get_hp(), 1, "HP 仍 1")
	assert_false(target.death_called, "取消后不判死亡,playerDeath 不调用")


# --- 6.6 死亡判定 ---

func test_damage_lethal_triggers_playerDeath() -> void:
	var target := _SpyPlayer.new()
	target.set_hp(3)
	var source := Player.new()
	target.damage(5, source)
	assert_eq(target.get_hp(), -2, "HP 可降至 0 以下")
	assert_true(target.death_called, "致死伤害触发 playerDeath")


func test_damage_non_lethal_no_playerDeath() -> void:
	var target := _SpyPlayer.new()
	target.set_hp(6)
	var source := Player.new()
	target.damage(3, source)
	assert_eq(target.get_hp(), 3, "非致死 HP")
	assert_false(target.death_called, "非致死不触发 playerDeath")


func test_damage_exact_lethal_triggers_death() -> void:
	var target := _SpyPlayer.new()
	target.set_hp(3)
	var source := Player.new()
	target.damage(3, source)
	assert_eq(target.get_hp(), 0, "HP=0 也判死亡")
	assert_true(target.death_called, "HP<=0 触发 playerDeath")


# --- 6.7 钩子内 event 字段可读 ---

func test_taking_damage_can_read_source() -> void:
	var target := Player.new()
	var source := Player.new()
	var captured_source: Array[Variant] = []
	target.add_skill(Skill.make("受到伤害时", Callable(), func(ev: Event) -> void: captured_source.append(ev.source)))
	target.damage(3, source)
	assert_eq(captured_source.size(), 1, "钩子触发 1 次")
	assert_eq(captured_source[0], source, "event.source 等于传入 source")


func test_dealing_damage_can_read_target() -> void:
	var target := Player.new()
	var source := Player.new()
	var captured_target: Array[Variant] = []
	source.add_skill(Skill.make("造成伤害时", Callable(), func(ev: Event) -> void: captured_target.append(ev.target)))
	target.damage(3, source)
	assert_eq(captured_target.size(), 1, "钩子触发 1 次")
	assert_eq(captured_target[0], target, "event.target 等于 target")


func test_taking_damage_can_read_type() -> void:
	var target := Player.new()
	var source := Player.new()
	var captured_type: Array[String] = []
	target.add_skill(Skill.make("受到伤害时", Callable(), func(ev: Event) -> void: captured_type.append(ev.type)))
	target.damage(3, source, "饥饿伤害")
	assert_eq(captured_type, ["饥饿伤害"], "event.type 透传")


# --- 私有辅助 ---

func _make_recording_skill(trig: String, label: String) -> Skill:
	return Skill.make(trig, Callable(), _record_callable(label))


func _make_cancel_skill(trig: String) -> Skill:
	return Skill.make(trig, Callable(), func(ev: Event) -> void:
		ev.cancel()
	)


func _record_callable(label: String) -> Callable:
	return func(_ev: Event) -> void:
		_call_log.append(label)
