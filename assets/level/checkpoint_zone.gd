class_name CheckpointZone
extends Area3D
## A checkpoint zone that triggers camera pause and tracks enemy deaths.
##
## Emits checkpoint_entered when a body (typically PathFollow3D) enters the zone.
## Emits checkpoint_cleared when all linked enemies have been defeated.

signal checkpoint_entered
signal checkpoint_cleared

## Unique identifier for this checkpoint
@export var checkpoint_id: String = ""

## Array of NodePaths to enemies that must be defeated to clear this checkpoint
@export var required_enemies: Array[NodePath] = []

## Trigger radius for the collision shape
@export var trigger_radius: float = 5.0

## Number of enemies remaining to defeat
var remaining_enemies: int = 0

## Array of linked enemy nodes for activation
var _linked_enemies: Array[Node3D] = []

## Cached checkpoint activation chime sound
var _chime_sound: AudioStreamWAV = null
## Cached checkpoint cleared fanfare sound
var _fanfare_sound: AudioStreamWAV = null

## Reference to the debug visual marker
@onready var _debug_marker: MeshInstance3D = $DebugMarker if has_node("DebugMarker") else null


func _ready() -> void:
	# Hide debug marker at runtime
	if _debug_marker:
		_debug_marker.visible = false

	# Connect body_entered signal to emit checkpoint_entered
	body_entered.connect(_on_body_entered)

	# Setup audio
	_setup_audio()

	# Auto-link enemies from required_enemies NodePaths if set
	if required_enemies.size() > 0:
		# Wait a frame for the scene tree to be ready
		await get_tree().process_frame
		_link_enemies_from_paths()

	# Auto-register with LevelPath if available
	await get_tree().process_frame
	_auto_register_with_level_path()


## Find and register with the LevelPath in the scene
func _auto_register_with_level_path() -> void:
	# Look for LevelPath in common locations
	var found_level_path: LevelPath = null

	# Try to find LevelPath as a sibling or in parent hierarchy
	var parent = get_parent()
	while parent != null:
		for child in parent.get_children():
			if child is LevelPath:
				found_level_path = child
				break
		if found_level_path:
			break
		parent = parent.get_parent()

	# Also try the common path structure for world_scene
	if not found_level_path:
		found_level_path = get_node_or_null("/root/Game/World/LevelPath") as LevelPath

	# Try Level2 path structure (World node contains Level2 scene)
	if not found_level_path:
		var world = get_node_or_null("/root/Game/World")
		if world:
			found_level_path = world.find_child("LevelPath", true, false) as LevelPath

	# Last resort: search entire scene tree
	if not found_level_path:
		var root = get_tree().current_scene
		if root:
			found_level_path = root.find_child("LevelPath", true, false) as LevelPath

	if found_level_path:
		found_level_path.register_checkpoint(self)


func _on_body_entered(_body: Node3D) -> void:
	_play_chime()
	checkpoint_entered.emit()
	_activate_linked_enemies()


## Link enemies to this checkpoint zone.
## Connects to their EntityStats.out_of_health signals to track deaths.
## Also stores references for activation when checkpoint is triggered.
## Note: This method accumulates enemies, allowing multiple spawners to link to one zone.
func link_enemies(enemies: Array) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Store reference for activation (avoid duplicates)
		if enemy is Node3D and not _linked_enemies.has(enemy):
			_linked_enemies.append(enemy)

		# Find EntityStats child
		var stats: EntityStats = _find_entity_stats(enemy)
		if stats:
			remaining_enemies += 1
			stats.out_of_health.connect(_on_enemy_died.bind(enemy))


## Find EntityStats node in an enemy's children
func _find_entity_stats(node: Node) -> EntityStats:
	for child in node.get_children():
		if child is EntityStats:
			return child
	return null


## Called when a linked enemy dies
func _on_enemy_died(_enemy: Node3D) -> void:
	remaining_enemies -= 1
	if remaining_enemies <= 0:
		remaining_enemies = 0
		_play_fanfare()
		checkpoint_cleared.emit()


## Activate all linked enemies (called when checkpoint is triggered)
func _activate_linked_enemies() -> void:
	for enemy in _linked_enemies:
		if is_instance_valid(enemy) and enemy.has_method("activate"):
			enemy.activate()


## Manually trigger activation of linked enemies (useful for external calls)
func activate_enemies() -> void:
	_activate_linked_enemies()


## Link enemies from the required_enemies NodePath array
func _link_enemies_from_paths() -> void:
	var enemies: Array[Node3D] = []
	for path in required_enemies:
		var node = get_node_or_null(path)
		if node is Node3D:
			enemies.append(node)

	if enemies.size() > 0:
		link_enemies(enemies)


## Set up audio and cache sounds
func _setup_audio() -> void:
	if SFXManager:
		_chime_sound = SFXManager.create_chime_sound()
		_fanfare_sound = SFXManager.create_fanfare_sound()


## Play checkpoint activation chime
func _play_chime() -> void:
	if _chime_sound and SFXManager:
		SFXManager.play_sfx_3d(_chime_sound, global_position, 0.0, 1.0)


## Play checkpoint cleared fanfare
func _play_fanfare() -> void:
	if _fanfare_sound and SFXManager:
		# Use 2D sound for fanfare so it's always clearly audible
		SFXManager.play_sfx(_fanfare_sound, 0.0, 1.0)
