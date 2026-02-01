extends Node3D

var level_path: LevelPath
@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Node3D = $CameraTarget
@onready var debug_cam: Camera3D = find_child("DebugCam").get_node("Camera3D")

func _ready() -> void:
	level_path = get_node("/root/Game/World/LevelPath") as LevelPath
	if not level_path:
		print_debug("Level path not found")
		push_error("Level path not found")
		return
	
	var remote_transform = level_path.remote_transform
	var parent: = get_parent()
	remote_transform.remote_path = remote_transform.get_path_to(parent)
	parent.global_transform = remote_transform.global_transform
	
	level_path.start()

	global_position = level_path.path_follow.global_position

	await get_tree().process_frame
	camera.global_transform = camera_target.global_transform

func _process(delta: float) -> void:
	var interp_factor: = 3.4 if level_path.is_moving else 0.1
	camera.global_transform = camera.global_transform.interpolate_with(camera_target.global_transform, delta * interp_factor)
	
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
		return
		
	if Input.is_action_just_pressed("menu"):
		if Input.mouse_mode in [Input.MOUSE_MODE_CAPTURED, Input.MOUSE_MODE_HIDDEN]:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			get_tree().quit()

	set_deferred("global_basis", Basis.looking_at(level_path.look_here.global_position - global_position, Vector3.UP))
	
