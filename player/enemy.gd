extends CharacterBody3D
class_name Enemy

@export var max_health: float = 100.0
@export var move_speed: float = 3.0

var health: float = 100.0

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	move_and_slide()

func take_damage(amount: float) -> void:
	health -= amount
	_on_hit()
	if health <= 0:
		die()

func get_health() -> float:
	return health

func is_alive() -> bool:
	return health > 0

func die() -> void:
	queue_free()

func _on_hit() -> void:
	# Visual feedback on hit - flash red
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var tween := create_tween()
		var original_color := Color.WHITE
		if mesh.material_override:
			original_color = mesh.material_override.albedo_color

		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color.RED
		mesh.material_override = flash_mat

		tween.tween_callback(func():
			var restore_mat := StandardMaterial3D.new()
			restore_mat.albedo_color = original_color
			mesh.material_override = restore_mat
		).set_delay(0.1)
