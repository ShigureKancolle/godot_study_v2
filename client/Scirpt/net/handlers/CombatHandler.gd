extends RefCounted
class_name CombatHandler

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

var _client_world: ClientWorldSynchronizer = null

func _init(client_world: ClientWorldSynchronizer):
	_client_world = client_world

func on_combat_frame(msg: GameProto.ServerMessage):
	# print("on_combat_frame")
	# print(msg)
	var frame = msg.get_combat_frame()
	_client_world.apply_combat_frame(frame)
