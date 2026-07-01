using MaximumApocalypse.Enums;

namespace MaximumApocalypse.Data
{
    // 拾荒卡数据。对应原 ScavengeCardData.gd。
    // 修复 Bug 10：新增 Value 字段（行动牌用，原 .tres 有 14+ 张用了 value=N 但脚本未声明）。
    public class ScavengeCardData
    {
        public string Id { get; set; } = "";
        public string CardName { get; set; } = "";
        public string Category { get; set; } = "";
        public ScavengeCardColor Color { get; set; }
        // 修复 Bug 5/11：card_type 原为中文字符串（"行动牌"/"装备牌"/"物品"），JSON 统一规范化为枚举字符串
        public ScavengeCardType CardType { get; set; }
        public int EquipmentSlot { get; set; }
        public int Value { get; set; }
        public string Effect { get; set; } = "";
        public string EffectScriptId { get; set; } = "";
    }
}
