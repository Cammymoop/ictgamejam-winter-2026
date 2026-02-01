extends Resource
class_name WeaponData

@export var projectile_scene: PackedScene = preload("res://assets/new_projectile.tscn")

@export var is_enemy: bool = false

@export var name: String = "Weapon"
@export var fire_rate: float = 0.2  # seconds between shots
@export var projectile_speed: float = 30.0
@export var speed_variance: float = 0.0
@export var damage: float = 10.0
@export var projectile_count: int = 1  # for shotgun spread
@export var spread_angle: float = 0.0  # degrees
@export var projectile_scale: float = 1.0
@export var projectile_color: Color = Color.WHITE
@export var projectile_color_variance: float = 0.4
@export var projectile_lifetime: float = 5.0
@export var impact_scale: float = 1.0

func make_projectiles() -> Array[Node3D]:
    var projectiles: Array[Node3D] = []
    for i in projectile_count:
        var projectile: = projectile_scene.instantiate()
        projectile.is_enemy_projectile = is_enemy

        #projectile.set_direction(direction)
        projectile.speed = projectile_speed
        if speed_variance > 0:
            projectile.speed *=  1 + randf_range(-speed_variance, speed_variance)
        projectile.damage = damage
        projectile.set_color(projectile_color.darkened(randf() * projectile_color_variance))
        projectile.lifetime = projectile_lifetime
        projectile.impact_scale = impact_scale
        projectiles.append(projectile)
    
    return projectiles