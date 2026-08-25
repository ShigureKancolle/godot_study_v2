extends Node
'''
用于组装初始化客户端
'''

const GameProto = preload("res://Scirpt/proto/game_proto.gd")
const GAME_SCENE := "res://Prefab/Level/TestLevel.tscn"

var web_socket_mgr: WebSocketMgr = null
var game_store: GameStore = null
var client_world_synchronizer: ClientWorldSynchronizer = null
var game_handler: GameHandler = null

func _ready():
	SignalMgr.Get().snl_world_snapshot_applied.connect(enter_world)


	game_store = GameStore.new()
	client_world_synchronizer = ClientWorldSynchronizer.new(game_store)
	game_handler = GameHandler.new(client_world_synchronizer)

	# 网络服务
	web_socket_mgr = WebSocketMgr.Get()
	web_socket_mgr.start()
	
	# 网络消息
	HandlerRegister.register(game_handler)

func _process(delta: float) -> void:
	web_socket_mgr.poll(delta)

func reset_game_store():
	if not game_store:
		return
	game_store.clear()

# func create_game_store():
# 	if game_store:
# 		return
# 	game_store = GameStore.new()

func enter_world(snapshot: GameProto.WorldSnapshot):
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != GAME_SCENE:
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
