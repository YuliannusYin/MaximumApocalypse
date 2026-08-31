class_name AnimationController
extends Control

## 统一动画入口。
## 具体动画仍由独立视图负责视觉细节；本控制器统一生命周期、挂载层级和调用接口，
## 使 GameScene2D 不再直接依赖多个动画脚本。

const DICE_VIEW_SCRIPT := preload("res://src/ui/dice_animation_view.gd")
const MONSTER_DRAW_VIEW_SCRIPT := preload("res://src/ui/monster_draw_animation_view.gd")
const SKILL_TRIGGER_VIEW_SCRIPT := preload("res://src/ui/skill_trigger_animation_view.gd")
const MONSTER_SKILL_TRIGGER_VIEW_SCRIPT := preload("res://src/ui/monster_skill_trigger_animation_view.gd")
const MONSTER_ATTACK_VIEW_SCRIPT := preload("res://src/ui/monster_attack_animation_view.gd")
const TARGET_LINK_VIEW_SCRIPT := preload("res://src/ui/target_link_animation_view.gd")
const CARD_DESTROY_VIEW_SCRIPT := preload("res://src/ui/card_destroy_animation_view.gd")
const TURN_BANNER_VIEW_SCRIPT := preload("res://src/ui/turn_banner_view.gd")

var _dice_view: DiceAnimationView
var _monster_draw_view: MonsterDrawAnimationView
var _skill_trigger_view: SkillTriggerAnimationView
var _monster_skill_trigger_view: MonsterSkillTriggerAnimationView
var _monster_attack_view: MonsterAttackAnimationView
var _card_destroy_view: CardDestroyAnimationView
var _turn_banner_view: TurnBannerView
var _target_link_layer: CanvasLayer
var _target_link_view: TargetLinkAnimationView


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_animation_views()


## 创建并挂载全部全屏动画视图。视图本身只负责一种演出，控制器负责统一持有。
func _build_animation_views() -> void:
	_dice_view = DICE_VIEW_SCRIPT.new()
	add_child(_dice_view)
	_monster_draw_view = MONSTER_DRAW_VIEW_SCRIPT.new()
	add_child(_monster_draw_view)
	_skill_trigger_view = SKILL_TRIGGER_VIEW_SCRIPT.new()
	add_child(_skill_trigger_view)
	_monster_skill_trigger_view = MONSTER_SKILL_TRIGGER_VIEW_SCRIPT.new()
	add_child(_monster_skill_trigger_view)
	_monster_attack_view = MONSTER_ATTACK_VIEW_SCRIPT.new()
	add_child(_monster_attack_view)
	_card_destroy_view = CARD_DESTROY_VIEW_SCRIPT.new()
	add_child(_card_destroy_view)
	_turn_banner_view = TURN_BANNER_VIEW_SCRIPT.new()
	add_child(_turn_banner_view)

	# 目标指向演出必须位于最高 UI 层，避免被弹窗和其他全屏演出遮挡。
	_target_link_layer = CanvasLayer.new()
	_target_link_layer.layer = 3
	add_child(_target_link_layer)
	_target_link_view = TARGET_LINK_VIEW_SCRIPT.new()
	_target_link_layer.add_child(_target_link_view)


## 以下方法是统一的公共契约，均可 await；完成后才返回。
func play_dice(d1: int, d2: int, label: String, outcome: String) -> void:
	await _dice_view.play(d1, d2, label, outcome)


func play_monster_draw(card: MonsterCard, target_position: Vector2) -> void:
	await _monster_draw_view.play(card, target_position)


func play_scavenge_draw(card: Card) -> void:
	await _skill_trigger_view.play(card)


func play_card_destroy(card: Card) -> void:
	await _card_destroy_view.play(card)


func play_monster_skill_trigger(monster: Variant) -> void:
	await _monster_skill_trigger_view.play(monster)


func play_monster_attack(monster: Variant, target_positions: Array) -> void:
	await _monster_attack_view.play(monster, target_positions)


func play_target_links(source_position: Vector2, player_target_positions: Array[Vector2], monsters: Array) -> void:
	await _target_link_view.play(source_position, player_target_positions, monsters)


## 横幅属于非阻塞演出，保持 fire-and-forget 语义。
func play_turn_banner(text: String) -> void:
	_turn_banner_view.play(text)
