extends RefCounted
class_name EntityState

# 存放游戏实体的信息

var entity_id: String = ""
var player_name: String = ""
var entity_type: int = 0

var server_position: Vector2 = Vector2.ZERO
var facing: float = 0.0
var anim_state: String = ""
var moving: bool = false

var hp: int = 0
var max_hp: int = 0
var dead: bool = false
