extends "res://test/gut_test_base.gd"
## Unit tests for enemy activation based on checkpoint state (task-005)
## Validates that enemies with checkpoint_id start IDLE and activate only when triggered


func test_enemy_base_has_checkpoint_id_property() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	assert_not_null(enemy, "EnemyBase scene should exist and load")
	assert_true("checkpoint_id" in enemy, "EnemyBase should have checkpoint_id property")


func test_enemy_without_checkpoint_id_is_empty_string() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	assert_eq(enemy.checkpoint_id, "", "Default checkpoint_id should be empty string")


func test_enemy_with_checkpoint_id_starts_idle() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	# Set checkpoint_id before adding to tree
	enemy.checkpoint_id = "checkpoint_1"
	await get_tree().process_frame

	assert_eq(enemy.state, enemy.State.IDLE, "Enemy with checkpoint_id should remain IDLE")


func test_enemy_activate_transitions_from_idle_to_active() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	enemy.checkpoint_id = "checkpoint_1"
	await get_tree().process_frame

	assert_eq(enemy.state, enemy.State.IDLE, "Should start in IDLE state")

	enemy.activate()
	await get_tree().process_frame

	assert_eq(enemy.state, enemy.State.ACTIVE, "Should transition to ACTIVE after activate()")


func test_enemy_has_checkpoint_returns_true_when_set() -> void:
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	assert_false(enemy.has_checkpoint(), "Should return false when checkpoint_id is empty")

	enemy.checkpoint_id = "test_checkpoint"

	assert_true(enemy.has_checkpoint(), "Should return true when checkpoint_id is set")


func test_checkpoint_zone_activates_linked_enemies() -> void:
	# Create checkpoint zone
	var checkpoint = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not checkpoint:
		pending("CheckpointZone not yet implemented")
		return

	checkpoint.checkpoint_id = "test_checkpoint"

	# Create enemy with matching checkpoint_id
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	enemy.checkpoint_id = "test_checkpoint"
	await get_tree().process_frame

	# Link enemy to checkpoint
	checkpoint.link_enemies([enemy])

	assert_eq(enemy.state, enemy.State.IDLE, "Enemy should be IDLE before checkpoint triggered")

	# Trigger checkpoint activation
	checkpoint.activate_enemies()
	await get_tree().process_frame

	assert_eq(enemy.state, enemy.State.ACTIVE, "Enemy should be ACTIVE after checkpoint triggered")


func test_checkpoint_entered_activates_linked_enemies() -> void:
	# Create checkpoint zone
	var checkpoint = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not checkpoint:
		pending("CheckpointZone not yet implemented")
		return

	checkpoint.checkpoint_id = "test_checkpoint"

	# Create enemy with matching checkpoint_id
	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	if not enemy:
		pending("EnemyBase not yet implemented")
		return

	enemy.checkpoint_id = "test_checkpoint"
	await get_tree().process_frame

	# Link enemy to checkpoint
	checkpoint.link_enemies([enemy])

	assert_eq(enemy.state, enemy.State.IDLE, "Enemy should be IDLE before body enters")

	# Simulate body entering checkpoint (triggers _on_body_entered)
	# We call the internal method directly since we don't have a PathFollow3D body
	checkpoint._on_body_entered(null)
	await get_tree().process_frame

	assert_eq(enemy.state, enemy.State.ACTIVE, "Enemy should be ACTIVE after checkpoint_entered")


func test_enemy_spawner_sets_checkpoint_id_on_spawned_enemies() -> void:
	# Create spawner
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		pending("EnemySpawner not yet implemented")
		return

	spawner.checkpoint_id = "spawner_checkpoint"

	# Add a spawn position
	var marker = Marker3D.new()
	spawner.add_child(marker)
	marker.position = Vector3(0, 0, 5)

	# Load enemy scene
	var enemy_scene = load("res://assets/enemies/enemy_base.tscn")
	var scenes: Array[PackedScene] = [enemy_scene]
	spawner.enemy_scenes = scenes

	# Re-collect markers since we added one
	spawner.spawn_positions.clear()
	for child in spawner.get_children():
		if child is Marker3D:
			spawner.spawn_positions.append(child)

	# Spawn wave
	var enemies = await spawner.spawn_wave()
	await get_tree().process_frame

	assert_eq(enemies.size(), 1, "Should spawn one enemy")
	assert_eq(enemies[0].checkpoint_id, "spawner_checkpoint", "Spawned enemy should have spawner's checkpoint_id")
	assert_eq(enemies[0].state, enemies[0].State.IDLE, "Spawned enemy with checkpoint_id should be IDLE")


func test_spawned_enemy_stays_idle_until_checkpoint_activates() -> void:
	# Create spawner with checkpoint_id
	var spawner = spawn_scene("res://assets/level/enemy_spawner.tscn")
	if not spawner:
		pending("EnemySpawner not yet implemented")
		return

	spawner.checkpoint_id = "wave_checkpoint"

	# Add spawn position
	var marker = Marker3D.new()
	spawner.add_child(marker)
	marker.position = Vector3(0, 0, 5)

	# Load enemy scene and set up spawner
	var enemy_scene = load("res://assets/enemies/enemy_base.tscn")
	var scenes: Array[PackedScene] = [enemy_scene]
	spawner.enemy_scenes = scenes
	spawner.spawn_positions.clear()
	for child in spawner.get_children():
		if child is Marker3D:
			spawner.spawn_positions.append(child)

	# Create checkpoint zone
	var checkpoint = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	checkpoint.checkpoint_id = "wave_checkpoint"

	# Spawn enemies
	var enemies = await spawner.spawn_wave()
	await get_tree().process_frame

	# Link spawned enemies to checkpoint
	checkpoint.link_enemies(enemies)

	# Verify enemy is IDLE
	assert_eq(enemies[0].state, enemies[0].State.IDLE, "Enemy should be IDLE before checkpoint")

	# Wait several frames - enemy should still be IDLE (not distance-activated)
	await wait_frames(10)
	assert_eq(enemies[0].state, enemies[0].State.IDLE, "Enemy should remain IDLE without checkpoint trigger")

	# Trigger checkpoint
	checkpoint._on_body_entered(null)
	await get_tree().process_frame

	# Now enemy should be ACTIVE
	assert_eq(enemies[0].state, enemies[0].State.ACTIVE, "Enemy should be ACTIVE after checkpoint triggered")


func test_multiple_enemies_activate_on_single_checkpoint_trigger() -> void:
	# Create checkpoint
	var checkpoint = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not checkpoint:
		pending("CheckpointZone not yet implemented")
		return

	checkpoint.checkpoint_id = "multi_enemy_checkpoint"

	# Create multiple enemies
	var enemies: Array = []
	for i in 3:
		var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
		enemy.checkpoint_id = "multi_enemy_checkpoint"
		enemies.append(enemy)

	await get_tree().process_frame

	# Link all enemies to checkpoint
	checkpoint.link_enemies(enemies)

	# Verify all are IDLE
	for enemy in enemies:
		assert_eq(enemy.state, enemy.State.IDLE, "All enemies should be IDLE before trigger")

	# Trigger checkpoint
	checkpoint._on_body_entered(null)
	await get_tree().process_frame

	# Verify all are ACTIVE
	for enemy in enemies:
		assert_eq(enemy.state, enemy.State.ACTIVE, "All enemies should be ACTIVE after trigger")


func test_enemy_emits_activated_signal_when_checkpoint_triggers() -> void:
	var checkpoint = spawn_scene("res://assets/level/checkpoint_zone.tscn")
	if not checkpoint:
		pending("CheckpointZone not yet implemented")
		return

	checkpoint.checkpoint_id = "signal_test"

	var enemy = spawn_scene("res://assets/enemies/enemy_base.tscn")
	enemy.checkpoint_id = "signal_test"

	await get_tree().process_frame

	checkpoint.link_enemies([enemy])

	# Watch for signal
	watch_signals(enemy)

	# Trigger checkpoint
	checkpoint._on_body_entered(null)
	await get_tree().process_frame

	assert_signal_emitted(enemy, "enemy_activated")
