extends GutTest
## Base test class with common helpers for Level 2 component testing
## Tests should extend "res://test/gut_test_base.gd" to use these helpers

var _spawned_nodes: Array[Node] = []


func after_each() -> void:
	# Clean up any nodes spawned during tests
	for node in _spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_nodes.clear()


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
