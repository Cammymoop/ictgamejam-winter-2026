extends Resource
class_name WeaponData

@export var name: String = "Weapon"
@export var fire_rate: float = 0.2  # seconds between shots
@export var projectile_speed: float = 30.0
@export var damage: float = 10.0
@export var projectile_count: int = 1  # for shotgun spread
@export var spread_angle: float = 0.0  # degrees
@export var projectile_scale: float = 1.0
@export var projectile_color: Color = Color.WHITE
