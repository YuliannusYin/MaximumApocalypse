using Godot;

namespace MaximumApocalypse
{
    /// <summary>
    /// 自定义菜单按钮。对应原 ui/menu_button.gd（extends Button）。
    /// 实现悬停、点击和出现动画效果。
    /// </summary>
    public partial class MenuButton : Button
    {
        [Export] public string ButtonText { get; set; } = "按钮";
        [Export] public float AppearDelay { get; set; } = 0.0f;

        private ShaderMaterial? _shaderMaterial;
        private Tween? _appearTween;
        private Tween? _hoverTween;
        private Tween? _clickTween;

        public override async void _Ready()
        {
            Text = ButtonText;

            if (Material is ShaderMaterial sm)
            {
                _shaderMaterial = sm;
                _shaderMaterial.SetShaderParameter("hover_intensity", 0.0f);
                _shaderMaterial.SetShaderParameter("click_intensity", 0.0f);
            }

            // 初始状态：透明且缩小
            Modulate = new Color(Modulate, 0.0f);
            Scale = new Vector2(0.8f, 0.8f);

            ButtonDown += OnButtonDown;
            ButtonUp += OnButtonUp;
            MouseEntered += OnMouseEntered;
            MouseExited += OnMouseExited;

            if (AppearDelay > 0.0f)
            {
                await ToSignal(GetTree().CreateTimer(AppearDelay), SceneTreeTimer.SignalName.Timeout);
            }
            PlayAppearAnimation();
        }

        private void PlayAppearAnimation()
        {
            _appearTween?.Kill();
            _appearTween = CreateTween();
            _appearTween.SetParallel(true);
            _appearTween.TweenProperty(this, "modulate:a", 1.0f, 0.6)
                .SetEase(Tween.EaseType.Out).SetTrans(Tween.TransitionType.Cubic);
            _appearTween.TweenProperty(this, "scale", Vector2.One, 0.6)
                .SetEase(Tween.EaseType.Out).SetTrans(Tween.TransitionType.Elastic);
        }

        private void OnMouseEntered()
        {
            if (_shaderMaterial == null) return;
            _hoverTween?.Kill();
            _hoverTween = CreateTween();
            _hoverTween.TweenMethod(
                Callable.From<float>(SetHoverIntensity),
                0.0f, 1.0f, 0.2);
        }

        private void OnMouseExited()
        {
            if (_shaderMaterial == null) return;
            _hoverTween?.Kill();
            float current = (float)_shaderMaterial.GetShaderParameter("hover_intensity").AsSingle();
            _hoverTween = CreateTween();
            _hoverTween.TweenMethod(
                Callable.From<float>(SetHoverIntensity),
                current, 0.0f, 0.2);
        }

        private void OnButtonDown()
        {
            if (_shaderMaterial == null) return;
            _clickTween?.Kill();
            _clickTween = CreateTween();
            _clickTween.TweenMethod(
                Callable.From<float>(SetClickIntensity),
                0.0f, 1.0f, 0.1);
        }

        private void OnButtonUp()
        {
            if (_shaderMaterial == null) return;
            _clickTween?.Kill();
            float current = (float)_shaderMaterial.GetShaderParameter("click_intensity").AsSingle();
            _clickTween = CreateTween();
            _clickTween.TweenMethod(
                Callable.From<float>(SetClickIntensity),
                current, 0.0f, 0.15);
        }

        private void SetHoverIntensity(float value)
        {
            _shaderMaterial?.SetShaderParameter("hover_intensity", value);
        }

        private void SetClickIntensity(float value)
        {
            _shaderMaterial?.SetShaderParameter("click_intensity", value);
        }
    }
}
