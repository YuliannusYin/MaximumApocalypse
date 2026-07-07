# 设计待完善报告：支撑系统缺失清单

> **评估对象**：`e:\B_ProjectLibrary\MaximumApocalypse\MxApoc_GDScript\GameDesignDocus` 游戏设计文档
> **评估目的**：识别完整游戏开发所需但当前缺失的支撑系统设计
> **评估日期**：2026-07-07
> **评估结论**：**6 大支撑系统设计缺失，需在对应开发阶段前补充**
> **配套文档**：[feasibility-analysis.md](feasibility-analysis.md) — 核心逻辑层开发可行性分析

---

## 一、缺失系统总览

| # | 系统 | 当前状态 | 优先级 | 阻塞的开发阶段 |
|---|------|---------|--------|--------------|
| 1 | Godot 工程结构设计 | ❌ 完全缺失 | P0 | 阶段 1 开始前 |
| 2 | UI 交互接口设计 | ❌ 完全缺失 | P1 | 阶段 1 中期（玩家交互方法实现时） |
| 3 | 3D 表现层设计 | ❌ 完全缺失 | P2 | 阶段 2（核心逻辑验证后） |
| 4 | AI 玩家系统设计 | ❌ 完全缺失 | P2 | 阶段 3（人机合作模式） |
| 5 | 网络/联机系统设计 | ❌ 完全缺失 | P3 | 阶段 4（多人联机模式） |
| 6 | 存档系统设计 | ❌ 完全缺失 | P3 | 阶段 3+（任意需要持久化的点） |

> **说明**：核心游戏逻辑层（GameSystem + Resource）设计已完整，可立即开始编码（详见可行性分析报告）。本报告列出的缺失系统不阻塞核心逻辑开发，但需在对应功能开发前补充设计。

---

## 二、各系统详细补充清单

### 2.1 Godot 工程结构设计（P0）

**当前状态**：完全缺失。AGENTS.md 仅说明使用 Godot 4.7 + GDScript，未定义工程结构。

**需补充的设计内容**：

#### 2.1.1 项目目录结构

```
MxApoc_GDScript/
├── project.godot              # Godot 项目配置
├── src/                       # 源代码
│   ├── core/                  # GameSystem 核心类
│   │   ├── entity.gd          # Entity 基类
│   │   ├── event_system.gd    # EventSystem
│   │   ├── game_state_machine.gd
│   │   └── ...
│   ├── entities/              # 实体类
│   │   ├── player.gd
│   │   ├── monster.gd
│   │   ├── card.gd
│   │   └── map_block.gd
│   ├── game/                  # 游戏全局类
│   │   └── game.gd
│   ├── common/                # 通用结构
│   │   ├── pile.gd
│   │   ├── role_card.gd
│   │   └── skill.gd
│   ├── data/                  # 数据加载层
│   │   ├── data_loader.gd     # 从 JSON 加载数据
│   │   └── ...
│   ├── ui/                    # UI 层（待设计）
│   ├── network/               # 网络层（待设计）
│   ├── ai/                    # AI 层（待设计）
│   └── save/                  # 存档层（待设计）
├── data/                      # 数据文件（JSON 格式）
│   ├── survivors/
│   ├── scavenge/
│   ├── monsters/
│   ├── missions/
│   └── map_blocks/
├── scenes/                    # Godot 场景文件
├── assets/                    # 美术/音效资源
└── tests/                     # 单元测试
```

#### 2.1.2 Autoload（自动加载）设计

| Autoload 名 | 类 | 说明 |
|-------------|---|------|
| Game | Game | 游戏全局实例 |
| EventBus | EventBus | 全局事件总线（可选） |
| DataManager | DataManager | 数据加载与管理 |

#### 2.1.3 标识符映射规范

设计文档使用中文标识符，GDScript 代码需用英文。需建立映射表：

| 中文 | 英文 | 说明 |
|------|------|------|
| 玩家.生命值 | player.hp | 生命值 |
| 玩家.饥饿值 | player.hunger | 饥饿值 |
| 玩家.潜行值 | player.stealth | 潜行值 |
| 玩家.行动次数 | player.actionCount | 行动次数 |
| 玩家.手牌区 | player.hand | 手牌区 |
| 玩家.装备区 | player.equipmentZone | 装备区 |
| 玩家.怪物区 | player.monsterZone | 怪物区 |
| 游戏.任务配置 | game.missionConfig | 任务配置 |
| ... | ... | 需完整映射 |

**预估工作量**：1-2 天

---

### 2.2 UI 交互接口设计（P1）

**当前状态**：完全缺失。设计文档中有多处依赖 UI 交互的方法，但未定义接口。

**已识别的 UI 交互点**（从 GameSystem 文档中提取）：

| 方法 | 来源 | 交互类型 | 说明 |
|------|------|---------|------|
| `player.等待玩家行动()` | D_gameFlow.md 节点 9 | 行动选择 | 玩家在行动阶段选择执行哪个行动 |
| `target.choose(list)` | Skill.md 交易技能 | 列表选择 | 目标玩家从列表中选择一项 |
| `target.chooseCard(n, position, source)` | Skill.md 交易技能 | 选牌 | 目标玩家从指定区域选 n 张牌 |
| `player.showCard(card, target)` | Skill.md 交易技能 | 卡牌展示 | 向目标展示一张牌 |
| `player.getNumber("xxx")` | Skill.md 多处 | 数值查询 | 查询玩家状态数值 |
| `player.getEquipment("xxx")` | SurvivorPacks 多处 | 装备查询 | 按名获取装备区装备 |
| `player.hasEquipment("xxx")` | SurvivorPacks 多处 | 装备判断 | 判断是否持有装备 |
| `player.get填充物数量("xxx")` | hunter.md | 填充物查询 | 查询装备填充物数量 |
| `player.get_current_block()` | Skill.md 移动/拾荒 | 地块查询 | 获取玩家当前地块 |

**需补充的设计内容**：

#### 2.2.1 UI 交互接口定义

```gdscript
# IPlayerInput.gd - 玩家输入接口
interface IPlayerInput:
    # 行动选择
    func waitAction(player: Player) -> Action
    # 列表选择
    func choose(options: List) -> int
    # 选牌
    func chooseCard(n: int, position: String, filter: Callable) -> List[Card]
    # 选目标
    func chooseTarget(n: int, range: String, filter: Callable) -> List[Player]
    # 确认对话框
    func confirm(message: String) -> bool
    # 展示卡牌
    func showCard(card: Card, target: Player) -> void
```

#### 2.2.2 UI 层架构

- **命令行 UI**（开发初期）：终端文本交互，用于核心逻辑测试
- **图形 UI**（阶段 2+）：Godot Control 节点实现

#### 2.2.3 玩家输入模式

| 模式 | 实现时机 | 说明 |
|------|---------|------|
| 命令行模式 | 阶段 1 | 用于核心逻辑测试 |
| 热座模式 | 阶段 2 | 单机多人轮流操作 |
| AI 模式 | 阶段 3 | AI 玩家替代人类输入 |
| 联机模式 | 阶段 4 | 远程玩家输入同步 |

**预估工作量**：3-5 天

---

### 2.3 3D 表现层设计（P2）

**当前状态**：完全缺失。AGENTS.md 说明项目目标为"3D 游戏"，但无任何 3D 相关设计。

**需补充的设计内容**：

#### 2.3.1 3D 场景结构

- 摄像机系统（俯视角/跟随视角/自由视角）
- 灯光系统（环境光/方向光/点光源）
- 地图块 3D 表示（网格地块 + 高度差 + 地标模型）
- 玩家角色 3D 模型（6 个角色的 3D 模型 + 动画）
- 怪物 3D 模型（4 类怪物的 3D 模型 + 动画）
- 卡牌 3D 表示（手牌区/装备区/怪物区的 3D 卡牌渲染）

#### 2.3.2 动画系统

| 动画类型 | 触发时机 | 说明 |
|---------|---------|------|
| 移动动画 | player.moveTo | 玩家/怪物在地块间移动 |
| 攻击动画 | entity.damage | 攻击者挥击 + 受击者反应 |
| 死亡动画 | entity.death | 角色/怪物倒地 |
| 抓牌动画 | player.draw/drawScavenge/drawMonster | 从牌堆抓牌到手牌 |
| 弃牌动画 | player.discard | 从手牌到弃牌堆 |
| 翻面动画 | RoleCard.翻面 | 角色卡翻面（饥饿状态） |
| 地块展示动画 | block.展示 | 地块从未展示到展示的翻转 |

#### 2.3.3 特效系统

- 伤害数字浮动
- 攻击轨迹/弹道
- 技能释放特效
- 状态标记图标（中毒/饥饿/击晕等）

#### 2.3.4 资源清单

需制作/获取的资源：
- 6 个角色 3D 模型 + 动画
- 4 类怪物 3D 模型 + 动画（每类含普通/精英/首领 3 种）
- 地图块 3D 资源（约 20+ 种地块类型）
- 卡牌美术（约 200+ 张卡牌的卡面）
- UI 图标与界面元素
- 音效与背景音乐

**预估工作量**：设计 1-2 周，资源制作 4-8 周（可外包/使用现有资源库）

---

### 2.4 AI 玩家系统设计（P2）

**当前状态**：完全缺失。AGENTS.md 说明项目要支持"人机合作"，但无 AI 设计。

**需补充的设计内容**：

#### 2.4.1 AI 决策架构

| 层级 | 说明 | 示例 |
|------|------|------|
| 战术层 | 当前回合的最优行动选择 | "面前有怪物 → 攻击 vs 拾荒" |
| 战略层 | 多回合目标规划 | "任务需要燃料 → 优先拾荒红色牌堆" |
| 合作层 | 与人类玩家的协作 | "队友濒死 → 优先治疗/掩护" |

#### 2.4.2 AI 难度等级

| 难度 | 决策能力 | 说明 |
|------|---------|------|
| 简单 | 随机 + 基本规则 | 随机选择合法行动，避免明显错误 |
| 普通 | 启发式评估 | 基于权重评估各行动价值 |
| 困难 | 前瞻搜索 | 简单的 minimax / 蒙特卡洛搜索 |
| 专家 | 任务感知 | 结合任务目标的深度策略 |

#### 2.4.3 AI 行为模块

- 行动评估器（评估每个可用行动的价值）
- 目标选择器（选择攻击/治疗/交易的目标）
- 路径规划器（地图移动路径选择）
- 牌使用决策器（何时使用手牌、装备牌）
- 任务进度跟踪器（跟踪任务目标完成度）

#### 2.4.4 AI 接口

```gdscript
# AIPlayer.gd - AI 玩家实现 IPlayerInput 接口
class AIPlayer(IPlayerInput):
    var difficulty: String  # simple/normal/hard/expert
    var strategy: AIStrategy

    func waitAction(player: Player) -> Action:
        return strategy.evaluateBestAction(player)
```

**预估工作量**：1-2 周

---

### 2.5 网络/联机系统设计（P3）

**当前状态**：完全缺失。AGENTS.md 说明项目要支持"多人联机"，但无网络架构设计。

**需补充的设计内容**：

#### 2.5.1 网络架构选型

需做技术选型：

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| Godot High-level Multiplayer | 官方支持，集成度高 | 需理解 RPC/ENet | 推荐方案 |
| 自定义 WebSocket | 灵活，跨平台 | 需自行实现同步逻辑 | Web 端兼容 |
| 第三方服务（Photon/Mirror） | 成熟稳定 | 可能有授权费用 | 商业项目 |

#### 2.5.2 同步策略

| 策略 | 适用场景 | 说明 |
|------|---------|------|
| 状态同步 | 回合制游戏（本项目） | 同步游戏状态快照，适合低频更新 |
| 帧同步 | 即时战略 | 同步玩家输入，需确定性模拟 |

> 本项目为回合制卡牌游戏，**推荐状态同步**：每个动作完成后同步状态。

#### 2.5.3 房间系统

- 房间创建/加入/离开
- 房主权限（开始游戏/踢人/设置）
- 玩家列表与座位顺序
- 断线重连

#### 2.5.4 状态序列化

需定义游戏状态的序列化/反序列化方案（与存档系统共用）：
- 玩家状态（HP/饥饿/手牌/装备/怪物区等）
- 地图状态（地块/标记/怪物）
- 牌堆状态（顺序与内容）
- 任务状态（任务配置/任务状态字典）

#### 2.5.5 网络协议

- 动作广播（玩家执行动作 → 广播给所有客户端）
- 状态同步（主机 → 客户端的状态快照）
- 心跳检测（断线判定）
- 重连恢复（断线后恢复游戏状态）

**预估工作量**：2-3 周

---

### 2.6 存档系统设计（P3）

**当前状态**：完全缺失。

**需补充的设计内容**：

#### 2.6.1 存档点设计

| 存档类型 | 触发时机 | 说明 |
|---------|---------|------|
| 自动存档 | 每回合开始时 | 防止意外丢失进度 |
| 手动存档 | 玩家主动触发 | 退出游戏前保存 |
| 任务完成存档 | 任务胜利后 | 保存通关记录 |

#### 2.6.2 存档数据结构

```gdscript
# SaveData.gd
class SaveData:
    var version: String          # 存档版本号
    var timestamp: int           # 存档时间
    var missionId: int           # 任务编号
    var gameState: Dictionary    # 完整游戏状态序列化
    var players: List[Dictionary]  # 所有玩家状态
    var map: Dictionary          # 地图状态
    var piles: Dictionary        # 所有牌堆状态
    var missionState: Dictionary  # 任务状态
    var turnQueue: List          # 回合队列
    var currentPlayerId: int     # 当前行动玩家
```

#### 2.6.3 存档格式

| 方案 | 优点 | 缺点 |
|------|------|------|
| JSON | 可读，易调试 | 文件较大 |
| MessagePack | 紧凑，高效 | 需额外库 |
| Godot Resource | 原生支持 | 二进制，不易调试 |

> 推荐 **JSON 格式**（开发期）+ **Godot Resource**（发布期）。

#### 2.6.4 存档位置

- Windows: `%APPDATA%/Godot/app_userdata/MxApoc_GDScript/saves/`
- 跨平台路径管理

#### 2.6.5 存档兼容性

- 版本号管理
- 存档迁移（旧版本存档升级到新版本）

**预估工作量**：3-5 天

---

## 三、优先级与时间线建议

```
阶段 1: 核心逻辑层（4-6 周）
├── 补充: Godot 工程结构设计（1-2 天）     ← 立即需要
├── 补充: UI 交互接口设计（3-5 天）         ← 阶段 1 中期需要
└── 实现: GameSystem + Resource 加载

阶段 2: 单机热座模式（2-3 周）
├── 补充: 3D 表现层设计（1-2 周）           ← 阶段 2 开始前
├── 实现: 3D 场景 + 动画 + UI
└── 实现: 热座模式（单机多人轮流）

阶段 3: 人机合作模式（2-3 周）
├── 补充: AI 玩家系统设计（1-2 周）         ← 阶段 3 开始前
├── 补充: 存档系统设计（3-5 天）            ← 阶段 3 开始前
├── 实现: AI 玩家
└── 实现: 存档系统

阶段 4: 多人联机模式（3-4 周）
├── 补充: 网络/联机系统设计（2-3 周）       ← 阶段 4 开始前
└── 实现: 房间系统 + 状态同步 + 断线重连
```

---

## 四、非阻塞性说明

上述 6 大缺失系统**不阻塞**核心游戏逻辑层的开发，原因：

1. **GameSystem 设计已自洽**：95 个方法的伪代码完整，可独立实现与测试
2. **UI 交互可抽象**：通过接口（IPlayerInput）抽象 UI 交互点，先用命令行实现，后续替换
3. **数据加载可独立**：Resource 数据可转为 JSON 独立加载，不依赖 UI/网络
4. **3D 表现可延后**：核心逻辑层不依赖 3D 资源，可先用 2D/文本调试
5. **AI/网络/存档是扩展**：这些系统建立在核心逻辑层之上，需先有核心逻辑

---

## 五、建议的补充设计文档清单

在 `GameDesignDocus/` 下建议新增以下设计文档：

| 文档路径 | 内容 | 优先级 |
|---------|------|--------|
| `GameDesignDocus/Engineering/GodotProjectStructure.md` | Godot 工程结构 + 目录 + autoload + 标识符映射 | P0 |
| `GameDesignDocus/Engineering/UIInterface.md` | UI 交互接口定义 + 玩家输入模式 | P1 |
| `GameDesignDocus/Engineering/IdentifierMapping.md` | 中英文标识符完整映射表 | P0 |
| `GameDesignDocus/Engineering/DataFormat.md` | Resource markdown → JSON 转换规范 | P0 |
| `GameDesignDocus/Presentation/3DScene.md` | 3D 场景结构 + 摄像机 + 灯光 | P2 |
| `GameDesignDocus/Presentation/Animation.md` | 动画系统 + 特效系统 | P2 |
| `GameDesignDocus/Presentation/AssetList.md` | 美术/音效资源清单 | P2 |
| `GameDesignDocus/AI/AIArchitecture.md` | AI 决策架构 + 难度等级 + 行为模块 | P2 |
| `GameDesignDocus/Network/NetworkArchitecture.md` | 网络架构 + 同步策略 + 房间系统 | P3 |
| `GameDesignDocus/Network/StateSerialization.md` | 状态序列化方案 | P3 |
| `GameDesignDocus/Save/SaveSystem.md` | 存档系统设计 | P3 |

---

## 六、下一步行动建议

1. **立即补充 P0 设计**（Godot 工程结构 + 标识符映射 + 数据格式）— 1 周内
2. **启动核心逻辑层开发**（阶段 1）— P0 设计完成后立即开始
3. **阶段 1 中期补充 P1 设计**（UI 交互接口）— 开发到玩家交互方法时
4. **按阶段推进补充 P2/P3 设计**— 对应功能开发前 1-2 周

---

## 七、相关文档

- [feasibility-analysis.md](feasibility-analysis.md) — 核心逻辑层开发可行性分析
- [GameDesignDocus/README.md](../GameDesignDocus/README.md) — 设计文档总览
- [AGENTS.md](../AGENTS.md) — 项目说明书（Godot 4.7 + GDScript + 3D + 单机/人机/联机）
