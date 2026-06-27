# [新增] 2026-06-24: UI管理类，负责游戏界面的显示和交互（待实现）
class_name UIManager
extends CanvasLayer

# [新增] 2026-06-24: 初始化UI管理器
func _ready() -> void:
	pass

# [新增] 2026-06-24: 播放骰子动画
func play_dice_animation(d1: int, d2: int) -> void:
	pass

# [新增] 2026-06-24: 骰子动画结束信号
signal dice_animation_finished

# [新增] 2026-06-24: 播放抽牌动画
func play_draw_card_anim(player_id: String, card: CardRuntime) -> void:
	pass

# [新增] 2026-06-24: 抽牌动画结束信号
signal draw_card_anim_finished

# [新增] 2026-06-24: 启用玩家控制
func enable_player_controls(player_id: String) -> void:
	pass

# [新增] 2026-06-24: 禁用玩家控制
func disable_player_controls() -> void:
	pass

# [新增] 2026-06-24: 显示角色翻面动画
func show_character_flip_anim(player_id: String) -> void:
	pass

# [新增] 2026-06-24: 翻面动画结束信号
signal flip_anim_finished

# [新增] 2026-06-24: 显示伤害飘字
func show_damage_floating_text(player_id: String, damage: int, reason: String) -> void:
	pass

# [新增] 2026-06-24: 播放怪物攻击动画
func play_monster_attack_anim(monster_id: String, player_id: String) -> void:
	pass

# [新增] 2026-06-24: 怪物攻击动画结束信号
signal monster_attack_anim_finished

# [新增] 2026-06-24: 显示胜利界面
func show_victory_screen() -> void:
	pass

# [新增] 2026-06-24: 显示失败界面
func show_defeat_screen() -> void:
	pass