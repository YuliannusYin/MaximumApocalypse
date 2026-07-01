using Godot;
using MaximumApocalypse.Data;
using MaximumApocalypse.Runtime;

namespace MaximumApocalypse
{
    /// <summary>
    /// 动态地块视图。对应原 TileViewPrototype.gd（extends Node2D）。
    /// 由 MapBoard 在运行时动态创建并调用 Setup。
    /// </summary>
    public partial class TileView : Node2D
    {
        private ColorRect _bgRect = null!;
        private ColorRect _borderRect = null!;
        private Label _nameLabel = null!;
        private Label _infoLabel = null!;

        private Vector2I _gridCoord;
        private TileRuntimeState _state = null!;

        /// <summary>
        /// 初始化入口：由 MapBoard 在动态生成节点后直接调用。
        /// </summary>
        public void Setup(Vector2I pos, TileRuntimeState runtimeData, Vector2 size)
        {
            _gridCoord = pos;
            _state = runtimeData;
            var template = runtimeData.Data;

            // 1. 底色方框
            _bgRect = new ColorRect { Size = size };
            _bgRect.Color = (template != null && template.Id.Contains("van"))
                ? new Color(0.15f, 0.45f, 0.25f)
                : new Color(0.2f, 0.2f, 0.25f);
            AddChild(_bgRect);

            // 2. 1 像素内边框
            _borderRect = new ColorRect
            {
                Size = size - new Vector2(2, 2),
                Position = new Vector2(1, 1),
            };
            _borderRect.Color = _bgRect.Color.Lightened(0.1f);
            AddChild(_borderRect);

            // 3. 地块名字
            _nameLabel = new Label
            {
                Position = new Vector2(8, 8),
                Text = template?.TileName ?? "",
            };
            _nameLabel.AddThemeColorOverride("font_color", Colors.White);
            _nameLabel.AddThemeFontSizeOverride("font_size", 16);
            AddChild(_nameLabel);

            // 4. 状态信息文本
            _infoLabel = new Label { Position = new Vector2(8, 40) };
            _infoLabel.AddThemeColorOverride("font_color", new Color(0.7f, 0.7f, 0.7f));
            _infoLabel.AddThemeFontSizeOverride("font_size", 11);
            AddChild(_infoLabel);

            RefreshInfoText();

            // 迷雾遮罩层与点击触发区在原 .gd 中已被注释禁用，C# 同样不启用。
        }

        /// <summary>
        /// 动态刷新地块内的数据文本提示。
        /// </summary>
        private void RefreshInfoText()
        {
            if (_state?.Data == null) return;

            var t = _state.Data;
            string scavColorStr = t.ScavengeType.ToString();

            string txt = $"ID: {t.Id}\n爆怪骰子: {t.SpawnValues}\n拾荒牌堆: {scavColorStr}";
            if (_state.MonsterTokens > 0)
            {
                txt += $"\n[ 🔴 怪物数量: {_state.MonsterTokens} ]";
            }
            _infoLabel.Text = txt;
        }

        /// <summary>
        /// 【外部更新接口】当外部修改了怪物数量，调用此函数刷新方框文字。
        /// </summary>
        public void UpdateMonsterDisplay(int newCount)
        {
            _state.MonsterTokens = newCount;
            RefreshInfoText();
        }

        public void UpdateFogState()
        {
            // 迷雾层未启用，留空。
        }
    }
}
