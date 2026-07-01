using MaximumApocalypse.Enums;

namespace MaximumApocalypse.Data
{
    // 怪物数据。对应原 MonsterData.gd。
    public class MonsterData
    {
        public string Id { get; set; } = "";
        public string MonsterName { get; set; } = "";
        public MonsterPack Pack { get; set; }
        public MonsterLevel Rank { get; set; }
        public int MaxHp { get; set; }
        public int CurrentHp { get; set; }
        public int Damage { get; set; }
        public RangeType RangeType { get; set; }
        public string Description { get; set; } = "";
        // 原 .tres 字段 Grab_trigger_id / Passive_id / Destroy_id（首字母大写），
        // JSON 序列化策略输出为 snake_case：grab_trigger_id 等。
        public string GrabTriggerId { get; set; } = "";
        public string PassiveId { get; set; } = "";
        public string DestroyId { get; set; } = "";
    }
}
