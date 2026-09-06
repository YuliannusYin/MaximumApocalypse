class_name AIPlayerInput
extends IPlayerInput

## AI 玩家输入。决策直接返回值，不入 GUI InputRequest 栈。
## 动画方法可委托给 GUIPlayerInput，供真人旁观。

const AiScorerScript = preload("res://src/ai/ai_scorer.gd")
const LegalActionsScript = preload("res://src/ai/legal_actions.gd")
const REDRAW_AVG_THRESHOLD := 70.0
const REDRAW_MAX_COUNT := 20

var scorer = AiScorerScript.new()
var animation_input: IPlayerInput = null
var think_seconds: float = 0.0
var _owner: Variant = null
var _repeat_key: String = ""
var _repeat_count: int = 0
var _redraw_count: int = 0


func set_request_owner(player: Variant) -> void:
	_owner = player


func get_active_request_id() -> int:
	return -1


func get_active_request_owner() -> Variant:
	return _owner


func wait_action(player: Variant) -> Variant:
	_owner = player
	await _think()
	var actions: Array = LegalActionsScript.enumerate(player)
	var best: Variant = null
	var best_score: float = 0.0
	for action in actions:
		var score: float = scorer.score_action(player, action)
		if score > best_score:
			best_score = score
			best = action
	if best == null or best_score <= 0.0:
		_reset_repeat()
		return null
	var key: String = _fingerprint(best)
	if key == _repeat_key:
		_repeat_count += 1
	else:
		_repeat_key = key
		_repeat_count = 1
	if _repeat_count >= 3:
		_reset_repeat()
		return null
	return best


func choose(options: Array, prompt: String = "") -> Variant:
	await _think()
	if options.is_empty():
		return null
	var player: Variant = _owner
	var best: Variant = options[0]
	var best_score: float = -INF
	for option in options:
		var score: float = scorer.check_item(player, null, option)
		if score > best_score:
			best_score = score
			best = option
	return best


func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	await _think()
	var player: Variant = _owner
	var candidates: Array = _card_candidates(player, param, filter)
	if candidates.is_empty():
		return []
	var discard: bool = prompt.contains("弃")
	var scored: Array = []
	for card in candidates:
		var value: float = scorer.useful(player, card)
		if discard:
			value = -value
		scored.append({"card": card, "score": value})
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var exact: bool = min_n < 0
	var need: int = n
	if need < 0:
		need = candidates.size()
	if need > scored.size():
		need = scored.size()
	var picked: Array = []
	for i in range(need):
		var item: Dictionary = scored[i]
		if not exact and min_n >= 0 and float(item["score"]) <= 0.0 and picked.size() >= mini(min_n, 0):
			break
		picked.append(item["card"])
	if exact and picked.size() < n and n > 0:
		return picked
	return picked


func choose_target(n: int, skill: Variant, prompt: String = "", min_n: int = -1) -> Array:
	await _think()
	var player: Variant = _owner
	if player == null or not player.has_method("get_skill_valid_targets"):
		return []
	var candidates: Array = player.get_skill_valid_targets(skill)
	if candidates.is_empty():
		return []
	var damage: bool = scorer.is_damage_obj(skill)
	if damage:
		var non_players: Array = scorer.non_player_targets(candidates)
		if not non_players.is_empty():
			candidates = non_players
	if n < 0:
		return candidates.duplicate()
	var scored: Array = []
	for target in candidates:
		var score: float = scorer.score_damage_target(player, skill, target) if damage else scorer.effect(player, skill, target)
		scored.append({"target": target, "score": score})
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var exact: bool = min_n < 0
	var need: int = n
	if need > scored.size():
		need = scored.size()
	var picked: Array = []
	for i in range(need):
		var item: Dictionary = scored[i]
		if not exact and float(item["score"]) <= 0.0 and picked.size() >= maxi(min_n, 0):
			break
		if exact or float(item["score"]) > 0.0 or picked.size() < maxi(min_n, 0):
			picked.append(item["target"])
	return picked


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	await _think()
	if blocks.is_empty():
		return null
	var player: Variant = _owner
	var best: Variant = blocks[0]
	var best_score: float = -INF
	for block in blocks:
		var score: float = scorer.score_block(player, block)
		if score > best_score:
			best_score = score
			best = block
	return best


func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	await _think()
	if valid_blocks.is_empty():
		return []
	var player: Variant = _owner
	var scored: Array = []
	for block in valid_blocks:
		scored.append({"block": block, "score": scorer.score_block(player, block)})
	scored.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var n: int = maxi(count, 1)
	if n > scored.size():
		n = scored.size()
	var picked: Array = []
	for i in range(n):
		picked.append(scored[i]["block"])
	return picked


func confirm(message: String) -> bool:
	await _think()
	if message.contains("伤害") or message.contains("否则"):
		return true
	if message.contains("取消"):
		return true
	return true


func show_card(card: Card, target: Variant) -> void:
	if animation_input != null:
		animation_input.show_card(card, target)


func set_prompt(text: String) -> void:
	if animation_input != null:
		animation_input.set_prompt(text)


func wait_redraw_decision(player: Variant) -> bool:
	_owner = player
	await _think()
	if player == null or player.hand == null or player.hand.is_empty():
		return false
	var total: float = 0.0
	for card in player.hand:
		total += scorer.useful(player, card)
	var avg: float = total / float(player.hand.size())
	if avg >= REDRAW_AVG_THRESHOLD:
		return false
	if _redraw_count >= REDRAW_MAX_COUNT:
		return false
	_redraw_count += 1
	return true


func wait_judge_confirm(player: Variant, prompt: String, allow_cancel: bool) -> bool:
	_owner = player
	await _think()
	if not allow_cancel:
		return true
	if player == null:
		return true
	var block: Variant = player.get_current_block() if player.has_method("get_current_block") else null
	if block != null and block.has_method("has_monster_mark") and block.has_monster_mark():
		return true
	if player.get_effective_action_count() > 0:
		return true
	return true


func play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	if animation_input != null:
		_bind_animation_owner()
		await animation_input.play_dice_animation(d1, d2, label, outcome)


func play_monster_draw_animation(player: Variant, card: Variant) -> void:
	if animation_input != null:
		_bind_animation_owner(player)
		await animation_input.play_monster_draw_animation(player, card)


func play_scavenge_draw_animation(player: Variant, card: Variant) -> void:
	if animation_input != null:
		_bind_animation_owner(player)
		await animation_input.play_scavenge_draw_animation(player, card)


func play_card_destroy_animation(card: Card) -> void:
	if animation_input != null:
		_bind_animation_owner()
		await animation_input.play_card_destroy_animation(card)


func play_monster_skill_trigger_animation(monster: Variant) -> void:
	if animation_input != null:
		_bind_animation_owner()
		await animation_input.play_monster_skill_trigger_animation(monster)


func play_monster_attack_animation(monster: Variant, targets: Array) -> void:
	if animation_input != null:
		_bind_animation_owner()
		await animation_input.play_monster_attack_animation(monster, targets)


## 动画走共享 GUI 输入栈，必须先写入所属玩家；否则会落入 `"__system__"` 字符串 owner。
func _bind_animation_owner(player: Variant = null) -> void:
	if animation_input == null or not animation_input.has_method("set_request_owner"):
		return
	var who: Variant = player if player != null else _owner
	if who != null:
		animation_input.set_request_owner(who)


func _think() -> void:
	if think_seconds <= 0.0:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(think_seconds).timeout


func _card_candidates(player: Variant, param: Variant, filter: Variant) -> Array:
	var cards: Array = []
	if typeof(param) == TYPE_ARRAY:
		cards = param
	elif player != null and player.has_method("get_cards"):
		cards = player.get_cards(str(param))
	if not (filter is Callable) or not filter.is_valid():
		return cards
	var filtered: Array = []
	for card in cards:
		if filter.call(player, card, {}, Game):
			filtered.append(card)
	return filtered


func _fingerprint(choice: Variant) -> String:
	if typeof(choice) != TYPE_DICTIONARY:
		return str(choice)
	var action_type: String = str(choice.get("type", ""))
	match action_type:
		"card":
			var card: Variant = choice.get("card")
			return "card:%s" % str(card.get("english_name") if card != null else "")
		"skill":
			var skill: Variant = choice.get("skill")
			return "skill:%s" % str(skill.get("english_name") if skill != null else "")
		"move":
			var block: Variant = choice.get("target")
			if block != null and block.has_method("get_coordinate"):
				return "move:%s" % str(block.get_coordinate())
			return "move"
		"pile_draw":
			return "pile:%s" % str(choice.get("pile_key", ""))
		_:
			return action_type


func _reset_repeat() -> void:
	_repeat_key = ""
	_repeat_count = 0
