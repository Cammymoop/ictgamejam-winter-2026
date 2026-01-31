class_name EnemySpawner
extends Node3D
## Spawns waves of enemies at designated Marker3D positions
## Connect checkpoint_entered signal to spawn_wave() for automatic triggering

signal wave_spawned(enemies: Array[Node3D])
signal wave_cleared

@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_delay: float = 0.2
## Optional checkpoint ID to assign to spawned enemies
@export var checkpoint_id: String = ""

var spawn_positions: Array[Marker3D] = []
var spawned_enemies: Array[Node3D] = []
var remaining_enemies: int = 0


func _ready() -> void:
	# Collect child Marker3D nodes as spawn positions
	for child in get_children():
		if child is Marker3D:
			spawn_positions.append(child)


func spawn_wave() -> Array[Node3D]:
	spawned_enemies.clear()
	remaining_enemies = 0

	var count = mini(enemy_scenes.size(), spawn_positions.size())
	for i in count:
		if spawn_delay > 0 and i > 0:
			await get_tree().create_timer(spawn_delay).timeout

		var enemy = enemy_scenes[i].instantiate()
		# Set checkpoint_id before adding to tree so _ready() sees it
		if not checkpoint_id.is_empty() and "checkpoint_id" in enemy:
			enemy.checkpoint_id = checkpoint_id
		get_parent().add_child(enemy)
		enemy.global_position = spawn_positions[i].global_position
		spawned_enemies.append(enemy)

		# Connect to death signal
		_connect_enemy_death(enemy)
		remaining_enemies += 1

	wave_spawned.emit(spawned_enemies)
	return spawned_enemies


func _connect_enemy_death(enemy: Node3D) -> void:
	var stats = enemy.find_child("EntityStats", true, false)
	if stats:
		stats.out_of_health.connect(_on_enemy_died.bind(enemy))
	elif enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))


func _on_enemy_died(_enemy: Node3D) -> void:
	remaining_enemies -= 1
	if remaining_enemies <= 0:
		wave_cleared.emit()
