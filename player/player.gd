extends CharacterBody3D

@export var move_force: float = 18.0
@export var input_move_interp_speed: float = 44
@export var bounds: Vector2 = Vector2(4, 3)  # X/Z movement limits
@export var bounds_force: float = 14
@export var iframe_duration: float = 2.2

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var flash_animator: AnimationPlayer = $FlashAnimator

var move_velocity: Vector2 = Vector2.ZERO
var iframe_timer: Timer = null

var target_world_position: Vector3 = Vector3.ZERO
@onready var entity_stats: EntityStats = $EntityStats

func _ready() -> void:
	assert(entity_stats, "Player EntityStats not found")
	entity_stats.out_of_health.connect(_on_entity_stats_out_of_health)
	entity_stats.got_hit.connect(_on_entity_stats_got_hit)
	
	iframe_timer = Timer.new()
	iframe_timer.wait_time = iframe_duration
	iframe_timer.one_shot = true
	iframe_timer.timeout.connect(iframe_timeout)
	add_child(iframe_timer)


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

	var level_path: = get_node("/root/Game").find_child("LevelPath")
	level_path.slow_to_stop()
	await get_tree().create_timer(3).timeout
	get_tree().reload_current_scene()

func _on_entity_stats_got_hit() -> void:
	if iframe_duration > 0:
		entity_stats.can_be_hit = false
		flash_animator.play("flash")
		iframe_timer.start()

func iframe_timeout() -> void:
	entity_stats.can_be_hit = true
	flash_animator.stop()
