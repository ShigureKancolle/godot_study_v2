extends Node2D
class_name OneShotEffect

## 一次性特效根节点。
##
## Factory 只负责实例化和写入业务参数；特效自身负责在进入场景树后播放，
## 并在播放结束时释放，避免父节点或调用方保存临时特效的生命周期状态。

@export var animation_player_path: NodePath
@export var animation_name: StringName = &""
@export var animated_sprite_path: NodePath
@export var sprite_animation_name: StringName = &""


func _ready() -> void:
	var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_player:
		animation_player.animation_finished.connect(_queue_free_after_finished, CONNECT_ONE_SHOT)
		animation_player.play(animation_name)
		return

	var animated_sprite := get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	if animated_sprite:
		animated_sprite.animation_finished.connect(_queue_free_after_finished, CONNECT_ONE_SHOT)
		animated_sprite.play(sprite_animation_name)
		return

	push_error("[OneShotEffect] 未配置 AnimationPlayer 或 AnimatedSprite2D：%s" % name)
	queue_free()


func _queue_free_after_finished(_played_animation: StringName = &"") -> void:
	queue_free()
