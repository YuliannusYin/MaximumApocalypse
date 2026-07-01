using System.Collections.Generic;

namespace MaximumApocalypse.Data
{
    // 任务剧本数据。对应原 MissionData.gd。
    public class MissionData
    {
        public string Id { get; set; } = "";
        public string MissionName { get; set; } = "";
        // 原 @export_enum 实际为字符串，保留 string 类型
        public string Difficulty { get; set; } = "";
        public string Description { get; set; } = "";
        public string ObjectiveText { get; set; } = "";
        public int RequiredVanFuel { get; set; }
        public string StartingTileId { get; set; } = "";
        public string InitialSetupRule { get; set; } = "";
        public Dictionary<string, int> TileManifest { get; set; } = new();
        public Dictionary<string, int> RedScavengePool { get; set; } = new();
        public Dictionary<string, int> GreenScavengePool { get; set; } = new();
        public Dictionary<string, int> BlueScavengePool { get; set; } = new();
        public string SpecialMapRequirements { get; set; } = "";
    }
}
