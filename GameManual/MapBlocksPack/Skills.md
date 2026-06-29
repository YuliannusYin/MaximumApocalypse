# MapBlockSkills

## MapBlockSkill Details

=== Format ===

MapBlockSkill: {
    Skill ID:
    Skill Description:
    Trigger:
    Filter:
    Content:
}

===========

MapBlockSkill: {
    Skill ID: general_store_free_scavenge
    Skill Description: Free Scavenge  # 免费拾荒
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: free_scavenge_once  # 执行一次免费的拾荒行动
}

MapBlockSkill: {
    Skill ID: shelter_immune_damage
    Skill Description: Shelter Immune  # 避难免疫
    Trigger: ON_TURN_END_ON_BLOCK
    Filter: None  # 无
    Content: immune_damage_this_turn  # 玩家本回合免疫所有伤害
}

MapBlockSkill: {
    Skill ID: city_street_draw_monster
    Skill Description: Street Spawn  # 街道刷怪
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: draw_monster_1  # 抓一张怪物卡
}

MapBlockSkill: {
    Skill ID: power_plant_contamination
    Skill Description: EM Contamination  # 电磁污染
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: discard_food_add_poison_1  # 弃掉所有食物卡，中毒层数 +1
}

MapBlockSkill: {
    Skill ID: river_stealth_check
    Skill Description: River Crossing Check  # 渡河检定
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: stealth_check_or_return  # 进行一次潜行检定：成功则进入本地块；失败则返回之前的地块
}

MapBlockSkill: {
    Skill ID: airport_teleport
    Skill Description: Airport Teleport  # 空港传送
    Trigger: ON_ACTION
    Filter: No monster on this block  # 此地块上没有怪物
    Content: move_to_revealed_block  # 消耗 1 行动点，移动到另一个已展示的地图块
}

MapBlockSkill: {
    Skill ID: police_station_free_scavenge
    Skill Description: Police Evidence Search  # 警局搜证
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: free_scavenge_once  # 执行一次免费的拾荒行动
}

MapBlockSkill: {
    Skill ID: military_base_airstrike
    Skill Description: Airstrike  # 空袭
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: damage_all_engaged_monsters_2  # 对你面前的所有纠缠怪物各造成 2 点伤害
}

MapBlockSkill: {
    Skill ID: prison_end_turn
    Skill Description: Prison Lockdown  # 监狱闭门
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: end_turn_immediately  # 立即结束你的回合
}

MapBlockSkill: {
    Skill ID: prison_reduce_action
    Skill Description: Prison Reduction  # 监狱减员
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: reduce_action_1  # 本回合行动点 -1
}

MapBlockSkill: {
    Skill ID: wasteland_reveal_spawn
    Skill Description: Wasteland Ambush  # 旷野伏击
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: draw_monster_1  # 抓一张怪物卡
}

MapBlockSkill: {
    Skill ID: wasteland_enter_spawn
    Skill Description: Wasteland Wander  # 旷野游荡
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: draw_monster_1  # 抓一张怪物卡
}

MapBlockSkill: {
    Skill ID: factory_spread_monsters
    Skill Description: Factory Spread  # 工厂扩散
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: add_monster_token_to_adjacent_1  # 向所有相邻地块各增加 1 个怪物标记
}

MapBlockSkill: {
    Skill ID: mall_free_scavenge
    Skill Description: Mall Scavenge  # 商场扫货
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: free_scavenge_once  # 执行一次免费的拾荒行动
}

MapBlockSkill: {
    Skill ID: gas_station_free_scavenge
    Skill Description: Gas Station Scavenge  # 加油站拾荒
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: free_scavenge_once  # 执行一次免费的拾荒行动
}

MapBlockSkill: {
    Skill ID: oasis_reduce_hunger
    Skill Description: Oasis Thirst Relief  # 绿洲止渴
    Trigger: ON_TURN_END_ON_BLOCK
    Filter: None  # 无
    Content: reduce_hunger_1  # 饥饿等级 -1
}

MapBlockSkill: {
    Skill ID: graveyard_reveal_mass_grave
    Skill Description: Graveyard Mass Grave  # 墓地群尸
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: all_players_draw_monster_1  # 每名玩家各抓一张怪物卡
}

MapBlockSkill: {
    Skill ID: graveyard_enter_spawn
    Skill Description: Graveyard Horror  # 墓地惊魂
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: draw_monster_1  # 抓一张怪物卡
}

MapBlockSkill: {
    Skill ID: farm_free_scavenge
    Skill Description: Farm Scavenge  # 农场拾荒
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: free_scavenge_once  # 执行一次免费的拾荒行动
}

MapBlockSkill: {
    Skill ID: raider_camp_robbery
    Skill Description: Raider Robbery  # 强盗劫掠
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: discard_equipment_or_take_5_damage  # 弃掉一张已装备的装备卡 或 受到 5 点伤害（玩家二选一）
}

MapBlockSkill: {
    Skill ID: mountain_draw_card
    Skill Description: Mountain Inspiration  # 山顶灵感
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: draw_card_1  # 从求生者牌库抓一张牌
}

MapBlockSkill: {
    Skill ID: tunnel_warp
    Skill Description: Tunnel Warp  # 隧道穿梭
    Trigger: ON_ACTION
    Filter: None  # 无
    Content: move_to_another_tunnel  # 消耗 1 行动点，移动到另一个已展示的【隧道】地图块
}

MapBlockSkill: {
    Skill ID: forest_pass_through
    Skill Description: Forest Pass-through  # 森林穿越
    Trigger: ON_LEAVE
    Filter: Entered this forest block this turn AND left this forest block this turn  # 本回合进入此森林地块且本回合离开此森林地块
    Content: draw_monster_1  # 抓一张怪物卡
}

MapBlockSkill: {
    Skill ID: desert_dehydration
    Skill Description: Desert Dehydration  # 沙漠脱水
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: add_hunger_1  # 饥饿等级 +1
}

MapBlockSkill: {
    Skill ID: amusement_park_reveal_discard
    Skill Description: Amusement Park Lost  # 游乐园失物
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: discard_card_3  # 弃掉三张牌
}

MapBlockSkill: {
    Skill ID: amusement_park_end_discard
    Skill Description: Amusement Park Aftermath  # 游乐园余兴
    Trigger: ON_TURN_END_ON_BLOCK
    Filter: None  # 无
    Content: discard_card_1  # 弃掉一张牌
}

MapBlockSkill: {
    Skill ID: hospital_enter_heal
    Skill Description: Hospital Emergency  # 医院急救
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: heal_self_1  # 恢复 1 点生命值
}

MapBlockSkill: {
    Skill ID: hospital_end_heal
    Skill Description: Hospital Rest  # 医院休养
    Trigger: ON_TURN_END_ON_BLOCK
    Filter: None  # 无
    Content: heal_self_2  # 恢复 2 点生命值
}

MapBlockSkill: {
    Skill ID: crash_site_reveal_destroy
    Skill Description: Crash Site Relic  # 坠毁点遗物
    Trigger: ON_REVEAL
    Filter: None  # 无
    Content: all_players_remove_equipment_1  # 所有玩家各 remove() 一张装备
}

MapBlockSkill: {
    Skill ID: crash_site_enter_destroy
    Skill Description: Crash Site Debris  # 坠毁点残骸
    Trigger: ON_ENTER
    Filter: None  # 无
    Content: remove_card_1  # remove() 一张牌（手牌/装备由玩家选）
}
