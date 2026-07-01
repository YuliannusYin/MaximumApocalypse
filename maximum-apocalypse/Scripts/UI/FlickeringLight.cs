using Godot;

namespace MaximumApocalypse
{
    /// <summary>
    /// 警示灯闪烁。对应原 ui/flickering_light.gd（extends PointLight2D）。
    /// </summary>
    public partial class FlickeringLight : PointLight2D
    {
        [Export] public float FlickerFrequency { get; set; } = 2.0f;
        [Export] public float FlickerMin { get; set; } = 0.5f;
        [Export] public float FlickerMax { get; set; } = 1.5f;
        [Export] public float ColorVariation { get; set; } = 0.1f;

        private float _baseEnergy;
        private Color _baseColor;
        private Tween? _tween;

        public override void _Ready()
        {
            _baseEnergy = Energy;
            _baseColor = Color;
            CallDeferred(nameof(StartFlickering));
        }

        private async void StartFlickering()
        {
            while (true)
            {
                _tween?.Kill();
                _tween = CreateTween();

                float duration = (float)GD.RandRange(0.1, 0.5);
                float targetEnergy = (float)GD.RandRange(FlickerMin, FlickerMax) * _baseEnergy;
                _tween.TweenProperty(this, "energy", targetEnergy, duration)
                    .SetEase(Tween.EaseType.InOut);

                var colorOffset = new Color(
                    (float)GD.RandRange(-ColorVariation, ColorVariation),
                    (float)GD.RandRange(-ColorVariation, ColorVariation),
                    (float)GD.RandRange(-ColorVariation, ColorVariation),
                    0.0f);
                _tween.Parallel().TweenProperty(this, "color", _baseColor + colorOffset, duration)
                    .SetEase(Tween.EaseType.InOut);

                // 等待本段动画时长
                await ToSignal(GetTree().CreateTimer(duration), SceneTreeTimer.SignalName.Timeout);
                await ToSignal(GetTree().CreateTimer((float)GD.RandRange(0.05, 0.2)),
                    SceneTreeTimer.SignalName.Timeout);
            }
        }
    }
}
