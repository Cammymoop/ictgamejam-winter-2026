extends Node3D
class_name LevelPath

@export var remote_transform: RemoteTransform3D
@onready var path_3d: Path3D = $Path3D
@onready var path_follow: PathFollow3D = path_3d.get_node("PathFollow3D")

@export var base_speed: float = 4

var delay_time: float = 1.4
var total_length: float = 0

var is_moving: bool = false

func start() -> void:
    var delay_timer = Timer.new()
    delay_timer.wait_time = delay_time
    delay_timer.one_shot = true
    delay_timer.autostart = true
    delay_timer.timeout.connect(start_moving)
    add_child(delay_timer)
    delay_timer.start()
    
    total_length = path_3d.curve.get_baked_length()

func start_moving() -> void:
    print_debug("Starting movement")
    path_follow.progress = 0
    is_moving = true

func _process(delta: float) -> void:
    if not is_moving:
        return

    path_follow.progress += delta * base_speed
    if path_follow.progress_ratio >= 1:
        is_moving = false