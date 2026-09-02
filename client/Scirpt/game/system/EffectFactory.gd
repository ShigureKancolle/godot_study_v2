extends Object
class_name EffectFactory


static func create_effect(effect_path: String) -> Node2D:
    var effect_scene := load(effect_path) as PackedScene
    if not effect_scene:
        push_error("[EffectFactory] 加载特效场景失败：%s" % effect_path)
        return null
    return effect_scene.instantiate() as Node2D

static func create_hurt_effect(_attack_id: int) -> Node2D:
    var effect_path = "res://Prefab/Effect/PlayerHitEffect.tscn"
    var effect = create_effect(effect_path)
    if not effect:
        return null

    var animated_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    if not animated_sprite:
        push_error("[EffectFactory] 受击特效缺少 AnimatedSprite2D 节点")
        effect.queue_free()
        return null

    animated_sprite.animation_finished.connect(
        _queue_free.bind(effect),
        CONNECT_ONE_SHOT
    )
    animated_sprite.play(&"default")
    effect.position = Vector2.ZERO
    return effect

static func create_damage_num(damage: int, _critical: bool) -> Node2D:
    var effect_path = "res://Prefab/Effect/FireDamageEffect.tscn"
    var effect = create_effect(effect_path)
    if not effect:
        return null

    var label := effect.get_node_or_null("Label") as Label
    if not label:
        push_error("[EffectFactory] 伤害数字缺少 Label 节点")
        effect.queue_free()
        return null

    label.text = str(damage)

    var animation_player := effect.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if not animation_player:
        push_error("[EffectFactory] 伤害数字缺少 AnimationPlayer 节点")
        effect.queue_free()
        return null

    animation_player.animation_finished.connect(
        _queue_free_after_animation.bind(effect),
        CONNECT_ONE_SHOT
    )
    animation_player.play(&"fire")

    return effect


static func _queue_free(effect: Node) -> void:
    if is_instance_valid(effect):
        effect.queue_free()


static func _queue_free_after_animation(_animation_name: StringName, effect: Node) -> void:
    _queue_free(effect)
