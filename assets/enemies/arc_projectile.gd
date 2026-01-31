class_name ArcProjectile
extends RigidBody3D
## A physics-based projectile that follows an arc trajectory with gravity.
## Creates area damage on ground impact.
##
## === BALANCE DOCUMENTATION ===
## Design Goal: Visible arc with small splash zone for precise dodging
## Player Context: 5 HP, speed 10.0, bounds 4x3 units
##
## FINAL BALANCED VALUES:
## - damage: 1.0 (set by ThrowingEnemy, 20% of player HP)
## - splash_radius: 1.5 (reduced from 2.0 - tighter splash rewards precise movement)
## - lifetime: 5.0s (unchanged - enough time for long arcs)
## - gravity_scale: 1.0 (standard gravity for predictable physics)
##
## Counterplay: The trajectory preview during windup shows exact landing spot.
## Splash radius 1.5 means player needs to move ~1.5 units from impact to avoid damage.
## At player speed 10.0, this takes only 0.15s of movement - very achievable.
## =========================

signal impacted(position: Vector3)

@export var damage: float = 1.0
@export var splash_radius: float = 1.5
@export var lifetime: float = 5.0
## Note: gravity_scale is inherited from RigidBody3D (default 1.0)

## Number of points to calculate for trajectory preview
@export var trajectory_preview_points: int = 30
## Time step for trajectory simulation
@export var trajectory_time_step: float = 0.05

var is_enemy_projectile: bool = true

## Visual impact effect scene
var _impact_effect_scene: PackedScene = preload("res://assets/effects/impact_sphere.tscn")

## Cached gravity value from project settings
var _gravity: float = 9.8

## Trajectory preview line (optional, created by enemy during wind-up)
var _trajectory_line: MeshInstance3D = null

## Cached thud sound for impact
var _thud_sound: AudioStreamWAV = null

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	# Cache gravity value
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float

	# gravity_scale uses RigidBody3D's built-in property (default 1.0)

	# Configure collision for enemy projectile
	_setup_collision_layers()

	# Start lifetime timer
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)

	# Connect body entered signal
	body_entered.connect(_on_body_entered)

	# Remove trajectory preview if it exists (it's only for wind-up phase)
	_clear_trajectory_preview()

	# Cache thud sound
	_setup_audio()


func _setup_collision_layers() -> void:
	if is_enemy_projectile:
		var enemy_coll_layer := Util.get_phys_layer_by_name("Enemies")
		var player_coll_layer := Util.get_phys_layer_by_name("Player")
		if enemy_coll_layer >= 0:
			set_collision_mask_value(enemy_coll_layer, false)
		if player_coll_layer >= 0:
			set_collision_mask_value(player_coll_layer, true)


## Launch the projectile with the given velocity vector
## This is the primary launch method used by ThrowingEnemy
func launch(velocity: Vector3) -> void:
	linear_velocity = velocity

	# Orient the projectile in the direction of travel
	if velocity.length() > 0.1:
		var direction := velocity.normalized()
		if abs(direction.y) < 0.99:  # Avoid gimbal lock
			look_at(global_position + direction, Vector3.UP)

	# Clear any trajectory preview now that we're launched
	_clear_trajectory_preview()


## Launch the projectile with a direction and force magnitude
## Alternative signature for simpler usage: launch_with_force(direction, force)
func launch_with_force(direction: Vector3, force: float) -> void:
	var velocity := direction.normalized() * force
	launch(velocity)


## Calculate the predicted trajectory points for preview visualization
## Returns array of Vector3 positions along the arc
func calculate_trajectory(
		start_pos: Vector3, initial_velocity: Vector3,
		num_points: int = -1, time_step: float = -1) -> Array[Vector3]:
	if num_points < 0:
		num_points = trajectory_preview_points
	if time_step < 0:
		time_step = trajectory_time_step

	var points: Array[Vector3] = []
	var pos := start_pos
	var vel := initial_velocity
	var gravity_vec := Vector3(0, -_gravity * gravity_scale, 0)

	for i in num_points:
		points.append(pos)
		# Simple Euler integration for trajectory prediction
		vel += gravity_vec * time_step
		pos += vel * time_step

		# Stop if we've gone below ground (y < 0)
		if pos.y < 0:
			# Interpolate to find ground intersection
			var prev_pos := points[points.size() - 1] if points.size() > 0 else start_pos
			if prev_pos.y > 0 and pos.y <= 0:
				var t := prev_pos.y / (prev_pos.y - pos.y)
				var ground_pos := prev_pos.lerp(pos, t)
				ground_pos.y = 0
				points.append(ground_pos)
			break

	return points


## Create a trajectory preview line mesh for visualization during wind-up
## Call this from the enemy during wind-up phase to show where projectile will land
func create_trajectory_preview(
		start_pos: Vector3, initial_velocity: Vector3,
		parent: Node3D = null) -> MeshInstance3D:
	_clear_trajectory_preview()

	var points := calculate_trajectory(start_pos, initial_velocity)
	if points.size() < 2:
		return null

	# Create material for the trajectory line first (to pass to surface_begin)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.0, 0.7)  # Orange, semi-transparent
	material.emission_enabled = true
	material.emission = Color(1.0, 0.5, 0.0)
	material.emission_energy_multiplier = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create immediate mesh for the line
	var immediate_mesh := ImmediateMesh.new()

	# Begin drawing line strip with the material
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)

	for point in points:
		# Convert to local coordinates if we have a parent
		var local_point := point
		if parent:
			local_point = parent.to_local(point)
		immediate_mesh.surface_add_vertex(local_point)

	immediate_mesh.surface_end()

	# Create mesh instance
	_trajectory_line = MeshInstance3D.new()
	_trajectory_line.mesh = immediate_mesh
	_trajectory_line.material_override = material

	# Add to parent or scene
	if parent:
		parent.add_child(_trajectory_line)
	elif is_inside_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(_trajectory_line)
		_trajectory_line.global_position = Vector3.ZERO
	# If not in tree and no parent provided, the mesh is still created and returned
	# but not added to any scene - caller is responsible for adding it

	return _trajectory_line


## Update the trajectory preview with new velocity (call during wind-up)
func update_trajectory_preview(start_pos: Vector3, initial_velocity: Vector3) -> void:
	if not _trajectory_line:
		return

	var points := calculate_trajectory(start_pos, initial_velocity)
	if points.size() < 2:
		return

	# Get the existing material from the trajectory line (or create a default)
	var material: Material = _trajectory_line.material_override
	if not material:
		material = StandardMaterial3D.new()
		var std_mat := material as StandardMaterial3D
		std_mat.albedo_color = Color(1.0, 0.5, 0.0, 0.7)
		std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trajectory_line.material_override = material

	# Recreate the mesh with updated points
	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)

	var parent := _trajectory_line.get_parent() as Node3D
	for point in points:
		var local_point := point
		if parent and parent != get_tree().current_scene:
			local_point = parent.to_local(point)
		immediate_mesh.surface_add_vertex(local_point)

	immediate_mesh.surface_end()
	_trajectory_line.mesh = immediate_mesh


## Clear and remove the trajectory preview
func _clear_trajectory_preview() -> void:
	if _trajectory_line and is_instance_valid(_trajectory_line):
		_trajectory_line.queue_free()
		_trajectory_line = null


## Get the predicted landing position for the given launch parameters
func get_predicted_landing_position(start_pos: Vector3, initial_velocity: Vector3) -> Vector3:
	# Use more points and longer time step to ensure we reach ground level
	# For a projectile starting at y=10 with upward velocity, we need more simulation time
	var points := calculate_trajectory(start_pos, initial_velocity, 100, 0.05)
	if points.size() > 0:
		var last_point := points[points.size() - 1]
		# If trajectory didn't reach ground, calculate analytically
		if last_point.y > 0.5:
			# Use physics equation to find time to ground: y = y0 + vy*t - 0.5*g*t^2
			# Solve for t when y = 0
			var g := _gravity * gravity_scale
			var y0 := start_pos.y
			var vy := initial_velocity.y
			# Quadratic formula: t = (vy + sqrt(vy^2 + 2*g*y0)) / g
			var discriminant := vy * vy + 2 * g * y0
			if discriminant >= 0:
				var t := (vy + sqrt(discriminant)) / g
				var landing_x := start_pos.x + initial_velocity.x * t
				var landing_z := start_pos.z + initial_velocity.z * t
				return Vector3(landing_x, 0.0, landing_z)
		return last_point
	return start_pos


func _on_body_entered(_body: Node) -> void:
	# Don't process if we're being freed
	if not is_inside_tree():
		return

	# Play thud sound on impact
	_play_thud()

	# Create splash damage at impact point
	_apply_splash_damage()

	# Show impact effect
	_spawn_impact_effect()

	# Emit impact signal
	impacted.emit(global_position)

	# Destroy projectile
	_destroy()


func _apply_splash_damage() -> void:
	# Find the player if within splash radius
	var player := Util.get_player_ref()
	if not player:
		return

	var distance := global_position.distance_to(player.global_position)
	if distance > splash_radius:
		return

	# Get player EntityStats and apply damage
	var player_stats: EntityStats = null

	if player in EntityManager.entity_stats:
		player_stats = EntityManager.entity_stats[player]
	else:
		player_stats = player.find_child("EntityStats", true, false) as EntityStats

	if player_stats:
		player_stats.get_hit(damage)


func _spawn_impact_effect() -> void:
	var effect := _impact_effect_scene.instantiate() as Node3D
	if effect and is_inside_tree() and get_tree() and get_tree().current_scene:
		effect.scale = Vector3.ONE * (splash_radius / 2.0)
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
	elif effect:
		effect.queue_free()


func _on_lifetime_expired() -> void:
	_destroy()


func _destroy() -> void:
	queue_free()


## Set up audio and cache sounds
func _setup_audio() -> void:
	if SFXManager:
		_thud_sound = SFXManager.create_thud_sound()


## Play thud sound on impact
func _play_thud() -> void:
	if _thud_sound and SFXManager:
		SFXManager.play_sfx_3d(_thud_sound, global_position, 2.0, randf_range(0.85, 1.15))
