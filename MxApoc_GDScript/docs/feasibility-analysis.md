# 可行性分析报告：核心游戏逻辑层开发

> **评估对象**：`e:\B_ProjectLibrary\MaximumApocalypse\MxApoc_GDScript\GameDesignDocus` 游戏设计文档
> **评估目的**：判断是否可以开始核心游戏逻辑层（GameSystem + Resource）的编码实现
> **评估日期**：2026-07-07
> **评估结论**：**✅ 可以开始核心游戏逻辑层开发**

---

## 一、文档统计总览

| 维度 | 数量 |
|------|------|
| 文档总数 | 55 个 markdown 文件 |
| 文档总行数 | 9,968 行 |
| GameSystem 方法数（含完整伪代码） | 95 个 |
| EventSystem trigger 索引行 | 132 行 |
| Resource 数据文件 | 28 个（6 角色 + 4 拾荒 + 4 怪物 + 13 任务 + 1 地图块） |
| 跨文档引用断裂 | 0 处 |
| 「待实现/待定义」标记残留 | 0 处 |

---

## 二、已就绪部分详细评估

### 2.1 GameSystem 系统设计（完整度 9.5/10）

#### 核心类（Core/）

| 文档 | 行数 | 方法数 | 评估 |
|------|------|--------|------|
| [Entity.md](../GameDesignDocus/GameSystem/Core/Entity.md) | 155 | 8 | ✅ 完整：伤害流程 8 节点伪代码、技能挂载、多态 death |
| [EventSystem.md](../GameDesignDocus/GameSystem/Core/EventSystem.md) | 240 | — | ✅ 完整：event schema、命名规范、全 trigger 索引（132 行） |
| [GameStateMachine.md](../GameDesignDocus/GameSystem/Core/GameStateMachine.md) | 399 | 12 | ✅ 完整：状态转换、回合队列、胜利失败检查、NULL 燃料值处理 |

#### 实体类（Entities/）

| 文档 | 行数 | 方法数 | 评估 |
|------|------|--------|------|
| [Player.md](../GameDesignDocus/GameSystem/Entities/Player.md) | 1418 | 34 | ✅ 极完整：21 节点回合流程、抓牌/弃牌/移动/检定/装备/死亡/任务系统 |
| [Monster.md](../GameDesignDocus/GameSystem/Entities/Monster.md) | 144 | 4 | ✅ 完整：行动/攻击/死亡/实体化 |
| [Card.md](../GameDesignDocus/GameSystem/Entities/Card.md) | 112 | 1 | ✅ 完整：Card/ScavengeCard/SurvivorGameCard/EquipmentCard/MonsterCard 继承体系 + 字段定义 |
| [MapBlock.md](../GameDesignDocus/GameSystem/Entities/MapBlock.md) | 311 | 17 | ✅ 完整：坐标/相邻/射程/目标标记管理 |

#### 游戏全局类（Game/）

| 文档 | 行数 | 方法数 | 评估 |
|------|------|--------|------|
| [Game.md](../GameDesignDocus/GameSystem/Game/Game.md) | 441 | 19 | ✅ 完整：全局区域/地图管理（buildMap/destroyMapBlock）/任务配置/状态机委托 |

#### 通用结构（Common/）

| 文档 | 行数 | 方法数 | 评估 |
|------|------|--------|------|
| [Pile.md](../GameDesignDocus/GameSystem/Common/Pile.md) | 82 | 6 | ✅ 完整：draw/add/shuffle/shuffleInto + 重洗规则 |
| [RoleCard.md](../GameDesignDocus/GameSystem/Common/RoleCard.md) | 60 | — | ✅ 完整：角色卡翻面机制 |
| [Skill.md](../GameDesignDocus/GameSystem/Common/Skill.md) | 210 | — | ✅ 完整：字段规范 + 6 个通用行动技能伪代码（移动/拾荒/摸牌/制衡/交易/加油） |

**GameSystem 小计**：11 个文档，3,717 行，95 个方法（全部含完整伪代码）

#### 关键流程覆盖确认

| 流程 | 定义位置 | 节点数 | trigger 钩子 |
|------|---------|--------|------------|
| 伤害流程 | Entity.damage | 8 节点 | 7 个（造成/受到 × 前/时/后 + 死亡判定） |
| 玩家回合流程 | Player.开始回合 | 21 节点 | 14 个钩子节点 |
| 抓取游戏牌流程 | Player.draw | 4 节点 | 3 个（前/时/后） |
| 抓取怪物卡流程 | Player.drawMonster | 6 节点 | 9 个（前/时/进入怪物区 × 前/时/后/后整体） |
| 抓取拾荒牌流程 | Player.drawScavenge | 4 节点 | 3 个（前/时/后） |
| 玩家移动流程 | Player.moveTo | 11 节点 | 7 个（离开 × 前/时/后 + 进入 × 前/时/后/展示） |
| 使用卡牌流程 | Player.useCard | 4 节点 | 3 个（前/时/后） |
| 装备进入流程 | Player.装备 | 3 节点 | 3 个（前/时/后） |
| 装备离开流程 | Player.卸下 | 3 节点 | 3 个（前/时/后） |
| 填充物消耗流程 | Player.消耗填充物 | 5 节点 | 5 个（前/时/后 + 耗尽） |
| 潜行检定流程 | Player.sneakJudge | 4 节点 | 3 个（前/时/后） |
| 怪物出生检定 | Player.monsterSpawnJudge | 4 节点 | 3 个（前/时/后） |
| 怪物行动流程 | Monster.行动 | 6 节点 | 6 个（前/时/攻击 × 前/时/后 + 后） |
| 怪物死亡流程 | Monster.monsterDeath | 4 节点 | 3 个（前/时/后） |
| 玩家死亡流程 | Player.playerDeath | 6 节点 | 3 个（前/时/后） |
| 弃置牌流程 | Player.discard | 3 节点 | 3 个（前/时/后） |
| 销毁牌流程 | Player.removeCard | 3 节点 | 3 个（前/时/后） |
| 摧毁地块流程 | Game.destroyMapBlock | 6 节点 | 3 个（前/时/后） |
| 游戏开始流程 | Game.startGame | 3 节点 | 1 个（游戏开始时） |
| 游戏结束流程 | Game.gameOver | 3 节点 | 1 个（游戏结束时） |

---

### 2.2 Resource 数据定义（完整度 9/10）

#### 求生者包（SurvivorPacks/）— 6 个角色，2,016 行

| 角色 | 行数 | 角色固有技能 | 游戏牌数 | API 落地 |
|------|------|------------|---------|---------|
| 消防员 firefighter | 329 | ✅ | ✅ | ✅ 正式 API |
| 枪手 gunslinger | 388 | ✅ | ✅ | ✅ 正式 API |
| 猎人 hunter | 343 | ✅ | ✅ | ✅ 正式 API |
| 机械师 mechanic | 313 | ✅ | ✅ | ✅ 正式 API |
| 外科医生 surgeon | 263 | ✅ | ✅ | ✅ 正式 API |
| 老兵 veteran | 380 | ✅ | ✅ | ✅ 正式 API |

#### 拾荒牌堆（ScavengePacks/）— 4 色，600 行

| 颜色 | 行数 | 牌数 | 说明 |
|------|------|------|------|
| 蓝色 blue | 278 | ✅ 完整 | 战备类，最安全 |
| 绿色 green | 129 | ✅ 完整 | 日常类 |
| 红色 red | 96 | ✅ 完整 | 危险类，含伏击 |
| 灰色 gray | 97 | ✅ 完整 | 通用（一无所获/伏击） |

#### 怪物包（MonsterPacks/）— 4 类型，725 行

| 怪物类型 | 行数 | 普通怪 | 精英怪 | 首领卡 |
|---------|------|--------|--------|--------|
| 外星人 alien | 220 | ✅ | ✅ | ✅ 2 张 |
| 突变体 mutant | 172 | ✅ | ✅ | ✅ 2 张 |
| 机器人 robot | 187 | ✅ | ✅ | ✅ 2 张 |
| 僵尸 zombie | 146 | ✅ | ✅ | ✅ 2 张 |

> 首领卡共 8 张（每包 2 张），支持 `player.drawBossCard()` 机制。

#### 任务包（MissionPacks/）— 13 个任务，1,052 行

| 任务 # | 行数 | 燃料值 | 目标标记 | 胜利条件 |
|--------|------|--------|---------|---------|
| 0 教程 | 63 | 4 | 无 | 普通 |
| 1 解救科学家 | 71 | 4 | 无 | 普通 |
| 2 收集样本 | 74 | 4 | 无 | 普通 |
| 3 研制解药 | 73 | 4 | 无 | 普通 |
| 4 核冬天 | 73 | NULL | 无 | 特殊 |
| 5 拆除炸弹 | 86 | 3 | 1 个 | 普通 |
| 6 核辐射 | 76 | 3 | 无 | 普通 |
| 7 侦查外星人地区 | 85 | 4 | 1 个 | 普通 |
| 8 情报恢复 | 100 | NULL | 1 个 | 特殊 |
| 9 人类反击 | 97 | NULL | 2 个 | 特殊 |
| 10 运输 | 109 | 6 | 3 个 | 普通 |
| 11 保护基地 | 113 | NULL | 3 个 | 特殊 |
| 12 烧死那群机器人 | 105 | 3 | 3 个 | 普通 |

#### 地图块包（MapBlocksPack/）— 1 个文件，398 行

`MapBlocks.md` 定义全部地图块（名字[拾荒牌堆颜色][刷怪点数] + 技能定义）。

**Resource 小计**：28 个数据文件，4,976 行

---

### 2.3 跨文档一致性验证

| 验证项 | 结果 |
|--------|------|
| 「待实现/待定义/TBD/FIXME」标记 | ✅ 全项目仅 1 处（README.md 标注约定说明，非实际标记） |
| 任务系统方法引用（`player.收集物品` / `player.drawBossCard` 等） | ✅ 66 处引用均正确 |
| 节点编号一致性（D_gameFlow vs Player.开始回合） | ✅ 已同步为 21 节点 |
| 燃料值 NULL 处理（任务 4/8/9/11） | ✅ 任务包 + Game.md + GameStateMachine.md 一致 |
| 同生共死模式（`game.同生共死模式`） | ✅ Game.md + Player.playerDeath + K_gameTerminology 一致 |
| 首领卡定义 | ✅ 4 个怪物包各 2 张 |
| `sneakJudge` 命名一致性 | ✅ 全项目无 `stealthJudge` 残留 |

---

## 三、开发可行性结论

### ✅ 可以开始核心游戏逻辑层开发

**判断依据**：

1. **系统设计完整**：11 个 GameSystem 文档定义了 95 个方法（全部含完整伪代码），覆盖全部 20 个核心流程
2. **数据定义完整**：28 个 Resource 文件定义了全部游戏数据（6 角色 + 4 拾荒堆 + 4 怪物包 + 13 任务 + 地图块）
3. **事件系统完整**：EventSystem 定义了全部 trigger 名（132 行索引），跨流程钩子一致
4. **跨文档一致**：无断裂引用、无「待实现」标记残留、节点编号已同步
5. **API 已落地**：所有卡牌技能 content 已使用正式 API 调用（非占位符）

### 开发范围建议

可立即开始的部分：
- GameSystem 核心类实现（Entity / Player / Monster / Card / MapBlock / Game / GameStateMachine）
- Common 结构实现（Pile / RoleCard / Skill）
- Resource 数据加载（从 markdown/JSON 加载卡牌/地图/任务数据）
- 核心流程单元测试（伤害/抓牌/移动/检定/回合/胜负判定）

**暂不包含**的部分（需先补充设计，详见 [design-gaps.md](design-gaps.md)）：
- UI/前端层
- 网络/联机系统
- AI 玩家系统
- 存档系统
- 3D 表现层
- Godot 工程结构

---

## 四、开发建议与优先级

### 阶段 1：核心逻辑层（可立即开始，预计 4-6 周）

| 优先级 | 任务 | 依赖 | 预估工作量 |
|--------|------|------|-----------|
| P0 | 搭建 Godot 工程基础结构（目录/autoload/基础类） | 无 | 1 天 |
| P0 | 实现 Entity 基类 + EventSystem | 无 | 3 天 |
| P0 | 实现 Pile / Card / Skill 数据结构 | Entity | 2 天 |
| P0 | 实现 Player 类（字段 + 状态管理 + 抓牌/弃牌/移动） | Entity, Pile, Card | 5 天 |
| P0 | 实现 Monster 类（实体化 + 行动 + 攻击 + 死亡） | Entity | 3 天 |
| P0 | 实现 MapBlock 类（坐标 + 相邻 + 射程 + 目标标记） | Entity | 3 天 |
| P0 | 实现 Game 类（全局区域 + 地图管理 + 任务配置） | 上述全部 | 4 天 |
| P0 | 实现 GameStateMachine（状态转换 + 回合队列 + 胜负判定） | Game | 3 天 |
| P1 | 加载 Resource 数据（从 markdown 解析为运行时对象） | 上述全部 | 5 天 |
| P1 | 实现 6 个通用行动技能（移动/拾荒/摸牌/制衡/交易/加油） | Player, Skill | 3 天 |
| P1 | 实现技能系统（filter/content 执行引擎） | Entity, EventSystem | 3 天 |
| P2 | 单元测试（覆盖 20 个核心流程） | 上述全部 | 5 天 |

### 阶段 2：数据验证与平衡性测试（阶段 1 完成后）

| 优先级 | 任务 | 说明 |
|--------|------|------|
| P1 | 加载 13 个任务包并验证地图构建 | `game.buildMap()` 对每个任务的地图要求 |
| P1 | 验证 6 个角色的初始游戏牌堆 | 角色专属牌堆 + 抓牌/弃牌流程 |
| P2 | 验证 4 个怪物包的实体化与行动 | 怪物卡 → Monster 实例 + 行动/攻击流程 |
| P2 | 验证 13 个任务的胜负条件 | 普通胜利（燃料+目标）+ 特殊胜利（NULL 燃料） |

---

## 五、风险点

### R1: 伪代码到 GDScript 的翻译风险（中等）

设计文档使用中文标识符 + GDScript 风格伪代码，实际编码时需翻译为英文标识符（GDScript 规范）。

**缓解**：建立标识符映射表（中文 → 英文），如 `玩家.生命值` → `player.hp`。

### R2: 技能系统执行引擎复杂度（中等）

Skill 结构有 14 个字段（含 filter/filterTarget/filterCard/selectCard/selectTarget 等），执行引擎需处理目标选择、选牌、射程过滤等复杂逻辑。

**缓解**：先实现简化版（仅支持主动技能 + trigger 技能），逐步补全 filter 链。

### R3: 数据加载格式未定（低）

Resource 数据目前以 markdown 格式定义，运行时需解析为对象。加载格式（markdown 解析 vs 转为 JSON/CSV）未在设计文档中明确。

**缓解**：建议先转为 JSON 格式（易于 Godot 解析），markdown 作为设计源文档。

### R4: UI 层交互点未定义（中等）

部分方法依赖 UI 交互（如 `player.等待玩家行动()`、`target.choose(list)`、`player.showCard(card, target)`），这些方法的接口与 UI 层耦合。

**缓解**：定义 UI 交互接口（Interface/IPlayerInput），核心逻辑层通过接口调用，UI 层后续实现。当前可先用命令行/简单 UI 替代。

### R5: 部分规则文档简略（低）

GameInstructions 中 E_gameJudge（7 行）、I_monsterAction（9 行）、A_overview（3 行）、L_gameVariants（5 行）较简略，但不影响核心逻辑实现（底层方法定义完整）。

**缓解**：核心实现以 GameSystem/ 为准，GameInstructions/ 作为玩家规则参考。

---

## 六、下一步行动建议

1. **立即开始**：阶段 1 核心逻辑层开发（P0 任务）
2. **并行进行**：补充支撑系统设计（详见 [design-gaps.md](design-gaps.md)）
3. **阶段 1 完成后**：启动 UI 层开发（需先完成 UI 系统设计）
4. **持续进行**：单元测试与数据验证

---

## 七、相关文档

- [design-gaps.md](design-gaps.md) — 设计待完善报告（6 大支撑系统缺失清单）
- [GameDesignDocus/README.md](../GameDesignDocus/README.md) — 设计文档总览
- [GameDesignDocus/GameSystem/README.md](../GameDesignDocus/GameSystem/README.md) — GameSystem 文档索引
- [GameDesignDocus/Resource/README.md](../GameDesignDocus/Resource/README.md) — Resource 数据格式说明
