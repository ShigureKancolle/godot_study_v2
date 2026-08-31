extends ClientReducerBase
class_name WorldFrameReducer

static func apply(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
    var changes: Array[EntityState] = []

    changes.append_array(EntitySpawnedReducer.apply_by_world_frame(store, frame))

    changes.append_array(MovementFrameReducer.apply_by_world_frame(store, frame))

    changes.append_array(CombatFrameReducer.apply_by_world_frame(store, frame))

    for health_state_delta: GameProto.HealthStateDelta in frame.get_health_states():
        pass

    for env: GameProto.WorldEvent in frame.get_events():
        pass

    EntityRemovedReducer.apply_by_world_frame(store, frame)
    return changes
