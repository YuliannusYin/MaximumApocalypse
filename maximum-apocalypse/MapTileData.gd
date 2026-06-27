# [新增] 2026-06-24: 地块数据类，用于存储地图地块的基本属性和效果配置
class_name MapBlockData
extends Resource

# [新增] 2026-06-24: 地块唯一标识符
@export var id: String = ""

# [新增] 2026-06-24: 地块名称
@export var tile_name: String = ""

# [新增] 2026-06-24: 怪物出生值列表，匹配骰子值时在该地块放置怪物标记
@export var spawn_values: int # 例如 8

# [新增] 2026-06-24: 拾荒颜色类型（红、绿、蓝、无）
@export var scavenge_type: Enums.ScavengeColor = Enums.ScavengeColor.NONE

# [新增] 2026-06-24: 效果触发时机和效果脚本ID，具体效果通过EffectManager匹配执行
# 简化的效果配置，具体效果可以通过 EffectManager 匹配 id 执行
@export var effect_trigger: Array[Enums.TriggerTime] 

# [新增] 2026-06-24: 效果脚本ID，用于EffectManager匹配执行具体效果
@export var effect_script_id: Array[String]

# [新增] 2026-06-24: 地块描述文本（多行）
@export_multiline var description: String = ""

# 怪物标记，0-3
@export var monster_mark: int
