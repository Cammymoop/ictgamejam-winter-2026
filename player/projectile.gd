extends RigidBody3D
class_name Projectile

var damage: float = 10.0
var lifetime: float = 5.0
var direction: Vector3 = Vector3.FORWARD
var speed: float = 30.0

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# Set initial velocity
	linear_velocity = direction * speed

	# Start lifetime timer
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)

	# Connect body entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return  # Don't hit the player who fired

	if body.has_method("take_damage"):
		body.take_damage(damage)

	_destroy()

func _on_lifetime_expired() -> void:
	_destroy()

func _destroy() -> void:
	# Could spawn hit particles here
	queue_free()

func set_color(color: Color) -> void:
	if mesh and mesh.mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
		mesh.material_override = mat

	if particles and particles.process_material:
		var mat: ParticleProcessMaterial = particles.process_material.duplicate()
		mat.color = color
		particles.process_material = mat
