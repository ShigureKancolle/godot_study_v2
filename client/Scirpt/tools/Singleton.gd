extends Object
class_name Singleton

static var _instance: Singleton = null

static func Get_Ins() -> Singleton:
	return _instance
	
static func Get() -> Singleton:
	var msg = "必须重构Singleton的Get"
	printerr(msg)
	return null

func _init() -> void:
	init()
	
func init():
	pass
