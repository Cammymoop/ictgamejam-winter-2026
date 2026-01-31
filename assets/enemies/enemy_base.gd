class_name EnemyBase
extends CharacterBody3D
## Base class for all enemies with common behavior including state machine,
## EntityStats integration, and player targeting.
##
## === BALANCE DOCUMENTATION ===
## Base class defaults - subclasses override with specific balanced values.
## Player Context: 5 HP, speed 10.0, bounds 4x3 units
##
## DEFAULT VALUES (for reference, typically overridden):
## - move_speed: 4.0 (base movement, subclasses set their own)
## - attack_range: 10.0 (default engagement distance)
## - detection_range: 50.0 (when enemy becomes aware of player)
##
## ENEMY HEALTH (set in EntityStats child nodes in .tscn files):
## - Recommend 3-5 HP for standard enemies (1-2 weapon hits to kill)
## - Higher HP enemies should have longer attack cooldowns as compensation
##
## WAVE TIMING TARGET: 15-30 seconds per checkpoint wave
## SURVIVAL TARGET: Skilled player should survive first attempt with 50%+ HP
## =========================

signal enemy_activated
signal enemy_died

enum State { IDLE, ACTIVE, ATTACKING, DYING }

## Common enemy properties
@export var move_speed: float = 4.0
@export var attack_range: float = 10.0
@export var detection_range: float = 50.0

## Optional checkpoint ID - if set, enemy starts IDLE and waits for checkpoint activation
@export var checkpoint_id: String = ""

## Current state of the enemy
var state: State = State.IDLE

## Cached reference to the player node
var _player_ref: Node3D = null

## Reference to EntityStats child node
@onready var entity_stats: EntityStats = $EntityStats


func _ready() -> void:
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
	_play_death_effect()


## Play a visual hit flash effect.
## Override in subclasses for custom flash behavior.
func _play_hit_flash() -> void:
	# Default implementation uses a tween on material if available
	var mesh_instance := _find_mesh_instance()
	if not mesh_instance:
		return

	var material := mesh_instance.get_surface_override_material(0)
	if not material or not material is StandardMaterial3D:
		return

	var std_mat := material as StandardMaterial3D
	var original_emission := std_mat.emission
	var original_enabled := std_mat.emission_enabled

	std_mat.emission_enabled = true
	std_mat.emission = Color.WHITE

	var tween := create_tween()
	tween.tween_property(std_mat, "emission", original_emission, 0.3)
	tween.tween_callback(func(): std_mat.emission_enabled = original_enabled)


## Find the first MeshInstance3D child for visual effects
func _find_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null


## Play death animation or effect.
## Override in subclasses for custom death behavior.
func _play_death_effect() -> void:
	# Default implementation: queue_free after a short delay
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(queue_free)


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
