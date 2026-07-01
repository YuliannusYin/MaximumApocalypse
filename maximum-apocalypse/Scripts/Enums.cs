// 所有全局枚举。原 enums.gd（autoload Node）改为命名空间下的 enum。
// 整数序与原 GDScript 枚举声明顺序保持一致，确保 .tres 中存的 int 值含义不变。
namespace MaximumApocalypse.Enums
{
    // 射程类型（无、短距离、中距离、长距离）
    public enum RangeType
    {
        NONE = 0,
        SHORT = 1,
        MEDIUM = 2,
        LONG = 3,
    }

    // 拾荒颜色枚举（用于 MapBlockData.scavenge_type：红/绿/蓝/无）
    public enum ScavengeColor
    {
        RED = 0,
        GREEN = 1,
        BLUE = 2,
        NONE = 3,
    }

    // 拾荒卡颜色枚举（用于 ScavengeCardData.color：红/绿/蓝/灰/无）
    public enum ScavengeCardColor
    {
        RED = 0,
        GREEN = 1,
        BLUE = 2,
        GRAY = 3,
        NONE = 4,
    }

    // 触发时机枚举（展示、进入、结束、行动）
    public enum TriggerTime
    {
        ON_REVEAL = 0,
        ON_ENTER = 1,
        ON_END = 2,
        ON_ACTION = 3,
    }

    // 卡牌类型枚举
    public enum CardType
    {
        MAPBLOCK = 0,
        SCAVENGE = 1,
        CHARACTER = 2,
        CHARACTER_CARD = 3,
    }

    // 游戏阶段枚举
    public enum GamePhase
    {
        SPAWN = 0,
        DRAW = 1,
        ACTION = 2,
        HUNGER = 3,
        MONSTER_ATTACK = 4,
    }

    // 游戏状态枚举
    public enum GameStatus
    {
        PLAYING = 0,
        VICTORY = 1,
        DEFEAT = 2,
    }

    // 拾荒卡类型：新增 ITEM=2 以表达 .tres 中的 "物品"（Bug 5/11 修复）
    public enum ScavengeCardType
    {
        ACTION = 0,
        EQUIPMENT = 1,
        ITEM = 2,
    }

    // 角色卡类型
    public enum CharacterCard
    {
        ACTION = 0,
        EQUIPMENT = 1,
    }

    // 怪物等级（普通、精英、首领）
    public enum MonsterRank
    {
        NORMAL = 0,
        ELITE = 1,
        BOSS = 2,
    }

    // 怪物所属卡包
    public enum MonsterPack
    {
        ALIEN = 0,
        MUTANT = 1,
        ROBOT = 2,
        ZOMBIE = 3,
    }

    // 怪物等级（与 MonsterRank 含义重叠，保留以对应原 .tres 的 rank 字段）
    public enum MonsterLevel
    {
        NORMAL = 0,
        ELITE = 1,
        BOSS = 2,
    }
}
