class_name EnemyBase
extends CharacterBody3D
## Base class for all enemies with common behavior including state machine,
## EntityStats integration, and player targeting.
##

signal enemy_activated
signal enemy_died

enum State { IDLE, ACTIVE, ATTACKING, DYING }

## Common enemy properties
@export var move_speed: float = 4.0
@export var attack_range: float = 10.0
@export var detection_range: float = 50.0
## Optional checkpoint ID - if set, enemy starts IDLE and waits for checkpoint activation
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
		_start_distance_based_activation()


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


## Get the cached player reference without refreshing
func get_player_ref() -> Node3D:
	return target_player()


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


## Start distance-based activation monitoring for enemies not linked to checkpoints
func _start_distance_based_activation() -> void:
	# Use a deferred call to allow scene tree setup
	call_deferred("_check_distance_activation")


## Check distance and activate if player is in range (for non-checkpoint enemies)
func _check_distance_activation() -> void:
	if state != State.IDLE:
		return
	if has_checkpoint():
		return  # Checkpoint-linked enemies don't use distance activation

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


## Check if the player is within attack range
func is_player_in_attack_range() -> bool:
	var player := target_player()
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= attack_range


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
