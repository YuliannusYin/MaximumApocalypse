namespace MaximumApocalypse.Runtime
{
    /// <summary>
    /// 卡牌运行时实例。对应原 CardRuntime.gd（extends RefCounted）。
    /// 纯 C# 类，无 Godot 依赖。
    /// </summary>
    public class CardRuntime
    {
        public string InstanceId { get; set; } = "";
        public string TemplateId { get; set; } = "";
        public int CurrentAmmo { get; set; }

        public CardRuntime(string instanceId, string templateId, int ammo = 0)
        {
            InstanceId = instanceId;
            TemplateId = templateId;
            CurrentAmmo = ammo;
        }

        // 供 JSON 反序列化使用
        public CardRuntime() { }
    }
}
