extends Node3D

var projectile_scene: PackedScene = preload("res://assets/enemies/test_projectile.tscn")

@export var move_speed: float = 4
@export var fire_rate: float = 0.8
@export var delay_ratio: float = 0.2
@export var delay_base_time: float = 1.4
@export var active_distance: float = 57

var player_ref: Node3D = null

var delay_timer: Timer = null
var is_shooting: bool = false
var is_reloading: bool = true
var reload_timeleft: float = 0

var is_enabled: bool = true
var is_active: bool = false

func _ready() -> void:
    delay_timer = Timer.new()
    delay_timer.one_shot = true
    delay_timer.timeout.connect(delay_over)
    add_child(delay_timer)
    
    player_ref = Util.get_player_ref()
    if not player_ref:
        disable()

func disable() -> void:
    is_enabled = false
    set_process(false)

func random_delay() -> void:
    is_shooting = false
    is_reloading = true
    reload_timeleft = 0
    delay_timer.wait_time = delay_base_time * randf_range(.8, 1.5)
    delay_timer.start()

func delay_over() -> void:
    is_shooting = true

func _process(delta: float) -> void:
    if not is_enabled:
        return
    
    var player_distance = global_position.distance_to(player_ref.global_position)
    if not is_active:
        if player_distance < active_distance:
            is_active = true
            random_delay()
            print_debug("Activating, player distance: %s" % player_distance)
    elif player_distance > active_distance + 5:
        is_active = false
        print_debug("Deactivating, player distance: %s" % player_distance)
    
    if not is_shooting:
        return
    
    if is_reloading:
        reload_timeleft -= delta
        if reload_timeleft <= 0:
            is_reloading = false
            return
    
    if is_shooting and not is_reloading:
        fire()
        if randf() < delay_ratio:
            random_delay()
        else:
            reload_timeleft = 1 / fire_rate
            is_reloading = true

func fire() -> void:
    var projectile = projectile_scene.instantiate()
    get_parent().add_child(projectile)
    projectile.look_at_from_position(global_position, player_ref.global_position, Vector3.UP)
