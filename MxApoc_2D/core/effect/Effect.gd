# Effect.gd
class_name Effect
extends RefCounted

# 所有原子效果的抽象基类

## 核心执行接口
## 所有子类必须重写此方法以实现具体的逻辑
func execute(context: EffectContext) -> void:
	pass


## 如果效果包含异步操作（例如：等待玩家弹窗选择、等待动画播放），重写此接口
func execute_async(context: EffectContext) -> void:
	execute(context)