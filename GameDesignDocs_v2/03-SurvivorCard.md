# 03 - SurvivorCard（求生者游戏牌）

> 求生者游戏牌 = 求生者牌库中的卡（`ActionCardData` / `EquipmentCardData` 子类 + `source = SURVIVOR_DECK`）。
> 不单设 `SurvivorCardData` 子类（02-Card.md 决策：按类型分层 + `source` 字段标记来源）。
> 应用 v1 决策：D8（死亡后装备按来源处理）、D9（装备卡抓取先进手牌）、D10（求生者牌库循环）、D22（装备栏 size）。

---

## 1. 设计原则

- **不单设子类**：求生者卡与拾荒卡字段结构完全一致（行动卡有射程+效果，装备卡有子类+大小+射程+弹药+技能），唯一区别是来源。用 `source: CardSource.SURVIVOR_DECK` 标记，不重复定义 `SurvivorWeaponCard` / `SurvivorActionCard` 等空子类（02-Card.md 已决策）。
- **牌库 = ID 引用**：`CharacterCardData.survivor_deck_card_ids: Array[StringName]` 只存卡牌 ID 列表（含重复 ID 表示多份），运行时由 `CardRegistry` 查表实例化 `CardInstance`（07-CharacterCard.md 第 2 节）。
- **实例归 Survivor 持有**：牌库实例化后存入 `Survivor.deck`，运行时所有流转（抓牌/弃牌/装备）都在该 Survivor 的 `deck` / `hand` / `equipment_zone` / `discard_pile` 之间进行。
- **牌库循环（D10）**：`deck` 空时玩家被淘汰；`discard_pile` 在 `deck` 空时可重洗为新的 `deck`。

---

## 2. 求生者卡的定义

求生者卡就是 `02-Card.md` 中定义的 `ActionCardData` / `EquipmentCardData` 子类，只是 `source = SURVIVOR_DECK`：

```text
# 求生者行动卡示例（外科医生"快速思考"）
{
    card_id: &"surgeon_quick_thinking",
    card_type: CardType.ACTION,
    source: CardSource.SURVIVOR_DECK,    # ← 标记来源
    skill_ids: [&"draw_2_and_scavenge_1"],
    # ... 其他字段同 ActionCardData
}

# 求生者装备卡示例（消防员"防火头盔"）
{
    card_id: &"firefighter_fire_helmet",
    card_type: CardType.EQUIPMENT,
    source: CardSource.SURVIVOR_DECK,    # ← 标记来源
    size: 1,
    range: Range.NONE,
    skill_ids: [&"fire_helmet_damage_reduce"],
    # ... 其他字段同 ArmorCardData
}
```

> 类型判断用 `card.data.source == CardSource.SURVIVOR_DECK`，不依赖 `is` 检查。

---

## 3. 求生者牌库概念

每个角色有独立的求生者牌库，由该角色的所有求生者卡组成：

```text
CharacterCardData.survivor_deck_card_ids: Array[StringName]
  ↓（游戏开始时 GameSession 实例化）
CardRegistry.get_card_data(card_id) → CardData
  ↓（每份 ID 创建一个 CardInstance）
CardInstance { data = CardData, source = SURVIVOR_DECK, location = DECK }
  ↓（洗混后存入）
Survivor.deck: Array[CardInstance]
```

实例化流程：
1. `GameSession` 读取 `CharacterCardData.survivor_deck_card_ids`
2. 对每个 ID 调 `CardRegistry.get_card_data(id)` 获取 `CardData`
3. 创建 `CardInstance`，设置 `data` / `source = SURVIVOR_DECK` / `location = DECK`
4. 洗混后存入 `Survivor.deck`

---

## 4. 牌库循环规则（D10）

```text
状态流转：
  deck（牌库）→ hand（手牌）→ discard_pile（弃牌堆）
                ↑                         ↓
                └────── 重洗（deck 空时）──┘

规则：
  1. 抓牌时从 deck 顶部抓
  2. deck 空 + 需抓牌 → 玩家被淘汰（任意需抓牌时）
  3. deck 空 + discard_pile 非空 → discard_pile 洗混成为新的 deck
     - 重洗时机：deck 抓空后下次需抓牌时（惰性重洗）
     - 或 deck 抓空时立即重洗（ eager 重洗）
     - 倾向惰性重洗（避免空 deck 时仍可触发"牌库空"相关效果）
  4. 弃牌堆操作（如机械师"神通广大"从弃牌堆抽装备）不依赖 deck 状态
```

> 与拾荒牌库不同（D12：拾荒牌库空无法拾荒，弃牌堆不可重洗），求生者牌库的弃牌堆可重洗。

---

## 5. 求生者卡 vs 拾荒卡对比

| 维度 | 求生者卡 | 拾荒卡 |
|---|---|---|
| `source` | `SURVIVOR_DECK` | `SCAVENGER_DECK` |
| CardData 子类 | `ActionCardData` / `EquipmentCardData` 子类（共用） | 同左（共用） |
| 牌库归属 | `Survivor.deck`（角色个人） | 三色拾荒牌堆（全局共享，见 04-ScavengerCard.md） |
| 弃牌堆 | `Survivor.discard_pile`（角色个人） | 拾荒弃牌堆（全局，按色分） |
| 牌库循环 | deck 空 → 淘汰；discard_pile 可重洗（D10） | 牌堆空 → 无法拾荒；弃牌堆不可重洗（D12） |
| 死亡处理 | 随玩家死亡移出游戏（D8） | 留在死亡地块，可被捡起（D8） |
| 交易限制 | 不可交易 | 可交易（同地块玩家免费交易） |
| 装备卡使用流程 | 先进手牌，使用花 1 行动（D9） | 同左 |

> 字段结构完全一致，所有差异通过 `source` 字段在规则层处理，不在数据层区分。

---

## 6. MVP 5 角色牌库概要

各角色牌库的 `survivor_deck_card_ids` 由原版角色包文件提取（数据录入阶段处理），此处仅列概要：

| character_id | 牌库张数 | 行动卡种类 | 装备卡种类 | 典型装备子类分布 |
|---|---|---|---|---|
| `surgeon` | 31 | 5 种 | 6 种 | 武器 3 / 工具 2 / 载具 1 |
| `mechanic` | 34 | 8 种 | 5 种 | 武器 4 / 防具 1 / 工具 1（含感应地雷） |
| `hunter` | 35 | 5 种 | 8 种 | 武器 5 / 工具 3（含背包/伪装） |
| `firefighter` | 31 | 8 种 | 5 种 | 武器 3 / 防具 2 / 工具 1（含梯子） |
| `cowboy` | 31 | 8 种 | 5 种 | 武器 3 / 防具 2 / 载具 1（含马） |

> 详细卡牌清单见原版角色包文件（`桌游实体/基础版/角色包/*.md`）与 v1 文档 `GameDesignDocs_v1/02-角色系统设计.md` 第 6 节。数据录入阶段将每张卡提取为 `.tres` 文件存放在 `data/cards/survivor/` 目录。

---

## 7. 待定问题

| # | 问题 | 决策/临时方案 |
|---|---|---|
| 1 | 牌库重洗时机（惰性 vs eager） | 倾向惰性重洗（deck 抓空后下次需抓牌时重洗），避免空 deck 时仍可触发"牌库空"相关效果 |
| 2 | 求生者卡的 `.tres` 文件组织（按角色分文件夹 vs 按类型分） | 倾向按角色分（`data/cards/survivor/surgeon/`），便于角色包扩展 |
| 3 | 同一卡牌定义被多角色复用（如"手枪"既在拾荒牌堆又在枪手牌库） | CardRegistry 全局唯一，按 card_id 索引；不同角色牌库的 `survivor_deck_card_ids` 可引用同一 card_id |
| 4 | 牌库洗混算法 | 标准洗混（Fisher-Yates），无需特殊处理 |
| 5 | 弃牌堆操作效果（如机械师"神通广大"从弃牌堆抽装备）的 API | 倾向 `Survivor.draw_from_discard_pile(filter: Callable)` 或类似，待 SkillExecutor 设计时定 |
