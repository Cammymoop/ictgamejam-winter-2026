extends "res://test/gut_test_base.gd"
## Unit tests for EnemySpawner - validates enemy wave spawning and tracking


func test_enemy_spawner_exists() -> void:
	# Validate the scene can be loaded
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	assert_not_null(spawner, "EnemySpawner scene should exist and load")
	assert_true(spawner is Node3D, "EnemySpawner should extend Node3D")


func test_enemy_spawner_has_required_properties() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	assert_true("enemy_scenes" in spawner, "Should have enemy_scenes property")
	assert_true("spawn_delay" in spawner, "Should have spawn_delay property")
	assert_true("spawn_positions" in spawner, "Should have spawn_positions property")
	assert_true("spawned_enemies" in spawner, "Should have spawned_enemies property")
	assert_true("remaining_enemies" in spawner, "Should have remaining_enemies property")


func test_enemy_spawner_collects_marker3d_children() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	# The scene has 3 Marker3D children defined
	assert_eq(spawner.spawn_positions.size(), 3, "Should collect 3 Marker3D spawn positions")


func test_enemy_spawner_spawn_wave_creates_enemies() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	# Load the test enemy scene
	var enemy_scene = load("res://assets/enemies/laser_enemy.tscn")
	assert_not_null(enemy_scene, "Test enemy scene should load")

	# Configure spawner with 2 enemy scenes (fewer than spawn positions)
	var scenes: Array[PackedScene] = [enemy_scene, enemy_scene]
	spawner.enemy_scenes = scenes
	spawner.spawn_delay = 0.0  # No delay for faster tests

	# Spawn the wave
	var enemies = await spawner.spawn_wave()

	assert_eq(enemies.size(), 2, "Should spawn 2 enemies (limited by enemy_scenes array)")
	assert_eq(spawner.spawned_enemies.size(), 2, "spawned_enemies should track spawned enemies")
	assert_eq(spawner.remaining_enemies, 2, "remaining_enemies should be 2")

	# Clean up spawned enemies
	for enemy in enemies:
		enemy.queue_free()


func test_enemy_spawner_spawn_count_matches_minimum() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	var enemy_scene = load("res://assets/enemies/laser_enemy.tscn")

	# Add more enemy scenes than spawn positions (3 positions, 5 scenes)
	var scenes: Array[PackedScene] = [enemy_scene, enemy_scene, enemy_scene, enemy_scene, enemy_scene]
	spawner.enemy_scenes = scenes
	spawner.spawn_delay = 0.0

	var enemies = await spawner.spawn_wave()

	assert_eq(enemies.size(), 3, "Should spawn only 3 enemies (limited by spawn positions)")

	for enemy in enemies:
		enemy.queue_free()


func test_enemy_spawner_emits_wave_spawned_signal() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	var enemy_scene = load("res://assets/enemies/laser_enemy.tscn")
	var scenes: Array[PackedScene] = [enemy_scene]
	spawner.enemy_scenes = scenes
	spawner.spawn_delay = 0.0

	watch_signals(spawner)

	var enemies = await spawner.spawn_wave()
	await get_tree().process_frame

	assert_signal_emitted(spawner, "wave_spawned")

	for enemy in enemies:
		enemy.queue_free()


func test_enemy_spawner_emits_wave_cleared_when_all_enemies_die() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	var enemy_scene = load("res://assets/enemies/laser_enemy.tscn")
	var scenes: Array[PackedScene] = [enemy_scene]
	spawner.enemy_scenes = scenes
	spawner.spawn_delay = 0.0

	var enemies = await spawner.spawn_wave()
	await get_tree().process_frame

	watch_signals(spawner)

	# Kill the enemy by triggering death without visual effects
	# (bypasses _play_death_effect which causes material errors in headless mode)
	var enemy = enemies[0]
	var stats = enemy.find_child("EntityStats", true, false)
	assert_not_null(stats, "Enemy should have EntityStats")

	# Disconnect the enemy's death handler to prevent _play_death_effect
	if stats.out_of_health.is_connected(enemy._on_entity_stats_out_of_health):
		stats.out_of_health.disconnect(enemy._on_entity_stats_out_of_health)

	# Emit out_of_health - spawner listens to this signal directly
	stats.out_of_health.emit()
	await get_tree().process_frame

	assert_signal_emitted(spawner, "wave_cleared")


func test_enemy_spawner_positions_enemies_at_markers() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	var enemy_scene = load("res://assets/enemies/laser_enemy.tscn")
	var scenes: Array[PackedScene] = [enemy_scene, enemy_scene]
	spawner.enemy_scenes = scenes
	spawner.spawn_delay = 0.0

	var enemies = await spawner.spawn_wave()
	await get_tree().process_frame

	# Verify enemies are positioned at spawn points
	for i in enemies.size():
		var expected_pos = spawner.spawn_positions[i].global_position
		var actual_pos = enemies[i].global_position
		assert_almost_eq(actual_pos, expected_pos, Vector3(0.01, 0.01, 0.01),
			"Enemy %d should be at spawn position %d" % [i, i])

	for enemy in enemies:
		enemy.queue_free()


func test_enemy_spawner_has_signals() -> void:
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		fail_test("Could not load EnemySpawner")
		return

	assert_true(spawner.has_signal("wave_spawned"), "Should have wave_spawned signal")
	assert_true(spawner.has_signal("wave_cleared"), "Should have wave_cleared signal")
