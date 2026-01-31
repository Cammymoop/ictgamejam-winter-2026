extends Node3D

var projectile_scene: PackedScene = preload("res://assets/new_projectile.tscn")

@export var shoot_from: Node3D = null

@export var show_warning_time: float = 0.3

@export var move_speed: float = 4
@export var fire_rate: float = 0.8
@export var delay_ratio: float = 0.2
@export var delay_base_time: float = 1.4
@export var active_distance: float = 57

@export var use_shield: bool = true

@export var show_before_shoot: Node3D
@onready var flash_animator: AnimationPlayer = find_child("FlashAnimator")
@onready var active_animator: AnimationPlayer = find_child("ActiveAnimator")

@onready var shield_mesh: MeshInstance3D = find_child("Shield")
@onready var shield_collider: CollisionShape3D = shield_mesh.find_child("CollisionShape3D")

@onready var shake_offset: Node3D = find_child("Shake")

@export var bullet_speed: float = 90
@export var bullet_lifetime: float = 6
@export var bullet_color: Color = Color.ORANGE

@export var innacuracy: float = TAU / 32
@export_exp_easing var innacuracy_curve_param: float

@export var shake_strength: float = 0.2

@export var active_check_interval: float = 0.5

@export var show_debug_path: bool = false

var active_check_timer: Timer = null
var active_check_waiting: bool = false

var player_ref: Node3D = null
var entity_stats: EntityStats = null

var delay_timer: Timer = null
var is_shooting: bool = false
var is_reloading: bool = true
var reload_timeleft: float = 0

var is_enabled: bool = true
var is_active: bool = false
var is_shaking: bool = false

func _ready() -> void:
	if show_before_shoot:
		show_before_shoot.visible = false
show_before_shoot.material_override.albedo_color = bullet_color

    show_warning_time = minf(show_warning_time, (1 / fire_rate) * 0.75)

    active_animator.animation_finished.connect(_on_active_animator_animation_finished)
	delay_timer = Timer.new()
	delay_timer.one_shot = true
	delay_timer.timeout.connect(delay_over)
	add_child(delay_timer)

	active_check_timer = Timer.new()
    active_check_timer.wait_time = active_check_interval
    active_check_timer.one_shot = false
    active_check_timer.timeout.connect(active_check_ready)
    add_child(active_check_timer)

    entity_stats = $EntityStats
    if use_shield:
        entity_stats.check_can_be_hit = can_enemy_be_hitplayer_ref = Util.get_player_ref()
	if not player_ref:
		disable()else:
        var starting_active: = true
        if player_ref.global_position.distance_to(global_position) < active_distance:
            try_activate()
            if active_check_waiting:
                starting_active = false
        else:
            starting_active = false

        if not starting_active:
            active_animator.play("RESET_inactive")

func can_enemy_be_hit() -> bool:
    return not is_shield_active()

func is_shield_active() -> bool:
    return shield_mesh.visible

func turn_on_shield() -> void:
    shield_mesh.visible = true
    shield_collider.set_deferred("disabled", false)

func turn_off_shield() -> void:
    shield_mesh.visible = false
    shield_collider.set_deferred("disabled", true)

func disable() -> void:
	is_enabled = false
	set_process(false)

func random_delay() -> void:
	is_shooting = false
	is_reloading = true
	reload_timeleft = show_warning_time
	delay_timer.wait_time = delay_base_time * randf_range(.8, 1.5)
	delay_timer.start()

func delay_over() -> void:
	is_shooting = true

func active_check_ready() -> void:
    active_check_waiting = false

func try_activate(recheck: bool = false) -> void:
    if is_active and not recheck:
        return

    var los_checker: = find_child("LineOfSightChecker") as ShapeCast3D
    if not los_checker and not is_active:
        print_debug("This enemy has no line of sight checker")
        activate()
        return

    if show_debug_path and not los_checker.visible:
        los_checker.visible = true

    los_checker.enabled = true
    los_checker.target_position = los_checker.to_local(player_ref.global_position)
    los_checker.force_shapecast_update()

    if los_checker.is_colliding():
        if is_active:
            deactivate()
        active_check_waiting = true
        active_check_timer.start()
    else:
        activate()


func activate() -> void:
    active_animator.play("activate")

func _on_active_animator_animation_finished(anim_name: String) -> void:
    if not is_active and anim_name == "activate":
        activate_done()

func activate_done() -> void:
    active_check_waiting = false
    is_active = true
    random_delay()

func deactivate() -> void:
    is_active = false
    active_animator.play("deactivate")

func _process(delta: float) -> void:
	if show_before_shoot:
		show_before_shoot.visible = false
	if not is_enabled:
		return

	var player_distance = global_position.distance_to(player_ref.global_position)
	if not is_active:
		if player_distance < active_distanceand not active_check_waiting:
			try_activate()
	elif player_distance > active_distance + 5:
		deactivate()

	if not is_shootingor not is_active:
		return

	if is_reloading:
		reload_timeleft -= delta
		if show_before_shoot:
			show_before_shoot.visible = reload_timeleft < show_warning_time
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
	var start_pos = global_position
	if shoot_from:
		start_pos = shoot_from.global_position

	var dist_to_player = start_pos.distance_to(player_ref.global_position)
	var player_pos_estimated = player_ref.global_position + (Global.player_velocity * (dist_to_player / bullet_speed))

	var projectile = projectile_scene.instantiate()
	projectile.set_color(bullet_color)
	projectile.speed = bullet_speed
	projectile.is_enemy_projectile = true
	var fire_dir: = (player_pos_estimated - start_pos).normalized()
	var fire_basis: = Basis.looking_at(fire_dir, Vector3.UP)
	fire_dir = fire_dir.rotated(fire_basis.x, ease(randf(), innacuracy_curve_param) * innacuracy)
	fire_dir = fire_dir.rotated(fire_basis.z, randf_range(0, TAU))

	projectile.set_direction(fire_dir)

	projectile.damage = 1

	get_parent().add_child(projectile)
	projectile.global_position = start_pos

	if show_debug_path:
		draw_debug_path(start_pos, player_pos_estimated)

func draw_debug_path(start_pos: Vector3, end_pos: Vector3) -> void:
	var debug_path: = Path3D.new()
	debug_path.curve = Curve3D.new()
	for point in [start_pos, end_pos]:
		debug_path.curve.add_point(point)
	get_node("/root/Game").add_child(debug_path)
	await get_tree().create_timer(8).timeout
	debug_path.queue_free()

func _on_entity_stats_got_hit() -> void:
	flash_animator.play("flash")

func _on_entity_stats_out_of_health() -> void:
	queue_free()
