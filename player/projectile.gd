extends RigidBody3D
class_name Projectile

var impact_scn: PackedScene = preload("res://assets/effects/impact_sphere.tscn")

@export var damage: float = 10.0
@export var speed: float = 30.0
@export var lifetime: float = 5.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
    # Start lifetime timer
    var timer := get_tree().create_timer(lifetime)
    timer.timeout.connect(_on_lifetime_expired)

    # Connect body entered signal
    body_entered.connect(_on_body_entered)

func set_direction(direction: Vector3) -> void:
    linear_velocity = direction * speed

func _on_body_entered(body: Node) -> void:
    print("projectile hit body: %s" % body.get_path())
    if Util.check_coll_layer(body, "Player"):
        return  # Don't hit the player who fired

    if body.has_method("take_damage"):
        body.take_damage(damage)
    show_imact()

    _destroy()

func _on_lifetime_expired() -> void:
    _destroy()

func show_imact() -> void:
    var impact := impact_scn.instantiate()
    get_parent().add_child(impact)
    impact.global_position = global_position

func _destroy() -> void:
    queue_free()

func set_color(color: Color) -> void:
    if mesh and mesh.mesh:
        var mat := mesh.material_override
        mat.albedo_color = color
