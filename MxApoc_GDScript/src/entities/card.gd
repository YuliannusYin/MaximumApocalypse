class_name Card
extends Entity

## 卡牌基类。
## 继承 Entity，卡牌自带技能（装备技能、行动牌效果、怪物卡技能）。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md

## 卡牌名称（中文）
var card_name: String = ""

## 网络实例 id（主机分配，供快照与输入 RPC 跨端引用）
var net_id: int = 0

## 卡牌英文名（用于 content 代码字符串中按名查找装备/卡牌）
var english_name: String = ""

## 卡牌类型（如"行动"、"装备"、"食物"等）
var card_type: String = ""

## 卡牌来源："scavenge"（拾荒牌堆）/ "game"（游戏牌堆）/ "monster"（怪物牌堆）
var source: String = ""
