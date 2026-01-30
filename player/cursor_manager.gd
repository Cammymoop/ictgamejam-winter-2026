extends CanvasLayer

@onready var cursor_sprite: Sprite2D = $CursorSprite
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var world_position: Vector3 = Vector3.ZERO
var player: CharacterBody3D = null
var weapon_manager: WeaponManager = null
var hovered_enemy: Node = null

# Collision layer bitmasks (layer N has bitmask value 2^(N-1))
const LAYER_PLAYER := 1    # Layer 1
const LAYER_GROUND := 2    # Layer 2
const LAYER_ENEMIES := 4   # Layer 3
const LAYER_PROJECTILES := 8  # Layer 4

func _ready() -> void:
	# Hide the default OS cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Find player in scene
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		weapon_manager = player.get_node_or_null("WeaponManager")

func _process(_delta: float) -> void:
	# Move 2D cursor sprite to mouse position
	var mouse_pos := get_viewport().get_mouse_position()
	cursor_sprite.global_position = mouse_pos

	# Raycast from camera through mouse position to find 3D world position
	var result := raycast_to_world(mouse_pos)
	world_position = result.position
	hovered_enemy = result.enemy

	# Update cursor visual based on hover state
	_update_cursor_visual()

	# Update player with target position
	if player and player.has_method("set_target_position"):
		player.set_target_position(world_position)

	# Update weapon manager with target position
	if weapon_manager:
		weapon_manager.set_target(world_position)

func raycast_to_world(screen_pos: Vector2) -> Dictionary:
	var result_data := { "position": Vector3.ZERO, "enemy": null }

	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return result_data

	# Get ray origin and direction from camera
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_direction := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_direction * 1000.0

	# Perform raycast - collides with Ground (2) and Enemies (4), excludes Player (1)
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = LAYER_GROUND | LAYER_ENEMIES  # Ground + Enemies

	var result := space_state.intersect_ray(query)

	if result:
		result_data.position = result.position
		# Check if we hit an enemy
		var collider = result.collider
		if collider and collider.is_in_group("enemies"):
			result_data.enemy = collider
		return result_data

	# Fallback: intersect with Y=0 plane if no collision
	if ray_direction.y != 0:
		var t := -ray_origin.y / ray_direction.y
		if t > 0:
			result_data.position = ray_origin + ray_direction * t

	return result_data

func _update_cursor_visual() -> void:
	if hovered_enemy:
		cursor_sprite.modulate = Color.RED
	else:
		cursor_sprite.modulate = Color.WHITE

func _notification(what: int) -> void:
	# Restore cursor when window loses focus or game exits
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
