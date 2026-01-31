extends "res://test/gut_test_base.gd"
## Unit tests for EnemyBase - validates state machine and common enemy behavior
## NOTE: These tests will fail until EnemyBase is implemented (TDD red phase)


func test_enemy_base_exists() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	assert_not_null(enemy, "EnemyBase scene should exist and load")
	assert_true(enemy is CharacterBody3D, "EnemyBase should extend CharacterBody3D")


func test_enemy_base_starts_in_idle_state() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	assert_true("state" in enemy or "current_state" in enemy, "Should have state property")
	var state = enemy.get("state") if "state" in enemy else enemy.get("current_state")
	assert_eq(state, enemy.State.IDLE if "State" in enemy else 0, "Should start in IDLE state")


func test_enemy_base_has_entity_stats() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	await get_tree().process_frame

	var stats = enemy.find_child("EntityStats", true, false)
	assert_not_null(stats, "EnemyBase should have EntityStats child")
	assert_true(stats is EntityStats, "Child should be EntityStats type")


func test_enemy_base_activate_transitions_to_active() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	assert_true(enemy.has_method("activate"), "Should have activate() method")

	enemy.activate()
	await get_tree().process_frame

	var state = enemy.get("state") if "state" in enemy else enemy.get("current_state")
	assert_eq(state, enemy.State.ACTIVE if "State" in enemy else 1, "Should be in ACTIVE state after activate()")


func test_enemy_base_emits_died_signal_on_death() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	await get_tree().process_frame

	watch_signals(enemy)

	# Get EntityStats and trigger death
	var stats = enemy.find_child("EntityStats", true, false) as EntityStats
	if stats:
		stats.get_hit(stats.max_health)
		await get_tree().process_frame
		assert_signal_emitted(enemy, "enemy_died")
	else:
		fail_test("No EntityStats found")


func test_enemy_base_targets_player() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	# Create mock player
	var player := create_mock_player(Vector3(10, 0, 0))

	assert_true(enemy.has_method("target_player"), "Should have target_player() method")

	var target: Node3D = enemy.target_player()
	assert_eq(target, player, "Should return player from group")


func test_enemy_base_deactivate_returns_to_idle() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	assert_true(enemy.has_method("deactivate"), "Should have deactivate() method")

	enemy.activate()
	await get_tree().process_frame

	enemy.deactivate()
	await get_tree().process_frame

	var state = enemy.get("state") if "state" in enemy else enemy.get("current_state")
	assert_eq(state, enemy.State.IDLE if "State" in enemy else 0, "Should return to IDLE after deactivate()")
