# 轮次 05:Judge 检定系统

> 状态: `[ ] 未开始`
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md) | 规则来源:[GameSystem/Judge.md](../GameDesignDocus/GameSystem/Judge.md) | [E_gameJudge.md](../GameDesignDocus/GameInstructions/E_gameJudge.md)

---

## 1. 范围

本轮实现 3 个检定方法,以及支持它们的最小 MapBlock stub。包含:

1. **`player.judge()`**:投两颗骰子,返回点数和
2. **`player.sneakJudge()`**:潜行检定,返回成功/失败
3. **`player.monsterSpawnJudge()`**:怪物出生检定,遍历匹配地图块
4. **MapBlock stub 类**:最小实现,支持 countMonsterMark/hasPlayer/addMonsterMark 等接口
5. **Player.随机投掷两颗大骰子()**:待定义方法,本轮实现

**本轮实现的已定义方法**:
- `player.judge()`
- `player.sneakJudge()`
- `player.monsterSpawnJudge()`

**本轮实现的相关待定义方法**:
- `player.随机投掷两颗大骰子()`

**本轮 stub**:
- `player.drawMonster(n)` —— 已定义方法,本轮空实现 + 日志
- MapBlock 的真实逻辑(后续轮次)

**本轮不实现**:
- MapBlock 真实实体(后续轮次)
- drawMonster 真实逻辑(后续 DrawFlow 轮次)
- game.getRevealedMapBlocks()(本轮用注入式列表)

---

## 2. 前置依赖

- **代码**: 01 轮 EventTrigger、02 轮 Player(潜行值/所在地图块/角色卡牌)
- **文档**: 已读 `GameSystem/Judge.md`、`E_gameJudge.md`

---

## 3. 设计要点(从 GameSystem/Judge.md 提炼)

### 3.1 judge() 伪代码
```
function player.judge() {
    player.随机投掷两颗大骰子()
    result = 两颗大骰子的点数之和
    return result
}
```
- 投两颗骰子,返回和
- "大骰子"指物理尺寸,点数仍为 1-6(标准骰子)
- 返回值范围:2-12

### 3.2 sneakJudge() 伪代码
```
function player.sneakJudge() {
    num = countMonster(player.所在地图块()) + countMonsterMark(player.所在地图块())
    sneakValue = player.潜行值() - num
    result = player.judge()
    if (result <= sneakValue) { return true }
    else { return false }
}
```
- 潜行值减成 = 地块怪物数 + 怪物标记数
- 检定结果 <= 潜行值(减成后)则成功
- 失败时(E_gameJudge.md):移除该地图块所有怪物标记,每移除一个抓一张怪物卡(本轮不实现此分支,仅 return false)

### 3.3 monsterSpawnJudge() 伪代码
```
function player.monsterSpawnJudge() {
    result = player.judge()
    List = 所有已经展示的,且怪物生成点数等于 result 的地图块
    for i in List {
        if (i.countMonsterMark() < 3) {
            i.addMonsterMark(1)
        } else if (i.countMonsterMark() == 3 && i.hasPlayer()) {
            List2 = 此地图块上的所有玩家
            for j in List2 {
                j.drawMonster(1)
            }
        }
    }
}
```
- 投骰子得 result
- 找所有已展示且怪物生成点数 == result 的地图块
- 标记 < 3:+1 标记
- 标记 == 3 且有玩家:每个玩家 drawMonster(1)

---

## 4. 设计决策(需确认)

### 4.1 骰子实现(提议)
新建 `scripts/system/dice.gd`:
```gdscript
class_name Dice extends RefCounted

## 投两颗标准骰子(1-6),返回点数和(2-12)。
## 规则引用: GameSystem/Judge.md
static func roll_two() -> int:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    return rng.randi_range(1, 6) + rng.randi_range(1, 6)
```
- "大骰子"理解为标准 1-6 骰子(物理尺寸不影响点数)
- 若设计文档指其他点数范围,需用户澄清

Player 实现:
```gdscript
## 投两颗大骰子。规则引用: GameSystem/Judge.md
func 随机投掷两颗大骰子() -> int:
    return Dice.roll_two()
```

### 4.2 MapBlock stub 类(提议)
新建 `scripts/system/map_block.gd`:
```gdscript
class_name MapBlock extends Entity

## 怪物生成点数(匹配 judge 结果)。
var 怪物生成点数: int = 0

## 是否已展示(翻开)。
var _revealed: bool = false

## 怪物标记数(0-3)。
var _monster_marks: int = 0

## 当前地块上的怪物卡列表(stub,空)。
var _monsters: Array = []

## 当前地块上的玩家列表(stub,空)。
var _players: Array = []

## 是否已展示。
func is_revealed() -> bool:
    return _revealed

## 怪物标记数。
## 规则引用: GameSystem/Judge.md(monsterSpawnJudge)
func countMonsterMark() -> int:
    return _monster_marks

## 添加 n 个怪物标记。
func addMonsterMark(n: int) -> void:
    _monster_marks += n

## 移除所有怪物标记。
func removeAllMonsterMarks() -> void:
    _monster_marks = 0

## 地块上是否有玩家。
func hasPlayer() -> bool:
    return not _players.is_empty()

## 地块上的怪物数(stub,返回 _monsters 大小)。
func countMonster() -> int:
    return _monsters.size()

## 添加玩家到地块。
func addPlayer(p: Player) -> void:
    _players.append(p)

## 移除玩家。
func removePlayer(p: Player) -> void:
    _players.erase(p)

## 设置已展示(测试用)。
func _set_revealed(v: bool) -> void:
    _revealed = v
```
- `extends Entity`(01 轮),可挂技能(地块技能后续轮次)
- 方法名保留设计文档中文/英文混用(`countMonsterMark`/`addMonsterMark`/`hasPlayer`/`countMonster` 为英文,`怪物生成点数` 为中文属性)
- 本轮仅实现 Judge 所需接口,不实现地块技能/移动钩子

### 4.3 countMonster/countMonsterMark 全局函数 vs MapBlock 方法
设计文档用全局函数 `countMonster(mapBlock)` / `countMonsterMark(mapBlock)`。本轮提议改为 **MapBlock 方法** `mapBlock.countMonster()` / `mapBlock.countMonsterMark()`:
- 更符合 OOP
- 与 `mapBlock.hasPlayer()` / `mapBlock.addMonsterMark()` 风格一致
- 设计文档伪代码的 `countMonster(block)` 可视为 `block.countMonster()` 的等价写法

**此偏差需用户确认。** 若用户要求严格保留全局函数形式,本轮补 `countMonster`/`countMonsterMark` 为全局函数(或 game 静态方法)。

### 4.4 Player.所在地图块() 扩展
02 轮 `所在地图块()` 返回 null。本轮扩展:
```gdscript
# Player 类追加
## 设置当前所在地图块(测试与后续移动流程用)。
func set_current_block(block: MapBlock) -> void:
    _current_block = block

## 当前所在地图块。null 表示未在地图上。
func 所在地图块() -> Variant:
    return _current_block
```
- 02 轮 `_current_block: Variant = null`,本轮允许设置
- 返回类型保持 Variant(后续可收紧为 MapBlock)

### 4.5 monsterSpawnJudge 的地图块列表来源
设计文档:"所有已经展示的,且怪物生成点数等于 result 的地图块"。本轮无 game 对象:
- **提议**: monsterSpawnJudge 接受 `revealed_blocks: Array[MapBlock]` 参数,由调用方传入
- **签名**: `func monsterSpawnJudge(revealed_blocks: Array[MapBlock] = []) -> void`
- **理由**: 避免依赖未实现的 game 对象;测试时可注入 mock 列表
- **后续**: game 对象实现后,改为内部调用 `game.getRevealedMapBlocks()`

**此签名变更需用户确认。** 若用户要求严格保留无参签名,本轮用全局 stub 函数获取列表。

### 4.6 drawMonster stub
```gdscript
# Player 类追加
## 抓 n 张怪物卡。本轮 stub;真实逻辑见 GameSystem/DrawFlow.md(后续轮次)。
## 规则引用: GameSystem/DrawFlow.md
func drawMonster(n: int) -> void:
    push_warning("drawMonster stub called on %s, n=%d" % [名字, n])
```
- 已定义方法,本轮空实现 + 日志
- 后续 DrawFlow 轮次实现真实逻辑

### 4.7 sneakJudge 失败分支
E_gameJudge.md:"潜行检定失败,移除该地图块上的所有怪物标记,每移除一个怪物标记就抓一张怪物卡。"
- **本轮处理**: sneakJudge 仅返回 bool,**不实现** 失败后的移除标记+抓怪物逻辑
- **理由**: 失败分支涉及 drawMonster(本轮 stub)与 removeAllMonsterMarks,且属于"调用方行为"而非检定本身
- **后续**: 调用方(Movement 节点 10)实现失败分支

**此处理需用户确认。** 若用户要求 sneakJudge 内部处理失败分支,本轮补。

### 4.8 命名说明
| 方法 | 命名 | 依据 |
|------|------|------|
| `judge`/`sneakJudge`/`monsterSpawnJudge` | 英文原名(camelCase) | 已定义方法契约(§3.2) |
| `随机投掷两颗大骰子` | 中文 | 设计文档中文方法名(§3.6) |
| `countMonsterMark`/`addMonsterMark`/`hasPlayer`/`countMonster` | 英文 camelCase | 设计文档伪代码用此形式,且为 MapBlock 接口 |
| `怪物生成点数` | 中文属性 | 设计文档中文术语(§3.6) |
| `Dice.roll_two` | snake_case | 非设计文档方法,新设计,按 §4.1 |

### 4.9 目录结构(本轮后)
```
scripts/system/
├── entity.gd          # 01-03 轮(无改动)
├── event.gd           # 01 轮(无改动)
├── skill.gd           # 01 轮(无改动)
├── role_card.gd       # 02 轮(无改动)
├── player.gd          # 02-04 轮 + 追加 judge/sneakJudge/monsterSpawnJudge/随机投掷两颗大骰子/drawMonster stub/set_current_block
├── dice.gd            # 05 轮新增
└── map_block.gd       # 05 轮新增(stub)
```

---

## 5. 实施任务清单

1. [ ] 与用户确认 §4.3(MapBlock 方法 vs 全局函数)、§4.5(monsterSpawnJudge 签名)、§4.7(sneakJudge 失败分支)
2. [ ] 新建 `scripts/system/dice.gd`(§4.1)
3. [ ] 新建 `scripts/system/map_block.gd`(§4.2)
4. [ ] 在 `scripts/system/player.gd` 追加:
   - `随机投掷两颗大骰子()`(§4.1)
   - `set_current_block()`(§4.4)
   - `judge()`(§3.1)
   - `sneakJudge()`(§3.2)
   - `monsterSpawnJudge(revealed_blocks)`(§3.3, §4.5)
   - `drawMonster()` stub(§4.6)
5. [ ] 在 `待定义方法.md` 登记 `drawMonster` 为 stub 状态
6. [ ] 新建 `tests/unit/test_judge.gd`(§6 验收用例)
7. [ ] 运行 GUT 测试,全部通过
8. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI

---

## 6. 验收标准(测试用例)

测试文件:`tests/unit/test_judge.gd`,继承 `GutTest`。
骰子随机性测试用固定 seed 或多次采样统计。

### 6.1 judge
- `test_judge_returns_value_in_2_to_12`: 调用 `judge()` 100 次,断言每次结果 ∈ [2, 12]
- `test_judge_can_return_extremes`: 调用 1000 次,断言至少出现过 2 和 12(或用 mock 骰子强制极值)
- `test_judge_uses_随机投掷两颗大骰子`: spy `随机投掷两颗大骰子`,断言 judge 调用了它一次

### 6.2 sneakJudge
- `test_sneakJudge_success_when_result_le_sneakValue`: 潜行值=8,地块无怪物无标记(sneakValue=8),mock 骰子返回 8 → 返回 true
- `test_sneakJudge_fail_when_result_gt_sneakValue`: 潜行值=8,mock 骰子返回 9 → 返回 false
- `test_sneakJudge_reduces_by_monster_count`: 潜行值=8,地块 2 怪物 + 1 标记(sneakValue=5),mock 骰子返回 5 → true;返回 6 → false
- `test_sneakJudge_with_null_block_treats_as_zero`: 所在地图块=null,潜行值=8(sneakValue=8,无减成),mock 骰子返回 8 → true
- `test_sneakJudge_negative_sneakValue`: 潜行值=2,地块 5 怪物(sneakValue=-3),mock 骰子返回 2 → false(2 > -3)

### 6.3 monsterSpawnJudge
- `test_monsterSpawnJudge_adds_mark_when_below_3`: 1 个已展示地图块,怪物生成点数=7,countMonsterMark=0,mock 骰子返回 7 → 该块 countMonsterMark==1
- `test_monsterSpawnJudge_adds_mark_at_2`: countMonsterMark=2,mock 返回匹配值 → countMonsterMark==3
- `test_monsterSpawnJudge_at_3_with_player_calls_drawMonster`: countMonsterMark=3,有玩家,mock 返回匹配值 → drawMonster 被调用(用 spy 验证)
- `test_monsterSpawnJudge_at_3_without_player_no_drawMonster`: countMonsterMark=3,无玩家 → drawMonster 不调用
- `test_monsterSpawnJudge_skips_non_matching_blocks`: 地块怪物生成点数=5,mock 返回 7 → 该块不变
- `test_monsterSpawnJudge_skips_unrevealed_blocks`: 未展示地块(即使点数匹配)不变
- `test_monsterSpawnJudge_multiple_matching_blocks`: 2 个匹配地块,均 < 3 标记 → 都 +1

### 6.4 MapBlock stub
- `test_map_block_countMonsterMark_default_0`: 新建 MapBlock,`countMonsterMark()` == 0
- `test_map_block_addMonsterMark_increases`: `addMonsterMark(2)` → countMonsterMark == 2
- `test_map_block_hasPlayer_default_false`: `hasPlayer()` == false
- `test_map_block_addPlayer_then_has`: `addPlayer(p)` → `hasPlayer()` == true
- `test_map_block_is_revealed_default_false`: `is_revealed()` == false

### 6.5 Player 集成
- `test_player_set_current_block`: `set_current_block(block)` → `所在地图块()` == block

---

## 7. 风险与待澄清

| 项 | 说明 | 处理 |
|----|------|------|
| "大骰子"点数范围 | 设计文档未明确点数,本轮假设 1-6 | §4.1 假设标准骰子;若用户澄清其他范围,调整 |
| countMonster/countMonsterMark 全局 vs 方法 | 设计文档用全局函数,本轮提议 MapBlock 方法 | §4.3 提议,动笔前确认 |
| monsterSpawnJudge 签名 | 设计文档无参,本轮提议接受 revealed_blocks 参数 | §4.5 提议,动笔前确认 |
| sneakJudge 失败分支 | E_gameJudge.md 要求失败时移除标记+抓怪物,本轮不实现 | §4.7 提议仅返回 bool,动笔前确认 |
| drawMonster stub | 已定义方法本轮空实现 | 后续 DrawFlow 轮次实现 |
| MapBlock 仅 stub | 真实地块技能/移动钩子未实现 | 后续 MapBlock 实体轮次 |
| 骰子随机性测试 | 真随机不可重复 | 用 mock 骰子(注入 Callable)或固定 seed;本轮提议 Dice.roll_two 用 RNG,测试用 spy/mock |

---

## 8. 不做的事

- 不实现 MapBlock 真实逻辑(地块技能、移动钩子、展示机制)
- 不实现 drawMonster 真实逻辑(后续 DrawFlow 轮次)
- 不实现 game 对象(monsterSpawnJudge 用参数注入列表)
- 不实现 sneakJudge 失败分支(§4.7)
- 不实现"重洗怪物弃牌堆"(drawMonster 后续轮次)
- 不修改 `data/` 下任何文件
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不解决 §9.x 歧义(本轮无直接相关)
