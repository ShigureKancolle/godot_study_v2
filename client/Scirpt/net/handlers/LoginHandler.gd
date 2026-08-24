extends Object
class_name LoginHandler

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

static func on_login_accepted(msg: GameProto.ServerMessage):
	var login_accepted = msg.get_login_accepted()
	var acc = login_accepted.get_account()
	var name = login_accepted.get_player_name()
	
	print("登录成功, account: ", login_accepted.get_account(), "  name: ",login_accepted.get_player_name())
	SignalMgr.Get().snl_on_login_accepted.emit(acc, name)
