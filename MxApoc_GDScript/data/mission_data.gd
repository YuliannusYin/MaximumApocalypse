class_name MissionData extends Resource

## 任务唯一标识，从 0 开始（0 为教程）。
@export var id: int

## 任务名称。
@export var name: String

## 难度名称，取值："特别简单"/"非常简单"/"简单"/"正常"/"困难"/"非常困难"。
@export var difficulty: String

## 难度排序值，由 difficulty 映射而来，用于排序。见 Missions.DIFFICULTY_ORDER。
@export var difficulty_order: int

## 通关所需燃料数。空字符串表示未指定。
@export var fuel: String

## 怪物包标识，取值："zombie"/"mutant"/"alien"/"robot"。
@export var monster_pack: String

## 任务背景介绍文本。
@export var intro: String

## 任务目标文本。
@export var objective: String

## 特殊设置说明文本。
@export var special_setup: String

## 地图块组成。键为地块名，值为该地块数量。
@export var map_blocks: Dictionary

## 图标资源路径。
@export var icon_path: String
