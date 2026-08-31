extends RefCounted
class_name GameHandler
## 应用权威游戏消息，并将命令拒绝信息提供给 UI 和日志。

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

var _client_world: ClientWorldSynchronizer = null

func _init(client_world: ClientWorldSynchronizer):
	_client_world = client_world

func on_world_frame(msg: GameProto.ServerMessage):
	var world_frame := msg.get_world_frame()
	var server_tick := msg.get_server_tick()
	_client_world.apply_world_frame(server_tick, world_frame)


func on_world_snapshot(msg: GameProto.ServerMessage):
	print("世界快照：", msg.get_world_snapshot())
	# 快照错误 没有正确的展示房间内实体的位置
	var world_snapshot := msg.get_world_snapshot()
	_client_world.apply_world_snapshot(world_snapshot)

func on_movement_frame(msg: GameProto.ServerMessage):
	# print("on_movement_frame")
	# print(msg)
	var movement_frame := msg.get_movement_frame()
	_client_world.apply_movement_frame(movement_frame)
	# var changed_states := MovementFrameReducer.apply(GameBootstrap.game_store, movement_frame)

func on_entity_spawned(msg: GameProto.ServerMessage):
	var entity_spawned := msg.get_entity_spawned()
	_client_world.apply_entity_spawned(entity_spawned)

func on_entity_removed(msg: GameProto.ServerMessage):
	var entity_removed := msg.get_entity_removed()
	_client_world.apply_entity_removed(entity_removed.get_entity_id())

func on_command_rejected(msg: GameProto.ServerMessage):
	var rejected := msg.get_command_rejected()
	var command_name := rejected.get_command_name()
	var reason_code := rejected.get_reason_code()
	var reason_message := rejected.get_reason_message()
	push_warning("命令被拒绝 [%s/%s]：%s" % [command_name, reason_code, reason_message])
	SignalMgr.Get().snl_command_rejected.emit(command_name, reason_code, reason_message)

func on_attack_start(msg: GameProto.ServerMessage):
	var attack_start := msg.get_attack_start()
	_client_world.apply_attack_start(attack_start)
