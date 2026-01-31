extends "res://test/gut_test_base.gd"
## Unit tests for EntityStats component - validates the health/damage system


func test_entity_stats_initial_health() -> void:
	# Create a basic node with EntityStats
	var parent := Node3D.new()
	add_child_autofree(parent)

	var stats := EntityStats.new()
	stats.health = 10.0
	stats.max_health = 10.0
	parent.add_child(stats)

	await get_tree().process_frame

	assert_eq(stats.health, 10.0, "Initial health should match configured value")
	assert_eq(stats.max_health, 10.0, "Max health should match configured value")


func test_entity_stats_takes_damage() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)

	var stats := EntityStats.new()
	stats.health = 10.0
	stats.max_health = 10.0
	parent.add_child(stats)

	await get_tree().process_frame

	stats.get_hit(3.0)

	assert_eq(stats.health, 7.0, "Health should decrease by damage amount")


func test_entity_stats_emits_got_hit_signal() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)

	var stats := EntityStats.new()
	stats.health = 10.0
	stats.max_health = 10.0
	parent.add_child(stats)

	await get_tree().process_frame

	watch_signals(stats)
	stats.get_hit(2.0)

	assert_signal_emitted(stats, "got_hit")


func test_entity_stats_emits_out_of_health_at_zero() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)

	var stats := EntityStats.new()
	stats.health = 5.0
	stats.max_health = 10.0
	parent.add_child(stats)

	await get_tree().process_frame

	watch_signals(stats)
	stats.get_hit(5.0)

	assert_signal_emitted(stats, "out_of_health")
	assert_eq(stats.health, 0.0, "Health should be exactly zero")


func test_entity_stats_health_does_not_go_negative() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)

	var stats := EntityStats.new()
	stats.health = 5.0
	stats.max_health = 10.0
	parent.add_child(stats)

	await get_tree().process_frame

	stats.get_hit(10.0)  # More damage than health

	assert_eq(stats.health, 0.0, "Health should clamp to zero, not go negative")


func test_entity_stats_ignores_damage_when_disabled() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)

	var stats := EntityStats.new()
	stats.health = 10.0
	stats.max_health = 10.0
	stats._can_be_hit = false
	parent.add_child(stats)

	await get_tree().process_frame

	stats.get_hit(5.0)

	assert_eq(stats.health, 10.0, "Health should not change when can_be_hit is false")
