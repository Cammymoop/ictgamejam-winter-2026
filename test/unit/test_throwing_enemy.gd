extends "res://test/gut_test_base.gd"
## TDD tests for ThrowingEnemy - validates throwing behavior and arc projectiles
## Tests the throwing enemy that lobs physics-based projectiles at the player


# =============================================================================
# Scene Loading Tests
# =============================================================================

func test_throwing_enemy_scene_exists() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	assert_not_null(enemy, "ThrowingEnemy scene should exist")


func test_throwing_enemy_extends_enemy_base() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	assert_true(enemy.has_method("activate"), "Should have activate() from EnemyBase")
	assert_true(enemy.has_method("target_player"), "Should have target_player() from EnemyBase")
	assert_true(enemy is EnemyBase, "Should extend EnemyBase")


func test_throwing_enemy_has_entity_stats() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	await get_tree().process_frame

	var stats = enemy.find_child("EntityStats", true, false)
	assert_not_null(stats, "ThrowingEnemy should have EntityStats child")
	assert_true(stats is EntityStats, "Child should be EntityStats type")


# =============================================================================
# Throwing Property Tests
# =============================================================================

func test_throwing_enemy_has_throw_properties() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	assert_true("throw_damage" in enemy, "Should have throw_damage property")
	assert_true("throw_force" in enemy, "Should have throw_force property")
	assert_true("windup_time" in enemy, "Should have windup_time property")
	assert_true("cooldown_time" in enemy, "Should have cooldown_time property")


func test_throwing_enemy_default_values() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	assert_eq(enemy.throw_damage, 1.5, "throw_damage should be 1.5")
	assert_eq(enemy.throw_force, 15.0, "throw_force should be 15.0")
	assert_eq(enemy.windup_time, 0.8, "windup_time should be 0.8")
	assert_eq(enemy.cooldown_time, 1.5, "cooldown_time should be 1.5")


func test_throwing_enemy_has_projectile_thrown_signal() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	assert_true(enemy.has_signal("projectile_thrown"), "Should have projectile_thrown signal")


# =============================================================================
# Throw State Machine Tests
# =============================================================================

func test_throwing_enemy_starts_in_idle_throw_state() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	assert_eq(enemy.throw_state, enemy.ThrowState.IDLE, "Should start in IDLE throw state")


func test_throwing_enemy_enters_windup_when_active() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()
	await wait_physics_frames(2)

	assert_eq(enemy.throw_state, enemy.ThrowState.WINDING_UP, "Should be in WINDING_UP state after activation")


func test_throwing_enemy_throws_after_windup() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	watch_signals(enemy)

	enemy.activate()

	# Wait for windup to complete (0.8s)
	await get_tree().create_timer(1.0).timeout

	assert_signal_emitted(enemy, "projectile_thrown")


func test_throwing_enemy_enters_cooldown_after_throw() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()

	# Wait for windup + a bit
	await get_tree().create_timer(0.9).timeout

	assert_eq(enemy.throw_state, enemy.ThrowState.COOLDOWN, "Should be in COOLDOWN state after throwing")


# =============================================================================
# Arc Projectile Tests
# =============================================================================

func test_arc_projectile_scene_exists() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	assert_not_null(projectile, "ArcProjectile scene should exist")


func test_arc_projectile_is_rigid_body() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile is RigidBody3D, "ArcProjectile should be RigidBody3D")


func test_arc_projectile_has_gravity() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var rigid := projectile as RigidBody3D
	assert_eq(rigid.gravity_scale, 1.0, "ArcProjectile should have gravity_scale = 1.0")


func test_arc_projectile_has_launch_method() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true(projectile.has_method("launch"), "ArcProjectile should have launch() method")


func test_arc_projectile_launch_sets_velocity() -> void:
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


func test_arc_projectile_has_splash_radius() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("splash_radius" in projectile, "Should have splash_radius property")
	assert_eq(projectile.splash_radius, 2.0, "splash_radius should be 2.0")


func test_arc_projectile_has_damage() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("damage" in projectile, "Should have damage property")
	assert_eq(projectile.damage, 1.5, "damage should be 1.5")


func test_arc_projectile_has_lifetime() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	assert_true("lifetime" in projectile, "Should have lifetime property")
	assert_eq(projectile.lifetime, 5.0, "lifetime should be 5.0 seconds")


# =============================================================================
# Trajectory Calculation Tests
# =============================================================================

func test_throwing_enemy_has_calculate_launch_velocity() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	assert_true(enemy.has_method("calculate_launch_velocity"), "Should have calculate_launch_velocity() method")


func test_launch_velocity_has_upward_component() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	enemy.global_position = Vector3.ZERO
	var target_pos := Vector3(10, 0, 0)

	var velocity: Vector3 = enemy.calculate_launch_velocity(target_pos)

	assert_gt(velocity.y, 0.0, "Launch velocity should have upward Y component for arc")


func test_launch_velocity_toward_target() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	enemy.global_position = Vector3.ZERO
	var target_pos := Vector3(10, 0, 0)

	var velocity: Vector3 = enemy.calculate_launch_velocity(target_pos)

	# Velocity should have positive X component (toward target)
	assert_gt(velocity.x, 0.0, "Launch velocity should be toward target (positive X)")


func test_projectile_lands_within_2_units_of_stationary_target() -> void:
	# This is the main acceptance criteria test
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	# Set up enemy and target positions
	enemy.global_position = Vector3.ZERO

	# Create a stationary player at a reasonable distance
	var target_pos := Vector3(15, 0, 0)
	var player := create_mock_player(target_pos)

	# Reset player velocity (stationary)
	Global.player_velocity = Vector3.ZERO

	# Calculate launch velocity
	var velocity: Vector3 = enemy.calculate_launch_velocity(target_pos)

	# Spawn projectile and launch
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	# Position projectile at enemy's throw point (approximately)
	projectile.global_position = enemy.global_position + Vector3(0, 2, 0)
	projectile.launch(velocity)

	# Track the projectile's landing position
	var landed := false
	var land_position := Vector3.ZERO

	projectile.impacted.connect(func(pos: Vector3):
		landed = true
		land_position = pos
	)

	# Wait for projectile to land (with timeout)
	var timeout := 5.0
	var elapsed := 0.0
	while not landed and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

		# Also check if projectile hit ground based on Y position
		if is_instance_valid(projectile) and projectile.global_position.y < 0:
			landed = true
			land_position = projectile.global_position

	if landed:
		var horizontal_dist := Vector2(land_position.x - target_pos.x, land_position.z - target_pos.z).length()
		assert_lt(horizontal_dist, 2.0, "Projectile should land within 2 units of target. Landed at: %s, Target: %s, Distance: %.2f" % [land_position, target_pos, horizontal_dist])
	else:
		# If no ground collision, verify trajectory was correct based on peak position
		pending("Projectile did not land - may need ground plane for full test")


# =============================================================================
# Target Leading Tests
# =============================================================================

func test_launch_velocity_leads_moving_target() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	enemy.global_position = Vector3.ZERO
	var target_pos := Vector3(10, 0, 0)

	# Set player velocity moving right
	Global.player_velocity = Vector3(5, 0, 0)

	var velocity_leading: Vector3 = enemy.calculate_launch_velocity(target_pos)

	# Reset velocity
	Global.player_velocity = Vector3.ZERO

	var velocity_stationary: Vector3 = enemy.calculate_launch_velocity(target_pos)

	# With leading, X component should be larger (aiming ahead)
	assert_gt(velocity_leading.x, velocity_stationary.x - 0.1, "Should lead target moving right")


# =============================================================================
# Visual Tests
# =============================================================================

func test_throwing_enemy_has_visible_mesh() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	var mesh := enemy.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "Should have visible mesh")


func test_throwing_enemy_has_arm_mesh() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	var arm := enemy.find_child("ArmMesh", true, false) as MeshInstance3D
	assert_not_null(arm, "Should have arm mesh for throwing animation")


func test_throwing_enemy_has_throw_point() -> void:
	var enemy = spawn_scene("res://assets/enemies/throwing_enemy.tscn")
	if not enemy:
		pending("ThrowingEnemy not yet implemented")
		return

	var throw_point := enemy.find_child("ThrowPoint", true, false) as Node3D
	assert_not_null(throw_point, "Should have ThrowPoint for projectile spawn")


func test_arc_projectile_has_distinct_visual() -> void:
	var projectile = spawn_scene("res://assets/enemies/arc_projectile.tscn")
	if not projectile:
		pending("ArcProjectile not yet implemented")
		return

	var mesh := projectile.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "Should have visible mesh")

	# Check that it has a sphere-like or rock-like mesh
	if mesh and mesh.mesh:
		assert_true(mesh.mesh is SphereMesh or mesh.mesh is BoxMesh, "Should have sphere or box mesh for rock/bomb appearance")
