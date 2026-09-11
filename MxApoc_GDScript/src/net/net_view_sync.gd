class_name NetViewSync
extends RefCounted

## 客机视图序号：快照丢旧包；GAME_EVENT 不因序号落后丢弃，只按键去重。

const VISUAL_EVENT_NAMES := [
	"show_card",
	"dice_animation",
	"monster_draw_animation",
	"scavenge_draw_animation",
	"card_destroy_animation",
	"monster_skill_animation",
	"monster_attack_animation",
]


static func should_apply_snapshot(sequence: int, last_snapshot_sequence: int) -> bool:
	return sequence <= 0 or sequence > last_snapshot_sequence


static func event_dedup_key(sequence: int, event_name: String, payload: Variant) -> String:
	var extra := ""
	if event_name == "log" and payload is Dictionary:
		extra = str(payload.get("message", ""))
	return "%d|%s|%d|%s" % [sequence, event_name, _payload_key_id(payload), extra]


static func _payload_key_id(payload: Variant) -> int:
	if not payload is Dictionary:
		return 0
	var data: Dictionary = payload
	var direct := int(data.get("net_id", 0))
	if direct > 0:
		return direct
	for field in ["card", "monster", "player", "block"]:
		var nested: Variant = data.get(field)
		var nested_id := _entity_net_id(nested)
		if nested_id > 0:
			return nested_id
	return int(data.get("seat_id", -1))


static func _entity_net_id(value: Variant) -> int:
	if value is Dictionary:
		return int(value.get("net_id", 0))
	if value == null or not value.has_method("get"):
		return 0
	var raw: Variant = value.get("net_id")
	return int(raw) if raw != null else 0


## 客机收到 log 事件时写入结算页用的 log_list。房主已在 log_message 写过，跳过以免重复。
static func append_guest_log(log_list: Array, message: String, is_authority: bool) -> void:
	if is_authority:
		return
	log_list.append(message)


## 对局结束用权威全量日志覆盖，补漏包与中途加入。
static func apply_game_over_logs(log_list: Array, logs: Variant) -> void:
	if not (logs is Array):
		return
	log_list.clear()
	for item in logs:
		log_list.append(item)


## 结算切场景前兜底：log_list 仍空时拷对局里的临时事件日志。
static func copy_event_log_if_empty(log_list: Array, event_log: Array) -> void:
	if not log_list.is_empty() or event_log.is_empty():
		return
	for item in event_log:
		log_list.append(item)
