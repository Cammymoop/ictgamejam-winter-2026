class_name ThrowingEnemy
extends EnemyBase
## A bulky enemy that lobs arcing projectiles at the player.
## Uses physics-based projectiles with gravity and leads the target.
##
## === BALANCE DOCUMENTATION ===
## Design Goal: Predictable arc attacks that reward movement
## Player Context: 5 HP, speed 10.0, bounds 4x3 units
##
## FINAL BALANCED VALUES:
## - windup_time: 1.0s (increased from 0.8s for clearer trajectory preview)
## - cooldown_time: 2.0s (increased from 1.5s for breathing room)
## - throw_force: 12.0 (reduced from 15.0 for slower, more readable arcs)
## - throw_damage: 1.0 (reduced from 1.5 - 20% of player HP, lowest damage enemy)
##
## Counterplay: Orange trajectory preview shows exact landing zone during 1.0s windup.
## Player can simply move away from the predicted impact point. The slower arc (force 12.0)
## gives more reaction time mid-flight. Splash radius 1.5 is tight, rewarding precise dodges.
## =========================

signal projectile_thrown

## Internal throw state machine
enum ThrowState { IDLE, WINDING_UP, THROWING, COOLDOWN }

## Projectile damage per hit
@export var throw_damage: float = 1.0

## Force applied to projectile at launch
@export var throw_force: float = 12.0

## Time to wind up before throwing
@export var windup_time: float = 1.0

## Cooldown after throwing before next attack
@export var cooldown_time: float = 2.0

## Show trajectory preview line during wind-up (visual telegraph for player)
@export var show_trajectory_preview: bool = true

## Preloaded arc projectile scene
var arc_projectile_scene: PackedScene = preload("res://assets/enemies/arc_projectile.tscn")

## Throw state machine state
var throw_state: ThrowState = ThrowState.IDLE
var state_timer: float = 0.0

## Reference to current trajectory preview (if showing)
var _trajectory_preview: MeshInstance3D = null
var _preview_projectile: ArcProjectile = null

## Cached grunt sound
var _grunt_sound: AudioStreamWAV = null

## Spawn point for projectiles (set via node reference or defaults to enemy position)
@onready var throw_point: Node3D = $ThrowPoint if has_node("ThrowPoint") else self


func _ready() -> void:
	super._ready()
	_setup_audio()


func _physics_process(delta: float) -> void:
	if state != State.ACTIVE:
		return

	_update_throw_state(delta)


## Update the internal throw state machine
func _update_throw_state(delta: float) -> void:
	match throw_state:
		ThrowState.IDLE:
			_look_at_player()
			_start_windup()

		ThrowState.WINDING_UP:
			_look_at_player()
			_update_trajectory_preview()
			state_timer -= delta
			if state_timer <= 0:
				_throw_projectile()

		ThrowState.THROWING:
			# Throwing state is instant, handled in _throw_projectile
			pass

		ThrowState.COOLDOWN:
			state_timer -= delta
			if state_timer <= 0:
				throw_state = ThrowState.IDLE


## Rotate to face the player
func _look_at_player() -> void:
	var player := target_player()
	if not player:
		return

	var look_target := player.global_position
	look_target.y = global_position.y  # Keep level
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)


## Begin the wind-up animation phase
func _start_windup() -> void:
	throw_state = ThrowState.WINDING_UP
	state_timer = windup_time
	_play_windup_animation()
	_create_trajectory_preview()


## Visual feedback during wind-up
func _play_windup_animation() -> void:
	var mesh_instance := _find_mesh_instance()
	if not mesh_instance:
		return

	var arm := find_child("ArmMesh", true, false) as MeshInstance3D
	if arm:
		# Animate arm pull-back
		var tween := create_tween()
		tween.tween_property(arm, "rotation:x", -0.5, windup_time * 0.5)
		tween.tween_property(arm, "rotation:x", 0.3, windup_time * 0.5)


## Throw the projectile at the player
func _throw_projectile() -> void:
	# Clear trajectory preview before throwing
	_clear_trajectory_preview()

	var player := target_player()
	if not player:
		throw_state = ThrowState.COOLDOWN
		state_timer = cooldown_time
		return

	# Play grunt sound on throw
	_play_grunt()

	# Calculate launch velocity
	var target_pos := player.global_position
	var launch_velocity := calculate_launch_velocity(target_pos)

	# Spawn projectile
	var projectile := arc_projectile_scene.instantiate() as ArcProjectile
	if projectile:
		projectile.damage = throw_damage
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = _get_throw_position()
		projectile.launch(launch_velocity)

	projectile_thrown.emit()

	# Transition to cooldown
	throw_state = ThrowState.COOLDOWN
	state_timer = cooldown_time


## Get the position from which to spawn projectiles
func _get_throw_position() -> Vector3:
	if throw_point and throw_point != self:
		return throw_point.global_position
	# Default: slightly above and in front of enemy
	return global_position + Vector3(0, 2, 0) - global_basis.z * 1.0


## Calculate the launch velocity to hit the target with an arc
## Leads the target based on player velocity
func calculate_launch_velocity(target_pos: Vector3) -> Vector3:
	var spawn_pos := _get_throw_position()
	var to_target := target_pos - spawn_pos

	# Horizontal distance and height difference
	var horizontal_dir := Vector2(to_target.x, to_target.z)
	var horizontal_dist := horizontal_dir.length()
	var height_diff := to_target.y

	# Estimate flight time for leading the target
	# Using a rough estimate based on horizontal distance and throw force
	var estimated_flight_time := _estimate_flight_time(horizontal_dist, height_diff)

	# Lead the target based on player velocity
	var lead_offset := Global.player_velocity * estimated_flight_time * 0.5
	var lead_pos := target_pos + lead_offset

	# Recalculate with lead position
	var to_lead := lead_pos - spawn_pos
	var lead_horizontal := Vector2(to_lead.x, to_lead.z)
	var lead_dist := lead_horizontal.length()
	var lead_height := to_lead.y

	# Calculate launch angle and velocity for the arc
	return _compute_arc_velocity(to_lead, lead_dist, lead_height)


## Estimate the time of flight for the projectile
func _estimate_flight_time(horizontal_dist: float, _height_diff: float) -> float:
	# Simple estimate: time = distance / horizontal_speed
	# Assume about 70% of throw_force goes to horizontal component
	var horizontal_speed := throw_force * 0.7
	if horizontal_speed <= 0:
		return 1.0
	return horizontal_dist / horizontal_speed


## Compute the velocity vector for an arcing trajectory
func _compute_arc_velocity(
		to_target: Vector3, horizontal_dist: float, height_diff: float) -> Vector3:
	# Use a fixed launch angle for predictable arcs
	# 45 degrees is optimal for maximum range, but we use ~50 degrees for a higher arc
	var launch_angle := deg_to_rad(50.0)

	# Gravity constant (Godot default is 9.8)
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float

	# Calculate required initial speed to hit target at given angle
	# Using projectile motion equations:
	# range = (v^2 * sin(2*angle)) / g
	# Solving for v: v = sqrt(range * g / sin(2*angle))
	var sin_2angle := sin(2.0 * launch_angle)
	if sin_2angle <= 0.01:
		sin_2angle = 0.01  # Avoid division by zero

	# Adjust for height difference
	var adjusted_dist := horizontal_dist
	if height_diff < 0:
		# Target is below us, can use less force
		adjusted_dist = horizontal_dist * 0.9
	elif height_diff > 0:
		# Target is above us, need more force
		adjusted_dist = horizontal_dist + height_diff * 2.0

	var required_speed := sqrt(max(adjusted_dist * gravity / sin_2angle, 1.0))

	# Clamp to throw_force range (allow some variance but not too much)
	required_speed = clampf(required_speed, throw_force * 0.5, throw_force * 1.5)

	# Build velocity vector
	var horizontal_dir := Vector3(to_target.x, 0, to_target.z).normalized()
	if horizontal_dir.length() < 0.1:
		horizontal_dir = -global_basis.z  # Fallback to forward direction

	var cos_angle := cos(launch_angle)
	var sin_angle := sin(launch_angle)

	var velocity := horizontal_dir * required_speed * cos_angle
	velocity.y = required_speed * sin_angle

	return velocity


## Create a trajectory preview line during wind-up phase
func _create_trajectory_preview() -> void:
	if not show_trajectory_preview:
		return

	var player := target_player()
	if not player:
		return

	# Create a temporary projectile instance just for trajectory calculation
	_preview_projectile = arc_projectile_scene.instantiate() as ArcProjectile
	if not _preview_projectile:
		return

	# Add temporarily to scene tree so it can access project settings
	add_child(_preview_projectile)
	_preview_projectile.visible = false

	var target_pos := player.global_position
	var launch_velocity := calculate_launch_velocity(target_pos)
	var spawn_pos := _get_throw_position()

	_trajectory_preview = _preview_projectile.create_trajectory_preview(
		spawn_pos, launch_velocity, get_tree().current_scene)


## Update the trajectory preview to track player movement during wind-up
func _update_trajectory_preview() -> void:
	if not show_trajectory_preview or not _preview_projectile:
		return

	var player := target_player()
	if not player:
		return

	var target_pos := player.global_position
	var launch_velocity := calculate_launch_velocity(target_pos)
	var spawn_pos := _get_throw_position()

	_preview_projectile.update_trajectory_preview(spawn_pos, launch_velocity)


## Clear and remove the trajectory preview
func _clear_trajectory_preview() -> void:
	if _preview_projectile and is_instance_valid(_preview_projectile):
		_preview_projectile.queue_free()
		_preview_projectile = null
	_trajectory_preview = null


## Set up audio and cache sounds
func _setup_audio() -> void:
	if SFXManager:
		_grunt_sound = SFXManager.create_grunt_sound()


## Play grunt sound when throwing
func _play_grunt() -> void:
	if _grunt_sound and SFXManager:
		SFXManager.play_sfx_3d(_grunt_sound, global_position, 0.0, randf_range(0.9, 1.1))
