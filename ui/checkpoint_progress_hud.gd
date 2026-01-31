extends Control
class_name CheckpointProgressHUD
## HUD element that displays current checkpoint and enemies remaining.
##
## Shows "Checkpoint X/Y - Enemies: N" format with real-time updates.
## Hidden during camera movement between checkpoints.
## Includes optional mini progress bar for current wave.

## Reference to the LevelPath for checkpoint signals
var level_path: LevelPath = null

## Reference to the current active checkpoint zone
var current_checkpoint: CheckpointZone = null

## Total number of checkpoints in the level
var total_checkpoints: int = 0

## Current checkpoint number (1-indexed)
var current_checkpoint_number: int = 0

## Initial enemy count when checkpoint started (for progress bar)
var initial_enemy_count: int = 0

## Node references (set via unique names in scene)
@onready var checkpoint_label: Label = %CheckpointLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var container: PanelContainer = %Container


func _ready() -> void:
	# Start hidden until a checkpoint is activated
	hide()

	# Connect to level path after scene tree is ready
	call_deferred("_connect_to_level_path")


func _process(_delta: float) -> void:
	# Update enemies remaining in real-time
	if visible and current_checkpoint and is_instance_valid(current_checkpoint):
		_update_enemies_display()


## Find and connect to the LevelPath in the scene
func _connect_to_level_path() -> void:
	# Wait for scene tree to be set up
	await get_tree().process_frame

	level_path = _find_level_path()
	if not level_path:
		push_warning("CheckpointProgressHUD: No LevelPath found")
		return

	# Count total checkpoints
	total_checkpoints = level_path.checkpoint_zones.size()

	# If checkpoints aren't registered yet, wait and check again
	if total_checkpoints == 0:
		await get_tree().create_timer(0.5).timeout
		total_checkpoints = level_path.checkpoint_zones.size()

	# Connect to checkpoint signals
	if not level_path.checkpoint_activated.is_connected(_on_checkpoint_activated):
		level_path.checkpoint_activated.connect(_on_checkpoint_activated)

	if not level_path.checkpoint_completed.is_connected(_on_checkpoint_completed):
		level_path.checkpoint_completed.connect(_on_checkpoint_completed)


## Find LevelPath anywhere in the scene tree
func _find_level_path() -> LevelPath:
	var root := get_tree().current_scene
	if root:
		var found := root.find_child("LevelPath", true, false)
		if found is LevelPath:
			return found
	return null


## Called when a checkpoint is activated (camera pauses)
func _on_checkpoint_activated(checkpoint_id: String) -> void:
	# Find the current checkpoint zone by ID
	current_checkpoint = _find_checkpoint_by_id(checkpoint_id)
	if not current_checkpoint:
		push_warning("CheckpointProgressHUD: Could not find checkpoint '%s'" % checkpoint_id)
		return

	# Determine checkpoint number from ID or zone order
	current_checkpoint_number = _get_checkpoint_number(checkpoint_id)

	# Re-count total checkpoints in case they were registered late
	if level_path:
		total_checkpoints = maxi(total_checkpoints, level_path.checkpoint_zones.size())

	# Wait a moment for enemies to spawn and be linked
	await get_tree().create_timer(0.5).timeout

	# Store initial enemy count for progress bar
	if current_checkpoint and is_instance_valid(current_checkpoint):
		initial_enemy_count = current_checkpoint.remaining_enemies

	# Update display and show
	_update_checkpoint_display()
	_update_enemies_display()
	show()


## Called when a checkpoint is completed (camera resumes)
func _on_checkpoint_completed(_checkpoint_id: String) -> void:
	# Hide the HUD during camera movement
	hide()
	current_checkpoint = null
	initial_enemy_count = 0


## Find a checkpoint zone by its ID
func _find_checkpoint_by_id(checkpoint_id: String) -> CheckpointZone:
	if not level_path:
		return null

	for zone in level_path.checkpoint_zones:
		if zone is CheckpointZone and zone.checkpoint_id == checkpoint_id:
			return zone

	return null


## Get the checkpoint number (1-indexed) from checkpoint_id
func _get_checkpoint_number(checkpoint_id: String) -> int:
	# Try to extract number from ID like "checkpoint_1", "checkpoint_2", etc.
	var parts := checkpoint_id.split("_")
	if parts.size() >= 2:
		var num_str := parts[-1]
		if num_str.is_valid_int():
			return num_str.to_int()

	# Fallback: find index in checkpoint_zones array
	if level_path:
		for i in range(level_path.checkpoint_zones.size()):
			var zone: CheckpointZone = level_path.checkpoint_zones[i]
			if zone.checkpoint_id == checkpoint_id:
				return i + 1

	return 1


## Update the checkpoint number display
func _update_checkpoint_display() -> void:
	if checkpoint_label:
		checkpoint_label.text = "Checkpoint %d/%d" % [current_checkpoint_number, total_checkpoints]


## Update the enemies remaining display and progress bar
func _update_enemies_display() -> void:
	if not current_checkpoint or not is_instance_valid(current_checkpoint):
		return

	var remaining: int = current_checkpoint.remaining_enemies

	if enemies_label:
		enemies_label.text = "Enemies: %d" % remaining

	if progress_bar and initial_enemy_count > 0:
		# Progress bar shows percentage defeated (fills up as enemies die)
		var defeated: int = initial_enemy_count - remaining
		progress_bar.value = float(defeated) / float(initial_enemy_count) * 100.0
	elif progress_bar:
		progress_bar.value = 0.0
