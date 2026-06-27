extends Node
#extends RefCounted

# [新增] 2026-06-24: 射程类型枚举（无、短距离、中距离、长距离）
enum RangeType { NONE, SHORT, MEDIUM, LONG }

# [新增] 2026-06-24: 拾荒颜色枚举（红、绿、蓝、无）
enum ScavengeColor { RED, GREEN, BLUE, NONE }

enum ScavengeCardColor { RED, GREEN, BLUE, GRAY, NONE }

# [新增] 2026-06-24: 触发时机枚举（展示、进入、结束、行动）
enum TriggerTime { ON_REVEAL, ON_ENTER, ON_END, ON_ACTION }

# [新增] 2026-06-24: 卡牌类型枚举（即时行动、装备、拾荒）
enum CardType { MAPBLOCK, SCAVENGE , CHARACTER ,CHARACTER_CARD}

# [新增] 2026-06-24: 游戏阶段枚举（怪物出生、抽牌、行动、饥饿、怪物攻击）
enum GamePhase { SPAWN, DRAW, ACTION, HUNGER, MONSTER_ATTACK }

# [新增] 2026-06-24: 游戏状态枚举（进行中、胜利、失败）
enum GameStatus { PLAYING, VICTORY, DEFEAT }

enum ScavengeCardType { ACTION, EQUIPMENT }

enum CharacterCard { ACTION, EQUIPMENT }

enum MonsterRank { NORMAL, ELITE, BOSS }

enum MonsterPack { ALIEN, MUTANT, ROBOT, ZOMBIE }

enum MonsterLevel { NORMAL, ELITE, BOSS }
