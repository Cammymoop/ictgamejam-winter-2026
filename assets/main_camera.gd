extends Node3D

var level_path: LevelPath
@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Node3D = $CameraTarget

func _ready() -> void:
    camera.global_transform = camera_target.global_transform
    level_path = get_node("/root/Game/World/LevelPath") as LevelPath
    if not level_path:
        print_debug("Level path not found")
        push_error("Level path not found")
        return
    
    var remote_transform = level_path.remote_transform
    remote_transform.remote_path = remote_transform.get_path_to(self)
    
    level_path.start()

func _process(delta: float) -> void:
    camera.global_transform = camera.global_transform.interpolate_with(camera_target.global_transform, delta * 1.4)
    

