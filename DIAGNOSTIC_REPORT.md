# 启动问题诊断报告 - MaximumApocalypse

## 已修复的问题

### 1. ✅ GameState autoload单例冲突
**问题**: GameState.gd中有`class_name GameState`，同时project.godot中配置为autoload单例，导致命名冲突。
**修复**: 移除GameState.gd中的class_name，保留extends Node。Autoload单例不应有class_name。

### 2. ✅ 节点引用路径错误
**问题**: RuleEngine和GameLoopManager使用了相对路径`get_node("../UIManager")`，在某些情况下会失效。
**修复**: 改为在_ready()中使用延迟获取，通过get_parent().get_node()安全获取节点。

### 3. ✅ game.gd初始化时序问题
**问题**: game.gd中await 1秒后调用game_loop.start_game()，但GameLoopManager的_ready()也需要0.1秒延迟，可能导致时序冲突。
**修复**: 增加game.gd延迟到1.5秒，并增加null检查和错误提示。

### 4. ✅ MissionData类型转换
**问题**: game.gd加载mission_0.tres但没有类型转换，可能导致类型不匹配。
**修复**: 增加`as MissionData`类型转换。

## 现有代码验证

### ✅ 方法名匹配
- GameLoopManager调用的所有RuleEngine方法都存在
- RuleEngine调用的所有UIManager方法都存在
- UIManager的所有信号都已定义

### ✅ 属性名匹配
- GameState.map_grid使用正确
- GameState.players使用正确
- GameState.required_fuel和current_fuel_in_van使用正确
- tile字典的"monster_tokens"属性使用正确
- MapBlockData.spawn_values属性使用正确

### ✅ 节点结构正确
game.tscn包含所有必需节点：
- GameState (autoload单例，不需要节点)
- RuleEngine
- GameLoopManager
- UIManager
- MapBoard

## 启动流程

1. **main.tscn** (主菜单) → 点击"开始游戏"
2. **MissionSelect.tscn** (选关场景) → 显示13个任务
3. **game.tscn** (游戏场景) → 核心游戏循环

## 测试建议

### 方法1: 直接运行main.tscn
- 在Godot编辑器中打开main.tscn
- 点击"播放"按钮或F5运行
- 观察控制台输出是否有错误

### 方法2: 直接运行game.tscn
- 在Godot编辑器中打开game.tscn
- 点击"播放"按钮或F5运行
- 跳过选关步骤，直接进入游戏

### 方法3: 检查autoload配置
- 确认project.godot中有以下autoload配置：
  ```
  Enums="*uid://buvwmjhq41w3f"
  GameState="*uid://ci33mkua1qnqq"
  ```

## 常见启动失败原因

### 1. 缺少autoload单例
**症状**: 控制台报错"GameState not found"
**解决**: 检查project.godot配置，确保Enums和GameState已配置为autoload

### 2. 节点路径错误
**症状**: 控制台报错"Node not found: UIManager"
**解决**: 检查game.tscn节点结构，确保所有节点都存在

### 3. 资源加载失败
**症状**: 控制台报错"Resource not found: res://godot/data/missions/mission_0.tres"
**解决**: 检查mission_0.tres文件是否存在，路径是否正确

### 4. 类型转换失败
**症状**: 控制台报错"Cannot convert Resource to MissionData"
**解决**: 确保MissionData.gd有class_name定义，mission_0.tres正确继承MissionData

## 下一步建议

如果场景仍然无法启动，请：
1. 查看Godot编辑器的输出窗口，找到具体错误信息
2. 检查每个脚本的错误提示（红色波浪线）
3. 确认所有资源文件（.tres）都存在且格式正确
4. 尝试逐个场景测试，先测试main.tscn，再测试game.tscn

## 代码质量检查结果

✅ 所有class_name定义正确（除GameState外）
✅ 所有extends语句正确
✅ 所有方法调用匹配
✅ 所有属性名匹配
✅ 所有信号定义完整
✅ 所有节点引用安全
✅ 所有类型转换正确
✅ 所有autoload配置正确