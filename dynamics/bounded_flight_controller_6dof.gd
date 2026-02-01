extends Node3D
class_name BoundedFlightController6DOF

## 6DOF Physics controller with Brownian motion and Control Barrier Functions
## Supports both AI-driven enemies and player-controlled characters.
##
## Control Modes:
## - AI: Brownian motion + optional target tracking
## - PLAYER: Direct WASD input with momentum
##
## Constraint Modes:
## - FULL_3D: Standard bounding box
## - PLANE_XZ: Horizontal plane (fixed Y)
## - PLANE_XY: Vertical plane (fixed Z)
## - PLANE_YZ: Side plane (fixed X)
## - THIN_BOX: 3D box with one very thin dimension

enum ControlMode {
	AI,  # Brownian motion + target seeking
	PLAYER,  # Direct input control
}

enum AIBehavior {
	BROWNIAN,  # Continuous Brownian motion (original)
	DISCRETE_DRIFT,  # Random discrete acceleration updates
}

enum PlayerDynamicsMode {
	SIMPLE,  # Direct acceleration (original)
	TRANSFER_FUNCTION,  # Second-order transfer function
}

enum ConstraintMode {
	FULL_3D,  # Standard 3D bounding box
	PLANE_XZ,  # Horizontal plane (Y fixed)
	PLANE_XY,  # Vertical plane facing Z (Z fixed)
	PLANE_YZ,  # Side plane (X fixed)
	THIN_BOX,  # 3D but with configurable thin dimension
}

# === Control Mode ===
@export_group("Control Mode")
@export var control_mode: ControlMode = ControlMode.AI
@export var constraint_mode: ConstraintMode = ConstraintMode.FULL_3D

# === Position Bounds ===
@export_group("Position Bounds")
@export var bounds_min: Vector3 = Vector3(-10, -10, -10)
@export var bounds_max: Vector3 = Vector3(10, 10, 10)
@export var plane_position: float = 0.0  # Fixed coordinate for plane modes
@export var thin_dimension: int = 1  # 0=X, 1=Y, 2=Z for THIN_BOX mode
@export var thin_thickness: float = 0.5  # Half-thickness for thin dimension

# === Orientation Bounds (radians) ===
@export_group("Orientation Bounds")
@export var roll_limit: float = PI / 4
@export var pitch_limit: float = PI / 4
@export var yaw_limit: float = PI
@export var constrain_yaw: bool = false

# === Linear Dynamics ===
@export_group("Linear Dynamics")
@export var linear_mass: float = 1.0
@export var linear_damping: float = 2.0
@export var linear_stiffness: float = 0.5  # For AI target tracking

# === Player Control Settings ===
@export_group("Player Controls")
@export var player_acceleration: float = 20.0  # Units/s²
@export var player_max_speed: float = 10.0
@export var player_drag: float = 3.0  # Deceleration when no input
@export var player_boost_multiplier: float = 1.5
@export var input_smoothing: float = 0.1  # Input lerp factor

# === Angular Dynamics ===
@export_group("Angular Dynamics")
@export var angular_inertia: float = 0.5
@export var angular_damping: float = 3.0
@export var angular_stiffness: float = 1.0

# === AI Behavior ===
@export_group("AI Behavior")
@export var ai_behavior: AIBehavior = AIBehavior.BROWNIAN

# === Brownian Motion (AI only) ===
@export_group("Brownian Motion (AI)")
@export var linear_brownian_intensity: float = 5.0
@export var linear_correlation_time: float = 0.1
@export var angular_brownian_intensity: float = 0.3
@export var angular_correlation_time: float = 0.15

# === Discrete Drift (AI only) ===
@export_group("Discrete Drift (AI)")
@export var drift_max_acceleration: float = 8.0
@export var drift_update_interval_min: float = 0.5
@export var drift_update_interval_max: float = 2.0
@export var drift_acceleration_smoothing: float = 0.3

# === Player Dynamics Mode ===
@export_group("Player Dynamics")
@export var player_dynamics_mode: PlayerDynamicsMode = PlayerDynamicsMode.SIMPLE

# === Player Transfer Function ===
@export_group("Player Transfer Function")
@export var tf_damping_ratio: float = 0.8  # 0.7-1.0 typical
@export var tf_natural_frequency: float = 5.0  # rad/s
@export var tf_velocity_scale: float = 10.0  # max velocity

# === CBF Safety Parameters ===
@export_group("Safety (CBF)")
@export var position_cbf_alpha: float = 1.5
@export var position_safety_margin: float = 0.5
@export var orientation_cbf_alpha: float = 2.0
@export var orientation_safety_margin: float = 0.1

# === Aerodynamic Alignment ===
@export_group("Aerodynamic Alignment")
@export var align_to_acceleration: bool = true
@export var gravity: Vector3 = Vector3(0, -9.81, 0)
@export var alignment_stiffness: float = 8.0
@export var alignment_damping: float = 4.0
@export var min_accel_magnitude: float = 0.5
@export var use_velocity_fallback: bool = true
@export var min_velocity_magnitude: float = 0.1
@export var bank_into_turns: bool = true
@export var bank_angle_scale: float = 0.5

# === State Variables ===
var linear_position: Vector3 = Vector3.ZERO
var linear_velocity: Vector3 = Vector3.ZERO
var linear_brownian_force: Vector3 = Vector3.ZERO

var angular_position: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var angular_brownian_torque: Vector3 = Vector3.ZERO

# === Target Tracking (AI) ===
var target_position: Vector3 = Vector3.ZERO
var target_orientation: Vector3 = Vector3.ZERO
var use_position_target: bool = false
var use_orientation_target: bool = false

# === Player Input State ===
var _input_direction: Vector3 = Vector3.ZERO  # Raw input
var _smoothed_input: Vector3 = Vector3.ZERO  # Smoothed input
var _is_boosting: bool = false

# === Alignment State ===
var _smoothed_accel: Vector3 = Vector3(0, -9.81, 0)
var _accel_smoothing: float = 0.1

# === Discrete Drift State ===
var _drift_target_acceleration: Vector3 = Vector3.ZERO
var _drift_current_acceleration: Vector3 = Vector3.ZERO
var _drift_time_until_update: float = 0.0

# === Transfer Function State (per-axis) ===
var _tf_y: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # Output history [n-1, n-2]
var _tf_u: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # Input history [n-1, n-2]
var _tf_coeffs_computed: bool = false
var _tf_a1: float = 0.0
var _tf_a2: float = 0.0
var _tf_b0: float = 0.0
var _tf_b1: float = 0.0
var _tf_b2: float = 0.0
var _tf_last_dt: float = 0.0

# === Internal ===
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _initialized: bool = false


func _ready() -> void:
	rng.randomize()
	_initialize_from_transform()
	_smoothed_accel = gravity
	_drift_time_until_update = 0.0  # Trigger first update immediately
	_initialized = true


func _initialize_from_transform() -> void:
	linear_position = global_position
	linear_position = _apply_constraint_mode(linear_position)
	linear_position = _clamp_position_to_bounds(linear_position)

	angular_position = global_basis.get_euler(EULER_ORDER_YXZ)
	angular_position = _clamp_orientation_to_bounds(angular_position)


func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	# === Compute Linear Acceleration Based on Control Mode ===
	var nominal_linear_accel: Vector3

	match control_mode:
		ControlMode.AI:
			match ai_behavior:
				AIBehavior.BROWNIAN:
					_update_linear_brownian(delta)
					nominal_linear_accel = _compute_ai_linear_acceleration()
				AIBehavior.DISCRETE_DRIFT:
					_update_drift_acceleration(delta)
					nominal_linear_accel = _compute_drift_linear_acceleration()
		ControlMode.PLAYER:
			_update_player_input(delta)
			match player_dynamics_mode:
				PlayerDynamicsMode.SIMPLE:
					nominal_linear_accel = _compute_player_linear_acceleration()
				PlayerDynamicsMode.TRANSFER_FUNCTION:
					nominal_linear_accel = _compute_player_tf_acceleration(delta)

	# Apply constraint mode to acceleration
	nominal_linear_accel = _apply_constraint_to_vector(nominal_linear_accel)

	# Apply CBF safety filter
	var safe_linear_accel := _apply_linear_cbf(nominal_linear_accel)

	# Integrate linear dynamics
	linear_velocity += safe_linear_accel * delta
	linear_velocity = _apply_constraint_to_vector(linear_velocity)

	# Speed limit for player
	if control_mode == ControlMode.PLAYER:
		var max_spd := player_max_speed * (player_boost_multiplier if _is_boosting else 1.0)
		if linear_velocity.length() > max_spd:
			linear_velocity = linear_velocity.normalized() * max_spd

	linear_position += linear_velocity * delta
	linear_position = _apply_constraint_mode(linear_position)
	linear_position = _clamp_position_to_bounds(linear_position)

	# === Compute Angular Acceleration ===
	if control_mode == ControlMode.AI:
		_update_angular_brownian(delta)

	var nominal_angular_accel := _compute_nominal_angular_acceleration()
	var safe_angular_accel := _apply_angular_cbf(nominal_angular_accel)

	angular_velocity += safe_angular_accel * delta
	angular_position += angular_velocity * delta
	angular_position = _clamp_orientation_to_bounds(angular_position)

	# === Apply to Node Transform ===
	if is_inside_tree():
		global_position = linear_position
		global_basis = Basis.from_euler(angular_position, EULER_ORDER_YXZ)


# =============================================================================
# PUBLIC API - CONFIGURATION
# =============================================================================


## Configure as AI-controlled enemy
func configure_as_ai(brownian_intensity: float = 5.0, enable_target_tracking: bool = false) -> void:
	control_mode = ControlMode.AI
	linear_brownian_intensity = brownian_intensity
	use_position_target = enable_target_tracking


## Configure as player-controlled
func configure_as_player(acceleration: float = 20.0, max_speed: float = 10.0) -> void:
	control_mode = ControlMode.PLAYER
	player_acceleration = acceleration
	player_max_speed = max_speed
	linear_brownian_intensity = 0.0  # No random motion for player
	angular_brownian_intensity = 0.0


## Set up 2D plane constraint (thin box in one dimension)
func configure_plane_constraint(mode: ConstraintMode, fixed_position: float = 0.0) -> void:
	constraint_mode = mode
	plane_position = fixed_position

	# Adjust orientation constraints for 2D
	match mode:
		ConstraintMode.PLANE_XZ:
			# Horizontal plane - limit pitch, allow yaw
			pitch_limit = PI / 6  # Reduced pitch for 2D feel
			roll_limit = PI / 4
		ConstraintMode.PLANE_XY:
			# Vertical plane - different orientation handling
			yaw_limit = PI / 6
			constrain_yaw = true
		ConstraintMode.PLANE_YZ:
			yaw_limit = PI / 6
			constrain_yaw = true


## Set up thin box constraint
func configure_thin_box(dimension: int, thickness: float) -> void:
	constraint_mode = ConstraintMode.THIN_BOX
	thin_dimension = clamp(dimension, 0, 2)
	thin_thickness = thickness


## Configure position bounds
func set_position_bounds(box_min: Vector3, box_max: Vector3) -> void:
	bounds_min = box_min
	bounds_max = box_max
	linear_position = _clamp_position_to_bounds(linear_position)


## Configure position bounds from AABB
func set_position_bounds_aabb(aabb: AABB) -> void:
	set_position_bounds(aabb.position, aabb.end)


## Set 2D bounds (for plane modes)
func set_2d_bounds(min_a: float, max_a: float, min_b: float, max_b: float) -> void:
	match constraint_mode:
		ConstraintMode.PLANE_XZ:
			bounds_min = Vector3(min_a, plane_position, min_b)
			bounds_max = Vector3(max_a, plane_position, max_b)
		ConstraintMode.PLANE_XY:
			bounds_min = Vector3(min_a, min_b, plane_position)
			bounds_max = Vector3(max_a, max_b, plane_position)
		ConstraintMode.PLANE_YZ:
			bounds_min = Vector3(plane_position, min_a, min_b)
			bounds_max = Vector3(plane_position, max_a, max_b)
		_:
			push_warning("set_2d_bounds called but not in plane mode")


## Configure orientation bounds (degrees)
func set_orientation_bounds_degrees(
	roll_deg: float, pitch_deg: float, yaw_deg: float = 180.0, constrain_yaw_axis: bool = false
) -> void:
	roll_limit = deg_to_rad(roll_deg)
	pitch_limit = deg_to_rad(pitch_deg)
	yaw_limit = deg_to_rad(yaw_deg)
	constrain_yaw = constrain_yaw_axis
	angular_position = _clamp_orientation_to_bounds(angular_position)


## Enable/disable aerodynamic alignment
func set_aerodynamic_alignment(enabled: bool, include_gravity: bool = true) -> void:
	align_to_acceleration = enabled
	if not include_gravity:
		gravity = Vector3.ZERO


## Configure gravity
func set_gravity(g: Vector3) -> void:
	gravity = g
	_smoothed_accel = g


## Configure banking
func set_banking(enabled: bool, scale: float = 0.5) -> void:
	bank_into_turns = enabled
	bank_angle_scale = clamp(scale, 0.0, 1.0)


# =============================================================================
# PUBLIC API - PLAYER INPUT
# =============================================================================


## Set player input direction (call from _process or _input)
## Input should be normalized or raw WASD values
func set_input_direction(direction: Vector3) -> void:
	_input_direction = direction


## Set 2D input (for plane modes) - automatically maps to correct axes
func set_input_2d(horizontal: float, vertical: float) -> void:
	match constraint_mode:
		ConstraintMode.PLANE_XZ:
			_input_direction = Vector3(horizontal, 0, -vertical)  # -Z is forward
		ConstraintMode.PLANE_XY:
			_input_direction = Vector3(horizontal, vertical, 0)
		ConstraintMode.PLANE_YZ:
			_input_direction = Vector3(0, vertical, -horizontal)
		_:
			_input_direction = Vector3(horizontal, 0, -vertical)


## Set boost state
func set_boosting(boosting: bool) -> void:
	_is_boosting = boosting


## Helper: Get input from standard Godot input actions
func read_wasd_input() -> void:
	var input := Vector3.ZERO

	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S):
		input.z += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_SPACE):
		input.y += 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_SHIFT):
		input.y -= 1.0

	_is_boosting = Input.is_action_pressed("boost") or Input.is_key_pressed(KEY_CTRL)

	set_input_direction(input.normalized() if input.length() > 1.0 else input)


## Helper: Get input for 2D plane mode
func read_2d_input() -> void:
	var h := 0.0
	var v := 0.0

	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		h += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		h -= 1.0
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W):
		v += 1.0
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S):
		v -= 1.0

	_is_boosting = Input.is_action_pressed("boost") or Input.is_key_pressed(KEY_SHIFT)

	set_input_2d(h, v)


# =============================================================================
# PUBLIC API - AI CONTROL
# =============================================================================


## Set AI target position
func set_position_target(target: Vector3, enabled: bool = true) -> void:
	target_position = _apply_constraint_mode(target)
	target_position = _clamp_position_to_bounds(target_position)
	use_position_target = enabled


## Set AI target orientation
func set_orientation_target(target_euler: Vector3, enabled: bool = true) -> void:
	target_orientation = _clamp_orientation_to_bounds(target_euler)
	use_orientation_target = enabled


# =============================================================================
# PUBLIC API - IMPULSES & STATE
# =============================================================================


## Apply linear impulse
func apply_linear_impulse(impulse: Vector3) -> void:
	impulse = _apply_constraint_to_vector(impulse)
	linear_velocity += impulse / linear_mass


## Apply angular impulse
func apply_angular_impulse(torque_impulse: Vector3) -> void:
	angular_velocity += torque_impulse / angular_inertia


## Apply impulse in local coordinates
func apply_local_linear_impulse(local_impulse: Vector3) -> void:
	var world_impulse := global_basis * local_impulse
	apply_linear_impulse(world_impulse)


## Get current state
func get_state() -> Dictionary:
	return {
		"position": linear_position,
		"velocity": linear_velocity,
		"speed": linear_velocity.length(),
		"orientation": angular_position,
		"orientation_degrees":
		Vector3(
			rad_to_deg(angular_position.x),
			rad_to_deg(angular_position.y),
			rad_to_deg(angular_position.z)
		),
		"angular_velocity": angular_velocity,
		"control_mode": "AI" if control_mode == ControlMode.AI else "PLAYER",
		"constraint_mode": ConstraintMode.keys()[constraint_mode],
		"input_direction": _smoothed_input if control_mode == ControlMode.PLAYER else Vector3.ZERO,
	}


## Get barrier values for debugging
func get_barrier_values() -> Dictionary:
	var margin_p := position_safety_margin
	var margin_o := orientation_safety_margin

	var barriers := {
		"pos_x_min": linear_position.x - bounds_min.x - margin_p,
		"pos_x_max": bounds_max.x - linear_position.x - margin_p,
		"pos_y_min": linear_position.y - bounds_min.y - margin_p,
		"pos_y_max": bounds_max.y - linear_position.y - margin_p,
		"pos_z_min": linear_position.z - bounds_min.z - margin_p,
		"pos_z_max": bounds_max.z - linear_position.z - margin_p,
		"roll_min": angular_position.x + roll_limit - margin_o,
		"roll_max": roll_limit - angular_position.x - margin_o,
		"pitch_min": angular_position.y + pitch_limit - margin_o,
		"pitch_max": pitch_limit - angular_position.y - margin_o,
	}

	if constrain_yaw:
		barriers["yaw_min"] = angular_position.z + yaw_limit - margin_o
		barriers["yaw_max"] = yaw_limit - angular_position.z - margin_o

	return barriers


## Check if in safe region
func is_safe() -> bool:
	var h := get_barrier_values()
	for key in h:
		if h[key] < 0:
			return false
	return true


## Reset to center
func reset_to_center() -> void:
	linear_position = (bounds_min + bounds_max) / 2.0
	linear_position = _apply_constraint_mode(linear_position)
	linear_velocity = Vector3.ZERO
	linear_brownian_force = Vector3.ZERO

	angular_position = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	angular_brownian_torque = Vector3.ZERO

	_smoothed_input = Vector3.ZERO
	_input_direction = Vector3.ZERO

	if is_inside_tree():
		global_position = linear_position
		global_basis = Basis.IDENTITY


# =============================================================================
# CONSTRAINT MODE HANDLING
# =============================================================================


## Apply constraint mode to position
func _apply_constraint_mode(pos: Vector3) -> Vector3:
	match constraint_mode:
		ConstraintMode.PLANE_XZ:
			pos.y = plane_position
		ConstraintMode.PLANE_XY:
			pos.z = plane_position
		ConstraintMode.PLANE_YZ:
			pos.x = plane_position
		ConstraintMode.THIN_BOX:
			var center := (bounds_min[thin_dimension] + bounds_max[thin_dimension]) / 2.0
			pos[thin_dimension] = clamp(
				pos[thin_dimension], center - thin_thickness, center + thin_thickness
			)
	return pos


## Apply constraint to velocity/acceleration vectors
func _apply_constraint_to_vector(vec: Vector3) -> Vector3:
	match constraint_mode:
		ConstraintMode.PLANE_XZ:
			vec.y = 0.0
		ConstraintMode.PLANE_XY:
			vec.z = 0.0
		ConstraintMode.PLANE_YZ:
			vec.x = 0.0
		ConstraintMode.THIN_BOX:
			# Allow movement but heavily damped in thin dimension
			vec[thin_dimension] *= 0.1
	return vec


# =============================================================================
# PLAYER INPUT PROCESSING
# =============================================================================


func _update_player_input(delta: float) -> void:
	# Smooth the input
	var target_input := _input_direction
	if target_input.length() > 1.0:
		target_input = target_input.normalized()

	_smoothed_input = _smoothed_input.lerp(target_input, 1.0 - exp(-delta / input_smoothing))


func _compute_player_linear_acceleration() -> Vector3:
	var accel := Vector3.ZERO

	if _smoothed_input.length() > 0.01:
		# Accelerate in input direction
		var input_accel := player_acceleration
		if _is_boosting:
			input_accel *= player_boost_multiplier
		accel = _smoothed_input * input_accel
	else:
		# Apply drag when no input
		accel = -linear_velocity * player_drag

	return accel


# =============================================================================
# AI CONTROL PROCESSING
# =============================================================================


func _update_linear_brownian(delta: float) -> void:
	linear_brownian_force = _ornstein_uhlenbeck_step(
		linear_brownian_force, linear_correlation_time, linear_brownian_intensity, delta
	)
	# Apply constraint to Brownian force
	linear_brownian_force = _apply_constraint_to_vector(linear_brownian_force)


func _update_angular_brownian(delta: float) -> void:
	angular_brownian_torque = _ornstein_uhlenbeck_step(
		angular_brownian_torque, angular_correlation_time, angular_brownian_intensity, delta
	)


func _ornstein_uhlenbeck_step(current: Vector3, tau: float, sigma: float, delta: float) -> Vector3:
	if sigma < 0.001:
		return Vector3.ZERO
	var decay := exp(-delta / tau)
	var noise_scale := sigma * sqrt(1.0 - decay * decay)
	var noise := (
		Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)) * noise_scale
	)
	return current * decay + noise


func _compute_ai_linear_acceleration() -> Vector3:
	var spring_force := Vector3.ZERO
	if use_position_target:
		spring_force = -linear_stiffness * (linear_position - target_position)

	var damping_force := -linear_damping * linear_velocity
	var total_force := spring_force + damping_force + linear_brownian_force

	return total_force / linear_mass


# =============================================================================
# DISCRETE DRIFT AI BEHAVIOR
# =============================================================================


func _update_drift_acceleration(delta: float) -> void:
	# Check if we need to select a new target acceleration
	_drift_time_until_update -= delta
	if _drift_time_until_update <= 0.0:
		# Select new random acceleration direction
		var random_dir := (
			Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
		)
		_drift_target_acceleration = random_dir * drift_max_acceleration
		_drift_target_acceleration = _apply_constraint_to_vector(_drift_target_acceleration)

		# Schedule next update (Poisson-like with uniform interval)
		_drift_time_until_update = rng.randf_range(
			drift_update_interval_min, drift_update_interval_max
		)

	# Smooth interpolation to target (first-order filter)
	var alpha := 1.0 - exp(-delta / drift_acceleration_smoothing)
	_drift_current_acceleration = _drift_current_acceleration.lerp(
		_drift_target_acceleration, alpha
	)


func _compute_drift_linear_acceleration() -> Vector3:
	var spring_force := Vector3.ZERO
	if use_position_target:
		spring_force = -linear_stiffness * (linear_position - target_position)

	var damping_force := -linear_damping * linear_velocity
	var total_force := spring_force + damping_force + _drift_current_acceleration * linear_mass

	return total_force / linear_mass


# =============================================================================
# TRANSFER FUNCTION PLAYER DYNAMICS
# =============================================================================


func _compute_tf_coefficients(dt: float) -> void:
	# Skip if already computed for this timestep
	if _tf_coeffs_computed and abs(dt - _tf_last_dt) < 0.0001:
		return

	# Tustin (bilinear) transform of G(s) = wn^2 / (s^2 + 2*zeta*wn*s + wn^2)
	var wn := tf_natural_frequency
	var zeta := tf_damping_ratio
	var T := dt

	# Pre-warp frequency for Tustin transform
	var wn_sq := wn * wn
	var T_sq := T * T

	# Denominator coefficients for continuous system: s^2 + 2*zeta*wn*s + wn^2
	# Using bilinear transform: s = (2/T) * (z-1)/(z+1)
	# After substitution and simplification:
	var k := 2.0 / T
	var k_sq := k * k

	var a0 := k_sq + 2.0 * zeta * wn * k + wn_sq
	var a1_num := 2.0 * wn_sq - 2.0 * k_sq
	var a2_num := k_sq - 2.0 * zeta * wn * k + wn_sq

	# Normalize by a0 and negate for difference equation form
	_tf_a1 = -a1_num / a0
	_tf_a2 = -a2_num / a0

	# Numerator (wn^2 in continuous) becomes:
	_tf_b0 = wn_sq / a0
	_tf_b1 = 2.0 * wn_sq / a0
	_tf_b2 = wn_sq / a0

	_tf_coeffs_computed = true
	_tf_last_dt = dt


func _apply_tf_filter(input: Vector3, dt: float) -> Vector3:
	_compute_tf_coefficients(dt)

	# Second-order IIR filter: y[n] = a1*y[n-1] + a2*y[n-2] + b0*u[n] + b1*u[n-1] + b2*u[n-2]
	var output := Vector3(
		(
			_tf_a1 * _tf_y[0].x
			+ _tf_a2 * _tf_y[1].x
			+ _tf_b0 * input.x
			+ _tf_b1 * _tf_u[0].x
			+ _tf_b2 * _tf_u[1].x
		),
		(
			_tf_a1 * _tf_y[0].y
			+ _tf_a2 * _tf_y[1].y
			+ _tf_b0 * input.y
			+ _tf_b1 * _tf_u[0].y
			+ _tf_b2 * _tf_u[1].y
		),
		(
			_tf_a1 * _tf_y[0].z
			+ _tf_a2 * _tf_y[1].z
			+ _tf_b0 * input.z
			+ _tf_b1 * _tf_u[0].z
			+ _tf_b2 * _tf_u[1].z
		)
	)

	# Update history (shift)
	_tf_y[1] = _tf_y[0]
	_tf_y[0] = output
	_tf_u[1] = _tf_u[0]
	_tf_u[0] = input

	return output


func _compute_player_tf_acceleration(delta: float) -> Vector3:
	# Input is desired velocity direction scaled by max velocity
	var target_velocity := _smoothed_input * tf_velocity_scale
	if _is_boosting:
		target_velocity *= player_boost_multiplier

	# Apply transfer function to get smooth velocity response
	var filtered_velocity := _apply_tf_filter(target_velocity, delta)

	# Compute acceleration needed to achieve filtered velocity
	# a = (v_filtered - v_current) / dt, but we want smooth approach
	var velocity_error := filtered_velocity - linear_velocity

	# Use a proportional controller with limit
	var accel := velocity_error * tf_natural_frequency
	var max_accel := player_acceleration * (player_boost_multiplier if _is_boosting else 1.0)
	if accel.length() > max_accel:
		accel = accel.normalized() * max_accel

	return accel


## Configure player with transfer function dynamics
func configure_player_tf(responsiveness: String = "smooth", speed_class: String = "medium") -> void:
	control_mode = ControlMode.PLAYER
	player_dynamics_mode = PlayerDynamicsMode.TRANSFER_FUNCTION
	linear_brownian_intensity = 0.0
	angular_brownian_intensity = 0.0

	# Set damping ratio based on responsiveness
	match responsiveness:
		"snappy":
			tf_damping_ratio = 0.7
			tf_natural_frequency = 8.0
		"smooth":
			tf_damping_ratio = 0.9
			tf_natural_frequency = 4.0
		"floaty":
			tf_damping_ratio = 1.0
			tf_natural_frequency = 2.5
		_:
			tf_damping_ratio = 0.8
			tf_natural_frequency = 5.0

	# Set velocity scale based on speed class
	match speed_class:
		"slow":
			tf_velocity_scale = 6.0
			player_max_speed = 8.0
		"medium":
			tf_velocity_scale = 10.0
			player_max_speed = 12.0
		"fast":
			tf_velocity_scale = 15.0
			player_max_speed = 18.0
		_:
			tf_velocity_scale = 10.0
			player_max_speed = 12.0

	# Reset filter state
	_tf_y = [Vector3.ZERO, Vector3.ZERO]
	_tf_u = [Vector3.ZERO, Vector3.ZERO]
	_tf_coeffs_computed = false


## Configure as drift enemy
func configure_as_drift_enemy(
	max_accel: float = 8.0, update_interval_min: float = 0.5, update_interval_max: float = 2.0
) -> void:
	control_mode = ControlMode.AI
	ai_behavior = AIBehavior.DISCRETE_DRIFT
	drift_max_acceleration = max_accel
	drift_update_interval_min = update_interval_min
	drift_update_interval_max = update_interval_max
	linear_brownian_intensity = 0.0  # Disable Brownian
	_drift_time_until_update = 0.0  # Trigger first update


# =============================================================================
# ANGULAR DYNAMICS (Shared)
# =============================================================================


func _compute_nominal_angular_acceleration() -> Vector3:
	var spring_torque := Vector3.ZERO

	if align_to_acceleration:
		spring_torque = _compute_alignment_torque()
	elif use_orientation_target:
		spring_torque = -angular_stiffness * _angle_difference(angular_position, target_orientation)
	else:
		spring_torque = -angular_stiffness * angular_position

	var damping_torque := -angular_damping * angular_velocity
	var brownian := angular_brownian_torque if control_mode == ControlMode.AI else Vector3.ZERO
	var total_torque := spring_torque + damping_torque + brownian

	return total_torque / angular_inertia


func _compute_alignment_torque() -> Vector3:
	var body_accel := _get_current_body_acceleration()
	var total_accel := body_accel + gravity

	# Apply constraint to alignment vector
	total_accel = _apply_constraint_to_vector(total_accel) + gravity

	var alpha := 1.0 - exp(-get_physics_process_delta_time() / _accel_smoothing)
	_smoothed_accel = _smoothed_accel.lerp(total_accel, alpha)

	var align_vector := _smoothed_accel
	var align_magnitude := align_vector.length()

	if align_magnitude < min_accel_magnitude:
		if use_velocity_fallback and linear_velocity.length() > min_velocity_magnitude:
			align_vector = linear_velocity.normalized() * min_accel_magnitude
		else:
			align_vector = (
				gravity.normalized() * min_accel_magnitude if gravity.length() > 0 else Vector3.DOWN
			)

	var desired_forward := -align_vector.normalized()
	var desired_basis := _basis_looking_at(desired_forward, Vector3.UP)

	if bank_into_turns:
		desired_basis = _apply_banking(desired_basis, body_accel)

	var desired_euler := desired_basis.get_euler(EULER_ORDER_YXZ)
	desired_euler = _clamp_orientation_to_bounds(desired_euler)

	var angle_error := _angle_difference(angular_position, desired_euler)
	return -alignment_stiffness * angle_error


func _get_current_body_acceleration() -> Vector3:
	match control_mode:
		ControlMode.PLAYER:
			return _smoothed_input * player_acceleration
		ControlMode.AI:
			var spring_force := Vector3.ZERO
			if use_position_target:
				spring_force = -linear_stiffness * (linear_position - target_position)
			var damping_force := -linear_damping * linear_velocity
			var total_force := spring_force + damping_force + linear_brownian_force
			return total_force / linear_mass
	return Vector3.ZERO


func _basis_looking_at(forward: Vector3, up_hint: Vector3) -> Basis:
	if forward.length_squared() < 0.0001:
		return Basis.IDENTITY

	forward = forward.normalized()

	if abs(forward.dot(up_hint)) > 0.999:
		up_hint = Vector3.FORWARD if abs(forward.y) > 0.9 else Vector3.UP

	var right := up_hint.cross(forward).normalized()
	var up := forward.cross(right).normalized()

	return Basis(right, up, -forward)


func _apply_banking(basis: Basis, body_accel: Vector3) -> Basis:
	var horizontal_accel := Vector3(body_accel.x, 0, body_accel.z)

	if horizontal_accel.length() < 0.1:
		return basis

	var local_right := basis.x
	var lateral_accel := horizontal_accel.dot(local_right)

	var bank_angle := -atan(lateral_accel * bank_angle_scale / 9.81)
	bank_angle = clamp(bank_angle, -roll_limit, roll_limit)

	return basis.rotated(basis.z, bank_angle)


func _angle_difference(current: Vector3, target: Vector3) -> Vector3:
	return Vector3(
		_wrap_angle_diff(current.x - target.x),
		_wrap_angle_diff(current.y - target.y),
		_wrap_angle_diff(current.z - target.z)
	)


func _wrap_angle_diff(diff: float) -> float:
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff


# =============================================================================
# CONTROL BARRIER FUNCTIONS
# =============================================================================


func _apply_linear_cbf(nominal_accel: Vector3) -> Vector3:
	var safe := nominal_accel

	# Only apply CBF to unconstrained dimensions
	var apply_x := constraint_mode != ConstraintMode.PLANE_YZ
	var apply_y := constraint_mode != ConstraintMode.PLANE_XZ
	var apply_z := constraint_mode != ConstraintMode.PLANE_XY

	if constraint_mode == ConstraintMode.THIN_BOX:
		match thin_dimension:
			0:
				apply_x = false
			1:
				apply_y = false
			2:
				apply_z = false

	if apply_x:
		safe.x = _cbf_filter_axis(
			linear_position.x,
			linear_velocity.x,
			nominal_accel.x,
			bounds_min.x,
			bounds_max.x,
			position_cbf_alpha,
			position_safety_margin
		)

	if apply_y:
		safe.y = _cbf_filter_axis(
			linear_position.y,
			linear_velocity.y,
			nominal_accel.y,
			bounds_min.y,
			bounds_max.y,
			position_cbf_alpha,
			position_safety_margin
		)

	if apply_z:
		safe.z = _cbf_filter_axis(
			linear_position.z,
			linear_velocity.z,
			nominal_accel.z,
			bounds_min.z,
			bounds_max.z,
			position_cbf_alpha,
			position_safety_margin
		)

	return safe


func _apply_angular_cbf(nominal_accel: Vector3) -> Vector3:
	var safe := nominal_accel

	safe.x = _cbf_filter_axis(
		angular_position.x,
		angular_velocity.x,
		nominal_accel.x,
		-roll_limit,
		roll_limit,
		orientation_cbf_alpha,
		orientation_safety_margin
	)

	safe.y = _cbf_filter_axis(
		angular_position.y,
		angular_velocity.y,
		nominal_accel.y,
		-pitch_limit,
		pitch_limit,
		orientation_cbf_alpha,
		orientation_safety_margin
	)

	if constrain_yaw:
		safe.z = _cbf_filter_axis(
			angular_position.z,
			angular_velocity.z,
			nominal_accel.z,
			-yaw_limit,
			yaw_limit,
			orientation_cbf_alpha,
			orientation_safety_margin
		)

	return safe


func _cbf_filter_axis(
	pos: float,
	vel: float,
	accel: float,
	bound_min: float,
	bound_max: float,
	alpha: float,
	margin: float
) -> float:
	var safe_accel := accel
	var activation_zone := margin * 2.0

	var h_min := pos - bound_min - margin
	var h_max := bound_max - pos - margin

	if h_min < activation_zone:
		var min_accel := -alpha * vel - alpha * alpha * h_min
		safe_accel = max(safe_accel, min_accel)

	if h_max < activation_zone:
		var max_accel := alpha * vel + alpha * alpha * h_max
		safe_accel = min(safe_accel, max_accel)

	return safe_accel


# =============================================================================
# CLAMPING (Backup Safety)
# =============================================================================


func _clamp_position_to_bounds(pos: Vector3) -> Vector3:
	return Vector3(
		clamp(pos.x, bounds_min.x, bounds_max.x),
		clamp(pos.y, bounds_min.y, bounds_max.y),
		clamp(pos.z, bounds_min.z, bounds_max.z)
	)


func _clamp_orientation_to_bounds(euler: Vector3) -> Vector3:
	return Vector3(
		clamp(euler.x, -roll_limit, roll_limit),
		clamp(euler.y, -pitch_limit, pitch_limit),
		clamp(euler.z, -yaw_limit, yaw_limit) if constrain_yaw else euler.z
	)
