# 场景文件与测试文件索引

---

## 场景文件 (scenes/)

项目自有场景（不含 addons/gut）：

| 场景文件 | 绑定脚本 | 说明 |
|---------|---------|------|
| `scenes/MainMenu.tscn` | `scripts/ui/main_menu.gd` | 主菜单 |
| `scenes/GameRoom.tscn` | `scripts/ui/game_room.gd` | 房间配置 |
| `scenes/GameScene.tscn` | `scripts/ui/game_scene.gd` | 游戏场景（占位） |
| `scenes/SeatItem.tscn` | `scripts/ui/seat_item.gd` | 座位条目 |
| `scenes/SettingsDialog.tscn` | `scripts/ui/settings_dialog.gd` | 设置对话框 |

---

## 测试文件 (tests/unit/)

基于 GUT (Godot Unit Test) 框架的单元测试。

| 测试文件 | 被测对象 | 覆盖范围 |
|---------|---------|---------|
| `tests/unit/test_event_trigger.gd` | `Entity.trigger`、`Skill`、`Event` | 触发链顺序、filter 过滤、复合 trigger、cancel 中断、event 字段读写、source=null 容忍 |
| `test_player.gd` | `Player`、`RoleCard` | 状态查询、add_hp、add_hunger、reduce_hunger、潜行值、角色卡翻面、标记系统、Entity 集成 |
| `test_damage_flow.gd` | `Entity.damage` | 前置检查(num<=0/已死亡)、8 节点顺序、source=null、event.num 修改、cancel 取消、死亡判定、event 字段可读 |
| `test_player_state.gd` | `Player.recover/increaseHunger/decreaseHunger/poison` | recover 上下限/钩子/cancel、increaseHunger 逐点结算/翻面/饥饿伤害等级、decreaseHunger 清标记翻回、poison 无来源伤害 |
| `test_judge.gd` | `Dice`、`MapBlock`、`Player.judge/sneakJudge/monsterSpawnJudge` | judge 范围/注入、sneakJudge 成功失败/怪物减成/null block/负值、monsterSpawnJudge 标记/抓怪物/跳过不匹配、MapBlock stub |
