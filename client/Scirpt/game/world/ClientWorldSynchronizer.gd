extends RefCounted
class_name ClientWorldSynchronizer
## 按顺序通过 Reducer 应用服务端消息，并发出表现层信号。
const GameProto := preload("res://Scirpt/proto/game_proto.gd")

var store: GameStore = null

var _last_movement_tick: int = -1
var _last_combat_tick: int = -1

var run_id: String = ""
var _last_world_tick: int = -1
var _processed_event_ids: Dictionary[int, bool] = {}

func _init(store: GameStore):
	self.store = store

func apply_world_frame(server_tick: int, frame: GameProto.WorldFrame):
	if server_tick <= _last_world_tick:
		return

	var changes := WorldFrameReducer.apply(store, frame)
	_last_world_tick = server_tick
	store.server_tick = server_tick


func apply_world_snapshot(snapshot: GameProto.WorldSnapshot):
	WorldSnapshotReducer.apply(store, snapshot)
	_last_movement_tick = snapshot.get_server_tick()
	_last_combat_tick = snapshot.get_server_tick()
	SignalMgr.Get().snl_world_snapshot_applied.emit(snapshot)


func apply_movement_frame(frame: GameProto.MovementFrame):
	var frame_tick := frame.get_server_tick()
	if frame_tick <= _last_movement_tick:
		return

	_last_movement_tick = frame_tick
	var change_states := MovementFrameReducer.apply(store, frame)

	if not change_states.is_empty():
		SignalMgr.Get().snl_entities_moved.emit(change_states)


func apply_entity_spawned(entity_spawned: GameProto.EntitySpawned):
	var state := EntitySpawnedReducer.apply(store, entity_spawned.get_entity_info())
	SignalMgr.Get().snl_entity_added.emit(state)
	

func apply_entity_removed(entity_id: String):
	EntityRemovedReducer.apply(store, entity_id)
	SignalMgr.Get().snl_entity_removed.emit(entity_id)
# func apply_entity_relocated()

func apply_attack_start(attack_start: GameProto.AttackStart):
	var attacker_id := attack_start.get_attacker_id()
	var attack_id := attack_start.get_attack_id()
	var atk_facing := attack_start.get_atk_facing()
	SignalMgr.Get().snl_attack_start.emit(attacker_id, attack_id, atk_facing)


# func apply_combat_frame(frame: GameProto.CombatFrame):
# 	var frame_tick := frame.get_server_tick()
# 	if frame_tick <= _last_movement_tick:
# 		return

# 	_last_movement_tick = frame_tick
# 	var change_states := CombatFrameReducer.apply(store, frame)


# 	if not change_states.is_empty():
# 		SignalMgr.Get().snl_entities_combat.emit(change_states)

func reset_world():
	WorldResetReducer.apply(store)

	_last_movement_tick = -1

	_last_world_tick = -1
	SignalMgr.Get().snl_store_cleared.emit()
