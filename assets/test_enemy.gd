extends Node3D

var projectile_scene: PackedScene = preload("res://assets/new_projectile.tscn")

@export var shoot_from: Node3D = null

@export var show_warning_time: float = 0.3

@export var move_speed: float = 4
@export var fire_rate: float = 0.8
@export var delay_ratio: float = 0.2
@export var delay_base_time: float = 1.4
@export var active_distance: float = 57

@export var show_before_shoot: Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var bullet_speed: float = 90
@export var bullet_lifetime: float = 6
@export var bullet_color: Color = Color.ORANGE

@export var innacuracy: float = TAU / 32

@export var show_debug_path: bool = false

var player_ref: Node3D = null

var delay_timer: Timer = null
var is_shooting: bool = false
var is_reloading: bool = true
var reload_timeleft: float = 0

var is_enabled: bool = true
var is_active: bool = false

func _ready() -> void:
	if show_before_shoot:
		show_before_shoot.visible = false
	
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
	reload_timeleft = show_warning_time
	delay_timer.wait_time = delay_base_time * randf_range(.8, 1.5)
	delay_timer.start()

func delay_over() -> void:
	is_shooting = true

func _process(delta: float) -> void:
	if show_before_shoot:
		show_before_shoot.visible = false
	if not is_enabled:
		return
	
	var player_distance = global_position.distance_to(player_ref.global_position)
	if not is_active:
		if player_distance < active_distance:
			is_active = true
			random_delay()
	elif player_distance > active_distance + 5:
		is_active = false
	
	if not is_shooting:
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
	fire_dir = fire_dir.rotated(fire_basis.x, randf_range(0, innacuracy))
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
	animation_player.play("flash")

func _on_entity_stats_out_of_health() -> void:
	queue_free()
