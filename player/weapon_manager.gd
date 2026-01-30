extends Node3D
class_name WeaponManager

signal weapon_changed(weapon_index: int, weapon_data: WeaponData)

@export var projectile_scene: PackedScene

var weapons: Array[WeaponData] = []
var current_weapon_index: int = 0
var can_fire: bool = true
var target_position: Vector3 = Vector3.ZERO

@onready var muzzle: Marker3D = $Muzzle

func _ready() -> void:
	_setup_weapons()
	weapon_changed.emit(current_weapon_index, weapons[current_weapon_index])

func _setup_weapons() -> void:
	# Weapon 1: Pistol - balanced
	var pistol := WeaponData.new()
	pistol.name = "Pistol"
	pistol.fire_rate = 0.3
	pistol.projectile_speed = 40.0
	pistol.damage = 15.0
	pistol.projectile_count = 1
	pistol.projectile_color = Color(1.0, 0.8, 0.2)  # Yellow
	weapons.append(pistol)

	# Weapon 2: Shotgun - spread
	var shotgun := WeaponData.new()
	shotgun.name = "Shotgun"
	shotgun.fire_rate = 0.8
	shotgun.projectile_speed = 35.0
	shotgun.damage = 8.0
	shotgun.projectile_count = 5
	shotgun.spread_angle = 15.0
	shotgun.projectile_color = Color(1.0, 0.3, 0.1)  # Orange
	weapons.append(shotgun)

	# Weapon 3: Rapid Fire - fast
	var rapid := WeaponData.new()
	rapid.name = "Rapid Fire"
	rapid.fire_rate = 0.1
	rapid.projectile_speed = 50.0
	rapid.damage = 5.0
	rapid.projectile_count = 1
	rapid.projectile_scale = 0.7
	rapid.projectile_color = Color(0.2, 0.8, 1.0)  # Cyan
	weapons.append(rapid)

func _process(_delta: float) -> void:
	# Point weapon toward target
	if target_position != Vector3.ZERO:
		var look_target := target_position
		look_target.y = global_position.y  # Keep weapon level
		if look_target.distance_to(global_position) > 0.1:
			look_at(look_target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	# Weapon switching with number keys
	if event.is_action_pressed("weapon_1"):
		switch_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		switch_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		switch_weapon(2)

	# Scroll wheel weapon switching
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			switch_weapon((current_weapon_index - 1 + weapons.size()) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			switch_weapon((current_weapon_index + 1) % weapons.size())

	# Fire on click
	if event.is_action_pressed("shoot"):
		fire()

func switch_weapon(index: int) -> void:
	if index >= 0 and index < weapons.size():
		current_weapon_index = index
		weapon_changed.emit(current_weapon_index, weapons[current_weapon_index])

func fire() -> void:
	if not can_fire or not projectile_scene:
		return

	var weapon := weapons[current_weapon_index]
	var spawn_pos := muzzle.global_position if muzzle else global_position
	# Use weapon's forward direction (already rotated toward target via look_at)
	var base_direction := -global_transform.basis.z

	# Spawn projectiles
	for i in weapon.projectile_count:
		var direction := base_direction

		# Apply spread for multiple projectiles
		if weapon.projectile_count > 1:
			var spread_rad := deg_to_rad(weapon.spread_angle)
			var angle_offset := randf_range(-spread_rad, spread_rad)
			direction = direction.rotated(Vector3.UP, angle_offset)
		
		print("target_position: %s" % target_position)
		var dir_to_target = (target_position - spawn_pos).normalized()
		dir_to_target = dir_to_target.rotated(global_basis.y, randf_range(-deg_to_rad(weapon.spread_angle), deg_to_rad(weapon.spread_angle)))

		_spawn_projectile(spawn_pos, dir_to_target, weapon)

	# Start cooldown
	can_fire = false
	var timer := get_tree().create_timer(weapon.fire_rate)
	timer.timeout.connect(func(): can_fire = true)

func _spawn_projectile(pos: Vector3, direction: Vector3, weapon: WeaponData) -> void:
	var projectile: Projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)

	projectile.global_position = pos
	projectile.set_direction(direction)
	projectile.speed = weapon.projectile_speed
	projectile.damage = weapon.damage
	projectile.set_color(weapon.projectile_color)

	if weapon.projectile_scale != 1.0:
		projectile.scale *= weapon.projectile_scale

func set_target(world_pos: Vector3) -> void:
	target_position = world_pos

func get_current_weapon() -> WeaponData:
	return weapons[current_weapon_index]
