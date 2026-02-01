class_name EnemyBase
extends CharacterBody3D
## Base class for all enemies with common behavior including state machine,
## EntityStats integration, and player targeting.
##

signal enemy_activated
signal enemy_died

enum State { IDLE, ACTIVE, ATTACKING, DYING }

@export var detection_range: float = 50.0
@export var checkpoint_id: String = ""

@export_group("Animations")
@export var flash_animator: AnimationPlayer
@export var death_animator: AnimationPlayer

## Current state of the enemy
var state: State = State.IDLE
## Cached reference to the player node
var _player_ref: Node3D = null

## Reference to EntityStats child node
@onready var entity_stats: Node = $EntityStats  # EntityStats

@export var add_mesh_instances: Array[MeshInstance3D] = []
var mesh_instances: Array[MeshInstance3D] = []

func _ready() -> void:
	for mesh_instance in add_mesh_instances:
		if not mesh_instance:
			continue
		mesh_instances.append(mesh_instance)
	_connect_entity_stats_signals()
	# Enemies with a checkpoint_id remain IDLE until checkpoint triggers activation
	# Enemies without checkpoint_id activate based on distance (existing behavior)
	if checkpoint_id.is_empty():
		_check_distance_activation()


func _connect_entity_stats_signals() -> void:
	if entity_stats:
		if not entity_stats.got_hit.is_connected(_on_entity_stats_got_hit):
			entity_stats.got_hit.connect(_on_entity_stats_got_hit)
		if not entity_stats.out_of_health.is_connected(_on_entity_stats_out_of_health):
			entity_stats.out_of_health.connect(_on_entity_stats_out_of_health)


## Activate the enemy, transitioning from IDLE to ACTIVE state
func activate() -> void:
	if state == State.DYING:
		return
	state = State.ACTIVE
	enemy_activated.emit()


## Deactivate the enemy, returning to IDLE state
func deactivate() -> void:
	if state == State.DYING:
		return
	state = State.IDLE


## Get a reference to the player, caching it for future calls.
## Returns null if no player is found.
func target_player() -> Node3D:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref
	_player_ref = Util.get_player_ref()
	return _player_ref


## Called when EntityStats emits got_hit signal.
## Override in subclasses for custom hit effects.
func _on_entity_stats_got_hit() -> void:
	_play_hit_flash()


## Called when EntityStats emits out_of_health signal.
## Transitions to DYING state and emits enemy_died signal.
func _on_entity_stats_out_of_health() -> void:
	state = State.DYING
	enemy_died.emit()
	_play_death_anim()


func _play_hit_flash() -> void:
	if not flash_animator:
		return
	if flash_animator.is_playing():
		flash_animator.stop()
	flash_animator.play("flash")


## Play death animation or effect.
func _play_death_anim() -> void:
	if not death_animator:
		return
	if death_animator.is_playing():
		death_animator.stop()
	death_animator.play("death")
	if flash_animator and flash_animator.has_animation("flash_death"):
		flash_animator.play("flash_death")

## Returns true if this enemy is linked to a checkpoint
func has_checkpoint() -> bool:
	return not checkpoint_id.is_empty()



## Check distance and activate if player is in range (for non-checkpoint enemies)
func _check_distance_activation() -> void:
	if state != State.IDLE:
		return

	if is_player_in_range():
		activate()
	else:
		# Schedule another check next frame
		get_tree().create_timer(0.1).timeout.connect(_check_distance_activation)


## Check if the player is within detection range
func is_player_in_range() -> bool:
	var player := target_player()
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= detection_range


## Get direction to the player
func get_direction_to_player() -> Vector3:
	var player := target_player()
	if not player:
		return Vector3.ZERO
	return (player.global_position - global_position).normalized()


## Get distance to the player
func get_distance_to_player() -> float:
	var player := target_player()
	if not player:
		return INF
	return global_position.distance_to(player.global_position)


func spawn_random_impacts(num_impacts: int = 5, size_min: float = 0.7, size_max: float = 1.9) -> void:
	for i in num_impacts:
		_spawn_random_impact(size_min, size_max)

func _spawn_random_impact(size_min: float = 0.7, size_max: float = 1.9) -> bool:
	var global_aabb: = get_global_aabb_approx()
	var ray_cast_dest: = global_aabb.get_center()
	var aabb_radius: = global_aabb.get_endpoint(0).distance_to(ray_cast_dest)

	var from_dir: = Vector3.FORWARD.rotated(Vector3.RIGHT, (TAU/4) * ease(randf(), 2))
	from_dir = from_dir.rotated(Vector3.UP, randf_range(0, TAU))
	
	var ray_cast_query: = PhysicsRayQueryParameters3D.new()
	ray_cast_query.from = ray_cast_dest + from_dir * aabb_radius
	ray_cast_query.to = ray_cast_dest
	ray_cast_query.collision_mask = Util.get_phys_bitmask_from_layer_names(["Enemies"])
	ray_cast_query.hit_from_inside = true
	var ray_cast_result: = get_world_3d().direct_space_state.intersect_ray(ray_cast_query)
	
	if not ray_cast_result or not ray_cast_result.collider:
		#print_debug("No ray cast result")
		return false
	var the_collider: = ray_cast_result.collider as CollisionObject3D
	if not EntityManager.get_entity_from_coll_object(the_collider) == self:
		print("explosion impact position check hit something else: %s" % the_collider.get_path())
		return false

	var impact: = preload("res://assets/effects/impact_sphere.tscn").instantiate()
	impact.scale = Vector3.ONE * randf_range(size_min, size_max)
	get_parent().add_child(impact)
	
	impact.global_position = ray_cast_result.position
	return true


func get_global_aabb_approx() -> AABB:
	return Util.get_enclosing_aabb_of_mesh_instances_approximate(mesh_instances)

func get_global_center_approx() -> Vector3:
	return get_global_aabb_approx().get_center()