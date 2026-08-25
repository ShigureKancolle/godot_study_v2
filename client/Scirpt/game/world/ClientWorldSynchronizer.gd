extends RefCounted
class_name ClientWorldSynchronizer
const GameProto := preload("res://Scirpt/proto/game_proto.gd")

var store: GameStore = null

var _last_movement_tick: int = -1

func _init(store: GameStore):
	self.store = store

func apply_world_snapshot(snapshot: GameProto.WorldSnapshot):
	CompSystem.apply_world_snapshot(store, snapshot)
	_last_movement_tick = snapshot.get_server_tick()
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
	var state := EntityState.from_entity_info(entity_spawned.get_entity_info())
	state.server_position = state.server_position
	store.add_entity(state.entity_id, state)
	SignalMgr.Get().snl_entity_added.emit(state)
	

func apply_entity_removed(entity_id: String):
	store.remove_entity(entity_id)
	SignalMgr.Get().snl_entity_removed.emit(entity_id)
# func apply_entity_relocated()
