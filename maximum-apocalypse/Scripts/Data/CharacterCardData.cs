using MaximumApocalypse.Enums;

namespace MaximumApocalypse.Data
{
    // 角色专属卡数据。对应原 CharacterCardData.gd。
    public class CharacterCardData
    {
        public string Id { get; set; } = "";
        public string CardName { get; set; } = "";
        public string OwnerCharacterId { get; set; } = "";
        public string Description { get; set; } = "";
        public string EffectScriptId { get; set; } = "";
        public CharacterCard CardType { get; set; }
        public int EquipmentCost { get; set; }
        public RangeType RangeType { get; set; }
        public string ActionCondition { get; set; } = "";
    }
}
