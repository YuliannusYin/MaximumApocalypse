# ArchiveManager 档案与成就

> 以 `src/core/archive_manager.gd` 为准。
> 职责：跨对局档案（`user://archive.json`）的加载、内存持有、结算更新与落盘；成就定义（`data/achievements.json`）的加载与声明式求值；任务解锁查询。
> 注册为 autoload，全局名 `ArchiveManager`，无 `class_name`，继承 `Node`。
> 本局统计由 [StatsTracker](./StatsTracker.md) 聚合，结算页 `GameResult` 调用 `record_game_result`。

---

## 设计意图

档案与对局内存状态分离。仅**玩家模式**（`Settings.dev_mode == false`）且结算结果为胜或负时归档；开发者模式不写档案、不推进解锁。

解锁状态不单独存盘：由档案 `missions` 块推导。任务 0 恒解锁；任务 N 需任务 N-1 在任意人数档 `win_count > 0`。13 个任务均通关后解锁「随机任务」与游戏变体。

成就条件为声明式对象，不走 CodeExecutor。

---

## 档案结构

顶层键：`achievements` / `survivors` / `missions` / `monsters` / `win_total`。

| 块 | 结构 | 更新时机 |
| --- | --- | --- |
| `win_total` | int | 仅胜利 +1 |
| `survivors` | `{survivor_id: {total_damage, best_damage, total_kills, best_kills, boss_kills, total_healing, best_healing, total_turns, best_turns, wins}}` | 胜负都累加统计；`wins` 仅胜利 |
| `missions` | `{mission_id: {player_count: {win_count, best_time_msec}}}` | 仅胜利 |
| `monsters` | `{怪物卡 english_name: 击杀数}` | 胜负都累加。旧档案的类型级键（zombie/alien/mutant/robot）加载时丢弃，不迁移 |
| `achievements` | `{id: {first_at, count}}` | 每次结算重新评估全部定义 |

损坏文件：解析失败时重命名为 `<文件名>.bak.<时间戳>` 后使用空档案。缺失字段给防御性默认值；未知字段与未知成就 id 原样保留。

---

## 结算入口

`record_game_result(summary) -> Array`：按 [StatsTracker.get_archive_summary](./StatsTracker.md) 更新内存档案、立即 `save()`，返回本局**新达成**的成就定义列表（供结算页展示）。`summary` 含 `result` / `duration_msec` / `player_count` / `mission_id` / `survivors` / `monsters`。

---

## 任务解锁

| 方法 | 说明 |
|------|------|
| `is_mission_unlocked(mission_id)` | `id <= 0` 恒 true；否则前一任务任意人数 `win_count > 0` |
| `are_all_missions_completed()` | DataManager 全集每个任务至少通关一次 |
| `is_random_and_variants_unlocked()` | 等同全任务通关 |

开发者模式全解锁由 **调用方** 负责（`GameRoom` 不置灰、`DataManager.get_available_missions()` 返回全部）。`DataManager` 注册早于本单例，查询仅在运行期调用。

---

## 成就

定义文件 `data/achievements.json`：数组，每项 `{id, name, description, condition}`。当前 11 条。

条件类型：

| type | 字段 | 含义 |
|------|------|------|
| `win_total` | `value` | 累计胜利局数 ≥ N |
| `stat_total` | `stat`, `value` | 全部求生者累计字段之和 ≥ N |
| `stat_best` | `stat`, `value` | 任一求生者单局最佳 ≥ N |
| `survivor_wins_all` | — | DataManager 加载的全部求生者均至少胜利一局 |
| `missions_complete_all` | — | 全部任务均至少胜利一次（任意人数） |

未知条件类型 / 未知统计字段 → false。条件首次成立时记录 `first_at`（ISO8601 本地时间）并计入返回列表；之后每次结算只要条件仍成立则 `count +1`。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| `GameResult` | 玩家模式结算时调用 `record_game_result` |
| [StatsTracker](./StatsTracker.md) | 提供 summary |
| [DataManager](../../Engineering/DataFormat.md) | `get_available_missions` 委托 `is_mission_unlocked`；成就求值读求生者/任务全集 |
| `GameRoom` | 锁定任务置灰；随机任务与变体未解锁时禁用 |
| [EventBus](./EventBus.md) | 不经 EventBus；归档发生在结算场景 |
