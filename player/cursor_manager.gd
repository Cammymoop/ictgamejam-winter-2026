extends CanvasLayer

@onready var cursor_sprite: Sprite2D = $CursorSprite
@onready var camera: Camera3D = get_viewport().get_camera_3d()

@export var cursor_color_normal: Color = Color.LIGHT_CYAN
@export var cursor_color_enemy: Color = Color.ORANGE

var world_position: Vector3 = Vector3.ZERO
var player: CharacterBody3D = null
var weapon_manager: WeaponManager = null
var hovered_enemy: Node3D = null

var aim_cast_mask: int

func _ready() -> void:
	# Hide the default OS cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	var enemy_coll_layer: = Util.get_phys_layer_by_name("Enemies")
	assert(enemy_coll_layer != -1, "Enemy collision layer not found")
	
	var ground_coll_layer: = Util.get_phys_layer_by_name("Ground")
	assert(ground_coll_layer != -1, "Ground collision layer not found")
	aim_cast_mask = Util.layer_to_bit(enemy_coll_layer) | Util.layer_to_bit(ground_coll_layer)
	
	# Find player in scene
	await get_tree().process_frame
	player = Util.get_player_ref()
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
	var ray_origin := camera.global_position
	var ray_direction := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_direction * 2000.0

	# Perform raycast - collides with Ground (2) and Enemies (4), excludes Player (1)
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = aim_cast_mask

	var result := space_state.intersect_ray(query)
	if not result:
		return {
			"position": ray_end,
			"enemy": null
		}

	result_data.position = result.position
	var coll: CollisionObject3D = result.collider as CollisionObject3D
	if coll and coll is AnimatableBody3D:#Util.check_coll_layer(coll, "Enemies"):
		print("hovering enemy")
		result_data.enemy = coll
	elif coll:
		prints("hovering not enemy", coll.get_path())
	elif result.collider:
		prints("hovering other collider", result.collider.get_class(), result.collider.get_path())
	prints("hovering")
		
	return result_data

func _update_cursor_visual() -> void:
	if hovered_enemy:
		cursor_sprite.modulate = cursor_color_enemy
	else:
		cursor_sprite.modulate = cursor_color_normal

func _notification(what: int) -> void:
	# Restore cursor when window loses focus or game exits
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
