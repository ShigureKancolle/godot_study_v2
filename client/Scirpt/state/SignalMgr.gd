extends Singleton
class_name SignalMgr

static var _instance: SignalMgr = null

static func Get_Ins() -> SignalMgr:
	return _instance

static func Get() -> SignalMgr:
	if not _instance:
		_instance = SignalMgr.new()
	return _instance
	
# 信号注册前缀 snl_
# handel前缀 hdl_
signal snl_on_login_accepted(acc: String, name: String)
