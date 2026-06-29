# MapBlocksPack

## MapBlock Configuration

Format: <MapBlockName>[<ScavengerPileColors>][<MonsterSpawnValue>], e.g., amusement_park[RED, BLUE, GREEN][6], city_street[RED][8],

general_store[GREEN][9]  # 百货商店
shelter[][12]  # 避难所
shelter[][2]  # 避难所
city_street[RED][6]  # 城市街道
city_street[GREEN][8]  # 城市街道
city_street[BLUE][5]  # 城市街道
power_plant[][10]  # 电厂
river[][10]  # 河流
river[][11]  # 河流
airport[RED, GREEN][8]  # 机场
police_station[BLUE][6]  # 警察局
military_base[RED, BLUE][0]  # 军事基地
prison[RED, GREEN, BLUE][9]  # 监狱
wasteland[][6]  # 旷野
wasteland[][8]  # 旷野
factory[BLUE][4]  # 工厂
mall[BLUE][8]  # 购物中心
gas_station[RED][9]  # 加油站
gas_station[RED][5]  # 加油站
gas_station[RED][4]  # 加油站
oasis[][11]  # 绿洲
van[][6]  # 面包车 # 特殊地图块一般是玩家的出生点和结束点
graveyard[][4]  # 墓地
farm[GREEN][3]  # 农场
farm[GREEN][11]  # 农场
raider_camp[][9]  # 强盗营地
raider_camp[][3]  # 强盗营地
mountain[][9]  # 山
mountain[][5]  # 山
tunnel[][10]  # 隧道
tunnel[][4]  # 隧道
forest[][5]  # 森林
forest[][8]  # 森林
desert[][10]  # 沙漠
desert[][4]  # 沙漠
amusement_park[RED, BLUE, GREEN][6]  # 游乐园
hospital[RED][3]  # 医院
crash_site[][10]  # 坠毁点

## MapBlock Details

=== Format ===

MapBlock Class {
    MapBlockID:
    MapBlockName:
    ScavengerPiles:
    MonsterSpawnValue:
    SkillID:
    IsStarting:
    IsSpecial:
    InstancesConfig:
}

===========

MapBlock Class {
    MapBlockID: general_store
    MapBlockName: general_store  # 百货商店
    ScavengerPiles: [GREEN]
    MonsterSpawnValue: 9
    SkillID: [general_store_free_scavenge]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: shelter
    MapBlockName: shelter  # 避难所
    ScavengerPiles: []
    MonsterSpawnValue: 12  # 默认值，实例 2 覆盖为 2
    SkillID: [shelter_immune_damage]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 12}, {"monster_spawn_value": 2}]
}

MapBlock Class {
    MapBlockID: city_street
    MapBlockName: city_street  # 城市街道
    ScavengerPiles: [RED]  # 类型默认；3 个实例分别覆盖为 [RED]/[GREEN]/[BLUE]
    MonsterSpawnValue: 6  # 默认值，实例覆盖为 6/8/5
    SkillID: [city_street_draw_monster]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 6, "scavenger_piles": [RED]}, {"monster_spawn_value": 8, "scavenger_piles": [GREEN]}, {"monster_spawn_value": 5, "scavenger_piles": [BLUE]}]
}

MapBlock Class {
    MapBlockID: power_plant
    MapBlockName: power_plant  # 电厂
    ScavengerPiles: []
    MonsterSpawnValue: 10
    SkillID: [power_plant_contamination]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: river
    MapBlockName: river  # 河流
    ScavengerPiles: []
    MonsterSpawnValue: 10  # 默认值，实例 2 覆盖为 11
    SkillID: [river_stealth_check]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 10}, {"monster_spawn_value": 11}]
}

MapBlock Class {
    MapBlockID: airport
    MapBlockName: airport  # 机场
    ScavengerPiles: [RED, GREEN]
    MonsterSpawnValue: 8
    SkillID: [airport_teleport]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: police_station
    MapBlockName: police_station  # 警察局
    ScavengerPiles: [BLUE]
    MonsterSpawnValue: 6
    SkillID: [police_station_free_scavenge]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: military_base
    MapBlockName: military_base  # 军事基地
    ScavengerPiles: [RED, BLUE]
    MonsterSpawnValue: 0
    SkillID: [military_base_airstrike]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: prison
    MapBlockName: prison  # 监狱
    ScavengerPiles: [RED, GREEN, BLUE]
    MonsterSpawnValue: 9
    SkillID: [prison_end_turn, prison_reduce_action]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: wasteland
    MapBlockName: wasteland  # 旷野
    ScavengerPiles: []
    MonsterSpawnValue: 6  # 默认值，实例 2 覆盖为 8
    SkillID: [wasteland_reveal_spawn, wasteland_enter_spawn]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 6}, {"monster_spawn_value": 8}]
}

MapBlock Class {
    MapBlockID: factory
    MapBlockName: factory  # 工厂
    ScavengerPiles: [BLUE]
    MonsterSpawnValue: 4
    SkillID: [factory_spread_monsters]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: mall
    MapBlockName: mall  # 购物中心
    ScavengerPiles: [BLUE]
    MonsterSpawnValue: 8
    SkillID: [mall_free_scavenge]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: gas_station
    MapBlockName: gas_station  # 加油站
    ScavengerPiles: [RED]
    MonsterSpawnValue: 9  # 默认值，实例覆盖为 9/5/4
    SkillID: [gas_station_free_scavenge]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 9}, {"monster_spawn_value": 5}, {"monster_spawn_value": 4}]
}

MapBlock Class {
    MapBlockID: oasis
    MapBlockName: oasis  # 绿洲
    ScavengerPiles: []
    MonsterSpawnValue: 11
    SkillID: [oasis_reduce_hunger]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: van
    MapBlockName: van  # 面包车
    ScavengerPiles: []
    MonsterSpawnValue: 6
    SkillID: []
    IsStarting: true
    IsSpecial: true  # 特殊地图块一般是玩家的出生点和结束点
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: graveyard
    MapBlockName: graveyard  # 墓地
    ScavengerPiles: []
    MonsterSpawnValue: 4
    SkillID: [graveyard_reveal_mass_grave, graveyard_enter_spawn]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: farm
    MapBlockName: farm  # 农场
    ScavengerPiles: [GREEN]
    MonsterSpawnValue: 3  # 默认值，实例 2 覆盖为 11
    SkillID: [farm_free_scavenge]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 3}, {"monster_spawn_value": 11}]
}

MapBlock Class {
    MapBlockID: raider_camp
    MapBlockName: raider_camp  # 强盗营地
    ScavengerPiles: []
    MonsterSpawnValue: 9  # 默认值，实例 2 覆盖为 3
    SkillID: [raider_camp_robbery]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 9}, {"monster_spawn_value": 3}]
}

MapBlock Class {
    MapBlockID: mountain
    MapBlockName: mountain  # 山
    ScavengerPiles: []
    MonsterSpawnValue: 9  # 默认值，实例 2 覆盖为 5
    SkillID: [mountain_draw_card]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 9}, {"monster_spawn_value": 5}]
}

MapBlock Class {
    MapBlockID: tunnel
    MapBlockName: tunnel  # 隧道
    ScavengerPiles: []
    MonsterSpawnValue: 10  # 默认值，实例 2 覆盖为 4
    SkillID: [tunnel_warp]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 10}, {"monster_spawn_value": 4}]
}

MapBlock Class {
    MapBlockID: forest
    MapBlockName: forest  # 森林
    ScavengerPiles: []
    MonsterSpawnValue: 5  # 默认值，实例 2 覆盖为 8
    SkillID: [forest_pass_through]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 5}, {"monster_spawn_value": 8}]
}

MapBlock Class {
    MapBlockID: desert
    MapBlockName: desert  # 沙漠
    ScavengerPiles: []
    MonsterSpawnValue: 10  # 默认值，实例 2 覆盖为 4
    SkillID: [desert_dehydration]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: [{"monster_spawn_value": 10}, {"monster_spawn_value": 4}]
}

MapBlock Class {
    MapBlockID: amusement_park
    MapBlockName: amusement_park  # 游乐园
    ScavengerPiles: [RED, BLUE, GREEN]
    MonsterSpawnValue: 6
    SkillID: [amusement_park_reveal_discard, amusement_park_end_discard]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: hospital
    MapBlockName: hospital  # 医院
    ScavengerPiles: [RED]
    MonsterSpawnValue: 3
    SkillID: [hospital_enter_heal, hospital_end_heal]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}

MapBlock Class {
    MapBlockID: crash_site
    MapBlockName: crash_site  # 坠毁点
    ScavengerPiles: []
    MonsterSpawnValue: 10
    SkillID: [crash_site_reveal_destroy, crash_site_enter_destroy]
    IsStarting: false
    IsSpecial: false
    InstancesConfig: []
}
