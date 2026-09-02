class_name NetClientInput
extends GUIPlayerInput

## 客机侧输入：接收主机 INPUT_REQUEST，复用 GUIPlayerInput 的请求队列与信号
## 驱动现有 UI（ActionSelectionController / PopupManager 等），用户响应经 respond_*
## 后编码回传主机（INPUT_RESPONSE）。

var _net_req_id: int = 0
var _net_req_type: String = ""
var _net_options: Array = []


## 重写：结算活动请求的同时把响应编码回传主机。
func _respond_active(value: Variant) -> void:
	super(value)
	if _net_req_id > 0:
		var choice: Variant = _encode_response(value)
		NetSession.client_send(NetProtocol.Msg.INPUT_RESPONSE, {"req_id": _net_req_id, "choice": choice})
		_net_req_id = 0


# === 网络请求入口（由 GameScene2D 收到 INPUT_REQUEST 后调用） ===

func net_wait_action(req_id: int, player_view: Variant) -> void:
	_net_req_id = req_id
	_net_req_type = "action"
	var req := _enqueue_request(func() -> void:
		action_requested.emit(player_view)
	)
	await _wait_for_request(req)


func net_choose(req_id: int, options: Array, prompt: String) -> void:
	_net_req_id = req_id
	_net_req_type = "choose"
	_net_options = options
	var req := _enqueue_request(func() -> void:
		choose_requested.emit(options, prompt)
	)
	await _wait_for_request(req)


func net_choose_card(req_id: int, n: int, cards: Array, prompt: String, min_n: int) -> void:
	_net_req_id = req_id
	_net_req_type = "choose_card"
	var req := _enqueue_request(func() -> void:
		choose_card_requested.emit(n, cards, null, prompt, min_n)
	)
	await _wait_for_request(req)


func net_choose_target(req_id: int, n: int, skill: Variant, prompt: String, min_n: int) -> void:
	_net_req_id = req_id
	_net_req_type = "choose_target"
	var req := _enqueue_request(func() -> void:
		choose_target_requested.emit(n, skill, prompt, min_n)
	)
	await _wait_for_request(req)


func net_choose_block(req_id: int, blocks: Array, prompt: String) -> void:
	_net_req_id = req_id
	_net_req_type = "choose_block"
	var req := _enqueue_request(func() -> void:
		choose_block_requested.emit(blocks, prompt)
	)
	await _wait_for_request(req)


func net_choose_block_inline(req_id: int, valid_blocks: Array, prompt: String, count: int) -> void:
	_net_req_id = req_id
	_net_req_type = "choose_block_inline"
	var req := _enqueue_request(func() -> void:
		choose_block_inline_requested.emit(valid_blocks, prompt, count)
	)
	await _wait_for_request(req)


func net_confirm(req_id: int, message: String) -> void:
	_net_req_id = req_id
	_net_req_type = "confirm"
	var req := _enqueue_request(func() -> void:
		confirm_requested.emit(message)
	)
	await _wait_for_request(req)


func net_redraw(req_id: int) -> void:
	_net_req_id = req_id
	_net_req_type = "redraw"
	var req := _enqueue_request(func() -> void:
		redraw_decision_requested.emit()
	)
	await _wait_for_request(req)


func net_judge_confirm(req_id: int, prompt: String, allow_cancel: bool) -> void:
	_net_req_id = req_id
	_net_req_type = "judge_confirm"
	var req := _enqueue_request(func() -> void:
		judge_confirm_requested.emit(prompt, allow_cancel)
	)
	await _wait_for_request(req)


func net_show_card(req_id: int, card: Card, target: Variant) -> void:
	_net_req_id = req_id
	_net_req_type = "show_card"
	var req := _enqueue_request(func() -> void:
		show_card_requested.emit(card, target)
	)
	await _wait_for_request(req)


func net_set_prompt(req_id: int, text: String) -> void:
	_net_req_id = req_id
	_net_req_type = "set_prompt"
	var req := _enqueue_request(func() -> void:
		set_prompt_requested.emit(text)
	)
	await _wait_for_request(req)


# === 动画请求：播放后回执（阻塞流程），暂以即时回执推进 ===

func net_anim(req_id: int, type_name: String, params: Dictionary) -> void:
	_net_req_id = req_id
	_net_req_type = type_name
	var req := _enqueue_request(func() -> void:
		match type_name:
			"anim_dice":
				dice_animation_requested.emit(int(params.get("d1", 0)), int(params.get("d2", 0)), str(params.get("label", "")), str(params.get("outcome", "")))
			"anim_monster_draw":
				monster_draw_animation_requested.emit(Game.get_current_player(), _card_by_id(int(params.get("card", 0))))
			"anim_scavenge_draw":
				scavenge_draw_animation_requested.emit(Game.get_current_player(), _card_by_id(int(params.get("card", 0))))
			"anim_card_destroy":
				card_destroy_animation_requested.emit(_card_by_id(int(params.get("card", 0))))
			"anim_monster_skill":
				monster_skill_trigger_animation_requested.emit(_card_by_id(int(params.get("monster", 0))))
			"anim_monster_attack":
				monster_attack_animation_requested.emit(_card_by_id(int(params.get("monster", 0))), [])
	)
	await _wait_for_request(req)


# === 响应编码 ===

func _encode_response(value: Variant) -> Variant:
	match _net_req_type:
		"action":
			if value is Dictionary:
				return NetInputCodec.encode_action_choice(value)
			return value
		"choose":
			# value 是选中项，映射回选项索引
			for i in range(_net_options.size()):
				if _net_options[i] == value:
					return i
			return -1
		"choose_card":
			var ids: Array = []
			if value is Array:
				for c in value:
					if c is Card:
						ids.append(c.net_id)
			return ids
		"choose_target":
			var out: Array = []
			if value is Array:
				for t in value:
					out.append(NetInputCodec.encode_target(t))
			return out
		"choose_block":
			if value is MapBlock:
				return value.coordinate
			return null
		"choose_block_inline":
			var out2: Array = []
			if value is Array:
				for b in value:
					if b is MapBlock:
						out2.append(b.coordinate)
			return out2
		"confirm", "redraw", "judge_confirm":
			return bool(value)
		_:
			return null


func _card_by_id(nid: int) -> Variant:
	if nid <= 0:
		return null
	# 玩家区域
	for player in Game.players:
		if player == null:
			continue
		for c in player.hand:
			if c is Card and c.net_id == nid:
				return c
		for eq in player.equipment_zone:
			if eq != null and eq.equipment_card != null and eq.equipment_card.net_id == nid:
				return eq.equipment_card
		for m in player.monster_zone:
			if m != null and m.net_id == nid:
				return m
		if player.game_deck != null:
			for c in player.game_deck.cards:
				if c is Card and c.net_id == nid:
					return c
		if player.game_discard_pile != null:
			for c in player.game_discard_pile.cards:
				if c is Card and c.net_id == nid:
					return c
	# 全局牌堆（抓取中的怪物/拾荒卡仍在堆内）
	for pile in [Game.monster_pile, Game.red_scavenge_pile, Game.green_scavenge_pile, Game.blue_scavenge_pile, Game.scavenge_discard_pile]:
		if pile == null:
			continue
		for c in pile.cards:
			if c is Card and c.net_id == nid:
				return c
	return null
