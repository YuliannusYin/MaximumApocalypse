using System.Collections.Generic;
using Godot;

namespace MaximumApocalypse.Runtime
{
    /// <summary>
    /// 玩家运行时状态。对应原 PlayerState.gd（extends RefCounted）。
    /// 修复 Bug 6：原 `boolean` 非法类型名 → bool。
    /// </summary>
    public class PlayerState
    {
        public string Id { get; set; } = "";
        public string CharacterName { get; set; } = "";
        public int MaxHp { get; set; }
        public int CurrentHp { get; set; }

        // 饥饿系统：1-5 正常，6+ 饥饿
        public int HungerLevel { get; set; } = 1;
        public bool IsStarving { get; set; } = false;
        public int StarvingDamageStage { get; set; } = 0;

        // 坐标
        public Vector2I Position { get; set; } = Vector2I.Zero;

        // 属性与行动力
        public int BaseStealth { get; set; } = 7;
        public int StarvingStealth { get; set; } = 6;
        public int ActionPoints { get; set; } = 4;

        // 状态效果
        public int PoisonTokens { get; set; } = 0;
        public bool IsStunned { get; set; } = false;

        // 玩家牌组（运行时动态生成）
        public List<CardRuntime> Hand { get; set; } = new();
        public List<CardRuntime> EquipmentZone { get; set; } = new();
        public List<CardRuntime> Deck { get; set; } = new();
        public List<CardRuntime> DiscardPile { get; set; } = new();
    }
}
