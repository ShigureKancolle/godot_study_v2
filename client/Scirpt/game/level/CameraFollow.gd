extends Camera2D

# 平滑跟随系数 0不动 1瞬移
@export_range(0, 1) var follow_smoothing: float = 0.02


var target_player_id: String = ""
var has_aligned_to_target: bool = false

func _ready() -> void:
	target_player_id = GameBootstrap.game_store.self_entity_id
	
	
func _process(_delta: float) -> void:
	var map_node := get_parent() as TestLevel
	if map_node == null:
		return


	var player_node: EntityView = map_node.entity_views.get(target_player_id, null)
	if player_node == null:
		return

	#if not player_node.is_instance_valid(): 
		#return
		
	if player_node.is_queued_for_deletion():
		return

	
	var target_pos := player_node.global_position
	if not has_aligned_to_target:
		global_position = target_pos
		has_aligned_to_target = true
		return

	global_position = lerp(global_position, target_pos, follow_smoothing)
