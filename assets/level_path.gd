extends Node3D
class_name LevelPath

signal checkpoint_activated(checkpoint_id: String)
signal checkpoint_completed(checkpoint_id: String)
signal path_completed

@export var remote_transform: RemoteTransform3D
@onready var path_3d: Path3D = $Path3D
@onready var path_follow: PathFollow3D = path_3d.get_node("PathFollow3D")

@onready var look_here: Node3D = $LookHere

@export var base_speed: float = 4

## Duration for velocity to lerp to zero when stopping at checkpoint
@export var stop_lerp_duration: float = 0.3

var delay_time: float = 1.4
var total_length: float = 0

var is_moving: bool = false

## Array of registered checkpoint zones
var checkpoint_zones: Array = []

## Currently active checkpoint (null if not paused at checkpoint)
var current_checkpoint: CheckpointZone = null

## Internal: tracks velocity lerp progress when stopping
var _stopping: bool = false
var _stop_timer: float = 0.0
var _current_speed: float = 0.0

## Cached whoosh sound for camera resume
var _whoosh_sound: AudioStreamWAV = null

func _ready() -> void:
	_setup_audio()


func start() -> void:
	var delay_timer = Timer.new()
	delay_timer.wait_time = delay_time
	delay_timer.one_shot = true
	delay_timer.autostart = true
	delay_timer.timeout.connect(start_moving)
	add_child(delay_timer)
	delay_timer.start()

	total_length = path_3d.curve.get_baked_length()

func start_moving() -> void:
	print_debug("Starting movement")
	path_follow.progress = 0
	is_moving = true
	_current_speed = base_speed
	_stopping = false

func _process(delta: float) -> void:
	# Handle smooth stopping at checkpoint
	if _stopping:
		_stop_timer += delta
		var t: float = clampf(_stop_timer / stop_lerp_duration, 0.0, 1.0)
		_current_speed = lerpf(base_speed, 0.0, t)
		if t >= 1.0:
			_stopping = false
			is_moving = false
			_current_speed = 0.0
			Global.player_velocity = Vector3.ZERO
			return

	if not is_moving:
		return

	var old_pos: Vector3 = path_follow.global_position

	path_follow.progress += delta * _current_speed
	if path_follow.progress_ratio >= 1:
		is_moving = false
		path_completed.emit()

	if old_pos.distance_squared_to(path_follow.global_position) > 0.01:
		Global.player_velocity = (path_follow.global_position - old_pos) / delta
	else:
		Global.player_velocity = Vector3.ZERO


## Register a checkpoint zone to be tracked by this LevelPath.
## Connects the zone's checkpoint_entered and checkpoint_cleared signals.
func register_checkpoint(zone: CheckpointZone) -> void:
	if zone in checkpoint_zones:
		return
	checkpoint_zones.append(zone)
	zone.checkpoint_entered.connect(_on_checkpoint_entered.bind(zone))
	zone.checkpoint_cleared.connect(resume_from_checkpoint)


## Called when a checkpoint zone is entered.
## Initiates smooth camera stop and pauses movement.
func _on_checkpoint_entered(zone: CheckpointZone) -> void:
	pause_at_checkpoint(zone)


## Pause movement at the specified checkpoint zone.
## Camera will smoothly lerp velocity to zero over stop_lerp_duration.
func pause_at_checkpoint(zone: CheckpointZone) -> void:
	if current_checkpoint != null:
		return  # Already paused at a checkpoint

	current_checkpoint = zone
	_stopping = true
	_stop_timer = 0.0

	# Optionally update look_here to checkpoint center
	if look_here and zone:
		look_here.global_position = zone.global_position

	checkpoint_activated.emit(zone.checkpoint_id)


## Resume movement after checkpoint is cleared.
## Restores full speed and clears current checkpoint reference.
func resume_from_checkpoint() -> void:
	if current_checkpoint == null:
		return

	var checkpoint_id: String = current_checkpoint.checkpoint_id
	current_checkpoint = null
	_stopping = false
	_current_speed = base_speed
	is_moving = true

	# Play whoosh sound as camera resumes movement
	_play_whoosh()

	checkpoint_completed.emit(checkpoint_id)


## Set up audio and cache sounds
func _setup_audio() -> void:
	if SFXManager:
		_whoosh_sound = SFXManager.create_whoosh_sound()


## Play subtle whoosh when camera resumes movement
func _play_whoosh() -> void:
	if _whoosh_sound and SFXManager:
		SFXManager.play_sfx(_whoosh_sound, -6.0, 1.0)  # Quieter for subtlety
