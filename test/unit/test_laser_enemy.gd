extends "res://test/gut_test_base.gd"
## TDD tests for LaserEnemy - validates charged beam attack behavior
## These tests define the expected behavior for task-008


# =============================================================================
# Scene Loading Tests
# =============================================================================

func test_laser_enemy_scene_exists() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	assert_not_null(enemy, "LaserEnemy scene should exist")


func test_laser_enemy_extends_enemy_base() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	# Check it has EnemyBase methods
	assert_true(enemy.has_method("activate"), "Should have activate() from EnemyBase")
	assert_true(enemy.has_method("target_player"), "Should have target_player() from EnemyBase")
	assert_true(enemy.has_method("deactivate"), "Should have deactivate() from EnemyBase")


# =============================================================================
# Laser Property Tests
# =============================================================================

func test_laser_enemy_has_laser_properties() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	assert_true("laser_damage" in enemy, "Should have laser_damage property")
	assert_true("charge_time" in enemy, "Should have charge_time property")
	assert_true("fire_duration" in enemy, "Should have fire_duration property")
	assert_true("cooldown_time" in enemy, "Should have cooldown_time property")


func test_laser_enemy_has_correct_default_values() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	assert_eq(enemy.laser_damage, 1.5, "laser_damage should be 1.5")
	assert_eq(enemy.charge_time, 1.8, "charge_time should be 1.8s")
	assert_eq(enemy.fire_duration, 0.25, "fire_duration should be 0.25s")
	assert_eq(enemy.cooldown_time, 2.5, "cooldown_time should be 2.5s")


# =============================================================================
# State Machine Tests
# =============================================================================

func test_laser_enemy_has_laser_state() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	assert_true("laser_state" in enemy, "Should have laser_state property")
	assert_true("LaserState" in enemy, "Should have LaserState enum")


func test_laser_enemy_starts_in_idle_laser_state() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	assert_eq(enemy.laser_state, enemy.LaserState.IDLE, "Should start in IDLE laser state")


func test_laser_enemy_transitions_to_charging_when_active() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()
	await wait_physics_frames(5)

	assert_eq(enemy.laser_state, enemy.LaserState.CHARGING, "Should transition to CHARGING when active")


func test_laser_enemy_transitions_to_firing_after_charge() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()
	# Wait for charge time (1.8s) plus some buffer
	await get_tree().create_timer(2.0).timeout

	assert_eq(enemy.laser_state, enemy.LaserState.FIRING, "Should transition to FIRING after charge")


func test_laser_enemy_transitions_to_cooldown_after_firing() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	enemy.activate()
	# Wait for charge time (1.8s) + fire duration (0.25s) plus buffer
	await get_tree().create_timer(2.2).timeout

	assert_eq(enemy.laser_state, enemy.LaserState.COOLDOWN, "Should transition to COOLDOWN after firing")


# =============================================================================
# Laser Hit Detection Tests
# =============================================================================

func test_laser_enemy_has_raycast() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var raycast = enemy.find_child("LaserRaycast", true, false)
	assert_not_null(raycast, "Should have LaserRaycast child")
	assert_true(raycast is RayCast3D, "LaserRaycast should be RayCast3D")


func test_laser_enemy_has_beam_mesh() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var beam = enemy.find_child("BeamMesh", true, false)
	assert_not_null(beam, "Should have BeamMesh child")
	assert_true(beam is MeshInstance3D, "BeamMesh should be MeshInstance3D")


func test_laser_hits_player_in_line_of_sight() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	# Create player with EntityStats for damage detection
	var player := CharacterBody3D.new()
	player.add_to_group("Player")
	# Set collision layer to match actual player (layer 2) which raycast mask 3 detects
	player.collision_layer = 2
	var player_stats := EntityStats.new()
	player_stats.health = 10.0
	player_stats.max_health = 10.0
	player.add_child(player_stats)
	# Add collision shape for raycast detection
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision.shape = shape
	player.add_child(collision)
	add_child_autofree(player)

	await get_tree().process_frame

	# Position player directly in front of enemy at raycast height (y=2.5)
	# The laser raycast originates at y=2.5, so player must be at same height
	player.global_position = Vector3(0, 2.5, -10)
	enemy.global_position = Vector3.ZERO
	enemy.look_at(player.global_position)

	enemy.activate()
	# Wait for full attack cycle: charge (1.8s) + fire (0.25s) plus buffer
	await get_tree().create_timer(2.2).timeout

	assert_lt(player_stats.health, 10.0, "Player should take damage from laser hit")


func test_laser_emits_fired_signal() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(10, 0, 0))
	enemy.global_position = Vector3.ZERO

	watch_signals(enemy)

	enemy.activate()
	# Wait for charge time (1.8s) + firing (0.25s) plus buffer
	await get_tree().create_timer(2.2).timeout

	assert_signal_emitted(enemy, "laser_fired")


# =============================================================================
# Behavior Tests
# =============================================================================

func test_laser_enemy_does_not_move_during_charge() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var player := create_mock_player(Vector3(20, 0, 0))
	enemy.global_position = Vector3.ZERO
	var initial_position: Vector3 = enemy.global_position

	enemy.activate()
	await wait_physics_frames(30)

	assert_eq(enemy.global_position, initial_position, "Enemy should not move during charge/fire sequence")


func test_laser_enemy_is_taller() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	var mesh := enemy.find_child("MeshInstance3D", true, false) as MeshInstance3D
	assert_not_null(mesh, "Should have visible mesh")

	if mesh and mesh.mesh:
		var aabb := mesh.mesh.get_aabb()
		assert_gte(aabb.size.y, 2.5, "LaserEnemy should be taller than base enemy")


func test_laser_deals_correct_damage() -> void:
	var enemy = spawn_scene("res://assets/enemies/laser_enemy.tscn")
	if not enemy:
		pending("LaserEnemy not yet implemented")
		return

	assert_eq(enemy.laser_damage, 1.5, "Laser should deal 1.5 damage per hit")
