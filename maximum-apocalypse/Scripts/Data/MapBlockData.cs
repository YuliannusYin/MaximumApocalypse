using System.Collections.Generic;
using MaximumApocalypse.Enums;

namespace MaximumApocalypse.Data
{
    // 地块数据。对应原 MapBlockData.gd（extends Resource）。
    public class MapBlockData
    {
        public string Id { get; set; } = "";
        public string TileName { get; set; } = "";
        public int SpawnValues { get; set; }
        public ScavengeColor ScavengeType { get; set; } = ScavengeColor.NONE;
        public List<TriggerTime> EffectTrigger { get; set; } = new();
        public List<string> EffectScriptId { get; set; } = new();
        public string Description { get; set; } = "";
        public int MonsterMark { get; set; }
    }
}
