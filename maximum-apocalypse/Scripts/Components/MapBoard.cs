using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using MaximumApocalypse.Data;
using MaximumApocalypse.Runtime;

namespace MaximumApocalypse
{
    /// <summary>
    /// 地图生成与渲染。对应原 MapBoard.gd（extends Node2D）。
    /// 改为从 DataLoader 读取 JSON 数据（替代 .tres 的 ResourceLoader.load）。
    /// </summary>
    public partial class MapBoard : Node2D
    {
        [Export] public Vector2 TileSize { get; set; } = new(140, 140);
        [Export] public float GridSpacing { get; set; } = 12.0f;
        [Export] public int TotalTilesNeeded { get; set; } = 13;

        private readonly Dictionary<Vector2I, TileView> _spawnedTileViews = new();
        private List<MapBlockData> _loadedTemplates = new();
        private MapBlockData? _vanTemplate;

        public override void _Ready()
        {
            GD.Print("[MapBoard] 节点已就绪，开始自主独立生成地图...");

            LoadTileResources();
            LoadVanResource();

            if (_loadedTemplates.Count == 0)
            {
                GD.PushError("[MapBoard 错误] 未找到任何有效的 MapBlockData 普通资源！");
                return;
            }
            if (_vanTemplate == null)
            {
                GD.PushError("[MapBoard 错误] 未能成功加载面包车资源！");
                return;
            }

            var finalPool = BuildFinalTilePool();
            GenerateAndRenderMap(finalPool);
        }

        private void LoadTileResources()
        {
            // 从 DataLoader 取全部地块，过滤掉面包车
            _loadedTemplates = DataLoader.GetAllBlocks()
                .Where(b => !b.Id.Contains("van"))
                .ToList();
        }

        private void LoadVanResource()
        {
            _vanTemplate = DataLoader.GetBlock("van");
        }

        private List<MapBlockData> BuildFinalTilePool()
        {
            var pool = new List<MapBlockData>();
            for (int i = 0; i < TotalTilesNeeded; i++)
            {
                int index = i % _loadedTemplates.Count;
                pool.Add(_loadedTemplates[index]);
            }
            // 洗牌打乱顺序
            var rng = new Random();
            int n = pool.Count;
            while (n > 1)
            {
                n--;
                int k = rng.Next(n + 1);
                (pool[n], pool[k]) = (pool[k], pool[n]);
            }
            return pool;
        }

        private void GenerateAndRenderMap(List<MapBlockData> drawPile)
        {
            // 清理旧节点
            foreach (var child in GetChildren())
            {
                child.QueueFree();
            }
            _spawnedTileViews.Clear();
            GameState.Instance.MapGrid.Clear();

            int width = (int)Mathf.Ceil(Mathf.Sqrt(TotalTilesNeeded));

            // 铺设普通网格
            for (int tileIndex = 0; tileIndex < TotalTilesNeeded; tileIndex++)
            {
                int x = tileIndex % width;
                int y = tileIndex / width;
                var pos = new Vector2I(x, y);

                var currentData = drawPile[0];
                drawPile.RemoveAt(0);

                var state = new TileRuntimeState
                {
                    TemplateId = currentData.Id,
                    Data = currentData,
                    IsRevealed = false,
                    MonsterTokens = 0,
                    DroppedCards = new List<CardRuntime>(),
                };
                GameState.Instance.MapGrid[pos] = state;

                CreateTileView(pos, state);
            }

            // 探测边缘放置面包车
            var vanPos = FindValidVanPosition();
            if (vanPos != new Vector2I(-99, -99))
            {
                var vanState = new TileRuntimeState
                {
                    TemplateId = _vanTemplate!.Id,
                    Data = _vanTemplate,
                    IsRevealed = true, // 面包车初始可见
                    MonsterTokens = 0,
                    DroppedCards = new List<CardRuntime>(),
                };
                GameState.Instance.MapGrid[vanPos] = vanState;
                CreateTileView(vanPos, vanState);
                GD.Print($"[MapBoard] 地图渲染完毕！面包车坐落于外围: {vanPos}");
            }
        }

        private void CreateTileView(Vector2I gridPos, TileRuntimeState runtimeData)
        {
            var tileNode = new TileView
            {
                Position = new Vector2(
                    gridPos.X * (TileSize.X + GridSpacing),
                    gridPos.Y * (TileSize.Y + GridSpacing)),
            };
            AddChild(tileNode);
            tileNode.Setup(gridPos, runtimeData, TileSize);
            _spawnedTileViews[gridPos] = tileNode;
        }

        private Vector2I FindValidVanPosition()
        {
            var potential = new List<Vector2I>();
            var directions = new[]
            {
                Vector2I.Up, Vector2I.Down, Vector2I.Left, Vector2I.Right,
            };

            foreach (var pos in GameState.Instance.MapGrid.Keys)
            {
                foreach (var dir in directions)
                {
                    var target = pos + dir;
                    if (!GameState.Instance.MapGrid.ContainsKey(target) && !potential.Contains(target))
                    {
                        potential.Add(target);
                    }
                }
            }

            if (potential.Count > 0)
            {
                var rng = new Random();
                return potential[rng.Next(potential.Count)];
            }
            return new Vector2I(-99, -99);
        }
    }
}
