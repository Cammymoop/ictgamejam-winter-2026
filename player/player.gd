extends CharacterBody3D

@export var speed: float = 10.0
@export var bounds: Vector2 = Vector2(4, 3)  # X/Z movement limits

var target_world_position: Vector3 = Vector3.ZERO
var local_offset: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# Get camera-relative input
	#var cam_right := camera.global_transform.basis.x.normalized()
	#var cam_up := camera.global_transform.basis.y.normalized()


	var input_h := Input.get_axis("move_left", "move_right")
	var input_v := Input.get_axis("move_down", "move_up")

	# Update local offset (clamped to bounds)
	local_offset.x += input_h * speed * delta
	local_offset.y += input_v * speed * delta
	local_offset.x = clamp(local_offset.x, -bounds.x, bounds.x)
	local_offset.y = clamp(local_offset.y, -bounds.y, bounds.y)

	# Apply as local position (parent is MainCamera moving along path)
	position = local_offset

func set_target_position(world_pos: Vector3) -> void:
	target_world_position = world_pos
	var look_target := Vector3(world_pos.x, global_position.y, world_pos.z)
	if look_target.distance_to(global_position) > 0.1:
		look_at(look_target, Vector3.UP)


func _on_entity_stats_out_of_health() -> void:
	set_physics_process(false)
	visible = false

	# Try to notify game manager for proper lose screen handling
	var game_manager := _find_game_manager()
	if game_manager and game_manager.has_method("trigger_lose"):
		await get_tree().create_timer(0.5).timeout
		game_manager.trigger_lose()
	else:
		# Fallback: reload scene directly if no game manager
		await get_tree().create_timer(1).timeout
		get_tree().reload_current_scene()


## Find the GameManager in the scene tree
func _find_game_manager() -> Node:
	var root := get_tree().current_scene
	if root:
		return root.find_child("GameManager", true, false)
	return null
