extends RefCounted

const BFC = preload("res://dynamics/bounded_flight_controller_6dof.gd")

# Track controllers for cleanup
var _controllers: Array[Node] = []

# =============================================================================
# HELPER
# =============================================================================

func _create_controller() -> BFC:
	var ctrl := BFC.new()
	ctrl._initialized = true  # bypass _ready()
	ctrl.linear_position = Vector3.ZERO
	ctrl.linear_velocity = Vector3.ZERO
	ctrl.angular_position = Vector3.ZERO
	ctrl.angular_velocity = Vector3.ZERO
	_controllers.append(ctrl)
	return ctrl

func _cleanup() -> void:
	for ctrl in _controllers:
		if is_instance_valid(ctrl):
			ctrl.free()
	_controllers.clear()

# =============================================================================
# CONFIGURATION TESTS
# =============================================================================

func test_configure_as_player() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_player(25.0, 15.0)

	if ctrl.control_mode != BFC.ControlMode.PLAYER:
		return false
	if not is_equal_approx(ctrl.player_acceleration, 25.0):
		return false
	if not is_equal_approx(ctrl.player_max_speed, 15.0):
		return false
	if not is_equal_approx(ctrl.linear_brownian_intensity, 0.0):
		return false
	if not is_equal_approx(ctrl.angular_brownian_intensity, 0.0):
		return false
	return true

func test_configure_as_ai() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_ai(8.0, true)

	if ctrl.control_mode != BFC.ControlMode.AI:
		return false
	if not is_equal_approx(ctrl.linear_brownian_intensity, 8.0):
		return false
	if not ctrl.use_position_target:
		return false
	return true

func test_configure_plane_constraint_xz() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_XZ, 5.0)

	if ctrl.constraint_mode != BFC.ConstraintMode.PLANE_XZ:
		return false
	if not is_equal_approx(ctrl.plane_position, 5.0):
		return false
	return true

func test_configure_plane_constraint_xy() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_XY, 3.0)

	if ctrl.constraint_mode != BFC.ConstraintMode.PLANE_XY:
		return false
	if not ctrl.constrain_yaw:
		return false
	return true

func test_set_position_bounds() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-20, -10, -30), Vector3(20, 10, 30))

	if not ctrl.bounds_min.is_equal_approx(Vector3(-20, -10, -30)):
		return false
	if not ctrl.bounds_max.is_equal_approx(Vector3(20, 10, 30)):
		return false
	return true

func test_set_position_bounds_clamps_position() -> bool:
	var ctrl := _create_controller()
	ctrl.linear_position = Vector3(100, 100, 100)
	ctrl.set_position_bounds(Vector3(-5, -5, -5), Vector3(5, 5, 5))

	# Position should be clamped to new bounds
	if ctrl.linear_position.x > 5.0 or ctrl.linear_position.y > 5.0 or ctrl.linear_position.z > 5.0:
		return false
	return true

# =============================================================================
# CBF SAFETY TESTS
# =============================================================================

func test_cbf_prevents_boundary_violation() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-5, -5, -5), Vector3(5, 5, 5))
	ctrl.linear_position = Vector3(4.5, 0, 0)  # near +X boundary
	ctrl.linear_velocity = Vector3(10, 0, 0)   # moving fast toward boundary

	# Run several physics steps
	for i in range(20):
		ctrl._physics_process(0.016)

	var state := ctrl.get_state()
	# Should remain within bounds
	if state.position.x > 5.0:
		return false
	return true

func test_cbf_prevents_boundary_violation_negative() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-5, -5, -5), Vector3(5, 5, 5))
	ctrl.linear_position = Vector3(-4.5, 0, 0)  # near -X boundary
	ctrl.linear_velocity = Vector3(-10, 0, 0)   # moving fast toward boundary

	for i in range(20):
		ctrl._physics_process(0.016)

	var state := ctrl.get_state()
	if state.position.x < -5.0:
		return false
	return true

func test_cbf_allows_safe_motion() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.set_position_bounds(Vector3(-10, -10, -10), Vector3(10, 10, 10))
	ctrl.linear_position = Vector3.ZERO  # center
	ctrl.set_input_direction(Vector3(1, 0, 0))  # move right

	# Run physics
	for i in range(10):
		ctrl._physics_process(0.016)

	var state := ctrl.get_state()
	# Should have moved right
	if state.position.x <= 0.0:
		return false
	# Should not have hit the boundary
	if state.position.x >= 10.0:
		return false
	return true

func test_barrier_values_reflect_proximity() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-10, -10, -10), Vector3(10, 10, 10))

	# Position in center
	ctrl.linear_position = Vector3.ZERO
	var barriers_center := ctrl.get_barrier_values()

	# Position near +X boundary
	ctrl.linear_position = Vector3(9, 0, 0)
	var barriers_near := ctrl.get_barrier_values()

	# Barrier value for +X should be smaller when near +X boundary
	if barriers_near.pos_x_max >= barriers_center.pos_x_max:
		return false
	# Barrier value for -X should be larger when far from -X boundary
	if barriers_near.pos_x_min <= barriers_center.pos_x_min:
		return false
	return true

# =============================================================================
# PHYSICS INTEGRATION TESTS
# =============================================================================

func test_player_input_accelerates() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.set_position_bounds(Vector3(-100, -100, -100), Vector3(100, 100, 100))

	ctrl.set_input_direction(Vector3(1, 0, 0))
	var initial_speed := ctrl.linear_velocity.length()

	for i in range(10):
		ctrl._physics_process(0.016)

	var final_speed := ctrl.linear_velocity.length()
	if final_speed <= initial_speed:
		return false
	return true

func test_drag_decelerates() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.set_position_bounds(Vector3(-100, -100, -100), Vector3(100, 100, 100))
	ctrl.linear_velocity = Vector3(5, 0, 0)
	ctrl.set_input_direction(Vector3.ZERO)  # no input

	var initial_speed := ctrl.linear_velocity.length()

	for i in range(30):
		ctrl._physics_process(0.016)

	var final_speed := ctrl.linear_velocity.length()
	if final_speed >= initial_speed:
		return false
	return true

func test_impulse_application() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-100, -100, -100), Vector3(100, 100, 100))
	ctrl.linear_velocity = Vector3.ZERO

	ctrl.apply_linear_impulse(Vector3(10, 0, 0))

	if ctrl.linear_velocity.x <= 0:
		return false
	return true

func test_impulse_respects_mass() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-100, -100, -100), Vector3(100, 100, 100))
	ctrl.linear_velocity = Vector3.ZERO
	ctrl.linear_mass = 2.0

	ctrl.apply_linear_impulse(Vector3(10, 0, 0))

	# v = impulse / mass = 10 / 2 = 5
	if not is_equal_approx(ctrl.linear_velocity.x, 5.0):
		return false
	return true

func test_angular_impulse_application() -> bool:
	var ctrl := _create_controller()
	ctrl.angular_velocity = Vector3.ZERO

	ctrl.apply_angular_impulse(Vector3(0, 1, 0))

	if ctrl.angular_velocity.y <= 0:
		return false
	return true

# =============================================================================
# CONSTRAINT MODE TESTS
# =============================================================================

func test_plane_xz_constraint() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_XZ, 5.0)
	ctrl.set_position_bounds(Vector3(-10, 5, -10), Vector3(10, 5, 10))
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.linear_position = Vector3(0, 5, 0)

	# Try to move in Y direction
	ctrl.set_input_direction(Vector3(0, 1, 0))

	for i in range(20):
		ctrl._physics_process(0.016)

	# Y should stay fixed at plane_position
	if not is_equal_approx(ctrl.linear_position.y, 5.0):
		return false
	return true

func test_plane_xy_constraint() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_XY, 3.0)
	ctrl.set_position_bounds(Vector3(-10, -10, 3), Vector3(10, 10, 3))
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.linear_position = Vector3(0, 0, 3)

	# Try to move in Z direction
	ctrl.set_input_direction(Vector3(0, 0, 1))

	for i in range(20):
		ctrl._physics_process(0.016)

	# Z should stay fixed at plane_position
	if not is_equal_approx(ctrl.linear_position.z, 3.0):
		return false
	return true

func test_plane_yz_constraint() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_YZ, -2.0)
	ctrl.set_position_bounds(Vector3(-2, -10, -10), Vector3(-2, 10, 10))
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.linear_position = Vector3(-2, 0, 0)

	# Try to move in X direction
	ctrl.set_input_direction(Vector3(1, 0, 0))

	for i in range(20):
		ctrl._physics_process(0.016)

	# X should stay fixed at plane_position
	if not is_equal_approx(ctrl.linear_position.x, -2.0):
		return false
	return true

func test_orientation_bounds() -> bool:
	var ctrl := _create_controller()
	ctrl.roll_limit = PI / 4
	ctrl.pitch_limit = PI / 4
	var out_of_bounds := Vector3(PI, PI, 0)  # way outside limits

	# Clamp should bring it within bounds
	var clamped := ctrl._clamp_orientation_to_bounds(out_of_bounds)

	if abs(clamped.x) > ctrl.roll_limit + 0.001:
		return false
	if abs(clamped.y) > ctrl.pitch_limit + 0.001:
		return false
	return true

# =============================================================================
# AI BEHAVIOR TESTS
# =============================================================================

func test_brownian_motion_produces_movement() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_ai(10.0, false)
	ctrl.set_position_bounds(Vector3(-50, -50, -50), Vector3(50, 50, 50))
	ctrl.linear_position = Vector3.ZERO

	var initial_pos := ctrl.linear_position

	# Run many physics steps
	for i in range(100):
		ctrl._physics_process(0.016)

	var final_pos := ctrl.linear_position

	# Should have moved from origin
	var distance := initial_pos.distance_to(final_pos)
	if distance < 0.1:
		return false
	return true

func test_target_tracking() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_ai(0.0, true)  # No brownian, just target tracking
	ctrl.set_position_bounds(Vector3(-50, -50, -50), Vector3(50, 50, 50))
	ctrl.linear_position = Vector3.ZERO
	ctrl.set_position_target(Vector3(10, 0, 0), true)
	ctrl.linear_stiffness = 2.0

	# Run physics - should move toward target
	for i in range(100):
		ctrl._physics_process(0.016)

	# Should have moved toward +X
	if ctrl.linear_position.x <= 0:
		return false
	return true

func test_discrete_drift_produces_movement() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_drift_enemy(10.0, 0.1, 0.2)
	ctrl.set_position_bounds(Vector3(-50, -50, -50), Vector3(50, 50, 50))
	ctrl.linear_position = Vector3.ZERO

	var initial_pos := ctrl.linear_position

	for i in range(100):
		ctrl._physics_process(0.016)

	var final_pos := ctrl.linear_position
	var distance := initial_pos.distance_to(final_pos)

	if distance < 0.1:
		return false
	return true

# =============================================================================
# STATE QUERY TESTS
# =============================================================================

func test_get_state_returns_correct_values() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.linear_position = Vector3(1, 2, 3)
	ctrl.linear_velocity = Vector3(4, 5, 6)
	ctrl.angular_position = Vector3(0.1, 0.2, 0.3)

	var state := ctrl.get_state()

	if not state.position.is_equal_approx(Vector3(1, 2, 3)):
		return false
	if not state.velocity.is_equal_approx(Vector3(4, 5, 6)):
		return false
	if state.control_mode != "PLAYER":
		return false
	return true

func test_is_safe_returns_true_when_safe() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-10, -10, -10), Vector3(10, 10, 10))
	ctrl.linear_position = Vector3.ZERO  # center
	ctrl.angular_position = Vector3.ZERO

	if not ctrl.is_safe():
		return false
	return true

func test_reset_to_center() -> bool:
	var ctrl := _create_controller()
	ctrl.set_position_bounds(Vector3(-10, -10, -10), Vector3(10, 10, 10))
	ctrl.linear_position = Vector3(5, 5, 5)
	ctrl.linear_velocity = Vector3(10, 10, 10)
	ctrl.angular_position = Vector3(0.5, 0.5, 0.5)
	ctrl.angular_velocity = Vector3(1, 1, 1)

	ctrl.reset_to_center()

	if not ctrl.linear_position.is_equal_approx(Vector3.ZERO):
		return false
	if not ctrl.linear_velocity.is_equal_approx(Vector3.ZERO):
		return false
	if not ctrl.angular_position.is_equal_approx(Vector3.ZERO):
		return false
	if not ctrl.angular_velocity.is_equal_approx(Vector3.ZERO):
		return false
	return true

# =============================================================================
# PLAYER DYNAMICS MODE TESTS
# =============================================================================

func test_configure_player_tf() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_player_tf("snappy", "fast")

	if ctrl.control_mode != BFC.ControlMode.PLAYER:
		return false
	if ctrl.player_dynamics_mode != BFC.PlayerDynamicsMode.TRANSFER_FUNCTION:
		return false
	if not is_equal_approx(ctrl.tf_damping_ratio, 0.7):
		return false
	if not is_equal_approx(ctrl.tf_velocity_scale, 15.0):
		return false
	return true

func test_player_boost_increases_speed() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_as_player(20.0, 10.0)
	ctrl.player_boost_multiplier = 2.0
	ctrl.set_position_bounds(Vector3(-100, -100, -100), Vector3(100, 100, 100))

	# First without boost
	ctrl.linear_position = Vector3.ZERO
	ctrl.linear_velocity = Vector3.ZERO
	ctrl.set_input_direction(Vector3(1, 0, 0))
	ctrl.set_boosting(false)

	for i in range(100):
		ctrl._physics_process(0.016)

	var speed_normal := ctrl.linear_velocity.length()

	# Now with boost
	ctrl.linear_position = Vector3.ZERO
	ctrl.linear_velocity = Vector3.ZERO
	ctrl.set_boosting(true)

	for i in range(100):
		ctrl._physics_process(0.016)

	var speed_boosted := ctrl.linear_velocity.length()

	# Boosted max speed should be higher
	if speed_boosted <= speed_normal:
		return false
	return true

# =============================================================================
# 2D INPUT TESTS
# =============================================================================

func test_set_input_2d_plane_xz() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_XZ, 0.0)

	ctrl.set_input_2d(1.0, 1.0)  # right + forward

	# In PLANE_XZ: horizontal->X, vertical->-Z
	if not is_equal_approx(ctrl._input_direction.x, 1.0):
		return false
	if not is_equal_approx(ctrl._input_direction.y, 0.0):
		return false
	if not is_equal_approx(ctrl._input_direction.z, -1.0):
		return false
	return true

func test_set_input_2d_plane_xy() -> bool:
	var ctrl := _create_controller()
	ctrl.configure_plane_constraint(BFC.ConstraintMode.PLANE_XY, 0.0)

	ctrl.set_input_2d(1.0, 1.0)  # right + up

	# In PLANE_XY: horizontal->X, vertical->Y
	if not is_equal_approx(ctrl._input_direction.x, 1.0):
		return false
	if not is_equal_approx(ctrl._input_direction.y, 1.0):
		return false
	if not is_equal_approx(ctrl._input_direction.z, 0.0):
		return false
	return true
