using System.Linq;
using System.Threading.Tasks;
using Godot;
using MaximumApocalypse.Enums;

namespace MaximumApocalypse
{
    /// <summary>
    /// 游戏主循环驱动。对应原 GameLoopManager.gd（extends Node）。
    /// _Ready 取子节点 RuleEngine/MapBoard/UIManager，注入到 RuleEngine，延迟启动主循环。
    /// </summary>
    public partial class GameLoopManager : Node
    {
        private RuleEngine _ruleEngine = null!;
        private MapBoard _mapBoard = null!;
        private UIManager _uiManager = null!;

        public override void _Ready()
        {
            _ruleEngine = GetNode<RuleEngine>("RuleEngine");
            _mapBoard = GetNode<MapBoard>("MapBoard");
            _uiManager = GetNode<UIManager>("UIManager");

            _ruleEngine.MapBoard = _mapBoard;
            _ruleEngine.UIManager = _uiManager;

            CallDeferred(nameof(StartGame));
        }

        private async void StartGame()
        {
            GD.Print("游戏开始，初始化数据...");
            var state = GameState.Instance;
            state.CurrentTurn = 1;

            // 玩家初始化在原 .gd 中为 TODO；无玩家时避免崩溃，直接退出循环。
            if (state.Players.Count == 0)
            {
                GD.PushError("[GameLoopManager] 无玩家数据，无法开始游戏循环（玩家初始化尚未实现）");
                return;
            }
            state.ActivePlayerId = state.Players.Keys.First();

            while (state.GameStatus == GameStatus.PLAYING)
            {
                await RunPlayerTurn(state.ActivePlayerId);
                _ruleEngine.SwitchToNextPlayer();
            }

            _ruleEngine.HandleGameOver();
        }

        private async Task RunPlayerTurn(string playerId)
        {
            GD.Print($"--- 玩家 {playerId} 的回合开始 ---");
            var state = GameState.Instance;

            // 阶段 1: 怪物出生
            state.CurrentPhase = GamePhase.SPAWN;
            state.EmitSignal(GameState.SignalName.PhaseChanged, Variant.From(state.CurrentPhase));
            await _ruleEngine.ProcessSpawnPhase();
            if (_ruleEngine.IsGameOver()) return;

            // 阶段 2: 玩家抽牌
            state.CurrentPhase = GamePhase.DRAW;
            state.EmitSignal(GameState.SignalName.PhaseChanged, Variant.From(state.CurrentPhase));
            await _ruleEngine.ProcessDrawPhase(playerId);
            if (_ruleEngine.IsGameOver()) return;

            // 阶段 3: 执行行动
            state.CurrentPhase = GamePhase.ACTION;
            state.EmitSignal(GameState.SignalName.PhaseChanged, Variant.From(state.CurrentPhase));
            await _ruleEngine.ProcessActionPhase(playerId);
            if (_ruleEngine.IsGameOver()) return;

            // 阶段 4: 增加饥饿值与结算伤害
            state.CurrentPhase = GamePhase.HUNGER;
            state.EmitSignal(GameState.SignalName.PhaseChanged, Variant.From(state.CurrentPhase));
            await _ruleEngine.ProcessHungerPhase(playerId);
            if (_ruleEngine.IsGameOver()) return;

            // 阶段 5: 怪物攻击
            state.CurrentPhase = GamePhase.MONSTER_ATTACK;
            state.EmitSignal(GameState.SignalName.PhaseChanged, Variant.From(state.CurrentPhase));
            await _ruleEngine.ProcessMonsterAttackPhase(playerId);

            GD.Print($"--- 玩家 {playerId} 的回合结束 ---");
        }
    }
}
