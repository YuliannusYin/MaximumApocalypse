using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using Godot;

namespace MaximumApocalypse.Data
{
    /// <summary>
    /// 数据加载器：启动时扫描 Data/ 目录下的 JSON 反序列化到内存缓存。
    /// 替代原 MapBoard.gd 中 _load_tile_resources_from_folder / ResourceLoader.load 的 .tres 加载方式。
    /// </summary>
    public static class DataLoader
    {
        private static readonly Dictionary<string, MapBlockData> _blocks = new();
        private static readonly Dictionary<string, PlayerData> _characters = new();
        private static readonly Dictionary<string, CharacterCardData> _characterCards = new();
        private static readonly Dictionary<string, ScavengeCardData> _scavengeCards = new();
        private static readonly Dictionary<string, MonsterData> _monsters = new();
        private static readonly Dictionary<string, MissionData> _missions = new();

        private static bool _loaded = false;

        public static void LoadAll()
        {
            if (_loaded) return;
            LoadDir("res://data/blocks", _blocks, recursive: false);
            LoadDir("res://data/characters", _characters, recursive: false);
            LoadDir("res://data/cards/characterCards", _characterCards, recursive: true);
            LoadDir("res://data/cards/scavengeCards", _scavengeCards, recursive: true);
            LoadDir("res://data/monsters", _monsters, recursive: true);
            LoadDir("res://data/missions", _missions, recursive: false);
            _loaded = true;
            GD.Print($"[DataLoader] Loaded {_blocks.Count} blocks, {_characters.Count} characters, {_characterCards.Count} character cards, {_scavengeCards.Count} scavenge cards, {_monsters.Count} monsters, {_missions.Count} missions");
        }

        private static void LoadDir<T>(string resDir, Dictionary<string, T> cache, bool recursive) where T : class
        {
            string globalDir = ProjectSettings.GlobalizePath(resDir);
            if (!DirAccess.DirExistsAbsolute(globalDir))
            {
                GD.PushWarning($"[DataLoader] Directory not found: {resDir}");
                return;
            }
            var files = new List<string>();
            CollectJsonFiles(globalDir, files, recursive);
            foreach (string file in files)
            {
                string json = File.ReadAllText(file);
                T? data = JsonSerializer.Deserialize<T>(json, JsonOptions.Default);
                if (data == null) continue;
                string? id = GetId(data);
                if (string.IsNullOrEmpty(id))
                {
                    GD.PushWarning($"[DataLoader] Entry missing Id in {file}");
                    continue;
                }
                cache[id] = data;
            }
        }

        private static void CollectJsonFiles(string dir, List<string> files, bool recursive)
        {
            foreach (string f in Directory.GetFiles(dir, "*.json"))
            {
                files.Add(f);
            }
            if (recursive)
            {
                foreach (string d in Directory.GetDirectories(dir))
                {
                    CollectJsonFiles(d, files, recursive);
                }
            }
        }

        private static string? GetId<T>(T data) => data switch
        {
            MapBlockData b => b.Id,
            PlayerData p => p.Id,
            CharacterCardData c => c.Id,
            ScavengeCardData s => s.Id,
            MonsterData m => m.Id,
            MissionData mi => mi.Id,
            _ => null,
        };

        // --- 查询接口 ---
        public static MapBlockData? GetBlock(string id) => _blocks.GetValueOrDefault(id);
        public static IReadOnlyCollection<MapBlockData> GetAllBlocks() => _blocks.Values;

        public static PlayerData? GetCharacter(string id) => _characters.GetValueOrDefault(id);
        public static IReadOnlyCollection<PlayerData> GetAllCharacters() => _characters.Values;

        public static CharacterCardData? GetCharacterCard(string id) => _characterCards.GetValueOrDefault(id);
        public static IReadOnlyCollection<CharacterCardData> GetAllCharacterCards() => _characterCards.Values;

        public static ScavengeCardData? GetScavengeCard(string id) => _scavengeCards.GetValueOrDefault(id);
        public static IReadOnlyCollection<ScavengeCardData> GetAllScavengeCards() => _scavengeCards.Values;

        public static MonsterData? GetMonster(string id) => _monsters.GetValueOrDefault(id);
        public static IReadOnlyCollection<MonsterData> GetAllMonsters() => _monsters.Values;

        public static MissionData? GetMission(string id) => _missions.GetValueOrDefault(id);
        public static IReadOnlyCollection<MissionData> GetAllMissions() => _missions.Values;
    }
}
