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

func on_command_rejected(msg: GameProto.ServerMessage):
	var rejected := msg.get_command_rejected()
	var command_name := rejected.get_command_name()
	var reason_code := rejected.get_reason_code()
	var reason_message := rejected.get_reason_message()
	push_warning("命令被拒绝 [%s/%s]：%s" % [command_name, reason_code, reason_message])
	SignalMgr.Get().snl_command_rejected.emit(command_name, reason_code, reason_message)

func on_level_debug(msg: GameProto.ServerMessage):
	var debug := msg.get_level_debug_data()
	# print("等级调试信息：", debug)
	var data = TestLevelDebugUI.LevelDebugData.new()
	data.server_tick = debug.get_server_tick()
	data.cur_stage_id = debug.get_cur_stage_id()
	data.spwan_time_count_down_ms = debug.get_spwan_time_count_down_ms()
	data.stage_time_seconds = debug.get_stage_time_seconds()
	data.enemy_count = debug.get_enemy_count()
	data.normal_enemy_count = debug.get_normal_enemy_count()
	var enemy_budget_data := debug.get_enemy_budget_data()
	for enemy_budget in enemy_budget_data:
		data.enemy_budget_data += enemy_budget.get_enemy_type() + ":" + str(enemy_budget.get_budget()) + "\n"

	SignalMgr.Get().snl_level_debug.emit(data)
	
func on_cur_game_speed(msg: GameProto.ServerMessage):
	var speed_msg := msg.get_cur_game_speed()
	
	var speed := speed_msg.get_speed()
	
	SignalMgr.Get().snl_cur_game_speed.emit(speed)

func on_game_over(msg: GameProto.ServerMessage):
	var over := msg.get_game_over()
	SignalMgr.Get().snl_game_over.emit()
	
