extends ClientReducerBase
class_name HpChangeReducer

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
    var changed_states: Array[EntityState] = []
    for health_state_delta in frame.get_health_states():
        var state := _apply_health_state_delta(store, health_state_delta)
        if state != null:
            changed_states.append(state)

    return changed_states

static func _apply_health_state_delta(store: GameStore, health_state: GameProto.HealthStateDelta) -> EntityState:
    var entity_id: String = health_state.get_entity_id()
    var state := store.get_entity(entity_id)
    if state == null:
        return null
    var combat_state := state.combat_entity_state
    if combat_state == null:
        return null
    combat_state.hp = health_state.get_hp()
    combat_state.max_hp = health_state.get_max_hp()
    combat_state.dead = health_state.get_dead()
    return state
