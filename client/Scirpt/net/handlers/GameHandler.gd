extends RefCounted
class_name GameHandler

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

var _client_world: ClientWorldSynchronizer = null

func _init(client_world: ClientWorldSynchronizer):
	_client_world = client_world


func on_world_snapshot(msg: GameProto.ServerMessage):
	print("世界快照：", msg.get_world_snapshot())
	# 快照错误 没有正确的展示房间内实体的位置
	var world_snapshot := msg.get_world_snapshot()
	_client_world.apply_world_snapshot(world_snapshot)

func on_movement_frame(msg: GameProto.ServerMessage):
	var movement_frame := msg.get_movement_frame()
	_client_world.apply_movement_frame(movement_frame)
	# var changed_states := MovementFrameReducer.apply(GameBootstrap.game_store, movement_frame)

func on_entity_spawned(msg: GameProto.ServerMessage):
	var entity_spawned := msg.get_entity_spawned()
	_client_world.apply_entity_spawned(entity_spawned)

func on_entity_removed(msg: GameProto.ServerMessage):
	var entity_removed := msg.get_entity_removed()
	_client_world.apply_entity_removed(entity_removed.get_entity_id())
