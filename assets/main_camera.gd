extends Node3D

var level_path: LevelPath
@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Node3D = $CameraTarget
@onready var debug_cam: Camera3D = find_child("DebugCam").get_node("Camera3D")

func _ready() -> void:
	# Find level path - try multiple locations to support different level scenes
	level_path = _find_level_path()
	if not level_path:
		print_debug("Level path not found")
		push_error("Level path not found")
		return

	var remote_transform = level_path.remote_transform
	remote_transform.remote_path = remote_transform.get_path_to(get_parent())

	level_path.start()

	global_position = level_path.path_follow.global_position

	camera.global_transform = camera_target.global_transform


## Find LevelPath in the scene tree - supports both world_scene and level2 structures
func _find_level_path() -> LevelPath:
	# Try standard path for world_scene
	var path := get_node_or_null("/root/Game/World/LevelPath") as LevelPath
	if path:
		return path

	# Try finding LevelPath as child of any World node
	var world := get_node_or_null("/root/Game/World")
	if world:
		var found := world.find_child("LevelPath", true, false)
		if found is LevelPath:
			return found

	# Try finding LevelPath directly under Level2 (which might be named Level2)
	var level2 := get_node_or_null("/root/Game/Level2")
	if level2:
		var found := level2.find_child("LevelPath", true, false)
		if found is LevelPath:
			return found

	# Last resort: search the entire scene tree
	var root := get_tree().current_scene
	if root:
		var found := root.find_child("LevelPath", true, false)
		if found is LevelPath:
			return found

	return null


func _process(delta: float) -> void:
	camera.global_transform = camera.global_transform.interpolate_with(camera_target.global_transform, delta * 3.4)

	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN and Input.is_action_just_pressed("shoot"):
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if Input.is_action_just_pressed("debug_switch_cam"):
		if debug_cam.current:
			debug_cam.current = false
			camera.current = true
		else:
			debug_cam.current = true
			camera.current = false

	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()

	if Input.is_action_just_pressed("menu"):
		if Input.mouse_mode in [Input.MOUSE_MODE_CAPTURED, Input.MOUSE_MODE_HIDDEN]:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			get_tree().quit()

	if level_path and level_path.look_here:
		set_deferred("global_basis", Basis.looking_at(level_path.look_here.global_position - global_position, Vector3.UP))
	
