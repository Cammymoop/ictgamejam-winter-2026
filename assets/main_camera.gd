extends Node3D

var level_path: LevelPath
@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Node3D = $CameraTarget
@onready var debug_cam: Camera3D = find_child("DebugCam").get_node("Camera3D")

@onready var starting_basis: Basis = global_basis

var main_game: Node3D

func _ready() -> void:
    main_game = get_node("/root/Game")
    main_game.loaded_new_world.connect(on_world_loaded)
    
    on_world_loaded()


func on_world_loaded() -> void:
    level_path = main_game.current_world.get_node("LevelPath") as LevelPath
    assert(level_path, "Level path not found")
    global_basis = starting_basis
    
    var remote_transform = level_path.remote_transform
    var parent: = get_parent()
    remote_transform.remote_path = remote_transform.get_path_to(parent)
    parent.global_position = remote_transform.global_position
    
    level_path.start()

    global_position = level_path.path_follow.global_position
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

    global_basis = Basis.looking_at(level_path.look_here.global_position - global_position, Vector3.UP)
    

