extends "res://test/gut_test_base.gd"
## Unit tests for LevelPath checkpoint pausing functionality
## Validates pause/resume behavior when entering checkpoint zones


func test_level_path_has_checkpoint_signals() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	if not level_path:
		fail_test("Could not load LevelPath scene")
		return

	assert_true(level_path.has_signal("checkpoint_activated"), "Should have checkpoint_activated signal")
	assert_true(level_path.has_signal("checkpoint_completed"), "Should have checkpoint_completed signal")


func test_level_path_has_checkpoint_properties() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	if not level_path:
		fail_test("Could not load LevelPath scene")
		return

	assert_true("checkpoint_zones" in level_path, "Should have checkpoint_zones property")
	assert_true("current_checkpoint" in level_path, "Should have current_checkpoint property")
	assert_true(level_path.checkpoint_zones is Array, "checkpoint_zones should be an Array")
	assert_null(level_path.current_checkpoint, "current_checkpoint should initially be null")


func test_register_checkpoint_adds_to_array() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	assert_eq(level_path.checkpoint_zones.size(), 0, "Should start with no checkpoints")

	level_path.register_checkpoint(zone)

	assert_eq(level_path.checkpoint_zones.size(), 1, "Should have 1 checkpoint after registration")
	assert_true(zone in level_path.checkpoint_zones, "Zone should be in checkpoint_zones array")


func test_register_checkpoint_prevents_duplicates() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	level_path.register_checkpoint(zone)
	level_path.register_checkpoint(zone)  # Try to register again

	assert_eq(level_path.checkpoint_zones.size(), 1, "Should not add duplicate checkpoints")


func test_pause_at_checkpoint_stops_movement() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "test_checkpoint"
	level_path.is_moving = true
	level_path._current_speed = level_path.base_speed

	level_path.pause_at_checkpoint(zone)

	assert_true(level_path._stopping, "Should be in stopping state")
	assert_eq(level_path.current_checkpoint, zone, "current_checkpoint should be set")


func test_pause_at_checkpoint_emits_activated_signal() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "test_checkpoint_1"
	watch_signals(level_path)

	level_path.pause_at_checkpoint(zone)

	assert_signal_emitted_with_parameters(level_path, "checkpoint_activated", ["test_checkpoint_1"])


func test_resume_from_checkpoint_restores_movement() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "test_checkpoint"
	level_path.pause_at_checkpoint(zone)
	level_path.is_moving = false
	level_path._stopping = false
	level_path._current_speed = 0.0

	level_path.resume_from_checkpoint()

	assert_true(level_path.is_moving, "Should be moving after resume")
	assert_eq(level_path._current_speed, level_path.base_speed, "Speed should be restored")
	assert_null(level_path.current_checkpoint, "current_checkpoint should be cleared")


func test_resume_from_checkpoint_emits_completed_signal() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "test_checkpoint_2"
	level_path.pause_at_checkpoint(zone)
	watch_signals(level_path)

	level_path.resume_from_checkpoint()

	assert_signal_emitted_with_parameters(level_path, "checkpoint_completed", ["test_checkpoint_2"])


func test_resume_does_nothing_without_active_checkpoint() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	if not level_path:
		fail_test("Could not load LevelPath scene")
		return

	watch_signals(level_path)
	level_path.is_moving = false

	level_path.resume_from_checkpoint()

	assert_signal_not_emitted(level_path, "checkpoint_completed")
	assert_false(level_path.is_moving, "Should not start moving without active checkpoint")


func test_checkpoint_entered_triggers_pause() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "trigger_test"
	level_path.is_moving = true
	level_path._current_speed = level_path.base_speed
	level_path.register_checkpoint(zone)

	watch_signals(level_path)

	# Simulate body entering the checkpoint zone
	var body := Node3D.new()
	add_child_autofree(body)
	zone.body_entered.emit(body)

	assert_signal_emitted(level_path, "checkpoint_activated")
	assert_eq(level_path.current_checkpoint, zone, "Should be paused at checkpoint")


func test_checkpoint_cleared_triggers_resume() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "clear_test"
	level_path.register_checkpoint(zone)
	level_path.pause_at_checkpoint(zone)
	level_path.is_moving = false
	level_path._stopping = false

	watch_signals(level_path)

	# Simulate checkpoint being cleared
	zone.checkpoint_cleared.emit()

	assert_signal_emitted(level_path, "checkpoint_completed")
	assert_true(level_path.is_moving, "Should resume moving after checkpoint cleared")


func test_smooth_stop_lerps_velocity_over_time() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "lerp_test"
	level_path.stop_lerp_duration = 0.3
	level_path.is_moving = true
	level_path._current_speed = level_path.base_speed

	level_path.pause_at_checkpoint(zone)

	# Simulate partial time passing (half the lerp duration)
	level_path._process(0.15)

	assert_true(level_path._stopping, "Should still be stopping")
	assert_true(level_path._current_speed < level_path.base_speed, "Speed should be decreasing")
	assert_true(level_path._current_speed > 0, "Speed should not be zero yet")


func test_smooth_stop_completes_after_duration() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "complete_stop_test"
	level_path.stop_lerp_duration = 0.3
	level_path.is_moving = true
	level_path._current_speed = level_path.base_speed

	level_path.pause_at_checkpoint(zone)

	# Simulate full lerp duration passing
	level_path._process(0.35)

	assert_false(level_path._stopping, "Should no longer be stopping")
	assert_false(level_path.is_moving, "Should not be moving")
	assert_eq(level_path._current_speed, 0.0, "Speed should be zero")


func test_look_here_updated_to_checkpoint_position() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone:
		fail_test("Could not load required scenes")
		return

	zone.checkpoint_id = "look_test"
	zone.global_position = Vector3(10, 5, 20)

	# Ensure look_here exists
	if level_path.look_here == null:
		pending("LevelPath does not have look_here node")
		return

	level_path.pause_at_checkpoint(zone)

	assert_eq(level_path.look_here.global_position, zone.global_position,
		"look_here should be updated to checkpoint position")


func test_cannot_pause_while_already_paused() -> void:
	var level_path = spawn_scene("res://assets/level_path.tscn")
	var zone1 = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	var zone2 = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not level_path or not zone1 or not zone2:
		fail_test("Could not load required scenes")
		return

	zone1.checkpoint_id = "first"
	zone2.checkpoint_id = "second"

	level_path.pause_at_checkpoint(zone1)
	watch_signals(level_path)

	level_path.pause_at_checkpoint(zone2)

	assert_eq(level_path.current_checkpoint, zone1, "Should still be at first checkpoint")
	assert_signal_not_emitted(level_path, "checkpoint_activated")
