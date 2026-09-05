# MissionComponent 任务组件

> 以 `src/game/mission/components/` 与 `src/game/mission/scripts/` 为准。
> 三层架构第二层：可复用条件 / 触发器 / 行动组件。第三层为 `MissionScript`（当前无内置脚本）。
> JSON 声明与内置组件 id 目录见 [DataFormat.md §3.4](../../Engineering/DataFormat.md)。
> 运行时挂载与编排见 [MissionConfig.md](./MissionConfig.md)。

---

## 三层架构

| 层 | 位置 | 职责 |
| --- | --- | --- |
| 第一层 声明 | `data/missions/*.json` | `win_conditions` / `lose_conditions` / `triggers` / `actions` / `mission_script` |
| 第二层 组件 | `src/game/mission/components/` | 按 id 实例化，注入 `params`，读写 `mission_state` |
| 第三层 脚本 | `src/game/mission/scripts/` | 组件表达不了的极特殊逻辑；`MissionScriptRegistry` 内置为空 |

组件按**声明位置**区分职责，同一组件类可在多处声明（如 `kill_monsters`、`card_discard_watch` 需 trigger + win/lose 双声明，两个实例共享同一 `mission_state`）。

---

## MissionComponent 基类

`class_name MissionComponent`，继承 `RefCounted`。字段：`params: Dictionary`（JSON 注入）。

| 方法 | 默认 | 由谁实现 |
|------|------|----------|
| `setup(game, mission_config)` | 空 | 需要读写 `mission_state` 或缓存引用的组件 |
| `check_win(game) -> bool` | true（不参与胜利） | 声明于 `win_conditions` |
| `check_lose(game) -> bool` | false（不参与失败） | 声明于 `lose_conditions` |
| `on_event(game, event_name, event)` | 空 | 声明于 `triggers` |
| `get_action_options(game, player) -> Array` | `[]` | 声明于 `actions` |
| `get_action_skill_decl() -> Variant` | null | 行动组件；返回技能栏声明字典 |

`get_action_skill_decl()` 字典键：

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `skill_name` | String | 技能栏按钮名 |
| `block_match` | Callable(block) -> bool | 进入该地块时是否挂载 |
| `filter` | Callable(player) -> bool | 可用性（false 时按钮灰化；不含地块匹配） |
| `execute` | Callable(player) | 执行体（可协程，内部扣行动） |
| `confirm` | Callable(player) -> String | 确认门文案 |

地块匹配：静态组件按 `params.block_name`；动态组件（`destroy_current_mark` / `rescue_judge_win`）按地块是否仍有未移除任务标记。

技能名默认：`spend_action_rescue`→解救科学家（可用 `params.skill_name` 覆盖）、`destroy_current_mark`→摧毁目标、`submit_items`→提交物资、`repair_van`→维修面包车、`defuse_bomb`→解除炸弹、`upload_virus`→上传病毒、`rescue_judge_win`→解救科学家。

---

## 注册表

`MissionComponentRegistry`（`mission_component_registry.gd`）静态映射 `id → 组件类`。`create(id, params)` 实例化并写入 `params`；未知 id `push_error` 并返回 null。内置 22 个 id（判定 / 行动 / 触发三类）见 DataFormat §3.4。`reset()` 仅测试用。

`MissionScriptRegistry` 同模式；当前无内置脚本。`MissionScript` 与组件共用 `setup` / `on_event` / `check_win` / `check_lose` / `get_action_options`。

---

## 胜负与即时结束

- **回合结束判定**：`GameStateMachine.check_win_condition` 先 `check_lose()`，再 `check_win()`，再面包车三项（若 `van_fuel_required >= 0`）。
- **行动直胜/直负**：`rescue_judge_win`、`upload_virus` 在执行体内 `await game.game_over("win"|"lose")`，不依赖回合结束。此类任务须挂 `action_win_only`，避免空真。
- **倒计时**：`turn_countdown` 配置 `expire_kill_outside` 时归零击杀该地块外玩家，`check_lose` 恒 false，由全灭判定接管（任务 5）；未配置时归零置 `countdown_expired`，由 `check_lose` 判负。

各任务实际挂载见 [Resource/MissionPacks/](../../Resource/MissionPacks/)。`mission_state` 键见 [IdentifierMapping.md §八](../../Engineering/IdentifierMapping.md)。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [MissionConfig](./MissionConfig.md) | 持有四类组件数组并编排 |
| [Game](./Game.md) | `initialize_game` 挂载；EventBus → `_forward_mission_event` |
| [Skill](../Common/Skill.md) | 任务行动以 Skill 挂到玩家技能栏 |
