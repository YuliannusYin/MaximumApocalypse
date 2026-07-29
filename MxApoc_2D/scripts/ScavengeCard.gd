#ScavengeCard.gd
extends Node2D

signal hovered
signal hovered_off

var card_position
var is_revealed: bool = false

# 拾荒卡牌数据（运行时由 ScavengeCardDeck 注入）
var card_data: Dictionary = {}
# 卡牌中文名（便于调试，与 card_data["card_name"] 一致）
var card_name: String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_parent().connect_card_signals(self)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
