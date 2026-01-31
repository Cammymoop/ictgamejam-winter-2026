extends "res://test/gut_test_base.gd"
## Unit tests for CheckpointZone - validates checkpoint trigger and clear logic
## NOTE: These tests will fail until CheckpointZone is implemented (TDD red phase)


func test_checkpoint_zone_exists() -> void:
	# This test validates the scene can be loaded
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	assert_not_null(zone, "CheckpointZone scene should exist and load")
	assert_true(zone is Area3D, "CheckpointZone should extend Area3D")


func test_checkpoint_zone_has_required_properties() -> void:
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not zone:
		fail_test("Could not load CheckpointZone")
		return

	assert_true("checkpoint_id" in zone, "Should have checkpoint_id property")
	assert_true("required_enemies" in zone, "Should have required_enemies property")


func test_checkpoint_zone_emits_entered_signal() -> void:
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not zone:
		pending("CheckpointZone not yet implemented")
		return

	watch_signals(zone)

	# Simulate a body entering the zone
	var body := Node3D.new()
	add_child_autofree(body)
	zone.body_entered.emit(body)

	assert_signal_emitted(zone, "checkpoint_entered")


func test_checkpoint_zone_tracks_enemy_count() -> void:
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not zone:
		pending("CheckpointZone not yet implemented")
		return

	# Create mock enemies with EntityStats
	var enemies: Array[Node3D] = []
	for i in 3:
		var enemy := Node3D.new()
		var stats := EntityStats.new()
		stats.health = 10.0
		stats.max_health = 10.0
		enemy.add_child(stats)
		add_child_autofree(enemy)
		enemies.append(enemy)

	await get_tree().process_frame

	# Link enemies to checkpoint
	if zone.has_method("link_enemies"):
		zone.link_enemies(enemies)
		assert_eq(zone.get("remaining_enemies"), 3, "Should track 3 enemies")


func test_checkpoint_zone_emits_cleared_when_all_enemies_dead() -> void:
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not zone:
		pending("CheckpointZone not yet implemented")
		return

	watch_signals(zone)

	# Create one mock enemy
	var enemy := Node3D.new()
	var stats := EntityStats.new()
	stats.health = 10.0
	stats.max_health = 10.0
	enemy.add_child(stats)
	add_child_autofree(enemy)

	await get_tree().process_frame

	if zone.has_method("link_enemies"):
		zone.link_enemies([enemy])

	# Kill the enemy
	stats.get_hit(10.0)
	await get_tree().process_frame

	assert_signal_emitted(zone, "checkpoint_cleared")
