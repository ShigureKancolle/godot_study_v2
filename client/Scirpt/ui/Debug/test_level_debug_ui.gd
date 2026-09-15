extends Node2D
class_name TestLevelDebugUI

@onready var server_tick: Label = $PanelContainer/BoxContainer/server_tick
@onready var cur_stage: Label = $PanelContainer/BoxContainer/cur_stage
@onready var spwan_time_count_down: Label = $PanelContainer/BoxContainer/spwan_time_count_down
@onready var enemy_budget: Label = $PanelContainer/BoxContainer/enemy_budget
@onready var stage_time: Label = $PanelContainer/BoxContainer/stage_time
@onready var enemy_count: Label = $PanelContainer/BoxContainer/enemy_count
@onready var normal_enemy_count: Label = $PanelContainer/BoxContainer/normal_enemy_count
@onready var speed_change: Button = $PanelContainer/BoxContainer/speed_change
@onready var next_stage: Button = $PanelContainer/BoxContainer/next_stage

class LevelDebugData:
	extends Object
	var enemy_budget_data: String = ""
	var server_tick: int = 0
	var cur_stage_id: int = 0
	var spwan_time_count_down_ms: int = 0
	var stage_time_seconds: int = 0
	var enemy_count: int = 0
	var normal_enemy_count: int = 0

func _ready() -> void:
	speed_change.connect("pressed", on_speed_change)
	next_stage.connect("pressed", on_next_stage)
	SignalMgr.Get().snl_cur_game_speed.connect(hdl_cur_game_speed)
	
func on_speed_change():
	WebSocketMgr.Get().send(
		"game_speed_change",
		{}
	)
	
func on_next_stage():
	WebSocketMgr.Get().send(
		"skip_cur_stage",
		{}
	)
	
func hdl_cur_game_speed(speed: int):
	speed_change.text = str(speed) + "倍"


func update(debug: LevelDebugData):
	server_tick.text = "服务器tick: " + str(debug.server_tick)
	cur_stage.text = "当前阶段: " + str(debug.cur_stage_id)
	spwan_time_count_down.text = "下次刷怪倒计时: " + str(debug.spwan_time_count_down_ms)
	enemy_budget.text = "敌人预算: " + debug.enemy_budget_data
	stage_time.text = "当前阶段时间: " + str(debug.stage_time_seconds)
	enemy_count.text = "敌人数量: " + str(debug.enemy_count)
	normal_enemy_count.text = "普通敌人数量: " + str(debug.normal_enemy_count)
