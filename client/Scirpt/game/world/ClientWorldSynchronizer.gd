extends RefCounted
class_name ClientWorldSynchronizer
## 按顺序通过 Reducer 应用服务端消息，并发出表现层信号。
const GameProto := preload("res://Scirpt/proto/game_proto.gd")

var store: GameStore = null

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

	# 发送消息
	_emit_world_frame_changes(changes)

func _emit_world_frame_changes(changes: WorldFrameChanges):
	# 批量信号
	if not changes.moved.is_empty():
		SignalMgr.Get().snl_entities_moved.emit(changes.moved)

	if not changes.aims_changed.is_empty():
		SignalMgr.Get().snl_entities_aims_changed.emit(changes.aims_changed)
	
	if not changes.health_changed.is_empty():
		SignalMgr.Get().snl_entities_health_changed.emit(changes.health_changed)

	# 单独信号
	for spawn in changes.spawned:
		SignalMgr.Get().snl_entity_added.emit(spawn)

	for removed in changes.removed:
		SignalMgr.Get().snl_entity_removed.emit(removed)

	# 离散事件
	for env in changes.events:
		_emit_world_event(env)

func _emit_world_event(env: GameProto.WorldEvent):
	# 处理离散事件
	
	match env.get_payload_case():
		GameProto.WorldEvent.PayloadCase.ATTACK_START:
			var attack_start: GameProto.AttackStart = env.get_attack_start()
			apply_attack_start(attack_start)
		GameProto.WorldEvent.PayloadCase.DAMAGE:
			var damage_event: GameProto.DamageEvent = env.get_damage()
			apply_damage_event(damage_event)
		GameProto.WorldEvent.PayloadCase.ENTITY_DEAD:
			var entity_dead: GameProto.EntityDead = env.get_entity_dead()
			apply_entity_dead(entity_dead)
		
func apply_world_snapshot(snapshot: GameProto.WorldSnapshot):
	WorldSnapshotReducer.apply(store, snapshot)
	_last_world_tick = snapshot.get_server_tick()
	SignalMgr.Get().snl_world_snapshot_applied.emit(snapshot)

func apply_attack_start(attack_start: GameProto.AttackStart):
	var attacker_id := attack_start.get_attacker_id()
	var attack_id := attack_start.get_attack_id()
	var atk_facing := attack_start.get_atk_facing()
	SignalMgr.Get().snl_attack_start.emit(attacker_id, attack_id, atk_facing)

func apply_damage_event(damage_event: GameProto.DamageEvent):
	var target_id := damage_event.get_target_id()
	var damage := damage_event.get_damage()
	var attacker_id := damage_event.get_attacker_id()
	var attack_id := damage_event.get_attack_id()
	var critical := damage_event.get_critical()

	SignalMgr.Get().snl_damage_received.emit(attacker_id, target_id, attack_id, damage, critical)

func apply_entity_dead(entity_dead: GameProto.EntityDead):
	var entity_id := entity_dead.get_entity_id()
	SignalMgr.Get().snl_entity_dead.emit(entity_id)

func reset_world():
	WorldResetReducer.apply(store)
	_last_world_tick = -1
	SignalMgr.Get().snl_store_cleared.emit()
