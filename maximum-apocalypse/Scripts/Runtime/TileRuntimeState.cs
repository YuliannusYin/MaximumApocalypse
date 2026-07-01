using System.Collections.Generic;
using MaximumApocalypse.Data;

namespace MaximumApocalypse.Runtime
{
    /// <summary>
    /// 地块运行时状态。替代原 MapBoard.gd 中 map_grid[pos] 的内联 Dictionary，
    /// 提供强类型字段，避免 Variant 装箱。
    /// </summary>
    public class TileRuntimeState
    {
        public string TemplateId { get; set; } = "";
        public MapBlockData? Data { get; set; }
        public bool IsRevealed { get; set; }
        public int MonsterTokens { get; set; }
        public List<CardRuntime> DroppedCards { get; set; } = new();
    }
}
