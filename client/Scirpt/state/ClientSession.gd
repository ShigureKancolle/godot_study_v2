extends Singleton
class_name ClientSession
static var _instance: ClientSession = null

static func Get_Ins() -> ClientSession:
	return _instance

static func Get() -> ClientSession:
	if not _instance:
		_instance = ClientSession.new()
	return _instance


var account: String = ""
var player_name: String = ""

func on_login_accepted(acc: String, name: String):
	account = acc
	player_name = name
	
	
