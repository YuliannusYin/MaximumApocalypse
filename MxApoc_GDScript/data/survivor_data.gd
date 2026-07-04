class_name SurvivorData extends Resource

## 求生者唯一标识（英文 snake_case）。
@export var id: String

## 求生者显示名称（中文）。
@export var display_name: String

## 生命值上限。
@export var hp: int

## 潜行值，用于怪物生成检定。
@export var stealth: int

## 饥饿检定时的潜行值。
@export var hunger_stealth: int

## 技能名称。
@export var skill_name: String

## 技能描述文本。
@export var skill_desc: String

## 是否为特殊角色（如"老兵与狗"二位一体）。
@export var is_special: bool

## 特殊角色的额外规则说明；非特殊角色为空字符串。
@export var special_note: String

## 图标资源路径。
@export var icon_path: String
