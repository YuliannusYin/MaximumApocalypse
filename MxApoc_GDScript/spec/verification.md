# 验收方法与标准

> 每轮迭代用 GUT(Godot Unit Test) 框架写单元测试,验收通过才进入下一轮。
>
> 配套:[路线图](roadmap.md) | [AGENTS.md](../AGENTS.md) §3.8 提交前自检

---

## 1. 测试框架:GUT

- **框架**: [GUT](https://github.com/bitwes/gut)(Godot Unit Test),Godot 4.x 用 GUT 9.x+
- **安装**: 将 GUT 插件克隆到 `addons/gut/`,在编辑器中启用 plugin,或在 `project.godot` 中手动注册
- **目录**: 测试代码放 `tests/unit/`,与生产代码 `scripts/` 分离
- **入口**: 通过 GUT 提供的测试运行场景运行,或命令行 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit`

> **01 轮前置任务**: 在 `project.godot` 中配置 GUT,确保 `addons/gut/` 可用。若用户已有偏好测试框架,在此文档登记替换。

---

## 2. 目录结构

```
tests/
├── unit/                       # 单元测试(每轮产出)
│   ├── test_event_trigger.gd   # 01 轮
│   ├── test_player.gd          # 02 轮
│   ├── test_damage_flow.gd     # 03 轮
│   ├── test_player_state.gd    # 04 轮
│   └── test_judge.gd           # 05 轮
└── integration/                # 集成测试(后续轮次,暂不产出)
```

测试文件与被测模块一一对应,文件名 `test_<module>.gd`,模块名取自 `scripts/` 下的脚本名(不含扩展名)。

---

## 3. 命名约定

- **文件**: `test_<被测模块>.gd`(`test_event_trigger.gd` ↔ `scripts/system/event_trigger.gd`)
- **测试函数**: `test_<场景>_<期望行为>()`
  - `test_trigger_calls_matching_skill_content()`
  - `test_trigger_skips_non_matching_filter()`
  - `test_cancel_stops_subsequent_skills()`
- **测试用例分组**: 用 GUT 的 `class TestXxx extends GutTest` 内分 `func test_xxx()` 函数
- **辅助函数**: 私有前缀 `_helper_xxx`,放在测试类底部

---

## 4. 每个已定义方法的测试用例要求

每个已定义方法至少覆盖以下 3 类用例,缺一不可:

| 类别 | 定义 | 示例(recover) |
|------|------|---------------|
| **正常** | 典型输入下行为正确 | HP=3, max=6, recover(2) → HP=5 |
| **边界** | 极值/临界输入 | HP=5, max=6, recover(5) → HP=6(不溢出) |
| **异常/无效** | 非法输入不崩溃,行为符合契约 | recover(0) / recover(-1) → 不变更 |

**额外要求**:
- 有事件钩子的方法,每类用例都要断言钩子触发顺序与次数
- 有 `event.cancel()` 取消点的方法,必须有用例验证取消后状态回滚
- 有 source=NULL 等特殊参数的方法,必须有用例覆盖该分支
- 涉及随机性的方法(judge/draw 等),用固定 seed 或 mock 骰子

---

## 5. 验收标准(每轮 Definition of Done)

一轮迭代视为完成,当且仅当:

1. **代码**: 实现了本轮范围内所有已定义方法,签名与 `已定义方法.md` 契约一致
2. **测试**: 配套 `test_<module>.gd` 完成,覆盖 §4 的 3 类用例,且全部通过
3. **解析**: GDScript 解析无错误(编辑器底部状态栏绿)
4. **注释**: 按 [comments.md](../.trae/rules/comments.md) 规则,Public API 有 `##` 文档注释,Complex Logic 有 `# 规则引用`
5. **文档**: 把本轮实现的方法从 `待定义方法.md` 迁移到 `已定义方法.md`(若适用)
6. **未触碰**: 未重构本轮范围外的代码(AGENTS.md §3.7)
7. **关键路径**: 走通 AGENTS.md §6.2 的 1-3 步(主菜单→GameRoom→GameScene→返回),确认未破坏现有 UI

---

## 6. 测试运行

### 6.1 编辑器内
- 安装 GUT 后,编辑器底部出现 GUT 面板
- 选择测试目录 `res://tests/unit/`,点击 Run

### 6.2 命令行(自动化用)
```powershell
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
- `-gexit`: 测试结束退出,返回码 0=全部通过,1=有失败
- 适合 CI/CD(后续接入)

### 6.3 单文件运行
```powershell
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_event_trigger -gexit
```

---

## 7. 测试代码本身的要求

- **不依赖场景树**: 单元测试用 `GutTest` 基类,`new` 出被测对象,不 `$`/`%` 节点路径
- **不依赖 autoload**: 测试中 `new` 出 `RoomState`/`Settings` 等的替代品或 mock,不依赖全局单例
- **每个测试函数独立**: 不依赖前一个测试的状态,`before_each` 重置
- **断言明确**: 用 `assert_eq`/`assert_true`/`assert_false`/`assert_called`,不要 `print` + 人工看
- **mock 钩子**: 测试 EventTrigger 时,用 Callable 注入假技能,不依赖真实技能系统

---

## 8. 不验收的情况

以下情况本轮迭代**不通过**,需返工:

- 测试用例少于 §4 要求的 3 类(正常/边界/异常)
- 测试通过但靠 `print` 人工判断,无 `assert_*`
- 实现的签名与 `已定义方法.md` 契约不一致(参数顺序、默认值、返回类型)
- 触碰了本轮范围外的代码(除非是必要的 stub,且在文档中登记)
- GUT 测试有 fail/error/warning(GUT 的 warning 需排查是否误报)
