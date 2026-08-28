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


## 返回怪物所在的地块。
## 怪物不直接持有地块引用，需遍历 Game.players 找到其所属玩家
## （怪物在该玩家的 monster_zone 中），返回该玩家的当前地块。
## 未找到所属玩家时返回 null。
func get_current_block() -> MapBlock:
	if Game == null or not is_instance_valid(Game):
		return null
	for p in Game.players:
		if p == null or not is_instance_valid(p):
			continue
		if "monster_zone" in p and p.monster_zone.has(self):
			return p.get_current_block()
	return null


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


# === 行动流程（6 节点） ===

## 击晕怪物（灭火器使用）。设置 stunned=true，怪物下回合行动时清除并跳过行动。
## expire_trigger 由调用方语义约定（如 "before_next_turn_start"），
## 实际清除由 act() 开头已有的 stunned 检查负责，故此处仅置标志。
func stun(source: Variant, expire_trigger: String) -> void:
	stunned = true


## 怪物行动流程。
## 击晕的怪物跳过行动；击晕仅持续到下次行动。
## 节点：before_monster_act → on_monster_act → before_monster_attack → on_monster_attack + _attack() → after_monster_attack → after_monster_act
func act() -> void:
	# 击晕的怪物跳过行动，击晕仅持续到下次行动
	if stunned:
		stunned = false
		return

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
	await trigger("on_monster_attack", event)
	_attack()

	# 5. after_monster_attack
	await trigger("after_monster_attack", event)

	# 6. after_monster_act
	await trigger("after_monster_act", event)


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
func _attack() -> void:
	var targets: Array = _get_attack_targets()

	for target in targets:
		if target != null and is_instance_valid(target) and target.is_alive():
			if Game != null and is_instance_valid(Game):
				Game.log_message(LogColors.monster(monster_name) + " 攻击了 " + LogColors.player(target.player_name))
			target.damage(damage_value, self, "monster_attack")


# === 死亡流程（3 节点） ===

## 实现 Entity.death。
## 流程：before_monster_death → on_monster_death → after_monster_death（从怪物区移除 + 进入怪物弃牌堆）
## 取消点：无（死亡流程不可取消）
func death(source: Entity) -> void:
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

	await trigger("after_monster_death", event)
