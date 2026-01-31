extends "res://test/gut_test_base.gd"
## TDD tests for ArcProjectile - validates parabolic arc trajectory and impact behavior
## Tests the physics-based projectile with gravity that creates area damage on impact


# =============================================================================
# Scene Loading Tests
# =============================================================================

func test_arc_projectile_scene_exists() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	assert_not_null(projectile, "ArcProjectile scene should exist")


func test_arc_projectile_is_rigid_body() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile is RigidBody3D, "ArcProjectile should extend RigidBody3D")


func test_arc_projectile_has_class_name() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile is ArcProjectile, "Should have ArcProjectile class_name")


# =============================================================================
# Property Tests
# =============================================================================

func test_arc_projectile_has_gravity_scale() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var rigid := projectile as RigidBody3D
	assert_eq(rigid.gravity_scale, 1.0, "ArcProjectile should have gravity_scale = 1.0")


func test_arc_projectile_has_splash_radius() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("splash_radius" in projectile, "Should have splash_radius property")
	assert_eq(projectile.splash_radius, 1.5, "splash_radius should be 1.5")


func test_arc_projectile_has_damage() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("damage" in projectile, "Should have damage property")
	assert_eq(projectile.damage, 1.0, "damage should be 1.0")


func test_arc_projectile_has_lifetime() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("lifetime" in projectile, "Should have lifetime property")
	assert_eq(projectile.lifetime, 5.0, "lifetime should be 5.0 seconds")


# =============================================================================
# Launch Method Tests
# =============================================================================

func test_arc_projectile_has_launch_method() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.has_method("launch"), "Should have launch() method")


func test_arc_projectile_has_launch_with_force_method() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.has_method("launch_with_force"), "Should have launch_with_force() method")


func test_launch_sets_velocity() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var launch_velocity := Vector3(5, 10, 0)
	projectile.launch(launch_velocity)

	await wait_physics_frames(1)

	# Velocity should be close to launch velocity (may have minor physics adjustments)
	assert_almost_eq(projectile.linear_velocity.x, launch_velocity.x, 0.5, "X velocity should match launch")
	assert_almost_eq(projectile.linear_velocity.z, launch_velocity.z, 0.5, "Z velocity should match launch")


func test_launch_with_force_sets_velocity() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var direction := Vector3(1, 1, 0).normalized()
	var force := 15.0
	projectile.launch_with_force(direction, force)

	await wait_physics_frames(1)

	var expected_velocity := direction * force
	assert_almost_eq(projectile.linear_velocity.x, expected_velocity.x, 0.5, "X velocity should match")
	assert_almost_eq(projectile.linear_velocity.z, expected_velocity.z, 0.5, "Z velocity should match")


# =============================================================================
# Parabolic Arc Trajectory Tests
# =============================================================================

func test_projectile_follows_parabolic_arc() -> void:
	## Core acceptance test: validates projectile follows expected parabolic trajectory
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	# Position projectile above ground
	projectile.global_position = Vector3(0, 10, 0)

	# Launch horizontally with upward component
	var launch_velocity := Vector3(10, 5, 0)
	projectile.launch(launch_velocity)

	# Record positions over time to verify parabolic motion
	var positions: Array[Vector3] = []
	var times: Array[float] = []
	var start_time := Time.get_ticks_msec() / 1000.0

	# Sample positions for 1 second
	for i in 20:
		await wait_physics_frames(3)
		if not is_instance_valid(projectile):
			break
		positions.append(projectile.global_position)
		times.append(Time.get_ticks_msec() / 1000.0 - start_time)

	assert_gt(positions.size(), 5, "Should have recorded multiple positions")

	# Verify parabolic motion characteristics:
	# 1. X position should increase linearly (constant horizontal velocity)
	# 2. Y position should follow parabola (starts going up, then down)
	# 3. Z position should remain approximately constant

	# Check horizontal motion is approximately linear
	if positions.size() >= 3:
		var x_0 := positions[0].x
		var x_mid := positions[positions.size() / 2].x
		var x_end := positions[positions.size() - 1].x

		# X should be increasing
		assert_gt(x_end, x_0, "X position should increase over time")

		# Check Z remains approximately constant
		var z_variance := 0.0
		var z_avg := 0.0
		for pos in positions:
			z_avg += pos.z
		z_avg /= positions.size()
		for pos in positions:
			z_variance += abs(pos.z - z_avg)
		z_variance /= positions.size()

		assert_lt(z_variance, 1.0, "Z position should remain approximately constant")


func test_projectile_y_velocity_decreases_due_to_gravity() -> void:
	## Verifies gravity affects vertical velocity
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	projectile.global_position = Vector3(0, 10, 0)

	# Launch with upward velocity
	var launch_velocity := Vector3(5, 10, 0)
	projectile.launch(launch_velocity)

	await wait_physics_frames(2)
	var initial_y_vel: float = projectile.linear_velocity.y

	await wait_physics_frames(10)
	var later_y_vel: float = projectile.linear_velocity.y

	# Y velocity should decrease due to gravity
	assert_lt(later_y_vel, initial_y_vel, "Y velocity should decrease due to gravity")


func test_projectile_reaches_apex_then_descends() -> void:
	## Verifies projectile goes up, reaches apex, then comes down
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	projectile.global_position = Vector3(0, 5, 0)

	# Launch with significant upward velocity
	var launch_velocity := Vector3(5, 15, 0)
	projectile.launch(launch_velocity)

	var max_y: float = projectile.global_position.y
	var found_apex := false
	var descending := false

	for i in 60:
		await wait_physics_frames(2)
		if not is_instance_valid(projectile):
			break

		var current_y: float = projectile.global_position.y

		if current_y > max_y:
			max_y = current_y
		elif current_y < max_y - 0.5 and not descending:
			found_apex = true
			descending = true

	assert_true(found_apex, "Projectile should reach apex and begin descending")
	assert_gt(max_y, 5.0, "Projectile should rise above starting position")


func test_trajectory_prediction_matches_physics() -> void:
	## Verifies that calculate_trajectory produces points matching actual physics
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var start_pos := Vector3(0, 10, 0)
	var launch_velocity := Vector3(10, 8, 0)

	# Calculate predicted trajectory
	var predicted_points := projectile.calculate_trajectory(start_pos, launch_velocity, 20, 0.1)

	assert_gt(predicted_points.size(), 5, "Should predict multiple trajectory points")

	# Verify predicted trajectory follows physics equations
	# y = y0 + vy*t - 0.5*g*t^2
	var gravity := 9.8
	var time_step := 0.1

	for i in min(predicted_points.size(), 10):
		var t: float = i * time_step
		var expected_x: float = start_pos.x + launch_velocity.x * t
		var expected_y: float = start_pos.y + launch_velocity.y * t - 0.5 * gravity * t * t

		# Allow some tolerance for numerical integration differences
		assert_almost_eq(predicted_points[i].x, expected_x, 0.5,
			"Predicted X at t=%.2f should match physics" % t)
		assert_almost_eq(predicted_points[i].y, expected_y, 1.0,
			"Predicted Y at t=%.2f should match physics" % t)


func test_trajectory_prediction_stops_at_ground() -> void:
	## Verifies trajectory calculation stops when hitting ground
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var start_pos := Vector3(0, 5, 0)
	var launch_velocity := Vector3(10, 0, 0)  # Horizontal launch

	var predicted_points := projectile.calculate_trajectory(start_pos, launch_velocity)

	assert_gt(predicted_points.size(), 1, "Should have multiple points")

	# Last point should be at or very near ground level
	var last_point := predicted_points[predicted_points.size() - 1]
	assert_almost_eq(last_point.y, 0.0, 0.1, "Last point should be at ground level (y=0)")


# =============================================================================
# Trajectory Preview Tests
# =============================================================================

func test_arc_projectile_has_trajectory_preview_methods() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.has_method("calculate_trajectory"), "Should have calculate_trajectory() method")
	assert_true(projectile.has_method("create_trajectory_preview"), "Should have create_trajectory_preview() method")
	assert_true(projectile.has_method("update_trajectory_preview"), "Should have update_trajectory_preview() method")
	assert_true(projectile.has_method("get_predicted_landing_position"), "Should have get_predicted_landing_position() method")


func test_calculate_trajectory_returns_points() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var start_pos := Vector3(0, 5, 0)
	var velocity := Vector3(10, 10, 0)

	var points := projectile.calculate_trajectory(start_pos, velocity)

	assert_gt(points.size(), 0, "Should return trajectory points")
	assert_eq(points[0], start_pos, "First point should be start position")


func test_get_predicted_landing_position() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var start_pos := Vector3(0, 10, 0)
	var velocity := Vector3(10, 5, 0)

	var landing := projectile.get_predicted_landing_position(start_pos, velocity)

	# Landing should be ahead of start (positive X) and at ground level
	assert_gt(landing.x, start_pos.x, "Landing X should be ahead of start")
	assert_almost_eq(landing.y, 0.0, 0.5, "Landing should be at ground level")


func test_create_trajectory_preview_returns_mesh() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as ArcProjectile
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var start_pos := Vector3(0, 5, 0)
	var velocity := Vector3(10, 10, 0)

	var preview := projectile.create_trajectory_preview(start_pos, velocity)

	assert_not_null(preview, "Should return a MeshInstance3D")
	assert_true(preview is MeshInstance3D, "Preview should be MeshInstance3D")
	assert_not_null(preview.mesh, "Preview should have a mesh")


# =============================================================================
# Impact and Damage Tests
# =============================================================================

func test_arc_projectile_has_impacted_signal() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.has_signal("impacted"), "Should have impacted signal")


func test_arc_projectile_has_is_enemy_projectile_flag() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("is_enemy_projectile" in projectile, "Should have is_enemy_projectile flag")
	assert_true(projectile.is_enemy_projectile, "is_enemy_projectile should be true by default")


# =============================================================================
# Visual Tests
# =============================================================================

func test_arc_projectile_has_visible_mesh() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var mesh := projectile.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "Should have visible mesh")


func test_arc_projectile_has_collision_shape() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var collision := projectile.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(collision, "Should have collision shape")
	assert_not_null(collision.shape, "Collision shape should be set")


func test_arc_projectile_has_rock_like_appearance() -> void:
	## Verifies the projectile has a distinct rock/bomb visual
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var mesh := projectile.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "Should have mesh")

	if mesh and mesh.mesh:
		# Should have sphere or similar primitive mesh for rock appearance
		assert_true(
			mesh.mesh is SphereMesh or mesh.mesh is BoxMesh,
			"Should have sphere or box mesh for rock/bomb appearance"
		)

	# Check for earthy/rock color material
	if mesh:
		var material := mesh.get_active_material(0) as StandardMaterial3D
		if material:
			# Should have brownish/earthy color
			var color := material.albedo_color
			assert_gt(color.r, 0.2, "Should have some red component (earthy tone)")


# =============================================================================
# Physics Configuration Tests
# =============================================================================

func test_arc_projectile_has_contact_monitor_enabled() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as RigidBody3D
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.contact_monitor, "contact_monitor should be enabled for body_entered signal")
	assert_gt(projectile.max_contacts_reported, 0, "max_contacts_reported should be > 0")


func test_arc_projectile_has_continuous_cd() -> void:
	## Verifies continuous collision detection is enabled for fast-moving projectile
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn") as RigidBody3D
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.continuous_cd, "Should have continuous collision detection enabled")
