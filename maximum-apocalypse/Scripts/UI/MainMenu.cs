using Godot;

namespace MaximumApocalypse
{
    /// <summary>
    /// 主菜单。对应原 menu.gd（extends Control）。
    /// 精美动画菜单，非入口主场景但保留可用。
    /// </summary>
    public partial class MainMenu : Control
    {
        private Button _startButton = null!;
        private Button _exitButton = null!;
        private Label _titleLabel = null!;
        private TextureRect _ruinsIcon = null!;
        private TextureRect _zombieIcon = null!;
        private TextureRect _survivorIcon = null!;

        public override void _Ready()
        {
            _startButton = GetNode<Button>("MainContainer/ButtonContainer/StartButtonContainer/StartButton");
            _exitButton = GetNode<Button>("MainContainer/ButtonContainer/ExitButtonContainer/ExitButton");
            _titleLabel = GetNode<Label>("MainContainer/Title");
            _ruinsIcon = GetNode<TextureRect>("Decorations/RuinsIcon");
            _zombieIcon = GetNode<TextureRect>("Decorations/ZombieIcon");
            _survivorIcon = GetNode<TextureRect>("Decorations/SurvivorIcon");

            _startButton.Pressed += OnStartButtonPressed;
            _exitButton.Pressed += OnExitButtonPressed;

            PlayTitleAnimation();
            PlayDecorationAnimations();
        }

        private void PlayTitleAnimation()
        {
            // 初始状态：透明且向上偏移
            _titleLabel.Modulate = new Color(_titleLabel.Modulate, 0.0f);
            _titleLabel.Position = new Vector2(_titleLabel.Position.X, _titleLabel.Position.Y - 30);

            var tween = CreateTween();
            tween.SetParallel(true);
            tween.TweenProperty(_titleLabel, "modulate:a", 1.0f, 0.8)
                .SetEase(Tween.EaseType.Out).SetTrans(Tween.TransitionType.Cubic);
            tween.TweenProperty(_titleLabel, "position:y", _titleLabel.Position.Y + 30, 0.8)
                .SetEase(Tween.EaseType.Out).SetTrans(Tween.TransitionType.Cubic);
        }

        private void PlayDecorationAnimations()
        {
            // 废墟图标：缓慢飘动
            var ruinsTween = CreateTween();
            ruinsTween.SetLoops();
            ruinsTween.TweenProperty(_ruinsIcon, "position:y", _ruinsIcon.Position.Y + 10, 2.0)
                .SetEase(Tween.EaseType.InOut);
            ruinsTween.TweenProperty(_ruinsIcon, "position:y", _ruinsIcon.Position.Y - 10, 2.0)
                .SetEase(Tween.EaseType.InOut);

            // 僵尸图标：缓慢移动
            var zombieTween = CreateTween();
            zombieTween.SetLoops();
            zombieTween.TweenProperty(_zombieIcon, "position:x", _zombieIcon.Position.X + 5, 3.0)
                .SetEase(Tween.EaseType.InOut);
            zombieTween.TweenProperty(_zombieIcon, "position:x", _zombieIcon.Position.X - 5, 3.0)
                .SetEase(Tween.EaseType.InOut);

            // 求生者图标：轻微旋转
            var survivorTween = CreateTween();
            survivorTween.SetLoops();
            survivorTween.TweenProperty(_survivorIcon, "rotation", 0.05f, 4.0)
                .SetEase(Tween.EaseType.InOut);
            survivorTween.TweenProperty(_survivorIcon, "rotation", -0.05f, 4.0)
                .SetEase(Tween.EaseType.InOut);
        }

        private void OnStartButtonPressed()
        {
            // 补全：原 .gd 仅 print，此处切换到游戏场景
            GetTree().ChangeSceneToFile("res://game.tscn");
        }

        private void OnExitButtonPressed()
        {
            GetTree().Quit();
        }
    }
}
