extends RefCounted
class_name WorldFrameChanges

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

var spawned: Array[EntityState] = []
var moved: Array[EntityState] = []
var aims_changed: Array[EntityState] = []
var health_changed: Array[EntityState] = []
var events: Array[GameProto.WorldEvent] = []
var removed: Array[String] = []
var prog_changed: Array[EntityState] = []
var entity_move_paths: Array[EntityMovePathState] = []
