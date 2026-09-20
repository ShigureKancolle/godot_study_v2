extends Singleton
class_name SignalMgr
@warning_ignore_start("unused_signal")

const GameProto := preload("res://Scirpt/proto/game_proto.gd")

static var _instance: SignalMgr = null

static func Get_Ins() -> SignalMgr:
	return _instance

static func Get() -> SignalMgr:
	if not _instance:
		_instance = SignalMgr.new()
	return _instance
	
# 信号注册前缀 snl_
# handel前缀 hdl_
# login
signal snl_on_login_accepted(acc: String, name: String)

# GameStore
signal snl_entity_added(entity: EntityState)
signal snl_entity_updated(entity: EntityState)
signal snl_entity_removed(entity_id: String)
signal snl_store_cleared
signal snl_entities_moved(change_states: Array[EntityState])
signal snl_command_rejected(command_name: String, reason_code: String, reason_message: String)
signal snl_attack_start(attacker_id: String, attack_id: int, atk_facing: float)
signal snl_entities_aims_changed(change_states: Array[EntityState])
signal snl_entities_health_changed(change_states: Array[EntityState])
signal snl_damage_received(attacker_id: String, target_id: String, attack_id: int, damage: int, critical: bool)
signal snl_entity_dead(entity_id: String)
signal snl_game_pause(pause: bool)
signal snl_entities_prog_changed(change_states: Array[EntityState])
signal snl_entity_upgrade(entity_id: String, pre_level: int, cur_level: int)
signal snl_game_over()

# debug
signal snl_level_debug(data: TestLevelDebugUI.LevelDebugData)
signal snl_cur_game_speed(speed: int)
signal snl_entities_move_paths_changed(change_states: Array[EntityMovePathState])
signal snl_draw_entity_path(draw: bool)  # 能不能画
signal snl_entity_path_draw(entity_id: String, draw_path: bool) # 告诉level显示或隐藏路径
# debugend

# Bootstrap
signal snl_world_snapshot_applied(snapshot: GameProto.WorldSnapshot)
