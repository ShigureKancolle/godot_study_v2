extends Object
class_name HandlerRegister

static func register(game_handler: GameHandler):
	var router := MessageRouter.Get()
	
	router.register(&"login_accepted", LoginHandler.on_login_accepted)
	router.register(&"world_snapshot", game_handler.on_world_snapshot)
	router.register(&"command_rejected", game_handler.on_command_rejected)
	router.register(&"world_frame", game_handler.on_world_frame)
	router.register(&"level_debug_data", game_handler.on_level_debug)
	router.register(&"cur_game_speed", game_handler.on_cur_game_speed)
