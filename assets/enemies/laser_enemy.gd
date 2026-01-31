class_name LaserEnemy
extends EnemyBase
## Enemy that charges and fires a powerful laser beam at the player.
## Attack sequence: charge (1.8s) -> fire (0.25s) -> cooldown (2.5s)
##
## === BALANCE DOCUMENTATION ===
## Design Goal: Dodgeable with attention - punishes stationary play
## Player Context: 5 HP, speed 10.0, bounds 4x3 units
##
## FINAL BALANCED VALUES:
## - charge_time: 1.8s (increased from 1.5s for clearer telegraph window)
## - fire_duration: 0.25s (reduced from 0.3s - quick punish if you fail to dodge)
## - cooldown_time: 2.5s (increased from 2.0s for breathing room between attacks)
## - laser_damage: 1.5 (reduced from 2.0 - 30% of player HP per hit)
##
## Counterplay: Watch for the growing charge visual and audio whine. Move perpendicular
## to the laser direction during the 1.8s charge. The laser locks direction at fire time.
## With 2.5s cooldown, player has safe windows to focus fire on this enemy.
## =========================

signal laser_fired

enum LaserState { IDLE, CHARGING, FIRING, COOLDOWN }

## Damage dealt per laser hit
@export var laser_damage: float = 1.5
## Time to charge before firing
@export var charge_time: float = 1.8
## Duration the laser fires for
@export var fire_duration: float = 0.25
## Cooldown between attack cycles
@export var cooldown_time: float = 2.5

## Current state of the laser attack sequence
var laser_state: LaserState = LaserState.IDLE
## Timer for current laser state
var state_timer: float = 0.0
## Direction the laser is targeting
var target_direction: Vector3 = Vector3.FORWARD
## Whether damage has been applied this fire cycle
var _damage_applied: bool = false

## Audio: charge sound player (attached, follows enemy)
var _charge_player: AudioStreamPlayer3D = null
## Cached charge whine sound
var _charge_sound: AudioStreamWAV = null
## Cached zap sound
var _zap_sound: AudioStreamWAV = null

@onready var raycast: RayCast3D = $LaserRaycast
@onready var beam_mesh: MeshInstance3D = $BeamMesh
@onready var charge_mesh: MeshInstance3D = $ChargeMesh


func _ready() -> void:
	super._ready()
	_hide_beam()
	_hide_charge()
	_setup_audio()


func _physics_process(delta: float) -> void:
	if state != State.ACTIVE:
		return

	match laser_state:
		LaserState.IDLE:
			_process_idle()
		LaserState.CHARGING:
			_process_charging(delta)
		LaserState.FIRING:
			_process_firing(delta)
		LaserState.COOLDOWN:
			_process_cooldown(delta)


func _process_idle() -> void:
	_look_at_player()
	_start_charge()


func _process_charging(delta: float) -> void:
	state_timer -= delta
	_update_charge_visual()
	_look_at_player()

	if state_timer <= 0:
		_fire_laser()


func _process_firing(delta: float) -> void:
	state_timer -= delta
	_check_laser_hit()

	if state_timer <= 0:
		_end_fire()


func _process_cooldown(delta: float) -> void:
	state_timer -= delta

	if state_timer <= 0:
		laser_state = LaserState.IDLE


func _look_at_player() -> void:
	var player := target_player()
	if not player:
		return

	var direction := (player.global_position - global_position).normalized()
	if direction.length_squared() > 0.001:
		target_direction = direction
		# Look at player but keep upright
		var look_target := global_position + direction
		look_target.y = global_position.y
		if look_target.distance_to(global_position) > 0.001:
			look_at(look_target)


func _start_charge() -> void:
	laser_state = LaserState.CHARGING
	state_timer = charge_time
	_damage_applied = false
	_show_charge()
	_play_charge_audio()


func _fire_laser() -> void:
	laser_state = LaserState.FIRING
	state_timer = fire_duration
	_hide_charge()
	_show_beam()
	_stop_charge_audio()
	_play_zap_audio()
	laser_fired.emit()


func _end_fire() -> void:
	laser_state = LaserState.COOLDOWN
	state_timer = cooldown_time
	_hide_beam()


func _check_laser_hit() -> void:
	if _damage_applied:
		return

	if not raycast:
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider := raycast.get_collider()
		if collider and collider.is_in_group("Player"):
			_apply_laser_damage(collider)
			_damage_applied = true


func _apply_laser_damage(target: Node) -> void:
	# Try to find EntityStats on the target
	var stats: EntityStats = null

	if target.has_node("EntityStats"):
		stats = target.get_node("EntityStats") as EntityStats
	else:
		# Search in children
		for child in target.get_children():
			if child is EntityStats:
				stats = child
				break

	if stats:
		stats.get_hit(laser_damage)


func _show_charge() -> void:
	if charge_mesh:
		charge_mesh.visible = true


func _hide_charge() -> void:
	if charge_mesh:
		charge_mesh.visible = false


func _update_charge_visual() -> void:
	if not charge_mesh:
		return

	# Scale up the charge visual as charge progresses
	var progress := 1.0 - (state_timer / charge_time)
	var scale_factor := 0.5 + (progress * 0.5)

	# Update charge mesh scale for visual feedback
	charge_mesh.scale = Vector3(scale_factor, scale_factor, 1.0)

	# Pulse the emission for warning effect
	var material := charge_mesh.get_surface_override_material(0) as StandardMaterial3D
	if material:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		material.emission_energy_multiplier = 1.0 + (pulse * progress * 2.0)


func _show_beam() -> void:
	if beam_mesh:
		beam_mesh.visible = true
		_update_beam_to_target()


func _hide_beam() -> void:
	if beam_mesh:
		beam_mesh.visible = false


func _update_beam_to_target() -> void:
	if not beam_mesh or not raycast:
		return

	# Get the length of the beam based on raycast hit or max length
	var beam_length: float = 100.0

	raycast.force_raycast_update()
	if raycast.is_colliding():
		beam_length = global_position.distance_to(raycast.get_collision_point())

	# Update the cylinder mesh to match beam length
	var cylinder := beam_mesh.mesh as CylinderMesh
	if cylinder:
		cylinder.height = beam_length
		# Position the beam mesh so it extends forward from the emitter
		beam_mesh.position = Vector3(0, 0, -beam_length / 2.0)


func _play_charge_audio() -> void:
	if _charge_player and _charge_sound:
		_charge_player.stream = _charge_sound
		_charge_player.play()


## Stop the charge audio (when firing or interrupted)
func _stop_charge_audio() -> void:
	if _charge_player and _charge_player.playing:
		_charge_player.stop()


## Play the zap/laser fire sound
func _play_zap_audio() -> void:
	if _zap_sound and SFXManager:
		SFXManager.play_sfx_3d(_zap_sound, global_position, 0.0, 1.0)


## Set up audio players and cache sounds
func _setup_audio() -> void:
	# Create charge sound player attached to this enemy
	_charge_player = AudioStreamPlayer3D.new()
	_charge_player.bus = "SFX"
	_charge_player.max_distance = 40.0
	add_child(_charge_player)

	# Cache sounds from SFXManager
	if SFXManager:
		_charge_sound = SFXManager.create_charge_whine_sound(charge_time)
		_zap_sound = SFXManager.create_zap_sound()


## Override to prevent hit flash from interrupting laser visual
func _play_hit_flash() -> void:
	# Only flash the body mesh, not the beam
	var mesh_instance: MeshInstance3D = null
	for child in get_children():
		if child is MeshInstance3D and child != beam_mesh and child != charge_mesh:
			mesh_instance = child
			break

	if not mesh_instance:
		return

	var material := mesh_instance.get_surface_override_material(0)
	if not material or not material is StandardMaterial3D:
		return

	var std_mat := material as StandardMaterial3D
	var original_emission := std_mat.emission
	var original_enabled := std_mat.emission_enabled

	std_mat.emission_enabled = true
	std_mat.emission = Color.WHITE

	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(std_mat, "emission", original_emission, 0.3)
	_hit_flash_tween.tween_callback(func(): std_mat.emission_enabled = original_enabled)
