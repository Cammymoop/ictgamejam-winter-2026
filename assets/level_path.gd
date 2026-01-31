extends Node3D
class_name LevelPath

@export var remote_transform: RemoteTransform3D
@onready var path_3d: Path3D = $Path3D
@onready var path_follow: PathFollow3D = path_3d.get_node("PathFollow3D")

@onready var look_here: Node3D = $LookHere

@export var base_speed: float = 4
var now_speed: float = 0

var delay_time: float = 1.4
var total_length: float = 0

var is_moving: bool = false

var is_stopping: bool = false

func _ready() -> void:
    SplineMath.update_cardinal_spline_curve3d(path_3d.curve, 0.5)


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
    
    if is_stopping:
        now_speed -= now_speed * delta * 2.5
        if now_speed <= 0.2:
            is_moving = false

    var old_pos: Vector3 = path_follow.global_position

    path_follow.progress += delta * now_speed
    if path_follow.progress_ratio >= 1:
        is_moving = false
    
    if not is_stopping and now_speed < base_speed:
        now_speed = min(now_speed + delta * 2.5, base_speed)
    
    if old_pos.distance_squared_to(path_follow.global_position) > 0.01:
        Global.player_velocity = (path_follow.global_position - old_pos) / delta
    else:
        Global.player_velocity = Vector3.ZERO

func slow_to_stop() -> void:
    is_stopping = true