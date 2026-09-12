# NetInputCodec 输入编解码

> 以 `MxApoc_GDScript/src/net/net_input_codec.gd` 为准（约 402 行）。
> `class_name NetInputCodec`，`extends RefCounted`，非 autoload，**全部方法为 static**，纯工具类。
> 职责：**输入候选和响应的稳定 ID 编解码，禁止把运行时对象直接放进 RPC**。对象↔带 `__kind` 标记的稳定字典快照，尽量返回活对象引用而非重建。

---

## 一、职责

`encode` 把运行时对象/候选列表编码为可走 RPC 的稳定数据结构；`decode` 逆编码，尽量返回活对象**引用**（不写回战斗字段），只有找不到活对象时才重建新实例（快照场景）。还提供从静态数据新建卡牌/怪物的入口。

无常量、无信号、无实例成员（纯静态）。

---

## 二、方法定义

| 方法 | 签名 | 说明 |
| --- | --- | --- |
| `encode` | `static func encode(value: Variant) -> Variant` | 运行时对象/候选列表 → 稳定 RPC 数据结构 |
| `apply_display_combat_fields` | `static func apply_display_combat_fields(value: Variant, game: Variant) -> void` | 选目标弹窗专用：把 payload 中的怪物战斗字段写到显示层活对象；`__kind=="monster"` 时经 `_find_live_monster` 定位后 `_apply_monster_payload` |
| `decode` | `static func decode(value: Variant, game: Variant = null) -> Variant` | 逆编码；`game==null` 原样返回；有 `net_id` 且命中活对象则**只返回引用、不写回战斗字段**；否则按 `__kind` 分支重建/解析 |
| `resolve_card` | `static func resolve_card(value: Dictionary, game: Variant) -> Variant` | 网络卡牌描述 → 已存在的完整卡牌实例（按 net_id → 按 english_name 在各区域 → 新建） |
| `create_card_from_payload` | `static func create_card_from_payload(value: Dictionary, game: Variant) -> Variant` | 不复用场上实例，从静态数据或 payload 新建卡牌（`source=="game"` 走求生者牌、`source=="scavenge"` 走拾荒堆、否则裸建） |
| `apply_monster_payload` | `static func apply_monster_payload(monster: Variant, value: Dictionary) -> void` | 公开入口，包装 `_apply_monster_payload` |
| `resolve_skill` | `static func resolve_skill(value: Dictionary, game: Variant) -> Variant` | 网络技能描述 → 已创建的真实 `Skill` 实例；只按 `english_name` 查找（含 `sub_skills` 递归），找不到返回 `null` |

**私有方法**：`_find_live_monster`、`_apply_monster_payload`、`_find_skill_in_array`、`_entity_net_id`、`_string_property`。

---

## 三、编码格式（`encode` 输出）

不是位级紧凑二进制，而是**带 `__kind` 标记的稳定字典快照**：

| 输入 | 输出 |
| --- | --- |
| 标量（null/bool/int/float/String） | 原样透传 |
| `Array` | 逐元素递归 `encode` |
| `Dictionary` | key 强转 String 后逐值递归 |
| `MonsterCard` | `{"__kind":"monster_card", net_id, id, card_name, card_type, source, monster_type, monster_level, max_hp, damage_value, range}` |
| `Monster` | `{"__kind":"monster", net_id, id, monster_name, monster_type, monster_level, hp, max_hp, damage_value, range, stunned, holder_seat, zone_index}` |
| `Equipment` | `{"__kind":"equipment", net_id, id, card_name, card_type, source, size, range, charge_type, charge_max, charge_current, weapon, owner_seat, equipment_index}` |
| `Card` | `{"__kind":"card", net_id, id, card_name, card_type, source}` |
| `Skill` | `{"__kind":"skill", id, skill_name}`（**无 net_id**） |
| `Player` | `{"__kind":"player", net_id, seat_id, role_english_name}` |
| `MapBlock` | `{"__kind":"block", net_id, x, y}` |
| 其它带 `english_name` 对象 | `{"__kind":"entity", net_id, id}` |
| 其余 | `str(value)` 兜底 |

**decode 优先级**：Array 递归 → 无 `__kind` 的 Dictionary 递归 → `game==null` 返回 → **有 net_id 且命中活对象则返回引用（不写回战斗字段）** → 按 `__kind` 分支重建/解析。

---

## 四、关键业务逻辑

- **技能 content/filter 等 Callable 不传输**：`resolve_skill` 只按名解析为本地已编译的 `Skill` 实例，代码字段始终用本地编译版本。
- **decode 不写回战斗字段**（v0.37.4 起）：命中活对象只返回引用，避免客机把过期 hp 等覆盖显示层；只有 `apply_display_combat_fields`（选目标弹窗专用）例外，用于刷新显示层战斗数值。
- **用索引令牌定位**：monster 用 `holder_seat`+`zone_index`、equipment 用 `owner_seat`+`equipment_index` 在对应区定位活对象。

---

## 五、与其他类的关系

| 关系 | 说明 |
| --- | --- |
| [NetSession](./NetSession.md) | 调用 `encode`（`send_input_response` 等） |
| [GameStateSerializer](./GameStateSerializer.md) | `find_by_net_id` 定位活实体 |
| [DataManager](../../Engineering/DataFormat.md) | `get_all_survivors` / `get_scavenge_pile` 建卡 |
| [Game](../../README.md) | `get_block_by_coord` / `_create_game_card_from_dict` / `_create_scavenge_card_from_data` |
