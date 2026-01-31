extends GutTest
## Base test class with common helpers for Level 2 component testing
## Tests should extend "res://test/gut_test_base.gd" to use these helpers

var _spawned_nodes: Array[Node] = []


func after_each() -> void:
	# Clean up any nodes spawned during tests
	for node in _spawned_nodes:
		if is_instance_valid(node):
			# Clear meshes to prevent headless renderer errors
			_clear_meshes_recursive(node)
			node.queue_free()
	_spawned_nodes.clear()
	# Allow cleanup to process
	await get_tree().process_frame
	# Handle any remaining Godot headless renderer errors
	_handle_headless_errors()


## Spawn a scene and track it for cleanup
func spawn_scene(scene_path: String) -> Node:
	var scene: PackedScene = load(scene_path)
	if not scene:
		fail_test("Failed to load scene: %s" % scene_path)
		return null
	var instance: Node = scene.instantiate()
	add_child_autofree(instance)
	_spawned_nodes.append(instance)
	return instance


## Spawn an enemy and register it with EntityManager
func spawn_enemy(scene_path: String) -> Node3D:
	var enemy: Node3D = spawn_scene(scene_path) as Node3D
	if enemy:
		# Wait for EntityStats to register
		await get_tree().process_frame
	return enemy


## Simulate damage to an entity via EntityManager
func simulate_damage(entity: Node3D, amount: float) -> void:
	EntityManager.hit_entity(entity, amount)
	await get_tree().process_frame


## Wait for a specified number of physics frames
## Note: GUT 9.5+ has built-in wait_frames and wait_physics_frames methods.
## Use the parent class versions instead of custom implementations.


## Assert a signal was emitted within timeout
func assert_signal_emitted_with_timeout(
	obj: Object,
	signal_name: String,
	timeout_sec: float = 1.0
) -> bool:
	var emitted := false
	var callback := func(): emitted = true
	obj.connect(signal_name, callback, CONNECT_ONE_SHOT)

	var elapsed := 0.0
	while not emitted and elapsed < timeout_sec:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05

	if not emitted:
		obj.disconnect(signal_name, callback)
		fail_test("Signal '%s' not emitted within %ss" % [signal_name, timeout_sec])
	return emitted


## Create a mock player node at a position
func create_mock_player(position: Vector3 = Vector3.ZERO) -> Node3D:
	var player := Node3D.new()
	player.add_to_group("Player")
	add_child_autofree(player)
	player.global_position = position
	_spawned_nodes.append(player)
	return player


## Get distance between two nodes
func get_distance(a: Node3D, b: Node3D) -> float:
	return a.global_position.distance_to(b.global_position)


## Safely destroy an enemy without triggering visual effects
## Use this instead of queue_free() for enemies in tests
func destroy_enemy_safely(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	# Disconnect death handler to prevent _play_death_effect
	var stats = enemy.find_child("EntityStats", true, false)
	if stats and stats.has_signal("out_of_health"):
		if stats.out_of_health.is_connected(enemy._on_entity_stats_out_of_health):
			stats.out_of_health.disconnect(enemy._on_entity_stats_out_of_health)
	# Clear all meshes to prevent material access errors in headless mode
	_clear_meshes_recursive(enemy)
	enemy.queue_free()


## Recursively clear mesh instances to prevent headless renderer errors
func _clear_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		node.visible = false
		node.mesh = null
	for child in node.get_children():
		_clear_meshes_recursive(child)


## Handle Godot headless renderer errors (engine bugs, not our code)
## Call this after operations that may trigger material/shader errors in headless mode
func _handle_headless_errors() -> void:
	var errors = get_errors()
	for err in errors:
		# Godot dummy renderer null material error
		if err.contains_text("material") or err.contains_text("Parameter") and err.contains_text("null"):
			err.handled = true
