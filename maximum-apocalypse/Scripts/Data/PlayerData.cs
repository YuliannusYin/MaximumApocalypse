using Godot;

namespace MaximumApocalypse.Data
{
    // 玩家配置数据。对应原 PlayerData.gd（extends Resource）。
    // 仅含 @export 字段（.tres 中可填）。运行时牌组字段归 PlayerState 管理。
    public class PlayerData
    {
        public string Id { get; set; } = "";
        public string CharacterName { get; set; } = "";
        public int MaxHp { get; set; }
        public int CurrentHp { get; set; }
        public int HungerLevel { get; set; }
        public bool IsStarving { get; set; }
        public int StarvingDamageStage { get; set; }
        public Vector2I Position { get; set; } = Vector2I.Zero;
        public int BaseStealth { get; set; }
        public int StarvingStealth { get; set; }
        public int ActionPoints { get; set; }
        public int PoisonTokens { get; set; }
        public bool IsStunned { get; set; }
    }
}
