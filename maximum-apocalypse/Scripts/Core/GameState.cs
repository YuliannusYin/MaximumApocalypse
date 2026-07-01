using System.Collections.Generic;
using Godot;
using MaximumApocalypse.Data;
using MaximumApocalypse.Enums;
using MaximumApocalypse.Runtime;

namespace MaximumApocalypse
{
    /// <summary>
    /// 全局游戏状态单例。对应原 GameState.gd（被全局当单例用但未注册 autoload）。
    /// 修复 Bug 4：在 project.godot 注册为 autoload：GameState="*res://Scripts/Core/GameState.cs"
    /// </summary>
    public partial class GameState : Node
    {
        public static GameState Instance { get; private set; } = null!;

        // 游戏基础状态
        public int CurrentTurn { get; set; } = 1;
        public string ActivePlayerId { get; set; } = "";
        public GamePhase CurrentPhase { get; set; } = GamePhase.SPAWN;
        public GameStatus GameStatus { get; set; } = GameStatus.PLAYING;

        // 配件流失检查 - 可用怪物标记数量
        public int AvailableMonsterTokens { get; set; } = 30;

        // 共有牌堆
        public List<string> MonsterDeck { get; set; } = new();
        public List<string> MonsterDiscardPile { get; set; } = new();

        // 拾荒牌库（按颜色分类）
        public Dictionary<ScavengeColor, List<string>> ScavengeDecks { get; set; } = new()
        {
            [ScavengeColor.RED] = new List<string>(),
            [ScavengeColor.GREEN] = new List<string>(),
            [ScavengeColor.BLUE] = new List<string>(),
        };

        public List<string> ScavengeDiscardPile { get; set; } = new();

        // 地图网格：Key=Vector2I，Value=地块运行时状态
        public Dictionary<Vector2I, TileRuntimeState> MapGrid { get; set; } = new();

        // 所有玩家状态
        public Dictionary<string, PlayerState> Players { get; set; } = new();

        // 任务目标进度
        public int RequiredFuel { get; set; } = 4;
        public int CurrentFuelInVan { get; set; } = 0;

        // 信号（解耦数据与 UI 表现层）
        [Signal] public delegate void PhaseChangedEventHandler(GamePhase newPhase);
        [Signal] public delegate void PlayerHpChangedEventHandler(string playerId, int newHp);
        [Signal] public delegate void TileRevealedEventHandler(Vector2I pos);
        [Signal] public delegate void GameOverEventHandler(GameStatus status);

        public override void _Ready()
        {
            Instance = this;
            DataLoader.LoadAll();
        }
    }
}
