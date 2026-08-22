extends Object
class_name Singleton
	
static func Get() -> Singleton:
	var msg = "必须重构Singleton的Get"
	printerr(msg)
	return null

func _init() -> void:
	init()
	
func init():
	pass
