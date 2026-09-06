extends Object
class_name AttackInputController

const ATTACK_ID: int = 1004


static func get_attack_id(_delta: float) -> int:
    var attack := Input.is_action_just_pressed("atk_left")
    if attack:
        return ATTACK_ID

    return 0
