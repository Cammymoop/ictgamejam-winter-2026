class_name FlightEnemy
extends "res://assets/enemies/enemy_base.gd"
## Flying enemy that uses BoundedFlightController6DOF for smooth 6DOF movement.
## Configurable movement bounds, behavior mode, and optional projectile attacks.
##
## Place in scene and configure bounds_min/bounds_max to define flight area.
## Enemy will wander within bounds and optionally shoot at player.

const BFC = preload("res://dynamics/bounded_flight_controller_6dof.gd")

signal attack_fired

enum MovementMode { BROWNIAN, DISCRETE_DRIFT }  ## Smooth continuous random motion  ## Random direction changes at intervals

enum AttackMode {
	NONE,  ## No attacks, just flies around
	PROJECTILE,  ## Fires projectiles at player
	CHASE,  ## Chases the player within bounds
}

## Movement configuration
@export_group("Flight Bounds")
@export var bounds_min: Vector3 = Vector3(-10, 5, -10)
@export var bounds_max: Vector3 = Vector3(10, 12, 10)
@export var use_2d_plane: bool = false
@export var plane_height: float = 8.0

@export_group("Flight Behavior")
@export var movement_mode: MovementMode = MovementMode.BROWNIAN
@export var brownian_intensity: float = 5.0
@export var drift_max_acceleration: float = 8.0
@export var drift_interval_min: float = 0.5
@export var drift_interval_max: float = 2.0

@export_group("Orientation")
@export var align_to_movement: bool = true
@export var alignment_stiffness: float = 8.0
@export var roll_limit_degrees: float = 35.0
@export var pitch_limit_degrees: float = 45.0

@export_group("Attack")
@export var attack_mode: AttackMode = AttackMode.PROJECTILE
@export var projectile_scene: PackedScene
@export var fire_rate: float = 2.0  ## Seconds between shots
@export var projectile_speed: float = 25.0
@export var projectile_damage: float = 1.0
@export var aim_lead: float = 0.0  ## How much to lead the target (0-1)
@export var inaccuracy: float = TAU / 32  ## Spread angle in radians
@export_exp_easing var inaccuracy_curve_param: float = 1.0  ## Easing for spread distribution
@export var chase_strength: float = 1.5  ## Stiffness when chasing

## Internal state
var flight_controller: BFC
var _fire_timer: float = 0.0
var _projectile_spawn_point: Node3D


func _ready() -> void:
	super._ready()
	_setup_flight_controller()
	_setup_projectile_spawn()


func _physics_process(delta: float) -> void:
	if state == State.DYING:
		return

	if state == State.ACTIVE:
		_update_attack(delta)
		_sync_position_from_controller()


func _setup_flight_controller() -> void:
	flight_controller = BFC.new()
	add_child(flight_controller)

	# Set bounds
	if use_2d_plane:
		flight_controller.configure_plane_constraint(BFC.ConstraintMode.PLANE_XZ, plane_height)
		flight_controller.bounds_min = Vector3(bounds_min.x, plane_height, bounds_min.z)
		flight_controller.bounds_max = Vector3(bounds_max.x, plane_height, bounds_max.z)
	else:
		flight_controller.set_position_bounds(bounds_min, bounds_max)

	# Set movement mode
	match movement_mode:
		MovementMode.BROWNIAN:
			flight_controller.configure_as_ai(brownian_intensity, false)
		MovementMode.DISCRETE_DRIFT:
			flight_controller.configure_as_drift_enemy(
				drift_max_acceleration, drift_interval_min, drift_interval_max
			)

	# Orientation settings
	flight_controller.align_to_acceleration = align_to_movement
	flight_controller.alignment_stiffness = alignment_stiffness
	flight_controller.set_orientation_bounds_degrees(roll_limit_degrees, pitch_limit_degrees)

	# Initialize position
	flight_controller.linear_position = global_position
	flight_controller.linear_position = flight_controller._clamp_position_to_bounds(
		flight_controller.linear_position
	)


func _setup_projectile_spawn() -> void:
	# Look for existing spawn point or create one
	_projectile_spawn_point = get_node_or_null("ProjectileSpawn")
	if not _projectile_spawn_point:
		_projectile_spawn_point = Node3D.new()
		_projectile_spawn_point.name = "ProjectileSpawn"
		_projectile_spawn_point.position = Vector3(0, 0, -1)  # Front of enemy
		add_child(_projectile_spawn_point)


func _update_attack(delta: float) -> void:
	match attack_mode:
		AttackMode.NONE:
			pass
		AttackMode.PROJECTILE:
			_update_projectile_attack(delta)
		AttackMode.CHASE:
			_update_chase()


func _update_projectile_attack(delta: float) -> void:
	_fire_timer -= delta

	if _fire_timer <= 0 and is_player_in_attack_range():
		_fire_projectile()
		_fire_timer = fire_rate


func _update_chase() -> void:
	var player := target_player()
	if player and is_player_in_range():
		flight_controller.linear_stiffness = chase_strength
		flight_controller.set_position_target(player.global_position, true)
	else:
		flight_controller.use_position_target = false


func _fire_projectile() -> void:
	if not projectile_scene:
		return

	var player := target_player()
	if not player:
		return

	var projectile := projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = _projectile_spawn_point.global_position

	# Calculate aim direction with optional lead
	var aim_target := player.global_position
	if aim_lead > 0 and player.has_method("get_velocity"):
		var player_vel: Vector3 = player.get_velocity()
		var flight_time := global_position.distance_to(player.global_position) / projectile_speed
		aim_target += player_vel * flight_time * aim_lead

	var direction: Vector3 = (aim_target - projectile.global_position).normalized()

	# Apply inaccuracy spread like test_enemy
	if inaccuracy > 0:
		var fire_basis := Basis.looking_at(direction, Vector3.UP)
		direction = direction.rotated(fire_basis.x, ease(randf(), inaccuracy_curve_param) * inaccuracy)
		direction = direction.rotated(fire_basis.z, randf_range(0, TAU))

	# Configure projectile
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction)
	elif "linear_velocity" in projectile:
		projectile.linear_velocity = direction * projectile_speed

	if "damage" in projectile:
		projectile.damage = projectile_damage

	if "is_enemy_projectile" in projectile:
		projectile.is_enemy_projectile = true

	attack_fired.emit()


func _sync_position_from_controller() -> void:
	if flight_controller:
		global_position = flight_controller.linear_position
		global_basis = flight_controller.global_basis


## Override activate to start movement
func activate() -> void:
	super.activate()
	_fire_timer = randf_range(0.5, fire_rate)  # Randomize first shot


## Get the flight controller for external configuration
func get_flight_controller() -> BFC:
	return flight_controller


## Set flight bounds at runtime
func set_flight_bounds(new_min: Vector3, new_max: Vector3) -> void:
	bounds_min = new_min
	bounds_max = new_max
	if flight_controller:
		flight_controller.set_position_bounds(bounds_min, bounds_max)


## Apply an impulse to the enemy (e.g., from explosions)
func apply_knockback(impulse: Vector3) -> void:
	if flight_controller:
		flight_controller.apply_linear_impulse(impulse)
