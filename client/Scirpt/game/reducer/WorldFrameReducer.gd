extends ClientReducerBase
class_name WorldFrameReducer


static func apply(store: GameStore, frame: GameProto.WorldFrame) -> WorldFrameChanges:
	var changes := WorldFrameChanges.new()

	changes.spawned.append_array(EntitySpawnedReducer.apply_by_world_frame(store, frame))

	changes.moved.append_array(MovementFrameReducer.apply_by_world_frame(store, frame))

	changes.aims_changed.append_array(AimsChangeReducer.apply_by_world_frame(store, frame))

	changes.health_changed.append_array(HpChangeReducer.apply_by_world_frame(store, frame))

	changes.events.append_array(frame.get_events())

	changes.removed.append_array(EntityRemovedReducer.apply_by_world_frame(store, frame))

	changes.prog_changed.append_array(ProgressionReducer.apply_by_world_frame(store, frame))

	if ConfigLoader.get_constant("DEBUG_MSG_ENABLED"):
		changes.entity_move_paths.append_array(EntityMovePathReducer.apply_by_world_frame(store, frame))
	return changes
