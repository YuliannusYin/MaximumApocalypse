class_name Monster
extends Entity

## 怪物类。
## 继承 Entity。职责：怪物实体的属性、行动/攻击流程与死亡流程。
## 设计文档：GameDesignDocus/GameSystem/Entities/Monster.md
## 实体化由 MonsterCard.instantiate(player) 完成（复制卡面数据到 Monster 实例）。

## 怪物名（来自 MonsterCard.card_name）
var monster_name: String = ""

## 怪物类型："alien"（外星人）/ "mutant"（突变体）/ "zombie"（僵尸）/ "robot"（机器人）
var monster_type: String = ""

## 怪物英文名（来自 MonsterCard.english_name）。归档怪物击杀统计的分型键
var english_name: String = ""

## 怪物级别："boss"（首领）/ "elite"（精英）/ "normal"（普通）
var monster_level: String = "normal"

## 当前生命值。≤ 0 时进入死亡流程
var hp: int = 0

## 最大生命值上限
var max_hp: int = 0

## 攻击伤害值
var damage_value: int = 0

## 射程："none"（只攻击纠缠玩家）/ "short" / "medium" / "long" / "infinity"
var range: String = "none"

## 纠缠的玩家。怪物只攻击其纠缠对象所在地块的玩家（按射程）
var attack_target: Player = null

## 来源怪物卡（死亡后进入怪物弃牌堆用）
var monster_card: MonsterCard = null

## 击晕状态。击晕的怪物跳过下次行动，击晕仅持续到下次行动
var stunned: bool = false


# === Entity 抽象方法实现 ===

func get_hp() -> int:
	return hp


func get_max_hp() -> int:
	return max_hp


func reduce_hp(n: int) -> void:
	hp = maxi(hp - n, 0)


func add_hp(n: int) -> void:
	hp = mini(hp + n, max_hp)


func is_monster() -> bool:
	return true


## 返回怪物的所属玩家（monster_zone 持有该怪的玩家）。
## 怪物不直接持有玩家引用，需遍历 Game.players 查找。
## Game 无效或未找到所属玩家时返回 null。
func get_owner_player() -> Player:
	if Game == null or not is_instance_valid(Game):
		return null
	for p in Game.players:
		if p == null or not is_instance_valid(p):
			continue
		if "monster_zone" in p and p.monster_zone.has(self):
			return p
	return null


## 返回怪物所在的地块。
## 怪物不直接持有地块引用，经所属玩家（monster_zone 持有者）的当前地块取得。
## 未找到所属玩家时返回 null。
func get_current_block() -> MapBlock:
	var owner: Player = get_owner_player()
	if owner == null:
		return null
	return owner.get_current_block()


## 覆写基类钩子：怪物技能通过 filter 后、content 执行前播放"触发怪物技能"动画。
## 经所属玩家（monster_zone 持有者）的 input 播放；找不到所属玩家或 input 时静默跳过。
func _notify_monster_skill_triggered() -> void:
	var owner: Player = get_owner_player()
	if owner == null or not is_instance_valid(owner):
		return
	if owner.input == null or not is_instance_valid(owner.input):
		return
	# 与 Player 其它输入请求一致：先标记所属玩家，避免 owner 落到字符串 "__system__"，
	# 进而在地图刷新里出现 Player == String 崩溃。
	if owner.has_method("_prepare_input_request"):
		owner._prepare_input_request()
	await owner.input.play_monster_skill_trigger_animation(self)


# === 纠缠对象 ===

## 修改纠缠对象。设计文档方法：修改纠缠对象(target)。
## 用于僵尸潜行者（攻击后改纠缠血量最低玩家）、枪手/消防员（嘲讽使怪物纠缠自己）。
func change_engaged_target(target: Player) -> void:
	var old_target: Player = attack_target
	attack_target = target
	# 实际移动怪物：从 old_target.monster_zone 移除，追加到 target.monster_zone
	if old_target != null and is_instance_valid(old_target) and "monster_zone" in old_target:
		old_target.monster_zone.erase(self)
	if target != null and is_instance_valid(target) and "monster_zone" in target:
		if not target.monster_zone.has(self):
			target.monster_zone.append(self)
	# 纠缠日志
	if target != null and is_instance_valid(target) and target != old_target:
		if Game != null and is_instance_valid(Game):
			Game.log_message(LogColors.monster(monster_name) + " 纠缠了 " + LogColors.player(target.player_name))
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.monster_engaged_target_changed.emit(self, old_target, target)


## 事件化的纠缠对象变更；保留旧方法兼容既有数据。
func change_engaged_target_evented(target: Player) -> bool:
	var event: Dictionary = EventSystem.create_engaged_target_event(self, target)
	await trigger("before_change_engaged_target", event)
	if EventSystem.is_cancelled(event):
		return false
	await trigger("on_change_engaged_target", event)
	if EventSystem.is_cancelled(event):
		return false
	change_engaged_target(event["target"])
	await trigger("after_change_engaged_target", event)
	return true


# === 行动流程（6 节点） ===

## 击晕怪物（灭火器使用）。设置 stunned=true，怪物下回合行动时清除并跳过行动。
## expire_trigger 由调用方语义约定（如 "before_next_turn_start"），
## 实际清除由 act() 开头已有的 stunned 检查负责，故此处仅置标志。
func stun(source: Variant, expire_trigger: String) -> void:
	stunned = true


## 事件化的击晕；保留旧方法兼容既有数据。
## runtime 为可选的统一事件调度 runtime，见 Entity.damage 说明。
func stun_evented(source: Variant, expire_trigger: String, runtime: Variant = null) -> bool:
	var scheduler: Variant = runtime if runtime != null else Game.event_scheduler
	return await scheduler.dispatch("stun", func() -> bool:
		var event: Dictionary = EventSystem.create_stun_event(self, source, expire_trigger)
		await trigger("before_stun", event)
		if EventSystem.is_cancelled(event):
			return false
		await trigger("on_stun", event)
		if EventSystem.is_cancelled(event):
			return false
		stun(source, expire_trigger)
		await trigger("after_stun", event)
		return true,
		{"target": self, "source": source, "expire_trigger": expire_trigger})


## 怪物行动流程。
## 击晕的怪物跳过行动；击晕仅持续到下次行动。
## 节点：before_monster_act → on_monster_act → before_monster_attack → on_monster_attack 前（含攻击演出）→ on_monster_attack + _attack() → after_monster_attack → after_monster_act
## runtime 为可选的统一事件调度 runtime，见 Entity.damage 说明。
func act(runtime: Variant = null) -> void:
	# 击晕的怪物跳过行动，击晕仅持续到下次行动
	if stunned:
		stunned = false
		return

	var scheduler: Variant = runtime if runtime != null else Game.event_scheduler
	await scheduler.dispatch("monster_act", func() -> void:
		var event: Dictionary = EventSystem.create_monster_act_event(self)

		# 1. before_monster_act
		await trigger("before_monster_act", event)

		# 2. on_monster_act
		await trigger("on_monster_act", event)

		# 3. before_monster_attack
		await trigger("before_monster_attack", event)

		# 4. on_monster_attack + 调用 _attack()
		# 先填充 target_players，供 on_monster_attack 数据技能（如突变体中毒、外星人技能）遍历
		event["target_players"] = _get_attack_targets()
		# 攻击演出：目标非空时先播放居中怪物牌 + 血红色箭头动画（经所属玩家 input）
		if not event["target_players"].is_empty():
			await _play_attack_animation(event["target_players"])
		await trigger("on_monster_attack", event)
		await _attack(scheduler)

		# 5. after_monster_attack
		await trigger("after_monster_attack", event)

		# 6. after_monster_act
		await trigger("after_monster_act", event),
		{"target": self})


# === 攻击流程 ===

## 计算攻击目标列表。
## 以纠缠玩家所在地块为中心，按射程确定攻击目标列表。
## range="none" 时只攻击纠缠玩家，无需查询地块。
## attack_target 为 null/无效或其所在地块为 null 时返回空列表。
func _get_attack_targets() -> Array:
	if attack_target == null or not is_instance_valid(attack_target):
		return []

	if range == "none":
		# 只攻击纠缠玩家，无需地块查询
		return [attack_target]

	var block: MapBlock = attack_target.get_current_block()
	if block == null:
		return []
	return block.get_players_in_range(range, true)


## 怪物根据射程对目标发动攻击。
## 对 _get_attack_targets() 返回的每个存活目标造成伤害（source = self）。
func _attack(runtime: Variant = null) -> void:
	var targets: Array = _get_attack_targets()

	for target in targets:
		if target != null and is_instance_valid(target) and target.is_alive():
			if Game != null and is_instance_valid(Game):
				Game.log_message(LogColors.monster(monster_name) + " 攻击了 " + LogColors.player(target.player_name))
			await target.damage(damage_value, self, "monster_attack", null, runtime)


## 播放"怪物攻击"动画：经所属玩家 input 请求，阻塞至播完；无所属玩家或 input 时跳过。
func _play_attack_animation(targets: Array) -> void:
	var owner: Player = get_owner_player()
	if owner == null or not is_instance_valid(owner):
		return
	if owner.input == null or not is_instance_valid(owner.input):
		return
	if owner.has_method("_prepare_input_request"):
		owner._prepare_input_request()
	await owner.input.play_monster_attack_animation(self, targets)


# === 死亡流程（3 节点） ===

## 实现 Entity.death。
## 流程：before_monster_death → on_monster_death → after_monster_death（从怪物区移除 + 进入怪物弃牌堆）
## 取消点：无（死亡流程不可取消）。runtime 为可选的统一事件调度 runtime，见 Entity.damage 说明。
func death(source: Entity, runtime: Variant = null) -> void:
	var scheduler: Variant = runtime if runtime != null else Game.event_scheduler
	await scheduler.dispatch("monster_death", func() -> void:
		if Game != null and is_instance_valid(Game):
			if source != null and source.is_player():
				Game.log_message(LogColors.monster(monster_name) + " 被 " + LogColors.player(source.player_name) + " 击杀")
			else:
				Game.log_message(LogColors.monster(monster_name) + " 被击杀")
		var event: Dictionary = EventSystem.create_monster_death_event(self, source)

		# 1. before_monster_death
		await trigger("before_monster_death", event)

		# 2. on_monster_death（如僵尸女王、爆破机器人、方阵机器人）
		await trigger("on_monster_death", event)
		# 向所有玩家怪物区中的其他存活怪物广播，使跨怪物监听技能（如僵尸女王）能触发
		if Game != null and is_instance_valid(Game):
			for _p in Game.players:
				if _p == null or not is_instance_valid(_p):
					continue
				for _m in _p.monster_zone:
					if _m == null or not is_instance_valid(_m) or _m == self:
						continue
					await _m.trigger("on_monster_death", event)

		# 向击杀者（玩家）触发，使玩家身上的 on_monster_death 技能（如搜索尸体）能触发
		if source != null and is_instance_valid(source) and source.has_method("is_player") and source.is_player():
			await source.trigger("on_monster_death", event)

		# 3. after_monster_death：从纠缠玩家怪物区移除 + 进入怪物弃牌堆
		if attack_target != null and is_instance_valid(attack_target):
			if "monster_zone" in attack_target:
				attack_target.monster_zone.erase(self)
		if Game != null and is_instance_valid(Game):
			if Game.monster_discard_pile != null:
				Game.monster_discard_pile.add(self.monster_card)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.monster_died.emit(self, source)

		await trigger("after_monster_death", event),
		{"target": self, "source": source})
