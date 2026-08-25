extends Node2D
class_name Role

const PALYER_VISUAL_SCENE := preload("res://Prefab/Role/PlayerVisual.tscn")
const LOCAL_PLAYER_CONTROLLER_SCRIPT := preload("res://Scirpt/game/controller/LocalPlayerController.gd")

const POSITION_LERP_SPEED := 15.0
var entity_id: String = ""
var player_visual: PlayerVisual = null
var entity_state: EntityState = null
var local_player_controller: LocalPlayerController = null
var target_position: Vector2 = Vector2.ZERO

func _ready():
	pass

func setup(state: EntityState):
	self.entity_id = state.entity_id
	self.entity_state = state
	self.position = entity_state.server_position
	self.target_position = entity_state.server_position
	if state.entity_type == EntityState.EntityType.PLAYER:
		self.player_visual = PALYER_VISUAL_SCENE.instantiate()
		self.add_child(self.player_visual)
		self.player_visual.setup(state)

		if self.entity_id == GameBootstrap.game_store.self_entity_id:
			self.local_player_controller = LOCAL_PLAYER_CONTROLLER_SCRIPT.new()
			self.add_child(self.local_player_controller)
			self.local_player_controller.setup(self.entity_id)

func apply_entity_state(state: EntityState):
	self.entity_state = state
	self.position = state.server_position
	self.player_visual.setup(state)

func apply_moved(state: EntityState):
	self.entity_state = state
	self.target_position = state.server_position

	if player_visual:
		player_visual.apply_moved(state)

func _process(delta: float):
	var alpha := 1.0 - exp(
		-POSITION_LERP_SPEED * delta
	)

	self.position = self.position.lerp(target_position, alpha)
