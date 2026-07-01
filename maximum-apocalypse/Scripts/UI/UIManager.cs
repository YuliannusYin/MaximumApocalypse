using Godot;
using MaximumApocalypse.Runtime;

namespace MaximumApocalypse
{
    /// <summary>
    /// UI 表现层接口。对应原 UIManager.gd（extends CanvasLayer）。
    /// 方法体留空（对齐原 .gd 的 pass），仅提供方法签名与信号供 RuleEngine 调用。
    /// </summary>
    public partial class UIManager : CanvasLayer
    {
        // 表现层完成信号
        [Signal] public delegate void DiceAnimationFinishedEventHandler();
        [Signal] public delegate void DrawCardAnimFinishedEventHandler();
        [Signal] public delegate void FlipAnimFinishedEventHandler();
        [Signal] public delegate void MonsterAttackAnimFinishedEventHandler();

        public void PlayDiceAnimation(int d1, int d2) { }
        public void PlayDrawCardAnim(string playerId, CardRuntime card) { }
        public void EnablePlayerControls(string playerId) { }
        public void DisablePlayerControls() { }
        public void ShowCharacterFlipAnim(string playerId) { }
        public void ShowDamageFloatingText(string playerId, int damage, string reason) { }
        public void PlayMonsterAttackAnim(string monsterId, string playerId) { }
        public void ShowVictoryScreen() { }
        public void ShowDefeatScreen() { }
    }
}
