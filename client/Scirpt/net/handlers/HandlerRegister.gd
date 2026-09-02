extends Object
class_name HandlerRegister

static func register(game_handler: GameHandler):
	var router := MessageRouter.Get()
	
	router.register(&"login_accepted", LoginHandler.on_login_accepted)
	router.register(&"world_snapshot", game_handler.on_world_snapshot)
	router.register(&"command_rejected", game_handler.on_command_rejected)
	router.register(&"world_frame", game_handler.on_world_frame)
