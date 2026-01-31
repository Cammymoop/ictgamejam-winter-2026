class_name ExplodingEnemy
extends EnemyBase
## An enemy that rushes toward the player and detonates when close or when killed.
## Deals area damage to the player (not other enemies).
##
## === BALANCE DOCUMENTATION ===
## Design Goal: Threatening but dodgeable with WASD movement
## Player Context: 5 HP, speed 10.0, bounds 4x3 units
##
## FINAL BALANCED VALUES:
## - move_speed: 6.0 (slower than player speed 10.0, giving ~40% speed advantage to dodge)
## - explosion_radius: 4.0 (reduced from 5.0 to give more escape room within 4x3 bounds)
## - explosion_damage: 2.0 (40% of player HP - punishing but survivable with 2 mistakes)
## - warning_time: 0.7s (increased from 0.5s for clearer audio/visual telegraph)
## - desperation_speed: 9.0 effective (1.5x at low HP, still slower than player)
##
## Counterplay: Player can kite sideways, prioritize killing before detonation range,
## or use the 0.7s warning flash to dash away. Audio tick speeds up as proximity warning.
## =========================

signal exploded

## Explosion properties
@export var explosion_radius: float = 4.0
@export var explosion_damage: float = 2.0
@export var warning_time: float = 0.7

## Note: move_speed inherited from EnemyBase, default 6.0 set in _ready()

## Desperation behavior: speed multiplier when health is low
@export var desperation_speed_multiplier: float = 1.5
## Health percentage below which desperation kicks in (0.0 to 1.0)
@export var desperation_threshold: float = 0.5

## Ground Y position for keeping enemy grounded
@export var ground_y: float = 0.0

## Track if explosion sequence has started
var _is_exploding: bool = false

## Reference to NavigationAgent3D if available
var _nav_agent: NavigationAgent3D = null

## Reference to the explosion effect scene
var _explosion_effect_scene: PackedScene = preload("res://assets/effects/impact_sphere.tscn")

## Audio: ticking sound player (attached to this enemy)
var _tick_player: AudioStreamPlayer3D = null
## Cached tick sound
var _tick_sound: AudioStreamWAV = null
## Cached boom sound
var _boom_sound: AudioStreamWAV = null
## Timer for tick interval
var _tick_timer: float = 0.0
## Base tick interval (gets faster as we approach)
var _base_tick_interval: float = 0.5


func _ready() -> void:
	# Set ExplodingEnemy's higher move_speed (rushing behavior)
	move_speed = 6.0
	super._ready()
	# Try to find NavigationAgent3D child for pathfinding
	_nav_agent = find_child("NavigationAgent3D", false, false) as NavigationAgent3D
	# Initialize ground Y to current position
	ground_y = global_position.y
	# Initialize audio
	_setup_audio()


func _physics_process(delta: float) -> void:
	if state != State.ACTIVE or _is_exploding:
		return

	_move_toward_player(delta)
	_check_explosion_trigger()
	_update_tick_sound(delta)


## Calculate the effective speed including desperation boost
func _get_effective_speed() -> float:
	var base_speed := move_speed

	# Apply desperation speed boost when health is low
	if entity_stats:
		var health_percent := entity_stats.health / entity_stats.max_health
		if health_percent <= desperation_threshold:
			# Linear interpolation: more damage = more speed boost
			# At 0% health, full multiplier; at threshold, no multiplier
			var desperation_factor := 1.0 - (health_percent / desperation_threshold)
			var multiplier := 1.0 + (desperation_speed_multiplier - 1.0) * desperation_factor
			base_speed *= multiplier

	return base_speed


## Move toward the player at high speed
func _move_toward_player(_delta: float) -> void:
	var direction := _get_movement_direction()
	if direction == Vector3.ZERO:
		return

	# Calculate effective speed with desperation boost
	var effective_speed := _get_effective_speed()

	# Set velocity and move
	velocity = direction * effective_speed
	move_and_slide()

	# Keep Y position grounded
	var pos := global_position
	pos.y = ground_y
	global_position = pos

	# Face the movement direction
	_face_movement_direction(direction)


## Get the movement direction, using NavigationAgent3D if available
func _get_movement_direction() -> Vector3:
	# Try navigation agent first if available and nav mesh exists
	if _nav_agent and _nav_agent.is_navigation_finished() == false:
		var next_pos := _nav_agent.get_next_path_position()
		var direction := (next_pos - global_position).normalized()
		# Keep movement on XZ plane
		direction.y = 0
		return direction.normalized() if direction.length() > 0.01 else Vector3.ZERO

	# Update navigation target if we have an agent
	if _nav_agent:
		var player := target_player()
		if player:
			_nav_agent.target_position = player.global_position

	# Fall back to direct movement
	var direction := get_direction_to_player()
	# Keep movement on XZ plane
	direction.y = 0
	return direction.normalized() if direction.length() > 0.01 else Vector3.ZERO


## Rotate to face the movement direction
func _face_movement_direction(direction: Vector3) -> void:
	if direction.length_squared() < 0.001:
		return

	# Calculate the target rotation on the Y axis (horizontal plane)
	var target_rotation := atan2(direction.x, direction.z)

	# Smoothly interpolate rotation for fluid movement
	rotation.y = lerp_angle(rotation.y, target_rotation, 0.2)


## Check if we should trigger the explosion
func _check_explosion_trigger() -> void:
	var distance := get_distance_to_player()
	if distance <= explosion_radius:
		_start_explosion_sequence()


## Start the warning sequence before exploding
func _start_explosion_sequence() -> void:
	if _is_exploding:
		return

	_is_exploding = true
	_play_warning_flash()

	# Wait for warning time then explode
	var tween := create_tween()
	tween.tween_interval(warning_time)
	tween.tween_callback(explode)


## Play a warning flash animation before explosion
func _play_warning_flash() -> void:
	var mesh_instance := _find_mesh_instance()
	if not mesh_instance:
		return

	var material: StandardMaterial3D = _get_mesh_material(mesh_instance)
	if not material:
		return

	# Flash rapidly during warning time
	material.emission_enabled = true
	var tween := create_tween()
	tween.set_loops(int(warning_time / 0.1))  # Flash every 0.1s
	tween.tween_property(material, "emission", Color.WHITE, 0.05)
	tween.tween_property(material, "emission", Color.RED, 0.05)


## Get the material from a mesh instance, checking material_override first
func _get_mesh_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance.material_override and mesh_instance.material_override is StandardMaterial3D:
		return mesh_instance.material_override as StandardMaterial3D
	if mesh_instance.get_surface_override_material(0) is StandardMaterial3D:
		return mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	return null


## Trigger the explosion, dealing damage to the player if in range
func explode() -> void:
	if not is_inside_tree():
		return

	# Play explosion sound
	_play_boom()

	# Spawn explosion visual effect
	_spawn_explosion_effect()

	# Deal damage to player if in range
	_damage_player_in_radius()

	# Emit signal before destruction
	exploded.emit()

	# Self-destruct
	queue_free()


## Spawn the explosion visual effect
func _spawn_explosion_effect() -> void:
	var effect := _explosion_effect_scene.instantiate() as Node3D
	if effect:
		# Scale up the effect for explosion
		effect.scale = Vector3.ONE * (explosion_radius / 2.0)
		var parent := get_tree().current_scene if get_tree() else null
		if parent:
			parent.add_child(effect)
			effect.global_position = global_position
		else:
			effect.queue_free()


## Damage the player if within explosion radius (does NOT damage other enemies)
func _damage_player_in_radius() -> void:
	var player := target_player()
	if not player:
		return

	var distance := global_position.distance_to(player.global_position)
	if distance > explosion_radius:
		return

	# Find the player's EntityStats and deal damage
	var player_stats: EntityStats = null

	# Try to get stats from EntityManager first
	if player in EntityManager.entity_stats:
		player_stats = EntityManager.entity_stats[player]
	else:
		# Fallback: search for EntityStats child
		player_stats = player.find_child("EntityStats", true, false) as EntityStats

	if player_stats:
		player_stats.get_hit(explosion_damage)


## Override death handler to trigger explosion
func _on_entity_stats_out_of_health() -> void:
	if _is_exploding:
		# Already exploding, let the sequence complete
		return

	state = State.DYING
	enemy_died.emit()

	# Explode immediately on death (skip warning)
	explode()


## Set up audio players and cache sounds
func _setup_audio() -> void:
	# Create tick sound player attached to this enemy
	_tick_player = AudioStreamPlayer3D.new()
	_tick_player.bus = "SFX"
	_tick_player.max_distance = 30.0
	# Only add child if we're in the scene tree
	if is_inside_tree():
		add_child(_tick_player)
	else:
		# Defer until we're in the tree
		call_deferred("add_child", _tick_player)

	# Cache the sounds from SFXManager
	if SFXManager:
		_tick_sound = SFXManager.create_tick_sound(880.0, 0.08)
		_boom_sound = SFXManager.create_boom_sound()


## Update ticking sound based on distance to player
func _update_tick_sound(delta: float) -> void:
	if not _tick_sound or not _tick_player:
		return

	var distance := get_distance_to_player()
	if distance <= 0.1:
		return

	# Tick faster as we get closer (from 0.5s at far to 0.1s when close)
	var proximity_factor := clampf(1.0 - (distance / (explosion_radius * 4.0)), 0.0, 1.0)
	var tick_interval := lerpf(_base_tick_interval, 0.1, proximity_factor)

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_play_tick()


## Play the tick sound
func _play_tick() -> void:
	if _tick_player and _tick_sound and not _tick_player.playing:
		_tick_player.stream = _tick_sound
		# Pitch slightly higher as we get closer
		var distance := get_distance_to_player()
		var proximity := clampf(1.0 - (distance / (explosion_radius * 4.0)), 0.0, 1.0)
		_tick_player.pitch_scale = 1.0 + proximity * 0.5
		_tick_player.play()


## Play the explosion boom sound
func _play_boom() -> void:
	if _boom_sound and SFXManager:
		SFXManager.play_sfx_3d(_boom_sound, global_position, 3.0, 0.8)
