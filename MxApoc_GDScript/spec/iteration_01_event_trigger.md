# 轮次 01:EventTrigger 事件系统

> 状态: `[x] 已完成`
>
> 路线图:[roadmap.md](roadmap.md) | 验收:[verification.md](verification.md) | 规则来源:[GameSystem/EventTrigger.md](../GameDesignDocus/GameSystem/EventTrigger.md)

---

## 1. 范围

本轮实现事件触发系统,这是所有后续 GameSystem 流程的基础设施。包含 4 个产出物:

1. **Skill 资源结构**:表示一个技能(trigger + filter + content)
2. **Event 对象**:事件上下文,承载 triggerName/source/target/num/type/cancelled
3. **Entity 基类**:所有可挂技能的实体(Player/Monster/MapBlock/Card)的父类
4. **`entity.trigger(triggerName, event)` 方法**:遍历技能,依次触发匹配的

**本轮实现的已定义方法**:
- `entity.trigger(triggerName, event)` —— 见 [已定义方法](../GameDesignDocus/已定义方法.md)

**本轮不实现**:
- Player/Monster 等具体实体(02 轮)
- 具体技能的 filter/content 逻辑(各 Pack 实现时)
- damage/draw/moveTo 等流程(03+ 轮)

---

## 2. 前置依赖

- **代码**: 无(本轮是最底层)
- **环境**: 需先安装配置 GUT(见 [verification.md](verification.md) §1)
- **文档**: 已读 `GameSystem/EventTrigger.md`

---

## 3. 设计要点(从 GameSystem/EventTrigger.md 提炼)

伪代码原文:
```
function entity.trigger(triggerName, event) {
    event.triggerName = triggerName
    skills = entity.getAllSkills()
    for s in skills {
        triggerList = s.trigger.split("、")
        if (triggerList.contains(triggerName) && s.filter(event)) {
            s.content(event)
            if (event.cancelled) {
                break
            }
        }
    }
}
```

关键点:
- `event.triggerName` 在循环外赋值(所有技能看到同一 triggerName)
- 技能的 `trigger` 字段是字符串,可用 `、` 分隔多个触发名(如 `"游戏开始时、受到伤害时"`)
- 先匹配 trigger 名,再过 `s.filter(event)`,两者都通过才执行 `s.content(event)`
- `s.content(event)` 执行后检查 `event.cancelled`,为 true 则中断循环
- `filter` 与 `content` 都是回调,接受 `event` 参数

---

## 4. 设计决策(需确认)

`GameSystem/EventTrigger.md` 未明确 Skill/Event/Entity 的数据结构,以下为本轮提议方案。**若用户有意见,在动笔前调整**。

### 4.1 Skill 结构(提议)
新建 `scripts/system/skill.gd`:
```gdscript
class_name Skill extends Resource

## 触发名。单个字符串或用"、"分隔的多个字符串(如 "游戏开始时、受到伤害时")。
@export var trigger: String

## 过滤函数。签名为 (event: Event) -> bool。默认恒真。
@export var filter: Callable = Callable()

## 内容函数。签名为 (event: Event) -> void。
@export var content: Callable = Callable()
```
- 用 `Resource` 便于在编辑器/数据文件中实例化
- `filter`/`content` 用 `Callable`,允许技能逻辑用闭包或方法引用注入
- 默认 `filter` 恒真(无过滤),`content` 空操作(占位技能)

### 4.2 Event 对象(提议)
新建 `scripts/system/event.gd`:
```gdscript
class_name Event extends RefCounted

## 触发名,由 entity.trigger 在循环外赋值。
var trigger_name: String

## 事件来源。null 表示无来源(如饥饿伤害、中毒)。
var source: Variant = null

## 事件目标。
var target: Variant = null

## 数值参数(伤害点数、抓牌数等)。可被钩子修改。
var num: int = 0

## 类型标签(如 "饥饿伤害"、"poison")。
var type: String = ""

## 是否已取消。cancel() 后为 true。
var cancelled: bool = false

## 取消事件。后续技能不再执行。
func cancel() -> void:
    cancelled = true
```
- 用 `RefCounted` 而非 `Dictionary`,类型安全,编辑器悬停提示友好
- 字段命名遵循 AGENTS.md §4.1(snake_case),但保留 `source`/`target`/`num`/`type` 与设计文档一致
- `source`/`target` 用 `Variant`,因为本轮 Entity 类型尚未定义;02 轮后可收紧为 `Entity`

### 4.3 Entity 基类(提议)
新建 `scripts/system/entity.gd`:
```gdscript
class_name Entity extends RefCounted

## 该实体上所有技能(含角色固有、装备、临时、地块等)。
var _skills: Array[Skill] = []

## 返回所有技能。子类可重写以聚合多来源(角色+装备+地块)。
func get_all_skills() -> Array[Skill]:
    return _skills

## 添加技能。
func add_skill(s: Skill) -> void:
    _skills.append(s)

## 移除技能。
func remove_skill(s: Skill) -> void:
    _skills.erase(s)

## 遍历技能,依次触发匹配 trigger_name 的。见 GameSystem/EventTrigger.md。
func trigger(trigger_name: String, event: Event) -> void:
    event.trigger_name = trigger_name
    for s in get_all_skills():
        var trigger_list := s.trigger.split("、")
        if trigger_list.has(trigger_name) and s.filter.call(event):
            s.content.call(event)
            if event.cancelled:
                break
```
- 用 `RefCounted`,Player/Monster 等子类后续 `extends Entity`
- `get_all_skills()` 返回 `_skills` 数组;02 轮 Player 可重写为聚合多来源
- `trigger` 方法严格按伪代码实现,不复用 `_skills` 直接访问

### 4.4 目录结构(提议)
```
scripts/
├── system/                # 新增:游戏系统层
│   ├── entity.gd          # Entity 基类
│   ├── event.gd           # Event 对象
│   └── skill.gd           # Skill 资源
├── autoload/              # 已有
└── ui/                    # 已有
```
- `scripts/system/` 放游戏逻辑(非 UI、非数据、非 autoload)
- 与 AGENTS.md §2 目录结构一致,只是新增子目录

---

## 5. 实施任务清单

1. [x] 安装 GUT 插件到 `addons/gut/`,在 `project.godot` 中启用(若未装)
2. [x] 新建 `scripts/system/skill.gd`(§4.1)
3. [x] 新建 `scripts/system/event.gd`(§4.2)
4. [x] 新建 `scripts/system/entity.gd`(§4.3)
5. [x] 实现 `entity.trigger(trigger_name, event)`(§4.3 末尾)
6. [x] 新建 `tests/unit/test_event_trigger.gd`(§6 验收用例)
7. [x] 运行 GUT 测试,全部通过
8. [ ] 走通 [AGENTS.md](../AGENTS.md) §6.2 关键路径 1-3,确认未破坏 UI
9. [ ] 在 `GameDesignDocus/已定义方法.md` 中确认 `entity.trigger` 条目(若需要补充实现说明)

---

## 6. 验收标准(测试用例)

测试文件:`tests/unit/test_event_trigger.gd`,继承 `GutTest`。

### 6.1 触发链顺序
- `test_trigger_calls_matching_skills_in_order`: 实体挂 3 个技能(trigger 都是 `"受到伤害时"`),content 记录调用顺序;触发后断言顺序为 1→2→3

### 6.2 filter 过滤
- `test_trigger_skills_with_false_filter_not_called`: 技能 A 的 filter 返回 false,技能 B 的 filter 返回 true;触发后只有 B 的 content 被调用
- `test_trigger_no_skills_matching`: 实体无任何技能时,trigger 不崩溃,正常返回

### 6.3 复合 trigger(、分隔)
- `test_trigger_matches_skill_with_multiple_trigger_names`: 技能 trigger = `"游戏开始时、受到伤害时"`,触发 `"受到伤害时"` 时该技能被调用;触发 `"游戏开始时"` 时也被调用;触发 `"造成伤害时"` 时不被调用

### 6.4 event.cancel() 中断
- `test_cancel_stops_subsequent_skills`: 3 个技能,第 2 个 content 调用 `event.cancel()`;触发后第 3 个不被调用,`event.cancelled == true`
- `test_cancel_does_not_affect_already_executed`: 取消后,已执行的第 1、2 个技能的副作用保留

### 6.5 event 成员可读写
- `test_trigger_name_set_before_loop`: 触发后 `event.trigger_name == "受到伤害时"`
- `test_skill_content_can_modify_event_num`: 技能 content 修改 `event.num += 5`,触发后断言 `event.num` 已变更
- `test_skill_filter_can_read_event_fields`: filter 读取 `event.source`,根据 source 决定是否执行

### 6.6 source=NULL 容忍
- `test_trigger_with_null_source`: `event.source = null`,技能 filter/content 能正常处理(不崩溃)

---

## 7. 风险与待澄清

| 项 | 说明 | 处理 |
|----|------|------|
| Skill 字段类型 | `filter`/`content` 用 `Callable` 是否够灵活? 技能数据需要序列化时(存档)Callable 不可序列化 | 本轮先用 Callable,后续若需序列化再重构为脚本子类 |
| Event.source/target 用 Variant | 类型不安全,但 Entity 类型本轮未定义 | 02 轮 Player 实现后,考虑收紧为 `Entity` 或保留 Variant |
| get_all_skills() 返回可变引用 | 调用方可直接改 `_skills` 数组 | 本轮可接受;02 轮若需要再返回不可变副本 |
| GUT 安装方式 | 用户可能偏好其他测试框架 | 已确认:GUT v9.7.0(支持 Godot 4.7),git clone 安装 |
| `、` 分隔符 | 中文顿号,不是英文逗号 | 严格按设计文档,用 `"、"` |
| GUT 9.6.0 不支持 Godot 4.7 | 初次克隆 main 分支为 9.6.0,导入报错 | 已切换到 v9.7.0 tag,测试通过 |
| `@export Callable` 不可用 | Godot 4 不支持 Callable 类型的 @export | §4.1 已说明:filter/content 用 `var`,trigger 保持 `@export` |
| ConfigFile 警告 | `--import` 时报 "ConfigFile parse error at gut_plugin.gd:3" | Godot 4.7 已知非致命警告,不影响命令行测试运行,可忽略 |
| GDScript lambda 局部变量捕获 | String 等值类型按值捕获,lambda 内赋值不回写 | 测试用 Array 容器中转(见 test_trigger_name_set_before_loop) |

---

## 8. 不做的事

- 不实现具体技能(如求生者技能、地块技能)
- 不实现 Player/Monster/MapBlock 实体(02 轮)
- 不实现 damage/draw/moveTo 等流程(03+ 轮)
- 不修改 `data/` 下任何文件
- 不修改 `scripts/ui/`、`scripts/autoload/` 下任何文件
- 不解决 §9.x 歧义(本轮无相关歧义)
