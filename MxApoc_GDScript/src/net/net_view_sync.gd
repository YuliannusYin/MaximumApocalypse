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
	return "%d|%s|%d" % [sequence, event_name, _payload_key_id(payload)]


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
