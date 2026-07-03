# source攻击target的方法
function target.damage(num, source, type){ # target受到来自于source的num点类型为type的伤害
    # 1. source攻击target前
    # 2. target受到伤害前
    # 3. source攻击target时
    # 4. target受到伤害时
    target.生命值 -= num
    # 5. source攻击target后
    # 6. target受到伤害后
}
