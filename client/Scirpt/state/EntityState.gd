extends RefCounted
class_name EntityState

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

enum EntityType {
	PLAYER = 1,
	ENEMY = 2,
	ORNAMENT = 3,
	EXP = 4
}
	

# 存放游戏实体的信息

var entity_id: String = ""
var player_name: String = ""
var entity_type: int = 0
var entity_config_key: String = ""

var server_position: Vector2 = Vector2.ZERO
var facing_dir: Vector2 = Vector2.ZERO
var anim_state: String = ""
var moving: bool = false

var is_local_player: bool = false
var progression_state: ProgressionState = null

var combat_entity_state: CombatEntityState = null

# region debug
var entity_move_path: EntityMovePathState = null

# regionend


static func from_entity_info(entity_info: GameProto.EntityInfo) -> EntityState:
	var state = EntityState.new()
	state.entity_id = entity_info.get_entity_id()
	state.player_name = entity_info.get_player_name()
	state.entity_type = entity_info.get_entity_type()
	state.entity_config_key = entity_info.get_entity_config_key()
	state.server_position = Vector2(entity_info.get_x(), entity_info.get_y())
	state.facing_dir = Vector2(entity_info.get_facing_x(), entity_info.get_facing_y())
	state.anim_state = entity_info.get_anim_state()
	state.moving = entity_info.get_moving()
	if entity_info.has_combat_entity_info():
		state.combat_entity_state = CombatEntityState.from_entity_info(entity_info.get_combat_entity_info())
	if entity_info.has_prog_entity_info():
		state.progression_state = ProgressionState.from_progression_info(entity_info.get_prog_entity_info())
	if entity_info.has_entity_move_path():
		state.entity_move_path = EntityMovePathState.from_proto(entity_info.get_entity_move_path())
	return state
