using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using MaximumApocalypse.Data;
using MaximumApocalypse.Enums;
using MaximumApocalypse.Runtime;

namespace MaximumApocalypse
{
    /// <summary>
    /// 规则引擎。对应原 RuleEngine.gd（extends Node）。
    /// Bug 2：原 5 处 rule_engine.xxx 自引用 → 直接 this 调用。
    /// Bug 9：7 个未定义方法以抛 NotImplementedException 的 stub 形式落地。
    /// spawn_values 原用 `X in spawn_values`（int 上 `in` 非法）→ 改为 `X == SpawnValues`。
    /// </summary>
    public partial class RuleEngine : Node
    {
        // 由 GameLoopManager._Ready 注入（替代原 @onready var map_board = $MapBoard）
        public MapBoard? MapBoard { get; set; }
        public UIManager? UIManager { get; set; }

        // 内部异步信号催化剂（替代原 signal action_phase_finished）
        [Signal] public delegate void ActionPhaseFinishedEventHandler();

        /// <summary>执行怪物出生逻辑。</summary>
        public void ExecuteMonsterSpawn(int dice1, int dice2)
        {
            int x = dice1 + dice2;
            var state = GameState.Instance;

            foreach (var kv in state.MapGrid)
            {
                var pos = kv.Key;
                var tile = kv.Value;
                var tileData = tile.Data;
                if (tileData == null) continue;

                // Bug 修复：原 `X in tile_data.spawn_values`（int 上 in 非法）改为相等比较
                if (tile.IsRevealed && x == tileData.SpawnValues)
                {
                    if (tile.MonsterTokens < 3)
                    {
                        // 配件流失校验
                        if (state.AvailableMonsterTokens <= 0)
                        {
                            state.GameStatus = GameStatus.DEFEAT;
                            state.EmitSignal(GameState.SignalName.GameOver, Variant.From(state.GameStatus));
                            return;
                        }
                        tile.MonsterTokens += 1;
                        state.AvailableMonsterTokens -= 1;
                    }
                    else
                    {
                        // 标记满了，该地块所有玩家抓一张怪物卡
                        var playersOnTile = GetPlayersAtPosition(pos);
                        foreach (var player in playersOnTile)
                        {
                            DrawMonsterCardToPlayer(player.Id);
                        }
                    }
                }
            }
        }

        /// <summary>移动玩家到目标位置。</summary>
        public void MovePlayer(string playerId, Vector2I targetPos)
        {
            var state = GameState.Instance;
            if (!state.Players.TryGetValue(playerId, out var player)) return;
            if (!state.MapGrid.TryGetValue(targetPos, out var tile)) return;

            // 1. 扣除行动点
            player.ActionPoints -= 1;
            player.Position = targetPos;

            // 2. 翻开迷雾
            if (!tile.IsRevealed)
            {
                tile.IsRevealed = true;
                state.EmitSignal(GameState.SignalName.TileRevealed, targetPos);
                TriggerTileEffect(targetPos, TriggerTime.ON_REVEAL, playerId);
            }
            TriggerTileEffect(targetPos, TriggerTime.ON_ENTER, playerId);

            // 3. 潜行检定
            if (tile.MonsterTokens > 0 && !HasEngagedMonsters(playerId))
            {
                int baseStealth = player.IsStarving ? player.StarvingStealth : player.BaseStealth;
                int finalStealth = baseStealth - tile.MonsterTokens;

                int roll = (int)GD.RandRange(1, 6) + (int)GD.RandRange(1, 6);
                if (roll > finalStealth)
                {
                    int count = tile.MonsterTokens;
                    tile.MonsterTokens = 0;
                    state.AvailableMonsterTokens += count; // 退回标记

                    for (int i = 0; i < count; i++)
                    {
                        DrawMonsterCardToPlayer(playerId);
                    }
                }
            }
        }

        /// <summary>处理怪物出生阶段。</summary>
        public async Task ProcessSpawnPhase()
        {
            int d1 = (int)GD.RandRange(1, 6);
            int d2 = (int)GD.RandRange(1, 6);

            UIManager?.PlayDiceAnimation(d1, d2);
            if (UIManager != null)
            {
                await ToSignal(UIManager, UIManager.SignalName.DiceAnimationFinished);
            }

            ExecuteMonsterSpawn(d1, d2);

            await ToSignal(GetTree().CreateTimer(0.5f), SceneTreeTimer.SignalName.Timeout);
        }

        /// <summary>处理抽牌阶段。</summary>
        public async Task ProcessDrawPhase(string playerId)
        {
            var state = GameState.Instance;
            if (!state.Players.TryGetValue(playerId, out var player)) return;

            if (player.Deck.Count == 0)
            {
                KillPlayer(playerId);
                return;
            }

            var drawnCard = player.Deck[0];
            player.Deck.RemoveAt(0);
            player.Hand.Add(drawnCard);

            UIManager?.PlayDrawCardAnim(playerId, drawnCard);
            if (UIManager != null)
            {
                await ToSignal(UIManager, UIManager.SignalName.DrawCardAnimFinished);
            }
        }

        /// <summary>处理行动阶段。</summary>
        public async Task ProcessActionPhase(string playerId)
        {
            var state = GameState.Instance;
            if (!state.Players.TryGetValue(playerId, out var player)) return;

            player.ActionPoints = 4;
            UIManager?.EnablePlayerControls(playerId);

            // 核心挂起：直到玩家用完行动点或点击“结束回合”触发 ActionPhaseFinished
            await ToSignal(this, SignalName.ActionPhaseFinished);

            UIManager?.DisablePlayerControls();
        }

        /// <summary>处理饥饿阶段。</summary>
        public async Task ProcessHungerPhase(string playerId)
        {
            var state = GameState.Instance;
            if (!state.Players.TryGetValue(playerId, out var player)) return;

            player.HungerLevel += 1;

            if (player.HungerLevel >= 6)
            {
                if (!player.IsStarving)
                {
                    player.IsStarving = true;
                    player.StarvingDamageStage = 1;
                    UIManager?.ShowCharacterFlipAnim(playerId);
                    if (UIManager != null)
                    {
                        await ToSignal(UIManager, UIManager.SignalName.FlipAnimFinished);
                    }
                }

                int dmg = player.StarvingDamageStage * 2;
                ApplyDamageToPlayer(playerId, dmg, true);

                player.StarvingDamageStage += 1;

                UIManager?.ShowDamageFloatingText(playerId, dmg, "饥饿!");
                await ToSignal(GetTree().CreateTimer(0.8f), SceneTreeTimer.SignalName.Timeout);
            }
        }

        /// <summary>处理怪物攻击阶段。</summary>
        public async Task ProcessMonsterAttackPhase(string playerId)
        {
            var monsters = GetMonstersEngagedWith(playerId);

            foreach (var monster in monsters)
            {
                ApplyDamageToPlayer(playerId, monster.Damage, false);

                UIManager?.PlayMonsterAttackAnim(monster.Id, playerId);
                if (UIManager != null)
                {
                    await ToSignal(UIManager, UIManager.SignalName.MonsterAttackAnimFinished);
                }

                if (IsGameOver()) return;
            }
        }

        /// <summary>顺时针轮转玩家。</summary>
        public void SwitchToNextPlayer()
        {
            var state = GameState.Instance;
            var keys = state.Players.Keys.ToList();
            if (keys.Count == 0) return;

            int currentIndex = keys.IndexOf(state.ActivePlayerId);
            int nextIndex = (currentIndex + 1) % keys.Count;
            state.ActivePlayerId = keys[nextIndex];

            if (nextIndex == 0)
            {
                state.CurrentTurn += 1;
            }
        }

        /// <summary>判定游戏是否结束。</summary>
        public bool IsGameOver()
        {
            return GameState.Instance.GameStatus != GameStatus.PLAYING;
        }

        /// <summary>处理输赢结局。</summary>
        public void HandleGameOver()
        {
            var status = GameState.Instance.GameStatus;
            if (status == GameStatus.VICTORY)
            {
                UIManager?.ShowVictoryScreen();
            }
            else if (status == GameStatus.DEFEAT)
            {
                UIManager?.ShowDefeatScreen();
            }
        }

        /// <summary>UI“结束回合”按钮点击时调用。</summary>
        public void OnUiEndTurnButtonPressed()
        {
            EmitSignal(SignalName.ActionPhaseFinished);
        }

        // --- Bug 9：7 个未实现方法的 stub，保证编译通过并标记后续实现 ---

        public List<PlayerState> GetPlayersAtPosition(Vector2I pos)
            => throw new NotImplementedException($"GetPlayersAtPosition({pos}) 未实现");

        public void DrawMonsterCardToPlayer(string playerId)
            => throw new NotImplementedException($"DrawMonsterCardToPlayer({playerId}) 未实现");

        public void TriggerTileEffect(Vector2I pos, TriggerTime time, string playerId)
            => throw new NotImplementedException(
                $"TriggerTileEffect({pos}, {time}, {playerId}) 未实现");

        public bool HasEngagedMonsters(string playerId)
            => throw new NotImplementedException($"HasEngagedMonsters({playerId}) 未实现");

        public List<MonsterData> GetMonstersEngagedWith(string playerId)
            => throw new NotImplementedException($"GetMonstersEngagedWith({playerId}) 未实现");

        public void ApplyDamageToPlayer(string playerId, int damage, bool unavoidable)
            => throw new NotImplementedException(
                $"ApplyDamageToPlayer({playerId}, {damage}, {unavoidable}) 未实现");

        public void KillPlayer(string playerId)
            => throw new NotImplementedException($"KillPlayer({playerId}) 未实现");
    }
}
