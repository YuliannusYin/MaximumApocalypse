# Pile 牌堆类

> 职责：通用牌堆结构，提供抓牌、弃牌、洗牌等操作。
> Pile 类**不继承** Entity（无技能、无 trigger），是数据容器。
> 被广泛应用于：怪物牌堆、怪物弃牌堆、三色拾荒牌堆、拾荒弃牌堆、玩家游戏牌堆、玩家游戏牌弃牌堆。

---

## 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 牌列表 | List\<Card\> | 牌堆中的卡牌列表（有序） |

---

## 方法

### draw()

> 从牌堆顶抓取一张牌并返回。

```gdscript
function pile.draw() {
    if (pile.牌列表.isEmpty()) {
        return NULL
    }
    return pile.牌列表.popFirst()  # 从顶部取出
}
```

> 调用方需在使用前检查 `isEmpty()`，或处理好返回 NULL 的情况。

---

### isEmpty()

> 判断牌堆是否为空。

```gdscript
function pile.isEmpty() {
    return pile.牌列表.isEmpty()
}
```

---

### add(card)

> 将一张牌加入牌堆底部。

```gdscript
function pile.add(card) {
    pile.牌列表.addLast(card)
}
```

---

### shuffle()

> 洗牌（随机打乱牌堆顺序）。

```gdscript
function pile.shuffle() {
    pile.牌列表.shuffle()
}
```

---

### shuffleInto(targetPile)

> 将本牌堆的所有牌洗入目标牌堆（本牌堆清空，目标牌堆重洗）。
> 触发场景：怪物牌堆空时重洗怪物弃牌堆（见 [Player.drawMonster](../Entities/Player.md#drawmonster) 节点 2a）。

```gdscript
function pile.shuffleInto(targetPile) {
    for card in pile.牌列表 {
        targetPile.牌列表.add(card)
    }
    pile.牌列表.clear()
    targetPile.shuffle()
}
```

---

### getAll()

> 返回牌堆中所有牌的列表（不移除）。

```gdscript
function pile.getAll() {
    return pile.牌列表.copy()
}
```

---

## 不同牌堆的重洗规则

| 牌堆类型 | 空时处理 |
|---------|---------|
| 怪物牌堆 | 空时重洗怪物弃牌堆组成新牌堆；重洗后仍空 → `game.gameOver("lose")` |
| 拾荒牌堆（红/绿/蓝） | 空时**不**重洗弃牌堆，停止抓取 |
| 玩家游戏牌堆 | 空时**不**重洗弃牌堆；尝试抓牌 → 玩家死亡 |

> 详见 [C_gameSetup.md](../../GameInstructions/C_gameSetup.md)。

---

## 与其他类的关系

| 关系 | 说明 |
|------|------|
| [Game](Game.md) | Game 持有各类全局牌堆（怪物牌堆、拾荒牌堆等） |
| [Player](../Entities/Player.md) | Player 持有游戏牌堆与游戏牌弃牌堆 |
| [Card](../Entities/Card.md) | Pile 存储 Card 实例 |
