extends ClientReducerBase
class_name WorldFrameReducer


static func apply(store: GameStore, frame: GameProto.WorldFrame) -> WorldFrameChanges:
    var changes := WorldFrameChanges.new()

    changes.spawned.append_array(EntitySpawnedReducer.apply_by_world_frame(store, frame))

    changes.moved.append_array(MovementFrameReducer.apply_by_world_frame(store, frame))

    changes.aims_changed.append_array(AimsChangeReducer.apply_by_world_frame(store, frame))

    for health_state_delta: GameProto.HealthStateDelta in frame.get_health_states():
        # reducer.health_changed.append(health_state_delta)
        pass

    changes.events.append_array(frame.get_events())

    changes.removed.append_array(EntityRemovedReducer.apply_by_world_frame(store, frame))
    return changes
