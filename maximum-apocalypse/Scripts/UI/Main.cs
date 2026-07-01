using Godot;

namespace MaximumApocalypse
{
    /// <summary>
    /// 旧主场景脚本。对应原 main.gd（extends Node2D）。
    /// 入口主场景 main.tscn 挂载本脚本。
    /// </summary>
    public partial class Main : Node2D
    {
        // 由 main.tscn 的 [connection] button_down 信号触发
        public void OnStartButtonButtonDown()
        {
            GetTree().ChangeSceneToFile("res://game.tscn");
        }

        public void OnQuitButtonButtonDown()
        {
            GetTree().Quit();
        }
    }
}
