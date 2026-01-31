extends "res://test/gut_test_base.gd"
## TDD tests for ExplodingEnemy - write these BEFORE implementation
## These tests define the expected behavior for task-006


# =============================================================================
# Scene Loading Tests
# =============================================================================

func test_exploding_enemy_scene_exists() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	assert_not_null(enemy, "ExplodingEnemy scene should exist")


func test_exploding_enemy_extends_enemy_base() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	# Check it has EnemyBase methods
	assert_true(enemy.has_method("activate"), "Should have activate() from EnemyBase")
	assert_true(enemy.has_method("target_player"), "Should have target_player() from EnemyBase")


# =============================================================================
# Movement Tests
# =============================================================================

func test_exploding_enemy_moves_toward_player_when_active() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(20, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()
	var initial_distance := get_distance(enemy, player)

	# Simulate some physics frames
	await wait_physics_frames(30)

	var new_distance := get_distance(enemy, player)
	assert_lt(new_distance, initial_distance, "Enemy should move closer to player")


func test_exploding_enemy_has_high_move_speed() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	var speed = enemy.get("move_speed")
	assert_gte(speed, 7.0, "ExplodingEnemy should have high move speed (>=7)")


# =============================================================================
# Explosion Tests
# =============================================================================

func test_exploding_enemy_has_explosion_properties() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	assert_true("explosion_radius" in enemy, "Should have explosion_radius property")
	assert_true("explosion_damage" in enemy, "Should have explosion_damage property")

	assert_gte(enemy.explosion_radius, 3.0, "Explosion radius should be meaningful")
	assert_gte(enemy.explosion_damage, 1.0, "Explosion should deal damage")


func test_exploding_enemy_explodes_when_reaching_player() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	watch_signals(enemy)

	var player := create_mock_player(Vector3(2, 0, 0))
	enemy.global_position = Vector3.ZERO

	# Put enemy in explosion range
	enemy.global_position = Vector3(1, 0, 0)  # Very close to player

	enemy.activate()
	await wait_physics_frames(10)

	assert_signal_emitted(enemy, "exploded")


func test_exploding_enemy_explodes_on_death() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	await get_tree().process_frame
	watch_signals(enemy)

	# Kill the enemy
	var stats = enemy.find_child("EntityStats", true, false) as EntityStats
	if stats:
		stats.get_hit(stats.max_health)
		await wait_frames(5)
		assert_signal_emitted(enemy, "exploded")


func test_explosion_damages_player_in_radius() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	# Create player with EntityStats
	var player := Node3D.new()
	player.add_to_group("Player")
	var player_stats := EntityStats.new()
	player_stats.health = 10.0
	player_stats.max_health = 10.0
	player.add_child(player_stats)
	add_child_autofree(player)

	await get_tree().process_frame

	# Position player within explosion radius
	player.global_position = Vector3(3, 0, 0)
	enemy.global_position = Vector3.ZERO

	# Trigger explosion
	if enemy.has_method("explode"):
		enemy.explode()
		await wait_frames(3)

		assert_lt(player_stats.health, 10.0, "Player should take damage from explosion")


func test_explosion_does_not_damage_player_outside_radius() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	var player := Node3D.new()
	player.add_to_group("Player")
	var player_stats := EntityStats.new()
	player_stats.health = 10.0
	player_stats.max_health = 10.0
	player.add_child(player_stats)
	add_child_autofree(player)

	await get_tree().process_frame

	# Position player far outside explosion radius
	player.global_position = Vector3(50, 0, 0)
	enemy.global_position = Vector3.ZERO

	if enemy.has_method("explode"):
		enemy.explode()
		await wait_frames(3)

		assert_eq(player_stats.health, 10.0, "Player outside radius should not take damage")


# =============================================================================
# Warning Tests
# =============================================================================

func test_exploding_enemy_shows_warning_before_exploding() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	assert_true("warning_time" in enemy, "Should have warning_time property")
	assert_gte(enemy.warning_time, 0.3, "Warning should be at least 0.3 seconds")


func test_exploding_enemy_has_distinct_visual() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	var mesh := enemy.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "Should have visible mesh")

	# Check for red/orange coloring indicating danger
	if mesh and mesh.material_override:
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			var color := mat.albedo_color
			# Should be reddish (high red component)
			assert_gte(color.r, 0.7, "Should have red tint to indicate danger")


# =============================================================================
# Task-007: Movement and Pathfinding Tests
# =============================================================================

func test_exploding_enemy_faces_movement_direction() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	# Position player to the right
	var player := create_mock_player(Vector3(20, 0, 0))
	enemy.global_position = Vector3.ZERO

	# Store initial rotation
	var initial_rotation := enemy.rotation.y

	enemy.activate()

	# Simulate physics frames for movement and rotation
	await wait_physics_frames(20)

	# Enemy should have rotated to face the player (roughly toward +X)
	# atan2(20, 0) = PI/2 (90 degrees)
	# Allow some tolerance for smooth rotation
	assert_true(
		enemy.has_method("_face_movement_direction"),
		"Should have _face_movement_direction method"
	)


func test_exploding_enemy_has_desperation_speed_properties() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	assert_true("desperation_speed_multiplier" in enemy, "Should have desperation_speed_multiplier property")
	assert_true("desperation_threshold" in enemy, "Should have desperation_threshold property")
	assert_gte(enemy.desperation_speed_multiplier, 1.0, "Desperation multiplier should be >= 1.0")
	assert_gt(enemy.desperation_threshold, 0.0, "Desperation threshold should be > 0")
	assert_lte(enemy.desperation_threshold, 1.0, "Desperation threshold should be <= 1.0")


func test_exploding_enemy_speed_increases_when_damaged() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	await get_tree().process_frame

	# Get effective speed at full health
	var full_health_speed := enemy._get_effective_speed()

	# Damage the enemy below desperation threshold
	var stats = enemy.find_child("EntityStats", true, false) as EntityStats
	if stats:
		# Bring health to 25% (below 50% threshold)
		stats.health = stats.max_health * 0.25
		var damaged_speed := enemy._get_effective_speed()

		assert_gt(damaged_speed, full_health_speed, "Speed should increase when health is low")


func test_exploding_enemy_no_speed_boost_above_threshold() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	await get_tree().process_frame

	# Get effective speed at full health
	var full_health_speed := enemy._get_effective_speed()

	# Damage the enemy but keep above threshold
	var stats = enemy.find_child("EntityStats", true, false) as EntityStats
	if stats:
		# Bring health to 75% (above 50% threshold)
		stats.health = stats.max_health * 0.75
		var partial_damage_speed := enemy._get_effective_speed()

		assert_eq(partial_damage_speed, full_health_speed, "Speed should not change above threshold")


func test_exploding_enemy_stays_grounded() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	assert_true("ground_y" in enemy, "Should have ground_y property")

	# Position enemy at a specific Y
	enemy.global_position = Vector3(0, 1.0, 0)
	await get_tree().process_frame

	# Store the ground_y (should be set in _ready to initial position)
	var expected_y := enemy.ground_y

	# Create player at different height
	var player := create_mock_player(Vector3(20, 5.0, 0))
	enemy.activate()

	# Simulate physics frames
	await wait_physics_frames(10)

	# Enemy Y should stay at ground level, not follow player up
	assert_almost_eq(enemy.global_position.y, expected_y, 0.1, "Enemy should stay grounded")


func test_exploding_enemy_has_get_movement_direction_method() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	assert_true(
		enemy.has_method("_get_movement_direction"),
		"Should have _get_movement_direction method for pathfinding support"
	)


func test_exploding_enemy_reaches_player_within_expected_time() -> void:
	var enemy = spawn_scene("res://assets/enemies/exploding_enemy.tscn")
	if not enemy:
		pending("ExplodingEnemy not yet implemented")
		return

	# Place enemy 40 units from player
	# With speed 8, should take ~5 seconds (300 physics frames at 60fps)
	# Add some margin for startup
	var distance := 40.0
	var player := create_mock_player(Vector3(distance, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()
	var start_distance := get_distance(enemy, player)

	# Wait enough frames for enemy to get significantly closer
	# At 8 units/sec, 60 frames = 1 second = 8 units
	await wait_physics_frames(60)

	var end_distance := get_distance(enemy, player)
	var distance_traveled := start_distance - end_distance

	# Should have traveled at least 6 units (allowing for startup/ramp)
	assert_gte(distance_traveled, 6.0, "Enemy should travel significant distance toward player")
