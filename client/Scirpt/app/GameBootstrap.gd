extends Node
'''
用于组装初始化客户端
'''

var web_socket_mgr: WebSocketMgr = null

func _ready():
	web_socket_mgr = WebSocketMgr.Get()
	web_socket_mgr.start()

func _process(delta: float) -> void:
	web_socket_mgr.poll(delta)
