extends Object
class_name HandlerRegister

static func register(game_handler: GameHandler):
	var router := MessageRouter.Get()
	
	router.register(&"login_accepted", LoginHandler.on_login_accepted)
	router.register(&"world_snapshot", game_handler.on_world_snapshot)
	router.register(&"movement_frame", game_handler.on_movement_frame)
	router.register(&"entity_spawned", game_handler.on_entity_spawned)
	router.register(&"entity_removed", game_handler.on_entity_removed)
	router.register(&"command_rejected", game_handler.on_command_rejected)
	router.register(&"attack_start", game_handler.on_attack_start)
