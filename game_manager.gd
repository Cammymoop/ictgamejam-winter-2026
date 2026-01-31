extends Node
class_name GameManager
## Manages level loading, win/lose conditions, and game state.
##
## Supports loading different levels (world_scene or level2) via:
## - Export variable level_scene_path
## - Command-line argument: --level=path/to/level.tscn
## - Autodetects final checkpoint for win condition

signal level_won
signal level_lost
signal level_loaded(level_name: String)

## Path to the level scene to load (not used for dynamic loading, but can be checked)
@export var level_scene_path: String = "res://assets/world_scene.tscn"

## Available level scenes for selection
@export var available_levels: Array[String] = [
	"res://assets/world_scene.tscn",
	"res://assets/levels/level2.tscn"
]

## Final checkpoint ID that triggers win condition
## For level2, this is "checkpoint_4"
@export var final_checkpoint_id: String = "checkpoint_4"

## Reference to the loaded level node
var current_level: Node3D = null

## Reference to the level path (for checkpoint tracking)
var level_path: LevelPath = null

## Win and lose screen references (set via node paths or found at runtime)
var win_screen: Control = null
var lose_screen: Control = null

## Track game state
var game_over: bool = false

func _ready() -> void:
	# Check for command-line level override
	_check_command_line_args()

	# Find win/lose screens in the scene tree
	_find_ui_screens()

	# Connect to level path checkpoint signals (deferred to allow scene setup)
	call_deferred("_connect_to_level_path")


## Check command-line arguments for level selection
## Usage: godot -- --level=res://assets/levels/level2.tscn
## Or: godot -- --level2 (shorthand for level2)
func _check_command_line_args() -> void:
	var args := OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--level="):
			var level_arg := arg.substr(8)  # Remove "--level="
			if level_arg == "2" or level_arg == "level2":
				level_scene_path = "res://assets/levels/level2.tscn"
			elif level_arg == "1" or level_arg == "level1" or level_arg == "world":
				level_scene_path = "res://assets/world_scene.tscn"
			elif ResourceLoader.exists(level_arg):
				level_scene_path = level_arg
			else:
				push_warning("GameManager: Invalid level path '%s', using default" % level_arg)
		elif arg == "--level2":
			level_scene_path = "res://assets/levels/level2.tscn"


## Find win and lose screen nodes in the scene tree
func _find_ui_screens() -> void:
	# Defer to allow scene tree to be set up
	await get_tree().process_frame

	# Look for win/lose screens as siblings or children
	win_screen = _find_node_of_type("WinScreen") as Control
	lose_screen = _find_node_of_type("LoseScreen") as Control


## Helper to find a node by name in the scene tree
func _find_node_of_type(node_name: String) -> Node:
	# Try common paths first
	var root := get_tree().current_scene
	if root:
		var found := root.find_child(node_name, true, false)
		if found:
			return found
	return null


## Connect to the LevelPath in the current scene for checkpoint tracking
func _connect_to_level_path() -> void:
	# Wait a frame for scene tree to be fully set up
	await get_tree().process_frame

	# Find LevelPath in the scene
	level_path = _find_level_path()
	if not level_path:
		print_debug("GameManager: No LevelPath found - win condition unavailable")
		return

	# Connect to checkpoint completion signals if not already connected
	if not level_path.checkpoint_completed.is_connected(_on_checkpoint_completed):
		level_path.checkpoint_completed.connect(_on_checkpoint_completed)
		print_debug("GameManager: Connected to LevelPath checkpoint signals")

	# Connect to path completion for levels without checkpoints (like world_scene)
	if level_path.has_signal("path_completed"):
		if not level_path.path_completed.is_connected(_on_path_completed):
			level_path.path_completed.connect(_on_path_completed)
			print_debug("GameManager: Connected to LevelPath path_completed signal")


## Find LevelPath anywhere in the scene tree
func _find_level_path() -> LevelPath:
	var root := get_tree().current_scene
	if root:
		var found := root.find_child("LevelPath", true, false)
		if found is LevelPath:
			return found
	return null


## Load a level by path and add it to the scene (for dynamic level loading)
func load_level(path: String) -> void:
	# Unload current level if exists
	if current_level:
		current_level.queue_free()
		current_level = null
		level_path = null

	# Load new level
	var level_scene := load(path) as PackedScene
	if not level_scene:
		push_error("GameManager: Failed to load level '%s'" % path)
		return

	current_level = level_scene.instantiate() as Node3D
	if not current_level:
		push_error("GameManager: Level scene is not a Node3D")
		return

	# Find the World node to add level as child, or add to self
	var world_parent := get_node_or_null("../World")
	if world_parent:
		# Replace existing World content
		world_parent.add_child(current_level)
	else:
		# Add as sibling
		get_parent().add_child(current_level)
		current_level.name = "World"

	# Find and connect to LevelPath
	_setup_level_path()

	level_loaded.emit(path.get_file().get_basename())


## Set up level path and checkpoint connections (for dynamically loaded levels)
func _setup_level_path() -> void:
	if not current_level:
		return

	# Find LevelPath in the level
	level_path = current_level.find_child("LevelPath", true, false) as LevelPath
	if not level_path:
		# Level might not have checkpoints (like world_scene)
		return

	# Connect to checkpoint completion signals
	if not level_path.checkpoint_completed.is_connected(_on_checkpoint_completed):
		level_path.checkpoint_completed.connect(_on_checkpoint_completed)


## Called when a checkpoint is completed
func _on_checkpoint_completed(checkpoint_id: String) -> void:
	print_debug("GameManager: Checkpoint completed: %s (final: %s)" % [checkpoint_id, final_checkpoint_id])
	if checkpoint_id == final_checkpoint_id:
		trigger_win()


## Called when the path is completed (for levels without checkpoints)
func _on_path_completed() -> void:
	print_debug("GameManager: Path completed")
	# Only trigger win if there are no checkpoints (world_scene style)
	# For checkpoint-based levels, win is triggered by final checkpoint
	if level_path and level_path.checkpoint_zones.size() == 0:
		trigger_win()


## Trigger win condition
func trigger_win() -> void:
	if game_over:
		return

	game_over = true
	level_won.emit()

	if win_screen and win_screen.has_method("show_screen"):
		win_screen.show_screen()
	elif win_screen:
		win_screen.show()

	# Pause game
	get_tree().paused = true


## Trigger lose condition
func trigger_lose() -> void:
	if game_over:
		return

	game_over = true
	level_lost.emit()

	if lose_screen and lose_screen.has_method("show_screen"):
		lose_screen.show_screen()
	elif lose_screen:
		lose_screen.show()

	# Pause game after a short delay to show death effect
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = true


## Reset game state and reload current level
func reset_level() -> void:
	game_over = false
	get_tree().paused = false
	get_tree().reload_current_scene()


## Switch to a different level
func change_level(level_index: int) -> void:
	if level_index < 0 or level_index >= available_levels.size():
		push_warning("GameManager: Invalid level index %d" % level_index)
		return

	level_scene_path = available_levels[level_index]
	reset_level()


## Get current level index in available_levels array
func get_current_level_index() -> int:
	return available_levels.find(level_scene_path)
