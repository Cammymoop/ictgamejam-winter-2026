extends Node3D
class_name WeaponManager

signal weapon_changed(weapon_index: int, weapon_data: WeaponData)

@export var projectile_scene: PackedScene

@export var speed_factor: float = 1.0

var weapons: Array[WeaponData] = []
var current_weapon_index: int = 0
var can_fire: bool = true
var target_position: Vector3 = Vector3.ZERO

@export var weapon_colors: Array[Color] = [
    Color.WHITE, Color.BLUE, Color.RED
]

@onready var muzzle: Marker3D = $Muzzle

func _ready() -> void:
    _setup_weapons()
    weapon_changed.emit(current_weapon_index, weapons[current_weapon_index])

func _setup_weapons() -> void:
    # Weapon 1: Pistol - balanced
    var pistol := WeaponData.new()
    pistol.name = "Pistol"
    pistol.fire_rate = 0.7
    pistol.projectile_speed = 40.0
    pistol.damage = 3
    pistol.projectile_count = 1
    pistol.projectile_color = weapon_colors[0] * 2
    pistol.projectile_lifetime = 4.0
    pistol.spread_angle = 0.1
    weapons.append(pistol)

    # Weapon 2: Shotgun - spread
    var shotgun := WeaponData.new()
    shotgun.name = "Shotgun"
    shotgun.fire_rate = 1.2
    shotgun.projectile_speed = 25.0
    shotgun.speed_variance = 0.2
    shotgun.damage = 1.2
    shotgun.projectile_count = 8
    shotgun.spread_angle = 4.0
    shotgun.projectile_color = weapon_colors[1] * 1.2
    shotgun.projectile_lifetime = 1.9
    weapons.append(shotgun)

    # Weapon 3: Rapid Fire - fast
    var rapid := WeaponData.new()
    rapid.name = "Rapid Fire"
    rapid.fire_rate = 0.1
    rapid.projectile_speed = 70.0
    rapid.damage = 0.5
    rapid.projectile_count = 1
    rapid.projectile_scale = 0.7
    rapid.projectile_color = weapon_colors[2] * 1.3
    rapid.projectile_lifetime = 2.8
    rapid.spread_angle = 1.2
    rapid.impact_scale = 0.6
    weapons.append(rapid)

func _process(_delta: float) -> void:
    # Point weapon toward target
    if target_position != Vector3.ZERO:
        var look_target := target_position
        look_target.y = global_position.y  # Keep weapon level
        if look_target.distance_to(global_position) > 0.1:
            look_at(look_target, Vector3.UP)
    
    if Input.is_action_just_pressed("weapon_1"):
        switch_weapon(0)
    elif Input.is_action_just_pressed("weapon_2"):
        switch_weapon(1)
    elif Input.is_action_just_pressed("weapon_3"):
        switch_weapon(2)
    
    if Input.is_action_pressed("shoot"):
        try_fire()

func _unhandled_input(event: InputEvent) -> void:
    # Scroll wheel weapon switching
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            switch_weapon((current_weapon_index - 1 + weapons.size()) % weapons.size())
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            switch_weapon((current_weapon_index + 1) % weapons.size())

func switch_weapon(index: int) -> void:
    if index >= 0 and index < weapons.size():
        current_weapon_index = index
        weapon_changed.emit(current_weapon_index, weapons[current_weapon_index])

func try_fire() -> void:
    if not can_fire or not projectile_scene:
        return

    fire()

func fire() -> void:
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
        var base_dir: = (target_position - spawn_pos).normalized()
        var base_basis: = Basis.looking_at(base_dir, Vector3.UP)
        var dir_to_target: = base_dir.rotated(base_basis.y, randf_range(-deg_to_rad(weapon.spread_angle), deg_to_rad(weapon.spread_angle)))
        dir_to_target = dir_to_target.rotated(base_basis.z, randf_range(0, TAU))

        _spawn_projectile(spawn_pos, dir_to_target, weapon)

    # Start cooldown
    can_fire = false
    var timer := get_tree().create_timer(weapon.fire_rate)
    timer.timeout.connect(func(): can_fire = true)

func _spawn_projectile(pos: Vector3, direction: Vector3, weapon: WeaponData) -> void:
    var projectile: = projectile_scene.instantiate()
    projectile.is_enemy_projectile = false

    projectile.set_direction(direction)
    projectile.speed = weapon.projectile_speed
    if weapon.speed_variance > 0:
        projectile.speed *=  1 + randf_range( -weapon.speed_variance, weapon.speed_variance)
    projectile.damage = weapon.damage
    projectile.set_color(weapon.projectile_color.darkened(randf() * 0.4))
    projectile.lifetime = weapon.projectile_lifetime
    projectile.impace_scale = weapon.impact_scale

    get_tree().current_scene.add_child(projectile)

    projectile.global_position = pos

    if weapon.projectile_scale != 1.0:
        projectile.scale *= weapon.projectile_scale

func set_target(world_pos: Vector3) -> void:
    target_position = world_pos

func get_current_weapon() -> WeaponData:
    return weapons[current_weapon_index]
