# LogColors 日志着色工具

> 以 `src/common/log_colors.gd` 为准。
> 职责：日志实体名 BBCode 着色工具类。统一封装角色 / 怪物 / 卡牌 / 技能 / 地图块名的着色逻辑，配合 `RichTextLabel`（`bbcode_enabled = true`）使用。
> 类名 `LogColors`，继承 `RefCounted`。所有公开方法均为 `static`。

---

## 颜色常量

| 常量名 | 类型 | 值 | 含义 |
|--------|------|----|------|
| `PLAYER` | String | `#73d0ff` | 角色名：浅天蓝色 |
| `MONSTER` | String | `#ff7b7b` | 怪物名：浅珊瑚红 |
| `CARD` | String | `#d299ff` | 卡牌名：淡紫 |
| `SKILL` | String | `#ffd370` | 技能名：暖金黄色 |
| `BLOCK` | String | `#88dd88` | 地图块名：薄荷绿 |
| `TEXT` | String | `#cccccc` | 其他字符：浅灰白 |
| `BG` | String | `#1E2228` | 日志背景：深暗色 |

---

## 静态方法

> 6 个 static 公开方法。返回 BBCode 包裹的双引号字符串：`[color=<颜色>]"name"[/color]`。

### player(name: String) -> String

> 角色名着色（PLAYER 浅天蓝）。返回 `[color=#73d0ff]"name"[/color]`。

### monster(name: String) -> String

> 怪物名着色（MONSTER 浅珊瑚红）。返回 `[color=#ff7b7b]"name"[/color]`。

### card(name: String) -> String

> 卡牌名着色（CARD 淡紫）。返回 `[color=#d299ff]"name"[/color]`。

### skill(name: String) -> String

> 技能名着色（SKILL 暖金黄）。返回 `[color=#ffd370]"name"[/color]`。

### block(name: String) -> String

> 地图块名着色（BLOCK 薄荷绿）。返回 `[color=#88dd88]"name"[/color]`。

### skill_by_type(name: String, skill_type: String) -> String

> 根据 skill_type 决定技能名颜色：
> - `"block"` → BLOCK（薄荷绿）
> - `"monster"` → MONSTER（浅珊瑚红）
> - 其他 → CARD（淡紫）
>
> 用于 [Entity](../Core/Entity.md) trigger 中输出"X 触发了 Y"日志时按技能类型着色。

---

## 内部方法

### _wrap(name: String, color: String) -> String

> 内部静态方法：用指定颜色包裹双引号文本，返回 `"[color=%s]\"%s\"[/color]" % [color, name]`。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](../Game/Game.md) | `log_message` / `create_scavenge_card` / `destroy_map_block` 等流程中日志输出使用 |
| [Entity](../Core/Entity.md) | trigger 中按 skill_type 输出技能名着色（`skill_by_type`） |
