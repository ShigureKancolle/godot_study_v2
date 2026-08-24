extends Object
class_name HandlerRegister

static func register():
	var router := MessageRouter.Get()
	
	router.register(&"login_accepted", LoginHandler.on_login_accepted)
