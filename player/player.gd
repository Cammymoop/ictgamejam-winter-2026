extends CharacterBody3D

@export var move_force: float = 18.0
@export var input_move_interp_speed: float = 44
@export var bounds: Vector2 = Vector2(4, 3)  # X/Z movement limits
@export var bounds_force: float = 14
@export var iframe_duration: float = 2.2

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var flash_animator: AnimationPlayer = $FlashAnimator
@onready var weapon_manager: WeaponManager = $WeaponManager

var move_velocity: Vector2 = Vector2.ZERO
var iframe_timer: Timer = null

var target_world_position: Vector3 = Vector3.ZERO
@onready var entity_stats: EntityStats = $EntityStats

var destroyed_waves: int = 0

var won_screen_on: bool = false

var ready_to_aim: bool = false

func _ready() -> void:
	assert(entity_stats, "Player EntityStats not found")
	entity_stats.out_of_health.connect(_on_entity_stats_out_of_health)
	entity_stats.got_hit.connect(_on_entity_stats_got_hit)
	
	iframe_timer = Timer.new()
	iframe_timer.wait_time = iframe_duration
	iframe_timer.one_shot = true
	iframe_timer.timeout.connect(iframe_timeout)
	add_child(iframe_timer)
	
	EntityManager.entity_removed.connect(_on_entity_removed.unbind(1))

func _on_entity_removed() -> void:
	if not is_inside_tree():
		return
	if EntityManager.are_all_entities_required_destroy():
		destroyed_waves += 1
		if destroyed_waves > 1:
			if not won_screen_on:
				won_screen_on = true
				print_debug("Showing won screen")
				show_won_screen()
		else:
			print_debug("Spawning next wave")
			var spawner = get_node("/root/Game").current_world.get_node("SpecialSpawner")
			if spawner:
				spawner.do_spawn()

func show_won_screen() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.8).timeout
	var win_screen: = get_node("/root/Game/WinLayer") as CanvasLayer
	win_screen.show()

func _physics_process(delta: float) -> void:
	var local_offset: = get_local_offset()
	var bounds_force_vec: = Vector2.ZERO
	bounds_force_vec.x = -(minf(local_offset.x + bounds.x, 0) + maxf(local_offset.x - bounds.x, 0))
	bounds_force_vec.y = -(minf(local_offset.y + bounds.y, 0) + maxf(local_offset.y - bounds.y, 0))

	var input_vec: = Input.get_vector("move_left", "move_right", "move_down", "move_up")
	if bounds_force_vec.x != 0:
		if signf(input_vec.x) != signf(bounds_force_vec.x):
			input_vec.x = 0
	if bounds_force_vec.y != 0:
		if signf(input_vec.y) != signf(bounds_force_vec.y):
			input_vec.y = 0
	move_velocity = move_velocity.move_toward(input_vec * move_force, input_move_interp_speed * delta)
	move_velocity += bounds_force_vec * bounds_force * delta

	set_local_offset(local_offset + move_velocity * delta)

func set_local_offset(local_offset: Vector2) -> void:
	position = Vector3(local_offset.x, local_offset.y, position.z)

func get_local_offset() -> Vector2:
	return Vector2(position.x, position.y)

func set_target_position(world_pos: Vector3) -> void:
	target_world_position = world_pos
	if not ready_to_aim:
		return
	var look_target := Vector3(world_pos.x, global_position.y, world_pos.z)
	if look_target.distance_to(global_position) > 0.1:
		look_at(look_target, Vector3.UP)


func _on_entity_stats_out_of_health() -> void:
	set_physics_process(false)
	visible = false
	collision_shape.set_deferred("disabled", true)
	for i in 10:
		var impact := preload("res://assets/effects/impact_sphere.tscn").instantiate()
		impact.scale = Vector3.ONE * randf_range(0.5, 0.65)
		impact.position = position + Vector3(randf_range(-0.3, 0.3), randf_range(-1, 1), 0)
		var parent: = get_parent()
		var s_timer: = get_tree().create_timer(randf_range(0.01, 0.5))
		s_timer.timeout.connect(func(): parent.add_child(impact))

	var level_path: = get_node("/root/Game").current_world.get_node("LevelPath") as LevelPath
	level_path.slow_to_stop()
	await get_tree().create_timer(3).timeout
	get_tree().reload_current_scene()

func _on_entity_stats_got_hit() -> void:
	if iframe_duration > 0:
		entity_stats._can_be_hit = false
		flash_animator.play("flash")
		iframe_timer.start()

func iframe_timeout() -> void:
	entity_stats._can_be_hit = true
	flash_animator.stop()
