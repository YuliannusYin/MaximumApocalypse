class_name NetPlayerInput
extends IPlayerInput

## 主机侧远程玩家输入：把 IPlayerInput 请求序列化为 INPUT_REQUEST 发往对应客机，
## 等待客机 INPUT_RESPONSE 后还原为对象选择。由 NetSession 把响应路由到 receive_response。

var peer_id: int = 0
## 本输入对应的玩家（主机真实 Player 对象）。
var player: Player = null

var _req_counter := 0
var _pending: Dictionary = {}  # req_id -> {done: bool, choice: Variant, type: String}


## 发起请求并等待响应。
func _send(type_name: String, params: Dictionary) -> Variant:
	_req_counter += 1
	var req_id := _req_counter
	_pending[req_id] = {"done": false, "choice": null, "type": type_name}
	NetSession.host_send_to(peer_id, NetProtocol.Msg.INPUT_REQUEST, {
		"req_id": req_id, "type": type_name, "params": params,
	})
	return await _await_response(req_id)


func _await_response(req_id: int) -> Variant:
	while not _pending[req_id]["done"]:
		await Engine.get_main_loop().process_frame
	var choice: Variant = _pending[req_id]["choice"]
	_pending.erase(req_id)
	return choice


## NetSession 收到客机 INPUT_RESPONSE 时调用。
func receive_response(req_id: int, choice: Variant) -> void:
	if _pending.has(req_id):
		_pending[req_id]["done"] = true
		_pending[req_id]["choice"] = choice


## 客机掉线时调用：以安全默认值结算所有挂起请求，避免模拟卡死。
## 不主动清空 _pending —— 每个已挂起请求由 _await_response 恢复后自行 erase。
func on_peer_disconnected() -> void:
	for req_id in _pending.keys():
		var entry: Dictionary = _pending[req_id]
		if entry["done"]:
			continue
		entry["done"] = true
		entry["choice"] = _default_response(str(entry.get("type", "")))


func _default_response(type_name: String) -> Variant:
	match type_name:
		"choose":
			return -1
		"choose_card":
			return []
		"choose_target":
			return []
		"choose_block_inline":
			return []
		"confirm":
			return false
		"redraw":
			return false
		"judge_confirm":
			return false
		"action":
			return null
		_:
			return null


# === IPlayerInput 实现 ===

func wait_action(_player: Variant) -> Variant:
	var raw: Variant = await _send("action", {})
	if raw == null:
		return null
	if raw is Dictionary:
		return NetInputCodec.decode_action_choice(player, raw)
	return raw


func choose(options: Array, prompt: String = "") -> Variant:
	var opts := NetInputCodec.serialize_options(options)
	var idx: Variant = await _send("choose", {"options": opts, "prompt": prompt})
	if idx is int and idx >= 0 and idx < options.size():
		return options[idx]
	return null


func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	var candidates: Array = []
	if param is Array:
		candidates = param
	elif param is String:
		candidates = _cards_in_position(player, param)
	if filter is Callable and (filter as Callable).is_valid():
		var fc: Callable = filter
		candidates = candidates.filter(func(c: Variant) -> bool:
			return fc.call(c)
		)
	var ids: Array = []
	for c in candidates:
		ids.append(c.net_id)
	var resp: Variant = await _send("choose_card", {"n": n, "cards": ids, "prompt": prompt, "min_n": min_n})
	var out: Array = []
	if resp is Array:
		for rid in resp:
			var card: Variant = NetRegistry.get_obj(int(rid))
			if card != null:
				out.append(card)
	return out


func choose_target(n: int, skill: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	var candidates: Array = _compute_targets(player, skill)
	var encoded: Array = []
	for t in candidates:
		encoded.append(NetInputCodec.encode_target(t))
	var skill_name := ""
	if skill != null:
		skill_name = skill.english_name
	var resp: Variant = await _send("choose_target", {"n": n, "targets": encoded, "prompt": prompt, "min_n": min_n, "skill": skill_name})
	var out: Array = []
	if resp is Array:
		for td in resp:
			var t: Variant = NetInputCodec.decode_target(Game, td)
			if t != null:
				out.append(t)
	return out


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	var coords: Array = []
	for b in blocks:
		coords.append(b.coordinate)
	var resp: Variant = await _send("choose_block", {"blocks": coords, "prompt": prompt})
	if resp is Dictionary:
		for b in Game.map_area:
			if b != null and b.coordinate == resp:
				return b
	return null


func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	var coords: Array = []
	for b in valid_blocks:
		coords.append(b.coordinate)
	var resp: Variant = await _send("choose_block_inline", {"blocks": coords, "prompt": prompt, "count": count})
	var out: Array = []
	if resp is Array:
		for c in resp:
			for b in Game.map_area:
				if b != null and b.coordinate == c:
					out.append(b)
					break
	return out


func confirm(message: String) -> bool:
	var resp: Variant = await _send("confirm", {"message": message})
	return bool(resp)


func show_card(card: Card, target: Variant) -> void:
	var td := {}
	if target != null:
		td = NetInputCodec.encode_target(target)
	NetSession.host_send_to(peer_id, NetProtocol.Msg.INPUT_REQUEST, {
		"req_id": -1, "type": "show_card", "params": {"card": card.net_id, "target": td},
	})


func set_prompt(text: String) -> void:
	NetSession.host_send_to(peer_id, NetProtocol.Msg.INPUT_REQUEST, {
		"req_id": -1, "type": "set_prompt", "params": {"text": text},
	})


func wait_redraw_decision(_player: Variant) -> bool:
	var resp: Variant = await _send("redraw", {})
	return bool(resp)


func wait_judge_confirm(_player: Variant, prompt: String, allow_cancel: bool) -> bool:
	var resp: Variant = await _send("judge_confirm", {"prompt": prompt, "allow_cancel": allow_cancel})
	return bool(resp)


# === 动画请求（客机端自动/播放后回执，阻塞期间不推进） ===

func play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	await _send("anim_dice", {"d1": d1, "d2": d2, "label": label, "outcome": outcome})


func play_monster_draw_animation(_player: Variant, card: Variant) -> void:
	await _send("anim_monster_draw", {"card": card.net_id if card != null else 0})


func play_scavenge_draw_animation(_player: Variant, card: Variant) -> void:
	await _send("anim_scavenge_draw", {"card": card.net_id if card != null else 0})


func play_card_destroy_animation(card: Card) -> void:
	await _send("anim_card_destroy", {"card": card.net_id})


func play_monster_skill_trigger_animation(monster: Variant) -> void:
	await _send("anim_monster_skill", {"monster": monster.net_id if monster != null else 0})


func play_monster_attack_animation(monster: Variant, _targets: Array) -> void:
	await _send("anim_monster_attack", {"monster": monster.net_id if monster != null else 0})


# === 主机侧候选计算 ===

## 按位置获取玩家区域的卡牌（choose_card 的 param 字符串形式）。
func _cards_in_position(player: Player, position: String) -> Array:
	if player == null:
		return []
	match position:
		"hand":
			return player.hand
		"equipment":
			var out: Array = []
			for eq in player.equipment_zone:
				if eq != null and eq.equipment_card != null:
					out.append(eq.equipment_card)
			return out
		"discard":
			return player.game_discard_pile.cards if player.game_discard_pile != null else []
		"settlement":
			return player.card_settlement_zone
	return []


## 计算 choose_target 候选（复刻 game_scene_2d._on_choose_target_requested 逻辑）。
func _compute_targets(current: Player, skill: Variant) -> Array:
	var candidates: Array = []
	if current == null:
		return candidates
	var current_block: Variant = current.current_block
	var target_type := ""
	var filter_target_range := "short"
	if skill != null:
		target_type = str(_skill_get(skill, "target_type", ""))
		var ftr: Variant = _skill_get(skill, "filter_target_range", "")
		if ftr != null and str(ftr) != "":
			filter_target_range = str(ftr)
	match target_type:
		"block":
			if current_block != null and is_instance_valid(current_block):
				candidates = current_block.get_blocks_in_range(filter_target_range)
		"equipment":
			if current.equipment_zone != null:
				candidates = current.equipment_zone
		_:
			if current_block != null and is_instance_valid(current_block):
				candidates = current_block.get_players_in_range(filter_target_range)
				candidates.append_array(current_block.get_players())
			if current.monster_zone != null:
				for m in current.monster_zone:
					if m != null:
						candidates.append(m)
			if current_block != null and is_instance_valid(current_block):
				for other in current_block.get_players_in_range(filter_target_range):
					if other == current:
						continue
					if "monster_zone" in other:
						for m in other.monster_zone:
							if m != null and not candidates.has(m):
								candidates.append(m)
			# 去重
			var seen: Dictionary = {}
			var deduped: Array = []
			for c in candidates:
				if c == null or not is_instance_valid(c):
					continue
				var key: int = c.get_instance_id()
				if seen.has(key):
					continue
				seen[key] = true
				deduped.append(c)
			candidates = deduped
	# filter_target 过滤
	var filtered: Array = []
	var event := {"player": current, "target": null, "card": null}
	for target in candidates:
		if target == null or not is_instance_valid(target):
			continue
		event["target"] = target
		if _is_valid_target(skill, target, event, current):
			filtered.append(target)
	return filtered


func _is_valid_target(skill: Variant, target: Variant, event: Dictionary, player: Variant) -> bool:
	if skill == null:
		return true
	if skill is Dictionary:
		var fc_str: Variant = skill.get("filter_target", null)
		if fc_str is String and str(fc_str) != "":
			var compiled: Callable = CodeExecutor.compile_filter_target(fc_str)
			if compiled.is_valid():
				return bool(compiled.call(player, target, event, Game))
		return true
	# Skill 实例
	var fc: Variant = _skill_get(skill, "filter_target", null)
	if fc is Callable and (fc as Callable).is_valid():
		return bool((fc as Callable).call(player, target, event, Game))
	return true


## Skill 可能是对象（Skill）或字典，统一安全读取属性（Dictionary 用双参 get，Object 用单参 get）。
func _skill_get(skill: Variant, prop: String, default: Variant) -> Variant:
	if skill == null:
		return default
	if skill is Dictionary:
		return skill.get(prop, default)
	var v: Variant = skill.get(prop)
	return v if v != null else default
